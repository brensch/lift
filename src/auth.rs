use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::Mutex;
use tracing::error;
use url::Url;
use webauthn_rs::prelude::*;
use webauthn_rs::WebauthnBuilder;

use crate::db::ServerDb;

const CHALLENGE_TTL_SECS: u64 = 300;

enum AuthChallengeState {
    Discoverable(DiscoverableAuthentication),
    Passkey {
        state: PasskeyAuthentication,
        user_id: String,
    },
}

struct PendingAuthChallenge {
    state: AuthChallengeState,
    issued_challenge: String,
    created_at: Instant,
}

pub struct AuthState {
    pub webauthn: Arc<Webauthn>,
    pub db: ServerDb,
    reg_challenges: Arc<Mutex<HashMap<String, (PasskeyRegistration, String, Instant)>>>,
    auth_challenges: Arc<Mutex<HashMap<String, PendingAuthChallenge>>>,
}

impl AuthState {
    pub fn new(db: ServerDb) -> Self {
        let rp_id = std::env::var("WEBAUTHN_RP_ID").unwrap_or_else(|_| "localhost".to_string());
        let rp_origin_str = std::env::var("WEBAUTHN_RP_ORIGIN")
            .unwrap_or_else(|_| "http://localhost:5173".to_string());
        let rp_origin = Url::parse(&rp_origin_str).expect("Invalid WEBAUTHN_RP_ORIGIN URL");

        let mut builder = WebauthnBuilder::new(&rp_id, &rp_origin)
            .expect("Failed to create WebauthnBuilder")
            .rp_name("Schlift");

        if let Ok(android_origins) = std::env::var("WEBAUTHN_ANDROID_ORIGINS") {
            for origin in android_origins
                .split(',')
                .map(str::trim)
                .filter(|s| !s.is_empty())
            {
                let android_origin =
                    Url::parse(origin).expect("Invalid entry in WEBAUTHN_ANDROID_ORIGINS");
                builder = builder.append_allowed_origin(&android_origin);
            }
        } else if let Ok(android_origin_str) = std::env::var("WEBAUTHN_ANDROID_ORIGIN") {
            let android_origin =
                Url::parse(&android_origin_str).expect("Invalid WEBAUTHN_ANDROID_ORIGIN URL");
            builder = builder.append_allowed_origin(&android_origin);
        }

        let webauthn = builder.build().expect("Failed to build Webauthn");

        Self {
            webauthn: Arc::new(webauthn),
            db,
            reg_challenges: Arc::new(Mutex::new(HashMap::new())),
            auth_challenges: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub async fn start_registration(
        &self,
        username: &str,
    ) -> Result<(String, CreationChallengeResponse), String> {
        let user_id = uuid::Uuid::new_v4().to_string();
        let user_unique_id =
            uuid::Uuid::parse_str(&user_id).map_err(|e| format!("Invalid UUID: {}", e))?;

        let (ccr, reg_state) = self
            .webauthn
            .start_passkey_registration(user_unique_id, username, username, None)
            .map_err(|e| format!("WebAuthn error: {}", e))?;

        let mut challenges = self.reg_challenges.lock().await;
        self.cleanup_expired_reg(&mut challenges);
        challenges.insert(
            user_id.clone(),
            (reg_state, username.to_string(), Instant::now()),
        );

        Ok((user_id, ccr))
    }

    pub async fn finish_registration(
        &self,
        user_id: &str,
        reg: &RegisterPublicKeyCredential,
        created_at_ip: Option<String>,
        name: Option<String>,
    ) -> Result<String, String> {
        let mut challenges = self.reg_challenges.lock().await;
        let (reg_state, username, _) = challenges
            .remove(user_id)
            .ok_or_else(|| "No pending registration challenge".to_string())?;
        drop(challenges);

        let passkey = self
            .webauthn
            .finish_passkey_registration(reg, &reg_state)
            .map_err(|e| format!("WebAuthn registration failed: {}", e))?;

        self.db
            .create_user_with_id(user_id, &username)
            .await
            .map_err(|e| format!("Failed to create user: {}", e))?;

        let cred_id = format!("{:?}", passkey.cred_id());
        let mut cred_val =
            serde_json::to_value(&passkey).map_err(|e| format!("Serialization error: {}", e))?;
        if let Some(n) = name {
            if let Some(obj) = cred_val.as_object_mut() {
                obj.insert("cred_name".to_string(), serde_json::Value::String(n));
            }
        }
        let cred_json =
            serde_json::to_string(&cred_val).map_err(|e| format!("Serialization error: {}", e))?;

        self.db
            .store_credential(&cred_id, user_id, &cred_json, created_at_ip.as_deref())
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        Ok(username)
    }

    pub async fn start_add_passkey(
        &self,
        user_id: &str,
        username: &str,
    ) -> Result<CreationChallengeResponse, String> {
        let user_unique_id =
            uuid::Uuid::parse_str(user_id).map_err(|e| format!("Invalid UUID: {}", e))?;

        let cred_jsons = self
            .db
            .get_credentials_for_user(user_id)
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        let existing_creds: Vec<Passkey> = cred_jsons
            .iter()
            .filter_map(|json| serde_json::from_str(json).ok())
            .collect();

        let exclude_cred_ids: Option<Vec<_>> = if existing_creds.is_empty() {
            None
        } else {
            Some(
                existing_creds
                    .iter()
                    .map(|pk| pk.cred_id().clone())
                    .collect(),
            )
        };

        let (ccr, reg_state) = self
            .webauthn
            .start_passkey_registration(user_unique_id, username, username, exclude_cred_ids)
            .map_err(|e| format!("WebAuthn error: {}", e))?;

        let mut challenges = self.reg_challenges.lock().await;
        self.cleanup_expired_reg(&mut challenges);
        challenges.insert(
            user_id.to_string(),
            (reg_state, username.to_string(), Instant::now()),
        );

        Ok(ccr)
    }

    pub async fn finish_add_passkey(
        &self,
        user_id: &str,
        reg: &RegisterPublicKeyCredential,
        created_at_ip: Option<String>,
        name: Option<String>,
    ) -> Result<(), String> {
        let mut challenges = self.reg_challenges.lock().await;
        let (reg_state, _, _) = challenges
            .remove(user_id)
            .ok_or_else(|| "No pending add-passkey challenge".to_string())?;
        drop(challenges);

        let passkey = self
            .webauthn
            .finish_passkey_registration(reg, &reg_state)
            .map_err(|e| format!("WebAuthn registration failed: {}", e))?;

        let cred_id = format!("{:?}", passkey.cred_id());
        let mut cred_val =
            serde_json::to_value(&passkey).map_err(|e| format!("Serialization error: {}", e))?;
        if let Some(n) = name {
            if let Some(obj) = cred_val.as_object_mut() {
                obj.insert("cred_name".to_string(), serde_json::Value::String(n));
            }
        }
        let cred_json =
            serde_json::to_string(&cred_val).map_err(|e| format!("Serialization error: {}", e))?;

        self.db
            .store_credential(&cred_id, user_id, &cred_json, created_at_ip.as_deref())
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        Ok(())
    }

    pub async fn start_authentication(&self) -> Result<(String, RequestChallengeResponse), String> {
        let (rcr, auth_state) = self
            .webauthn
            .start_discoverable_authentication()
            .map_err(|e| format!("WebAuthn error: {}", e))?;

        let challenge_id = uuid::Uuid::new_v4().to_string();

        let mut challenges = self.auth_challenges.lock().await;
        self.cleanup_expired_auth(&mut challenges);
        challenges.insert(
            challenge_id.clone(),
            PendingAuthChallenge {
                state: AuthChallengeState::Discoverable(auth_state),
                issued_challenge: encode_challenge(&rcr.public_key.challenge),
                created_at: Instant::now(),
            },
        );

        Ok((challenge_id, rcr))
    }

    pub async fn start_authentication_with_username(
        &self,
        username: &str,
    ) -> Result<(String, RequestChallengeResponse), String> {
        let user = self
            .db
            .get_user_by_name(username)
            .await
            .map_err(|e| format!("DB error: {}", e))?
            .ok_or_else(|| "User not found".to_string())?;

        let cred_jsons = self
            .db
            .get_credentials_for_user(&user.id)
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        let creds: Vec<Passkey> = cred_jsons
            .iter()
            .filter_map(|json| serde_json::from_str(json).ok())
            .collect();

        if creds.is_empty() {
            return Err("No credentials found for user".to_string());
        }

        let (rcr, auth_state) = self
            .webauthn
            .start_passkey_authentication(&creds)
            .map_err(|e| format!("WebAuthn error: {}", e))?;

        let challenge_id = uuid::Uuid::new_v4().to_string();

        let mut challenges = self.auth_challenges.lock().await;
        self.cleanup_expired_auth(&mut challenges);
        challenges.insert(
            challenge_id.clone(),
            PendingAuthChallenge {
                state: AuthChallengeState::Passkey {
                    state: auth_state,
                    user_id: user.id,
                },
                issued_challenge: encode_challenge(&rcr.public_key.challenge),
                created_at: Instant::now(),
            },
        );

        Ok((challenge_id, rcr))
    }

    pub async fn finish_authentication(
        &self,
        challenge_id: &str,
        credential_json: &str,
        cred: &PublicKeyCredential,
    ) -> Result<(String, String, String), String> {
        let mut challenges = self.auth_challenges.lock().await;
        let pending = challenges
            .remove(challenge_id)
            .ok_or_else(|| "No pending authentication challenge".to_string())?;
        drop(challenges);

        let client_challenge = extract_client_response_challenge(credential_json);
        let client_origin = extract_client_response_origin(credential_json);
        let allowed_origins = self
            .webauthn
            .get_allowed_origins()
            .iter()
            .map(|origin| origin.as_str().to_string())
            .collect::<Vec<_>>()
            .join(",");
        if let Some(ref client_challenge) = client_challenge {
            if client_challenge != &pending.issued_challenge {
                error!(
                    "WebAuthn challenge mismatch before verification: challenge_id={}, issued_challenge={}, client_challenge={}, client_origin={}, allowed_origins={}",
                    challenge_id,
                    pending.issued_challenge,
                    client_challenge,
                    client_origin.as_deref().unwrap_or("<unparseable>"),
                    allowed_origins
                );
            }
        } else {
            error!(
                "WebAuthn credential missing parseable client challenge: challenge_id={}, client_origin={}, allowed_origins={}",
                challenge_id,
                client_origin.as_deref().unwrap_or("<unparseable>"),
                allowed_origins
            );
        }

        let (auth_result, user_id) = match pending.state {
            AuthChallengeState::Discoverable(auth_state) => {
                let (user_uuid, _) = self
                    .webauthn
                    .identify_discoverable_authentication(cred)
                    .map_err(|e| format!("WebAuthn identify failed: {}", e))?;

                let user_id = user_uuid.to_string();
                let user_cred_jsons = self
                    .db
                    .get_credentials_for_user(&user_id)
                    .await
                    .map_err(|e| format!("DB error: {}", e))?;

                let discoverable_keys: Vec<DiscoverableKey> = user_cred_jsons
                    .iter()
                    .filter_map(|json| {
                        serde_json::from_str::<Passkey>(json)
                            .ok()
                            .map(DiscoverableKey::from)
                    })
                    .collect();

                if discoverable_keys.is_empty() {
                    return Err("No credentials found for user".to_string());
                }

                let result = self
                    .webauthn
                    .finish_discoverable_authentication(cred, auth_state, &discoverable_keys)
                    .map_err(|e| {
                        format!(
                            "WebAuthn authentication failed: {} (challenge_id={}, issued_challenge={}, client_challenge={}, client_origin={}, allowed_origins={})",
                            e,
                            challenge_id,
                            pending.issued_challenge,
                            client_challenge.as_deref().unwrap_or("<unparseable>"),
                            client_origin.as_deref().unwrap_or("<unparseable>"),
                            allowed_origins
                        )
                    })?;

                (result, user_id)
            }
            AuthChallengeState::Passkey { state, user_id } => {
                let result = self
                    .webauthn
                    .finish_passkey_authentication(cred, &state)
                    .map_err(|e| {
                        format!(
                            "WebAuthn authentication failed: {} (challenge_id={}, issued_challenge={}, client_challenge={}, client_origin={}, allowed_origins={})",
                            e,
                            challenge_id,
                            pending.issued_challenge,
                            client_challenge.as_deref().unwrap_or("<unparseable>"),
                            client_origin.as_deref().unwrap_or("<unparseable>"),
                            allowed_origins
                        )
                    })?;

                (result, user_id)
            }
        };

        self.update_credential_counter(&user_id, &auth_result).await;

        let token = self
            .db
            .create_auth_session(&user_id)
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        let user = self
            .db
            .get_user(&user_id)
            .await
            .map_err(|e| format!("DB error: {}", e))?
            .ok_or_else(|| "User not found".to_string())?;

        Ok((token, user_id, user.name))
    }

    async fn update_credential_counter(&self, user_id: &str, auth_result: &AuthenticationResult) {
        let cred_jsons = match self.db.get_credentials_for_user(user_id).await {
            Ok(jsons) => jsons,
            Err(_) => return,
        };

        for json in &cred_jsons {
            let mut pk: Passkey = match serde_json::from_str(json) {
                Ok(pk) => pk,
                Err(_) => continue,
            };

            if let Some(true) = pk.update_credential(auth_result) {
                let cred_id = format!("{:?}", pk.cred_id());
                let new_json = match serde_json::to_string(&pk) {
                    Ok(j) => j,
                    Err(_) => continue,
                };
                let _ = self.db.update_credential_json(&cred_id, &new_json).await;
            }
        }
    }

    fn cleanup_expired_reg(
        &self,
        map: &mut HashMap<String, (PasskeyRegistration, String, Instant)>,
    ) {
        let now = Instant::now();
        map.retain(|_, (_, _, created)| {
            now.duration_since(*created).as_secs() < CHALLENGE_TTL_SECS
        });
    }

    fn cleanup_expired_auth(&self, map: &mut HashMap<String, PendingAuthChallenge>) {
        let now = Instant::now();
        map.retain(|_, pending| {
            now.duration_since(pending.created_at).as_secs() < CHALLENGE_TTL_SECS
        });
    }
}

fn extract_client_response_challenge(credential_json: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(credential_json).ok()?;
    let encoded = value.get("response")?.get("clientDataJSON")?.as_str()?;
    let decoded = URL_SAFE_NO_PAD.decode(encoded).ok()?;
    let client_data: serde_json::Value = serde_json::from_slice(&decoded).ok()?;
    client_data.get("challenge")?.as_str().map(str::to_string)
}

fn extract_client_response_origin(credential_json: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(credential_json).ok()?;
    let encoded = value.get("response")?.get("clientDataJSON")?.as_str()?;
    let decoded = URL_SAFE_NO_PAD.decode(encoded).ok()?;
    let client_data: serde_json::Value = serde_json::from_slice(&decoded).ok()?;
    client_data.get("origin")?.as_str().map(str::to_string)
}

fn encode_challenge(challenge: &Base64UrlSafeData) -> String {
    serde_json::to_string(challenge)
        .unwrap_or_else(|_| "\"<serialization-failed>\"".to_string())
        .trim_matches('"')
        .to_string()
}
