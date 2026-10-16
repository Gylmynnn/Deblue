//! PipeWire/PulseAudio mixer backend via `pactl`.
//!
//! `pactl` speaks the PulseAudio protocol, which PipeWire re-exposes
//! (`Server Name: PulseAudio (on PipeWire …)`), so one implementation
//! covers both servers. Reads use `pactl -f json …` (parsed with
//! `serde_json::Value` — pactl adds fields across versions, so untyped
//! parsing with small extractors stays robust); writes are plain `pactl`
//! verbs; change notifications stream from `pactl subscribe`.

use std::collections::HashMap;
use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;

use crate::common::cmd;
use crate::common::error::ApiResult;
use crate::frb_generated::StreamSink;

// ---------------------------------------------------------------------------
// FRB types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct SoundPort {
    pub name: String,
    pub description: String,
}

#[derive(Debug, Clone)]
pub struct SoundDevice {
    pub name: String,
    pub description: String,
    pub volume_percent: u8,
    pub muted: bool,
    pub is_default: bool,
    pub is_monitor: bool,
    pub active_port: String,
    pub ports: Vec<SoundPort>,
}

#[derive(Debug, Clone)]
pub struct SoundStream {
    pub index: u32,
    /// Human label, e.g. `ALSA plug-in [speaker-test]`.
    pub app_name: String,
    /// e.g. `ALSA Playback`.
    pub stream_name: String,
    pub volume_percent: u8,
    pub muted: bool,
    /// Owning sink/source *name* (resolved from its index).
    pub device: String,
}

#[derive(Debug, Clone)]
pub struct SoundState {
    pub sinks: Vec<SoundDevice>,
    pub sources: Vec<SoundDevice>,
    /// Per-app playback streams (`sink-inputs`).
    pub playback: Vec<SoundStream>,
    /// Per-app recording streams (`source-outputs`).
    pub recording: Vec<SoundStream>,
    pub default_sink: String,
    pub default_source: String,
}

#[derive(Debug, Clone)]
pub struct SoundEvent {
    pub event_type: String,
    pub detail: String,
}

/// Guard so repeated Dart `connect()` calls don't spawn duplicate threads.
static SUBSCRIBED: AtomicBool = AtomicBool::new(false);

// ---------------------------------------------------------------------------
// JSON extractors (pactl output is version-fluid, so stay defensive)
// ---------------------------------------------------------------------------

fn str_field(v: &serde_json::Value, key: &str) -> String {
    v.get(key)
        .and_then(|x| x.as_str())
        .unwrap_or_default()
        .to_string()
}

fn bool_field(v: &serde_json::Value, key: &str) -> bool {
    v.get(key).and_then(|x| x.as_bool()).unwrap_or(false)
}

fn u32_field(v: &serde_json::Value, key: &str) -> u32 {
    v.get(key).and_then(|x| x.as_u64()).unwrap_or(0) as u32
}

/// Average `value_percent` (`"31%"`) across channels, falling back to the
/// raw `value` (0–65536). pactl omits `value_percent` on some nodes.
fn volume_percent(v: &serde_json::Value) -> u8 {
    let Some(vol) = v.get("volume").and_then(|x| x.as_object()) else {
        return 0;
    };
    let mut sum: u32 = 0;
    let mut count: u32 = 0;
    for ch in vol.values() {
        if let Some(pct) = ch.get("value_percent").and_then(|x| x.as_str()) {
            if let Ok(n) = pct.trim_end_matches('%').parse::<u32>() {
                sum += n.min(200);
                count += 1;
                continue;
            }
        }
        if let Some(raw) = ch.get("value").and_then(|x| x.as_u64()) {
            sum += ((raw * 100) / 65536) as u32;
            count += 1;
        }
    }
    if count == 0 {
        0
    } else {
        sum.checked_div(count).unwrap_or(0).min(200) as u8
    }
}

fn is_monitor_source(v: &serde_json::Value) -> bool {
    let name = str_field(v, "name");
    let monitor_of = v
        .get("monitor_source")
        .and_then(|x| x.as_str())
        .unwrap_or("");
    // PipeWire monitor sources are named `<sink>.monitor`, and carry
    // `device.class == "monitor"`.
    if name.ends_with(".monitor") {
        return true;
    }
    let class = v
        .get("properties")
        .and_then(|p| p.get("device.class"))
        .and_then(|x| x.as_str())
        .unwrap_or("");
    class == "monitor" || !monitor_of.is_empty() && name == monitor_of
}

fn parse_ports(v: &serde_json::Value) -> Vec<SoundPort> {
    v.get("ports")
        .and_then(|x| x.as_array())
        .map(|ports| {
            ports
                .iter()
                .map(|p| SoundPort {
                    name: str_field(p, "name"),
                    description: str_field(p, "description"),
                })
                .filter(|p| !p.name.is_empty())
                .collect()
        })
        .unwrap_or_default()
}

fn parse_device(
    v: &serde_json::Value,
    defaults: &HashMap<String, String>,
    default_key: &str,
    monitor: bool,
) -> Option<SoundDevice> {
    let name = str_field(v, "name");
    if name.is_empty() {
        return None;
    }
    Some(SoundDevice {
        is_default: defaults.get(default_key).is_some_and(|d| *d == name),
        active_port: str_field(v, "active_port"),
        ports: parse_ports(v),
        name,
        description: str_field(v, "description"),
        volume_percent: volume_percent(v),
        muted: bool_field(v, "mute"),
        is_monitor: monitor,
    })
}

fn list_json(table: &str) -> ApiResult<Vec<serde_json::Value>> {
    let out = cmd::run("pactl", &["-f", "json", "list", table])?;
    if out.is_empty() || out == "[]" {
        return Ok(Vec::new());
    }
    serde_json::from_str::<Vec<serde_json::Value>>(&out)
        .map_err(|e| format!("Failed to parse `pactl list {table}`: {e}"))
}

fn default_name(kind: &str) -> String {
    // `pactl get-default-sink` prints the name or fails when unset.
    cmd::run("pactl", &[&format!("get-default-{kind}")]).unwrap_or_default()
}

fn parse_stream(
    v: &serde_json::Value,
    owner_key: &str,
    owners: &HashMap<u32, String>,
) -> Option<SoundStream> {
    let props = v.get("properties");
    let app = props
        .and_then(|p| p.get("application.name"))
        .and_then(|x| x.as_str())
        .or_else(|| {
            props
                .and_then(|p| p.get("application.process.binary"))
                .and_then(|x| x.as_str())
        })
        .unwrap_or("Unknown app")
        .to_string();
    let stream = props
        .and_then(|p| p.get("media.name"))
        .and_then(|x| x.as_str())
        .or_else(|| {
            props
                .and_then(|p| p.get("node.name"))
                .and_then(|x| x.as_str())
        })
        .unwrap_or("")
        .to_string();
    let owner_idx = u32_field(v, owner_key);
    Some(SoundStream {
        index: u32_field(v, "index"),
        app_name: app,
        stream_name: stream,
        volume_percent: volume_percent(v),
        muted: bool_field(v, "mute"),
        device: owners.get(&owner_idx).cloned().unwrap_or_default(),
    })
}

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------

pub fn get_sound_state() -> ApiResult<SoundState> {
    let default_sink = default_name("sink");
    let default_source = default_name("source");
    let defaults: HashMap<String, String> = [
        ("sink".to_string(), default_sink.clone()),
        ("source".to_string(), default_source.clone()),
    ]
    .into_iter()
    .collect();

    let mut sinks = Vec::new();
    let mut sink_index_to_name: HashMap<u32, String> = HashMap::new();
    for entry in list_json("sinks")? {
        let idx = u32_field(&entry, "index");
        if let Some(dev) = parse_device(&entry, &defaults, "sink", false) {
            sink_index_to_name.insert(idx, dev.name.clone());
            sinks.push(dev);
        }
    }
    // Loudest-first is closest to user intent; keep name as tiebreak.
    sinks.sort_by(|a, b| {
        b.is_default
            .cmp(&a.is_default)
            .then_with(|| a.description.cmp(&b.description))
    });

    let mut sources = Vec::new();
    let mut source_index_to_name: HashMap<u32, String> = HashMap::new();
    for entry in list_json("sources")? {
        let idx = u32_field(&entry, "index");
        let monitor = is_monitor_source(&entry);
        if let Some(dev) = parse_device(&entry, &defaults, "source", monitor) {
            source_index_to_name.insert(idx, dev.name.clone());
            sources.push(dev);
        }
    }
    // Real microphones first, monitors last.
    sources.sort_by(|a, b| {
        b.is_default
            .cmp(&a.is_default)
            .then_with(|| a.is_monitor.cmp(&b.is_monitor))
            .then_with(|| a.description.cmp(&b.description))
    });

    let mut playback = Vec::new();
    for entry in list_json("sink-inputs")? {
        if let Some(s) = parse_stream(&entry, "sink", &sink_index_to_name) {
            playback.push(s);
        }
    }
    playback.sort_by(|a, b| a.app_name.cmp(&b.app_name));

    let mut recording = Vec::new();
    for entry in list_json("source-outputs")? {
        if let Some(s) = parse_stream(&entry, "source", &source_index_to_name) {
            recording.push(s);
        }
    }
    recording.sort_by(|a, b| a.app_name.cmp(&b.app_name));

    Ok(SoundState {
        sinks,
        sources,
        playback,
        recording,
        default_sink,
        default_source,
    })
}

// ---------------------------------------------------------------------------
// Writes
// ---------------------------------------------------------------------------

fn clamp_volume(percent: u8) -> u8 {
    percent.min(200)
}

fn set_volume(target: &str, name: &str, percent: u8) -> ApiResult<()> {
    cmd::run(
        "pactl",
        &[target, name, &format!("{}%", clamp_volume(percent))],
    )?;
    Ok(())
}

fn set_mute(target: &str, id: &str, mute: bool) -> ApiResult<()> {
    cmd::run("pactl", &[target, id, if mute { "1" } else { "0" }])?;
    Ok(())
}

pub fn set_sink_volume(name: String, percent: u8) -> ApiResult<()> {
    set_volume("set-sink-volume", &name, percent)
}

pub fn set_source_volume(name: String, percent: u8) -> ApiResult<()> {
    set_volume("set-source-volume", &name, percent)
}

pub fn set_stream_volume(index: u32, is_playback: bool, percent: u8) -> ApiResult<()> {
    let target = if is_playback {
        "set-sink-input-volume"
    } else {
        "set-source-output-volume"
    };
    set_volume(target, &index.to_string(), percent)
}

pub fn set_sink_mute(name: String, mute: bool) -> ApiResult<()> {
    set_mute("set-sink-mute", &name, mute)
}

pub fn set_source_mute(name: String, mute: bool) -> ApiResult<()> {
    set_mute("set-source-mute", &name, mute)
}

pub fn set_stream_mute(index: u32, is_playback: bool, mute: bool) -> ApiResult<()> {
    let target = if is_playback {
        "set-sink-input-mute"
    } else {
        "set-source-output-mute"
    };
    set_mute(target, &index.to_string(), mute)
}

pub fn set_default_sink(name: String) -> ApiResult<()> {
    cmd::run("pactl", &["set-default-sink", &name])?;
    Ok(())
}

pub fn set_default_source(name: String) -> ApiResult<()> {
    cmd::run("pactl", &["set-default-source", &name])?;
    Ok(())
}

pub fn move_stream(index: u32, is_playback: bool, device: String) -> ApiResult<()> {
    let target = if is_playback {
        "move-sink-input"
    } else {
        "move-source-output"
    };
    cmd::run("pactl", &[target, &index.to_string(), &device])?;
    Ok(())
}

pub fn set_device_port(device: String, port: String, is_source: bool) -> ApiResult<()> {
    let target = if is_source {
        "set-source-port"
    } else {
        "set-sink-port"
    };
    cmd::run("pactl", &[target, &device, &port])?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Events: `pactl subscribe` lines look like `Event 'change' on sink #81`.
// Every server/sink/source/stream event triggers a Dart-side refresh
// (debounced there); the line itself is only a hint.
// ---------------------------------------------------------------------------

fn parse_subscribe_line(line: &str) -> Option<SoundEvent> {
    // Event 'change' on sink #81
    let mut parts = line.split_whitespace();
    if parts.next()? != "Event" {
        return None;
    }
    let kind = parts.next()?.trim_matches('\'').to_string();
    if parts.next()? != "on" {
        return None;
    }
    let facility = parts.next()?.to_string();
    if facility.is_empty() {
        return None;
    }
    Some(SoundEvent {
        event_type: kind,
        detail: facility,
    })
}

pub fn subscribe_sound_events(sink: StreamSink<SoundEvent>) -> ApiResult<()> {
    // Idempotent: Dart may call connect() again after rebuilds/hot-restart.
    if SUBSCRIBED.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    let mut child = Command::new("pactl")
        .arg("subscribe")
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| {
            SUBSCRIBED.store(false, Ordering::SeqCst);
            format!("Failed to run `pactl subscribe`: {e}")
        })?;

    let stdout = child.stdout.take().ok_or_else(|| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        "Failed to capture `pactl subscribe` output".to_string()
    })?;

    thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines().map_while(Result::ok) {
            let Some(event) = parse_subscribe_line(&line) else {
                continue;
            };
            if sink.add(event).is_err() {
                break; // Dart listener closed/canceled.
            }
        }
        let _ = child.kill();
        let _ = child.wait();
        SUBSCRIBED.store(false, Ordering::SeqCst);
    });

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn volume_averages_percent_channels() {
        let v = json!({"volume": {
            "front-left": {"value": 20641, "value_percent": "31%"},
            "front-right": {"value": 26541, "value_percent": "40%"},
        }});
        assert_eq!(volume_percent(&v), 35);
    }

    #[test]
    fn volume_falls_back_to_raw_value() {
        let v = json!({"volume": {"mono": {"value": 32768}}});
        assert_eq!(volume_percent(&v), 50);
    }

    #[test]
    fn volume_missing_is_zero() {
        assert_eq!(volume_percent(&json!({})), 0);
    }

    #[test]
    fn subscribe_lines_parse() {
        let e = parse_subscribe_line("Event 'change' on sink #81").unwrap();
        assert_eq!(e.event_type, "change");
        assert_eq!(e.detail, "sink");
        assert!(parse_subscribe_line("random noise").is_none());
    }

    #[test]
    fn monitor_sources_detected() {
        let v = json!({"name": "alsa_output.pci.monitor", "monitor_source": "x"});
        assert!(is_monitor_source(&v));
        let v = json!({"name": "alsa_input.pci", "properties": {}});
        assert!(!is_monitor_source(&v));
    }

    // Hit the real PulseAudio/PipeWire server. Ignored by default
    // (CI has no audio); run locally with: cargo test -- --ignored
    #[test]
    #[ignore]
    fn smoke_sound_state() {
        let state = get_sound_state().expect("get_sound_state failed");
        assert!(!state.sinks.is_empty(), "expected at least one sink");
    }
}
