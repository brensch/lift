use super::*;
use crate::db::codec::{decode_exercise_configs, encode_exercise_configs};

impl ServerDb {
    // ── Workout CRUD (real tables) ──

    fn exercise_group_from_row(r: &sqlx::sqlite::SqliteRow) -> ExerciseGroup {
        let configs_blob: Option<Vec<u8>> = r.get("exercise_configs_blob");
        let exercise_configs = configs_blob
            .map(|b| decode_exercise_configs(&b))
            .unwrap_or_default();
        ExerciseGroup {
            id: r.get("id"),
            workout_id: r.get("workout_id"),
            name: r.get("name"),
            sets: r.get("sets"),
            interleave_warmups: r.get::<i32, _>("interleave_warmups") != 0,
            workout_order: r.get("workout_order"),
            exercise_configs,
            rest_config: Some(RestConfig {
                rest_after_success: r.get("rest_success"),
                rest_after_failure: r.get("rest_failure"),
                rest_after_warmup: r.get("rest_warmup"),
                rest_after_last_warmup: r.get("rest_last_warmup"),
            }),
            instruction: r.get("instruction"),
            prescribed_by_regime: r.get::<i32, _>("prescribed_by_regime") != 0,
        }
    }

    /// Insert a new workout with its groups and proposed sets in one transaction.
    pub async fn insert_workout(
        &self,
        user_id: &str,
        workout: &Workout,
        groups: &[ExerciseGroup],
        proposed_sets: &[ProposedSet],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;

        sqlx::query(
            "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(&workout.id)
        .bind(user_id)
        .bind(&workout.name)
        .bind(workout.start_time)
        .bind(workout.end_time)
        .bind(&workout.session_id)
        .execute(&mut *tx)
        .await?;

        for group in groups {
            Self::insert_exercise_group_tx(&mut tx, user_id, group).await?;
        }

        for set in proposed_sets {
            Self::insert_proposed_set_tx(&mut tx, user_id, set).await?;
        }

        // Set active workout pointer
        sqlx::query(
            "INSERT INTO active_workout_current (user_id, workout_id, session_id) VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET workout_id = excluded.workout_id, session_id = excluded.session_id",
        )
        .bind(user_id)
        .bind(&workout.id)
        .bind(&workout.session_id)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
        Ok(())
    }

    async fn insert_exercise_group_tx(
        tx: &mut sqlx::Transaction<'_, Sqlite>,
        user_id: &str,
        group: &ExerciseGroup,
    ) -> DbResult<()> {
        let rest = group.rest_config.as_ref();
        let configs_blob = if group.exercise_configs.is_empty() {
            None
        } else {
            Some(encode_exercise_configs(&group.exercise_configs))
        };
        sqlx::query(
            "INSERT INTO exercise_groups (id, user_id, workout_id, name, sets, interleave_warmups,
             prescribed_by_regime, workout_order, instruction, rest_success, rest_failure,
             rest_warmup, rest_last_warmup, exercise_configs_blob)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&group.id)
        .bind(user_id)
        .bind(&group.workout_id)
        .bind(&group.name)
        .bind(group.sets)
        .bind(group.interleave_warmups as i32)
        .bind(group.prescribed_by_regime as i32)
        .bind(group.workout_order)
        .bind(&group.instruction)
        .bind(rest.map(|r| r.rest_after_success).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_failure).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_warmup).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_last_warmup).unwrap_or(0))
        .bind(configs_blob)
        .execute(&mut **tx)
        .await?;
        Ok(())
    }

    async fn insert_proposed_set_tx(
        tx: &mut sqlx::Transaction<'_, Sqlite>,
        user_id: &str,
        set: &ProposedSet,
    ) -> DbResult<()> {
        let prog_blob = set.progression_hint.as_ref().map(|p| p.encode_to_vec());
        sqlx::query(
            "INSERT INTO proposed_sets (id, user_id, workout_id, exercise_group_id, workout_order,
             exercise, target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure, is_amrap, instruction, progression_blob)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&set.id)
        .bind(user_id)
        .bind(&set.workout_id)
        .bind(&set.exercise_group_id)
        .bind(set.workout_order)
        .bind(set.exercise)
        .bind(set.target_reps)
        .bind(set.target_weight as f64)
        .bind(set.warmup as i32)
        .bind(set.cancelled as i32)
        .bind(set.rest_after_success)
        .bind(set.rest_after_failure)
        .bind(set.is_amrap as i32)
        .bind(&set.instruction)
        .bind(prog_blob)
        .execute(&mut **tx)
        .await?;
        Ok(())
    }

    /// Insert a single completed set.
    pub async fn insert_completed_set(&self, user_id: &str, set: &CompletedSet) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
             actual_reps, actual_weight, started_at, ended_at, rest_until)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&set.id)
        .bind(user_id)
        .bind(&set.workout_id)
        .bind(&set.proposed_set_id)
        .bind(set.actual_reps)
        .bind(set.actual_weight as f64)
        .bind(set.started_at)
        .bind(set.ended_at)
        .bind(set.rest_until)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Update a completed set (for CompleteSet: fills in ended_at, actual_reps/weight, rest_until).
    pub async fn update_completed_set(
        &self,
        set_id: &str,
        actual_reps: i32,
        actual_weight: f32,
        ended_at: i64,
        rest_until: i64,
    ) -> DbResult<()> {
        sqlx::query(
            "UPDATE completed_sets SET actual_reps = ?, actual_weight = ?, ended_at = ?, rest_until = ? WHERE id = ?",
        )
        .bind(actual_reps)
        .bind(actual_weight as f64)
        .bind(ended_at)
        .bind(rest_until)
        .bind(set_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Delete a completed set by id.
    pub async fn delete_completed_set(&self, set_id: &str, workout_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM completed_sets WHERE id = ? AND workout_id = ?")
            .bind(set_id)
            .bind(workout_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// Cancel a proposed set.
    pub async fn cancel_proposed_set(&self, set_id: &str, workout_id: &str) -> DbResult<()> {
        sqlx::query("UPDATE proposed_sets SET cancelled = 1 WHERE id = ? AND workout_id = ?")
            .bind(set_id)
            .bind(workout_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// End a workout: set end_time and remove active pointer.
    pub async fn end_workout(
        &self,
        user_id: &str,
        workout_id: &str,
        end_time: i64,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("UPDATE workouts SET end_time = ? WHERE id = ? AND user_id = ?")
            .bind(end_time)
            .bind(workout_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM active_workout_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }

    /// Update workout session_id (when joining a multiplayer session).
    pub async fn update_workout_session_id(
        &self,
        user_id: &str,
        workout_id: &str,
        session_id: &str,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("UPDATE workouts SET session_id = ? WHERE id = ? AND user_id = ?")
            .bind(session_id)
            .bind(workout_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("UPDATE active_workout_current SET session_id = ? WHERE user_id = ?")
            .bind(session_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }

    /// Persist full workout state from an ActiveWorkout (used after ReplaceExerciseGroupPlan
    /// and other structural mutations that modify groups/sets).
    pub async fn persist_workout_state(
        &self,
        user_id: &str,
        workout: &Workout,
        groups: &[ExerciseGroup],
        proposed_sets: &[ProposedSet],
        completed_sets: &[CompletedSet],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;

        // Update workout row
        sqlx::query("UPDATE workouts SET name = ?, start_time = ?, end_time = ?, session_id = ? WHERE id = ? AND user_id = ?")
            .bind(&workout.name)
            .bind(workout.start_time)
            .bind(workout.end_time)
            .bind(&workout.session_id)
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;

        // Replace groups: delete old, insert new
        sqlx::query("DELETE FROM exercise_groups WHERE workout_id = ? AND user_id = ?")
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        for group in groups {
            Self::insert_exercise_group_tx(&mut tx, user_id, group).await?;
        }

        // Replace proposed sets: delete old, insert new
        sqlx::query("DELETE FROM proposed_sets WHERE workout_id = ? AND user_id = ?")
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        for set in proposed_sets {
            Self::insert_proposed_set_tx(&mut tx, user_id, set).await?;
        }

        // Replace completed sets: delete old, insert new
        sqlx::query("DELETE FROM completed_sets WHERE workout_id = ? AND user_id = ?")
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        for set in completed_sets {
            sqlx::query(
                "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
                 actual_reps, actual_weight, started_at, ended_at, rest_until)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(&set.id)
            .bind(user_id)
            .bind(&set.workout_id)
            .bind(&set.proposed_set_id)
            .bind(set.actual_reps)
            .bind(set.actual_weight as f64)
            .bind(set.started_at)
            .bind(set.ended_at)
            .bind(set.rest_until)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    // ── Workout Reads ──

    /// Get active workout_id for a user.
    pub async fn get_active_workout_id(&self, user_id: &str) -> DbResult<Option<(String, String)>> {
        let row: Option<(String, String)> = sqlx::query_as(
            "SELECT workout_id, session_id FROM active_workout_current WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row)
    }

    /// Load a workout row by id.
    pub async fn get_workout(&self, user_id: &str, workout_id: &str) -> DbResult<Option<Workout>> {
        let row = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id FROM workouts WHERE id = ? AND user_id = ?",
        )
        .bind(workout_id)
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| Workout {
            id: r.get("id"),
            name: r.get("name"),
            start_time: r.get("start_time"),
            end_time: r.get("end_time"),
            session_id: r.get("session_id"),
        }))
    }

    pub async fn list_workouts_started_since(
        &self,
        user_id: &str,
        started_since: i64,
    ) -> DbResult<Vec<Workout>> {
        let rows = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id
             FROM workouts
             WHERE user_id = ? AND start_time >= ?
             ORDER BY start_time ASC, id ASC",
        )
        .bind(user_id)
        .bind(started_since.max(0))
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| Workout {
                id: r.get("id"),
                name: r.get("name"),
                start_time: r.get("start_time"),
                end_time: r.get("end_time"),
                session_id: r.get("session_id"),
            })
            .collect())
    }

    /// Load exercise groups for a workout.
    pub async fn get_exercise_groups(&self, workout_id: &str) -> DbResult<Vec<ExerciseGroup>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, name, sets, interleave_warmups, prescribed_by_regime,
             workout_order, instruction, rest_success, rest_failure, rest_warmup,
             rest_last_warmup, exercise_configs_blob
             FROM exercise_groups WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| Self::exercise_group_from_row(&r))
            .collect())
    }

    pub async fn list_profile_exercise_groups(
        &self,
        user_id: &str,
    ) -> DbResult<Vec<ExerciseGroup>> {
        let rows = sqlx::query(
            "SELECT id,
                    '' AS workout_id,
                    name,
                    sets,
                    interleave_warmups,
                    prescribed_by_regime,
                    profile_order AS workout_order,
                    instruction,
                    rest_success,
                    rest_failure,
                    rest_warmup,
                    rest_last_warmup,
                    exercise_configs_blob
             FROM profile_exercise_groups
             WHERE user_id = ?
             ORDER BY profile_order ASC, updated_at DESC, created_at DESC, name ASC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| Self::exercise_group_from_row(&r))
            .collect())
    }

    pub async fn save_profile_exercise_group(
        &self,
        user_id: &str,
        group: &ExerciseGroup,
    ) -> DbResult<ExerciseGroup> {
        let mut tx = self.write_pool.begin().await?;
        let now = now_unix();
        let group_id = if group.id.is_empty() {
            Uuid::new_v4().to_string()
        } else {
            group.id.clone()
        };
        let rest = group.rest_config.as_ref();
        let configs_blob = if group.exercise_configs.is_empty() {
            None
        } else {
            Some(encode_exercise_configs(&group.exercise_configs))
        };
        let existing_order: Option<i32> = sqlx::query_scalar(
            "SELECT profile_order FROM profile_exercise_groups WHERE user_id = ? AND id = ?",
        )
        .bind(user_id)
        .bind(&group_id)
        .fetch_optional(&mut *tx)
        .await?;
        let next_order: i64 = sqlx::query_scalar(
            "SELECT COALESCE(MAX(profile_order), -1) + 1 FROM profile_exercise_groups WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await?;
        let profile_order =
            existing_order.unwrap_or_else(|| group.workout_order.max(next_order as i32));

        sqlx::query(
            "INSERT INTO profile_exercise_groups (
                id, user_id, name, sets, interleave_warmups, prescribed_by_regime, profile_order,
                instruction, rest_success, rest_failure, rest_warmup, rest_last_warmup,
                exercise_configs_blob, created_at, updated_at
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                sets = excluded.sets,
                interleave_warmups = excluded.interleave_warmups,
                prescribed_by_regime = excluded.prescribed_by_regime,
                instruction = excluded.instruction,
                rest_success = excluded.rest_success,
                rest_failure = excluded.rest_failure,
                rest_warmup = excluded.rest_warmup,
                rest_last_warmup = excluded.rest_last_warmup,
                exercise_configs_blob = excluded.exercise_configs_blob,
                updated_at = excluded.updated_at",
        )
        .bind(&group_id)
        .bind(user_id)
        .bind(&group.name)
        .bind(group.sets)
        .bind(group.interleave_warmups as i32)
        .bind(group.prescribed_by_regime as i32)
        .bind(profile_order)
        .bind(&group.instruction)
        .bind(rest.map(|r| r.rest_after_success).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_failure).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_warmup).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_last_warmup).unwrap_or(0))
        .bind(configs_blob)
        .bind(now)
        .bind(now)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;

        Ok(ExerciseGroup {
            id: group_id,
            workout_id: String::new(),
            name: group.name.clone(),
            sets: group.sets,
            interleave_warmups: group.interleave_warmups,
            workout_order: profile_order,
            exercise_configs: group.exercise_configs.clone(),
            rest_config: group.rest_config.clone(),
            instruction: group.instruction.clone(),
            prescribed_by_regime: group.prescribed_by_regime,
        })
    }

    pub async fn delete_profile_exercise_group(
        &self,
        user_id: &str,
        group_id: &str,
    ) -> DbResult<()> {
        sqlx::query("DELETE FROM profile_exercise_groups WHERE user_id = ? AND id = ?")
            .bind(user_id)
            .bind(group_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// Load proposed sets for a workout.
    pub async fn get_proposed_sets(&self, workout_id: &str) -> DbResult<Vec<ProposedSet>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, exercise_group_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure, is_amrap, instruction, progression_blob
             FROM proposed_sets WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut sets = Vec::with_capacity(rows.len());
        for r in rows {
            let prog_blob: Option<Vec<u8>> = r.get("progression_blob");
            let progression_hint =
                prog_blob.and_then(|b| ProgressionHint::decode(b.as_slice()).ok());
            sets.push(ProposedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                exercise_group_id: r.get("exercise_group_id"),
                workout_order: r.get("workout_order"),
                exercise: r.get("exercise"),
                target_reps: r.get("target_reps"),
                target_weight: r.get::<f64, _>("target_weight") as f32,
                warmup: r.get::<i32, _>("warmup") != 0,
                cancelled: r.get::<i32, _>("cancelled") != 0,
                rest_after_success: r.get("rest_after_success"),
                rest_after_failure: r.get("rest_after_failure"),
                is_amrap: r.get::<i32, _>("is_amrap") != 0,
                instruction: r.get("instruction"),
                progression_hint,
            });
        }
        Ok(sets)
    }

    /// Load completed sets for a workout.
    pub async fn get_completed_sets(&self, workout_id: &str) -> DbResult<Vec<CompletedSet>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight,
             started_at, ended_at, rest_until
             FROM completed_sets WHERE workout_id = ? ORDER BY started_at",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut sets = Vec::with_capacity(rows.len());
        for r in rows {
            sets.push(CompletedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                proposed_set_id: r.get("proposed_set_id"),
                actual_reps: r.get("actual_reps"),
                actual_weight: r.get::<f64, _>("actual_weight") as f32,
                started_at: r.get("started_at"),
                ended_at: r.get("ended_at"),
                rest_until: r.get("rest_until"),
            });
        }
        Ok(sets)
    }

    /// Load full workout response from real tables.
    pub async fn load_workout_full(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> DbResult<Option<GetWorkoutResponse>> {
        let workout = match self.get_workout(user_id, workout_id).await? {
            Some(w) => w,
            None => return Ok(None),
        };
        let exercise_groups = self.get_exercise_groups(workout_id).await?;
        let proposed_sets = self.get_proposed_sets(workout_id).await?;
        let completed_sets = self.get_completed_sets(workout_id).await?;

        use crate::progress::compute_next_up_set;
        use crate::workout::{
            active_proposed_sets, workout_plan_change_stats_from_sets,
            workout_state_snapshot_from_state,
        };

        let now = now_unix();
        let active_proposed = active_proposed_sets(&proposed_sets);
        let next_up_set = compute_next_up_set(&active_proposed, &completed_sets);
        let state_snapshot = Some(workout_state_snapshot_from_state(
            &proposed_sets,
            &completed_sets,
            now,
        ));
        let plan_change_stats = Some(workout_plan_change_stats_from_sets(&proposed_sets));

        Ok(Some(GetWorkoutResponse {
            workout: Some(workout),
            exercise_groups,
            proposed_sets: active_proposed,
            completed_sets,
            next_up_set,
            plan_change_stats,
            state_snapshot,
        }))
    }

    /// Get a proposed set by id (for StartSet to look up target values).
    pub async fn get_proposed_set(&self, set_id: &str) -> DbResult<Option<ProposedSet>> {
        let row = sqlx::query(
            "SELECT id, workout_id, exercise_group_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure, is_amrap, instruction, progression_blob
             FROM proposed_sets WHERE id = ?",
        )
        .bind(set_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| {
            let prog_blob: Option<Vec<u8>> = r.get("progression_blob");
            let progression_hint =
                prog_blob.and_then(|b| ProgressionHint::decode(b.as_slice()).ok());
            ProposedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                exercise_group_id: r.get("exercise_group_id"),
                workout_order: r.get("workout_order"),
                exercise: r.get("exercise"),
                target_reps: r.get("target_reps"),
                target_weight: r.get::<f64, _>("target_weight") as f32,
                warmup: r.get::<i32, _>("warmup") != 0,
                cancelled: r.get::<i32, _>("cancelled") != 0,
                rest_after_success: r.get("rest_after_success"),
                rest_after_failure: r.get("rest_after_failure"),
                is_amrap: r.get::<i32, _>("is_amrap") != 0,
                instruction: r.get("instruction"),
                progression_hint,
            }
        }))
    }

    /// Find the in-progress completed set for a proposed_set_id.
    pub async fn find_in_progress_completed_set(
        &self,
        workout_id: &str,
        proposed_set_id: &str,
    ) -> DbResult<Option<CompletedSet>> {
        let row = sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight,
             started_at, ended_at, rest_until
             FROM completed_sets WHERE workout_id = ? AND proposed_set_id = ? AND ended_at = 0",
        )
        .bind(workout_id)
        .bind(proposed_set_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| CompletedSet {
            id: r.get("id"),
            workout_id: r.get("workout_id"),
            proposed_set_id: r.get("proposed_set_id"),
            actual_reps: r.get("actual_reps"),
            actual_weight: r.get::<f64, _>("actual_weight") as f32,
            started_at: r.get("started_at"),
            ended_at: r.get("ended_at"),
            rest_until: r.get("rest_until"),
        }))
    }

    /// List finished workouts for a user.
    pub async fn list_workouts(&self, user_id: &str) -> DbResult<Vec<Workout>> {
        let rows = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id
             FROM workouts WHERE user_id = ? AND end_time > 0 ORDER BY start_time DESC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| Workout {
                id: r.get("id"),
                name: r.get("name"),
                start_time: r.get("start_time"),
                end_time: r.get("end_time"),
                session_id: r.get("session_id"),
            })
            .collect())
    }
}
