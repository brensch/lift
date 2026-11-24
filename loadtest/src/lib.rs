//! What the load test binaries share.

pub mod metrics;

use tonic::transport::{ClientTlsConfig, Endpoint};

/// A connection to `url`: plain HTTP/2 for a server on this machine or
/// through a tunnel, TLS for one behind Caddy (`https://`), as phones reach
/// schlift.com.
pub fn endpoint(url: &str) -> Result<Endpoint, String> {
    let endpoint = Endpoint::from_shared(url.to_string())
        .map_err(|e| e.to_string())?
        .tcp_nodelay(true)
        .http2_adaptive_window(true);
    if url.starts_with("https://") {
        return endpoint
            .tls_config(ClientTlsConfig::new().with_webpki_roots())
            .map_err(|e| e.to_string());
    }
    Ok(endpoint)
}
