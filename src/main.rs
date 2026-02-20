use axum::{
    extract::Extension,
    http::StatusCode,
    response::Html,
    routing::{get, post},
    Json,
};
use http::{header::HeaderName, Method};
use lift::workout::v1::{
    auth_service_server::AuthServiceServer, multiplayer_service_server::MultiplayerServiceServer,
    user_service_server::UserServiceServer, workout_service_server::WorkoutServiceServer,
};
use log::{error, info};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use webauthn_rs::prelude::PublicKeyCredential;

mod auth;
mod db;
mod progress;
mod scheduler;
mod service_auth;
mod service_group;
mod service_user;
mod service_workout;
mod state;

use auth::AuthState;
use db::CentralDb;
use service_auth::MyAuthService;
use service_group::GroupService;
use service_user::MyUserService;
use service_workout::MyWorkoutService;
use state::AppState;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    env_logger::init();
    info!("Starting server...");

    // Catch panics and log them
    std::panic::set_hook(Box::new(|panic_info| {
        let location = panic_info
            .location()
            .map(|l| format!("{}:{}", l.file(), l.line()))
            .unwrap_or_else(|| "unknown".to_string());
        let payload = panic_info.payload();
        let message = if let Some(s) = payload.downcast_ref::<&str>() {
            *s
        } else if let Some(s) = payload.downcast_ref::<String>() {
            s.as_str()
        } else {
            "no message"
        };
        error!("PANIC at {}: {}", location, message);
    }));

    let central_db = CentralDb::new().await?;
    let app_state = Arc::new(AppState::new());

    // Spawn periodic checkpoint task (flushes dirty workouts every 30s)
    state::spawn_checkpoint_task(app_state.clone(), central_db.clone());

    let addr: SocketAddr = "0.0.0.0:50051".parse()?;
    let workout_service = MyWorkoutService::new(central_db.clone(), app_state.clone());
    let user_service = MyUserService::new(central_db.clone());
    let group_service = GroupService::new(central_db.clone(), app_state.clone());

    let auth_state = Arc::new(AuthState::new(central_db.clone()));
    let auth_service = MyAuthService {
        auth_state: auth_state.clone(),
    };

    // CORS layer for browser access
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers(Any)
        .allow_methods([Method::POST, Method::OPTIONS, Method::GET])
        .expose_headers([
            HeaderName::from_static("grpc-status"),
            HeaderName::from_static("grpc-message"),
            HeaderName::from_static("grpc-status-details-bin"),
            HeaderName::from_static("x-grpc-web"),
            HeaderName::from_static("x-user-agent"),
        ]);

    let workout_service_web = tonic_web::enable(WorkoutServiceServer::new(workout_service));
    let user_service_web = tonic_web::enable(UserServiceServer::new(user_service));
    let multiplayer_service_web = tonic_web::enable(MultiplayerServiceServer::new(group_service));
    let auth_service_web = tonic_web::enable(AuthServiceServer::new(auth_service));

    // Build gRPC router
    #[allow(deprecated)]
    let grpc_router = tonic::transport::Server::builder()
        .accept_http1(true)
        .add_service(workout_service_web)
        .add_service(user_service_web)
        .add_service(multiplayer_service_web)
        .add_service(auth_service_web)
        .into_router();

    // Assetlinks handler for Android passkey verification
    let app = grpc_router
        .route("/", get(root_handler))
        .route("/privacy", get(privacy_handler))
        .route("/forget", get(forget_handler))
        .route("/api/forget/start", post(forget_start_handler))
        .route("/api/forget/confirm", post(forget_confirm_handler))
        .route("/.well-known/assetlinks.json", get(assetlinks_handler))
        .layer(Extension(auth_state))
        .layer(Extension(app_state))
        .layer(cors);

    println!("Server listening on {} (gRPC-Web)", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await?;

    Ok(())
}

async fn root_handler() -> Html<&'static str> {
    Html(include_str!("../index.html"))
}

async fn privacy_handler() -> Html<&'static str> {
    Html(PRIVACY_HTML)
}

async fn forget_handler() -> Html<&'static str> {
    Html(FORGET_HTML)
}

#[derive(Serialize)]
struct ForgetStartResponse {
    challenge_id: String,
    options_json: serde_json::Value,
}

#[derive(Deserialize)]
struct ForgetConfirmRequest {
    challenge_id: String,
    credential_json: serde_json::Value,
}

#[derive(Serialize)]
struct ForgetConfirmResponse {
    deleted_user_id: String,
}

async fn forget_start_handler(
    Extension(auth_state): Extension<Arc<AuthState>>,
) -> Result<Json<ForgetStartResponse>, (StatusCode, String)> {
    let (challenge_id, options) = auth_state
        .start_authentication()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    let options_json = serde_json::to_value(options)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(ForgetStartResponse {
        challenge_id,
        options_json,
    }))
}

async fn forget_confirm_handler(
    Extension(auth_state): Extension<Arc<AuthState>>,
    Extension(app_state): Extension<Arc<AppState>>,
    Json(req): Json<ForgetConfirmRequest>,
) -> Result<Json<ForgetConfirmResponse>, (StatusCode, String)> {
    let credential: PublicKeyCredential =
        serde_json::from_value(req.credential_json).map_err(|e| {
            (
                StatusCode::BAD_REQUEST,
                format!("Invalid credential JSON: {}", e),
            )
        })?;

    let (session_token, user_id, _) = auth_state
        .finish_authentication(&req.challenge_id, &credential)
        .await
        .map_err(|e| (StatusCode::UNAUTHORIZED, e))?;

    auth_state
        .central_db
        .delete_user_account_and_data(&user_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    app_state.remove_user_data(&user_id);

    let _ = auth_state
        .central_db
        .invalidate_auth_session(&session_token)
        .await;

    Ok(Json(ForgetConfirmResponse {
        deleted_user_id: user_id,
    }))
}

async fn assetlinks_handler() -> Json<serde_json::Value> {
    // Always include the Play/upload signing fingerprint.
    // Optionally include ANDROID_CERT_SHA256 (e.g. local debug cert) for dev installs.
    let mut fingerprints = vec![
        "1F:0C:6B:FD:A7:5A:7D:18:7A:AE:53:1B:33:30:CD:11:7F:31:F5:05:8E:05:A9:21:FF:23:B0:E8:74:C2:21:EC".to_string(),
    ];
    if let Ok(env_fp) = std::env::var("ANDROID_CERT_SHA256") {
        let env_fp = env_fp.trim();
        if !env_fp.is_empty() && !fingerprints.iter().any(|f| f == env_fp) {
            fingerprints.push(env_fp.to_string());
        }
    }
    Json(serde_json::json!([{
        "relation": ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
        "target": {
            "namespace": "android_app",
            "package_name": "com.brensch.lift",
            "sha256_cert_fingerprints": fingerprints
        }
    }]))
}

const PRIVACY_HTML: &str = r#"<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Lift Privacy Policy</title>
  <style>
    body { margin: 0; font-family: -apple-system, Segoe UI, Roboto, sans-serif; background: #f7f8fb; color: #14213d; }
    main { max-width: 860px; margin: 0 auto; padding: 32px 20px 56px; }
    h1 { margin: 0 0 8px; }
    h2 { margin-top: 28px; }
    p, li { line-height: 1.55; }
    .card { background: #fff; border-radius: 12px; padding: 20px; box-shadow: 0 10px 30px rgba(20,33,61,.08); }
  </style>
</head>
<body>
<main>
  <h1>Lift Privacy Policy</h1>
  <p>Effective date: February 20, 2026</p>
  <div class="card">
    <p>This policy explains what data Lift collects, why we collect it, and how you can control or delete it.</p>
    <h2>Data We Collect</h2>
    <ul>
      <li>Account data: username, account creation time, and authentication credentials (for passkey login).</li>
      <li>Workout data: workouts, exercise groups, planned sets, completed sets, and related timestamps.</li>
      <li>Optional device telemetry: heart-rate samples from supported wearable integrations.</li>
      <li>Security data: session tokens and limited metadata needed to protect accounts and detect abuse.</li>
    </ul>
    <h2>How We Use Data</h2>
    <ul>
      <li>Provide core functionality (saving workouts, syncing sessions, and powering progress/history views).</li>
      <li>Secure accounts and authenticate users through passkeys and session management.</li>
      <li>Operate and improve reliability of the service.</li>
    </ul>
    <h2>Data Sharing</h2>
    <p>We do not sell your personal data. We only share data when required to run the service, meet legal obligations, or protect users and the platform.</p>
    <h2>Data Retention</h2>
    <p>We retain data while your account is active. You can request immediate deletion of your account and associated data at <a href="/forget">/forget</a>.</p>
    <h2>Your Choices</h2>
    <ul>
      <li>You can stop using the service at any time.</li>
      <li>You can delete your account and workout data permanently through the account deletion page.</li>
    </ul>
    <h2>Contact</h2>
    <p>For privacy requests, contact the Lift project maintainer.</p>
  </div>
</main>
</body>
</html>
"#;

const FORGET_HTML: &str = r#"<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Delete Lift Account</title>
  <style>
    body { margin: 0; font-family: -apple-system, Segoe UI, Roboto, sans-serif; background: linear-gradient(120deg, #fffaf2, #eaf6ff); color: #112; }
    main { max-width: 720px; margin: 0 auto; padding: 36px 20px 60px; }
    .card { background: #fff; border-radius: 14px; padding: 22px; box-shadow: 0 16px 34px rgba(10,20,40,.1); }
    button { border: none; border-radius: 10px; padding: 12px 16px; cursor: pointer; font-size: 15px; font-weight: 600; background: #003566; color: #fff; }
    button:disabled { opacity: .6; cursor: not-allowed; }
    .warn { color: #9a3412; font-weight: 600; }
    .ok { color: #166534; font-weight: 600; }
    .err { color: #b91c1c; font-weight: 600; }
    code { background: #f3f4f6; padding: 2px 6px; border-radius: 6px; }
  </style>
</head>
<body>
<main>
  <h1>Delete your Lift account</h1>
  <div class="card">
    <p class="warn">This permanently deletes your account, passkeys, workout history, heart-rate data, and active sessions.</p>
    <p>To continue, confirm with a passkey in this browser.</p>
    <button id="deleteBtn">Delete my data with passkey</button>
    <p id="status" aria-live="polite"></p>
    <p>If your browser does not support passkeys, open this page in a modern browser with WebAuthn support.</p>
  </div>
</main>
<script>
const deleteBtn = document.getElementById('deleteBtn');
const statusEl = document.getElementById('status');

function setStatus(text, cls) {
  statusEl.className = cls || '';
  statusEl.textContent = text;
}

deleteBtn.addEventListener('click', async () => {
  deleteBtn.disabled = true;
  setStatus('Starting secure passkey verification...', '');

  try {
    if (!window.PublicKeyCredential || !PublicKeyCredential.parseRequestOptionsFromJSON) {
      throw new Error('Passkeys are not supported in this browser.');
    }

    const startRes = await fetch('/api/forget/start', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{}',
    });
    if (!startRes.ok) {
      throw new Error(await startRes.text());
    }
    const startData = await startRes.json();
    const publicKey = PublicKeyCredential.parseRequestOptionsFromJSON(startData.options_json);
    const credential = await navigator.credentials.get({ publicKey });
    if (!credential) {
      throw new Error('No passkey response was returned.');
    }
    const credentialJson = credential.toJSON ? credential.toJSON() : null;
    if (!credentialJson) {
      throw new Error('Credential serialization failed.');
    }

    setStatus('Deleting your account data...', '');
    const confirmRes = await fetch('/api/forget/confirm', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        challenge_id: startData.challenge_id,
        credential_json: credentialJson,
      }),
    });
    if (!confirmRes.ok) {
      throw new Error(await confirmRes.text());
    }

    const deleted = await confirmRes.json();
    setStatus(`Account deleted for user id: ${deleted.deleted_user_id}`, 'ok');
  } catch (err) {
    setStatus(err instanceof Error ? err.message : 'Delete request failed', 'err');
    deleteBtn.disabled = false;
  }
});
</script>
</body>
</html>
"#;
