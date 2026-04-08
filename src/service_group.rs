use crate::db::CentralDb;
use crate::progress::{compute_participant_progress, compute_session_next_up};
use crate::service_workout::get_user_id_authenticated;
use crate::state::AppState;
use schlift::workout::v1::multiplayer_service_server::MultiplayerService;
use schlift::workout::v1::*;
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use tonic::{Request, Response, Status};

#[derive(Clone)]
pub struct GroupService {
    central_db: CentralDb,
    state: Arc<AppState>,
}

impl GroupService {
    pub fn new(central_db: CentralDb, state: Arc<AppState>) -> Self {
        Self { central_db, state }
    }

    fn build_participant_status(&self, user_id: &str) -> ParticipantStatus {
        let user = self
            .state
            .users
            .get(user_id)
            .map(|u| u.clone())
            .unwrap_or_else(|| User {
                id: user_id.to_string(),
                name: String::new(),
                created_at: 0,
            });

        if let Some(w) = self.state.workouts.get(user_id) {
            let proposed_sets: Vec<ProposedSet> = w
                .proposed_sets
                .iter()
                .filter(|set| !set.cancelled)
                .cloned()
                .collect();
            let progress = compute_participant_progress(&proposed_sets, &w.completed_sets);
            ParticipantStatus {
                user: Some(user),
                active_workout_id: w.workout.id.clone(),
                active_workout: Some(w.workout.clone()),
                exercise_groups: w.exercise_groups.clone(),
                proposed_sets,
                completed_sets: w.completed_sets.clone(),
                next_up_set: progress.next_up_set,
                rest_until: progress.rest_until,
                has_active_set: progress.has_active_set,
            }
        } else {
            ParticipantStatus {
                user: Some(user),
                active_workout_id: String::new(),
                ..Default::default()
            }
        }
    }

    fn current_lifting_user_id(participants: &[ParticipantStatus]) -> String {
        participants
            .iter()
            .filter_map(|participant| {
                if !participant.has_active_set {
                    return None;
                }
                let started_at = participant
                    .completed_sets
                    .iter()
                    .filter(|set| set.ended_at == 0)
                    .map(|set| set.started_at)
                    .max()
                    .unwrap_or(0);
                let user_id = participant
                    .user
                    .as_ref()
                    .map(|u| u.id.clone())
                    .unwrap_or_default();
                Some((started_at, user_id))
            })
            .max_by_key(|(started_at, _)| *started_at)
            .map(|(_, user_id)| user_id)
            .unwrap_or_default()
    }

    async fn active_member_ids_for_session(&self, session_id: &str) -> Vec<String> {
        if let Some(members) = self.state.sessions.get(session_id) {
            if !members.is_empty() {
                return members.iter().cloned().collect();
            }
        }
        self.central_db
            .get_session_membership_states(session_id)
            .await
            .unwrap_or_default()
            .into_iter()
            .filter_map(|(user_id, is_active)| if is_active { Some(user_id) } else { None })
            .collect()
    }

    async fn move_active_member_to_session(
        &self,
        user_id: &str,
        from_session_id: &str,
        to_session_id: &str,
    ) -> Result<(), Status> {
        if from_session_id == to_session_id {
            return Ok(());
        }

        self.state
            .user_sessions
            .insert(user_id.to_string(), to_session_id.to_string());

        if let Some(mut members) = self.state.sessions.get_mut(from_session_id) {
            members.remove(user_id);
            if members.is_empty() {
                drop(members);
                self.state.sessions.remove(from_session_id);
            }
        }
        self.state
            .sessions
            .entry(to_session_id.to_string())
            .or_insert_with(HashSet::new)
            .insert(user_id.to_string());

        if let Some(mut active) = self.state.workouts.get_mut(user_id) {
            if active.workout.session_id != to_session_id {
                active.workout.session_id = to_session_id.to_string();
                self.central_db
                    .update_workout_session_id(user_id, &active.workout.id, to_session_id)
                    .await
                    .map_err(|e| Status::internal(e.to_string()))?;
            }
        }

        self.central_db
            .leave_session(user_id, from_session_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        self.central_db
            .join_session(user_id, to_session_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(())
    }
}

#[tonic::async_trait]
impl MultiplayerService for GroupService {
    async fn join_user(
        &self,
        request: Request<JoinUserRequest>,
    ) -> Result<Response<JoinUserResponse>, Status> {
        let caller_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let target_id = request.into_inner().user_id;

        if caller_id == target_id {
            return Err(Status::invalid_argument("Cannot join yourself"));
        }

        // Recover both users to ensure we have their latest session info
        self.state
            .try_recover_user(&self.central_db, &caller_id)
            .await;
        self.state
            .try_recover_user(&self.central_db, &target_id)
            .await;

        let caller_session_id = self.state.user_sessions.get(&caller_id).map(|r| r.clone());
        let target_session_id = self.state.user_sessions.get(&target_id).map(|r| r.clone());

        let session_id = match (caller_session_id, target_session_id) {
            (Some(c_sid), Some(t_sid)) => {
                if c_sid == t_sid {
                    c_sid
                } else {
                    let caller_active_members = self.active_member_ids_for_session(&c_sid).await;
                    let target_active_members = self.active_member_ids_for_session(&t_sid).await;

                    let caller_is_solo =
                        caller_active_members.len() == 1 && caller_active_members[0] == caller_id;
                    let target_is_solo =
                        target_active_members.len() == 1 && target_active_members[0] == target_id;

                    if caller_is_solo {
                        self.move_active_member_to_session(&caller_id, &c_sid, &t_sid)
                            .await?;
                        t_sid
                    } else if target_is_solo {
                        self.move_active_member_to_session(&target_id, &t_sid, &c_sid)
                            .await?;
                        c_sid
                    } else {
                        return Err(Status::failed_precondition("Both users are already in different active sessions. Leave your current session first."));
                    }
                }
            }
            (None, Some(t_sid)) => {
                // Caller joins target's session
                self.state
                    .user_sessions
                    .insert(caller_id.clone(), t_sid.clone());
                self.state
                    .sessions
                    .entry(t_sid.clone())
                    .or_insert_with(HashSet::new)
                    .insert(caller_id.clone());
                self.central_db
                    .join_session(&caller_id, &t_sid)
                    .await
                    .map_err(|e| Status::internal(e.to_string()))?;
                t_sid
            }
            (Some(c_sid), None) => {
                // Target joins caller's session
                self.state
                    .user_sessions
                    .insert(target_id.clone(), c_sid.clone());
                self.state
                    .sessions
                    .entry(c_sid.clone())
                    .or_insert_with(HashSet::new)
                    .insert(target_id.clone());
                self.central_db
                    .join_session(&target_id, &c_sid)
                    .await
                    .map_err(|e| Status::internal(e.to_string()))?;
                c_sid
            }
            (None, None) => {
                // Create new session for both
                let sid = uuid::Uuid::new_v4().to_string();

                // Use entry logic to avoid race conditions where both create sessions simultaneously
                use dashmap::mapref::entry::Entry;
                match self.state.user_sessions.entry(target_id.clone()) {
                    Entry::Occupied(existing) => {
                        // Someone else just put the target in a session
                        let sid = existing.get().clone();
                        self.state
                            .user_sessions
                            .insert(caller_id.clone(), sid.clone());
                        self.state
                            .sessions
                            .entry(sid.clone())
                            .or_insert_with(HashSet::new)
                            .insert(caller_id.clone());
                        self.central_db
                            .join_session(&caller_id, &sid)
                            .await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        sid
                    }
                    Entry::Vacant(vacant) => {
                        vacant.insert(sid.clone());
                        self.state
                            .user_sessions
                            .insert(caller_id.clone(), sid.clone());

                        let mut members = HashSet::new();
                        members.insert(caller_id.clone());
                        members.insert(target_id.clone());
                        self.state.sessions.insert(sid.clone(), members);

                        self.central_db
                            .join_session(&caller_id, &sid)
                            .await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        self.central_db
                            .join_session(&target_id, &sid)
                            .await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        sid
                    }
                }
            }
        };

        // Cache user info if needed
        for uid in &[&caller_id, &target_id] {
            if !self.state.users.contains_key(*uid) {
                if let Ok(Some(user)) = self.central_db.get_user(uid).await {
                    self.state.users.insert(uid.to_string(), user);
                }
            }

            // Update active workout with session_id if exists
            if let Some(mut active) = self.state.workouts.get_mut(*uid) {
                if active.workout.session_id != session_id {
                    active.workout.session_id = session_id.clone();
                    let _ = self
                        .central_db
                        .update_workout_session_id(uid, &active.workout.id, &session_id)
                        .await;
                }
            }
        }

        Ok(Response::new(JoinUserResponse { session_id }))
    }

    async fn leave_session(
        &self,
        request: Request<LeaveSessionRequest>,
    ) -> Result<Response<LeaveSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if let Some((_, session_id)) = self.state.user_sessions.remove(&user_id) {
            if let Some(mut members) = self.state.sessions.get_mut(&session_id) {
                members.remove(&user_id);
                if members.is_empty() {
                    drop(members);
                    self.state.sessions.remove(&session_id);
                }
            }
            // Record in user's DB
            self.central_db
                .leave_session(&user_id, &session_id)
                .await
                .map_err(|e| Status::internal(e.to_string()))?;
            self.central_db
                .flush_writes()
                .await
                .map_err(|e| Status::internal(e.to_string()))?;
        }

        Ok(Response::new(LeaveSessionResponse {}))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let _ = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        // Ensure target is recovered if possible
        self.state
            .try_recover_user(&self.central_db, &req.user_id)
            .await;

        // Read directly from in-memory state
        let status = self.build_participant_status(&req.user_id);
        if status.active_workout_id.is_empty() {
            return Err(Status::not_found(
                "Participant not in an active session or workout not found",
            ));
        }

        Ok(Response::new(status))
    }

    async fn get_current_session(
        &self,
        request: Request<GetCurrentSessionRequest>,
    ) -> Result<Response<GetCurrentSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        // Ensure user is recovered if possible
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        // Determine session ID
        let session_id = if !req.session_id.is_empty() {
            Some(req.session_id)
        } else {
            self.state.user_sessions.get(&user_id).map(|r| r.clone())
        };

        if let Some(sid) = session_id {
            // 1. Get session roster (latest membership state per user).
            let membership_states = self
                .central_db
                .get_session_membership_states(&sid)
                .await
                .unwrap_or_default();

            // 2. Get all workout data for the session in bulk
            let (workouts_with_user, all_groups, all_proposed, all_completed) = self
                .central_db
                .get_session_workout_data(&sid)
                .await
                .unwrap_or_default();

            // 3. Index data for efficient assembly
            let workouts_by_user: HashMap<String, Workout> =
                workouts_with_user.into_iter().collect();

            let mut active_members = HashSet::new();
            let mut session_members = Vec::<String>::new();
            let mut seen_members = HashSet::new();

            for (user_id, is_active_member) in membership_states {
                if is_active_member {
                    active_members.insert(user_id.clone());
                }
                if seen_members.insert(user_id.clone()) {
                    session_members.push(user_id);
                }
            }

            if let Some(live_members) = self.state.sessions.get(&sid) {
                for user_id in live_members.iter() {
                    active_members.insert(user_id.clone());
                    if seen_members.insert(user_id.clone()) {
                        session_members.push(user_id.clone());
                    }
                }
            }

            // Fallback for older rows where workouts.session_id exists but membership rows do not.
            for user_id in workouts_by_user.keys() {
                if seen_members.insert(user_id.clone()) {
                    session_members.push(user_id.clone());
                }
            }

            // Keep active members first so "currently in session" users remain prominent.
            session_members.sort_by_key(|user_id| {
                if active_members.contains(user_id) {
                    0
                } else {
                    1
                }
            });

            let mut groups_by_workout: HashMap<String, Vec<ExerciseGroup>> = HashMap::new();
            for g in all_groups {
                groups_by_workout
                    .entry(g.workout_id.clone())
                    .or_default()
                    .push(g);
            }

            let mut proposed_by_workout: HashMap<String, Vec<ProposedSet>> = HashMap::new();
            for p in all_proposed {
                proposed_by_workout
                    .entry(p.workout_id.clone())
                    .or_default()
                    .push(p);
            }

            let mut completed_by_workout: HashMap<String, Vec<CompletedSet>> = HashMap::new();
            for c in all_completed {
                completed_by_workout
                    .entry(c.workout_id.clone())
                    .or_default()
                    .push(c);
            }

            // Bulk-load uncached users to avoid N+1 queries in the 1Hz poll path.
            let missing_user_ids: Vec<String> = session_members
                .iter()
                .filter(|user_id| !self.state.users.contains_key(*user_id))
                .cloned()
                .collect();
            if !missing_user_ids.is_empty() {
                if let Ok(users) = self.central_db.get_users_by_ids(&missing_user_ids).await {
                    for (uid, user) in users {
                        self.state.users.insert(uid, user);
                    }
                }
            }

            let mut participant_statuses = Vec::new();
            for member_id in &session_members {
                // Get user info (check cache first)
                let user = if let Some(u) = self.state.users.get(member_id) {
                    u.clone()
                } else {
                    self.central_db
                        .get_user(member_id)
                        .await
                        .ok()
                        .flatten()
                        .unwrap_or_else(|| User {
                            id: member_id.clone(),
                            name: String::new(),
                            created_at: 0,
                        })
                };

                // Self-heal: if the workout is active in memory but its
                // session_id is wrong/empty, fix it so subsequent polls use
                // the fast in-memory path correctly.
                {
                    let needs_heal = self
                        .state
                        .workouts
                        .get(member_id)
                        .map(|w| w.workout.end_time == 0 && w.workout.session_id != sid)
                        .unwrap_or(false);
                    if needs_heal {
                        if let Some(mut active) = self.state.workouts.get_mut(member_id) {
                            if active.workout.end_time == 0 {
                                active.workout.session_id = sid.clone();
                                let _ = self
                                    .central_db
                                    .update_workout_session_id(member_id, &active.workout.id, &sid)
                                    .await;
                            }
                        }
                    }
                }

                let use_in_memory_status = self
                    .state
                    .workouts
                    .get(member_id)
                    .map(|w| w.workout.session_id == sid && w.workout.end_time == 0)
                    .unwrap_or(false);

                if use_in_memory_status {
                    let mut status = self.build_participant_status(member_id);
                    status.user = Some(user);
                    participant_statuses.push(status);
                    continue;
                }

                if let Some(workout) = workouts_by_user.get(member_id) {
                    let groups = groups_by_workout.remove(&workout.id).unwrap_or_default();
                    let proposed = proposed_by_workout.remove(&workout.id).unwrap_or_default();
                    let completed = completed_by_workout.remove(&workout.id).unwrap_or_default();

                    let proposed_active: Vec<ProposedSet> =
                        proposed.iter().filter(|s| !s.cancelled).cloned().collect();
                    let progress = compute_participant_progress(&proposed_active, &completed);

                    participant_statuses.push(ParticipantStatus {
                        user: Some(user),
                        active_workout_id: workout.id.clone(),
                        active_workout: Some(workout.clone()),
                        exercise_groups: groups,
                        proposed_sets: proposed_active,
                        completed_sets: completed,
                        next_up_set: progress.next_up_set,
                        rest_until: progress.rest_until,
                        has_active_set: progress.has_active_set,
                    });
                } else {
                    // Just a lurker
                    participant_statuses.push(ParticipantStatus {
                        user: Some(user),
                        active_workout_id: String::new(),
                        ..Default::default()
                    });
                }
            }

            let next_up_participants: Vec<ParticipantStatus> = if active_members.is_empty() {
                participant_statuses.clone()
            } else {
                participant_statuses
                    .iter()
                    .filter(|participant| {
                        participant
                            .user
                            .as_ref()
                            .map(|u| active_members.contains(&u.id))
                            .unwrap_or(false)
                    })
                    .cloned()
                    .collect()
            };

            let now_unix = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs() as i64)
                .unwrap_or(0);
            let session_next_up = compute_session_next_up(&next_up_participants, now_unix);
            let currently_lifting_user_id = Self::current_lifting_user_id(&participant_statuses);

            Ok(Response::new(GetCurrentSessionResponse {
                session_id: sid.clone(),
                session_status: Some(SessionStatus {
                    session_id: sid,
                    participants: participant_statuses,
                    next_up_user_id: session_next_up
                        .as_ref()
                        .map(|n| n.user_id.clone())
                        .unwrap_or_default(),
                    next_up_set: session_next_up.as_ref().map(|n| n.next_up_set.clone()),
                    next_up_rest_until: session_next_up.as_ref().map(|n| n.rest_until).unwrap_or(0),
                    currently_lifting_user_id,
                }),
            }))
        } else {
            Ok(Response::new(GetCurrentSessionResponse {
                session_id: String::new(),
                session_status: None,
            }))
        }
    }

    async fn update_active_workout(
        &self,
        request: Request<UpdateActiveWorkoutRequest>,
    ) -> Result<Response<UpdateActiveWorkoutResponse>, Status> {
        let _user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        // No-op: workout state is read directly from AppState.workouts
        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }
}

#[cfg(test)]
#[path = "service_group_tests.rs"]
mod tests;
