//! A limit on how often one client may do something: a burst, then one
//! each refill. For the unauthenticated calls that make rows (sign-in
//! ceremonies, assistants registering), where a limit on what is in flight
//! alone let a caller go round at line rate.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// Clients remembered at once: past it, those with a full allowance (idle a
/// while) are forgotten, and with none to forget, everyone new is refused.
const MAX_CLIENTS: usize = 100_000;

pub struct Limiter {
    burst: f64,
    refill: Duration,
    clients: Mutex<HashMap<String, (f64, Instant)>>,
}

impl Limiter {
    pub fn new(burst: u32, refill: Duration) -> Self {
        Self {
            burst: f64::from(burst),
            refill,
            clients: Mutex::new(HashMap::new()),
        }
    }

    /// Spend one of `client`'s allowance: false when it has none left.
    pub fn allow(&self, client: &str) -> bool {
        let mut clients = self.clients.lock().unwrap_or_else(|e| e.into_inner());
        let refilled = |(left, at): (f64, Instant)| {
            (left + at.elapsed().as_secs_f64() / self.refill.as_secs_f64()).min(self.burst)
        };
        if clients.len() >= MAX_CLIENTS && !clients.contains_key(client) {
            clients.retain(|_, entry| refilled(*entry) < self.burst);
            if clients.len() >= MAX_CLIENTS {
                return false;
            }
        }
        let left = clients
            .get(client)
            .map_or(self.burst, |entry| refilled(*entry));
        if left < 1.0 {
            return false;
        }
        clients.insert(client.to_string(), (left - 1.0, Instant::now()));
        true
    }
}

/// One client, from the address a request came from: an IPv6 address by
/// its /64, which one host can move freely within.
pub fn client_key(ip: &str) -> String {
    match ip.parse::<std::net::IpAddr>() {
        Ok(std::net::IpAddr::V6(v6)) => {
            let s = v6.segments();
            format!("{:x}:{:x}:{:x}:{:x}::/64", s[0], s[1], s[2], s[3])
        }
        _ => ip.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_client_gets_its_burst_then_waits() {
        let limiter = Limiter::new(3, Duration::from_secs(3600));
        assert!((0..3).all(|_| limiter.allow("a")));
        assert!(!limiter.allow("a"), "past the burst");
        assert!(limiter.allow("b"), "others have their own");
    }

    #[test]
    fn an_ipv6_host_is_one_client_across_its_64() {
        assert_eq!(
            client_key("2001:db8:1:2:aaaa::1"),
            client_key("2001:db8:1:2:bbbb::9")
        );
        assert_eq!(client_key("203.0.113.7"), "203.0.113.7");
    }
}
