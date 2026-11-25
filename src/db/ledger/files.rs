//! The ledger's files: Parquet, Hive-partitioned by day and hour, so DuckDB
//! and the like read the tree as it is:
//!
//! ```text
//! events/date=2026-11-24/hour=06/b-<ms>-<n>.parquet   a batch, as written
//! events/date=2026-11-24/hour=06/h-<ms>.parquet       that hour, compacted
//! events/date=2026-11-24/d-<ms>.parquet               that day, compacted
//! heart_rate/…                                        the same shape
//! ```
//!
//! A file is written whole to a temporary name, synced and renamed into
//! place, so one is either all there or not; once written it never changes
//! (compaction writes new files and the old go). Rows are sorted by account.
//!
//! Events: `user_id`, `seq`, `id`, `at`, `kind` (the fact), `workout_id`,
//! `heart_rate` (a workout's heart rate, which a fold without it skips
//! unread), `event` (the event as JSON, exactly as stored). Heart rate,
//! typed for queries and fetched by workout: `user_id`, `workout_id`,
//! `start_ms`, `t_ms` (each reading's time), `bpm`.

use std::fs::File;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use arrow_array::builder::{Int64Builder, ListBuilder, UInt16Builder};
use arrow_array::{Array, ArrayRef, BooleanArray, Int64Array, RecordBatch, StringArray};
use arrow_schema::{DataType, Field, Schema};
use parquet::arrow::arrow_reader::ParquetRecordBatchReaderBuilder;
use parquet::arrow::ArrowWriter;
use parquet::basic::{Compression, ZstdLevel};
use parquet::data_type::AsBytes;
use parquet::file::properties::WriterProperties;
use parquet::file::statistics::Statistics;

/// Rows per row group: a few accounts' worth, so reading one account
/// skips most of a file.
const ROWS_PER_GROUP: usize = 8_192;

/// One stored event.
#[derive(Clone, Debug, PartialEq)]
pub struct Row {
    pub user_id: String,
    pub seq: i64,
    pub id: String,
    pub at: i64,
    pub kind: String,
    pub workout_id: String,
    pub heart_rate: bool,
    /// The event as JSON.
    pub event: String,
}

/// One workout's heart rate.
#[derive(Clone, Debug, PartialEq)]
pub struct Beats {
    pub user_id: String,
    pub workout_id: String,
    pub start_ms: i64,
    pub t_ms: Vec<i64>,
    pub bpm: Vec<u16>,
}

/// What a file holds of one account: what the index (`event_files`) keeps.
#[derive(Clone, Debug, PartialEq)]
pub struct Span {
    pub user_id: String,
    pub min_seq: i64,
    pub max_seq: i64,
    pub events: i64,
}

fn events_schema() -> Arc<Schema> {
    Arc::new(Schema::new(vec![
        Field::new("user_id", DataType::Utf8, false),
        Field::new("seq", DataType::Int64, false),
        Field::new("id", DataType::Utf8, false),
        Field::new("at", DataType::Int64, false),
        Field::new("kind", DataType::Utf8, false),
        Field::new("workout_id", DataType::Utf8, false),
        Field::new("heart_rate", DataType::Boolean, false),
        Field::new("event", DataType::Utf8, false),
    ]))
}

fn beats_schema() -> Arc<Schema> {
    Arc::new(Schema::new(vec![
        Field::new("user_id", DataType::Utf8, false),
        Field::new("workout_id", DataType::Utf8, false),
        Field::new("start_ms", DataType::Int64, false),
        Field::new(
            "t_ms",
            DataType::List(Arc::new(Field::new("item", DataType::Int64, true))),
            false,
        ),
        Field::new(
            "bpm",
            DataType::List(Arc::new(Field::new("item", DataType::UInt16, true))),
            false,
        ),
    ]))
}

fn other(error: impl std::fmt::Display) -> io::Error {
    io::Error::other(error.to_string())
}

fn props(level: i32) -> io::Result<WriterProperties> {
    Ok(WriterProperties::builder()
        .set_compression(Compression::ZSTD(ZstdLevel::try_new(level).map_err(other)?))
        .set_max_row_group_row_count(Some(ROWS_PER_GROUP))
        .build())
}

/// Write `batch` as the file at `path`: all of it, synced, or nothing.
fn write_batch(
    path: &Path,
    schema: Arc<Schema>,
    batch: &RecordBatch,
    level: i32,
) -> io::Result<()> {
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let tmp = path.with_extension("parquet.tmp");
    let file = File::create(&tmp)?;
    let mut writer = ArrowWriter::try_new(file, schema, Some(props(level)?)).map_err(other)?;
    writer.write(batch).map_err(other)?;
    let file = writer.into_inner().map_err(other)?;
    file.sync_all()?;
    drop(file);
    std::fs::rename(&tmp, path)?;
    if let Some(dir) = path.parent() {
        File::open(dir)?.sync_all()?;
    }
    Ok(())
}

/// Events (sorted by account, then seq) as the file at `path`.
pub fn write_events(path: &Path, rows: &[Row], level: i32) -> io::Result<()> {
    let batch = RecordBatch::try_new(
        events_schema(),
        vec![
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.user_id.as_str()),
            )) as ArrayRef,
            Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.seq))),
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.id.as_str()),
            )),
            Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.at))),
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.kind.as_str()),
            )),
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.workout_id.as_str()),
            )),
            Arc::new(BooleanArray::from(
                rows.iter().map(|r| r.heart_rate).collect::<Vec<_>>(),
            )),
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.event.as_str()),
            )),
        ],
    )
    .map_err(other)?;
    write_batch(path, events_schema(), &batch, level)
}

/// Heart rate (sorted by account, then workout) as the file at `path`.
pub fn write_beats(path: &Path, beats: &[Beats], level: i32) -> io::Result<()> {
    let mut t_ms = ListBuilder::new(Int64Builder::new());
    let mut bpm = ListBuilder::new(UInt16Builder::new());
    for b in beats {
        t_ms.values().append_slice(&b.t_ms);
        t_ms.append(true);
        bpm.values().append_slice(&b.bpm);
        bpm.append(true);
    }
    let batch = RecordBatch::try_new(
        beats_schema(),
        vec![
            Arc::new(StringArray::from_iter_values(
                beats.iter().map(|b| b.user_id.as_str()),
            )) as ArrayRef,
            Arc::new(StringArray::from_iter_values(
                beats.iter().map(|b| b.workout_id.as_str()),
            )),
            Arc::new(Int64Array::from_iter_values(
                beats.iter().map(|b| b.start_ms),
            )),
            Arc::new(t_ms.finish()),
            Arc::new(bpm.finish()),
        ],
    )
    .map_err(other)?;
    write_batch(path, beats_schema(), &batch, level)
}

/// What each account has in `rows` (sorted by account, then seq).
pub fn spans(rows: &[Row]) -> Vec<Span> {
    let mut spans: Vec<Span> = Vec::new();
    for row in rows {
        match spans.last_mut() {
            Some(span) if span.user_id == row.user_id => {
                span.min_seq = span.min_seq.min(row.seq);
                span.max_seq = span.max_seq.max(row.seq);
                span.events += 1;
            }
            _ => spans.push(Span {
                user_id: row.user_id.clone(),
                min_seq: row.seq,
                max_seq: row.seq,
                events: 1,
            }),
        }
    }
    spans
}

fn strings(batch: &RecordBatch, name: &str) -> io::Result<StringArray> {
    let column = batch
        .column_by_name(name)
        .ok_or_else(|| other(format!("no column {name}")))?;
    column
        .as_any()
        .downcast_ref::<StringArray>()
        .cloned()
        .ok_or_else(|| other(format!("{name}: another type")))
}

fn ints(batch: &RecordBatch, name: &str) -> io::Result<Int64Array> {
    let column = batch
        .column_by_name(name)
        .ok_or_else(|| other(format!("no column {name}")))?;
    column
        .as_any()
        .downcast_ref::<Int64Array>()
        .cloned()
        .ok_or_else(|| other(format!("{name}: another type")))
}

fn bools(batch: &RecordBatch, name: &str) -> io::Result<BooleanArray> {
    let column = batch
        .column_by_name(name)
        .ok_or_else(|| other(format!("no column {name}")))?;
    column
        .as_any()
        .downcast_ref::<BooleanArray>()
        .cloned()
        .ok_or_else(|| other(format!("{name}: another type")))
}

/// Whether a row group may hold `user_id`, by its first column's statistics.
fn may_hold(stats: Option<&Statistics>, user_id: &str) -> bool {
    match stats {
        Some(Statistics::ByteArray(s)) => match (s.min_opt(), s.max_opt()) {
            (Some(min), Some(max)) => {
                min.as_bytes() <= user_id.as_bytes() && user_id.as_bytes() <= max.as_bytes()
            }
            _ => true,
        },
        _ => true,
    }
}

fn reader_for(
    path: &Path,
    user_id: Option<&str>,
) -> io::Result<parquet::arrow::arrow_reader::ParquetRecordBatchReader> {
    let builder = ParquetRecordBatchReaderBuilder::try_new(File::open(path)?).map_err(other)?;
    let builder = match user_id {
        Some(user_id) => {
            let groups: Vec<usize> = builder
                .metadata()
                .row_groups()
                .iter()
                .enumerate()
                .filter(|(_, g)| may_hold(g.column(0).statistics(), user_id))
                .map(|(i, _)| i)
                .collect();
            builder.with_row_groups(groups)
        }
        None => builder,
    };
    builder.build().map_err(other)
}

/// The rows of the file (one account's, with `user_id`), in its order.
pub fn read_rows(path: &Path, user_id: Option<&str>) -> io::Result<Vec<Row>> {
    let mut out = Vec::new();
    for batch in reader_for(path, user_id)? {
        let batch = batch.map_err(other)?;
        let users = strings(&batch, "user_id")?;
        let seqs = ints(&batch, "seq")?;
        let ids = strings(&batch, "id")?;
        let ats = ints(&batch, "at")?;
        let hr = bools(&batch, "heart_rate")?;
        let events = strings(&batch, "event")?;
        // Files from before these columns lack them.
        let kinds = strings(&batch, "kind").ok();
        let workouts = strings(&batch, "workout_id").ok();
        for i in 0..batch.num_rows() {
            if user_id.is_some_and(|u| users.value(i) != u) {
                continue;
            }
            out.push(Row {
                user_id: users.value(i).to_string(),
                seq: seqs.value(i),
                id: ids.value(i).to_string(),
                at: ats.value(i),
                kind: kinds.as_ref().map_or("", |k| k.value(i)).to_string(),
                workout_id: workouts.as_ref().map_or("", |w| w.value(i)).to_string(),
                heart_rate: hr.value(i),
                event: events.value(i).to_string(),
            });
        }
    }
    Ok(out)
}

/// The heart rate of one workout in the file, if it holds it.
pub fn read_beats(path: &Path, user_id: &str, workout_id: &str) -> io::Result<Option<Beats>> {
    for beats in read_all_beats(path, Some(user_id))? {
        if beats.workout_id == workout_id {
            return Ok(Some(beats));
        }
    }
    Ok(None)
}

/// Every workout's heart rate in the file (one account's, with `user_id`).
pub fn read_all_beats(path: &Path, user_id: Option<&str>) -> io::Result<Vec<Beats>> {
    let mut out = Vec::new();
    for batch in reader_for(path, user_id)? {
        let batch = batch.map_err(other)?;
        let users = strings(&batch, "user_id")?;
        let workouts = strings(&batch, "workout_id")?;
        let starts = ints(&batch, "start_ms")?;
        let list = |name: &str| {
            batch
                .column_by_name(name)
                .and_then(|c| c.as_any().downcast_ref::<arrow_array::ListArray>().cloned())
                .ok_or_else(|| other(format!("{name}: another type")))
        };
        let (t_ms, bpm) = (list("t_ms")?, list("bpm")?);
        for i in 0..batch.num_rows() {
            if user_id.is_some_and(|u| users.value(i) != u) {
                continue;
            }
            let t = t_ms.value(i);
            let b = bpm.value(i);
            let t = t
                .as_any()
                .downcast_ref::<Int64Array>()
                .ok_or_else(|| other("t_ms: another type"))?;
            let b = b
                .as_any()
                .downcast_ref::<arrow_array::UInt16Array>()
                .ok_or_else(|| other("bpm: another type"))?;
            out.push(Beats {
                user_id: users.value(i).to_string(),
                workout_id: workouts.value(i).to_string(),
                start_ms: starts.value(i),
                t_ms: t.values().to_vec(),
                bpm: b.values().to_vec(),
            });
        }
    }
    Ok(out)
}

/// How many rows the file holds, from its footer.
pub fn row_count(path: &Path) -> io::Result<i64> {
    let builder = ParquetRecordBatchReaderBuilder::try_new(File::open(path)?).map_err(other)?;
    Ok(builder.metadata().file_metadata().num_rows())
}

/// Every Parquet file under `dir`, each as its path relative to `dir`,
/// oldest first (names sort by when they were written); a temporary one a
/// crash left is removed.
pub fn list(dir: &Path) -> io::Result<Vec<String>> {
    let mut files = Vec::new();
    walk(dir, dir, &mut files)?;
    files.sort();
    Ok(files)
}

/// Files set aside at start (written by a write that never committed) go
/// here, under the folder of the files: kept, never read.
pub const ORPHANED: &str = "orphaned";

/// Remove what writes left half done (`.parquet.tmp`): only at start, when
/// nothing is writing.
pub fn clear_temporary(dir: &Path) -> io::Result<()> {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return Ok(());
    };
    for entry in entries {
        let path = entry?.path();
        if path.is_dir() {
            clear_temporary(&path)?;
        } else if path.to_string_lossy().ends_with(".parquet.tmp") {
            std::fs::remove_file(&path)?;
        }
    }
    Ok(())
}

fn walk(root: &Path, dir: &Path, out: &mut Vec<String>) -> io::Result<()> {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return Ok(());
    };
    for entry in entries {
        let path = entry?.path();
        if path.is_dir() {
            if path.file_name().and_then(|n| n.to_str()) != Some(ORPHANED) {
                walk(root, &path, out)?;
            }
            continue;
        }
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or_default();
        if name.ends_with(".parquet") {
            if let Ok(relative) = path.strip_prefix(root) {
                out.push(relative.to_string_lossy().into_owned());
            }
        }
    }
    Ok(())
}

/// The Hive partition a batch written at `ms` (Unix ms) goes in.
pub fn partition(ms: i64) -> PathBuf {
    let secs = ms.div_euclid(1000);
    let days = secs.div_euclid(86_400);
    let (y, m, d) = civil_from_days(days);
    let hour = secs.rem_euclid(86_400) / 3600;
    PathBuf::from(format!("date={y:04}-{m:02}-{d:02}/hour={hour:02}"))
}

/// The day (`date=YYYY-MM-DD`) and hour (`hour=HH`) a file's relative path
/// is in, if it is in one.
pub fn partition_of(relative: &str) -> (Option<String>, Option<String>) {
    let mut date = None;
    let mut hour = None;
    for part in Path::new(relative).components() {
        let part = part.as_os_str().to_string_lossy();
        if let Some(d) = part.strip_prefix("date=") {
            date = Some(d.to_string());
        } else if let Some(h) = part.strip_prefix("hour=") {
            hour = Some(h.to_string());
        }
    }
    (date, hour)
}

/// Days since 1970-01-01 as (year, month, day): Howard Hinnant's algorithm.
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// Events written a row group at a time: what compaction streams a merge
/// into, so a day of events never sits in memory whole.
pub struct EventsWriter {
    writer: ArrowWriter<File>,
    tmp: PathBuf,
    path: PathBuf,
    rows: Vec<Row>,
    written: i64,
}

impl EventsWriter {
    pub fn create(path: &Path, level: i32) -> io::Result<Self> {
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir)?;
        }
        let tmp = path.with_extension("parquet.tmp");
        let writer =
            ArrowWriter::try_new(File::create(&tmp)?, events_schema(), Some(props(level)?))
                .map_err(other)?;
        Ok(Self {
            writer,
            tmp,
            path: path.to_path_buf(),
            rows: Vec::with_capacity(ROWS_PER_GROUP),
            written: 0,
        })
    }

    pub fn push(&mut self, row: Row) -> io::Result<()> {
        self.rows.push(row);
        if self.rows.len() >= ROWS_PER_GROUP {
            self.write_rows()?;
        }
        Ok(())
    }

    fn write_rows(&mut self) -> io::Result<()> {
        if self.rows.is_empty() {
            return Ok(());
        }
        let rows = std::mem::take(&mut self.rows);
        let batch = RecordBatch::try_new(
            events_schema(),
            vec![
                Arc::new(StringArray::from_iter_values(
                    rows.iter().map(|r| r.user_id.as_str()),
                )) as ArrayRef,
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.seq))),
                Arc::new(StringArray::from_iter_values(
                    rows.iter().map(|r| r.id.as_str()),
                )),
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.at))),
                Arc::new(StringArray::from_iter_values(
                    rows.iter().map(|r| r.kind.as_str()),
                )),
                Arc::new(StringArray::from_iter_values(
                    rows.iter().map(|r| r.workout_id.as_str()),
                )),
                Arc::new(BooleanArray::from(
                    rows.iter().map(|r| r.heart_rate).collect::<Vec<_>>(),
                )),
                Arc::new(StringArray::from_iter_values(
                    rows.iter().map(|r| r.event.as_str()),
                )),
            ],
        )
        .map_err(other)?;
        self.writer.write(&batch).map_err(other)?;
        self.written += rows.len() as i64;
        self.rows = Vec::with_capacity(ROWS_PER_GROUP);
        Ok(())
    }

    /// Everything written, synced and renamed into place; how many rows.
    pub fn finish(mut self) -> io::Result<i64> {
        self.write_rows()?;
        let file = self.writer.into_inner().map_err(other)?;
        file.sync_all()?;
        drop(file);
        std::fs::rename(&self.tmp, &self.path)?;
        if let Some(dir) = self.path.parent() {
            File::open(dir)?.sync_all()?;
        }
        Ok(self.written)
    }
}

/// A file's rows one at a time, a batch in memory at once: one input of a
/// merge.
pub struct RowCursor {
    reader: parquet::arrow::arrow_reader::ParquetRecordBatchReader,
    batch: Vec<Row>,
    at: usize,
}

impl RowCursor {
    pub fn open(path: &Path) -> io::Result<Self> {
        Ok(Self {
            reader: reader_for(path, None)?,
            batch: Vec::new(),
            at: 0,
        })
    }

    /// The next row, or None at the end.
    pub fn next_row(&mut self) -> io::Result<Option<Row>> {
        while self.at >= self.batch.len() {
            let Some(batch) = self.reader.next() else {
                return Ok(None);
            };
            self.batch = rows_of(&batch.map_err(other)?)?;
            self.at = 0;
        }
        let row = std::mem::replace(
            &mut self.batch[self.at],
            Row {
                user_id: String::new(),
                seq: 0,
                id: String::new(),
                at: 0,
                kind: String::new(),
                workout_id: String::new(),
                heart_rate: false,
                event: String::new(),
            },
        );
        self.at += 1;
        Ok(Some(row))
    }
}

fn rows_of(batch: &RecordBatch) -> io::Result<Vec<Row>> {
    let users = strings(batch, "user_id")?;
    let seqs = ints(batch, "seq")?;
    let ids = strings(batch, "id")?;
    let ats = ints(batch, "at")?;
    let hr = bools(batch, "heart_rate")?;
    let events = strings(batch, "event")?;
    let kinds = strings(batch, "kind").ok();
    let workouts = strings(batch, "workout_id").ok();
    Ok((0..batch.num_rows())
        .map(|i| Row {
            user_id: users.value(i).to_string(),
            seq: seqs.value(i),
            id: ids.value(i).to_string(),
            at: ats.value(i),
            kind: kinds.as_ref().map_or("", |k| k.value(i)).to_string(),
            workout_id: workouts.as_ref().map_or("", |w| w.value(i)).to_string(),
            heart_rate: hr.value(i),
            event: events.value(i).to_string(),
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn partitions_are_hive_dates_and_hours() {
        // 2026-11-24 06:01:15 UTC.
        assert_eq!(
            partition(1_795_500_075_000),
            PathBuf::from("date=2026-11-24/hour=06")
        );
        assert_eq!(partition(0), PathBuf::from("date=1970-01-01/hour=00"));
        assert_eq!(
            partition_of("date=2026-11-24/hour=06/b-1-0.parquet"),
            (Some("2026-11-24".into()), Some("06".into()))
        );
        assert_eq!(partition_of("old.parquet"), (None, None));
    }

    #[test]
    fn heart_rate_round_trips_typed() {
        let dir = std::env::temp_dir().join(format!("beats-{}", std::process::id()));
        let path = dir.join("date=2026-11-24/hour=06/b.parquet");
        let beats = vec![Beats {
            user_id: "u".into(),
            workout_id: "w".into(),
            start_ms: 5,
            t_ms: vec![5, 2005, 4010],
            bpm: vec![100, 120, 118],
        }];
        write_beats(&path, &beats, 3).unwrap();
        assert_eq!(read_beats(&path, "u", "w").unwrap(), Some(beats[0].clone()));
        assert_eq!(read_beats(&path, "u", "x").unwrap(), None);
        assert_eq!(list(&dir).unwrap(), ["date=2026-11-24/hour=06/b.parquet"]);
        let _ = std::fs::remove_dir_all(dir);
    }
}
