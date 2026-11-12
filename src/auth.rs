use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::Mutex;
use tracing::{error, warn};
use url::Url;
use webauthn_rs::prelude::*;
use webauthn_rs::WebauthnBuilder;

use crate::db::ServerDb;

const CHALLENGE_TTL_SECS: u64 = 300;
/// Ceremonies in flight (of each kind, within the TTL) past these are
/// refused rather than remembered: per client, so one caller of the
/// unauthenticated starts can't crowd out everyone else's sign-ins; and in
/// all, so many callers can't grow the maps without bound.
const MAX_PENDING_PER_CLIENT: usize = 20;
const MAX_PENDING_CHALLENGES: usize = 100_000;

/// Why a ceremony was refused. The caller is told `message`; what went
/// wrong in detail is logged where it happened, never sent: a failure used
/// to be shown to the user with the challenge and every allowed origin in it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Refusal {
    /// No ceremony is in flight under that id: it took over
    /// `CHALLENGE_TTL_SECS`, was already finished, or never started.
    Expired,
    /// No account holds the passkey presented: its account or the passkey
    /// was deleted, or its sign-up never finished.
    UnknownPasskey,
    /// The passkey answered without verifying its user (no biometric or
    /// PIN), which passkeys here require.
    NotVerified,
    /// The passkey is already held by an account.
    AlreadyRegistered,
    /// The name was taken while the sign-up was under way.
    NameTaken,
    /// Nobody holds that username.
    UnknownUser,
    /// Too many ceremonies in flight.
    Busy,
    /// Too many requests to recover the account are waiting.
    TooManyRecoveries,
    /// The credential did not verify.
    Rejected,
    /// The server failed.
    Internal,
}

impl Refusal {
    /// Filed with the attempt (`auth_attempts.reason`) and counted on the
    /// stats page.
    pub fn slug(self) -> &'static str {
        match self {
            Refusal::Expired => "expired",
            Refusal::UnknownPasskey => "unknown_passkey",
            Refusal::NotVerified => "not_verified",
            Refusal::AlreadyRegistered => "already_registered",
            Refusal::NameTaken => "name_taken",
            Refusal::UnknownUser => "unknown_user",
            Refusal::Busy => "busy",
            Refusal::TooManyRecoveries => "too_many_recoveries",
            Refusal::Rejected => "rejected",
            Refusal::Internal => "internal",
        }
    }

    pub fn message(self) -> &'static str {
        match self {
            Refusal::Expired => "That took too long. Try again.",
            Refusal::UnknownPasskey => "That passkey isn't linked to an account here.",
            Refusal::NotVerified => {
                "Your passkey manager didn't confirm it was you. Unlock it and try again."
            }
            Refusal::AlreadyRegistered => "That passkey is already registered.",
            Refusal::NameTaken => "User already exists",
            Refusal::UnknownUser => "Nobody has that username.",
            Refusal::Busy => "Too many sign-ins in progress; try again shortly",
            Refusal::TooManyRecoveries => {
                "Too many requests are waiting for that account. Ask Brendan to clear them."
            }
            Refusal::Rejected => "That passkey didn't check out. Try again.",
            Refusal::Internal => "Something went wrong on the server. Try again.",
        }
    }
}

/// What a finished sign-in came to.
pub enum SignIn {
    /// A login: its token, the user's id and name.
    In {
        token: String,
        user_id: String,
        username: String,
    },
    /// The passkey is one held for a recovery an admin has not approved
    /// yet: it signs nothing in, and whoever holds it may read that
    /// request (its code, how it stands).
    AwaitingApproval { request_id: String },
}

/// The server failed: logged here, and the caller hears only that it did.
fn internal(what: &str, error: impl std::fmt::Display) -> Refusal {
    error!(%error, "{what}");
    Refusal::Internal
}

/// webauthn-rs refused a credential.
fn refused(what: &str, error: WebauthnError) -> Refusal {
    warn!(%error, "{what}");
    match error {
        WebauthnError::UserNotVerified => Refusal::NotVerified,
        _ => Refusal::Rejected,
    }
}

/// The credential id as a passkey's own JSON spells it (base64url): what
/// `passkeys.credential_id` holds.
pub fn credential_key(id: &CredentialID) -> String {
    serde_json::to_value(id)
        .ok()
        .and_then(|v| v.as_str().map(str::to_string))
        .unwrap_or_default()
}

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
    client: String,
    created_at: Instant,
}

/// A registration handshake in flight: the webauthn-rs state, the username it
/// was started for, who started it, and when (for TTL expiry).
struct PendingRegistration {
    state: PasskeyRegistration,
    username: String,
    client: String,
    created_at: Instant,
}

/// A passkey being made for an account whose owner lost theirs. `user_id`
/// is None when nobody holds the username that was asked for: the ceremony
/// runs the same, and nothing comes of it.
struct PendingRecovery {
    state: PasskeyRegistration,
    user_id: Option<String>,
    client: String,
    created_at: Instant,
}

pub struct AuthState {
    pub webauthn: Arc<Webauthn>,
    pub db: ServerDb,
    /// Sign-ups in flight, by the user id they will create.
    reg_challenges: Arc<Mutex<HashMap<String, PendingRegistration>>>,
    /// Passkeys being added to a signed-in account, by its user id: apart
    /// from sign-ups, so an unauthenticated RegisterFinish naming a user
    /// can't spend their add-passkey challenge.
    add_challenges: Arc<Mutex<HashMap<String, PendingRegistration>>>,
    auth_challenges: Arc<Mutex<HashMap<String, PendingAuthChallenge>>>,
    /// Recoveries in flight, by request id.
    recovery_challenges: Arc<Mutex<HashMap<String, PendingRecovery>>>,
    /// Mixed into the user id a recovery for a name nobody holds is given,
    /// so the same name gets the same id each time, as a real one would.
    nobody_key: [u8; 16],
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
        }

        let webauthn = builder.build().expect("Failed to build Webauthn");

        Self {
            webauthn: Arc::new(webauthn),
            db,
            reg_challenges: Arc::new(Mutex::new(HashMap::new())),
            add_challenges: Arc::new(Mutex::new(HashMap::new())),
            auth_challenges: Arc::new(Mutex::new(HashMap::new())),
            recovery_challenges: Arc::new(Mutex::new(HashMap::new())),
            nobody_key: *uuid::Uuid::new_v4().as_bytes(),
        }
    }

    pub async fn start_registration(
        &self,
        username: &str,
        client: &str,
    ) -> Result<(String, CreationChallengeResponse), Refusal> {
        let user_unique_id = uuid::Uuid::new_v4();
        let user_id = user_unique_id.to_string();

        let (ccr, reg_state) = self
            .webauthn
            .start_passkey_registration(user_unique_id, username, username, None)
            .map_err(|e| internal("starting a sign-up", e))?;

        let mut challenges = self.reg_challenges.lock().await;
        admit_registration(&mut challenges, client)?;
        challenges.insert(
            user_id.clone(),
            PendingRegistration {
                state: reg_state,
                username: username.to_string(),
                client: client.to_string(),
                created_at: Instant::now(),
            },
        );

        Ok((user_id, ccr))
    }

    pub async fn finish_registration(
        &self,
        user_id: &str,
        reg: &RegisterPublicKeyCredential,
        created_at_ip: Option<String>,
        name: Option<String>,
    ) -> Result<String, Refusal> {
        let mut challenges = self.reg_challenges.lock().await;
        let PendingRegistration {
            state, username, ..
        } = challenges.remove(user_id).ok_or(Refusal::Expired)?;
        drop(challenges);

        let passkey = self
            .webauthn
            .finish_passkey_registration(reg, &state)
            .map_err(|e| refused("sign-up passkey refused", e))?;
        let cred_id = credential_key(passkey.cred_id());
        self.refuse_registered(&cred_id).await?;
        let cred_json = stored_passkey_json(&passkey, name)?;

        if let Err(error) = self
            .db
            .create_user_with_passkey(
                user_id,
                &username,
                &cred_id,
                &cred_json,
                created_at_ip.as_deref(),
            )
            .await
        {
            // The name was free when the sign-up started; someone else may
            // have finished with it since.
            return Err(match self.db.get_user_by_name(&username).await {
                Ok(Some(_)) => Refusal::NameTaken,
                _ => internal("creating the account", error),
            });
        }

        Ok(username)
    }

    pub async fn start_add_passkey(
        &self,
        user_id: &str,
        username: &str,
        client: &str,
    ) -> Result<CreationChallengeResponse, Refusal> {
        let user_unique_id =
            uuid::Uuid::parse_str(user_id).map_err(|e| internal("user id is not a uuid", e))?;

        let cred_jsons = self
            .db
            .get_credentials_for_user(user_id)
            .await
            .map_err(|e| internal("reading passkeys", e))?;

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
            .map_err(|e| internal("starting to add a passkey", e))?;

        let mut challenges = self.add_challenges.lock().await;
        admit_registration(&mut challenges, client)?;
        challenges.insert(
            user_id.to_string(),
            PendingRegistration {
                state: reg_state,
                username: username.to_string(),
                client: client.to_string(),
                created_at: Instant::now(),
            },
        );

        Ok(ccr)
    }

    pub async fn finish_add_passkey(
        &self,
        user_id: &str,
        reg: &RegisterPublicKeyCredential,
        created_at_ip: Option<String>,
        name: Option<String>,
    ) -> Result<(), Refusal> {
        let mut challenges = self.add_challenges.lock().await;
        let pending = challenges.remove(user_id).ok_or(Refusal::Expired)?;
        drop(challenges);

        let passkey = self
            .webauthn
            .finish_passkey_registration(reg, &pending.state)
            .map_err(|e| refused("added passkey refused", e))?;
        let cred_id = credential_key(passkey.cred_id());
        self.refuse_registered(&cred_id).await?;

        let cred_json = stored_passkey_json(&passkey, name)?;

        self.db
            .store_credential(&cred_id, user_id, &cred_json, created_at_ip.as_deref())
            .await
            .map_err(|e| internal("storing a passkey", e))?;

        Ok(())
    }

    /// Start making a passkey for the account holding `username`, for
    /// someone who has lost theirs. Nothing of the account's is excluded or
    /// revealed beyond its id; what `finish_recovery` stores is inert until
    /// an admin approves it. A name nobody holds is answered the same way
    /// (a typo, or someone guessing): the ceremony runs for a made-up id,
    /// and `finish_recovery` stores nothing.
    pub async fn start_recovery(
        &self,
        username: &str,
        client: &str,
    ) -> Result<(String, CreationChallengeResponse), Refusal> {
        let user = self
            .db
            .get_user_by_name(username)
            .await
            .map_err(|e| internal("reading the user", e))?;
        let (user_unique_id, name) = match &user {
            Some(user) => (
                uuid::Uuid::parse_str(&user.id)
                    .map_err(|e| internal("user id is not a uuid", e))?,
                user.name.as_str(),
            ),
            None => (self.nobodys_id(username), username),
        };
        let (ccr, state) = self
            .webauthn
            .start_passkey_registration(user_unique_id, name, name, None)
            .map_err(|e| internal("starting a recovery", e))?;

        let request_id = uuid::Uuid::new_v4().to_string();
        let mut challenges = self.recovery_challenges.lock().await;
        challenges.retain(|_, pending| live(pending.created_at));
        admit(challenges.values().map(|p| p.client.as_str()), client)?;
        challenges.insert(
            request_id.clone(),
            PendingRecovery {
                state,
                user_id: user.map(|user| user.id),
                client: client.to_string(),
                created_at: Instant::now(),
            },
        );
        Ok((request_id, ccr))
    }

    /// The id a recovery for a name nobody holds is made for: the same for
    /// the same name while this server runs, and shaped like a real one.
    fn nobodys_id(&self, username: &str) -> uuid::Uuid {
        use sha2::{Digest, Sha256};
        let digest = Sha256::new()
            .chain_update(self.nobody_key)
            .chain_update(username.trim().to_lowercase())
            .finalize();
        let mut bytes = [0u8; 16];
        bytes.copy_from_slice(&digest[..16]);
        uuid::Builder::from_random_bytes(bytes).into_uuid()
    }

    /// Hold the new passkey aside under a code for an admin to approve:
    /// the code, when the request lapses, and whether there is an account
    /// behind it. With none, the passkey is checked like any other and
    /// then dropped: the code is one nothing will ever approve.
    pub async fn finish_recovery(
        &self,
        request_id: &str,
        reg: &RegisterPublicKeyCredential,
        created_at_ip: Option<String>,
        platform: &str,
    ) -> Result<(String, i64, bool), Refusal> {
        let pending = self
            .recovery_challenges
            .lock()
            .await
            .remove(request_id)
            .ok_or(Refusal::Expired)?;
        let passkey = self
            .webauthn
            .finish_passkey_registration(reg, &pending.state)
            .map_err(|e| refused("recovery passkey refused", e))?;
        let Some(user_id) = pending.user_id else {
            let now = crate::time::now_unix();
            return Ok((
                crate::db::nobodys_code(request_id),
                now + crate::db::RECOVERY_TTL_SECONDS,
                false,
            ));
        };
        let cred_id = credential_key(passkey.cred_id());
        let cred_json = stored_passkey_json(&passkey, Some("recovery key".to_string()))?;
        let (code, expires_at) = self
            .db
            .store_recovery(
                request_id,
                &user_id,
                &cred_id,
                &cred_json,
                created_at_ip.as_deref(),
                platform,
            )
            .await
            .map_err(|e| internal("storing a recovery", e))??;
        Ok((code, expires_at, true))
    }

    pub async fn start_authentication(
        &self,
        client: &str,
    ) -> Result<(String, RequestChallengeResponse), Refusal> {
        let (rcr, auth_state) = self
            .webauthn
            .start_discoverable_authentication()
            .map_err(|e| internal("starting a sign-in", e))?;

        let challenge_id = uuid::Uuid::new_v4().to_string();

        let mut challenges = self.auth_challenges.lock().await;
        admit_authentication(&mut challenges, client)?;
        challenges.insert(
            challenge_id.clone(),
            PendingAuthChallenge {
                state: AuthChallengeState::Discoverable(auth_state),
                issued_challenge: encode_challenge(&rcr.public_key.challenge),
                client: client.to_string(),
                created_at: Instant::now(),
            },
        );

        Ok((challenge_id, rcr))
    }

    pub async fn start_authentication_with_username(
        &self,
        username: &str,
        client: &str,
    ) -> Result<(String, RequestChallengeResponse), Refusal> {
        let user = self
            .db
            .get_user_by_name(username)
            .await
            .map_err(|e| internal("reading the user", e))?
            .ok_or(Refusal::UnknownUser)?;

        let cred_jsons = self
            .db
            .get_credentials_for_user(&user.id)
            .await
            .map_err(|e| internal("reading passkeys", e))?;

        let creds: Vec<Passkey> = cred_jsons
            .iter()
            .filter_map(|json| serde_json::from_str(json).ok())
            .collect();

        if creds.is_empty() {
            return Err(Refusal::UnknownUser);
        }

        let (rcr, auth_state) = self
            .webauthn
            .start_passkey_authentication(&creds)
            .map_err(|e| internal("starting a sign-in", e))?;

        let challenge_id = uuid::Uuid::new_v4().to_string();

        let mut challenges = self.auth_challenges.lock().await;
        admit_authentication(&mut challenges, client)?;
        challenges.insert(
            challenge_id.clone(),
            PendingAuthChallenge {
                state: AuthChallengeState::Passkey {
                    state: auth_state,
                    user_id: user.id,
                },
                issued_challenge: encode_challenge(&rcr.public_key.challenge),
                client: client.to_string(),
                created_at: Instant::now(),
            },
        );

        Ok((challenge_id, rcr))
    }

    pub async fn finish_authentication(
        &self,
        challenge_id: &str,
        cred: &PublicKeyCredential,
    ) -> Result<SignIn, Refusal> {
        let pending = self
            .auth_challenges
            .lock()
            .await
            .remove(challenge_id)
            .ok_or(Refusal::Expired)?;

        // What the client signed over, for the log when it fails.
        let (client_challenge, client_origin) = client_data(cred);
        let failed = |e: WebauthnError| {
            let allowed_origins = self
                .webauthn
                .get_allowed_origins()
                .iter()
                .map(|origin| origin.as_str().to_string())
                .collect::<Vec<_>>()
                .join(",");
            warn!(
                error = %e,
                %challenge_id,
                issued_challenge = %pending.issued_challenge,
                client_challenge = client_challenge.as_deref().unwrap_or("<unparseable>"),
                client_origin = client_origin.as_deref().unwrap_or("<unparseable>"),
                %allowed_origins,
                "sign-in refused"
            );
            match e {
                WebauthnError::UserNotVerified => Refusal::NotVerified,
                _ => Refusal::Rejected,
            }
        };

        let (auth_result, user_id) = match pending.state {
            AuthChallengeState::Discoverable(auth_state) => {
                let (user_uuid, _) = self
                    .webauthn
                    .identify_discoverable_authentication(cred)
                    .map_err(|e| refused("sign-in names no account", e))?;

                let user_id = user_uuid.to_string();
                let passkeys: Vec<Passkey> = self
                    .db
                    .get_credentials_for_user(&user_id)
                    .await
                    .map_err(|e| internal("reading passkeys", e))?
                    .iter()
                    .filter_map(|json| serde_json::from_str(json).ok())
                    .collect();

                // A passkey the device still holds for an account or
                // passkey that is gone, or for a sign-up that never
                // finished: said apart from a bad signature, so the app can
                // tell the passkey manager to drop it.
                let presented: &[u8] = cred.raw_id.as_ref();
                if !passkeys.iter().any(|pk| {
                    let held: &[u8] = pk.cred_id().as_ref();
                    held == presented
                }) {
                    // It may be one made at /recover and still waiting:
                    // then this is its maker, back for their code.
                    let waiting = self
                        .db
                        .held_passkeys(&user_id)
                        .await
                        .map_err(|e| internal("reading recoveries", e))?
                        .into_iter()
                        .find_map(|(request_id, json)| {
                            let passkey: Passkey = serde_json::from_str(&json).ok()?;
                            let held: &[u8] = passkey.cred_id().as_ref();
                            (held == presented).then_some((request_id, passkey))
                        });
                    let Some((request_id, passkey)) = waiting else {
                        warn!(%challenge_id, %user_id, "sign-in with a passkey no account holds");
                        return Err(Refusal::UnknownPasskey);
                    };
                    // Only for a signature the held passkey really made.
                    self.webauthn
                        .finish_discoverable_authentication(
                            cred,
                            auth_state,
                            &[DiscoverableKey::from(passkey)],
                        )
                        .map_err(failed)?;
                    return Ok(SignIn::AwaitingApproval { request_id });
                }

                let discoverable_keys: Vec<DiscoverableKey> =
                    passkeys.into_iter().map(DiscoverableKey::from).collect();
                let result = self
                    .webauthn
                    .finish_discoverable_authentication(cred, auth_state, &discoverable_keys)
                    .map_err(failed)?;
                (result, user_id)
            }
            AuthChallengeState::Passkey { state, user_id } => {
                let result = self
                    .webauthn
                    .finish_passkey_authentication(cred, &state)
                    .map_err(failed)?;
                (result, user_id)
            }
        };

        self.update_credential_counter(&user_id, &auth_result).await;

        let token = self
            .db
            .create_auth_session(&user_id)
            .await
            .map_err(|e| internal("creating a login", e))?;

        let user = self
            .db
            .get_user(&user_id)
            .await
            .map_err(|e| internal("reading the user", e))?
            .ok_or(Refusal::UnknownPasskey)?;

        Ok(SignIn::In {
            token,
            user_id,
            username: user.name,
        })
    }

    /// A passkey already held by an account can't be registered again, to
    /// that account or another.
    async fn refuse_registered(&self, cred_id: &str) -> Result<(), Refusal> {
        match self.db.credential_registered(cred_id).await {
            Ok(false) => Ok(()),
            Ok(true) => Err(Refusal::AlreadyRegistered),
            Err(e) => Err(internal("reading passkeys", e)),
        }
    }

    async fn update_credential_counter(&self, user_id: &str, auth_result: &AuthenticationResult) {
        // The login stands either way; a counter left behind only blunts
        // webauthn-rs's check for a cloned authenticator, so it is logged.
        let cred_jsons = match self.db.get_credentials_for_user(user_id).await {
            Ok(jsons) => jsons,
            Err(e) => {
                warn!(%user_id, error = %e, "failed to read passkeys to update the sign-in counter");
                return;
            }
        };

        for json in &cred_jsons {
            let Ok(stored) = serde_json::from_str::<serde_json::Value>(json) else {
                continue;
            };
            let Ok(mut pk) = serde_json::from_value::<Passkey>(stored.clone()) else {
                continue;
            };

            if let Some(true) = pk.update_credential(auth_result) {
                let cred_id = credential_key(pk.cred_id());
                let name = stored
                    .get("cred_name")
                    .and_then(|n| n.as_str())
                    .map(str::to_string);
                let Ok(new_json) = stored_passkey_json(&pk, name) else {
                    continue;
                };
                if let Err(e) = self.db.update_credential_json(&cred_id, &new_json).await {
                    warn!(%user_id, error = %e, "failed to store the sign-in counter");
                }
            }
        }
    }
}

/// Forget expired registrations, then make room for one more from `client`.
fn admit_registration(
    map: &mut HashMap<String, PendingRegistration>,
    client: &str,
) -> Result<(), Refusal> {
    map.retain(|_, pending| live(pending.created_at));
    admit(map.values().map(|pending| pending.client.as_str()), client)
}

/// Forget expired sign-ins, then make room for one more from `client`.
fn admit_authentication(
    map: &mut HashMap<String, PendingAuthChallenge>,
    client: &str,
) -> Result<(), Refusal> {
    map.retain(|_, pending| live(pending.created_at));
    admit(map.values().map(|pending| pending.client.as_str()), client)
}

fn live(created_at: Instant) -> bool {
    created_at.elapsed().as_secs() < CHALLENGE_TTL_SECS
}

/// Refuse one more ceremony when `client` already has its share in flight,
/// or everyone together has.
fn admit<'a>(pending: impl Iterator<Item = &'a str>, client: &str) -> Result<(), Refusal> {
    let (mut all, mut theirs) = (0, 0);
    for from in pending {
        all += 1;
        theirs += usize::from(from == client);
    }
    if all >= MAX_PENDING_CHALLENGES || theirs >= MAX_PENDING_PER_CLIENT {
        return Err(Refusal::Busy);
    }
    Ok(())
}

/// A passkey as stored: the webauthn-rs `Passkey` with the name the user
/// gave it, if any, beside it under "cred_name".
fn stored_passkey_json(passkey: &Passkey, name: Option<String>) -> Result<String, Refusal> {
    let mut value =
        serde_json::to_value(passkey).map_err(|e| internal("serialising a passkey", e))?;
    if let (Some(name), Some(obj)) = (name, value.as_object_mut()) {
        obj.insert("cred_name".to_string(), serde_json::Value::String(name));
    }
    serde_json::to_string(&value).map_err(|e| internal("serialising a passkey", e))
}

/// The challenge and origin the client signed over, as it sent them: for
/// the logs when a sign-in fails.
fn client_data(cred: &PublicKeyCredential) -> (Option<String>, Option<String>) {
    let Ok(client_data) =
        serde_json::from_slice::<serde_json::Value>(cred.response.client_data_json.as_ref())
    else {
        return (None, None);
    };
    let field = |key: &str| client_data.get(key)?.as_str().map(str::to_string);
    (field("challenge"), field("origin"))
}

fn encode_challenge(challenge: &Base64UrlSafeData) -> String {
    serde_json::to_string(challenge)
        .unwrap_or_else(|_| "\"<serialization-failed>\"".to_string())
        .trim_matches('"')
        .to_string()
}
