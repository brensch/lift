//! Training model v2 persistence: blocks → sets → append-only entries, plus the
//! append-only progression ledger.
//!
//! The design goal is that **every edit is a row-level operation** — an UPDATE
//! of one set, an INSERT of one entry — never a load-the-whole-workout,
//! delete-everything, reinsert-everything cycle. That is what makes editing O(1)
//! in the size of the workout instead of O(sets), and it is the performance win
//! over the v1 `persist_workout_state` path.

use super::{DbResult, ServerDb};
use sqlx::Row;
use uuid::Uuid;

// ── Row types (thin; the handler maps these to proto) ──

#[derive(Clone, Debug)]
pub struct TrainingWorkoutRow {
    pub id: String,
    pub name: String,
    pub start_time: i64,
    pub end_time: i64,
    pub session_id: String,
    pub active_set_id: String,
    pub active_started_at: i64,
    pub from_program: bool,
    pub closed_at: i64,
}

#[derive(Clone, Debug)]
pub struct TrainingBlockRow {
    pub id: String,
    pub ord: i32,
    pub name: String,
    pub interleave_warmups: bool,
    pub rest_success: i32,
    pub rest_failure: i32,
    pub rest_warmup: i32,
    pub rest_last_warmup: i32,
}

#[derive(Clone, Debug)]
pub struct TrainingSetRow {
    pub id: String,
    pub block_id: String,
    pub ord: i32,
    pub exercise: i32,
    pub role: i32,
    pub proposed_weight: f32,
    pub proposed_reps: i32,
    pub proposed_duration_s: i32,
    pub proposed_distance_m: f32,
    pub target_weight: f32,
    pub target_reps: i32,
    pub target_duration_s: i32,
    pub target_distance_m: f32,
    pub is_amrap: bool,
    pub instruction: String,
    pub skipped: bool,
    pub counts_toward_program: bool,
    pub slot_key: String,
}

/// The folded current performance for a set (newest non-tombstoned entry).
#[derive(Clone, Debug)]
pub struct TrainingEntryRow {
    pub set_id: String,
    pub weight: f32,
    pub reps: i32,
    pub duration_s: i32,
    pub distance_m: f32,
    pub performed_at: i64,
    /// Transaction time this row was written. Not surfaced in the view; kept for
    /// audit and future ledger re-folding.
    #[allow(dead_code)]
    pub recorded_at: i64,
}

#[derive(Clone, Debug)]
pub struct ProgressionRow {
    pub workout_id: String,
    pub at: i64,
    pub changes_blob: Vec<u8>,
}

/// A weight/reps (or timed/distance) measurement, shared by targets and entries.
#[derive(Clone, Copy, Default)]
pub struct MeasureVals {
    pub weight: f32,
    pub reps: i32,
    pub duration_s: i32,
    pub distance_m: f32,
}

/// An entry to append (log / correction / tombstone).
pub struct NewEntry {
    pub set_id: String,
    pub vals: MeasureVals,
    pub performed_at: i64,
    pub recorded_at: i64,
    pub tombstone: bool,
}

/// A set to insert when planning a block.
pub struct NewSet {
    pub id: String,
    pub block_id: String,
    pub ord: i32,
    pub exercise: i32,
    pub role: i32,
    pub weight: f32,
    pub reps: i32,
    pub duration_s: i32,
    pub distance_m: f32,
    pub is_amrap: bool,
    pub instruction: String,
    pub counts_toward_program: bool,
    pub slot_key: String,
}

pub struct NewBlock {
    pub id: String,
    pub ord: i32,
    pub name: String,
    pub interleave_warmups: bool,
    pub rest_success: i32,
    pub rest_failure: i32,
    pub rest_warmup: i32,
    pub rest_last_warmup: i32,
    pub sets: Vec<NewSet>,
}

/// A progression ledger event to append at CloseWorkout.
pub struct ProgressionWrite<'a> {
    pub workout_id: &'a str,
    pub at: i64,
    pub reason: &'a str,
    pub state_before: &'a [u8],
    pub state_after: &'a [u8],
    pub changes_blob: &'a [u8],
    pub latest_response_blob: &'a [u8],
}

/// A workout to create, minus its blocks.
pub struct NewWorkout {
    pub id: String,
    pub name: String,
    pub start_time: i64,
    pub session_id: String,
    pub from_program: bool,
}

impl ServerDb {
    // ── Create ──

    /// Create a workout with its blocks and sets in one transaction. A set's
    /// `proposed` and `target` are both seeded from the plan; entries start empty.
    pub async fn t_create_workout(
        &self,
        user_id: &str,
        workout: &NewWorkout,
        blocks: &[NewBlock],
    ) -> DbResult<()> {
        let workout_id = workout.id.as_str();
        let mut tx = self.write_pool.begin().await?;
        sqlx::query(
            "INSERT INTO t_workouts (id, user_id, name, start_time, session_id, from_program)
             VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(workout_id)
        .bind(user_id)
        .bind(&workout.name)
        .bind(workout.start_time)
        .bind(&workout.session_id)
        .bind(workout.from_program as i32)
        .execute(&mut *tx)
        .await?;
        for block in blocks {
            insert_block_tx(&mut tx, user_id, workout_id, block).await?;
            for set in &block.sets {
                insert_set_tx(&mut tx, user_id, workout_id, set).await?;
            }
        }
        tx.commit().await?;
        Ok(())
    }

    /// Append a block (with its sets) to an existing workout.
    pub async fn t_add_block(
        &self,
        user_id: &str,
        workout_id: &str,
        block: &NewBlock,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        insert_block_tx(&mut tx, user_id, workout_id, block).await?;
        for set in &block.sets {
            insert_set_tx(&mut tx, user_id, workout_id, set).await?;
        }
        tx.commit().await?;
        Ok(())
    }

    // ── Row-level set edits (the O(1) operations) ──

    pub async fn t_edit_target(
        &self,
        user_id: &str,
        set_id: &str,
        vals: MeasureVals,
    ) -> DbResult<()> {
        sqlx::query(
            "UPDATE t_sets SET target_weight = ?, target_reps = ?, target_duration_s = ?,
             target_distance_m = ? WHERE id = ? AND user_id = ?",
        )
        .bind(vals.weight)
        .bind(vals.reps)
        .bind(vals.duration_s)
        .bind(vals.distance_m)
        .bind(set_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn t_add_set(
        &self,
        user_id: &str,
        workout_id: &str,
        set: &NewSet,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        insert_set_tx(&mut tx, user_id, workout_id, set).await?;
        tx.commit().await?;
        Ok(())
    }

    pub async fn t_remove_set(&self, user_id: &str, set_id: &str) -> DbResult<()> {
        sqlx::query("UPDATE t_sets SET removed = 1 WHERE id = ? AND user_id = ?")
            .bind(set_id)
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn t_skip_set(&self, user_id: &str, set_id: &str, skipped: bool) -> DbResult<()> {
        sqlx::query("UPDATE t_sets SET skipped = ? WHERE id = ? AND user_id = ?")
            .bind(skipped as i32)
            .bind(set_id)
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn t_set_active(
        &self,
        user_id: &str,
        workout_id: &str,
        set_id: &str,
        at: i64,
    ) -> DbResult<()> {
        sqlx::query(
            "UPDATE t_workouts SET active_set_id = ?, active_started_at = ?
             WHERE id = ? AND user_id = ?",
        )
        .bind(set_id)
        .bind(at)
        .bind(workout_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Append an entry (log / correction / tombstone). Also clears the active
    /// pointer if this set was the active one. Append-only — never updates or
    /// deletes a prior entry row.
    pub async fn t_append_entry(
        &self,
        user_id: &str,
        workout_id: &str,
        entry: &NewEntry,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        sqlx::query(
            "INSERT INTO t_entries (entry_id, set_id, workout_id, user_id, weight, reps,
             duration_s, distance_m, performed_at, recorded_at, tombstone)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(Uuid::new_v4().to_string())
        .bind(&entry.set_id)
        .bind(workout_id)
        .bind(user_id)
        .bind(entry.vals.weight)
        .bind(entry.vals.reps)
        .bind(entry.vals.duration_s)
        .bind(entry.vals.distance_m)
        .bind(entry.performed_at)
        .bind(entry.recorded_at)
        .bind(entry.tombstone as i32)
        .execute(&mut *tx)
        .await?;
        // If we just logged the active set, clear the pointer.
        sqlx::query(
            "UPDATE t_workouts SET active_set_id = '', active_started_at = 0
             WHERE id = ? AND user_id = ? AND active_set_id = ?",
        )
        .bind(workout_id)
        .bind(user_id)
        .bind(&entry.set_id)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(())
    }

    pub async fn t_reorder_blocks(
        &self,
        user_id: &str,
        workout_id: &str,
        block_ids: &[String],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for (ord, block_id) in block_ids.iter().enumerate() {
            sqlx::query(
                "UPDATE t_blocks SET ord = ? WHERE id = ? AND workout_id = ? AND user_id = ?",
            )
            .bind(ord as i32)
            .bind(block_id)
            .bind(workout_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    pub async fn t_end_workout(
        &self,
        user_id: &str,
        workout_id: &str,
        ended_at: i64,
    ) -> DbResult<()> {
        sqlx::query("UPDATE t_workouts SET end_time = ? WHERE id = ? AND user_id = ?")
            .bind(ended_at)
            .bind(workout_id)
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    // ── Reads (the fold) ──

    pub async fn t_get_workout(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> DbResult<Option<TrainingWorkoutRow>> {
        let row = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id, active_set_id,
             active_started_at, from_program, closed_at
             FROM t_workouts WHERE id = ? AND user_id = ?",
        )
        .bind(workout_id)
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| TrainingWorkoutRow {
            id: r.get("id"),
            name: r.get("name"),
            start_time: r.get("start_time"),
            end_time: r.get("end_time"),
            session_id: r.get("session_id"),
            active_set_id: r.get("active_set_id"),
            active_started_at: r.get("active_started_at"),
            from_program: r.get::<i32, _>("from_program") != 0,
            closed_at: r.get("closed_at"),
        }))
    }

    pub async fn t_get_blocks(&self, workout_id: &str) -> DbResult<Vec<TrainingBlockRow>> {
        let rows = sqlx::query(
            "SELECT id, ord, name, interleave_warmups, rest_success, rest_failure,
             rest_warmup, rest_last_warmup FROM t_blocks WHERE workout_id = ? ORDER BY ord ASC",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| TrainingBlockRow {
                id: r.get("id"),
                ord: r.get("ord"),
                name: r.get("name"),
                interleave_warmups: r.get::<i32, _>("interleave_warmups") != 0,
                rest_success: r.get("rest_success"),
                rest_failure: r.get("rest_failure"),
                rest_warmup: r.get("rest_warmup"),
                rest_last_warmup: r.get("rest_last_warmup"),
            })
            .collect())
    }

    pub async fn t_get_sets(&self, workout_id: &str) -> DbResult<Vec<TrainingSetRow>> {
        let rows = sqlx::query(
            "SELECT id, block_id, ord, exercise, role, proposed_weight, proposed_reps,
             proposed_duration_s, proposed_distance_m, target_weight, target_reps,
             target_duration_s, target_distance_m, is_amrap, instruction, skipped,
             counts_toward_program, slot_key
             FROM t_sets WHERE workout_id = ? AND removed = 0 ORDER BY ord ASC",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows.into_iter().map(set_row_from).collect())
    }

    /// The folded current entry per set: the newest row per `set_id`, kept only
    /// if it is not a tombstone. Ordered by `(recorded_at, rowid)` so a later
    /// append always wins — rowid breaks same-second ties, since `recorded_at`
    /// is second-granularity and a log + its correction/tombstone can share it.
    /// One query for the whole workout.
    pub async fn t_get_entries(&self, workout_id: &str) -> DbResult<Vec<TrainingEntryRow>> {
        let rows = sqlx::query(
            "SELECT set_id, weight, reps, duration_s, distance_m, performed_at, recorded_at, tombstone
             FROM (
                 SELECT *, ROW_NUMBER() OVER (
                     PARTITION BY set_id ORDER BY recorded_at DESC, rowid DESC
                 ) AS rn
                 FROM t_entries WHERE workout_id = ?
             )
             WHERE rn = 1",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .filter(|r| r.get::<i32, _>("tombstone") == 0)
            .map(|r| TrainingEntryRow {
                set_id: r.get("set_id"),
                weight: r.get::<f64, _>("weight") as f32,
                reps: r.get("reps"),
                duration_s: r.get("duration_s"),
                distance_m: r.get::<f64, _>("distance_m") as f32,
                performed_at: r.get("performed_at"),
                recorded_at: r.get("recorded_at"),
            })
            .collect())
    }

    // ── Progression ledger ──

    /// Append a progression event and refresh the `_latest` snapshot in one
    /// transaction. Idempotent: if an event for (user, workout) exists, this is a
    /// no-op and returns false.
    pub async fn t_apply_progression(
        &self,
        user_id: &str,
        event: &ProgressionWrite<'_>,
    ) -> DbResult<bool> {
        let ProgressionWrite {
            workout_id,
            at,
            reason,
            state_before,
            state_after,
            changes_blob,
            latest_response_blob,
        } = *event;
        let mut tx = self.write_pool.begin().await?;
        let claim = sqlx::query(
            "INSERT OR IGNORE INTO t_progression
             (id, user_id, workout_id, at, reason, state_before, state_after, changes_blob)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(Uuid::new_v4().to_string())
        .bind(user_id)
        .bind(workout_id)
        .bind(at)
        .bind(reason)
        .bind(state_before)
        .bind(state_after)
        .bind(changes_blob)
        .execute(&mut *tx)
        .await?;
        if claim.rows_affected() == 0 {
            tx.rollback().await?;
            return Ok(false);
        }
        // Refresh the fast-read snapshot the scheduler uses (shared with v1).
        sqlx::query(
            "INSERT INTO training_program_state_latest (user_id, response_blob, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET response_blob = excluded.response_blob,
             updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(latest_response_blob)
        .bind(at)
        .execute(&mut *tx)
        .await?;
        sqlx::query("UPDATE t_workouts SET closed_at = ? WHERE id = ? AND user_id = ?")
            .bind(at)
            .bind(workout_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(true)
    }

    pub async fn t_progression_history(
        &self,
        user_id: &str,
        limit: i64,
    ) -> DbResult<Vec<ProgressionRow>> {
        let rows = sqlx::query(
            "SELECT workout_id, at, changes_blob
             FROM t_progression WHERE user_id = ? ORDER BY at DESC LIMIT ?",
        )
        .bind(user_id)
        .bind(limit.max(0))
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| ProgressionRow {
                workout_id: r.get("workout_id"),
                at: r.get("at"),
                changes_blob: r.get::<Option<Vec<u8>>, _>("changes_blob").unwrap_or_default(),
            })
            .collect())
    }
}

fn set_row_from(r: sqlx::sqlite::SqliteRow) -> TrainingSetRow {
    TrainingSetRow {
        id: r.get("id"),
        block_id: r.get("block_id"),
        ord: r.get("ord"),
        exercise: r.get("exercise"),
        role: r.get("role"),
        proposed_weight: r.get::<f64, _>("proposed_weight") as f32,
        proposed_reps: r.get("proposed_reps"),
        proposed_duration_s: r.get("proposed_duration_s"),
        proposed_distance_m: r.get::<f64, _>("proposed_distance_m") as f32,
        target_weight: r.get::<f64, _>("target_weight") as f32,
        target_reps: r.get("target_reps"),
        target_duration_s: r.get("target_duration_s"),
        target_distance_m: r.get::<f64, _>("target_distance_m") as f32,
        is_amrap: r.get::<i32, _>("is_amrap") != 0,
        instruction: r.get("instruction"),
        skipped: r.get::<i32, _>("skipped") != 0,
        counts_toward_program: r.get::<i32, _>("counts_toward_program") != 0,
        slot_key: r.get("slot_key"),
    }
}

async fn insert_block_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    user_id: &str,
    workout_id: &str,
    block: &NewBlock,
) -> DbResult<()> {
    sqlx::query(
        "INSERT INTO t_blocks (id, workout_id, user_id, ord, name, interleave_warmups,
         rest_success, rest_failure, rest_warmup, rest_last_warmup)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&block.id)
    .bind(workout_id)
    .bind(user_id)
    .bind(block.ord)
    .bind(&block.name)
    .bind(block.interleave_warmups as i32)
    .bind(block.rest_success)
    .bind(block.rest_failure)
    .bind(block.rest_warmup)
    .bind(block.rest_last_warmup)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

async fn insert_set_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    user_id: &str,
    workout_id: &str,
    set: &NewSet,
) -> DbResult<()> {
    sqlx::query(
        "INSERT INTO t_sets (id, workout_id, block_id, user_id, ord, exercise, role,
         proposed_weight, proposed_reps, proposed_duration_s, proposed_distance_m,
         target_weight, target_reps, target_duration_s, target_distance_m,
         is_amrap, instruction, counts_toward_program, slot_key)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&set.id)
    .bind(workout_id)
    .bind(&set.block_id)
    .bind(user_id)
    .bind(set.ord)
    .bind(set.exercise)
    .bind(set.role)
    .bind(set.weight)
    .bind(set.reps)
    .bind(set.duration_s)
    .bind(set.distance_m)
    .bind(set.weight)
    .bind(set.reps)
    .bind(set.duration_s)
    .bind(set.distance_m)
    .bind(set.is_amrap as i32)
    .bind(&set.instruction)
    .bind(set.counts_toward_program as i32)
    .bind(&set.slot_key)
    .execute(&mut **tx)
    .await?;
    Ok(())
}
