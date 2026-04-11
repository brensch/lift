use crate::program_state::{payload_from_proto, payload_to_proto, pending_update_to_proto};
use crate::regimes::{catalog_regime_types, get_regime};
use crate::scratch::db::ScratchDb;
use crate::service_workout::{
    active_from_get_workout_response, active_proposed_sets, apply_cancel_proposed_set_to_active,
    apply_complete_set_to_active, apply_delete_completed_set_to_active,
    apply_replace_exercise_group_plan, apply_reorder_exercise_groups, apply_start_set_to_active,
    generate_sets_for_group, get_workout_response_from_active, is_final_set_in_exercise_group_after_completion,
    start_workout_response_from_active, workout_state_snapshot_from_state,
    END_OF_EXERCISE_GROUP_REST_SECONDS,
};
use crate::progress::compute_next_up_set;
use crate::state::ActiveWorkout;
use prost::Message;
use schlift::workout::v1::auth_service_server::AuthService;
use schlift::workout::v1::multiplayer_service_server::MultiplayerService;
use schlift::workout::v1::settings_service_server::SettingsService;
use schlift::workout::v1::user_service_server::UserService;
use schlift::workout::v1::workout_mutation::Mutation;
use schlift::workout::v1::workout_service_server::WorkoutService;
use schlift::workout::v1::*;
use std::pin::Pin;
use tonic::{Request, Response, Status};
use uuid::Uuid;

fn now_unix() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

async fn authed_user_id<T>(request: &Request<T>, db: &ScratchDb) -> Result<String, Status> {
    let token = request
        .metadata()
        .get("x-session-token")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| Status::unauthenticated("Missing session token"))?;
    db.validate_auth_session(token)
        .await
        .map_err(|e| Status::internal(e.to_string()))?
        .ok_or_else(|| Status::unauthenticated("Invalid session token"))
}

fn setting_type_key(setting: &UserSetting) -> Option<&'static str> {
    match &setting.setting {
        Some(user_setting::Setting::PlateColors(_)) => Some("plate_colors"),
        Some(user_setting::Setting::WeightUnit(_)) => Some("weight_unit"),
        None => None,
    }
}

fn build_participant_status(user: User, workout_resp: Option<&GetWorkoutResponse>) -> ParticipantStatus {
    if let Some(resp) = workout_resp {
        let rest_until = resp
            .state_snapshot
            .as_ref()
            .map(|s| s.rest_until)
            .unwrap_or(0);
        let has_active_set = resp.completed_sets.iter().any(|set| set.ended_at == 0);
        ParticipantStatus {
            user: Some(user),
            active_workout_id: resp.workout.as_ref().map(|w| w.id.clone()).unwrap_or_default(),
            active_workout: resp.workout.clone(),
            exercise_groups: resp.exercise_groups.clone(),
            proposed_sets: resp.proposed_sets.clone(),
            completed_sets: resp.completed_sets.clone(),
            next_up_set: resp.next_up_set.clone(),
            rest_until,
            has_active_set,
        }
    } else {
        ParticipantStatus {
            user: Some(user),
            active_workout_id: String::new(),
            active_workout: None,
            exercise_groups: Vec::new(),
            proposed_sets: Vec::new(),
            completed_sets: Vec::new(),
            next_up_set: None,
            rest_until: 0,
            has_active_set: false,
        }
    }
}

/// Refresh participant status from real tables and update the denormalized cache.
async fn refresh_participant_for_user(
    db: &ScratchDb,
    user_id: &str,
    session_id: &str,
) -> Result<(), Status> {
    let user = db
        .get_user(user_id)
        .await
        .map_err(|e| Status::internal(e.to_string()))?
        .ok_or_else(|| Status::not_found("User not found"))?;
    // Load workout from real tables
    let active = if let Some((workout_id, _)) = db
        .get_active_workout_id(user_id)
        .await
        .map_err(|e| Status::internal(e.to_string()))?
    {
        db.load_workout_full(user_id, &workout_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?
    } else {
        None
    };
    let participant = build_participant_status(user, active.as_ref());
    db.upsert_session_participant(session_id, user_id, &participant)
        .await
        .map_err(|e| Status::internal(e.to_string()))
}

// ── Auth Service ──

#[derive(Clone)]
pub struct ScratchAuthService {
    pub db: ScratchDb,
}

#[tonic::async_trait]
impl AuthService for ScratchAuthService {
    async fn test_login(
        &self,
        request: Request<TestLoginRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        let req = request.into_inner();
        let username = req.username.trim();
        if username.is_empty() {
            return Err(Status::invalid_argument("username is required"));
        }
        let (user, token) = self
            .db
            .get_or_create_user_with_auth_session(username)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(AuthResponse {
            session_token: token,
            user_id: user.id,
            username: user.name,
        }))
    }

    async fn logout(
        &self,
        request: Request<LogoutRequest>,
    ) -> Result<Response<LogoutResponse>, Status> {
        let token = request
            .metadata()
            .get("x-session-token")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| Status::unauthenticated("Missing session token"))?;
        self.db
            .delete_auth_session(token)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(LogoutResponse {}))
    }

    async fn register_start(&self, _r: Request<RegisterStartRequest>) -> Result<Response<RegisterStartResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn register_finish(&self, _r: Request<RegisterFinishRequest>) -> Result<Response<AuthResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn login_start(&self, _r: Request<LoginStartRequest>) -> Result<Response<LoginStartResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn login_finish(&self, _r: Request<LoginFinishRequest>) -> Result<Response<AuthResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn add_passkey_start(&self, _r: Request<AddPasskeyStartRequest>) -> Result<Response<AddPasskeyStartResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn add_passkey_finish(&self, _r: Request<AddPasskeyFinishRequest>) -> Result<Response<AddPasskeyFinishResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn delete_passkey(&self, _r: Request<DeletePasskeyRequest>) -> Result<Response<DeletePasskeyResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn list_passkeys(&self, _r: Request<ListPasskeysRequest>) -> Result<Response<ListPasskeysResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
    async fn delete_account(&self, _r: Request<DeleteAccountRequest>) -> Result<Response<DeleteAccountResponse>, Status> { Err(Status::unimplemented("scratch auth only supports TestLogin/Logout")) }
}

// ── User Service ──

#[derive(Clone)]
pub struct ScratchUserService {
    pub db: ScratchDb,
}

#[tonic::async_trait]
impl UserService for ScratchUserService {
    async fn create_user(
        &self,
        request: Request<CreateUserRequest>,
    ) -> Result<Response<CreateUserResponse>, Status> {
        let req = request.into_inner();
        let name = req.name.trim();
        if name.is_empty() {
            return Err(Status::invalid_argument("name is required"));
        }
        let (user, _) = self
            .db
            .get_or_create_user_with_auth_session(name)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(CreateUserResponse { user: Some(user) }))
    }

    async fn get_user(
        &self,
        request: Request<GetUserRequest>,
    ) -> Result<Response<GetUserResponse>, Status> {
        let req = request.into_inner();
        let user = self
            .db
            .get_user(&req.user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("User not found"))?;
        Ok(Response::new(GetUserResponse { user: Some(user) }))
    }
}

// ── Settings Service ──

#[derive(Clone)]
pub struct ScratchSettingsService {
    pub db: ScratchDb,
}

#[tonic::async_trait]
impl SettingsService for ScratchSettingsService {
    async fn update_setting(
        &self,
        request: Request<UpdateSettingRequest>,
    ) -> Result<Response<UpdateSettingResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let setting = req.setting.ok_or_else(|| Status::invalid_argument("setting is required"))?;
        let type_key = setting_type_key(&setting).ok_or_else(|| Status::invalid_argument("unknown setting type"))?;
        self.db.put_setting(&user_id, type_key, &setting).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(UpdateSettingResponse {}))
    }

    async fn get_settings(
        &self,
        request: Request<GetSettingsRequest>,
    ) -> Result<Response<GetSettingsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let settings = self.db.get_settings(&user_id).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(GetSettingsResponse { settings }))
    }

    async fn get_training_program_catalog(
        &self,
        _request: Request<GetTrainingProgramCatalogRequest>,
    ) -> Result<Response<GetTrainingProgramCatalogResponse>, Status> {
        let mut programs = catalog_regime_types()
            .into_iter()
            .map(|rt| get_regime(rt).training_program_definition(rt))
            .collect::<Vec<_>>();
        programs.sort_by_key(|p| (p.sort_order, p.regime_type));
        Ok(Response::new(GetTrainingProgramCatalogResponse { programs }))
    }

    async fn get_active_training_program_state(
        &self,
        request: Request<GetActiveTrainingProgramStateRequest>,
    ) -> Result<Response<GetActiveTrainingProgramStateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        if let Some(state) = self.db.get_program_state(&user_id).await.map_err(|e| Status::internal(e.to_string()))? {
            return Ok(Response::new(state));
        }
        let regime_type = RegimeType::Linear5x5;
        let regime = get_regime(regime_type);
        let response = GetActiveTrainingProgramStateResponse {
            state: Some(TrainingProgramState {
                regime_type: regime_type as i32,
                fields: payload_to_proto(&regime.default_state()),
                updated_at: 0,
                source: "default".to_string(),
            }),
            schema: Some(regime.state_schema()),
        };
        self.db.put_program_state(&user_id, &response).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(response))
    }

    async fn set_active_training_program_state(
        &self,
        request: Request<SetActiveTrainingProgramStateRequest>,
    ) -> Result<Response<SetActiveTrainingProgramStateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let regime_type = RegimeType::try_from(req.regime_type).unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);
        let payload = payload_from_proto(&req.fields);
        let state = TrainingProgramState {
            regime_type: regime_type as i32,
            fields: payload_to_proto(&payload),
            updated_at: now_unix(),
            source: if req.source.is_empty() { "manual_edit".to_string() } else { req.source },
        };
        let response = GetActiveTrainingProgramStateResponse {
            state: Some(state.clone()),
            schema: Some(regime.state_schema()),
        };
        self.db.put_program_state(&user_id, &response).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(SetActiveTrainingProgramStateResponse {
            state: Some(state),
            validation_warnings: regime.validate_state(&payload),
        }))
    }

    async fn get_training_program_state_history(
        &self,
        _request: Request<GetTrainingProgramStateHistoryRequest>,
    ) -> Result<Response<GetTrainingProgramStateHistoryResponse>, Status> {
        Err(Status::unimplemented("scratch settings does not store state history yet"))
    }

    async fn apply_pending_state_update(
        &self,
        request: Request<ApplyPendingStateUpdateRequest>,
    ) -> Result<Response<ApplyPendingStateUpdateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let current = self.db.get_program_state(&user_id).await.map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::failed_precondition("No active training program state"))?;
        let current_state = current.state.ok_or_else(|| Status::internal("missing state"))?;
        let regime_type = RegimeType::try_from(current_state.regime_type).unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);
        let current_payload = payload_from_proto(&current_state.fields);
        let updates = payload_from_proto(&req.field_values);
        let next_payload = regime.apply_pending_update_to_state(&current_payload, &req.update_id, &updates)
            .map_err(Status::invalid_argument)?;
        let state = TrainingProgramState {
            regime_type: regime_type as i32,
            fields: payload_to_proto(&next_payload),
            updated_at: now_unix(),
            source: format!("pending_update:{}", req.update_id),
        };
        let response = GetActiveTrainingProgramStateResponse {
            state: Some(state.clone()),
            schema: Some(regime.state_schema()),
        };
        self.db.put_program_state(&user_id, &response).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(ApplyPendingStateUpdateResponse { state: Some(state) }))
    }
}

// ── Multiplayer Service ──

#[derive(Clone)]
pub struct ScratchMultiplayerService {
    pub db: ScratchDb,
}

#[tonic::async_trait]
impl MultiplayerService for ScratchMultiplayerService {
    type SubscribeSessionStream =
        Pin<Box<dyn futures_util::Stream<Item = Result<SessionSubscriptionEvent, Status>> + Send>>;

    async fn join_user(
        &self,
        request: Request<JoinUserRequest>,
    ) -> Result<Response<JoinUserResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let target_id = req.user_id;
        if target_id.is_empty() || target_id == caller_id {
            return Err(Status::invalid_argument("target user_id is required"));
        }
        let _target = self.db.get_user(&target_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("Target user not found"))?;

        let session_id = self.db.get_current_session_id_for_user(&target_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .unwrap_or_else(|| Uuid::new_v4().to_string());

        self.db.join_session(&target_id, &session_id).await.map_err(|e| Status::internal(e.to_string()))?;
        self.db.join_session(&caller_id, &session_id).await.map_err(|e| Status::internal(e.to_string()))?;

        // Update session_id on both users' active workouts
        for user_id in [&caller_id, &target_id] {
            if let Some((workout_id, _)) = self.db.get_active_workout_id(user_id).await
                .map_err(|e| Status::internal(e.to_string()))?
            {
                self.db.update_workout_session_id(user_id, &workout_id, &session_id).await
                    .map_err(|e| Status::internal(e.to_string()))?;
            }
            refresh_participant_for_user(&self.db, user_id, &session_id).await?;
        }

        Ok(Response::new(JoinUserResponse { session_id }))
    }

    async fn leave_session(
        &self,
        request: Request<LeaveSessionRequest>,
    ) -> Result<Response<LeaveSessionResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        if let Some(session_id) = self.db.get_current_session_id_for_user(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            self.db.leave_session(&user_id, &session_id).await.map_err(|e| Status::internal(e.to_string()))?;
            self.db.remove_session_participant(&session_id, &user_id).await.map_err(|e| Status::internal(e.to_string()))?;
        }
        Ok(Response::new(LeaveSessionResponse {}))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let _caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let user = self.db.get_user(&req.user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("User not found"))?;
        let active = if let Some((workout_id, _)) = self.db.get_active_workout_id(&req.user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            self.db.load_workout_full(&req.user_id, &workout_id).await
                .map_err(|e| Status::internal(e.to_string()))?
        } else {
            None
        };
        Ok(Response::new(build_participant_status(user, active.as_ref())))
    }

    async fn get_current_session(
        &self,
        request: Request<GetCurrentSessionRequest>,
    ) -> Result<Response<GetCurrentSessionResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let session_id = if req.session_id.is_empty() {
            self.db.get_current_session_id_for_user(&caller_id).await
                .map_err(|e| Status::internal(e.to_string()))?
                .unwrap_or_default()
        } else {
            req.session_id
        };
        if session_id.is_empty() {
            return Ok(Response::new(GetCurrentSessionResponse {
                session_id,
                session_status: None,
            }));
        }
        let mut participants = self.db.get_session_participants(&session_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        participants.retain(|p| p.user.as_ref().map(|u| u.id.as_str()) != Some(caller_id.as_str()));
        Ok(Response::new(GetCurrentSessionResponse {
            session_id: session_id.clone(),
            session_status: Some(SessionStatus {
                session_id,
                participants,
                next_up_user_id: String::new(),
                next_up_set: None,
                next_up_rest_until: 0,
                currently_lifting_user_id: String::new(),
            }),
        }))
    }

    async fn subscribe_session(
        &self,
        _request: Request<SubscribeSessionRequest>,
    ) -> Result<Response<Self::SubscribeSessionStream>, Status> {
        Err(Status::unimplemented("scratch multiplayer uses polling, not streaming"))
    }

    async fn update_active_workout(
        &self,
        request: Request<UpdateActiveWorkoutRequest>,
    ) -> Result<Response<UpdateActiveWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        if let Some(session_id) = self.db.get_current_session_id_for_user(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }
        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }
}

// ── Workout Service ──

#[derive(Clone)]
pub struct ScratchWorkoutService {
    pub db: ScratchDb,
}

impl ScratchWorkoutService {
    async fn generate_schedule(
        &self,
        user_id: &str,
        at_time: i64,
    ) -> Result<GetProposedWorkoutScheduleResponse, Status> {
        let state_resp = if let Some(resp) = self.db.get_program_state(user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            resp
        } else {
            let regime = get_regime(RegimeType::Linear5x5);
            GetActiveTrainingProgramStateResponse {
                state: Some(TrainingProgramState {
                    regime_type: RegimeType::Linear5x5 as i32,
                    fields: payload_to_proto(&regime.default_state()),
                    updated_at: 0,
                    source: "default".to_string(),
                }),
                schema: Some(regime.state_schema()),
            }
        };
        let state = state_resp.state.ok_or_else(|| Status::internal("missing state"))?;
        let regime_type = RegimeType::try_from(state.regime_type).unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);
        let payload = payload_from_proto(&state.fields);
        let now = if at_time > 0 { at_time } else { now_unix() };
        let proposal = regime.propose_from_state(&payload, 0, now);
        let pending_updates = regime.pending_updates_for_state(&payload, 0, now)
            .into_iter().map(pending_update_to_proto).collect::<Vec<_>>();

        let active_workout_id = self.db.get_active_workout_id(user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .map(|(id, _)| id)
            .unwrap_or_default();

        let response = GetProposedWorkoutScheduleResponse {
            exercise_statuses: Vec::new(),
            active_workout_id,
            proposed_groups: proposal.proposed_groups,
            regime_context: Some(proposal.regime_context),
            session_readiness: Some(SessionReadiness {
                next_session_at: 0,
                last_session_at: 0,
                readiness_label: "Ready".to_string(),
                readiness_detail: String::new(),
                is_ready: true,
                is_overdue: false,
            }),
            suggested_workout_name: proposal.suggested_workout_name,
            pending_state_updates: pending_updates.clone(),
            can_start_workout: pending_updates.is_empty(),
            draft: self.db.get_workout_draft(user_id).await.map_err(|e| Status::internal(e.to_string()))?,
        };
        self.db.put_schedule_cache(user_id, &response).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(response)
    }

    /// Load proposed_sets + completed_sets for a workout and compute next_up + snapshot.
    async fn load_sets_and_compute(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> Result<(Vec<ProposedSet>, Vec<CompletedSet>, Option<ProposedSet>, Option<WorkoutStateSnapshot>), Status> {
        let proposed_sets = self.db.get_proposed_sets(workout_id).await.map_err(|e| Status::internal(e.to_string()))?;
        let completed_sets = self.db.get_completed_sets(workout_id).await.map_err(|e| Status::internal(e.to_string()))?;
        let active_proposed = active_proposed_sets(&proposed_sets);
        let next_up = compute_next_up_set(&active_proposed, &completed_sets);
        let snapshot = Some(workout_state_snapshot_from_state(&proposed_sets, &completed_sets, now_unix()));
        Ok((proposed_sets, completed_sets, next_up, snapshot))
    }

    /// Get session_id for a user (from active_workout_current or session membership).
    async fn get_session_id_for_user(&self, user_id: &str) -> Result<String, Status> {
        Ok(self.db.get_active_workout_id(user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .map(|(_, sid)| sid)
            .unwrap_or_default())
    }
}

#[tonic::async_trait]
impl WorkoutService for ScratchWorkoutService {
    async fn start_workout(
        &self,
        request: Request<StartWorkoutRequest>,
    ) -> Result<Response<StartWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let session_id = self.db.get_current_session_id_for_user(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .unwrap_or_default();
        let workout_id = Uuid::new_v4().to_string();
        let started_at = if req.started_at > 0 { req.started_at } else { now_unix() };
        let workout = Workout {
            id: workout_id.clone(),
            name: if req.name.is_empty() { "Workout".to_string() } else { req.name },
            start_time: started_at,
            end_time: 0,
            session_id: session_id.clone(),
        };
        let mut groups = req.exercise_groups;
        for (idx, group) in groups.iter_mut().enumerate() {
            if group.id.is_empty() {
                group.id = Uuid::new_v4().to_string();
            }
            group.workout_id = workout_id.clone();
            group.workout_order = idx as i32;
        }
        let mut proposed_sets = Vec::new();
        let mut order = 0;
        for group in &groups {
            let generated = generate_sets_for_group(&workout_id, group, order);
            order += generated.len() as i32;
            proposed_sets.extend(generated);
        }

        // Insert real rows
        self.db.insert_workout(&user_id, &workout, &groups, &proposed_sets).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let active = ActiveWorkout::new(workout, groups, proposed_sets, Vec::new());
        let response = start_workout_response_from_active(&active);

        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }
        Ok(Response::new(response))
    }

    async fn end_workout(
        &self,
        request: Request<EndWorkoutRequest>,
    ) -> Result<Response<EndWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let ended_at = if req.ended_at > 0 { req.ended_at } else { now_unix() };

        // Get session_id before ending
        let session_id = self.get_session_id_for_user(&user_id).await?;

        self.db.end_workout(&user_id, &req.workout_id, ended_at).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let workout = self.db.get_workout(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }
        Ok(Response::new(EndWorkoutResponse { workout: Some(workout) }))
    }

    async fn get_workout(
        &self,
        request: Request<GetWorkoutRequest>,
    ) -> Result<Response<GetWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let workout = self.db.load_workout_full(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        Ok(Response::new(workout))
    }

    async fn get_active_workout(
        &self,
        request: Request<GetActiveWorkoutRequest>,
    ) -> Result<Response<GetActiveWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let workout = if let Some((workout_id, _)) = self.db.get_active_workout_id(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            self.db.get_workout(&user_id, &workout_id).await
                .map_err(|e| Status::internal(e.to_string()))?
        } else {
            None
        };
        Ok(Response::new(GetActiveWorkoutResponse { workout }))
    }

    async fn list_workouts(
        &self,
        request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let workouts = self.db.list_workouts(&user_id).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(ListWorkoutsResponse { workouts }))
    }

    // ── Individual Set RPCs (targeted single-row SQL operations) ──

    async fn start_set(
        &self,
        request: Request<StartSetRequest>,
    ) -> Result<Response<StartSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        if req.workout_id.is_empty() || req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument("workout_id and proposed_set_id are required"));
        }

        // Look up proposed set for target values
        let proposed = self.db.get_proposed_set(&req.proposed_set_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::failed_precondition("Proposed set not found"))?;
        if proposed.cancelled {
            return Err(Status::failed_precondition("Proposed set is cancelled"));
        }

        // Check for existing in-progress set
        if let Some(_) = self.db.find_in_progress_completed_set(&req.workout_id, &req.proposed_set_id).await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            // Already started - load and return current state
            let (_, _, next_up, snapshot) = self.load_sets_and_compute(&user_id, &req.workout_id).await?;
            let existing = self.db.find_in_progress_completed_set(&req.workout_id, &req.proposed_set_id).await
                .map_err(|e| Status::internal(e.to_string()))?;
            return Ok(Response::new(StartSetResponse {
                completed_set: existing,
                next_up_set: next_up,
                state_snapshot: snapshot,
            }));
        }

        let started_at = if req.started_at > 0 { req.started_at } else { now_unix() };
        let completed_set = CompletedSet {
            id: Uuid::new_v4().to_string(),
            workout_id: req.workout_id.clone(),
            proposed_set_id: req.proposed_set_id.clone(),
            actual_reps: proposed.target_reps,
            actual_weight: proposed.target_weight,
            started_at,
            ended_at: 0,
            rest_until: 0,
        };

        self.db.insert_completed_set(&user_id, &completed_set).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let (_, _, next_up, snapshot) = self.load_sets_and_compute(&user_id, &req.workout_id).await?;

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(StartSetResponse {
            completed_set: Some(completed_set),
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    async fn complete_set(
        &self,
        request: Request<CompleteSetRequest>,
    ) -> Result<Response<CompleteSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();

        let proposed = self.db.get_proposed_set(&req.proposed_set_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::failed_precondition("Proposed set not found"))?;

        let ended_at = if req.completed_at > 0 { req.completed_at } else { now_unix() };

        // Compute rest_until
        let proposed_sets = self.db.get_proposed_sets(&req.workout_id).await.map_err(|e| Status::internal(e.to_string()))?;
        let completed_sets = self.db.get_completed_sets(&req.workout_id).await.map_err(|e| Status::internal(e.to_string()))?;

        let is_final = is_final_set_in_exercise_group_after_completion(
            &req.proposed_set_id, &proposed_sets, &completed_sets,
        );
        let mut rest_seconds = if req.actual_reps >= proposed.target_reps {
            proposed.rest_after_success as i64
        } else {
            proposed.rest_after_failure as i64
        };
        if is_final {
            rest_seconds = END_OF_EXERCISE_GROUP_REST_SECONDS;
        }
        let rest_until = ended_at + rest_seconds;

        // Find existing in-progress set and update it, or create new
        if let Some(existing) = self.db.find_in_progress_completed_set(&req.workout_id, &req.proposed_set_id).await
            .map_err(|e| Status::internal(e.to_string()))?
        {
            self.db.update_completed_set(&existing.id, req.actual_reps, req.actual_weight, ended_at, rest_until).await
                .map_err(|e| Status::internal(e.to_string()))?;

            let completed_set = CompletedSet {
                id: existing.id,
                workout_id: req.workout_id.clone(),
                proposed_set_id: req.proposed_set_id.clone(),
                actual_reps: req.actual_reps,
                actual_weight: req.actual_weight,
                started_at: existing.started_at,
                ended_at,
                rest_until,
            };

            let (_, _, next_up, snapshot) = self.load_sets_and_compute(&user_id, &req.workout_id).await?;

            let session_id = self.get_session_id_for_user(&user_id).await?;
            if !session_id.is_empty() {
                refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
            }

            Ok(Response::new(CompleteSetResponse {
                completed_set: Some(completed_set),
                next_up_set: next_up,
                state_snapshot: snapshot,
            }))
        } else {
            // No in-progress set - create a completed set directly
            let completed_set = CompletedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: req.workout_id.clone(),
                proposed_set_id: req.proposed_set_id.clone(),
                actual_reps: req.actual_reps,
                actual_weight: req.actual_weight,
                started_at: ended_at,
                ended_at,
                rest_until,
            };
            self.db.insert_completed_set(&user_id, &completed_set).await
                .map_err(|e| Status::internal(e.to_string()))?;

            let (_, _, next_up, snapshot) = self.load_sets_and_compute(&user_id, &req.workout_id).await?;

            let session_id = self.get_session_id_for_user(&user_id).await?;
            if !session_id.is_empty() {
                refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
            }

            Ok(Response::new(CompleteSetResponse {
                completed_set: Some(completed_set),
                next_up_set: next_up,
                state_snapshot: snapshot,
            }))
        }
    }

    async fn delete_completed_set(
        &self,
        request: Request<DeleteCompletedSetRequest>,
    ) -> Result<Response<DeleteCompletedSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();

        self.db.delete_completed_set(&req.completed_set_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let (_, _, next_up, snapshot) = self.load_sets_and_compute(&user_id, &req.workout_id).await?;

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(DeleteCompletedSetResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    async fn cancel_proposed_set(
        &self,
        request: Request<CancelProposedSetRequest>,
    ) -> Result<Response<CancelProposedSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();

        self.db.cancel_proposed_set(&req.proposed_set_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let (_, _, next_up, snapshot) = self.load_sets_and_compute(&user_id, &req.workout_id).await?;

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(CancelProposedSetResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    // ── Structural Mutations (load full state, apply, persist) ──

    async fn replace_exercise_group_plan(
        &self,
        request: Request<ReplaceExerciseGroupPlanRequest>,
    ) -> Result<Response<ReplaceExerciseGroupPlanResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();

        // Load full workout into ActiveWorkout
        let resp = self.db.load_workout_full(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        let mut active = active_from_get_workout_response(resp)?;

        // Apply the complex group plan replacement
        let (group, generated_sets) = apply_replace_exercise_group_plan(&mut active, &req)?;

        // Persist the full updated state back to real tables
        self.db.persist_workout_state(
            &user_id, &active.workout, &active.exercise_groups,
            &active.proposed_sets, &active.completed_sets,
        ).await.map_err(|e| Status::internal(e.to_string()))?;

        let active_proposed = active_proposed_sets(&active.proposed_sets);
        let next_up = compute_next_up_set(&active_proposed, &active.completed_sets);
        let snapshot = Some(workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, now_unix()));

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(ReplaceExerciseGroupPlanResponse {
            group,
            generated_sets,
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    async fn reorder_exercise_groups(
        &self,
        request: Request<ReorderExerciseGroupsRequest>,
    ) -> Result<Response<ReorderExerciseGroupsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();

        let resp = self.db.load_workout_full(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        let mut active = active_from_get_workout_response(resp)?;

        apply_reorder_exercise_groups(&mut active, &req)?;

        self.db.persist_workout_state(
            &user_id, &active.workout, &active.exercise_groups,
            &active.proposed_sets, &active.completed_sets,
        ).await.map_err(|e| Status::internal(e.to_string()))?;

        let active_proposed = active_proposed_sets(&active.proposed_sets);
        let next_up = compute_next_up_set(&active_proposed, &active.completed_sets);
        let snapshot = Some(workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, now_unix()));

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(ReorderExerciseGroupsResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    // ── Batch Mutations ──

    async fn append_workout_mutations(
        &self,
        request: Request<AppendWorkoutMutationsRequest>,
    ) -> Result<Response<AppendWorkoutMutationsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let first_mutation = req.mutations.first()
            .ok_or_else(|| Status::invalid_argument("mutations are required"))?;
        let workout_id = match first_mutation.mutation.as_ref() {
            Some(Mutation::StartSet(m)) => m.workout_id.clone(),
            Some(Mutation::CompleteSet(m)) => m.workout_id.clone(),
            Some(Mutation::CancelProposedSet(m)) => m.workout_id.clone(),
            Some(Mutation::DeleteCompletedSet(m)) => m.workout_id.clone(),
            Some(Mutation::EndWorkout(m)) => m.workout_id.clone(),
            Some(Mutation::ReplaceExerciseGroupPlan(m)) => m.workout_id.clone(),
            Some(Mutation::ReorderExerciseGroups(m)) => m.workout_id.clone(),
            None => return Err(Status::invalid_argument("mutation payload missing")),
        };

        // For batch mutations, load full state and use reducers (same as before)
        let resp = self.db.load_workout_full(&user_id, &workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        let mut active = active_from_get_workout_response(resp)?;
        let mut events = Vec::with_capacity(req.mutations.len());
        let mut applied = Vec::with_capacity(req.mutations.len());

        for mutation in req.mutations {
            let event_id = if mutation.event_id.is_empty() {
                Uuid::new_v4().to_string()
            } else {
                mutation.event_id.clone()
            };
            let recorded_at = if mutation.client_created_at > 0 { mutation.client_created_at } else { now_unix() };
            match mutation.mutation.ok_or_else(|| Status::invalid_argument("mutation missing"))? {
                Mutation::StartSet(req) => {
                    apply_start_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 2, req.encode_to_vec()));
                }
                Mutation::CompleteSet(req) => {
                    apply_complete_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 3, req.encode_to_vec()));
                }
                Mutation::DeleteCompletedSet(req) => {
                    apply_delete_completed_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 4, req.encode_to_vec()));
                }
                Mutation::CancelProposedSet(req) => {
                    apply_cancel_proposed_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 5, req.encode_to_vec()));
                }
                Mutation::EndWorkout(req) => {
                    let ended_at = if req.ended_at > 0 { req.ended_at } else { now_unix() };
                    active.workout.end_time = ended_at;
                    events.push((event_id.clone(), recorded_at, 6, req.encode_to_vec()));
                }
                Mutation::ReplaceExerciseGroupPlan(req) => {
                    apply_replace_exercise_group_plan(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 7, req.encode_to_vec()));
                }
                Mutation::ReorderExerciseGroups(req) => {
                    apply_reorder_exercise_groups(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 8, req.encode_to_vec()));
                }
            }
            applied.push(event_id);
        }

        // Append events
        self.db.append_workout_events(&user_id, &workout_id, &events).await
            .map_err(|e| Status::internal(e.to_string()))?;

        // Persist full state back to tables
        if active.workout.end_time > 0 {
            self.db.persist_workout_state(
                &user_id, &active.workout, &active.exercise_groups,
                &active.proposed_sets, &active.completed_sets,
            ).await.map_err(|e| Status::internal(e.to_string()))?;
            // End workout: remove active pointer
            self.db.end_workout(&user_id, &workout_id, active.workout.end_time).await
                .map_err(|e| Status::internal(e.to_string()))?;
        } else {
            self.db.persist_workout_state(
                &user_id, &active.workout, &active.exercise_groups,
                &active.proposed_sets, &active.completed_sets,
            ).await.map_err(|e| Status::internal(e.to_string()))?;
        }

        let response = get_workout_response_from_active(&active);

        if !active.workout.session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &active.workout.session_id).await?;
        }

        Ok(Response::new(AppendWorkoutMutationsResponse {
            applied_event_ids: applied,
            workout_state: Some(response),
        }))
    }

    // ── Heart Rate ──

    async fn append_workout_heart_rate(
        &self,
        request: Request<AppendWorkoutHeartRateRequest>,
    ) -> Result<Response<AppendWorkoutHeartRateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        self.db.insert_heart_rate_samples(&user_id, &req.workout_id, &req.samples).await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(AppendWorkoutHeartRateResponse { stored: req.samples.len() as i32 }))
    }

    async fn get_workout_heart_rate(
        &self,
        request: Request<GetWorkoutHeartRateRequest>,
    ) -> Result<Response<GetWorkoutHeartRateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let samples = self.db.get_workout_heart_rate(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(GetWorkoutHeartRateResponse { samples }))
    }

    // ── Schedule / Drafts ──

    async fn get_proposed_workout_schedule(
        &self,
        request: Request<GetProposedWorkoutScheduleRequest>,
    ) -> Result<Response<GetProposedWorkoutScheduleResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let response = self.generate_schedule(&user_id, req.at_time).await?;
        Ok(Response::new(response))
    }

    async fn save_workout_draft(
        &self,
        request: Request<SaveWorkoutDraftRequest>,
    ) -> Result<Response<SaveWorkoutDraftResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let draft = req.draft.ok_or_else(|| Status::invalid_argument("draft is required"))?;
        self.db.put_workout_draft(&user_id, &draft).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(SaveWorkoutDraftResponse { draft: Some(draft) }))
    }

    async fn clear_workout_draft(
        &self,
        request: Request<ClearWorkoutDraftRequest>,
    ) -> Result<Response<ClearWorkoutDraftResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        self.db.clear_workout_draft(&user_id).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(ClearWorkoutDraftResponse {}))
    }

    async fn rehydrate_workout_from_events(
        &self,
        _request: Request<RehydrateWorkoutFromEventsRequest>,
    ) -> Result<Response<RehydrateWorkoutFromEventsResponse>, Status> {
        Err(Status::unimplemented("scratch workout service does not support rehydration yet"))
    }
}
