//! Event files: each flush of the ledger is one Parquet file under
//! `DATA_DIR/events/`, its rows the events placed in that flush, sorted by
//! account then seq. A file is written whole to a temporary name, synced,
//! and renamed into place, so one is either all there or not there; once
//! written it is never changed.
//!
//! Columns: `user_id`, `seq`, `id`, `at`, `heart_rate` (true for a
//! workout's heart rate, which a fold without heart rate skips unread) and
//! `event`, the event as JSON exactly as stored before (`schlift_core::
//! events`). Row groups are small and sorted by account, so reading one
//! account's events skips the rest of the file by its statistics.

use std::fs::File;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use arrow_array::{ArrayRef, BooleanArray, Int64Array, RecordBatch, StringArray};
use arrow_schema::{DataType, Field, Schema};
use parquet::arrow::arrow_reader::ParquetRecordBatchReaderBuilder;
use parquet::arrow::{ArrowWriter, ProjectionMask};
use parquet::basic::{Compression, ZstdLevel};
use parquet::data_type::AsBytes;
use parquet::file::properties::WriterProperties;
use parquet::file::statistics::Statistics;

/// Rows per row group: a few accounts' worth, so one account's read skips
/// most of a large file.
const ROWS_PER_GROUP: usize = 8_192;

/// One stored event.
#[derive(Clone, Debug, PartialEq)]
pub struct Row {
    pub user_id: String,
    pub seq: i64,
    pub id: String,
    pub at: i64,
    pub heart_rate: bool,
    /// The event as JSON.
    pub event: String,
}

/// What a file holds of one account: what the index (`event_files`) keeps.
#[derive(Clone, Debug, PartialEq)]
pub struct Span {
    pub user_id: String,
    pub min_seq: i64,
    pub max_seq: i64,
    pub events: i64,
}

fn schema() -> Arc<Schema> {
    Arc::new(Schema::new(vec![
        Field::new("user_id", DataType::Utf8, false),
        Field::new("seq", DataType::Int64, false),
        Field::new("id", DataType::Utf8, false),
        Field::new("at", DataType::Int64, false),
        Field::new("heart_rate", DataType::Boolean, false),
        Field::new("event", DataType::Utf8, false),
    ]))
}

fn other(error: impl std::fmt::Display) -> io::Error {
    io::Error::other(error.to_string())
}

/// Write `rows` (sorted by account, then seq) as the file at `path`: all of
/// it, synced, or nothing.
pub fn write(path: &Path, rows: &[Row]) -> io::Result<()> {
    let tmp = path.with_extension("parquet.tmp");
    let batch = RecordBatch::try_new(
        schema(),
        vec![
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.user_id.as_str()),
            )) as ArrayRef,
            Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.seq))),
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.id.as_str()),
            )),
            Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.at))),
            Arc::new(BooleanArray::from(
                rows.iter().map(|r| r.heart_rate).collect::<Vec<_>>(),
            )),
            Arc::new(StringArray::from_iter_values(
                rows.iter().map(|r| r.event.as_str()),
            )),
        ],
    )
    .map_err(other)?;
    let props = WriterProperties::builder()
        .set_compression(Compression::ZSTD(ZstdLevel::try_new(3).map_err(other)?))
        .set_max_row_group_size(ROWS_PER_GROUP)
        .build();
    let file = File::create(&tmp)?;
    let mut writer = ArrowWriter::try_new(file, schema(), Some(props)).map_err(other)?;
    writer.write(&batch).map_err(other)?;
    let file = writer.into_inner().map_err(other)?;
    file.sync_all()?;
    drop(file);
    std::fs::rename(&tmp, path)?;
    sync_dir(path)
}

/// The directory entry of a renamed file is on disk too.
fn sync_dir(path: &Path) -> io::Result<()> {
    if let Some(dir) = path.parent() {
        File::open(dir)?.sync_all()?;
    }
    Ok(())
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

fn strings(batch: &RecordBatch, column: usize) -> io::Result<&StringArray> {
    batch
        .column(column)
        .as_any()
        .downcast_ref::<StringArray>()
        .ok_or_else(|| other("a column of another type"))
}

fn ints(batch: &RecordBatch, column: usize) -> io::Result<&Int64Array> {
    batch
        .column(column)
        .as_any()
        .downcast_ref::<Int64Array>()
        .ok_or_else(|| other("a column of another type"))
}

/// Whether a row group may hold `user_id`, by its statistics.
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

/// One account's events in the file after `after_seq`, in order: (seq, id,
/// event JSON). With `heart_rate` false, a workout's heart rate is left
/// out, unread.
pub fn read_user(
    path: &Path,
    user_id: &str,
    after_seq: i64,
    heart_rate: bool,
) -> io::Result<Vec<(i64, String, String)>> {
    let builder = ParquetRecordBatchReaderBuilder::try_new(File::open(path)?).map_err(other)?;
    let groups: Vec<usize> = builder
        .metadata()
        .row_groups()
        .iter()
        .enumerate()
        .filter(|(_, g)| may_hold(g.column(0).statistics(), user_id))
        .map(|(i, _)| i)
        .collect();
    let reader = builder.with_row_groups(groups).build().map_err(other)?;
    let mut out = Vec::new();
    for batch in reader {
        let batch = batch.map_err(other)?;
        let users = strings(&batch, 0)?;
        let seqs = ints(&batch, 1)?;
        let ids = strings(&batch, 2)?;
        let hr = batch
            .column(4)
            .as_any()
            .downcast_ref::<BooleanArray>()
            .ok_or_else(|| other("a column of another type"))?;
        let events = strings(&batch, 5)?;
        for i in 0..batch.num_rows() {
            if users.value(i) == user_id
                && seqs.value(i) > after_seq
                && (heart_rate || !hr.value(i))
            {
                out.push((
                    seqs.value(i),
                    ids.value(i).to_string(),
                    events.value(i).to_string(),
                ));
            }
        }
    }
    out.sort_by_key(|(seq, _, _)| *seq);
    Ok(out)
}

/// What each account has in the file, read from its first two columns
/// only: how the index is rebuilt for a file it lacks.
pub fn read_spans(path: &Path) -> io::Result<Vec<Span>> {
    let builder = ParquetRecordBatchReaderBuilder::try_new(File::open(path)?).map_err(other)?;
    let mask = ProjectionMask::roots(builder.parquet_schema(), [0, 1]);
    let reader = builder.with_projection(mask).build().map_err(other)?;
    let mut rows = Vec::new();
    for batch in reader {
        let batch = batch.map_err(other)?;
        let (users, seqs) = (strings(&batch, 0)?, ints(&batch, 1)?);
        for i in 0..batch.num_rows() {
            rows.push(Row {
                user_id: users.value(i).to_string(),
                seq: seqs.value(i),
                id: String::new(),
                at: 0,
                heart_rate: false,
                event: String::new(),
            });
        }
    }
    Ok(spans(&rows))
}

/// The event files in `dir`, oldest first (their names sort by when they
/// were written); a temporary one a crash left is removed.
pub fn list(dir: &Path) -> io::Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    for entry in std::fs::read_dir(dir)? {
        let path = entry?.path();
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or_default();
        if name.ends_with(".parquet.tmp") {
            std::fs::remove_file(&path)?;
        } else if name.ends_with(".parquet") {
            files.push(path);
        }
    }
    files.sort();
    Ok(files)
}
