//! Typed getters for D-Bus `HashMap<String, OwnedValue>` property maps.
//!
//! Every getter returns a neutral default when the key is missing or has
//! an unexpected variant, so callers never have to match on `Value`.

use std::collections::HashMap;
use std::ops::Deref;
use zbus::zvariant::{OwnedValue, Value};

/// `NULL_PATH` (`"/"`) is what PulseAudio/NetworkManager use for "no object".
pub const NULL_PATH: &str = "/";

pub fn get_bool(props: &HashMap<String, OwnedValue>, key: &str) -> bool {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::Bool(b) => Some(*b),
            _ => None,
        })
        .unwrap_or(false)
}

pub fn get_string(props: &HashMap<String, OwnedValue>, key: &str) -> String {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::Str(s) => Some(s.as_str().to_string()),
            _ => None,
        })
        .unwrap_or_default()
}

pub fn get_u8(props: &HashMap<String, OwnedValue>, key: &str) -> u8 {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::U8(i) => Some(*i),
            _ => None,
        })
        .unwrap_or(0)
}

pub fn get_u32(props: &HashMap<String, OwnedValue>, key: &str) -> u32 {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::U32(i) => Some(*i),
            Value::U16(i) => Some((*i).into()),
            Value::U8(i) => Some((*i).into()),
            _ => None,
        })
        .unwrap_or(0)
}

pub fn get_i16(props: &HashMap<String, OwnedValue>, key: &str) -> i16 {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::I16(i) => Some(*i),
            Value::I32(i) => Some(*i as i16),
            _ => None,
        })
        .unwrap_or(0)
}

pub fn get_obj_path(props: &HashMap<String, OwnedValue>, key: &str) -> String {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::ObjectPath(p) => Some(p.as_str().to_string()),
            _ => None,
        })
        .unwrap_or_else(|| NULL_PATH.to_string())
}

/// Raw bytes of an `ay` (byte array) property such as an AP `Ssid`.
pub fn get_bytes(props: &HashMap<String, OwnedValue>, key: &str) -> Vec<u8> {
    let Some(v) = props.get(key) else {
        return Vec::new();
    };
    match v.deref() {
        Value::Array(arr) => arr
            .iter()
            .filter_map(|e| match e {
                Value::U8(b) => Some(*b),
                _ => None,
            })
            .collect(),
        _ => Vec::new(),
    }
}

/// Lossy UTF-8 decoding used for SSIDs.
pub fn bytes_to_string(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes).trim().to_string()
}
