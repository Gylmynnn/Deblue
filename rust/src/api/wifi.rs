use std::cell::RefCell;
use std::collections::HashMap;
use std::ops::Deref;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant};
use zbus::MatchRule;
use zbus::blocking::Connection;
use zbus::blocking::MessageIterator;
use zbus::blocking::fdo::DBusProxy;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Value};
use crate::frb_generated::StreamSink;

const NM_SERVICE: &str = "org.freedesktop.NetworkManager";
const NM_PATH: &str = "/org/freedesktop/NetworkManager";
const NM_SETTINGS_PATH: &str = "/org/freedesktop/NetworkManager/Settings";
const NM_PATH_PREFIX: &str = "/org/freedesktop/NetworkManager";

const IFACE_NM: &str = "org.freedesktop.NetworkManager";
const IFACE_DEVICE: &str = "org.freedesktop.NetworkManager.Device";
const IFACE_WIFI_DEVICE: &str = "org.freedesktop.NetworkManager.Device.Wireless";
const IFACE_AP: &str = "org.freedesktop.NetworkManager.AccessPoint";
const IFACE_SETTINGS_CONN: &str = "org.freedesktop.NetworkManager.Settings.Connection";
const IFACE_SETTINGS: &str = "org.freedesktop.NetworkManager.Settings";
const IFACE_PROPS: &str = "org.freedesktop.DBus.Properties";
const IFACE_OBJ_MGR: &str = "org.freedesktop.DBus.ObjectManager";

const DEVICE_TYPE_WIFI: u32 = 2;
const DEVICE_STATE_ACTIVATED: u32 = 100;
const NULL_PATH: &str = "/";

#[derive(Debug, Clone)]
pub struct WifiStatus {
    pub enabled: bool,
    pub connected: bool,
    pub active_ssid: String,
    pub active_signal: u8,
    pub device: String,
}

#[derive(Debug, Clone)]
pub struct WifiDevice {
    pub iface: String,
    pub state: u32,
    pub connected: bool,
    pub active_ssid: String,
    pub driver: String,
    pub hw_address: String,
    pub udi: String,
}

#[derive(Debug, Clone)]
pub struct WifiNetwork {
    pub ssid: String,
    pub bssid: String,
    pub signal: u8,
    pub frequency: u32,
    pub security: String,
    pub in_use: bool,
    pub saved: bool,
}

#[derive(Debug, Clone)]
pub struct WifiEvent {
    pub event_type: String,
    pub path: String,
}

/// Throttle window for PropertiesChanged bursts (signal strength churn).
const PROPS_THROTTLE: Duration = Duration::from_millis(800);

/// Guard so repeated Dart `connect()` calls don't spawn duplicate listener threads.
static SUBSCRIBED: AtomicBool = AtomicBool::new(false);

type PropsMap = HashMap<String, OwnedValue>;

// Thread-local reuse of the system-bus connection (separate from bluetooth's
// so the two modules never share a TLS borrow).
thread_local! {
    static TLS_WIFI_CONN: RefCell<Option<Connection>> = const { RefCell::new(None) };
}

fn get_system_connection() -> Result<Connection, String> {
    Connection::system().map_err(|e| format!("Failed to connect to system bus: {e}"))
}

fn with_nm_connection<T>(f: impl Fn(&Connection) -> Result<T, String>) -> Result<T, String> {
    TLS_WIFI_CONN
        .try_with(|cell| {
            {
                let slot = cell.borrow();
                if let Some(conn) = slot.as_ref() {
                    match f(conn) {
                        Ok(v) => return Ok(v),
                        Err(e) if is_transport_error(&e) => { /* fall through to reconnect */ }
                        Err(e) => return Err(e),
                    }
                }
            }
            let fresh = get_system_connection()?;
            let result = f(&fresh);
            *cell.borrow_mut() = Some(fresh);
            result
        })
        .map_err(|_| "Thread-local storage inaccessible".to_string())?
}

fn is_transport_error(msg: &str) -> bool {
    msg.contains("connection closed")
        || msg.contains("disconnected")
        || msg.contains("I/O error")
        || msg.contains("Broken pipe")
}

fn get_bool(props: &HashMap<String, OwnedValue>, key: &str) -> bool {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::Bool(b) => Some(*b),
            _ => None,
        })
        .unwrap_or(false)
}

fn get_string(props: &HashMap<String, OwnedValue>, key: &str) -> String {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::Str(s) => Some(s.as_str().to_string()),
            _ => None,
        })
        .unwrap_or_default()
}

fn get_u8(props: &HashMap<String, OwnedValue>, key: &str) -> u8 {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::U8(i) => Some(*i),
            _ => None,
        })
        .unwrap_or(0)
}

fn get_u32(props: &HashMap<String, OwnedValue>, key: &str) -> u32 {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::U32(i) => Some(*i),
            Value::U16(i) => Some(*i as u32),
            Value::U8(i) => Some(*i as u32),
            _ => None,
        })
        .unwrap_or(0)
}

fn get_obj_path(props: &HashMap<String, OwnedValue>, key: &str) -> String {
    props
        .get(key)
        .and_then(|v| match v.deref() {
            Value::ObjectPath(p) => Some(p.as_str().to_string()),
            _ => None,
        })
        .unwrap_or_else(|| NULL_PATH.to_string())
}

/// AP `Ssid` is `ay` (array of bytes). Returns raw bytes + lossy string.
fn get_ssid_bytes(props: &HashMap<String, OwnedValue>, key: &str) -> Vec<u8> {
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

fn ssid_to_string(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes).trim().to_string()
}

fn ap_security(flags: u32, wpa_flags: u32, rsn_flags: u32) -> String {
    if wpa_flags == 0 && rsn_flags == 0 {
        if flags & 0x1 != 0 {
            "WEP".to_string()
        } else {
            "Open".to_string()
        }
    } else if rsn_flags != 0 {
        "WPA2".to_string()
    } else {
        "WPA".to_string()
    }
}

fn get_managed_device_paths(conn: &Connection) -> Result<Vec<String>, String> {
    // NOTE: unlike BlueZ, NetworkManager does not implement
    // org.freedesktop.DBus.ObjectManager, so devices / APs / profiles are
    // enumerated through explicit list methods instead of GetManagedObjects.
    let reply = conn
        .call_method(
            Some(NM_SERVICE),
            NM_PATH,
            Some(IFACE_NM),
            "GetDevices",
            &(),
        )
        .map_err(|e| format!("Failed to list NetworkManager devices: {e}"))?;
    let paths: Vec<OwnedObjectPath> = reply
        .body()
        .deserialize()
        .map_err(|e| format!("Failed to deserialize device list: {e}"))?;
    Ok(paths.into_iter().map(|p| p.to_string()).collect())
}

fn get_all_props(
    conn: &Connection,
    path: &str,
    iface: &str,
) -> Result<HashMap<String, OwnedValue>, String> {
    let reply = conn
        .call_method(
            Some(NM_SERVICE),
            path,
            Some(IFACE_PROPS),
            "GetAll",
            &(iface,),
        )
        .map_err(|e| format!("Failed to get properties for {path}: {e}"))?;
    reply
        .body()
        .deserialize()
        .map_err(|e| format!("Failed to deserialize properties for {path}: {e}"))
}

struct WifiDeviceInfo {
    path: String,
    iface: String,
    state: u32,
    active_ap: String,
    active_connection: String,
    driver: String,
    hw_address: String,
    udi: String,
}

fn collect_wifi_devices(conn: &Connection) -> Result<Vec<WifiDeviceInfo>, String> {
    let mut devices = Vec::new();
    for path in get_managed_device_paths(conn)? {
        let dev = get_all_props(conn, &path, IFACE_DEVICE)?;
        if get_u32(&dev, "DeviceType") != DEVICE_TYPE_WIFI {
            continue;
        }
        // Non-wireless-capable entries (e.g. p2p) are already filtered by
        // DeviceType, but ActiveAccessPoint only exists on the wireless
        // interface — a failed GetAll just means "skip".
        let Ok(wifi) = get_all_props(conn, &path, IFACE_WIFI_DEVICE) else {
            continue;
        };
        devices.push(WifiDeviceInfo {
            path,
            iface: get_string(&dev, "Interface"),
            state: get_u32(&dev, "State"),
            active_ap: get_obj_path(&wifi, "ActiveAccessPoint"),
            active_connection: get_obj_path(&dev, "ActiveConnection"),
            driver: get_string(&dev, "Driver"),
            hw_address: get_string(&dev, "HwAddress"),
            udi: get_string(&dev, "Udi"),
        });
    }
    // Stable order for deterministic UI.
    devices.sort_by(|a, b| a.iface.cmp(&b.iface));
    Ok(devices)
}

/// Preferred device: the activated one, otherwise the first wifi device.
fn preferred_device(devices: &[WifiDeviceInfo]) -> Option<&WifiDeviceInfo> {
    devices
        .iter()
        .find(|d| d.state == DEVICE_STATE_ACTIVATED)
        .or_else(|| devices.first())
}

/// Resolve the target device: an explicit interface selection wins,
/// otherwise the activated device, otherwise the first wifi device.
/// Falls back to preferred when the requested interface is gone
/// (e.g. external adapter unplugged).
fn resolve_device<'a>(
    devices: &'a [WifiDeviceInfo],
    requested: &str,
) -> Option<&'a WifiDeviceInfo> {
    let req = requested.trim();
    if !req.is_empty() {
        if let Some(dev) = devices.iter().find(|d| d.iface == req) {
            return Some(dev);
        }
    }
    preferred_device(devices)
}

/// Map of saved connections: ssid bytes -> settings object path.
fn saved_connections(conn: &Connection) -> HashMap<Vec<u8>, String> {
    let mut saved = HashMap::new();
    for path_str in settings_paths(conn) {
        if let Some(settings) = read_settings(conn, &path_str) {
            if let Some(wireless) = settings.get("802-11-wireless") {
                let ssid = get_ssid_bytes(wireless, "ssid");
                if !ssid.is_empty() {
                    saved.entry(ssid).or_insert(path_str);
                }
            }
        }
    }
    saved
}

fn settings_paths(conn: &Connection) -> Vec<String> {
    let Ok(reply) = conn.call_method(
        Some(NM_SERVICE),
        NM_SETTINGS_PATH,
        Some(IFACE_SETTINGS),
        "ListConnections",
        &(),
    ) else {
        return Vec::new();
    };
    let Ok(paths): Result<Vec<OwnedObjectPath>, _> = reply.body().deserialize() else {
        return Vec::new();
    };
    paths.into_iter().map(|p| p.to_string()).collect()
}

fn read_settings(
    conn: &Connection,
    settings_path: &str,
) -> Option<HashMap<String, HashMap<String, OwnedValue>>> {
    let reply = conn
        .call_method(
            Some(NM_SERVICE),
            settings_path,
            Some(IFACE_SETTINGS_CONN),
            "GetSettings",
            &(),
        )
        .ok()?;
    reply.body().deserialize().ok()
}

/// All saved profiles for an SSID: (settings path, interface-name lock).
/// The lock is "" for portable profiles usable on any adapter.
fn profiles_for_ssid(conn: &Connection, ssid: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    for path_str in settings_paths(conn) {
        let Some(settings) = read_settings(conn, &path_str) else {
            continue;
        };
        let matches = settings
            .get("802-11-wireless")
            .map(|w| ssid_to_string(&get_ssid_bytes(w, "ssid")) == ssid)
            .unwrap_or(false);
        if !matches {
            continue;
        }
        let locked = settings
            .get("connection")
            .map(|c| get_string(c, "interface-name"))
            .unwrap_or_default();
        out.push((path_str, locked));
    }
    out
}

fn bound_error(ssid: &str, profiles: &[(String, String)]) -> String {
    let ifaces: Vec<String> = profiles
        .iter()
        .map(|(_, locked)| {
            if locked.is_empty() {
                "any".to_string()
            } else {
                locked.clone()
            }
        })
        .collect();
    format!("PROFILE_BOUND_TO:{}:{ssid}", ifaces.join(","))
}

/// All visible access points across wifi devices: (object path, AP props).
fn collect_access_points(
    conn: &Connection,
    devices: &[WifiDeviceInfo],
) -> Vec<(String, PropsMap)> {
    let mut aps = Vec::new();
    for dev in devices {
        let Ok(reply) = conn.call_method(
            Some(NM_SERVICE),
            dev.path.as_str(),
            Some(IFACE_WIFI_DEVICE),
            "GetAllAccessPoints",
            &(),
        ) else {
            continue;
        };
        let Ok(paths): Result<Vec<OwnedObjectPath>, _> = reply.body().deserialize()
        else {
            continue;
        };
        for ap_path in paths {
            let ap_str = ap_path.to_string();
            if let Ok(props) = get_all_props(conn, &ap_str, IFACE_AP) {
                aps.push((ap_str, props));
            }
        }
    }
    aps
}

pub fn get_devices() -> Result<Vec<WifiDevice>, String> {
    with_nm_connection(|conn| {
        let devices = collect_wifi_devices(conn)?;
        let mut out = Vec::new();
        for dev in &devices {
            let mut active_ssid = String::new();
            if dev.state == DEVICE_STATE_ACTIVATED && dev.active_ap != NULL_PATH {
                if let Ok(ap) = get_all_props(conn, &dev.active_ap, IFACE_AP) {
                    active_ssid = ssid_to_string(&get_ssid_bytes(&ap, "Ssid"));
                }
            }
            // Hardware identity for the adapter picker (e.g. iwlwifi on
            // internal PCI vs ath9k_htc on external USB).
            out.push(WifiDevice {
                iface: dev.iface.clone(),
                state: dev.state,
                connected: dev.state == DEVICE_STATE_ACTIVATED,
                active_ssid,
                driver: dev.driver.clone(),
                hw_address: dev.hw_address.clone(),
                udi: dev.udi.clone(),
            });
        }
        Ok(out)
    })
}

pub fn get_wifi_status(device: String) -> Result<WifiStatus, String> {
    with_nm_connection(|conn| {
        let devices = collect_wifi_devices(conn)?;

        let nm_props = get_all_props(conn, NM_PATH, IFACE_NM)?;
        let enabled = get_bool(&nm_props, "WirelessEnabled");

        let Some(dev) = resolve_device(&devices, &device) else {
            return Ok(WifiStatus {
                enabled,
                connected: false,
                active_ssid: String::new(),
                active_signal: 0,
                device: String::new(),
            });
        };

        let mut active_ssid = String::new();
        let mut active_signal: u8 = 0;
        let connected = dev.state == DEVICE_STATE_ACTIVATED && dev.active_ap != NULL_PATH;
        if connected {
            if let Ok(ap_props) = get_all_props(conn, &dev.active_ap, IFACE_AP) {
                active_ssid = ssid_to_string(&get_ssid_bytes(&ap_props, "Ssid"));
                active_signal = get_u8(&ap_props, "Strength");
            }
        }

        Ok(WifiStatus {
            enabled,
            connected,
            active_ssid,
            active_signal,
            device: dev.iface.clone(),
        })
    })
}

pub fn get_networks(device: String) -> Result<Vec<WifiNetwork>, String> {
    with_nm_connection(|conn| {
        let devices = collect_wifi_devices(conn)?;
        let Some(target) = resolve_device(&devices, &device) else {
            return Ok(Vec::new());
        };
        let active_ap = target.active_ap.clone();
        let saved = saved_connections(conn);
        // Only the selected adapter's access points — each adapter sees a
        // different radio environment.
        let aps = collect_access_points(conn, std::slice::from_ref(target));

        // Deduplicate by SSID (multi-BSSID environments), keeping the
        // strongest BSSID per SSID.
        let mut by_ssid: HashMap<String, WifiNetwork> = HashMap::new();
        for (ap_path, ap) in &aps {
            let ssid_bytes = get_ssid_bytes(ap, "Ssid");
            let ssid = ssid_to_string(&ssid_bytes);
            if ssid.is_empty() {
                continue;
            }
            let candidate = WifiNetwork {
                ssid: ssid.clone(),
                bssid: get_string(ap, "HwAddress"),
                signal: get_u8(ap, "Strength"),
                frequency: get_u32(ap, "Frequency"),
                security: ap_security(
                    get_u32(ap, "Flags"),
                    get_u32(ap, "WpaFlags"),
                    get_u32(ap, "RsnFlags"),
                ),
                in_use: *ap_path == active_ap,
                saved: saved.contains_key(&ssid_bytes),
            };
            match by_ssid.get(&ssid) {
                Some(existing)
                    if existing.signal >= candidate.signal && !candidate.in_use => {}
                _ => {
                    by_ssid.insert(ssid, candidate);
                }
            }
        }

        let mut networks: Vec<WifiNetwork> = by_ssid.into_values().collect();
        networks.sort_by(|a, b| {
            b.in_use
                .cmp(&a.in_use)
                .then_with(|| b.signal.cmp(&a.signal))
                .then_with(|| a.ssid.cmp(&b.ssid))
        });
        Ok(networks)
    })
}

pub fn request_scan() -> Result<(), String> {
    with_nm_connection(|conn| {
        let devices = collect_wifi_devices(conn)?;
        if devices.is_empty() {
            return Err("No WiFi device found".to_string());
        }
        let empty_opts: HashMap<String, Value> = HashMap::new();
        // Scan every adapter: each radio sees a different environment
        // (e.g. 2.4 GHz-only dongle vs 5 GHz-capable built-in).
        let mut ok_any = false;
        let mut last_err: Option<String> = None;
        for dev in &devices {
            let result = conn.call_method(
                Some(NM_SERVICE),
                dev.path.as_str(),
                Some(IFACE_WIFI_DEVICE),
                "RequestScan",
                &(&empty_opts,),
            );
            if let Err(e) = result {
                let msg = e.to_string();
                // NM rate-limits scans; a throttled scan just means the
                // cached AP list is still fresh — not a failure.
                if msg.contains("not allowed")
                    || msg.contains("Scanning not allowed")
                    || msg.contains("already")
                {
                    continue;
                }
                last_err = Some(format!("Failed to request scan on {}: {msg}", dev.iface));
            } else {
                ok_any = true;
            }
        }
        if !ok_any {
            if let Some(err) = last_err {
                return Err(err);
            }
        }
        Ok(())
    })
}

pub fn set_wifi_enabled(enabled: bool) -> Result<(), String> {
    with_nm_connection(|conn| {
        conn.call_method(
            Some(NM_SERVICE),
            NM_PATH,
            Some(IFACE_PROPS),
            "Set",
            &(IFACE_NM, "WirelessEnabled", Value::from(enabled)),
        )
        .map_err(|e| format!("Failed to set WirelessEnabled: {e}"))?;
        Ok(())
    })
}

fn activate_connection(
    conn: &Connection,
    settings_path: &str,
    device_path: &str,
) -> Result<(), String> {
    let settings_obj = ObjectPath::try_from(settings_path)
        .map_err(|e| format!("Invalid connection path: {e}"))?;
    let device_obj = ObjectPath::try_from(device_path)
        .map_err(|e| format!("Invalid device path: {e}"))?;
    let specific_obj =
        ObjectPath::try_from(NULL_PATH).map_err(|e| format!("Invalid null path: {e}"))?;
    conn.call_method(
        Some(NM_SERVICE),
        NM_PATH,
        Some(IFACE_NM),
        "ActivateConnection",
        &(settings_obj, device_obj, specific_obj),
    )
    .map_err(|e| format!("Failed to activate connection: {e}"))?;
    Ok(())
}

pub fn connect_saved(ssid: String, device: String) -> Result<(), String> {
    with_nm_connection(|conn| {
        let devices = collect_wifi_devices(conn)?;
        let Some(target) = resolve_device(&devices, &device) else {
            return Err("No WiFi device found".to_string());
        };
        let profiles = profiles_for_ssid(conn, &ssid);
        if profiles.is_empty() {
            return Err(format!("No saved connection for '{ssid}'"));
        }
        // The user's explicit adapter choice wins: only a profile compatible
        // with it may be used. A profile locked to another adapter must NOT
        // hijack the connection onto that adapter (that was bug #1).
        if let Some((path, _)) = profiles
            .iter()
            .find(|(_, locked)| locked.is_empty() || *locked == target.iface)
        {
            return activate_connection(conn, path, &target.path);
        }
        Err(bound_error(&ssid, &profiles))
    })
}

pub fn connect_new(ssid: String, password: String, device: String) -> Result<(), String> {
    if ssid.trim().is_empty() {
        return Err("SSID must not be empty".to_string());
    }
    with_nm_connection(|conn| {
        let devices = collect_wifi_devices(conn)?;
        let Some(target) = resolve_device(&devices, &device) else {
            return Err("No WiFi device found".to_string());
        };

        // A typed password always means "create a fresh portable profile"
        // (e.g. the password changed). Otherwise reuse a compatible saved
        // profile on the selected adapter.
        if password.is_empty() {
            let profiles = profiles_for_ssid(conn, &ssid);
            if let Some((path, _)) = profiles
                .iter()
                .find(|(_, locked)| locked.is_empty() || *locked == target.iface)
            {
                return activate_connection(conn, path, &target.path);
            }
            if !profiles.is_empty() {
                return Err(bound_error(&ssid, &profiles));
            }
            // No saved profile at all and no password: fall through and
            // create a portable open profile below.
        }

        let device_path = target.path.clone();

        let ssid_bytes = ssid.as_bytes().to_vec();
        let mut connection_section: HashMap<String, Value> = HashMap::new();
        connection_section.insert("id".to_string(), Value::from(ssid.clone()));
        connection_section.insert("type".to_string(), Value::from("802-11-wireless"));

        let mut wireless_section: HashMap<String, Value> = HashMap::new();
        wireless_section.insert("ssid".to_string(), Value::from(ssid_bytes));
        wireless_section.insert("mode".to_string(), Value::from("infrastructure"));

        let mut ipv4_section: HashMap<String, Value> = HashMap::new();
        ipv4_section.insert("method".to_string(), Value::from("auto"));
        let mut ipv6_section: HashMap<String, Value> = HashMap::new();
        ipv6_section.insert("method".to_string(), Value::from("auto"));

        let mut settings: HashMap<String, HashMap<String, Value>> = HashMap::new();
        settings.insert("connection".to_string(), connection_section);
        settings.insert("802-11-wireless".to_string(), wireless_section);
        if !password.is_empty() {
            let mut sec_section: HashMap<String, Value> = HashMap::new();
            sec_section.insert("key-mgmt".to_string(), Value::from("wpa-psk"));
            sec_section.insert("psk".to_string(), Value::from(password.clone()));
            settings.insert("802-11-wireless-security".to_string(), sec_section);
        }
        settings.insert("ipv4".to_string(), ipv4_section);
        settings.insert("ipv6".to_string(), ipv6_section);

        let reply = conn
            .call_method(
                Some(NM_SERVICE),
                NM_SETTINGS_PATH,
                Some(IFACE_SETTINGS),
                "AddConnection",
                &(&settings,),
            )
            .map_err(|e| format!("Failed to add connection for '{ssid}': {e}"))?;
        let new_path: OwnedObjectPath = reply
            .body()
            .deserialize()
            .map_err(|e| format!("Failed to read new connection path: {e}"))?;
        activate_connection(conn, &new_path.to_string(), &device_path)
    })
}

pub fn disconnect(device: String) -> Result<(), String> {
    with_nm_connection(|conn| {
        let devices = collect_wifi_devices(conn)?;
        // Prefer the selected adapter's active connection; with no explicit
        // selection, fall back to any active wifi connection.
        let active = resolve_device(&devices, &device)
            .filter(|d| d.active_connection != NULL_PATH)
            .map(|d| d.active_connection.clone())
            .or_else(|| {
                if device.trim().is_empty() {
                    devices
                        .iter()
                        .find(|d| d.active_connection != NULL_PATH)
                        .map(|d| d.active_connection.clone())
                } else {
                    None
                }
            });
        let Some(active_path) = active else {
            return Ok(());
        };
        let active_obj = ObjectPath::try_from(active_path.as_str())
            .map_err(|e| format!("Invalid active connection path: {e}"))?;
        conn.call_method(
            Some(NM_SERVICE),
            NM_PATH,
            Some(IFACE_NM),
            "DeactivateConnection",
            &(active_obj,),
        )
        .map_err(|e| format!("Failed to deactivate connection: {e}"))?;
        Ok(())
    })
}

pub fn forget(ssid: String) -> Result<u32, String> {
    with_nm_connection(|conn| {
        let profiles = profiles_for_ssid(conn, &ssid);
        if profiles.is_empty() {
            return Err(format!("No saved connection for '{ssid}'"));
        }
        // Delete every profile for this SSID (per-adapter locks and portable
        // duplicates) so "Forget" really forgets the network.
        let mut deleted: u32 = 0;
        let mut last_err: Option<String> = None;
        for (settings_path, _) in &profiles {
            match conn.call_method(
                Some(NM_SERVICE),
                settings_path.as_str(),
                Some(IFACE_SETTINGS_CONN),
                "Delete",
                &(),
            ) {
                Ok(_) => deleted += 1,
                Err(e) => {
                    last_err = Some(format!("Failed to delete '{ssid}': {e}"));
                }
            }
        }
        if deleted == 0 {
            return Err(last_err.unwrap_or_else(|| format!("Failed to delete '{ssid}'")));
        }
        Ok(deleted)
    })
}

pub fn subscribe_wifi_events(sink: StreamSink<WifiEvent>) -> Result<(), String> {
    // Idempotent: Dart may call connect() again after rebuilds/hot-restart.
    if SUBSCRIBED.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    let conn = get_system_connection().map_err(|e| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        e
    })?;
    let dbus = DBusProxy::new(&conn).map_err(|e| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        format!("Failed to create DBusProxy: {e}")
    })?;

    // Only NetworkManager signals. Without the sender + path filter, every
    // PropertiesChanged on the system bus (BlueZ, UPower, ...) would wake
    // the Dart isolate.
    let props_rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(NM_SERVICE)
        .map_err(|e| format!("Failed to create properties match rule: {e}"))?
        .interface(IFACE_PROPS)
        .map_err(|e| format!("Failed to create properties match rule: {e}"))?
        .path_namespace(NM_PATH_PREFIX)
        .map_err(|e| format!("Failed to create properties match rule: {e}"))?
        .build();

    let obj_mgr_rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(NM_SERVICE)
        .map_err(|e| format!("Failed to create ObjectManager match rule: {e}"))?
        .interface(IFACE_OBJ_MGR)
        .map_err(|e| format!("Failed to create ObjectManager match rule: {e}"))?
        .path_namespace(NM_PATH_PREFIX)
        .map_err(|e| format!("Failed to create ObjectManager match rule: {e}"))?
        .build();

    let wifi_signal_rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(NM_SERVICE)
        .map_err(|e| format!("Failed to create wireless match rule: {e}"))?
        .interface(IFACE_WIFI_DEVICE)
        .map_err(|e| format!("Failed to create wireless match rule: {e}"))?
        .path_namespace(NM_PATH_PREFIX)
        .map_err(|e| format!("Failed to create wireless match rule: {e}"))?
        .build();

    dbus.add_match_rule(props_rule).map_err(|e| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        format!("Failed to add properties match rule: {e}")
    })?;
    dbus.add_match_rule(obj_mgr_rule).map_err(|e| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        format!("Failed to add ObjectManager match rule: {e}")
    })?;
    dbus.add_match_rule(wifi_signal_rule).map_err(|e| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        format!("Failed to add wireless match rule: {e}")
    })?;

    thread::spawn(move || {
        let iter = MessageIterator::from(&conn);
        // Per-path last-emit for PropertiesChanged throttling (strength churn).
        let mut last_emit: HashMap<String, Instant> = HashMap::new();
        for msg in iter {
            let Ok(msg) = msg else { continue };
            let header = msg.header();
            let path = header.path().map(|p| p.to_string()).unwrap_or_default();
            if path.is_empty() || !path.starts_with(NM_PATH_PREFIX) {
                continue;
            }
            let member = header.member().map(|m| m.to_string()).unwrap_or_default();
            let event_type: &'static str = match member.as_str() {
                "InterfacesAdded" => "interfaces_added",
                "InterfacesRemoved" => "interfaces_removed",
                "AccessPointAdded" => "access_point_added",
                "AccessPointRemoved" => "access_point_removed",
                "PropertiesChanged" => "properties_changed",
                "StateChanged" => "state_changed",
                _ => continue,
            };
            // Throttle only the noisy updates per path.
            // Added/removed always pass through immediately.
            if matches!(event_type, "properties_changed" | "state_changed") {
                let now = Instant::now();
                if let Some(prev) = last_emit.get(&path) {
                    if now.duration_since(*prev) < PROPS_THROTTLE {
                        continue;
                    }
                }
                last_emit.insert(path.clone(), now);
            }

            let event = WifiEvent {
                event_type: event_type.to_string(),
                path,
            };

            if sink.add(event).is_err() {
                // Dart stream listener has closed/canceled
                break;
            }
        }
        SUBSCRIBED.store(false, Ordering::SeqCst);
    });

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    // Hit the real system bus. Ignored by default (CI has no
    // NetworkManager); run locally with: cargo test -- --ignored
    #[test]
    #[ignore]
    fn smoke_wifi_status() {
        let status = get_wifi_status(String::new()).expect("get_wifi_status failed");
        assert!(
            !status.device.is_empty(),
            "expected at least one wifi device"
        );
    }

    #[test]
    #[ignore]
    fn smoke_get_networks() {
        let devices = get_devices().expect("get_devices failed");
        assert!(!devices.is_empty(), "expected at least one wifi device");
        let networks = get_networks(String::new()).expect("get_networks failed");
        assert!(!networks.is_empty(), "expected at least one access point");
        assert!(
            networks.iter().any(|n| !n.ssid.is_empty()),
            "expected non-empty SSIDs"
        );
    }
}
