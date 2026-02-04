use axum::{
    extract::{
        ws::{Message, WebSocket},
        State, WebSocketUpgrade,
    },
    response::Response,
    routing::get,
    Router,
};
use futures::{SinkExt, StreamExt};
use shared::{OnlineUser, SignalMessage};
use std::{
    collections::HashMap,
    sync::Arc,
};
use tokio::sync::{mpsc, RwLock};
use tower_http::cors::CorsLayer;
use uuid::Uuid;

type Users = Arc<RwLock<HashMap<Uuid, UserConnection>>>;

struct UserConnection {
    username: String,
    tx: mpsc::UnboundedSender<String>,
}

#[derive(Clone)]
struct AppState {
    users: Users,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let state = AppState {
        users: Arc::new(RwLock::new(HashMap::new())),
    };

    let app = Router::new()
        .route("/ws", get(ws_handler))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3001").await.unwrap();
    println!("Signaling server running on http://localhost:3001");
    axum::serve(listener, app).await.unwrap();
}

async fn ws_handler(ws: WebSocketUpgrade, State(state): State<AppState>) -> Response {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: AppState) {
    let (mut sender, mut receiver) = socket.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<String>();

    let mut user_id: Option<Uuid> = None;

    // Task to send messages to this client
    let send_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if sender.send(Message::Text(msg.into())).await.is_err() {
                break;
            }
        }
    });

    // Handle incoming messages
    while let Some(Ok(msg)) = receiver.next().await {
        if let Message::Text(text) = msg {
            if let Ok(signal) = serde_json::from_str::<SignalMessage>(&text) {
                match signal {
                    SignalMessage::Register { user_id: uid, username } => {
                        user_id = Some(uid);

                        // Add user to registry
                        {
                            let mut users = state.users.write().await;
                            users.insert(uid, UserConnection {
                                username: username.clone(),
                                tx: tx.clone(),
                            });
                        }

                        println!("User registered: {} ({})", username, uid);

                        // Send updated user list to all
                        broadcast_user_list(&state).await;
                    }

                    SignalMessage::Offer { from, to, sdp } => {
                        forward_to_user(&state, to, SignalMessage::Offer { from, to, sdp }).await;
                    }

                    SignalMessage::Answer { from, to, sdp } => {
                        forward_to_user(&state, to, SignalMessage::Answer { from, to, sdp }).await;
                    }

                    SignalMessage::IceCandidate { from, to, candidate } => {
                        forward_to_user(&state, to, SignalMessage::IceCandidate { from, to, candidate }).await;
                    }

                    SignalMessage::ConnectRequest { from, to } => {
                        forward_to_user(&state, to, SignalMessage::ConnectRequest { from, to }).await;
                    }

                    _ => {}
                }
            }
        }
    }

    // Cleanup on disconnect
    if let Some(uid) = user_id {
        let mut users = state.users.write().await;
        if let Some(user) = users.remove(&uid) {
            println!("User disconnected: {} ({})", user.username, uid);
        }
        drop(users);
        broadcast_user_list(&state).await;
    }

    send_task.abort();
}

async fn broadcast_user_list(state: &AppState) {
    let users = state.users.read().await;
    let user_list: Vec<OnlineUser> = users
        .iter()
        .map(|(id, conn)| OnlineUser {
            id: *id,
            username: conn.username.clone(),
        })
        .collect();

    let msg = serde_json::to_string(&SignalMessage::UserList { users: user_list }).unwrap();

    for conn in users.values() {
        let _ = conn.tx.send(msg.clone());
    }
}

async fn forward_to_user(state: &AppState, user_id: Uuid, message: SignalMessage) {
    let users = state.users.read().await;
    if let Some(conn) = users.get(&user_id) {
        let msg = serde_json::to_string(&message).unwrap();
        let _ = conn.tx.send(msg);
    }
}
