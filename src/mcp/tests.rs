use super::*;
use crate::db::MAX_FEEDBACK_CHARS;
use axum::body::Body;
use axum::http::Request;
use http_body_util::BodyExt;
use schlift_core::pb::ConnectRequest;
use tower::ServiceExt;

const VERIFIER: &str = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
const REDIRECT: &str = "https://claude.ai/api/mcp/auth_callback";

async fn mcp() -> Mcp {
    let dir = std::env::temp_dir().join(format!("lift-mcp-{}", uuid::Uuid::new_v4()));
    let db = ServerDb::new_in_dir(&dir).await.unwrap();
    db.create_user_with_id("u1", "Lyss").await.unwrap();
    Mcp {
        db,
        origin: "https://schlift.test".into(),
    }
}

async fn send(mcp: &Mcp, request: Request<Body>) -> (StatusCode, HeaderMap, Value) {
    let response = router(mcp.clone()).oneshot(request).await.unwrap();
    let status = response.status();
    let headers = response.headers().clone();
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    let body = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
    (status, headers, body)
}

fn post_json(uri: &str, token: Option<&str>, body: Value) -> Request<Body> {
    let mut request = Request::post(uri).header(header::CONTENT_TYPE, "application/json");
    if let Some(token) = token {
        request = request.header(header::AUTHORIZATION, format!("Bearer {token}"));
    }
    request.body(Body::from(body.to_string())).unwrap()
}

fn post_form(uri: &str, form: &[(&str, &str)]) -> Request<Body> {
    let body = url::form_urlencoded::Serializer::new(String::new())
        .extend_pairs(form)
        .finish();
    Request::post(uri)
        .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
        .body(Body::from(body))
        .unwrap()
}

fn rpc(method: &str, params: Value) -> Value {
    json!({ "jsonrpc": "2.0", "id": 1, "method": method, "params": params })
}

/// The tool's result as the structured value it wrote.
fn structured(reply: &Value) -> &Value {
    &reply["result"]["structuredContent"]
}

/// RFC 7636's own example.
#[test]
fn pkce_is_base64url_sha256() {
    assert_eq!(
        pkce_challenge(VERIFIER),
        "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
    );
}

#[test]
fn only_safe_redirects_register() {
    for ok in [
        REDIRECT,
        "http://localhost:33418/callback",
        "http://127.0.0.1:6274/oauth/callback",
        "cursor://anysphere.cursor-retrieval/oauth/callback",
    ] {
        assert!(redirect_allowed(ok), "{ok}");
    }
    for bad in [
        "http://evil.example/cb",
        "javascript:alert(1)",
        "data:text/html,hi",
        "https://claude.ai/cb#frag",
        "not a url",
    ] {
        assert!(!redirect_allowed(bad), "{bad}");
    }
}

/// Discovery, registration, consent, the code for tokens, the tools, a
/// refresh, a revocation: the whole way an assistant connects.
#[tokio::test]
async fn an_assistant_connects_and_sets_a_program() {
    let mcp = mcp().await;
    let (status, headers, _) = send(
        &mcp,
        post_json("/api/mcp", None, rpc("tools/list", json!({}))),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    let challenge = headers[header::WWW_AUTHENTICATE].to_str().unwrap();
    assert!(challenge.contains("https://schlift.test/.well-known/oauth-protected-resource"));

    let get = |uri: &str| Request::get(uri).body(Body::empty()).unwrap();
    let (_, _, resource) = send(&mcp, get("/.well-known/oauth-protected-resource")).await;
    assert_eq!(resource["resource"], "https://schlift.test/api/mcp");
    let (_, _, server) = send(&mcp, get("/.well-known/oauth-authorization-server")).await;
    assert_eq!(
        server["authorization_endpoint"],
        "https://schlift.test/connect"
    );
    assert_eq!(server["code_challenge_methods_supported"], json!(["S256"]));

    let (status, _, client) = send(
        &mcp,
        post_json(
            "/api/oauth/register",
            None,
            json!({ "client_name": "Claude", "redirect_uris": [REDIRECT] }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED);
    let client_id = client["client_id"].as_str().unwrap().to_string();

    // The /connect page: checked, then allowed by the signed-in person.
    let connect = ConnectRequest {
        client_id: client_id.clone(),
        redirect_uri: REDIRECT.into(),
        code_challenge: pkce_challenge(VERIFIER),
        code_challenge_method: "S256".into(),
        state: "xyz".into(),
        scope: SCOPE.into(),
        resource: "https://schlift.test/api/mcp".into(),
    };
    let found = check_connect(&mcp, &connect).await.unwrap();
    assert_eq!(found.client_name, "Claude");
    let other = ConnectRequest {
        redirect_uri: "https://evil.example/cb".into(),
        ..connect.clone()
    };
    assert!(check_connect(&mcp, &other).await.is_err());
    let code = mcp
        .db
        .issue_assistant_code(&crate::db::Consent {
            user_id: "u1".into(),
            client_id: client_id.clone(),
            redirect_uri: REDIRECT.into(),
            code_challenge: connect.code_challenge.clone(),
            scope: SCOPE.into(),
        })
        .await
        .unwrap();
    let back = redirect_back(REDIRECT, &[("code", &code), ("state", "xyz")]);
    assert!(back.starts_with(REDIRECT) && back.contains("state=xyz"));

    // A wrong verifier spends nothing it shouldn't: the code is gone.
    let exchange = |verifier: &str, code: &str| {
        post_form(
            "/api/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", code),
                ("code_verifier", verifier),
                ("redirect_uri", REDIRECT),
                ("client_id", &client_id),
            ],
        )
    };
    let (status, _, tokens) = send(&mcp, exchange(VERIFIER, &code)).await;
    assert_eq!(status, StatusCode::OK, "{tokens}");
    let access = tokens["access_token"].as_str().unwrap().to_string();
    let refresh = tokens["refresh_token"].as_str().unwrap().to_string();
    let (status, _, again) = send(&mcp, exchange(VERIFIER, &code)).await;
    assert_eq!(
        (status, again["error"].as_str()),
        (StatusCode::BAD_REQUEST, Some("invalid_grant"))
    );

    let (_, _, init) = send(
        &mcp,
        post_json(
            "/api/mcp",
            Some(&access),
            rpc(
                "initialize",
                json!({ "protocolVersion": "2025-06-18", "capabilities": {} }),
            ),
        ),
    )
    .await;
    assert_eq!(init["result"]["protocolVersion"], "2025-06-18");
    let (status, _, _) = send(
        &mcp,
        post_json(
            "/api/mcp",
            Some(&access),
            json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::ACCEPTED);
    let (_, _, tools) = send(
        &mcp,
        post_json("/api/mcp", Some(&access), rpc("tools/list", json!({}))),
    )
    .await;
    let names: Vec<&str> = tools["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|t| t["name"].as_str().unwrap())
        .collect();
    assert_eq!(
        names,
        [
            "read_guide",
            "get_program",
            "get_earlier_program",
            "get_profile",
            "get_history",
            "get_progress",
            "validate_program",
            "simulate_program",
            "set_program",
            "list_exercises",
            "list_library",
            "get_program_part",
            "send_feedback"
        ]
    );
    let call = |name: &str, arguments: Value| {
        post_json(
            "/api/mcp",
            Some(&access),
            rpc(
                "tools/call",
                json!({ "name": name, "arguments": arguments }),
            ),
        )
    };
    let (_, _, guide) = send(&mcp, call("read_guide", json!({}))).await;
    assert!(guide["result"]["content"][0]["text"]
        .as_str()
        .unwrap()
        .contains("# Writing a Schlift program"));

    let (_, _, got) = send(&mcp, call("get_program", json!({}))).await;
    let mut program = structured(&got)["program"].clone();
    assert_eq!(program["schema"], "schlift.program/v1");
    program["name"] = "From Claude".into();

    let mut broken = program.clone();
    broken["sets"]["max"] = 0.into();
    let (_, _, checked) = send(&mcp, call("validate_program", json!({ "program": broken }))).await;
    assert_eq!(structured(&checked)["ok"], false);
    let (_, _, refused) = send(
        &mcp,
        call("set_program", json!({ "program": broken, "note": "x" })),
    )
    .await;
    assert_eq!(refused["result"]["isError"], true);

    let (_, _, run) = send(
        &mcp,
        call(
            "simulate_program",
            json!({ "program": program, "sessions": 0 }),
        ),
    )
    .await;
    assert!(structured(&run)["workouts"].as_array().unwrap().is_empty());
    let (_, _, set) = send(
        &mcp,
        call(
            "set_program",
            json!({ "program": program, "note": "A start" }),
        ),
    )
    .await;
    assert_eq!(structured(&set)["set"], true, "{set}");
    let account = mcp.db.read_account("u1", Clone::clone).await.unwrap();
    assert_eq!(account.program.name, "From Claude");
    assert_eq!(account.programs.last().unwrap().author, "mcp:Claude");
    // Set again, the first is earlier, and opens by its id.
    let (_, _, again) = send(
        &mcp,
        call(
            "set_program",
            json!({ "program": program, "note": "Again" }),
        ),
    )
    .await;
    assert_eq!(structured(&again)["set"], true, "{again}");
    let (_, _, now) = send(&mcp, call("get_program", json!({}))).await;
    let earlier = structured(&now)["earlier"][0]["id"].clone();
    assert!(earlier.is_string(), "{now}");
    let (_, _, opened) = send(&mcp, call("get_earlier_program", json!({ "id": earlier }))).await;
    assert_eq!(
        structured(&opened)["program"]["schema"],
        "schlift.program/v1"
    );
    let (_, _, missing) = send(&mcp, call("get_earlier_program", json!({ "id": "nope" }))).await;
    assert_eq!(missing["result"]["isError"], true);
    let (_, _, profile) = send(&mcp, call("get_profile", json!({}))).await;
    assert_eq!(structured(&profile)["program"]["name"], "From Claude");
    let (_, _, history) = send(&mcp, call("get_history", json!({ "limit": 5 }))).await;
    assert!(structured(&history)["workouts"]
        .as_array()
        .unwrap()
        .is_empty());

    // Refresh: new tokens, the old refresh token spent.
    let refresh_with = |token: &str| {
        post_form(
            "/api/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", token),
                ("client_id", &client_id),
            ],
        )
    };
    let (status, _, fresh) = send(&mcp, refresh_with(&refresh)).await;
    assert_eq!(status, StatusCode::OK);
    let (status, _, _) = send(&mcp, refresh_with(&refresh)).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);

    // Revoked: every token stops working.
    let grant = mcp.db.assistant_grants("u1").await.unwrap().remove(0);
    mcp.db
        .revoke_assistant("u1", &grant.grant_id)
        .await
        .unwrap();
    let token = fresh["access_token"].as_str().unwrap();
    let (status, _, _) = send(
        &mcp,
        post_json("/api/mcp", Some(token), rpc("tools/list", json!({}))),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}

/// A tool called as the server calls it, for the person "u1" by Claude.
async fn tool(mcp: &Mcp, name: &str, arguments: Value) -> Result<Value, String> {
    match tools::call(mcp, "u1", "Claude", name, &arguments).await {
        Ok(v) => Ok(v["structuredContent"].clone()),
        Err(tools::Failure::Tool(m)) => Err(m),
        Err(tools::Failure::Server(m)) => panic!("server failure: {m}"),
        Err(tools::Failure::Unknown) => panic!("no tool {name}"),
    }
}

/// The program as an assistant sees it leaves out the built-in exercises
/// and says so; a change is a few edits, simulated and set the same way,
/// and a bad one changes nothing and says which.
#[tokio::test]
async fn an_assistant_changes_the_program_by_edits() {
    let mcp = mcp().await;
    let got = tool(&mcp, "get_program", json!({})).await.unwrap();
    assert_eq!(got["program"]["exercises"], json!([]));
    assert!(got["exercises_note"].as_str().unwrap().contains("built-in"));

    let edits = json!([
        { "set": "name", "value": "Upper/Lower" },
        { "set": "classes.heavy.rest_seconds", "value": 150 },
        { "set": "workouts[upper]", "value": { "name": "Upper", "exercises": ["bench_press", "barbell_row"] } },
        { "set": "workouts[lower]", "value": { "name": "Lower", "exercises": ["squat", "romanian_deadlift"] } }
    ]);
    let checked = tool(&mcp, "validate_program", json!({ "edits": edits }))
        .await
        .unwrap();
    assert_eq!(
        (checked["ok"].clone(), checked["applied"].clone()),
        (json!(true), json!(4)),
        "{checked}"
    );
    let run = tool(
        &mcp,
        "simulate_program",
        json!({ "edits": edits, "sessions": 2 }),
    )
    .await
    .unwrap();
    assert_eq!(run["workouts"].as_array().unwrap().len(), 2, "{run}");
    let set = tool(
        &mcp,
        "set_program",
        json!({ "edits": edits, "note": "Split it" }),
    )
    .await
    .unwrap();
    assert_eq!(set["set"], true, "{set}");
    let account = mcp.db.read_account("u1", Clone::clone).await.unwrap();
    assert_eq!(account.program.name, "Upper/Lower");
    assert_eq!(account.program.classes["heavy"].rest_seconds, 150);
    let ids: Vec<&str> = account
        .program
        .workouts
        .iter()
        .map(|w| w.id.as_str())
        .collect();
    assert_eq!(ids, ["upper", "lower"]);
    assert_eq!(
        account.program.exercises.len(),
        schlift_core::program::Program::builtin().exercises.len(),
        "the recorded program is whole"
    );

    let bad = tool(
        &mcp,
        "set_program",
        json!({ "edits": [{ "set": "name", "value": "x" }, { "remove": "workouts[nope]" }], "note": "x" }),
    )
    .await
    .unwrap_err();
    assert!(
        bad.contains("\"failed_edit\": 1") && bad.contains("workouts[nope]"),
        "{bad}"
    );
    let wrong = tool(
        &mcp,
        "simulate_program",
        json!({ "edits": [{ "set": "workouts[upper].exercises", "value": ["bench_press", "nope"] }] }),
    )
    .await
    .unwrap_err();
    assert!(wrong.contains("workouts[upper].exercises[1]"), "{wrong}");
    assert!(tool(
        &mcp,
        "set_program",
        json!({ "edits": edits, "program": {}, "note": "x" })
    )
    .await
    .unwrap_err()
    .contains("not both"));

    let part = tool(
        &mcp,
        "get_program_part",
        json!({ "path": "workouts[lower].exercises" }),
    )
    .await
    .unwrap();
    assert_eq!(part["value"], json!(["squat", "romanian_deadlift"]));
}

#[tokio::test]
async fn helpers_find_exercises_and_the_library() {
    let mcp = mcp().await;
    let found = tool(
        &mcp,
        "list_exercises",
        json!({ "muscle": "chest", "primary_only": true, "equipment": "barbell" }),
    )
    .await
    .unwrap();
    let keys: Vec<&str> = found["exercises"]
        .as_array()
        .unwrap()
        .iter()
        .map(|e| e["key"].as_str().unwrap())
        .collect();
    assert!(keys.contains(&"bench_press"), "{keys:?}");
    assert!(found["exercises"]
        .as_array()
        .unwrap()
        .iter()
        .all(|e| e["muscles"][0] == "chest" && e["built_in"] == true));
    let library = tool(&mcp, "list_library", json!({})).await.unwrap();
    assert!(!library["workouts"].as_array().unwrap().is_empty());
}

/// Feedback is one short line, kept for the admin page with the assistant
/// and tool but no user; past the day's cap it is thanked for and dropped.
#[tokio::test]
async fn feedback_is_kept_short_and_capped() {
    let mcp = mcp().await;
    tool(
        &mcp,
        "send_feedback",
        json!({ "text": "Edits were easy.", "tool": "set_program" }),
    )
    .await
    .unwrap();
    let too_long = "x".repeat(MAX_FEEDBACK_CHARS + 1);
    assert!(tool(&mcp, "send_feedback", json!({ "text": too_long }))
        .await
        .unwrap_err()
        .contains("1 to 144"));
    assert!(tool(&mcp, "send_feedback", json!({ "text": "  " }))
        .await
        .is_err());
    let kept = mcp.db.assistant_feedback(10).await.unwrap();
    assert_eq!(kept.len(), 1);
    assert_eq!(
        (
            kept[0].client_name.as_str(),
            kept[0].tool.as_str(),
            kept[0].text.as_str()
        ),
        ("Claude", "set_program", "Edits were easy.")
    );
    for _ in 0..30 {
        tool(&mcp, "send_feedback", json!({ "text": "again" }))
            .await
            .unwrap();
    }
    assert_eq!(mcp.db.assistant_feedback(100).await.unwrap().len(), 20);
}

/// One rule, two lifts: the squat's params give it a bigger step than the
/// bench's, through the simulator's own planning; `lifts` and `summary`
/// keep the output to what was asked.
#[tokio::test]
async fn params_tune_a_shared_rule_and_the_simulator_says_only_what_was_asked() {
    let mcp = mcp().await;
    let edits = json!([
        { "set": "progressions.reps_then_weight", "value": {
            "kind": "linear", "sets": 3, "reps": 5, "increment_lb": 5,
            "deload_after_fails": 3, "deload_factor": 0.9 } },
        { "set": "exercises[squat].progression", "value": "reps_then_weight" },
        { "set": "exercises[squat].params", "value": { "increment_lb": 10 } },
        { "set": "exercises[bench_press].progression", "value": "reps_then_weight" },
        { "set": "workouts[a]", "value": { "name": "A", "exercises": ["squat", "bench_press", "barbell_row"] } }
    ]);
    let run = tool(
        &mcp,
        "simulate_program",
        json!({ "edits": edits, "sessions": 4, "template_id": "a", "lifts": ["squat", "bench_press"], "summary": true }),
    )
    .await
    .unwrap();
    let lifts = run["lifts"].as_array().unwrap();
    let keys: Vec<&str> = lifts
        .iter()
        .map(|l| l["exercise"].as_str().unwrap())
        .collect();
    assert_eq!(keys, ["squat", "bench_press"], "{run}");
    let weights = |lift: &Value| -> Vec<f64> {
        lift["sessions"]
            .as_array()
            .unwrap()
            .iter()
            .map(|line| {
                let line = line.as_str().unwrap();
                let at = &line[line.find(" @ ").unwrap() + 3..];
                at[..at.find(' ').unwrap_or(at.len())].parse().unwrap()
            })
            .collect()
    };
    let (squat, bench) = (weights(&lifts[0]), weights(&lifts[1]));
    // After the first session (the calibration ramp), each hit adds the
    // lift's own step.
    assert_eq!(squat[3] - squat[2], 10.0, "{squat:?}");
    assert_eq!(bench[3] - bench[2], 5.0, "{bench:?}");
    assert!(lifts[0]["sessions"][0].as_str().unwrap().contains("hit"));

    let bad = tool(
        &mcp,
        "validate_program",
        json!({ "edits": [{ "set": "exercises[squat].params", "value": { "nope": 1 } }] }),
    )
    .await
    .unwrap();
    assert_eq!(bad["ok"], false);
    assert!(
        bad["problems"]
            .to_string()
            .contains("exercises[squat].params.nope"),
        "{bad}"
    );
}

#[tokio::test]
async fn progress_is_per_lift() {
    let mcp = mcp().await;
    let progress = tool(&mcp, "get_progress", json!({})).await.unwrap();
    assert_eq!(
        (progress["workouts"].clone(), progress["lifts"].clone()),
        (json!(0), json!([]))
    );
}
