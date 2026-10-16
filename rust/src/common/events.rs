//! Helpers for the `subscribe_*_events` listener threads.
//!
//! D-Bus `PropertiesChanged` can burst at tens/sec (BlueZ RSSI, NM signal
//! strength), so [`ThrottleMap`] rate-limits noisy members per object path
//! while letting Added/Removed pass through immediately.

use std::collections::HashMap;
use std::time::{Duration, Instant};
use zbus::MatchRule;

use super::error::ApiResult;

/// Default throttle window for noisy `PropertiesChanged` bursts.
pub const PROPS_THROTTLE: Duration = Duration::from_millis(800);

/// Per-path last-emit timestamps. Returns `true` when the caller should emit.
#[derive(Debug, Default)]
pub struct ThrottleMap {
    window: Duration,
    last_emit: HashMap<String, Instant>,
}

impl ThrottleMap {
    pub fn new(window: Duration) -> Self {
        Self {
            window,
            last_emit: HashMap::new(),
        }
    }

    /// `throttled=false` always emits (Added/Removed). `throttled=true`
    /// emits at most once per [`PROPS_THROTTLE`] window per path.
    pub fn should_emit(&mut self, path: &str, throttled: bool) -> bool {
        if !throttled {
            return true;
        }
        let now = Instant::now();
        match self.last_emit.get(path) {
            Some(prev) if now.duration_since(*prev) < self.window => false,
            _ => {
                self.last_emit.insert(path.to_string(), now);
                true
            }
        }
    }
}

/// Signal match rule scoped to `sender` + `interface` under `path_namespace`.
/// Scoping matters: without it every `PropertiesChanged` on the system bus
/// (BlueZ, NM, UPower, ...) would wake the Dart isolate.
///
/// Takes `&'static str` (module constants) so the built rule is `'static`.
pub fn signal_rule(
    sender: &'static str,
    interface: &'static str,
    path_namespace: &'static str,
) -> ApiResult<MatchRule<'static>> {
    let rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(sender)
        .map_err(|e| format!("Failed to build match rule for {interface}: {e}"))?
        .interface(interface)
        .map_err(|e| format!("Failed to build match rule for {interface}: {e}"))?
        .path_namespace(path_namespace)
        .map_err(|e| format!("Failed to build match rule for {interface}: {e}"))?
        .build();
    Ok(rule)
}
