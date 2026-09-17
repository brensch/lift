use super::*;

impl ServerDb {
    // ── Workout CRUD (real tables) ──

    /// Insert a new workout with its proposed sets in one transaction.
    pub async fn insert_workout(
        &self,
        user_id: &str,
        workout: &Workout,
        proposed_sets: &[ProposedSet],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;

        sqlx::query(
            "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id, template_id)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&workout.id)
        .bind(user_id)
        .bind(&workout.name)
        .bind(workout.start_time)
        .bind(workout.end_time)
        .bind(&workout.session_id)
        .bind(&workout.template_id)
        .execute(&mut *tx)
        .await?;

        for set in proposed_sets {
            Self::insert_proposed_set_tx(&mut tx, user_id, set).await?;
        }

        // Set active workout pointer
        sqlx::query(
            "INSERT INTO active_workout_current (user_id, workout_id) VALUES (?, ?)
             ON CONFLICT(user_id) DO UPDATE SET workout_id = excluded.workout_id",
        )
        .bind(user_id)
        .bind(&workout.id)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
        Ok(())
    }

    async fn insert_proposed_set_tx(
        tx: &mut sqlx::Transaction<'_, Sqlite>,
        user_id: &str,
        set: &ProposedSet,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order,
             exercise, target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&set.id)
        .bind(user_id)
        .bind(&set.workout_id)
        .bind(set.workout_order)
        .bind(set.exercise)
        .bind(set.target_reps)
        .bind(set.target_weight as f64)
        .bind(set.warmup as i32)
        .bind(set.cancelled as i32)
        .bind(set.rest_after_success)
        .bind(set.rest_after_failure)
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

    /// Delete a completed set by id. User-scoped.
    pub async fn delete_completed_set(
        &self,
        user_id: &str,
        set_id: &str,
        workout_id: &str,
    ) -> DbResult<()> {
        sqlx::query(
            "DELETE FROM completed_sets WHERE id = ? AND workout_id = ? AND user_id = ?",
        )
        .bind(set_id)
        .bind(workout_id)
        .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// Cancel a proposed set. User-scoped.
    pub async fn cancel_proposed_set(
        &self,
        user_id: &str,
        set_id: &str,
        workout_id: &str,
    ) -> DbResult<()> {
        sqlx::query(
            "UPDATE proposed_sets SET cancelled = 1 WHERE id = ? AND workout_id = ? AND user_id = ?",
        )
        .bind(set_id)
        .bind(workout_id)
        .bind(user_id)
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

    /// Stamp a session_id onto an existing workout row (used when the user joins a group
    /// mid-workout — we backfill the historical marker so the workout remembers which
    /// session it was attached to).
    pub async fn update_workout_session_id(
        &self,
        user_id: &str,
        workout_id: &str,
        session_id: &str,
    ) -> DbResult<()> {
        sqlx::query("UPDATE workouts SET session_id = ? WHERE id = ? AND user_id = ?")
            .bind(session_id)
            .bind(workout_id)
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// Persist full workout state from an ActiveWorkout (used after the
    /// plan-shaping mutations).
    pub async fn persist_workout_state(
        &self,
        user_id: &str,
        workout: &Workout,
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

    /// Get the user's active workout id, if any.
    pub async fn get_active_workout_id(&self, user_id: &str) -> DbResult<Option<String>> {
        let row: Option<String> =
            sqlx::query_scalar("SELECT workout_id FROM active_workout_current WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        Ok(row)
    }

    /// Load a workout row by id.
    pub async fn get_workout(&self, user_id: &str, workout_id: &str) -> DbResult<Option<Workout>> {
        let row = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id, template_id
             FROM workouts WHERE id = ? AND user_id = ?",
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
            template_id: r.get("template_id"),
        }))
    }

    /// The `limit` most recent workouts, returned oldest-first so callers can iterate chronologically. Uses the `idx_workouts_user_time` index. Bounds the scheduler's
    /// history load, which would otherwise grow without limit as a user's
    /// training history accumulates.
    pub async fn list_recent_workouts(
        &self,
        user_id: &str,
        limit: i64,
    ) -> DbResult<Vec<Workout>> {
        let rows = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id, template_id
             FROM workouts
             WHERE user_id = ?
             ORDER BY start_time DESC, id DESC
             LIMIT ?",
        )
        .bind(user_id)
        .bind(limit.max(0))
        .fetch_all(&self.read_pool)
        .await?;
        let mut workouts: Vec<Workout> = rows
            .into_iter()
            .map(|r| Workout {
                id: r.get("id"),
                name: r.get("name"),
                start_time: r.get("start_time"),
                end_time: r.get("end_time"),
                session_id: r.get("session_id"),
                template_id: r.get("template_id"),
            })
            .collect();
        workouts.reverse();
        Ok(workouts)
    }

    /// Load proposed sets for a workout.
    pub async fn get_proposed_sets(&self, workout_id: &str) -> DbResult<Vec<ProposedSet>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure
             FROM proposed_sets WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut sets = Vec::with_capacity(rows.len());
        for r in rows {
            sets.push(ProposedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                workout_order: r.get("workout_order"),
                exercise: r.get("exercise"),
                target_reps: r.get("target_reps"),
                target_weight: r.get::<f64, _>("target_weight") as f32,
                warmup: r.get::<i32, _>("warmup") != 0,
                cancelled: r.get::<i32, _>("cancelled") != 0,
                rest_after_success: r.get("rest_after_success"),
                rest_after_failure: r.get("rest_after_failure"),
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
        let summary = Some(crate::progress::compute_workout_summary(
            &workout,
            &proposed_sets,
            &completed_sets,
        ));

        // The FULL set list, cancelled rows included. Cancelled sets are
        // load-bearing state (they mark a bailed exercise for progression),
        // so a load→persist round trip must not shed them; the GetWorkout
        // handler filters to visible sets at the RPC boundary instead.
        Ok(Some(GetWorkoutResponse {
            workout: Some(workout),
            proposed_sets,
            completed_sets,
            next_up_set,
            plan_change_stats,
            state_snapshot,
            user_messages: Vec::new(),
            summary,
        }))
    }

    /// Get a proposed set by id (for StartSet to look up target values).
    /// User-scoped: a set id from someone else's workout resolves to None.
    pub async fn get_proposed_set(
        &self,
        user_id: &str,
        set_id: &str,
    ) -> DbResult<Option<ProposedSet>> {
        let row = sqlx::query(
            "SELECT id, workout_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure
             FROM proposed_sets WHERE id = ? AND user_id = ?",
        )
        .bind(set_id)
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| {
            ProposedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                workout_order: r.get("workout_order"),
                exercise: r.get("exercise"),
                target_reps: r.get("target_reps"),
                target_weight: r.get::<f64, _>("target_weight") as f32,
                warmup: r.get::<i32, _>("warmup") != 0,
                cancelled: r.get::<i32, _>("cancelled") != 0,
                rest_after_success: r.get("rest_after_success"),
                rest_after_failure: r.get("rest_after_failure"),
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
    /// Every finished workout with its proposed + completed sets loaded, newest
    /// first. Powers the server-side summary/progress rollups so the app never
    /// fans out getWorkout per row.
    pub async fn list_finished_workouts_full(
        &self,
        user_id: &str,
    ) -> DbResult<Vec<(Workout, Vec<ProposedSet>, Vec<CompletedSet>)>> {
        let workouts = self.list_workouts(user_id).await?;
        let mut out = Vec::with_capacity(workouts.len());
        for w in workouts {
            let proposed = self.get_proposed_sets(&w.id).await?;
            let completed = self.get_completed_sets(&w.id).await?;
            out.push((w, proposed, completed));
        }
        Ok(out)
    }

    pub async fn list_workouts(&self, user_id: &str) -> DbResult<Vec<Workout>> {
        let rows = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id, template_id
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
                template_id: r.get("template_id"),
            })
            .collect())
    }
}

// ── Templates & Trackers ─────────────────────────────────────────────────────

impl ServerDb {
    pub async fn list_templates(&self, user_id: &str) -> DbResult<Vec<WorkoutTemplate>> {
        let rows = sqlx::query(
            "SELECT template_blob FROM workout_templates
             WHERE user_id = ? ORDER BY template_order, created_at",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut out = Vec::with_capacity(rows.len());
        for row in rows {
            let blob: Vec<u8> = row.get("template_blob");
            out.push(WorkoutTemplate::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    pub async fn get_template(
        &self,
        user_id: &str,
        template_id: &str,
    ) -> DbResult<Option<WorkoutTemplate>> {
        let blob: Option<Vec<u8>> = sqlx::query_scalar(
            "SELECT template_blob FROM workout_templates WHERE user_id = ? AND id = ?",
        )
        .bind(user_id)
        .bind(template_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(match blob {
            Some(blob) => Some(WorkoutTemplate::decode(blob.as_slice())?),
            None => None,
        })
    }

    /// Create (empty id) or update a template. Returns the stored value.
    pub async fn save_template(
        &self,
        user_id: &str,
        template: &WorkoutTemplate,
    ) -> DbResult<WorkoutTemplate> {
        let now = now_unix();
        let mut stored = template.clone();
        if stored.id.is_empty() {
            stored.id = Uuid::new_v4().to_string();
            stored.created_at = now;
            let next_order: i64 = sqlx::query_scalar(
                "SELECT COALESCE(MAX(template_order), -1) + 1 FROM workout_templates WHERE user_id = ?",
            )
            .bind(user_id)
            .fetch_one(&self.write_pool)
            .await?;
            stored.order = next_order as i32;
        } else if let Some(existing) = self.get_template(user_id, &stored.id).await? {
            stored.created_at = existing.created_at;
            stored.order = existing.order;
        } else {
            stored.created_at = now;
        }
        stored.updated_at = now;

        sqlx::query(
            "INSERT INTO workout_templates
             (id, user_id, name, template_order, template_blob, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
               name = excluded.name,
               template_order = excluded.template_order,
               template_blob = excluded.template_blob,
               updated_at = excluded.updated_at",
        )
        .bind(&stored.id)
        .bind(user_id)
        .bind(&stored.name)
        .bind(stored.order)
        .bind(stored.encode_to_vec())
        .bind(stored.created_at)
        .bind(stored.updated_at)
        .execute(&self.write_pool)
        .await?;
        Ok(stored)
    }

    pub async fn delete_template(&self, user_id: &str, template_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM workout_templates WHERE user_id = ? AND id = ?")
            .bind(user_id)
            .bind(template_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn reorder_templates(&self, user_id: &str, template_ids: &[String]) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for (order, template_id) in template_ids.iter().enumerate() {
            // Keep the blob's order in sync with the column — the blob is
            // what list_templates returns.
            let blob: Option<Vec<u8>> = sqlx::query_scalar(
                "SELECT template_blob FROM workout_templates WHERE user_id = ? AND id = ?",
            )
            .bind(user_id)
            .bind(template_id)
            .fetch_optional(&mut *tx)
            .await?;
            let Some(blob) = blob else { continue };
            let mut template = WorkoutTemplate::decode(blob.as_slice())?;
            template.order = order as i32;
            sqlx::query(
                "UPDATE workout_templates SET template_order = ?, template_blob = ?
                 WHERE user_id = ? AND id = ?",
            )
            .bind(order as i32)
            .bind(template.encode_to_vec())
            .bind(user_id)
            .bind(template_id)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    /// When each template was last started: template_id → max start_time.
    /// Feeds the suggestion's tie-break.
    pub async fn template_last_started(
        &self,
        user_id: &str,
    ) -> DbResult<std::collections::HashMap<String, i64>> {
        let rows: Vec<(String, i64)> = sqlx::query_as(
            "SELECT template_id, MAX(start_time) FROM workouts
             WHERE user_id = ? AND template_id != '' GROUP BY template_id",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows.into_iter().collect())
    }

    pub async fn get_tracker_states(
        &self,
        user_id: &str,
    ) -> DbResult<std::collections::HashMap<i32, crate::exercise_progress::TrackerState>> {
        let rows = sqlx::query(
            "SELECT exercise, working_weight, current_reps, consecutive_misses,
             last_performed_at, override_sets, override_rep_low, override_rep_high
             FROM exercise_trackers WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| {
                (
                    r.get::<i32, _>("exercise"),
                    crate::exercise_progress::TrackerState {
                        working_weight: r.get::<f64, _>("working_weight") as f32,
                        current_reps: r.get("current_reps"),
                        consecutive_misses: r.get("consecutive_misses"),
                        last_performed_at: r.get("last_performed_at"),
                        override_sets: r.get("override_sets"),
                        override_rep_low: r.get("override_rep_low"),
                        override_rep_high: r.get("override_rep_high"),
                    },
                )
            })
            .collect())
    }

    pub async fn upsert_tracker_state(
        &self,
        user_id: &str,
        exercise: i32,
        state: &crate::exercise_progress::TrackerState,
        source: &str,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO exercise_trackers
             (user_id, exercise, working_weight, current_reps, consecutive_misses,
              last_performed_at, override_sets, override_rep_low, override_rep_high,
              updated_at, source)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(user_id, exercise) DO UPDATE SET
               working_weight = excluded.working_weight,
               current_reps = excluded.current_reps,
               consecutive_misses = excluded.consecutive_misses,
               last_performed_at = excluded.last_performed_at,
               override_sets = excluded.override_sets,
               override_rep_low = excluded.override_rep_low,
               override_rep_high = excluded.override_rep_high,
               updated_at = excluded.updated_at,
               source = excluded.source",
        )
        .bind(user_id)
        .bind(exercise)
        .bind(state.working_weight as f64)
        .bind(state.current_reps)
        .bind(state.consecutive_misses)
        .bind(state.last_performed_at)
        .bind(state.override_sets)
        .bind(state.override_rep_low)
        .bind(state.override_rep_high)
        .bind(now_unix())
        .bind(source)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }
}
