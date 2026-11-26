//! Client ID metadata documents (CIMD): a client whose `client_id` is an
//! `https://` URL is not registered here; the URL serves its metadata
//! (name, redirect URIs) and this server fetches it when the client asks
//! to connect. The MCP authorization spec's alternative to registering
//! first (DCR, `/api/oauth/register`, which stays).
//!
//! The fetch is a request this server makes to an address anyone can
//! name, before anyone has signed in, so it is kept to what a metadata
//! document needs:
//!
//! - `https` on the default port, a domain name (no IP literal), a path,
//!   no credentials, query-free form as written (canonical: the URL must
//!   read back exactly as it was sent).
//! - The name is resolved here, every address it resolves to must be a
//!   public one ([`public_ip`]), and the connection goes to that vetted
//!   address, so the name can't be re-pointed at a private one between
//!   the check and the connection.
//! - No redirects, 5 s for all of it, at most 64 KB, a few at once.
//! - A document read is kept an hour; a failure, a minute.
//!
//! What is fetched only ever lives in memory and in `assistant_clients`
//! (as a registered client's row would), so a grant and its tokens are
//! keyed by the URL like any client id.

use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use serde_json::Value;
use url::Url;

use crate::db::Client;

/// All of a fetch: resolving, connecting, TLS, the response.
const FETCH_TIMEOUT: Duration = Duration::from_secs(5);
/// A document past this is refused.
pub const MAX_DOCUMENT: usize = 64 * 1024;
/// How long a document read is trusted.
const FRESH: Duration = Duration::from_secs(60 * 60);
/// How long a failure is remembered, so a page reloaded in a loop doesn't
/// make this server fetch again each time.
const FAILED: Duration = Duration::from_secs(60);
/// Documents held at once; past it the stale ones go, then all.
const CACHE_ENTRIES: usize = 1024;
/// Fetches in flight at once, everyone's.
const CONCURRENT_FETCHES: usize = 8;
/// The longest client id URL.
const MAX_URL: usize = 2048;
/// A document's redirect URIs: as many, and as long together, as a
/// registration may have.
const MAX_REDIRECTS: usize = 10;

/// Whether a client id is a metadata document's URL rather than a
/// registered id (a UUID). Only these are fetched.
pub fn is_url(client_id: &str) -> bool {
    client_id.starts_with("https://")
}

/// A client id URL this server will fetch, or why not.
pub fn client_id_url(client_id: &str) -> Result<Url, String> {
    const NOT: &str = "The assistant's id isn't an address its details can be read from";
    if client_id.len() > MAX_URL {
        return Err(NOT.into());
    }
    let url = Url::parse(client_id).map_err(|_| NOT.to_string())?;
    let canonical = url.as_str() == client_id;
    let domain = match url.host() {
        Some(url::Host::Domain(d)) => d.to_string(),
        _ => return Err(NOT.into()),
    };
    if url.scheme() != "https"
        || !canonical
        || !url.username().is_empty()
        || url.password().is_some()
        || url.fragment().is_some()
        || url.port().is_some()
        || url.path() == "/"
        || !domain.contains('.')
        || domain.ends_with(".localhost")
        || domain.ends_with(".local")
        || domain.ends_with(".internal")
    {
        return Err(NOT.into());
    }
    Ok(url)
}

/// An address on the public internet: never this machine, a private or
/// carrier network, link-local, multicast, reserved or documentation
/// ranges, and for IPv6 only global unicast (an IPv4 address carried in
/// IPv6 is judged as that IPv4 address).
pub fn public_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => public_v4(v4),
        IpAddr::V6(v6) => public_v6(v6),
    }
}

fn public_v4(ip: Ipv4Addr) -> bool {
    let [a, b, c, _] = ip.octets();
    !(ip.is_unspecified()
        || ip.is_loopback()
        || ip.is_private()
        || ip.is_link_local()
        || ip.is_broadcast()
        || ip.is_multicast()
        || ip.is_documentation()
        || a == 0
        // Carrier-grade NAT, 100.64.0.0/10.
        || (a == 100 && (b & 0xc0) == 64)
        // IETF protocol assignments, 192.0.0.0/24.
        || (a == 192 && b == 0 && c == 0)
        // Benchmarking, 198.18.0.0/15.
        || (a == 198 && (b & 0xfe) == 18)
        // Reserved, 240.0.0.0/4.
        || a >= 240)
}

fn public_v6(ip: Ipv6Addr) -> bool {
    if let Some(v4) = ip.to_ipv4_mapped() {
        return public_v4(v4);
    }
    let s = ip.segments();
    // NAT64 (64:ff9b::/96) carries an IPv4 address: judge that.
    if s[0] == 0x64 && s[1] == 0xff9b && s[2..6] == [0, 0, 0, 0] {
        return public_v4(Ipv4Addr::new(
            (s[6] >> 8) as u8,
            s[6] as u8,
            (s[7] >> 8) as u8,
            s[7] as u8,
        ));
    }
    // 6to4 (2002::/16) does too.
    if s[0] == 0x2002 {
        return public_v4(Ipv4Addr::new(
            (s[1] >> 8) as u8,
            s[1] as u8,
            (s[2] >> 8) as u8,
            s[2] as u8,
        ));
    }
    // Global unicast is 2000::/3; within it, Teredo (2001::/32), ORCHID and
    // benchmarking (2001:2::/48, 2001:10::/28, 2001:20::/28) and
    // documentation (2001:db8::/32, 3fff::/20) are not addresses to fetch.
    (s[0] & 0xe000) == 0x2000
        && !(s[0] == 0x2001 && s[1] == 0)
        && !(s[0] == 0x2001 && s[1] == 0x0002 && s[2] == 0)
        && !(s[0] == 0x2001 && (s[1] & 0xfff0) == 0x0010)
        && !(s[0] == 0x2001 && (s[1] & 0xfff0) == 0x0020)
        && !(s[0] == 0x2001 && s[1] == 0x0db8)
        && !(s[0] == 0x3fff && (s[1] & 0xf000) == 0)
}

/// What a document says, once checked: the client as this server keeps it.
pub fn parse_document(client_id: &str, bytes: &[u8]) -> Result<Client, String> {
    let doc: Value = serde_json::from_slice(bytes)
        .map_err(|_| "The assistant's details aren't JSON".to_string())?;
    if doc.get("client_id").and_then(Value::as_str) != Some(client_id) {
        return Err("The assistant's details are for another id".into());
    }
    if doc.get("client_secret").is_some() {
        return Err("The assistant's details include a secret".into());
    }
    match doc.get("token_endpoint_auth_method") {
        None => {}
        Some(m) if m.as_str() == Some("none") => {}
        Some(_) => return Err("The assistant signs in a way this server doesn't support".into()),
    }
    let uris: Vec<String> = doc
        .get("redirect_uris")
        .and_then(Value::as_array)
        .map(|uris| {
            uris.iter()
                .filter_map(|u| u.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    if uris.is_empty()
        || uris.len() > MAX_REDIRECTS
        || uris.iter().map(String::len).sum::<usize>() > super::MAX_REDIRECT_BYTES
        || !uris.iter().all(|u| super::redirect_allowed(u))
    {
        return Err("The assistant's return addresses can't be used".into());
    }
    let host = Url::parse(client_id)
        .ok()
        .and_then(|u| u.host_str().map(str::to_string))
        .unwrap_or_default();
    let name: String = doc
        .get("client_name")
        .and_then(Value::as_str)
        .unwrap_or("")
        .chars()
        .filter(|c| !c.is_control())
        .take(80)
        .collect();
    let name = name.trim();
    Ok(Client {
        client_id: client_id.to_string(),
        client_name: if name.is_empty() {
            host
        } else {
            name.to_string()
        },
        redirect_uris: uris,
    })
}

/// Reads a client id URL: the network in the server, a table in tests.
#[tonic::async_trait]
pub trait Fetch: Send + Sync {
    async fn get(&self, url: &Url) -> Result<Vec<u8>, String>;
}

/// What a read of a document came to, and when.
type Read = (Instant, Result<Client, String>);

/// The fetches, and the documents they read.
pub struct Cimd {
    fetch: Arc<dyn Fetch>,
    cache: Mutex<HashMap<String, Read>>,
    in_flight: tokio::sync::Semaphore,
}

impl Cimd {
    pub fn new(fetch: Arc<dyn Fetch>) -> Self {
        Self {
            fetch,
            cache: Mutex::new(HashMap::new()),
            in_flight: tokio::sync::Semaphore::new(CONCURRENT_FETCHES),
        }
    }

    /// Fetches over the internet, to public addresses only.
    pub fn https() -> Self {
        Self::new(Arc::new(Https::new()))
    }

    /// The client a client id URL describes, checked, from the cache
    /// while it is fresh.
    pub async fn resolve(&self, client_id: &str) -> Result<Client, String> {
        let url = client_id_url(client_id)?;
        if let Some(cached) = self.cached(client_id) {
            return cached;
        }
        let read = match self.in_flight.try_acquire() {
            Ok(_permit) => self.fetch.get(&url).await,
            Err(_) => return Err("Too many assistants are connecting; try again".into()),
        };
        let result = match read {
            Ok(bytes) => parse_document(client_id, &bytes),
            Err(error) => {
                tracing::info!(%error, client_id, "reading a client metadata document");
                Err(format!(
                    "Couldn't read the assistant's details from {}",
                    url.host_str().unwrap_or_default()
                ))
            }
        };
        self.remember(client_id, &result);
        result
    }

    fn cached(&self, client_id: &str) -> Option<Result<Client, String>> {
        let cache = self.cache.lock().unwrap_or_else(|e| e.into_inner());
        let (at, result) = cache.get(client_id)?;
        let ttl = if result.is_ok() { FRESH } else { FAILED };
        (at.elapsed() < ttl).then(|| result.clone())
    }

    fn remember(&self, client_id: &str, result: &Result<Client, String>) {
        let mut cache = self.cache.lock().unwrap_or_else(|e| e.into_inner());
        if cache.len() >= CACHE_ENTRIES {
            cache.retain(|_, (at, r)| at.elapsed() < if r.is_ok() { FRESH } else { FAILED });
            if cache.len() >= CACHE_ENTRIES {
                cache.clear();
            }
        }
        cache.insert(client_id.to_string(), (Instant::now(), result.clone()));
    }
}

/// The real fetch: resolve, vet every address, connect to a vetted one,
/// TLS against the public roots for the URL's name, one GET.
pub struct Https {
    tls: tokio_rustls::TlsConnector,
}

impl Default for Https {
    fn default() -> Self {
        Self::new()
    }
}

impl Https {
    pub fn new() -> Self {
        use tokio_rustls::rustls;
        let roots = rustls::RootCertStore {
            roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
        };
        let config = rustls::ClientConfig::builder_with_provider(Arc::new(
            rustls::crypto::ring::default_provider(),
        ))
        .with_safe_default_protocol_versions()
        .expect("ring supports the default TLS versions")
        .with_root_certificates(roots)
        .with_no_client_auth();
        Self {
            tls: tokio_rustls::TlsConnector::from(Arc::new(config)),
        }
    }

    async fn fetch(&self, url: &Url) -> Result<Vec<u8>, String> {
        use http_body_util::BodyExt;
        use hyper::body::Bytes;

        let host = url.host_str().ok_or("no host")?.to_string();
        let addresses: Vec<SocketAddr> = tokio::net::lookup_host((host.as_str(), 443))
            .await
            .map_err(|e| format!("resolving: {e}"))?
            .collect();
        let address = vetted(&addresses)?;
        let tcp = tokio::net::TcpStream::connect(address)
            .await
            .map_err(|e| format!("connecting: {e}"))?;
        let name = tokio_rustls::rustls::pki_types::ServerName::try_from(host.clone())
            .map_err(|e| format!("name: {e}"))?;
        let tls = self
            .tls
            .connect(name, tcp)
            .await
            .map_err(|e| format!("tls: {e}"))?;
        let (mut sender, connection) =
            hyper::client::conn::http1::handshake(hyper_util::rt::TokioIo::new(tls))
                .await
                .map_err(|e| format!("http: {e}"))?;
        let driver = tokio::spawn(connection);
        let path = match url.query() {
            Some(q) => format!("{}?{q}", url.path()),
            None => url.path().to_string(),
        };
        let request = http::Request::get(path)
            .header(http::header::HOST, host)
            .header(http::header::ACCEPT, "application/json")
            .header(http::header::USER_AGENT, "schlift-oauth")
            .body(http_body_util::Empty::<Bytes>::new())
            .map_err(|e| format!("request: {e}"))?;
        let response = sender
            .send_request(request)
            .await
            .map_err(|e| format!("sending: {e}"))?;
        // A redirect is refused like any other answer that isn't the document.
        if response.status() != http::StatusCode::OK {
            driver.abort();
            return Err(format!("status {}", response.status()));
        }
        let mut body = response.into_body();
        let mut out = Vec::new();
        while let Some(frame) = body.frame().await {
            let frame = frame.map_err(|e| format!("reading: {e}"))?;
            if let Some(data) = frame.data_ref() {
                if out.len() + data.len() > MAX_DOCUMENT {
                    driver.abort();
                    return Err("over 64 KB".into());
                }
                out.extend_from_slice(data);
            }
        }
        driver.abort();
        Ok(out)
    }
}

/// The address to connect to: the first, once every one is public. A name
/// with any private address is refused outright rather than worked round.
pub fn vetted(addresses: &[SocketAddr]) -> Result<SocketAddr, String> {
    let first = *addresses.first().ok_or("resolves to nothing")?;
    if let Some(bad) = addresses.iter().find(|a| !public_ip(a.ip())) {
        return Err(format!("resolves to a non-public address {}", bad.ip()));
    }
    Ok(first)
}

#[tonic::async_trait]
impl Fetch for Https {
    async fn get(&self, url: &Url) -> Result<Vec<u8>, String> {
        tokio::time::timeout(FETCH_TIMEOUT, self.fetch(url))
            .await
            .map_err(|_| "timed out".to_string())?
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_public_addresses_are_fetched() {
        for bad in [
            "0.0.0.0",
            "0.1.2.3",
            "127.0.0.1",
            "10.1.2.3",
            "172.16.0.1",
            "192.168.10.2",
            "169.254.169.254",
            "100.64.0.1",
            "100.127.255.255",
            "192.0.0.8",
            "192.0.2.1",
            "198.18.0.1",
            "198.51.100.1",
            "203.0.113.1",
            "224.0.0.1",
            "240.0.0.1",
            "255.255.255.255",
            "::",
            "::1",
            "::ffff:127.0.0.1",
            "::ffff:10.0.0.1",
            "::127.0.0.1",
            "64:ff9b::a00:1",
            "2002:a00:1::",
            "2002:7f00:1::",
            "fc00::1",
            "fd12:3456::1",
            "fe80::1",
            "fec0::1",
            "ff02::1",
            "2001::1",
            "2001:db8::1",
            "2001:10::1",
            "3fff::1",
        ] {
            assert!(!public_ip(bad.parse().unwrap()), "{bad}");
        }
        for ok in [
            "1.1.1.1",
            "8.8.8.8",
            "100.128.0.1",
            "172.32.0.1",
            "160.79.104.10",
            "::ffff:8.8.8.8",
            "64:ff9b::808:808",
            "2002:808:808::",
            "2606:4700:4700::1111",
            "2a00:1450:4001::1",
        ] {
            assert!(public_ip(ok.parse().unwrap()), "{ok}");
        }
    }

    #[test]
    fn a_name_with_any_private_address_is_refused() {
        let public: SocketAddr = "1.1.1.1:443".parse().unwrap();
        let private: SocketAddr = "10.0.0.1:443".parse().unwrap();
        assert_eq!(vetted(&[public]), Ok(public));
        assert!(vetted(&[public, private]).is_err());
        assert!(vetted(&[private, public]).is_err());
        assert!(vetted(&[]).is_err());
    }

    #[test]
    fn only_plain_https_urls_are_client_ids() {
        assert!(client_id_url("https://claude.ai/oauth/mcp-oauth-client-metadata").is_ok());
        assert!(client_id_url("https://example.com/client.json?v=2").is_ok());
        for bad in [
            "http://claude.ai/client.json",
            "https://claude.ai",
            "https://claude.ai/",
            "https://claude.ai:8443/client.json",
            "https://user:pw@claude.ai/client.json",
            "https://claude.ai/client.json#x",
            "https://claude.ai/a/../client.json",
            "https://CLAUDE.ai/client.json",
            "https://127.0.0.1/client.json",
            "https://[::1]/client.json",
            "https://localhost/client.json",
            "https://box.localhost/client.json",
            "https://printer.local/client.json",
            "https://metadata.google.internal/computeMetadata",
            "not a url",
        ] {
            assert!(client_id_url(bad).is_err(), "{bad}");
        }
    }

    const ID: &str = "https://claude.ai/oauth/mcp-oauth-client-metadata";

    #[test]
    fn a_document_names_its_own_id_and_safe_redirects() {
        let doc = |v: Value| parse_document(ID, v.to_string().as_bytes());
        let client = doc(serde_json::json!({
            "client_id": ID,
            "client_name": "Claude\n",
            "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
            "token_endpoint_auth_method": "none",
        }))
        .unwrap();
        assert_eq!(client.client_name, "Claude");
        assert_eq!(
            client.redirect_uris,
            ["https://claude.ai/api/mcp/auth_callback"]
        );
        let unnamed = doc(serde_json::json!({
            "client_id": ID, "redirect_uris": ["https://claude.ai/cb"] }))
        .unwrap();
        assert_eq!(unnamed.client_name, "claude.ai");

        for bad in [
            serde_json::json!({ "client_id": "https://evil.example/c", "redirect_uris": ["https://claude.ai/cb"] }),
            serde_json::json!({ "redirect_uris": ["https://claude.ai/cb"] }),
            serde_json::json!({ "client_id": ID, "redirect_uris": [] }),
            serde_json::json!({ "client_id": ID, "redirect_uris": ["javascript:alert(1)"] }),
            serde_json::json!({ "client_id": ID, "redirect_uris": ["http://evil.example/cb"] }),
            serde_json::json!({ "client_id": ID, "redirect_uris": ["https://claude.ai/cb"], "client_secret": "x" }),
            serde_json::json!({ "client_id": ID, "redirect_uris": ["https://claude.ai/cb"], "token_endpoint_auth_method": "private_key_jwt" }),
        ] {
            assert!(doc(bad.clone()).is_err(), "{bad}");
        }
        assert!(parse_document(ID, b"<html>").is_err());
    }

    /// The real fetch, over the internet: `cargo test -- --ignored`.
    #[tokio::test]
    #[ignore = "reaches the internet"]
    async fn the_real_fetch_reads_a_public_document() {
        let https = Https::new();
        let url = Url::parse("https://registry.npmjs.org/left-pad/latest").unwrap();
        let bytes = https.get(&url).await.unwrap();
        let doc: Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(doc["name"], "left-pad");
        // Over 64 KB, refused.
        let big = Url::parse("https://registry.npmjs.org/react").unwrap();
        assert_eq!(https.get(&big).await.unwrap_err(), "over 64 KB");
        // A redirect is not followed.
        let moved = Url::parse("https://google.com/search").unwrap();
        assert!(https.get(&moved).await.unwrap_err().starts_with("status 3"));
    }

    struct Counting(std::sync::atomic::AtomicUsize, Result<Vec<u8>, String>);

    #[tonic::async_trait]
    impl Fetch for Counting {
        async fn get(&self, _: &Url) -> Result<Vec<u8>, String> {
            self.0.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            self.1.clone()
        }
    }

    #[tokio::test]
    async fn a_document_is_read_once_an_hour() {
        let body =
            serde_json::json!({ "client_id": ID, "redirect_uris": ["https://claude.ai/cb"] });
        let fetch = Arc::new(Counting(0.into(), Ok(body.to_string().into_bytes())));
        let cimd = Cimd::new(fetch.clone());
        assert!(cimd.resolve(ID).await.is_ok());
        assert!(cimd.resolve(ID).await.is_ok());
        assert_eq!(fetch.0.load(std::sync::atomic::Ordering::SeqCst), 1);
        // A URL that isn't one is never fetched.
        assert!(cimd.resolve("https://localhost/x").await.is_err());
        assert_eq!(fetch.0.load(std::sync::atomic::Ordering::SeqCst), 1);

        let failing = Arc::new(Counting(0.into(), Err("refused".into())));
        let cimd = Cimd::new(failing.clone());
        let error = cimd.resolve(ID).await.unwrap_err();
        assert_eq!(
            error,
            "Couldn't read the assistant's details from claude.ai"
        );
        assert!(cimd.resolve(ID).await.is_err());
        assert_eq!(failing.0.load(std::sync::atomic::Ordering::SeqCst), 1);
    }
}
