use dashmap::DashMap;
use lift::workout::v1::{
    CompletedSet, ExerciseGroup, ProposedSet, User, Workout,
};
use std::collections::HashSet;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::db::UserDb;

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
}

impl AppState {
    pub fn new() -> Self {
        Self {
            workouts: DashMap::new(),
            sessions: DashMap::new(),
            user_sessions: DashMap::new(),
            users: DashMap::new(),
        }
    }

    /// Flush a single user's active workout to their UserDb
    pub async fn flush_workout(
        &self,
        user_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let workout_ref = match self.workouts.get(user_id) {
            Some(r) => r,
            None => return Ok(()),
        };

        if !workout_ref.dirty.load(Ordering::Relaxed) {
            return Ok(());
        }

        let user_db = UserDb::new(user_id).await?;
        user_db
            .flush_workout(
                &workout_ref.workout,
                &workout_ref.exercise_groups,
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
            )
            .await?;

        workout_ref.clear_dirty();
        Ok(())
    }

    /// Flush all dirty workouts (called by checkpoint task)
    pub async fn flush_all_dirty(&self) {
        let user_ids: Vec<String> = self
            .workouts
            .iter()
            .filter(|entry| entry.value().dirty.load(Ordering::Relaxed))
            .map(|entry| entry.key().clone())
            .collect();

        for user_id in user_ids {
            if let Err(e) = self.flush_workout(&user_id).await {
                eprintln!("Checkpoint flush failed for {}: {}", user_id, e);
            }
        }
    }

    /// Load un-ended workouts from UserDb on startup for crash recovery
    pub async fn recover_active_workouts(
        &self,
        central_db: &crate::db::CentralDb,
    ) -> Result<usize, Box<dyn std::error::Error + Send + Sync>> {
        // Scan all user DBs for active (un-ended) workouts
        let data_dir = "data/user_dbs";
        let path = std::path::Path::new(data_dir);
        if !path.exists() {
            return Ok(0);
        }

        let mut count = 0;
        for entry in std::fs::read_dir(path)? {
            let entry = entry?;
            let filename = entry.file_name();
            let name = filename.to_string_lossy();
            if !name.ends_with(".sqlite") {
                continue;
            }
            let user_id = name.trim_end_matches(".sqlite").to_string();

            let user_db = match UserDb::new(&user_id).await {
                Ok(db) => db,
                Err(_) => continue,
            };

            let active = match user_db.get_active_workout().await {
                Ok(Some(w)) => w,
                _ => continue,
            };

            let groups = user_db.get_exercise_groups(&active.id).await.unwrap_or_default();
            let proposed = user_db.get_proposed_sets(&active.id).await.unwrap_or_default();
            let completed = user_db.get_completed_sets(&active.id).await.unwrap_or_default();

            self.workouts.insert(
                user_id.clone(),
                ActiveWorkout::new(active, groups, proposed, completed),
            );

            // Cache user info
            if let Ok(Some(user)) = central_db.get_user(&user_id).await {
                self.users.insert(user_id.clone(), user);
            }

            // Recover session membership from user_sessions table
            if let Ok(Some(session_id)) = user_db.get_active_session().await {
                self.user_sessions.insert(user_id.clone(), session_id.clone());
                self.sessions
                    .entry(session_id)
                    .or_insert_with(HashSet::new)
                    .insert(user_id);
            }

            count += 1;
        }

        Ok(count)
    }
}

pub fn spawn_checkpoint_task(state: Arc<AppState>) {
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));
        loop {
            interval.tick().await;
            state.flush_all_dirty().await;
        }
    });
}
