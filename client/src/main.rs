use dioxus::prelude::*;
use gloo_storage::{LocalStorage, Storage};
use shared::{OnlineUser, SignalMessage, UserPreferences};
use std::cell::RefCell;
use uuid::Uuid;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::spawn_local;
use web_sys::{
    MessageEvent, RtcDataChannel, RtcDataChannelEvent, RtcIceCandidate, RtcIceCandidateInit,
    RtcPeerConnection, RtcPeerConnectionIceEvent, RtcSessionDescriptionInit, WebSocket,
};

const STORAGE_KEY: &str = "lift_user_preferences";
const SIGNALING_SERVER: &str = "ws://localhost:3001/ws";

fn main() {
    console_error_panic_hook::set_once();
    dioxus::launch(App);
}

// Global state for WebSocket and WebRTC (accessed from JS callbacks)
thread_local! {
    static WEBSOCKET: RefCell<Option<WebSocket>> = RefCell::new(None);
    static PEER_CONNECTION: RefCell<Option<RtcPeerConnection>> = RefCell::new(None);
    static DATA_CHANNEL: RefCell<Option<RtcDataChannel>> = RefCell::new(None);
}

// Signals for reactive UI state
static ONLINE_USERS: GlobalSignal<Vec<OnlineUser>> = Signal::global(Vec::new);
static MESSAGES: GlobalSignal<Vec<String>> = Signal::global(Vec::new);
static CONNECTED: GlobalSignal<bool> = Signal::global(|| false);
static CONNECTION_STATUS: GlobalSignal<String> = Signal::global(|| "Connecting...".to_string());

#[component]
fn App() -> Element {
    let mut user = use_signal(|| LocalStorage::get::<UserPreferences>(STORAGE_KEY).ok());

    rsx! {
        style { {include_str!("../public/style.css")} }
        div { class: "container",
            match user.read().as_ref() {
                None => rsx! { RegistrationForm { on_register: move |prefs| user.set(Some(prefs)) } },
                Some(prefs) => rsx! { MainApp { user: prefs.clone() } },
            }
        }
    }
}

#[component]
fn RegistrationForm(on_register: EventHandler<UserPreferences>) -> Element {
    let mut username = use_signal(String::new);
    let mut age = use_signal(String::new);

    let submit = move |_: MouseEvent| {
        let name = username.read().trim().to_string();
        if name.is_empty() {
            return;
        }

        let mut prefs = UserPreferences::new(name);
        if let Ok(a) = age.read().parse::<u32>() {
            prefs.age = Some(a);
        }

        LocalStorage::set(STORAGE_KEY, &prefs).ok();
        on_register.call(prefs);
    };

    rsx! {
        div { class: "card",
            h1 { "Welcome to Lift" }
            p { class: "subtitle", "Your ID: will be generated on registration" }

            div { class: "form-group",
                label { "Username" }
                input {
                    r#type: "text",
                    placeholder: "Enter your name",
                    value: "{username}",
                    oninput: move |e| username.set(e.value()),
                }
            }

            div { class: "form-group",
                label { "Age (optional)" }
                input {
                    r#type: "number",
                    placeholder: "Enter your age",
                    value: "{age}",
                    oninput: move |e| age.set(e.value()),
                }
            }

            button {
                onclick: submit,
                "Register"
            }
        }
    }
}

#[component]
fn MainApp(user: UserPreferences) -> Element {
    let mut message_input = use_signal(String::new);
    let user_id = user.id;
    let username = user.username.clone();

    // Connect to signaling server on mount
    use_effect({
        let username = username.clone();
        move || {
            let username = username.clone();
            spawn_local(async move {
                match connect_signaling(user_id, &username) {
                    Ok(_) => *CONNECTION_STATUS.write() = "Connected to server".to_string(),
                    Err(e) => *CONNECTION_STATUS.write() = format!("Failed: {:?}", e),
                }
            });
        }
    });

    let online_users = ONLINE_USERS.read().clone();
    let messages = MESSAGES.read().clone();
    let connected = *CONNECTED.read();
    let connection_status = CONNECTION_STATUS.read().clone();

    let has_channel = DATA_CHANNEL.with(|dc| dc.borrow().is_some());

    let send_message = move |_: MouseEvent| {
        let msg = message_input.read().clone();
        if msg.is_empty() {
            return;
        }

        DATA_CHANNEL.with(|dc| {
            if let Some(dc) = dc.borrow().as_ref() {
                if dc.ready_state() == web_sys::RtcDataChannelState::Open {
                    dc.send_with_str(&msg).ok();
                    MESSAGES.write().push(format!("You: {}", msg));
                    message_input.set(String::new());
                }
            }
        });
    };

    let initiate_connection = move |target_id: Uuid| {
        spawn_local(async move {
            if let Err(e) = create_offer(user_id, target_id).await {
                web_sys::console::log_1(&format!("Error: {:?}", e).into());
            }
        });
    };

    rsx! {
        div { class: "card",
            h1 { "Lift" }
            p { class: "subtitle", "Logged in as {user.username} ({user.id})" }
            p { class: "status", "{connection_status}" }

            if connected {
                p { class: "status connected", "P2P Connected!" }
            }

            h2 { "Online Users" }
            div { class: "user-list",
                for online_user in online_users.iter().filter(|u| u.id != user_id) {
                    {
                        let target_id = online_user.id;
                        let name = online_user.username.clone();
                        rsx! {
                            div {
                                class: "user-item",
                                onclick: move |_| initiate_connection(target_id),
                                "{name}"
                            }
                        }
                    }
                }
                if online_users.iter().filter(|u| u.id != user_id).count() == 0 {
                    p { class: "empty", "No other users online. Open another tab!" }
                }
            }

            h2 { "Messages" }
            div { class: "messages",
                for msg in messages.iter() {
                    div { class: "message", "{msg}" }
                }
                if messages.is_empty() {
                    p { class: "empty", "No messages yet" }
                }
            }

            div { class: "message-input",
                input {
                    r#type: "text",
                    placeholder: "Type a message...",
                    value: "{message_input}",
                    oninput: move |e| message_input.set(e.value()),
                    onkeypress: move |e: KeyboardEvent| {
                        if e.key() == Key::Enter {
                            DATA_CHANNEL.with(|dc| {
                                if let Some(dc) = dc.borrow().as_ref() {
                                    if dc.ready_state() == web_sys::RtcDataChannelState::Open {
                                        let msg = message_input.read().clone();
                                        if !msg.is_empty() {
                                            dc.send_with_str(&msg).ok();
                                            MESSAGES.write().push(format!("You: {}", msg));
                                            message_input.set(String::new());
                                        }
                                    }
                                }
                            });
                        }
                    },
                }
                button {
                    onclick: send_message,
                    disabled: !has_channel,
                    "Send"
                }
            }
        }
    }
}

fn connect_signaling(user_id: Uuid, username: &str) -> Result<(), JsValue> {
    let ws = WebSocket::new(SIGNALING_SERVER)?;

    WEBSOCKET.with(|ws_cell| {
        *ws_cell.borrow_mut() = Some(ws.clone());
    });

    let ws_clone = ws.clone();
    let register_msg = serde_json::to_string(&SignalMessage::Register {
        user_id,
        username: username.to_string(),
    }).unwrap();

    let onopen = Closure::wrap(Box::new(move || {
        ws_clone.send_with_str(&register_msg).ok();
    }) as Box<dyn Fn()>);
    ws.set_onopen(Some(onopen.as_ref().unchecked_ref()));
    onopen.forget();

    let onmessage = Closure::wrap(Box::new(move |e: MessageEvent| {
        if let Ok(text) = e.data().dyn_into::<js_sys::JsString>() {
            let text: String = text.into();
            if let Ok(signal) = serde_json::from_str::<SignalMessage>(&text) {
                handle_signal_message(signal, user_id);
            }
        }
    }) as Box<dyn Fn(MessageEvent)>);
    ws.set_onmessage(Some(onmessage.as_ref().unchecked_ref()));
    onmessage.forget();

    Ok(())
}

fn handle_signal_message(signal: SignalMessage, user_id: Uuid) {
    match signal {
        SignalMessage::UserList { users } => {
            *ONLINE_USERS.write() = users;
        }
        SignalMessage::Offer { from, to: _, sdp } => {
            spawn_local(async move {
                if let Err(e) = handle_offer(user_id, from, &sdp).await {
                    web_sys::console::log_1(&format!("Error handling offer: {:?}", e).into());
                }
            });
        }
        SignalMessage::Answer { from: _, to: _, sdp } => {
            PEER_CONNECTION.with(|pc_cell| {
                if let Some(pc) = pc_cell.borrow().as_ref() {
                    let pc = pc.clone();
                    spawn_local(async move {
                        let desc = RtcSessionDescriptionInit::new(web_sys::RtcSdpType::Answer);
                        desc.set_sdp(&sdp);
                        let _ = wasm_bindgen_futures::JsFuture::from(pc.set_remote_description(&desc)).await;
                        *CONNECTED.write() = true;
                    });
                }
            });
        }
        SignalMessage::IceCandidate { from: _, to: _, candidate } => {
            PEER_CONNECTION.with(|pc_cell| {
                if let Some(pc) = pc_cell.borrow().as_ref() {
                    let pc = pc.clone();
                    spawn_local(async move {
                        let init = RtcIceCandidateInit::new(&candidate);
                        init.set_sdp_mid(Some("0"));
                        init.set_sdp_m_line_index(Some(0));
                        if let Ok(cand) = RtcIceCandidate::new(&init) {
                            let _ = wasm_bindgen_futures::JsFuture::from(
                                pc.add_ice_candidate_with_opt_rtc_ice_candidate(Some(&cand)),
                            ).await;
                        }
                    });
                }
            });
        }
        _ => {}
    }
}

fn get_websocket() -> Option<WebSocket> {
    WEBSOCKET.with(|ws| ws.borrow().clone())
}

async fn create_offer(user_id: Uuid, target_id: Uuid) -> Result<(), JsValue> {
    let ws = get_websocket().ok_or_else(|| JsValue::from_str("No WebSocket"))?;
    let pc = create_peer_connection(user_id, target_id)?;

    let dc = pc.create_data_channel("messages");
    setup_data_channel(&dc);
    DATA_CHANNEL.with(|dc_cell| *dc_cell.borrow_mut() = Some(dc));

    let offer = wasm_bindgen_futures::JsFuture::from(pc.create_offer()).await?;
    let offer_sdp = js_sys::Reflect::get(&offer, &"sdp".into())?
        .as_string()
        .unwrap_or_default();

    let desc = RtcSessionDescriptionInit::new(web_sys::RtcSdpType::Offer);
    desc.set_sdp(&offer_sdp);
    wasm_bindgen_futures::JsFuture::from(pc.set_local_description(&desc)).await?;

    PEER_CONNECTION.with(|pc_cell| *pc_cell.borrow_mut() = Some(pc));

    let msg = serde_json::to_string(&SignalMessage::Offer {
        from: user_id,
        to: target_id,
        sdp: offer_sdp,
    }).unwrap();
    ws.send_with_str(&msg).ok();

    Ok(())
}

async fn handle_offer(user_id: Uuid, from_id: Uuid, sdp: &str) -> Result<(), JsValue> {
    let ws = get_websocket().ok_or_else(|| JsValue::from_str("No WebSocket"))?;
    let pc = create_peer_connection(user_id, from_id)?;

    let ondatachannel = Closure::wrap(Box::new(move |e: RtcDataChannelEvent| {
        let dc = e.channel();
        setup_data_channel(&dc);
        DATA_CHANNEL.with(|dc_cell| *dc_cell.borrow_mut() = Some(dc));
    }) as Box<dyn Fn(RtcDataChannelEvent)>);
    pc.set_ondatachannel(Some(ondatachannel.as_ref().unchecked_ref()));
    ondatachannel.forget();

    let desc = RtcSessionDescriptionInit::new(web_sys::RtcSdpType::Offer);
    desc.set_sdp(sdp);
    wasm_bindgen_futures::JsFuture::from(pc.set_remote_description(&desc)).await?;

    let answer = wasm_bindgen_futures::JsFuture::from(pc.create_answer()).await?;
    let answer_sdp = js_sys::Reflect::get(&answer, &"sdp".into())?
        .as_string()
        .unwrap_or_default();

    let answer_desc = RtcSessionDescriptionInit::new(web_sys::RtcSdpType::Answer);
    answer_desc.set_sdp(&answer_sdp);
    wasm_bindgen_futures::JsFuture::from(pc.set_local_description(&answer_desc)).await?;

    PEER_CONNECTION.with(|pc_cell| *pc_cell.borrow_mut() = Some(pc));
    *CONNECTED.write() = true;

    let msg = serde_json::to_string(&SignalMessage::Answer {
        from: user_id,
        to: from_id,
        sdp: answer_sdp,
    }).unwrap();
    ws.send_with_str(&msg).ok();

    Ok(())
}

fn create_peer_connection(user_id: Uuid, target_id: Uuid) -> Result<RtcPeerConnection, JsValue> {
    let config = web_sys::RtcConfiguration::new();
    let ice_servers = js_sys::Array::new();
    let ice_server = web_sys::RtcIceServer::new();
    let urls = js_sys::Array::new();
    urls.push(&"stun:stun.l.google.com:19302".into());
    ice_server.set_urls(&urls);
    ice_servers.push(&ice_server);
    config.set_ice_servers(&ice_servers);

    let pc = RtcPeerConnection::new_with_configuration(&config)?;

    let onicecandidate = Closure::wrap(Box::new(move |e: RtcPeerConnectionIceEvent| {
        if let Some(candidate) = e.candidate() {
            if let Some(ws) = get_websocket() {
                let msg = serde_json::to_string(&SignalMessage::IceCandidate {
                    from: user_id,
                    to: target_id,
                    candidate: candidate.candidate(),
                }).unwrap();
                ws.send_with_str(&msg).ok();
            }
        }
    }) as Box<dyn Fn(RtcPeerConnectionIceEvent)>);
    pc.set_onicecandidate(Some(onicecandidate.as_ref().unchecked_ref()));
    onicecandidate.forget();

    Ok(pc)
}

fn setup_data_channel(dc: &RtcDataChannel) {
    let onopen = Closure::wrap(Box::new(move || {
        web_sys::console::log_1(&"Data channel opened!".into());
        *CONNECTED.write() = true;
    }) as Box<dyn Fn()>);
    dc.set_onopen(Some(onopen.as_ref().unchecked_ref()));
    onopen.forget();

    let onmessage = Closure::wrap(Box::new(move |e: MessageEvent| {
        if let Ok(text) = e.data().dyn_into::<js_sys::JsString>() {
            let text: String = text.into();
            MESSAGES.write().push(format!("Peer: {}", text));
        }
    }) as Box<dyn Fn(MessageEvent)>);
    dc.set_onmessage(Some(onmessage.as_ref().unchecked_ref()));
    onmessage.forget();
}
