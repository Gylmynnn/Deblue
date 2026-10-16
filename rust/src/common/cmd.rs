//! Blocking `Command` runner for CLI-backed modules.
//!
//! Sound goes through `pactl` (PulseAudio-compatible, works on PipeWire):
//! `pactl -f json list …` for reads, plain `pactl …` for writes, and
//! `pactl subscribe` for the event stream.

use std::process::{Command, Stdio};

use super::error::ApiResult;

/// Run `program args`, returning trimmed stdout or a `program: stderr` error.
pub fn run(program: &str, args: &[&str]) -> ApiResult<String> {
    let output = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .output()
        .map_err(|e| format!("Failed to run `{program}`: {e}"))?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let detail = if stderr.is_empty() {
            format!("exit {}", output.status)
        } else {
            stderr
        };
        Err(format!("`{program}` failed: {detail}"))
    }
}
