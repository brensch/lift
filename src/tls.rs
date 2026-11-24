//! The app's own TLS listener: phones connect to it directly, not through
//! Caddy. Caddy keeps the website, the assistants' endpoints and getting
//! and renewing the certificate; this reads the certificate Caddy keeps for
//! the domain (`TLS_CERT`, `TLS_KEY`) and picks up a renewed one by itself.
//! Behind Caddy each Sync stream cost Caddy about 85 KB and more CPU than
//! the server spent on it; here it costs the server's own few KB.
//!
//! Off unless `TLS_PORT` is set. `TLS_BIND` is the address (all of them by
//! default). The loopback listener Caddy forwards to stays, for the website
//! (gRPC-Web) and the assistants.

use std::io;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::{Arc, RwLock};
use std::time::{Duration, SystemTime};

use hyper_util::rt::{TokioExecutor, TokioIo};
use hyper_util::server::conn::auto::Builder;
use hyper_util::service::TowerToHyperService;
use tokio::net::TcpListener;
use tokio::sync::watch;

/// How long a client has to finish its TLS handshake.
const HANDSHAKE: Duration = Duration::from_secs(10);
use tokio_rustls::rustls::crypto::ring::sign::any_supported_type;
use tokio_rustls::rustls::server::{ClientHello, ResolvesServerCert};
use tokio_rustls::rustls::sign::CertifiedKey;
use tokio_rustls::rustls::ServerConfig;
use tokio_rustls::TlsAcceptor;
use tower::ServiceExt;

/// How often the certificate's file is looked at for a renewal.
const RECHECK: Duration = Duration::from_secs(600);

/// A connection idle this long is pinged: one gone quiet (a phone that lost
/// its network) is closed instead of held.
const KEEPALIVE: Duration = Duration::from_secs(60);
const KEEPALIVE_TIMEOUT: Duration = Duration::from_secs(20);

#[derive(Clone)]
pub struct Config {
    pub bind: SocketAddr,
    pub cert: PathBuf,
    pub key: PathBuf,
}

impl Config {
    /// From `TLS_PORT`, `TLS_CERT`, `TLS_KEY` (and `TLS_BIND`): None unless
    /// all three are set.
    pub fn from_env() -> Result<Option<Self>, String> {
        let (Ok(port), Ok(cert), Ok(key)) = (
            std::env::var("TLS_PORT"),
            std::env::var("TLS_CERT"),
            std::env::var("TLS_KEY"),
        ) else {
            return Ok(None);
        };
        let host = std::env::var("TLS_BIND").unwrap_or_else(|_| "0.0.0.0".to_string());
        let bind = format!("{host}:{port}")
            .parse()
            .map_err(|e| format!("TLS_BIND/TLS_PORT: {e}"))?;
        Ok(Some(Self {
            bind,
            cert: cert.into(),
            key: key.into(),
        }))
    }
}

fn load(config: &Config) -> io::Result<CertifiedKey> {
    let certs = rustls_pemfile::certs(&mut io::BufReader::new(std::fs::File::open(&config.cert)?))
        .collect::<Result<Vec<_>, _>>()?;
    let key =
        rustls_pemfile::private_key(&mut io::BufReader::new(std::fs::File::open(&config.key)?))?
            .ok_or_else(|| io::Error::other("no private key in TLS_KEY"))?;
    let key = any_supported_type(&key).map_err(io::Error::other)?;
    Ok(CertifiedKey::new(certs, key))
}

fn modified(config: &Config) -> Option<SystemTime> {
    std::fs::metadata(&config.cert)
        .and_then(|m| m.modified())
        .ok()
}

/// The certificate in use, swapped when its file changes.
#[derive(Debug)]
struct Current(RwLock<Arc<CertifiedKey>>);

impl ResolvesServerCert for Current {
    fn resolve(&self, _hello: ClientHello<'_>) -> Option<Arc<CertifiedKey>> {
        Some(self.0.read().unwrap_or_else(|e| e.into_inner()).clone())
    }
}

/// Serve `app` over TLS until `stop`. A renewed certificate is used for new
/// connections from when it is noticed.
pub async fn serve(
    config: Config,
    app: axum::Router,
    mut stop: watch::Receiver<bool>,
) -> io::Result<()> {
    let current = Arc::new(Current(RwLock::new(Arc::new(load(&config)?))));
    {
        let (current, config) = (current.clone(), config.clone());
        tokio::spawn(async move {
            let mut seen = modified(&config);
            loop {
                tokio::time::sleep(RECHECK).await;
                let now = modified(&config);
                if now == seen {
                    continue;
                }
                match load(&config) {
                    Ok(key) => {
                        *current.0.write().unwrap_or_else(|e| e.into_inner()) = Arc::new(key);
                        seen = now;
                        tracing::info!(cert = %config.cert.display(), "certificate renewed");
                    }
                    Err(error) => tracing::warn!(%error, "renewed certificate didn't load"),
                }
            }
        });
    }
    let mut tls = ServerConfig::builder()
        .with_no_client_auth()
        .with_cert_resolver(current);
    tls.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
    let acceptor = TlsAcceptor::from(Arc::new(tls));
    let listener = TcpListener::bind(config.bind).await?;
    println!("Server listening on {} (TLS, for the apps)", config.bind);
    let mut warned: Option<std::time::Instant> = None;
    loop {
        let accepted = tokio::select! {
            accepted = listener.accept() => accepted,
            _ = stop.wait_for(|s| *s) => return Ok(()),
        };
        let (tcp, peer) = match accepted {
            Ok(accepted) => accepted,
            Err(error) => {
                // Out of sockets (or the like): retrying at once spins a
                // core and floods the log. A moment, then again; said at
                // most once a second.
                if warned.is_none_or(|at| at.elapsed() > Duration::from_secs(1)) {
                    tracing::warn!(%error, "accepting a connection");
                    warned = Some(std::time::Instant::now());
                }
                tokio::time::sleep(Duration::from_millis(100)).await;
                continue;
            }
        };
        let _ = tcp.set_nodelay(true);
        let (acceptor, app) = (acceptor.clone(), app.clone());
        tokio::spawn(async move {
            // A client that never finishes its handshake gives its socket
            // back.
            let Ok(Ok(stream)) = tokio::time::timeout(HANDSHAKE, acceptor.accept(tcp)).await else {
                return;
            };
            // Who it is, as Caddy would say: the peer, never what the client
            // claims (passkey ceremonies are limited per address).
            let Ok(peer_ip) = axum::http::HeaderValue::from_str(&peer.ip().to_string()) else {
                return;
            };
            let service = app.map_request(move |mut request: axum::http::Request<_>| {
                request
                    .headers_mut()
                    .insert("x-forwarded-for", peer_ip.clone());
                request
                    .extensions_mut()
                    .insert(axum::extract::ConnectInfo(peer));
                request
            });
            let mut builder = Builder::new(TokioExecutor::new());
            builder
                .http2()
                .timer(hyper_util::rt::TokioTimer::new())
                .keep_alive_interval(Some(KEEPALIVE))
                .keep_alive_timeout(KEEPALIVE_TIMEOUT);
            let _ = builder
                .serve_connection(TokioIo::new(stream), TowerToHyperService::new(service))
                .await;
        });
    }
}
