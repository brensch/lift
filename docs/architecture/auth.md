# Authentication

Schlift uses **passkeys (WebAuthn) only**. There are no passwords and no
email. Someone who loses every passkey makes a new one that an admin approves
([below](#getting-back-in-without-a-passkey)). `webauthn-rs` handles the
protocol; `src/auth.rs` holds the state and `src/server/auth.rs` exposes the
RPCs.

## Pieces

```mermaid
graph TD
    AS["AuthState (src/auth.rs)"]
    AS --> wa["Arc&lt;Webauthn&gt;<br/>configured from env"]
    AS --> rc["reg_challenges<br/>Mutex&lt;HashMap&gt; — in memory"]
    AS --> adc["add_challenges<br/>Mutex&lt;HashMap&gt; — in memory"]
    AS --> ac["auth_challenges<br/>Mutex&lt;HashMap&gt; — in memory"]
    AS --> rec["recovery_challenges<br/>Mutex&lt;HashMap&gt; — in memory"]
    AS --> db["ServerDb"]
    db --> pc[("passkeys")]
    db --> pr[("passkey_recoveries")]
    db --> se[("logins")]
    db --> uc[("users")]
```

Configuration comes from environment variables, read once at construction:

| Variable | Purpose | Default |
|---|---|---|
| `WEBAUTHN_RP_ID` | Relying party id (the domain) | `localhost` |
| `WEBAUTHN_RP_ORIGIN` | Expected origin | `http://localhost:5173` |
| `WEBAUTHN_ANDROID_ORIGINS` | Comma-separated `android:apk-key-hash:…` origins | — |

Android apps present an APK-signing-key-hash origin rather than a URL, so every
signing key that ships (debug, upload, Play signing) needs its hash listed or
login fails on that build. Hashes are printed by `make print-cert-hashes`.

> These are `expect()`ed at startup — a malformed origin **panics the server on
> boot** rather than degrading. That is deliberate: a misconfigured RP silently
> accepting the wrong origin would be worse.

## Registration

```mermaid
sequenceDiagram
    participant App
    participant S as AuthService
    participant A as AuthState
    participant DB

    App->>S: RegisterStart(username)
    S->>A: start_registration(username)
    A->>A: generate user_id (UUID v4)
    A->>A: start_passkey_registration
    A->>A: store reg_state in reg_challenges[user_id]
    A-->>App: user_id + CreationChallengeResponse

    Note over App: platform authenticator<br/>(Face ID / fingerprint)

    App->>S: RegisterFinish(user_id, credential)
    S->>A: finish_registration
    A->>A: remove challenge (single use)
    A->>A: finish_passkey_registration → Passkey
    A->>DB: create_user_with_passkey(user_id, username, cred_id, cred_json)
    S->>DB: create_auth_session(user_id)
    S-->>App: AuthResponse{token, user}
```

Note the ordering: **the user row is created in `finish_registration`, not
`start`**, in one transaction with its passkey. An abandoned registration
leaves nothing behind except an in-memory challenge that expires, and a
failed one leaves no account without a passkey holding the name.

Challenges are single-use — `finish` removes the entry before verifying, so a
replayed `RegisterFinish` finds no challenge. Its attempt's verdict stands:
`finish_auth_attempt` never rewrites an earlier one. Add-passkey challenges
are kept apart from sign-ups (`add_challenges`), so an unauthenticated
`RegisterFinish` naming a user's id can't spend theirs.

## Login

Two paths. Discoverable (usernameless) is the default; the username path exists
for authenticators that need a credential hint.

```mermaid
sequenceDiagram
    participant App
    participant S as AuthService
    participant A as AuthState
    participant DB

    alt discoverable (default)
        App->>S: LoginStart()
        S->>A: start_authentication()
        A->>A: store AuthChallengeState::Discoverable
    else with username
        App->>S: LoginStart(username)
        S->>A: start_authentication_with_username
        A->>DB: get_credentials_for_user
        A->>A: store AuthChallengeState::Passkey{state, user_id}
    end
    A-->>App: RequestChallengeResponse

    App->>S: LoginFinish(credential)
    S->>A: finish_authentication
    A->>DB: look up credential
    A->>A: verify signature + counter
    A->>DB: update_credential_json (counter)
    S->>DB: create_auth_session(user_id)
    S-->>App: AuthResponse{token, user}
```

`AuthChallengeState` is an enum over the two flows so a single challenge map can
serve both. The signature counter is written back on every successful login —
`webauthn-rs` uses it to detect cloned authenticators. A failure to write it
is logged at `warn`; the login still succeeds.

## When a ceremony is refused

Every way a ceremony can fail is a `Refusal` (`src/auth.rs`). The caller is
sent one short sentence (`Refusal::message`); the detail (the webauthn-rs
error, the challenge, the origins) is logged where it happened and never
sent. A failed sign-in used to be shown to the user with the challenge and
every allowed origin in it. The refusal's `slug` is what `auth_attempts.reason`
holds, so the stats page counts refusals by kind.

The gRPC code tells a client which it was (`refusal_status`,
`src/server/auth.rs`):

| Refusal | Code | What happened |
|---|---|---|
| `UnknownPasskey`, `UnknownUser` | `NOT_FOUND` | No account holds the passkey presented (its account or the passkey was deleted, or its sign-up never finished); nobody has the username |
| `NotVerified` | `FAILED_PRECONDITION` | The passkey answered without verifying its user. Passkeys here require it |
| `AlreadyRegistered`, `NameTaken` | `ALREADY_EXISTS` | |
| `Busy`, `TooManyRecoveries` | `RESOURCE_EXHAUSTED` | |
| (not a refusal) | `PERMISSION_DENIED` | The passkey is one made at `/recover` and not approved yet; see below |
| `Expired`, `Rejected` | `UNAUTHENTICATED` signing in, `INVALID_ARGUMENT` registering | The challenge is spent or over five minutes old; the credential didn't verify |

The app words `NOT_FOUND` and `FAILED_PRECONDITION` itself (`formatAuthError`,
`copy.passkeyErrors`); anything else shows the server's sentence.

## On the phone

`app/lib/services/auth_service.dart` runs the device's half through the
`passkeys` plugin (Android signs in through `credential_manager`).

- **User verification is asked for.** The server's options say
  `userVerification: required`. `passkeys_darwin` before 0.4.8 never passed
  that to iOS, so a third-party passkey manager (1Password) signed without
  verifying and the server refused the sign-in. Keep `passkeys` at 2.24.1 or
  later.
- **The passkey sheet may stay open two minutes** (`_passkeyPromptTimeout`),
  inside the server's five. A sheet finished after the app gave up makes a
  passkey for nothing.
- **Passkeys no account holds are dropped.** When a sign-in is refused
  `NOT_FOUND`, or a sheet makes a passkey after its timeout, the app tells
  the passkey manager to forget it (`signalUnknownCredential`). Only newer
  systems act on it (Android with a provider that supports signals, iOS
  26.2); elsewhere the stale passkey is still offered and still refused.
- **iOS offers a passkey on another device.** Sign-in passes
  `preferImmediatelyAvailableCredentials: false`, so with no passkey on the
  phone the sheet offers the QR code and security keys instead of failing.

## Sessions

```mermaid
graph LR
    login["LoginFinish"] --> tok["create_auth_session<br/>random token"]
    tok -->|"SHA-256"| row[("logins<br/>token_hash PK, user_id, expires_at")]
    req["Every authed RPC"] --> chk["authed_user_id()"]
    chk -->|"SHA-256 of the bearer token"| row
    row -->|"valid + unexpired"| ok["user_id"]
    row -->|"otherwise"| err["Status::unauthenticated"]
```

The token is a bearer token in gRPC metadata, attached client-side by
`AuthInterceptor` (`app/lib/services/grpc_client.dart`). The server stores
only its SHA-256 (`token_hash`, `src/db/migrate.rs`), so the table never
holds a token that would let someone in; the token itself exists only on the
phone and in the response that hands it over. Creating a login deletes every
expired one.

`authed_user_id` is called **explicitly at the top of each handler** — there is
no interceptor or middleware enforcing it. A new handler that omits the call is
unauthenticated, and nothing will flag that. Copy an existing handler when adding
one.

`Logout` deletes the row. `DeleteAccount` deletes the user's row
(`delete_user_account_and_data`, `src/db/auth.rs`); every table with a
`user_id` references `users(id) ON DELETE CASCADE`, so the account's event
log, passkeys, logins, session memberships and page views go with it. It
also deletes the registration's `auth_attempts` row and drops any join
requests to or from it; the streams of those it asked, and of its session's
other members, hear the change.

## The account and the server session

Signing in to the server and having the account are two different things on
the phone (`AuthProvider`):

- `isLoggedIn` — an account is open on this phone (a user id is known).
  Everything works from here: the account file is on the phone.
- `hasServerSession` — the server knows this phone (a session token). Sync,
  multiplayer and the profile need it.

A passkey sign-in sets both: the token, and the user id whose file
`AccountSync` then opens (pulling the log from the server first on a fresh
install). A login stays signed in while it is used: each
use slides its expiry to 30 days out (`validate_auth_session`, written at most
once a day), so only a login left unused for 30 days lapses. If
the server refuses the token (lapsed, its passkey deleted, the account
deleted), `expireSession` clears only the token; the account stays open and
usable. While an account is open with no session (this, or one opened from a
file), `SessionExpiredBanner` sits over the app's pages (around `MainLayout`
in the shell route: not over `/login`, onboarding or the tutorial, and not
while the update banner shows) with a sign-in button to `/login`; signing in
there resumes sync, and the login screen's back arrow returns home without
signing in.

"Open an account file" on the login screen opens an exported account with no
server at all (`AuthProvider.openLocalAccount`): the file names its owner, so
the user id comes from it. Signing in as that user later lets it sync again.
A file belonging to a different account than the one open is refused.

## Challenge lifetime

Pending challenges live in process memory with a 300-second TTL
(`CHALLENGE_TTL_SECS`). Expired entries are swept lazily on the next
`start_registration` / `start_authentication`, not by a background task — so a
quiet server holds expired challenges until the next login attempt. Bounded by
traffic, not by time: a start is refused once its client (the address, or an
IPv6 /64) holds `MAX_PENDING_PER_CLIENT` unexpired ceremonies of that kind, or
everyone together holds `MAX_PENDING_CHALLENGES`.

**This makes the backend single-instance.** A challenge issued by one process
cannot be completed by another, so the service cannot be horizontally scaled or
restarted mid-handshake without users retrying. Any move to multiple instances
needs challenges in shared storage.

## Managing passkeys

| RPC | Effect |
|---|---|
| `AddPasskeyStart` / `AddPasskeyFinish` | Register an extra passkey for the logged-in user; excludes already-registered credentials |
| `ListPasskeys` | Metadata only — created-at, IP, optional `cred_name` |
| `DeletePasskey` | Removes one credential and signs out every other login of the user (logins aren't tied to a passkey; the caller's stays); the last one is refused (`FailedPrecondition`), and `PasskeysScreen` disables it |

A friendly name is stored by injecting a `cred_name` key into the serialised
credential JSON rather than as its own column
(`stored_passkey_json` in `src/auth.rs`). It travels with the credential, but it is not queryable.

`passkeys.credential_id` is the credential id as the passkey's own JSON
spells it (base64url; `credential_key`). It used to be how a Rust type
happened to print (`HumanBinaryData([1, 2, …])`); migration step 4 rekeyed
the rows from their JSON.

The passkeys screen says so when an account has only one.

## Getting back in without a passkey

You cannot delete your last passkey, but losing every device or password
manager that holds one locks you out. Getting back in is a new passkey that
an admin approves. The request is made on the website (`/recover`, which the
app's `LostPasskeyScreen` opens), so it works from any version of the app.

```mermaid
sequenceDiagram
    participant P as Person (browser)
    participant S as AuthService
    participant DB
    participant A as Admin (/admin)

    P->>S: RecoveryStart(username)
    S-->>P: request_id + creation options for the account's user id
    Note over P: makes a passkey (discoverable)
    P->>S: RecoveryFinish(request_id, credential)
    S->>DB: passkey_recoveries: held, status pending
    S-->>P: code (XXXX-XXXX), expires in 7 days
    P-->>A: the code, out of band
    A->>S: DecideRecovery(approve_code)
    S->>DB: move the passkey into passkeys
    P->>S: RecoveryStatus(request_id) → approved
    Note over P: the passkey signs in
```

A passkey is made for one user id and signs in by naming it, so the new
passkey is made for the old account from the start: one made for a new
account could not be moved across afterwards.

What keeps it safe:

- **The held passkey is inert.** It is in `passkey_recoveries`, not
  `passkeys`: it signs nothing in, and is dropped when the request is
  refused, lapses (7 days) or its account is deleted.
- **Approval is by code, never by row.** `ListRecoveries` does not return
  codes, so the request an admin approves is the one whose maker got their
  code to the admin. Knowing a username is enough to make a request and not
  enough to have it approved.
- **The admin reads the account first.** Typing the code opens the account
  it asks for (`GetRecovery`): its emoji and colour, when it joined and was
  last used, who it trains with, its saved workouts, latest workouts and
  lifts, the passkeys it had. Things its owner knows and a stranger does
  not, to ask about before approving. What is left is the admin being talked
  into it.
- **The owner hears of it.** A device still signed in to the account shows
  `RecoveryAlertBanner` (`ListMyRecoveries`) with a button that refuses the
  request (`DenyMyRecovery`). The admin's list shows how many devices are
  signed in: such a person can add a passkey themselves.
- **Bounded.** Starts are limited like every other ceremony; at most 5
  requests wait per account and 1,000 in all.
- **`remove_other_passkeys`** on approving drops the account's other
  passkeys and signs out its devices: for a stolen phone, not a lost key.

**Coming back for the code.** Nobody waiting is signed in: the browser that
made the request only remembers its id, and the site's sign-in button reads
"Waiting for approval" and leads to the code. From anywhere else, signing in
with the waiting passkey is refused `PERMISSION_DENIED` with the request's id
in the `x-recovery-request` trailer (`SignIn::AwaitingApproval`, only after
the signature checks out against the held passkey), and the website goes to
the code. The app shows the sentence: the passkey is waiting to be approved.

A username nobody holds is not refused. The ceremony runs the same, for a
made-up user id (the same one for the same name while the server runs), and
the request is held like any other: a row with no `user_id` and the name as
typed (`asked_username`). Its maker can come back to the code, and an admin
sent it opens the request to find there is no such account and says so; it
can be turned down, never approved (`Approval::NoSuchAccount`). The attempt
is filed `rejected` / `unknown_user`, which the stats page counts. Anyone
can make these, as anyone can sign up; they are bounded where sign-ups are
not (five waiting per name, a thousand in all, a week each).

`RecoveryStart`, `RecoveryFinish` and `RecoveryStatus` are
unauthenticated: the caller has no passkey. The request id (random, held by
whoever made the request) is what lets its status be read.

## Test login

`TestLogin(username)` bypasses WebAuthn entirely: it calls
`get_or_create_user_with_auth_session`, which returns an existing account if the
username matches and issues a 30-day session token for it. **It is an account
takeover primitive by design** and exists only for emulator development, the
e2e scenarios' API peers and the server's own tests.

It is gated behind the `test-auth` Cargo feature:

```rust
#[cfg(not(feature = "test-auth"))]
async fn test_login(...) -> Result<Response<AuthResponse>, Status> {
    Err(Status::permission_denied("test login is not enabled"))
}
```

| Build | Command | `TestLogin` |
|---|---|---|
| Production | `cargo build --release --bin schlift` | Refused |
| Dev / emulator | `make run-backend` (passes `--features test-auth`) | Enabled |

Both branches are covered by `test_login_gate_tests` in `src/server/auth.rs`, so
the gate cannot regress unnoticed.

> **History:** the feature existed in `Cargo.toml` and the Makefile dev targets
> passed `--features test-auth`, but no `#[cfg]` ever referenced it — so the
> bypass was compiled into production builds and reachable at
> `POST /workout.v1.AuthService/TestLogin`. If you are adding a similar
> dev-only affordance, add the `#[cfg]` *and* a test asserting the disabled
> branch; a declared-but-unused Cargo feature gates nothing.

## Local development

Passkeys need a valid RP configuration even locally. See
[`docs/android_dev.md`](../android_dev.md) for connecting an emulator to a local
backend, and [`docs/releasing.md`](../releasing.md) for the production
`.well-known/assetlinks.json` and `apple-app-site-association` values — both
served by `src/main.rs` and routed by Caddy.
