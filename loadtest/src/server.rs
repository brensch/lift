//! The server under test: started from its release binary in a fresh data
//! directory, watched through /proc, and stopped at the end.

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::process::{Child, Command};

/// What the browser would send as its origin; passkeys are bound to it.
pub const ORIGIN: &str = "http://localhost:5173";

pub struct Server {
    child: Child,
    pub url: String,
    pub data_dir: PathBuf,
    usage: Arc<Mutex<Usage>>,
}

/// The server process's resource use over the run.
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct Usage {
    /// CPU seconds (user + system) since it started.
    pub cpu_seconds: f64,
    pub rss_max_mb: f64,
    pub db_mb: f64,
}

impl Server {
    pub async fn spawn(bin: &Path, data_dir: &Path) -> Result<Self, String> {
        std::fs::create_dir_all(data_dir).map_err(|e| e.to_string())?;
        let port = free_port()?;
        let log = std::fs::File::create(data_dir.join("server.log")).map_err(|e| e.to_string())?;
        let child = Command::new(bin)
            .env("DATA_DIR", data_dir)
            .env("PORT", port.to_string())
            .env("RUST_LOG", "warn")
            .env("WEBAUTHN_RP_ID", "localhost")
            .env("WEBAUTHN_RP_ORIGIN", ORIGIN)
            .env_remove("MIN_APP_VERSION")
            .stdout(log.try_clone().map_err(|e| e.to_string())?)
            .stderr(log)
            .kill_on_drop(true)
            .spawn()
            .map_err(|e| format!("starting {}: {e}", bin.display()))?;
        let server = Server {
            child,
            url: format!("http://127.0.0.1:{port}"),
            data_dir: data_dir.to_path_buf(),
            usage: Arc::default(),
        };
        for _ in 0..100 {
            if healthy(port).await {
                server.sample();
                return Ok(server);
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        Err(format!(
            "server not healthy on port {port}; see {}",
            data_dir.join("server.log").display()
        ))
    }

    /// Sample CPU and memory twice a second until the process ends.
    fn sample(&self) {
        let Some(pid) = self.child.id() else { return };
        let usage = self.usage.clone();
        tokio::spawn(async move {
            let ticks = 100.0; // USER_HZ on Linux
            loop {
                let Ok(stat) = std::fs::read_to_string(format!("/proc/{pid}/stat")) else {
                    return;
                };
                // Fields after the command name (which may hold spaces).
                let rest = stat.rsplit(')').next().unwrap_or("");
                let fields: Vec<&str> = rest.split_whitespace().collect();
                let cpu = |i: usize| fields.get(i).and_then(|f| f.parse::<f64>().ok());
                let rss_kb = std::fs::read_to_string(format!("/proc/{pid}/status"))
                    .ok()
                    .and_then(|s| {
                        s.lines()
                            .find(|l| l.starts_with("VmRSS:"))
                            .and_then(|l| l.split_whitespace().nth(1)?.parse::<f64>().ok())
                    });
                {
                    let mut u = usage.lock().expect("usage lock");
                    // utime and stime are fields 14 and 15, 11 and 12 here.
                    if let (Some(user), Some(system)) = (cpu(11), cpu(12)) {
                        u.cpu_seconds = (user + system) / ticks;
                    }
                    if let Some(kb) = rss_kb {
                        u.rss_max_mb = u.rss_max_mb.max(kb / 1024.0);
                    }
                }
                tokio::time::sleep(Duration::from_millis(500)).await;
            }
        });
    }

    pub fn usage(&self) -> Usage {
        let mut usage = self.usage.lock().expect("usage lock").clone();
        let size = |name: &str| {
            std::fs::metadata(self.data_dir.join(name))
                .map(|m| m.len())
                .unwrap_or(0)
        };
        usage.db_mb = (size("server.sqlite") + size("server.sqlite-wal")) as f64 / 1e6;
        usage
    }

    pub async fn stop(mut self) {
        let _ = self.child.kill().await;
    }
}

fn free_port() -> Result<u16, String> {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").map_err(|e| e.to_string())?;
    Ok(listener.local_addr().map_err(|e| e.to_string())?.port())
}

async fn healthy(port: u16) -> bool {
    let Ok(mut stream) = TcpStream::connect(("127.0.0.1", port)).await else {
        return false;
    };
    let request = b"GET /api/health HTTP/1.0\r\nHost: localhost\r\n\r\n";
    if stream.write_all(request).await.is_err() {
        return false;
    }
    let mut body = String::new();
    let _ = stream.read_to_string(&mut body).await;
    body.ends_with("ok")
}
