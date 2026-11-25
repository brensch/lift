//! Compaction: the batch files a busy hour makes (one every couple of
//! seconds) merged into one file for the hour once it has closed, and an
//! hour's files into one for the day once the day has. The events are the
//! same, byte for byte; only the files that hold them change. So an
//! account's events after a day sit in one file per day, read straight
//! there by row group, and DuckDB has a few files a day to read, not
//! thousands.
//!
//! A merge never edits: it streams the inputs (each sorted by account) into
//! a new file, sorted the same, at a higher zstd level (it's off the hot
//! path), syncs it, checks it holds as many rows as they did, then points
//! the index at it in one transaction; the inputs are deleted a minute
//! later, once anything reading them has finished. A crash anywhere leaves
//! either the inputs indexed or the output: a stray temporary file is
//! removed at start, an output the index doesn't name is a merge to do
//! again (and is removed when it is). One merge at a time, at low priority.

use std::cmp::Reverse;
use std::collections::{BTreeMap, BinaryHeap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use super::files::{self, Beats, EventsWriter, Row, RowCursor};
use super::Ledger;
use crate::db::DbResult;

/// How often compaction looks for closed hours and days.
const EVERY: Duration = Duration::from_secs(300);

/// The most files a single purge pass rewrites, per kind. Deleting one heavy
/// account can flag hundreds of files; capping the work per pass spreads the
/// rewrites over many passes (the account is already unreadable the moment it
/// is deleted) so a deletion can never become one big burst of disk I/O.
const MAX_PURGE_PER_PASS: i64 = 16;

/// How long merged inputs stay after the index stops naming them.
const GRACE: Duration = Duration::from_secs(60);

/// zstd's level for merged files: written once, read for years.
const LEVEL: i32 = 9;

pub fn run(ledger: &Arc<Ledger>) {
    let ledger = Arc::downgrade(ledger);
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(EVERY).await;
            let Some(this) = ledger.upgrade() else { return };
            if let Err(error) = compact(&this, now_ms()).await {
                tracing::warn!(%error, "compacting the ledger's files; tried again later");
            }
        }
    });
}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_millis() as i64)
}

/// What to merge: for each closed hour with more than its one merged file,
/// its files; for each closed day with more than one, its files.
fn plan(listing: &[String], now_ms: i64) -> Vec<(PathBuf, Vec<String>)> {
    let hour_closed = files::partition(now_ms - 3_600_000);
    let day_closed = files::partition(now_ms - 86_400_000 - 3_600_000);
    let (closed_date, closed_hour) = files::partition_of(&hour_closed.join("x").to_string_lossy());
    let (day_date, _) = files::partition_of(&day_closed.join("x").to_string_lossy());
    let mut hours: BTreeMap<(String, String), Vec<String>> = BTreeMap::new();
    let mut days: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for file in listing {
        let (Some(date), hour) = files::partition_of(file) else {
            continue;
        };
        match hour {
            Some(hour) => {
                // Hours up to the one that closed an hour ago.
                if (date.as_str(), hour.as_str())
                    <= (
                        closed_date.as_deref().unwrap_or(""),
                        closed_hour.as_deref().unwrap_or(""),
                    )
                {
                    hours
                        .entry((date.clone(), hour))
                        .or_default()
                        .push(file.clone());
                }
                if Some(date.as_str()) <= day_date.as_deref() {
                    days.entry(date).or_default().push(file.clone());
                }
            }
            None => {
                if Some(date.as_str()) <= day_date.as_deref() {
                    days.entry(date).or_default().push(file.clone());
                }
            }
        }
    }
    let stamp = now_ms;
    let mut merges = Vec::new();
    for (date, files) in days {
        if files.len() > 1 {
            merges.push((
                PathBuf::from(format!("date={date}/d-{stamp:013}.parquet")),
                files,
            ));
        }
    }
    for ((date, hour), files) in hours {
        // A day merge takes the hour's files too.
        if merges.iter().any(|(_, f)| f.contains(&files[0])) {
            continue;
        }
        if files.len() > 1 {
            merges.push((
                PathBuf::from(format!("date={date}/hour={hour}/h-{stamp:013}.parquet")),
                files,
            ));
        }
    }
    merges
}

/// The ids of accounts that have been deleted: a merge drops their rows.
async fn purged(ledger: &Ledger) -> DbResult<HashSet<String>> {
    Ok(
        sqlx::query_scalar::<_, String>("SELECT user_id FROM purged_accounts")
            .fetch_all(&ledger.read_pool)
            .await?
            .into_iter()
            .collect(),
    )
}

/// An output path in the same partition as `file`, stamped to be unique.
fn rewrite_output(file: &str, stamp: i64) -> Option<PathBuf> {
    let (date, hour) = files::partition_of(file);
    let date = date?;
    // A distinct prefix ('p') from plan()'s merge outputs (d-/h-), so a purge
    // rewrite can never land on the same path as a merge in the same run,
    // whatever the stamps. Plan treats it like any other file in its partition.
    Some(match hour {
        Some(hour) => PathBuf::from(format!("date={date}/hour={hour}/ph-{stamp:013}.parquet")),
        None => PathBuf::from(format!("date={date}/pd-{stamp:013}.parquet")),
    })
}

/// One pass: every closed hour and day merged, then deleted accounts' rows
/// erased from the files that still hold them.
pub async fn compact(ledger: &Ledger, now_ms: i64) -> DbResult<()> {
    let events_dir = ledger.events_dir();
    let listing = {
        let dir = events_dir.clone();
        tokio::task::spawn_blocking(move || files::list(&dir)).await??
    };
    for (output, inputs) in plan(&listing, now_ms) {
        merge_events(ledger, &output, &inputs).await?;
    }
    let beats_dir = ledger.beats_dir();
    let listing = {
        let dir = beats_dir.clone();
        tokio::task::spawn_blocking(move || files::list(&dir)).await??
    };
    for (output, inputs) in plan(&listing, now_ms) {
        merge_beats(ledger, &output, &inputs).await?;
    }
    purge(ledger, now_ms).await?;
    Ok(())
}

/// Rewrite every file a deleted account left rows in, dropping them, so the
/// rows leave the shared files even where normal compaction would never
/// revisit. Merging a file (above) clears its `purge_files` row; the rest are
/// the files only a deletion marked, rewritten one at a time here.
async fn purge(ledger: &Ledger, now_ms: i64) -> DbResult<()> {
    for (kind, dir) in [
        ("events", ledger.events_dir()),
        ("beats", ledger.beats_dir()),
    ] {
        let files: Vec<String> = sqlx::query_scalar(
            "SELECT DISTINCT file FROM purge_files WHERE kind = ? ORDER BY file LIMIT ?",
        )
        .bind(kind)
        .bind(MAX_PURGE_PER_PASS)
        .fetch_all(&ledger.read_pool)
        .await?;
        for (i, file) in files.iter().enumerate() {
            if !dir.join(file).exists() {
                // Already merged away: the rows are gone with the file.
                sqlx::query("DELETE FROM purge_files WHERE file = ? AND kind = ?")
                    .bind(file)
                    .bind(kind)
                    .execute(&ledger.write_pool)
                    .await?;
                continue;
            }
            let Some(output) = rewrite_output(file, now_ms + i as i64) else {
                continue;
            };
            let inputs = [file.clone()];
            if kind == "events" {
                merge_events(ledger, &output, &inputs).await?;
            } else {
                merge_beats(ledger, &output, &inputs).await?;
            }
        }
    }
    // A deleted account whose files are all scrubbed (whether here or by a
    // normal merge) no longer needs its tombstone: drop it, so purged_accounts
    // holds only accounts with scrubbing still to do and never grows without
    // bound.
    sqlx::query(
        "DELETE FROM purged_accounts WHERE user_id NOT IN (SELECT user_id FROM purge_files)",
    )
    .execute(&ledger.write_pool)
    .await?;
    Ok(())
}

/// A row from one input, ordered for the merge: by account, then seq.
struct Next(Row, usize);

impl PartialEq for Next {
    fn eq(&self, other: &Self) -> bool {
        (&self.0.user_id, self.0.seq) == (&other.0.user_id, other.0.seq)
    }
}
impl Eq for Next {}
impl PartialOrd for Next {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}
impl Ord for Next {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        (&self.0.user_id, self.0.seq, self.1).cmp(&(&other.0.user_id, other.0.seq, other.1))
    }
}

/// Stream `inputs` (each sorted by account then seq) into `output`, sorted
/// the same; the rows written, and what each account has in it.
fn merge_rows(
    dir: &Path,
    inputs: &[String],
    output: &Path,
    purged: &HashSet<String>,
) -> std::io::Result<(i64, Vec<files::Span>, i64, i64)> {
    let mut cursors: Vec<RowCursor> = inputs
        .iter()
        .map(|f| RowCursor::open(&dir.join(f)))
        .collect::<Result<_, _>>()?;
    let mut heap = BinaryHeap::new();
    for (i, cursor) in cursors.iter_mut().enumerate() {
        if let Some(row) = cursor.next_row()? {
            heap.push(Reverse(Next(row, i)));
        }
    }
    let mut writer = EventsWriter::create(&dir.join(output), LEVEL)?;
    let mut spans: Vec<files::Span> = Vec::new();
    let mut last: Option<(String, i64)> = None;
    let mut dropped: i64 = 0;
    let mut deduped: i64 = 0;
    while let Some(Reverse(Next(row, i))) = heap.pop() {
        if let Some(next) = cursors[i].next_row()? {
            heap.push(Reverse(Next(next, i)));
        }
        // The same event in two inputs (a merge redone): once. Counted so the
        // row tally below still balances.
        if last.as_ref() == Some(&(row.user_id.clone(), row.seq)) {
            deduped += 1;
            continue;
        }
        last = Some((row.user_id.clone(), row.seq));
        // A deleted account's rows leave the files here.
        if purged.contains(&row.user_id) {
            dropped += 1;
            continue;
        }
        match spans.last_mut() {
            Some(span) if span.user_id == row.user_id => {
                span.max_seq = row.seq;
                span.events += 1;
            }
            _ => spans.push(files::Span {
                user_id: row.user_id.clone(),
                min_seq: row.seq,
                max_seq: row.seq,
                events: 1,
            }),
        }
        writer.push(row)?;
    }
    Ok((writer.finish()?, spans, dropped, deduped))
}

async fn merge_events(ledger: &Ledger, output: &Path, inputs: &[String]) -> DbResult<()> {
    let dir = ledger.events_dir();
    let purged = purged(ledger).await?;
    let (counted, written, spans, dropped, deduped) = {
        let (dir, inputs, output) = (dir.clone(), inputs.to_vec(), output.to_path_buf());
        tokio::task::spawn_blocking(move || -> DbResult<_> {
            let counted: i64 = inputs
                .iter()
                .map(|f| files::row_count(&dir.join(f)))
                .sum::<std::io::Result<i64>>()?;
            let (written, spans, dropped, deduped) = merge_rows(&dir, &inputs, &output, &purged)?;
            Ok((counted, written, spans, dropped, deduped))
        })
        .await??
    };
    // Every input row is accounted for: kept, dropped (purged), or a duplicate
    // of one already taken (a re-merge).
    if written + dropped + deduped != counted {
        let _ = std::fs::remove_file(dir.join(output));
        return Err(format!(
            "merging into {}: {written} written + {dropped} dropped + {deduped} deduped, {counted} read",
            output.display()
        )
        .into());
    }
    // A purged account's rows left with this merge (dropped), or there were
    // none left to drop: either way these inputs no longer need purging.
    if written == 0 {
        // Nothing survived: don't leave an empty file or index it.
        let _ = std::fs::remove_file(dir.join(output));
    }
    let output = output.to_string_lossy().into_owned();
    let mut tx = ledger.write_pool.begin().await?;
    sqlx::query("DELETE FROM event_files WHERE file IN (SELECT value FROM json_each(?))")
        .bind(serde_json::to_string(inputs)?)
        .execute(&mut *tx)
        .await?;
    let rows: Vec<(&str, &str, i64, i64, i64)> = spans
        .iter()
        .map(|s| {
            (
                output.as_str(),
                s.user_id.as_str(),
                s.min_seq,
                s.max_seq,
                s.events,
            )
        })
        .collect();
    sqlx::query(
        "INSERT OR IGNORE INTO event_files (file, user_id, min_seq, max_seq, events)
         SELECT value ->> 0, value ->> 1, value ->> 2, value ->> 3, value ->> 4
         FROM json_each(?) WHERE EXISTS (SELECT 1 FROM users WHERE id = value ->> 1)",
    )
    .bind(serde_json::to_string(&rows)?)
    .execute(&mut *tx)
    .await?;
    sqlx::query(
        "DELETE FROM purge_files WHERE kind = 'events'
             AND file IN (SELECT value FROM json_each(?))",
    )
    .bind(serde_json::to_string(inputs)?)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    tracing::info!(file = %output, inputs = inputs.len(), rows = written, dropped, "events compacted");
    delete_later(dir, inputs.to_vec());
    Ok(())
}

async fn merge_beats(ledger: &Ledger, output: &Path, inputs: &[String]) -> DbResult<()> {
    let dir = ledger.beats_dir();
    let purged = purged(ledger).await?;
    let written = {
        let (dir, inputs, output) = (dir.clone(), inputs.to_vec(), output.to_path_buf());
        tokio::task::spawn_blocking(move || -> DbResult<usize> {
            // A day's heart rate is one row a workout: small enough to sort
            // whole.
            let mut beats: Vec<Beats> = Vec::new();
            for input in &inputs {
                beats.extend(files::read_all_beats(&dir.join(input), None)?);
            }
            // A deleted account's heart rate leaves the files here.
            beats.retain(|b| !purged.contains(&b.user_id));
            beats.sort_by(|a, b| (&a.user_id, &a.workout_id).cmp(&(&b.user_id, &b.workout_id)));
            beats.dedup_by(|a, b| a.user_id == b.user_id && a.workout_id == b.workout_id);
            let written = beats.len();
            if written == 0 {
                let _ = std::fs::remove_file(dir.join(&output));
            } else {
                files::write_beats(&dir.join(&output), &beats, LEVEL)?;
            }
            Ok(written)
        })
        .await??
    };
    let output = output.to_string_lossy().into_owned();
    let mut tx = ledger.write_pool.begin().await?;
    sqlx::query(
        "UPDATE heart_rate_files SET file = ? WHERE file IN (SELECT value FROM json_each(?))",
    )
    .bind(&output)
    .bind(serde_json::to_string(inputs)?)
    .execute(&mut *tx)
    .await?;
    sqlx::query(
        "DELETE FROM purge_files WHERE kind = 'beats'
             AND file IN (SELECT value FROM json_each(?))",
    )
    .bind(serde_json::to_string(inputs)?)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    tracing::info!(file = %output, inputs = inputs.len(), workouts = written, "heart rate compacted");
    delete_later(dir, inputs.to_vec());
    Ok(())
}

/// Merged inputs go once anything reading them has had time to finish.
fn delete_later(dir: PathBuf, inputs: Vec<String>) {
    tokio::spawn(async move {
        tokio::time::sleep(if cfg!(test) { Duration::ZERO } else { GRACE }).await;
        for input in inputs {
            let _ = std::fs::remove_file(dir.join(input));
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn closed_hours_and_days_are_planned_open_ones_left() {
        // 2026-11-24 06:30 UTC.
        let now = 1_795_501_800_000;
        let listing: Vec<String> = [
            "date=2026-11-24/hour=06/b-1-0.parquet", // this hour: left
            "date=2026-11-24/hour=06/b-2-0.parquet",
            "date=2026-11-24/hour=04/b-3-0.parquet", // closed: merged
            "date=2026-11-24/hour=04/b-4-0.parquet",
            "date=2026-11-24/hour=03/h-5.parquet", // merged already, alone: left
            "date=2026-11-22/hour=10/h-6.parquet", // a closed day: merged whole
            "date=2026-11-22/hour=11/h-7.parquet",
        ]
        .map(String::from)
        .to_vec();
        let merges = plan(&listing, now);
        let outputs: Vec<String> = merges
            .iter()
            .map(|(o, _)| o.to_string_lossy().into_owned())
            .collect();
        assert!(
            outputs.iter().any(|o| o.starts_with("date=2026-11-22/d-")),
            "{outputs:?}"
        );
        assert!(
            outputs
                .iter()
                .any(|o| o.starts_with("date=2026-11-24/hour=04/h-")),
            "{outputs:?}"
        );
        assert_eq!(merges.len(), 2, "{outputs:?}");
        assert!(merges.iter().all(|(_, inputs)| inputs.len() == 2));
    }
}
