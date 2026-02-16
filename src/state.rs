use dashmap::DashMap;
use lift::workout::v1::{
    CompletedSet, ExerciseGroup, ProposedSet, User, Workout,
};
use std::collections::HashSet;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::db::CentralDb;

pub struct ActiveWorkout {
    pub workout: Workout,
    pub exercise_groups: Vec<ExerciseGroup>,
    pub proposed_sets: Vec<ProposedSet>,
    pub completed_sets: Vec<CompletedSet>,
    pub dirty: AtomicBool,
}

impl ActiveWorkout {
    pub fn new(
        workout: Workout,
        exercise_groups: Vec<ExerciseGroup>,
        proposed_sets: Vec<ProposedSet>,
        completed_sets: Vec<CompletedSet>,
    ) -> Self {
        Self {
            workout,
            exercise_groups,
            proposed_sets,
            completed_sets,
            dirty: AtomicBool::new(false),
        }
    }

    pub fn mark_dirty(&self) {
        self.dirty.store(true, Ordering::Relaxed);
    }

    pub fn clear_dirty(&self) -> bool {
        self.dirty.swap(false, Ordering::Relaxed)
    }

    /// Reindex proposed_sets workout_order based on exercise_group workout_order
    pub fn reindex_sets(&mut self) {
        // Build group order lookup
        let group_order: std::collections::HashMap<String, i32> = self
            .exercise_groups
            .iter()
            .map(|g| (g.id.clone(), g.workout_order))
            .collect();

        self.proposed_sets.sort_by(|a, b| {
            let a_group = group_order.get(&a.exercise_group_id).copied().unwrap_or(i32::MAX);
            let b_group = group_order.get(&b.exercise_group_id).copied().unwrap_or(i32::MAX);
            a_group.cmp(&b_group).then(a.workout_order.cmp(&b.workout_order))
        });

        for (idx, set) in self.proposed_sets.iter_mut().enumerate() {
            set.workout_order = idx as i32;
        }
    }
}

pub struct AppState {
    /// Active workouts: user_id -> full workout state
    pub workouts: DashMap<String, ActiveWorkout>,
    /// Session membership: session_id -> set of user_ids
    pub sessions: DashMap<String, HashSet<String>>,
    /// Reverse lookup: user_id -> session_id
    pub user_sessions: DashMap<String, String>,
    /// Cached user info: user_id -> User proto
    pub users: DashMap<String, User>,
    /// Users we've already checked for crash recovery (avoids repeated DB lookups)
    checked_users: DashMap<String, ()>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            workouts: DashMap::new(),
            sessions: DashMap::new(),
            user_sessions: DashMap::new(),
            users: DashMap::new(),
            checked_users: DashMap::new(),
        }
    }

    /// Lazy crash recovery: on first access per user, check their UserDb for
    /// an active workout left over from a crash. No-op if already checked.
    pub async fn try_recover_user(&self, central_db: &CentralDb, user_id: &str) {
        // Fast path: already checked
        if self.checked_users.contains_key(user_id) {
            return;
        }
        self.checked_users.insert(user_id.to_string(), ());

        // Already have an active workout in memory — nothing to recover
        if self.workouts.contains_key(user_id) {
            return;
        }

        // Check CentralDb for un-ended workout
        let active = match central_db.get_active_workout(user_id).await {
            Ok(Some(w)) => w,
            _ => return,
        };

        let groups = central_db.get_exercise_groups(user_id, &active.id).await.unwrap_or_default();
        let proposed = central_db.get_proposed_sets(user_id, &active.id).await.unwrap_or_default();
        let completed = central_db.get_completed_sets(user_id, &active.id).await.unwrap_or_default();

        // Re-check workouts to avoid overwriting a workout that might have started 
        // during the awaits above.
        use dashmap::mapref::entry::Entry;
        match self.workouts.entry(user_id.to_string()) {
            Entry::Vacant(v) => {
                v.insert(ActiveWorkout::new(active, groups, proposed, completed));
            }
            Entry::Occupied(_) => {
                // Someone else started a workout while we were fetching from DB
                return;
            }
        }

        // Recover session membership
        if let Ok(Some(session_id)) = central_db.get_active_session(user_id).await {
            self.user_sessions.insert(user_id.to_string(), session_id.clone());
            self.sessions
                .entry(session_id)
                .or_insert_with(HashSet::new)
                .insert(user_id.to_string());
        }
    }

    /// Flush a single user's active workout to their UserDb
    pub async fn flush_workout(
        &self,
        central_db: &CentralDb,
        user_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        // 1. Extract data while holding the lock
        let workout_data = {
            let workout_ref = match self.workouts.get(user_id) {
                Some(r) => r,
                None => return Ok(()),
            };

            if !workout_ref.dirty.load(Ordering::Relaxed) {
                return Ok(());
            }

            // Clone data to avoid holding the guard across .await
            (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            )
        };

        // 2. Perform IO outside the lock
        let (workout, groups, proposed, completed) = workout_data;
        
        central_db
            .flush_workout(
                user_id,
                &workout,
                &groups,
                &proposed,
                &completed,
            )
            .await?;

        // 3. Re-acquire lock to clear dirty flag if it's still the same workout
        if let Some(workout_ref) = self.workouts.get(user_id) {
            if workout_ref.workout.id == workout.id {
                workout_ref.clear_dirty();
            }
        }
        
        Ok(())
    }

    /// Flush all dirty workouts (called by checkpoint task)
    pub async fn flush_all_dirty(&self, central_db: &CentralDb) {
        let user_ids: Vec<String> = self
            .workouts
            .iter()
            .filter(|entry| entry.value().dirty.load(Ordering::Relaxed))
            .map(|entry| entry.key().clone())
            .collect();

        for user_id in user_ids {
            if let Err(e) = self.flush_workout(central_db, &user_id).await {
                eprintln!("Checkpoint flush failed for {}: {}", user_id, e);
            }
        }
    }

}

pub fn spawn_checkpoint_task(state: Arc<AppState>, central_db: CentralDb) {
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));
        loop {
            interval.tick().await;
            state.flush_all_dirty(&central_db).await;
        }
    });
}
