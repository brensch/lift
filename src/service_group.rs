use std::collections::HashSet;
use std::pin::Pin;
use std::sync::Arc;

use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{Request, Response, Status};

use crate::db::CentralDb;
use crate::multiplayer_current::{
    build_participant_status_from_state, load_current_session_snapshot,
    publish_current_session_snapshot, publish_current_session_snapshot_from_state,
    remove_and_publish_user_session_state, sync_and_publish_user_session_state,
};
use crate::service_workout::get_user_id_authenticated;
use crate::state::AppState;
use schlift::workout::v1::multiplayer_service_server::MultiplayerService;
use schlift::workout::v1::*;

#[derive(Clone)]
pub struct GroupService {
    central_db: CentralDb,
    state: Arc<AppState>,
}

type SessionStream =
    Pin<Box<dyn futures_util::Stream<Item = Result<SessionSubscriptionEvent, Status>> + Send>>;

impl GroupService {
    pub fn new(central_db: CentralDb, state: Arc<AppState>) -> Self {
        Self { central_db, state }
    }

    async fn active_member_ids_for_session(&self, session_id: &str) -> Vec<String> {
        if let Some(members) = self.state.sessions.get(session_id) {
            if !members.is_empty() {
                return members.iter().cloned().collect();
            }
        }

        self.central_db
            .get_current_session_participants(session_id)
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|row| row.user_id)
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

        sync_and_publish_user_session_state(&self.central_db, &self.state, user_id, "session_move")
            .await?;
        publish_current_session_snapshot(&self.central_db, &self.state, from_session_id).await?;
        Ok(())
    }
}

#[tonic::async_trait]
impl MultiplayerService for GroupService {
    type SubscribeSessionStream = SessionStream;

    async fn join_user(
        &self,
        request: Request<JoinUserRequest>,
    ) -> Result<Response<JoinUserResponse>, Status> {
        let caller_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let target_id = request.into_inner().user_id;

        if caller_id == target_id {
            return Err(Status::invalid_argument("Cannot join yourself"));
        }

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
                        return Err(Status::failed_precondition(
                            "Both users are already in different active sessions. Leave your current session first.",
                        ));
                    }
                }
            }
            (None, Some(t_sid)) => {
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
                let sid = uuid::Uuid::new_v4().to_string();
                use dashmap::mapref::entry::Entry;
                match self.state.user_sessions.entry(target_id.clone()) {
                    Entry::Occupied(existing) => {
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

        for uid in [&caller_id, &target_id] {
            if !self.state.users.contains_key(uid) {
                if let Ok(Some(user)) = self.central_db.get_user(uid).await {
                    self.state.users.insert(uid.to_string(), user);
                }
            }
            if let Some(mut active) = self.state.workouts.get_mut(uid) {
                if active.workout.session_id != session_id {
                    active.workout.session_id = session_id.clone();
                    let _ = self
                        .central_db
                        .update_workout_session_id(uid, &active.workout.id, &session_id)
                        .await;
                }
            }
            sync_and_publish_user_session_state(&self.central_db, &self.state, uid, "session_join")
                .await?;
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
            self.central_db
                .leave_session(&user_id, &session_id)
                .await
                .map_err(|e| Status::internal(e.to_string()))?;
            remove_and_publish_user_session_state(
                &self.central_db,
                &self.state,
                &session_id,
                &user_id,
                "session_leave",
            )
            .await?;
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

        self.state
            .try_recover_user(&self.central_db, &req.user_id)
            .await;

        let status = build_participant_status_from_state(&self.state, &req.user_id);
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
        let explicit_session = !req.session_id.is_empty();

        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        let session_id = if !req.session_id.is_empty() {
            req.session_id
        } else if let Some(in_memory) = self.state.user_sessions.get(&user_id) {
            in_memory.clone()
        } else if let Some(db_session) = self
            .central_db
            .get_current_session_id_for_user(&user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            db_session
        } else {
            return Ok(Response::new(GetCurrentSessionResponse {
                session_id: String::new(),
                session_status: None,
            }));
        };

        if explicit_session {
            let caller_session = self
                .central_db
                .get_current_session_id_for_user(&user_id)
                .await
                .map_err(|e| Status::internal(e.to_string()))?;
            let caller_was_member = self
                .central_db
                .was_user_in_session(&user_id, &session_id)
                .await
                .map_err(|e| Status::internal(e.to_string()))?;
            if caller_session.as_deref() != Some(session_id.as_str()) && !caller_was_member {
                return Err(Status::permission_denied(
                    "You are not a member of this multiplayer session",
                ));
            }
        }

        let Some((_, mut session_status)) =
            load_current_session_snapshot(&self.central_db, &self.state, &session_id).await?
        else {
            return Ok(Response::new(GetCurrentSessionResponse {
                session_id: String::new(),
                session_status: None,
            }));
        };
        session_status.participants.retain(|participant| {
            participant.user.as_ref().map(|u| u.id.as_str()) != Some(user_id.as_str())
        });

        Ok(Response::new(GetCurrentSessionResponse {
            session_id,
            session_status: Some(session_status),
        }))
    }

    async fn subscribe_session(
        &self,
        request: Request<SubscribeSessionRequest>,
    ) -> Result<Response<Self::SubscribeSessionStream>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let session_id = if !req.session_id.is_empty() {
            req.session_id
        } else {
            self.central_db
                .get_current_session_id_for_user(&user_id)
                .await
                .map_err(|e| Status::internal(e.to_string()))?
                .ok_or_else(|| Status::not_found("No active multiplayer session"))?
        };

        let caller_session = self
            .central_db
            .get_current_session_id_for_user(&user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        if caller_session.as_deref() != Some(session_id.as_str()) {
            return Err(Status::permission_denied(
                "You are not a member of this multiplayer session",
            ));
        }

        let sender = self.state.session_sender(&session_id);
        let mut rx = sender.subscribe();
        let central_db = self.central_db.clone();
        let state = self.state.clone();
        let session_id_for_task = session_id.clone();
        let (tx, out_rx) = mpsc::channel(32);

        tokio::spawn(async move {
            if let Ok(Some((version, session_status))) =
                load_current_session_snapshot(&central_db, &state, &session_id_for_task).await
            {
                if tx
                    .send(Ok(SessionSubscriptionEvent {
                        session_id: session_id_for_task.clone(),
                        version,
                        session_status: Some(session_status),
                    }))
                    .await
                    .is_err()
                {
                    return;
                }
            }

            loop {
                match rx.recv().await {
                    Ok(event) => {
                        if tx.send(Ok(event)).await.is_err() {
                            break;
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                        if let Ok(Some((version, session_status))) =
                            load_current_session_snapshot(&central_db, &state, &session_id_for_task)
                                .await
                        {
                            if tx
                                .send(Ok(SessionSubscriptionEvent {
                                    session_id: session_id_for_task.clone(),
                                    version,
                                    session_status: Some(session_status),
                                }))
                                .await
                                .is_err()
                            {
                                break;
                            }
                        } else if tx
                            .send(Err(Status::unavailable(
                                "Session stream lost sync and could not recover",
                            )))
                            .await
                            .is_err()
                        {
                            break;
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => {
                        let _ = publish_current_session_snapshot(
                            &central_db,
                            &state,
                            &session_id_for_task,
                        )
                        .await;
                        break;
                    }
                }
            }
        });

        Ok(Response::new(Box::pin(ReceiverStream::new(out_rx))))
    }

    async fn update_active_workout(
        &self,
        request: Request<UpdateActiveWorkoutRequest>,
    ) -> Result<Response<UpdateActiveWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;
        if let Some(session_id) = self.state.user_sessions.get(&user_id).map(|s| s.clone()) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }
        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }
}

#[cfg(test)]
#[path = "service_group_tests.rs"]
mod tests;
