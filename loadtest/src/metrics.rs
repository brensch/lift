//! Latency and errors per operation, shared by every client.

use hdrhistogram::Histogram;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fmt::Display;
use std::future::Future;
use std::sync::Mutex;
use std::time::{Duration, Instant};

#[derive(Default)]
pub struct Metrics(Mutex<BTreeMap<&'static str, Op>>);

struct Op {
    /// Microseconds.
    latency: Histogram<u64>,
    errors: BTreeMap<String, u64>,
}

impl Default for Op {
    fn default() -> Self {
        Op {
            // 1 µs to 10 minutes, three significant figures.
            latency: Histogram::new_with_bounds(1, 600_000_000, 3).expect("valid bounds"),
            errors: BTreeMap::new(),
        }
    }
}

/// One operation's numbers, as reported.
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct OpSummary {
    pub count: u64,
    pub errors: BTreeMap<String, u64>,
    pub p50_ms: f64,
    pub p95_ms: f64,
    pub p99_ms: f64,
    pub max_ms: f64,
}

impl Metrics {
    pub fn record(&self, op: &'static str, took: Duration) {
        let micros = (took.as_micros() as u64).clamp(1, 600_000_000);
        let mut ops = self.0.lock().expect("metrics lock");
        let _ = ops.entry(op).or_default().latency.record(micros);
    }

    pub fn error(&self, op: &'static str, why: impl Display) {
        // The first line names the error without its per-request detail.
        let why = why.to_string();
        let why: String = why.lines().next().unwrap_or("").chars().take(120).collect();
        let mut ops = self.0.lock().expect("metrics lock");
        *ops.entry(op).or_default().errors.entry(why).or_default() += 1;
    }

    /// Run `f`, recording its latency on success and its error otherwise.
    pub async fn time<T, E: Display>(
        &self,
        op: &'static str,
        f: impl Future<Output = Result<T, E>>,
    ) -> Result<T, String> {
        let start = Instant::now();
        match f.await {
            Ok(value) => {
                self.record(op, start.elapsed());
                Ok(value)
            }
            Err(error) => {
                let message = error.to_string();
                self.error(op, &message);
                Err(format!("{op}: {message}"))
            }
        }
    }

    /// [Metrics::time] for synchronous work: the phone's core.
    pub fn time_sync<T, E: Display>(
        &self,
        op: &'static str,
        f: impl FnOnce() -> Result<T, E>,
    ) -> Result<T, String> {
        let start = Instant::now();
        match f() {
            Ok(value) => {
                self.record(op, start.elapsed());
                Ok(value)
            }
            Err(error) => {
                let message = error.to_string();
                self.error(op, &message);
                Err(format!("{op}: {message}"))
            }
        }
    }

    pub fn summary(&self) -> BTreeMap<String, OpSummary> {
        let ops = self.0.lock().expect("metrics lock");
        let ms = |micros: u64| micros as f64 / 1000.0;
        ops.iter()
            .map(|(name, op)| {
                let h = &op.latency;
                (
                    name.to_string(),
                    OpSummary {
                        count: h.len(),
                        errors: op.errors.clone(),
                        p50_ms: ms(h.value_at_quantile(0.50)),
                        p95_ms: ms(h.value_at_quantile(0.95)),
                        p99_ms: ms(h.value_at_quantile(0.99)),
                        max_ms: ms(h.max()),
                    },
                )
            })
            .collect()
    }
}
