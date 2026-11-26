//! The MCP server: assistants (LLM clients) read a person's training and
//! set their program, over Streamable HTTP at `/api/mcp`, signed in the
//! OAuth 2.1 way the MCP authorization spec describes.
//!
//! - `/.well-known/oauth-protected-resource` says which authorization
//!   server signs in for `/api/mcp`: this one.
//! - `/.well-known/oauth-authorization-server` is its metadata.
//! - `/api/oauth/register` registers a client (RFC 7591), public: PKCE,
//!   no secret. Or a client needn't register: its `client_id` can be an
//!   `https://` URL serving its metadata, fetched when it connects
//!   (`cimd.rs`).
//! - The authorization endpoint is the website's `/connect` page: the
//!   person signs in with their passkey and allows the client, and the page
//!   answers through `AssistantService` (`src/server/assistant.rs`), which
//!   issues a code bound to the PKCE challenge.
//! - `/api/oauth/token` exchanges the code (with its verifier) for an
//!   access token, and a refresh token for new ones.
//!
//! The tools (`tools.rs`) read through the core's `View` and write through
//! its `Call`, as the phone does: a program set here is a `ProgramSet`
//! placed in the account's log and streamed to the person's phones.

use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, State};
use axum::http::{header, HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

use crate::db::{Client, ServerDb};

pub mod cimd;
mod tools;

/// The only scope: read the person's training, set their program.
pub const SCOPE: &str = "program";
/// What a granted assistant may do, as the consent page lists it.
pub const CAN: [&str; 3] = [
    "Read your workouts, sets and lifts",
    "Read and set your program: your workouts, exercises and how each progresses",
    "It can't record or delete training",
];
/// The MCP revisions this server speaks, newest first.
const PROTOCOL_VERSIONS: [&str; 3] = ["2025-06-18", "2025-03-26", "2024-11-05"];
/// A request body over this is refused: a program is at most 512 KB.
const MAX_BODY: usize = 1024 * 1024;

#[derive(Clone)]
pub struct Mcp {
    pub db: ServerDb,
    /// Where people reach this server: `https://schlift.com`.
    pub origin: String,
    /// Registrations each address may make: open to anyone, and the cap
    /// on clients nobody connected drops the oldest, so a flood would push
    /// out the ones people were about to allow.
    pub registrations: std::sync::Arc<crate::rate::Limiter>,
    /// Client ID metadata documents: fetched, checked and kept a while.
    pub cimd: std::sync::Arc<cimd::Cimd>,
}

/// Registrations from one address: a few at once, then one a minute.
const REGISTRATIONS_BURST: u32 = 10;
const REGISTRATION_REFILL: std::time::Duration = std::time::Duration::from_secs(60);
/// The redirect URIs a client registers, together.
const MAX_REDIRECT_BYTES: usize = 2048;

/// The address a request came from: the last X-Forwarded-For entry, which
/// Caddy (or the apps' own listener) sets from the peer.
fn caller(headers: &HeaderMap) -> String {
    let ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.rsplit(',').next())
        .map(str::trim)
        .unwrap_or_default();
    crate::rate::client_key(ip)
}

impl Mcp {
    pub fn new(db: ServerDb) -> Self {
        let origin = std::env::var("PUBLIC_ORIGIN")
            .or_else(|_| std::env::var("WEBAUTHN_RP_ORIGIN"))
            .unwrap_or_else(|_| "http://localhost:50051".to_string());
        Self {
            db,
            origin: origin.trim_end_matches('/').to_string(),
            registrations: std::sync::Arc::new(crate::rate::Limiter::new(
                REGISTRATIONS_BURST,
                REGISTRATION_REFILL,
            )),
            cimd: std::sync::Arc::new(cimd::Cimd::https()),
        }
    }

    /// The MCP endpoint's URL: the resource tokens are for.
    pub fn resource(&self) -> String {
        format!("{}/api/mcp", self.origin)
    }

    fn resource_metadata_url(&self) -> String {
        format!("{}/.well-known/oauth-protected-resource", self.origin)
    }
}

pub fn router(mcp: Mcp) -> Router {
    Router::new()
        .route(
            "/.well-known/oauth-protected-resource",
            get(protected_resource),
        )
        .route(
            "/.well-known/oauth-protected-resource/api/mcp",
            get(protected_resource),
        )
        .route(
            "/.well-known/oauth-authorization-server",
            get(authorization_server),
        )
        .route("/api/oauth/register", post(register))
        .route("/api/oauth/token", post(token))
        .route("/api/mcp", post(endpoint).get(no_stream).delete(no_stream))
        .layer(DefaultBodyLimit::max(MAX_BODY))
        .with_state(mcp)
}

async fn protected_resource(State(mcp): State<Mcp>) -> Json<Value> {
    Json(json!({
        "resource": mcp.resource(),
        "authorization_servers": [mcp.origin],
        "scopes_supported": [SCOPE],
        "bearer_methods_supported": ["header"],
        "resource_name": "Schlift",
    }))
}

async fn authorization_server(State(mcp): State<Mcp>) -> Json<Value> {
    Json(json!({
        "issuer": mcp.origin,
        "authorization_endpoint": format!("{}/connect", mcp.origin),
        "token_endpoint": format!("{}/api/oauth/token", mcp.origin),
        "registration_endpoint": format!("{}/api/oauth/register", mcp.origin),
        "scopes_supported": [SCOPE],
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "code_challenge_methods_supported": ["S256"],
        "token_endpoint_auth_methods_supported": ["none"],
        "client_id_metadata_document_supported": true,
    }))
}

/// An OAuth error (RFC 6749 §5.2), as JSON.
fn oauth_error(status: StatusCode, error: &str, description: &str) -> Response {
    (
        status,
        Json(json!({ "error": error, "error_description": description })),
    )
        .into_response()
}

/// A redirect URI a client may register: https, or plain http to this
/// machine (a desktop client listening on a loopback port).
pub fn redirect_allowed(uri: &str) -> bool {
    let Ok(url) = url::Url::parse(uri) else {
        return false;
    };
    if url.fragment().is_some() || uri.len() > 2048 {
        return false;
    }
    match url.scheme() {
        "https" => url.host_str().is_some(),
        "http" => matches!(url.host_str(), Some("localhost" | "127.0.0.1" | "[::1]")),
        // A native app's own scheme (`cursor://`, `vscode://`): it names
        // an app on the person's device. Never one a browser runs or reads
        // itself: the consent page navigates to it.
        scheme => !matches!(
            scheme,
            "javascript" | "data" | "file" | "vbscript" | "blob" | "about" | "ftp" | "ws" | "wss"
        ),
    }
}

async fn register(State(mcp): State<Mcp>, headers: HeaderMap, body: Bytes) -> Response {
    if !mcp.registrations.allow(&caller(&headers)) {
        return oauth_error(
            StatusCode::TOO_MANY_REQUESTS,
            "invalid_request",
            "too many registrations; try again later",
        );
    }
    let Ok(request) = serde_json::from_slice::<Value>(&body) else {
        return oauth_error(
            StatusCode::BAD_REQUEST,
            "invalid_client_metadata",
            "not JSON",
        );
    };
    let name = request
        .get("client_name")
        .and_then(Value::as_str)
        .unwrap_or("An assistant")
        .trim();
    let name: String = name.chars().take(80).collect();
    let uris: Vec<String> = request
        .get("redirect_uris")
        .and_then(Value::as_array)
        .map(|uris| {
            uris.iter()
                .filter_map(|u| u.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    if uris.is_empty()
        || uris.len() > 10
        || uris.iter().map(String::len).sum::<usize>() > MAX_REDIRECT_BYTES
        || !uris.iter().all(|u| redirect_allowed(u))
    {
        return oauth_error(
            StatusCode::BAD_REQUEST,
            "invalid_redirect_uri",
            "1 to 10 redirect URIs: https, a loopback http address, or an app's own scheme",
        );
    }
    match mcp.db.register_assistant(&name, &uris).await {
        Ok(client) => (
            StatusCode::CREATED,
            Json(json!({
                "client_id": client.client_id,
                "client_name": client.client_name,
                "redirect_uris": client.redirect_uris,
                "token_endpoint_auth_method": "none",
                "grant_types": ["authorization_code", "refresh_token"],
                "response_types": ["code"],
                "scope": SCOPE,
            })),
        )
            .into_response(),
        Err(error) => {
            tracing::error!(%error, "registering an assistant");
            oauth_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "try again",
            )
        }
    }
}

/// `base64url(SHA-256(verifier))`, unpadded: what a PKCE S256 challenge is.
pub fn pkce_challenge(verifier: &str) -> String {
    base64url(&Sha256::digest(verifier.as_bytes()))
}

fn base64url(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let n = (u32::from(chunk[0]) << 16)
            | (u32::from(*chunk.get(1).unwrap_or(&0)) << 8)
            | u32::from(*chunk.get(2).unwrap_or(&0));
        for i in 0..chunk.len() + 1 {
            out.push(ALPHABET[(n >> (18 - 6 * i) & 63) as usize] as char);
        }
    }
    out
}

async fn token(State(mcp): State<Mcp>, body: Bytes) -> Response {
    let form: std::collections::HashMap<String, String> =
        url::form_urlencoded::parse(&body).into_owned().collect();
    let field = |name: &str| form.get(name).map(String::as_str).unwrap_or("");
    let client_id = field("client_id");
    let issued = match field("grant_type") {
        "authorization_code" => {
            let consent = match mcp.db.take_assistant_code(field("code")).await {
                Ok(Some(consent)) => consent,
                Ok(None) => {
                    return oauth_error(
                        StatusCode::BAD_REQUEST,
                        "invalid_grant",
                        "the code is unknown, used or expired",
                    )
                }
                Err(error) => {
                    tracing::error!(%error, "taking an assistant code");
                    return oauth_error(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "");
                }
            };
            if consent.client_id != client_id
                || consent.redirect_uri != field("redirect_uri")
                || pkce_challenge(field("code_verifier")) != consent.code_challenge
            {
                return oauth_error(
                    StatusCode::BAD_REQUEST,
                    "invalid_grant",
                    "the client, redirect URI or code verifier doesn't match the consent",
                );
            }
            // A metadata document's client must still list the redirect it
            // was allowed with. (A refresh doesn't fetch: the grant is the
            // person's, and the document's host being down mustn't cut
            // them off.)
            if cimd::is_url(client_id) {
                match mcp.cimd.resolve(client_id).await {
                    Ok(client) if client.redirect_uris.contains(&consent.redirect_uri) => {}
                    Ok(_) => {
                        return oauth_error(
                            StatusCode::BAD_REQUEST,
                            "invalid_grant",
                            "the client's metadata no longer lists the redirect URI",
                        )
                    }
                    Err(error) => {
                        return oauth_error(StatusCode::BAD_REQUEST, "invalid_client", &error)
                    }
                }
            }
            mcp.db.grant_assistant(&consent).await.map(Some)
        }
        "refresh_token" => {
            mcp.db
                .refresh_assistant(field("refresh_token"), client_id)
                .await
        }
        _ => {
            return oauth_error(
                StatusCode::BAD_REQUEST,
                "unsupported_grant_type",
                "authorization_code or refresh_token",
            )
        }
    };
    match issued {
        Ok(Some(tokens)) => (
            StatusCode::OK,
            [(header::CACHE_CONTROL, "no-store")],
            Json(json!({
                "access_token": tokens.access_token,
                "token_type": "Bearer",
                "expires_in": tokens.expires_in,
                "refresh_token": tokens.refresh_token,
                "scope": tokens.scope,
            })),
        )
            .into_response(),
        Ok(None) => oauth_error(
            StatusCode::BAD_REQUEST,
            "invalid_grant",
            "the refresh token is unknown, used, expired or revoked",
        ),
        Err(error) => {
            tracing::error!(%error, "issuing assistant tokens");
            oauth_error(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "")
        }
    }
}

/// The client a client id names: registered here, or the metadata
/// document at the URL it is, fetched and kept as a client row so a grant
/// can name it.
async fn client(mcp: &Mcp, client_id: &str) -> Result<Client, String> {
    // Logged, not told: the caller isn't signed in.
    fn failed(error: impl std::fmt::Display) -> String {
        tracing::error!(%error, "reading an assistant");
        "Something went wrong; try again".to_string()
    }
    if cimd::is_url(client_id) {
        let client = mcp.cimd.resolve(client_id).await?;
        mcp.db.save_url_assistant(&client).await.map_err(failed)?;
        return Ok(client);
    }
    mcp.db
        .assistant_client(client_id)
        .await
        .map_err(failed)?
        .ok_or_else(|| "This assistant isn't registered".to_string())
}

/// What the consent page calls a client: its name, and for a metadata
/// document the host that vouches for it ("Claude (claude.ai)").
pub fn display_name(client: &Client) -> String {
    match url::Url::parse(&client.client_id) {
        Ok(url) if cimd::is_url(&client.client_id) => format!(
            "{} ({})",
            client.client_name,
            url.host_str().unwrap_or_default()
        ),
        _ => client.client_name.clone(),
    }
}

/// A consent request checked against its client: the client registered
/// (or its metadata document read), the redirect one it lists, PKCE S256,
/// and for this server.
pub async fn check_connect(
    mcp: &Mcp,
    request: &schlift_core::pb::ConnectRequest,
) -> Result<Client, String> {
    let client = client(mcp, &request.client_id).await?;
    if !client.redirect_uris.contains(&request.redirect_uri) {
        return Err("The return address isn't one this assistant registered".into());
    }
    if request.code_challenge_method != "S256"
        || !(43..=128).contains(&request.code_challenge.len())
    {
        return Err("The request needs a PKCE S256 challenge".into());
    }
    if !request.resource.is_empty()
        && request.resource.trim_end_matches('/') != mcp.resource()
        && request.resource.trim_end_matches('/') != mcp.origin
    {
        return Err("The request is for another server".into());
    }
    if !request.scope.split_whitespace().all(|s| s == SCOPE) {
        return Err(format!("The only scope is {SCOPE:?}"));
    }
    Ok(client)
}

/// The redirect back to the client: `code` and `state`, or an error.
pub fn redirect_back(redirect_uri: &str, params: &[(&str, &str)]) -> String {
    let mut url = match url::Url::parse(redirect_uri) {
        Ok(url) => url,
        Err(_) => return redirect_uri.to_string(),
    };
    {
        let mut query = url.query_pairs_mut();
        for (k, v) in params {
            if !v.is_empty() {
                query.append_pair(k, v);
            }
        }
    }
    url.to_string()
}

async fn no_stream() -> Response {
    (
        StatusCode::METHOD_NOT_ALLOWED,
        [(header::ALLOW, "POST")],
        "This server answers each request; it opens no stream.",
    )
        .into_response()
}

/// Who a request comes from: the person and the assistant's name, from
/// its bearer token; None when it has none that works.
async fn bearer(mcp: &Mcp, headers: &HeaderMap) -> Option<(String, String)> {
    let token = headers
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .map(str::trim)?;
    mcp.db.assistant_access(token).await.ok().flatten()
}

/// 401, with where to sign in.
fn unauthorized(mcp: &Mcp) -> Response {
    let challenge = format!(
        "Bearer resource_metadata=\"{}\", scope=\"{SCOPE}\"",
        mcp.resource_metadata_url()
    );
    (
        StatusCode::UNAUTHORIZED,
        [(header::WWW_AUTHENTICATE, challenge)],
        Json(json!({ "error": "invalid_token" })),
    )
        .into_response()
}

fn rpc_result(id: &Value, result: Value) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "result": result })
}

fn rpc_error(id: &Value, code: i64, message: &str) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "error": { "code": code, "message": message } })
}

async fn endpoint(State(mcp): State<Mcp>, headers: HeaderMap, body: Bytes) -> Response {
    let Some((user_id, client_name)) = bearer(&mcp, &headers).await else {
        return unauthorized(&mcp);
    };
    let Ok(message) = serde_json::from_slice::<Value>(&body) else {
        return Json(rpc_error(&Value::Null, -32700, "not JSON")).into_response();
    };
    if !message.is_object() {
        return Json(rpc_error(
            &Value::Null,
            -32600,
            "one JSON-RPC message per request",
        ))
        .into_response();
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let method = message
        .get("method")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let params = message.get("params").cloned().unwrap_or(Value::Null);
    // A notification or a response from the client: taken, nothing to say.
    if message.get("id").is_none() || method.is_empty() {
        return StatusCode::ACCEPTED.into_response();
    }
    let reply = match method {
        "initialize" => {
            let asked = params
                .get("protocolVersion")
                .and_then(Value::as_str)
                .unwrap_or("");
            let version = PROTOCOL_VERSIONS
                .iter()
                .find(|v| **v == asked)
                .unwrap_or(&PROTOCOL_VERSIONS[0]);
            rpc_result(
                &id,
                json!({
                    "protocolVersion": version,
                    "capabilities": { "tools": { "listChanged": false } },
                    "serverInfo": { "name": "schlift", "version": env!("CARGO_PKG_VERSION") },
                    "instructions": tools::INSTRUCTIONS,
                }),
            )
        }
        "ping" => rpc_result(&id, json!({})),
        "tools/list" => rpc_result(&id, json!({ "tools": tools::list() })),
        "tools/call" => {
            let name = params.get("name").and_then(Value::as_str).unwrap_or("");
            let arguments = params.get("arguments").cloned().unwrap_or(json!({}));
            match tools::call(&mcp, &user_id, &client_name, name, &arguments).await {
                Ok(result) => rpc_result(&id, result),
                Err(tools::Failure::Unknown) => rpc_error(&id, -32602, "no such tool"),
                Err(tools::Failure::Tool(message)) => rpc_result(
                    &id,
                    json!({ "content": [{ "type": "text", "text": message }], "isError": true }),
                ),
                Err(tools::Failure::Server(error)) => {
                    tracing::error!(%error, tool = name, "an assistant's tool call");
                    rpc_error(&id, -32603, "the server failed; try again")
                }
            }
        }
        _ => rpc_error(&id, -32601, "no such method"),
    };
    Json(reply).into_response()
}

#[cfg(test)]
mod tests;
