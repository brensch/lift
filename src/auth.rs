use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::Mutex;
use url::Url;
use webauthn_rs::prelude::*;
use webauthn_rs::WebauthnBuilder;

use crate::db::CentralDb;

const CHALLENGE_TTL_SECS: u64 = 300; // 5 minutes

pub struct AuthState {
    pub webauthn: Arc<Webauthn>,
    pub central_db: CentralDb,
    reg_challenges: Arc<Mutex<HashMap<String, (PasskeyRegistration, Instant)>>>,
    auth_challenges: Arc<Mutex<HashMap<String, (DiscoverableAuthentication, Instant)>>>,
}

impl AuthState {
    pub fn new(central_db: CentralDb) -> Self {
        let rp_id = std::env::var("WEBAUTHN_RP_ID").unwrap_or_else(|_| "localhost".to_string());
        let rp_origin_str = std::env::var("WEBAUTHN_RP_ORIGIN")
            .unwrap_or_else(|_| "http://localhost:5173".to_string());
        let rp_origin = Url::parse(&rp_origin_str).expect("Invalid WEBAUTHN_RP_ORIGIN URL");

        let webauthn = WebauthnBuilder::new(&rp_id, &rp_origin)
            .expect("Failed to create WebauthnBuilder")
            .rp_name("Lift")
            .build()
            .expect("Failed to build Webauthn");

        Self {
            webauthn: Arc::new(webauthn),
            central_db,
            reg_challenges: Arc::new(Mutex::new(HashMap::new())),
            auth_challenges: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub async fn start_registration(
        &self,
        user_id: &str,
        username: &str,
    ) -> Result<CreationChallengeResponse, String> {
        let user_unique_id = uuid::Uuid::parse_str(user_id)
            .map_err(|e| format!("Invalid user_id UUID: {}", e))?;

        // Get existing credentials for this user to exclude
        let existing_cred_jsons = self
            .central_db
            .get_credentials_for_user(user_id)
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        let existing_creds: Vec<Passkey> = existing_cred_jsons
            .iter()
            .filter_map(|json| serde_json::from_str(json).ok())
            .collect();

        let exclude_credentials = if existing_creds.is_empty() {
            None
        } else {
            Some(existing_creds.iter().map(|c| c.cred_id().clone()).collect())
        };

        let (ccr, reg_state) = self
            .webauthn
            .start_passkey_registration(user_unique_id, username, username, exclude_credentials)
            .map_err(|e| format!("WebAuthn error: {}", e))?;

        let mut challenges = self.reg_challenges.lock().await;
        self.cleanup_expired_reg(&mut challenges);
        challenges.insert(user_id.to_string(), (reg_state, Instant::now()));

        Ok(ccr)
    }

    pub async fn finish_registration(
        &self,
        user_id: &str,
        reg: &RegisterPublicKeyCredential,
    ) -> Result<(), String> {
        let mut challenges = self.reg_challenges.lock().await;
        let (reg_state, _) = challenges
            .remove(user_id)
            .ok_or_else(|| "No pending registration challenge".to_string())?;

        let passkey = self
            .webauthn
            .finish_passkey_registration(reg, &reg_state)
            .map_err(|e| format!("WebAuthn registration failed: {}", e))?;

        // Use serde to serialize the credential ID for the DB key
        let cred_id = format!("{:?}", passkey.cred_id());
        let cred_json =
            serde_json::to_string(&passkey).map_err(|e| format!("Serialization error: {}", e))?;

        self.central_db
            .store_credential(&cred_id, user_id, &cred_json)
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        Ok(())
    }

    pub async fn start_authentication(
        &self,
    ) -> Result<(String, RequestChallengeResponse), String> {
        let (rcr, auth_state) = self
            .webauthn
            .start_discoverable_authentication()
            .map_err(|e| format!("WebAuthn error: {}", e))?;

        let challenge_id = uuid::Uuid::new_v4().to_string();

        let mut challenges = self.auth_challenges.lock().await;
        self.cleanup_expired_auth(&mut challenges);
        challenges.insert(challenge_id.clone(), (auth_state, Instant::now()));

        Ok((challenge_id, rcr))
    }

    pub async fn finish_authentication(
        &self,
        challenge_id: &str,
        cred: &PublicKeyCredential,
    ) -> Result<(String, String, String), String> {
        let mut challenges = self.auth_challenges.lock().await;
        let (auth_state, _) = challenges
            .remove(challenge_id)
            .ok_or_else(|| "No pending authentication challenge".to_string())?;
        drop(challenges);

        // Step 1: identify the user from the credential response
        let (user_uuid, _cred_id_bytes) = self
            .webauthn
            .identify_discoverable_authentication(cred)
            .map_err(|e| format!("WebAuthn identify failed: {}", e))?;

        let user_id = user_uuid.to_string();

        // Step 2: load this user's credentials
        let user_cred_jsons = self
            .central_db
            .get_credentials_for_user(&user_id)
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        let discoverable_keys: Vec<DiscoverableKey> = user_cred_jsons
            .iter()
            .filter_map(|json| {
                serde_json::from_str::<Passkey>(json)
                    .ok()
                    .map(|pk| DiscoverableKey::from(pk))
            })
            .collect();

        if discoverable_keys.is_empty() {
            return Err("No credentials found for user".to_string());
        }

        // Step 3: finish authentication
        let _auth_result = self
            .webauthn
            .finish_discoverable_authentication(cred, auth_state, &discoverable_keys)
            .map_err(|e| format!("WebAuthn authentication failed: {}", e))?;

        // Step 4: create session
        let token = self
            .central_db
            .create_auth_session(&user_id)
            .await
            .map_err(|e| format!("DB error: {}", e))?;

        // Get username
        let user = self
            .central_db
            .get_user(&user_id)
            .await
            .map_err(|e| format!("DB error: {}", e))?
            .ok_or_else(|| "User not found".to_string())?;

        Ok((token, user_id, user.name))
    }

    fn cleanup_expired_reg(&self, map: &mut HashMap<String, (PasskeyRegistration, Instant)>) {
        let now = Instant::now();
        map.retain(|_, (_, created)| now.duration_since(*created).as_secs() < CHALLENGE_TTL_SECS);
    }

    fn cleanup_expired_auth(
        &self,
        map: &mut HashMap<String, (DiscoverableAuthentication, Instant)>,
    ) {
        let now = Instant::now();
        map.retain(|_, (_, created)| now.duration_since(*created).as_secs() < CHALLENGE_TTL_SECS);
    }
}
