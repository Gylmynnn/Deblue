use std::cell::RefCell;
use std::collections::HashMap;
use std::ops::Deref;
use std::sync::Mutex;
use std::sync::OnceLock;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant};
use zbus::blocking::Connection;
use zbus::blocking::fdo::DBusProxy;
use zbus::blocking::MessageIterator;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};
use zbus::MatchRule;
use crate::frb_generated::StreamSink;

const BLUEZ_SERVICE: &str = "org.bluez";
const BLUEZ_PATH_PREFIX: &str = "/org/bluez";
const DEFAULT_ADAPTER_PATH: &str = "/org/bluez/hci0";

#[derive(Debug, Clone)]
pub struct AdapterInfo {
    pub powered: bool,
    pub discovering: bool,
    pub address: String,
    pub name: String,
    pub alias: String,
}

#[derive(Debug, Clone)]
pub struct BluetoothDevice {
    pub path: String,
    pub name: String,
    pub address: String,
    pub connected: bool,
    pub paired: bool,
    pub trusted: bool,
    pub rssi: i16,
}

#[derive(Debug, Clone)]
pub struct BluetoothEvent {
    pub event_type: String,
    pub path: String,
}

/// Throttle window for PropertiesChanged bursts (mostly RSSI churn during discovery).
const PROPS_THROTTLE: Duration = Duration::from_millis(800);

/// Guard so repeated Dart `connect()` calls don't spawn duplicate listener threads.
static SUBSCRIBED: AtomicBool = AtomicBool::new(false);

/// Cache for the resolved adapter path. The adapter object rarely changes,
/// so we avoid one full `GetManagedObjects` round-trip per API call.
static ADAPTER_PATH_CACHE: OnceLock<Mutex<Option<String>>> = OnceLock::new();

fn adapter_cache() -> &'static Mutex<Option<String>> {
    ADAPTER_PATH_CACHE.get_or_init(|| Mutex::new(None))
}

// Thread-local reuse of the system-bus connection.
// FRB dispatches calls on a worker pool; each worker thread keeps its own
// connection instead of doing a Dial+Hello handshake on every call.
thread_local! {
    static TLS_CONN: RefCell<Option<Connection>> = const { RefCell::new(None) };
}

fn get_system_connection() -> Result<Connection, String> {
    Connection::system().map_err(|e| format!("Failed to connect to system bus: {e}"))
}

/// Run `f` with a cached thread-local connection, reconnecting once if the
/// cached connection turns out to be dead.
fn with_system_connection<T>(f: impl Fn(&Connection) -> Result<T, String>) -> Result<T, String> {
    // Simplest correct approach without Clone: hold the TLS borrow for the call.
    // If there is no cached connection or the call fails with a transport
    // error, drop it and retry once with a fresh connection.
    TLS_CONN.try_with(|cell| {
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
        // (Re)connect and retry once.
        let fresh = get_system_connection()?;
        let result = f(&fresh);
        *cell.borrow_mut() = Some(fresh);
        result
    }).map_err(|_| "Thread-local storage inaccessible".to_string())?
}

fn is_transport_error(msg: &str) -> bool {
    msg.contains("connection closed")
        || msg.contains("disconnected")
        || msg.contains("I/O error")
        || msg.contains("Broken pipe")
}

fn resolve_adapter_path_uncached(conn: &Connection) -> String {
    // Check if default adapter exists, or search in ObjectManager
    let reply = conn.call_method(
        Some(BLUEZ_SERVICE),
        "/",
        Some("org.freedesktop.DBus.ObjectManager"),
        "GetManagedObjects",
        &(),
    );

    if let Ok(reply) = reply {
        if let Ok(objects) = reply.body().deserialize::<HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>>() {
            for (path, ifaces) in objects {
                if ifaces.contains_key("org.bluez.Adapter1") {
                    return path.to_string();
                }
            }
        }
    }

    DEFAULT_ADAPTER_PATH.to_string()
}

fn resolve_adapter_path(conn: &Connection) -> String {
    if let Ok(guard) = adapter_cache().lock() {
        if let Some(cached) = guard.clone() {
            return cached;
        }
    }
    let resolved = resolve_adapter_path_uncached(conn);
    if let Ok(mut guard) = adapter_cache().lock() {
        *guard = Some(resolved.clone());
    }
    resolved
}

fn get_bool(props: &HashMap<String, OwnedValue>, key: &str) -> bool {
    props.get(key).and_then(|v| match v.deref() {
        Value::Bool(b) => Some(*b),
        _ => None,
    }).unwrap_or(false)
}

fn get_string(props: &HashMap<String, OwnedValue>, key: &str) -> String {
    props.get(key).and_then(|v| match v.deref() {
        Value::Str(s) => Some(s.as_str().to_string()),
        _ => None,
    }).unwrap_or_default()
}

fn get_i16(props: &HashMap<String, OwnedValue>, key: &str) -> i16 {
    props.get(key).and_then(|v| match v.deref() {
        Value::I16(i) => Some(*i),
        Value::I32(i) => Some(*i as i16),
        _ => None,
    }).unwrap_or(0)
}

pub fn get_adapter() -> Result<AdapterInfo, String> {
    with_system_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);

        let reply = conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some("org.freedesktop.DBus.Properties"),
            "GetAll",
            &("org.bluez.Adapter1",),
        ).map_err(|e| format!("Failed to get adapter properties: {e}"))?;

        let props: HashMap<String, OwnedValue> = reply
            .body()
            .deserialize()
            .map_err(|e| format!("Failed to deserialize adapter properties: {e}"))?;

        Ok(AdapterInfo {
            powered: get_bool(&props, "Powered"),
            discovering: get_bool(&props, "Discovering"),
            address: get_string(&props, "Address"),
            name: get_string(&props, "Name"),
            alias: get_string(&props, "Alias"),
        })
    })
}

pub fn set_adapter_power(powered: bool) -> Result<(), String> {
    with_system_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);

        conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some("org.freedesktop.DBus.Properties"),
            "Set",
            &("org.bluez.Adapter1", "Powered", Value::from(powered)),
        ).map_err(|e| format!("Failed to set adapter power: {e}"))?;

        Ok(())
    })
}

pub fn start_scan() -> Result<(), String> {
    with_system_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);

        conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some("org.bluez.Adapter1"),
            "StartDiscovery",
            &(),
        ).map_err(|e| format!("Failed to start scan: {e}"))?;

        Ok(())
    })
}

pub fn stop_scan() -> Result<(), String> {
    with_system_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);

        let result = conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some("org.bluez.Adapter1"),
            "StopDiscovery",
            &(),
        );

        if let Err(e) = result {
            let err_msg = e.to_string();
            if !err_msg.contains("No discovery started") && !err_msg.contains("InProgress") {
                return Err(format!("Failed to stop scan: {err_msg}"));
            }
        }

        Ok(())
    })
}

pub fn get_devices() -> Result<Vec<BluetoothDevice>, String> {
    with_system_connection(|conn| {
        let reply = conn.call_method(
            Some(BLUEZ_SERVICE),
            "/",
            Some("org.freedesktop.DBus.ObjectManager"),
            "GetManagedObjects",
            &(),
        ).map_err(|e| format!("Failed to get managed objects: {e}"))?;

        let objects: HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>> = reply
            .body()
            .deserialize()
            .map_err(|e| format!("Failed to deserialize managed objects: {e}"))?;

        let mut devices = Vec::new();

        for (path, ifaces) in objects {
            if let Some(props) = ifaces.get("org.bluez.Device1") {
                let mut name = get_string(props, "Name");
                if name.is_empty() {
                    name = get_string(props, "Alias");
                }

                devices.push(BluetoothDevice {
                    path: path.to_string(),
                    name,
                    address: get_string(props, "Address"),
                    connected: get_bool(props, "Connected"),
                    paired: get_bool(props, "Paired"),
                    trusted: get_bool(props, "Trusted"),
                    rssi: get_i16(props, "RSSI"),
                });
            }
        }

        Ok(devices)
    })
}

pub fn connect_device(path: String) -> Result<(), String> {
    with_system_connection(|conn| {
        conn.call_method(
            Some(BLUEZ_SERVICE),
            path.as_str(),
            Some("org.bluez.Device1"),
            "Connect",
            &(),
        ).map_err(|e| format!("Failed to connect device: {e}"))?;

        Ok(())
    })
}

pub fn disconnect_device(path: String) -> Result<(), String> {
    with_system_connection(|conn| {
        conn.call_method(
            Some(BLUEZ_SERVICE),
            path.as_str(),
            Some("org.bluez.Device1"),
            "Disconnect",
            &(),
        ).map_err(|e| format!("Failed to disconnect device: {e}"))?;

        Ok(())
    })
}

pub fn pair_device(path: String) -> Result<(), String> {
    with_system_connection(|conn| {
        conn.call_method(
            Some(BLUEZ_SERVICE),
            path.as_str(),
            Some("org.bluez.Device1"),
            "Pair",
            &(),
        ).map_err(|e| format!("Failed to pair device: {e}"))?;

        Ok(())
    })
}

pub fn set_device_trusted(path: String, trusted: bool) -> Result<(), String> {
    with_system_connection(|conn| {
        conn.call_method(
            Some(BLUEZ_SERVICE),
            path.as_str(),
            Some("org.freedesktop.DBus.Properties"),
            "Set",
            &("org.bluez.Device1", "Trusted", Value::from(trusted)),
        ).map_err(|e| format!("Failed to set device trust: {e}"))?;

        Ok(())
    })
}

pub fn remove_device(path: String) -> Result<(), String> {
    with_system_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);
        let dev_path = zbus::zvariant::ObjectPath::try_from(path.as_str())
            .map_err(|e| format!("Invalid device path: {e}"))?;

        conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some("org.bluez.Adapter1"),
            "RemoveDevice",
            &(dev_path,),
        ).map_err(|e| format!("Failed to remove device: {e}"))?;

        Ok(())
    })
}

pub fn subscribe_bluetooth_events(sink: StreamSink<BluetoothEvent>) -> Result<(), String> {
    // Idempotent: Dart may call connect() again after rebuilds/hot-restart.
    if SUBSCRIBED.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    let conn = get_system_connection().map_err(|e| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        e
    })?;
    let dbus = DBusProxy::new(&conn)
        .map_err(|e| {
            SUBSCRIBED.store(false, Ordering::SeqCst);
            format!("Failed to create DBusProxy: {e}")
        })?;

    // Only listen to BlueZ signals under /org/bluez. Without the sender +
    // path filter, every PropertiesChanged on the system bus (NetworkManager,
    // UPower, ...) would wake the Dart isolate.
    let props_rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(BLUEZ_SERVICE)
        .map_err(|e| format!("Failed to create properties match rule: {e}"))?
        .interface("org.freedesktop.DBus.Properties")
        .map_err(|e| format!("Failed to create properties match rule: {e}"))?
        .path_namespace(BLUEZ_PATH_PREFIX)
        .map_err(|e| format!("Failed to create properties match rule: {e}"))?
        .build();

    let obj_mgr_rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(BLUEZ_SERVICE)
        .map_err(|e| format!("Failed to create ObjectManager match rule: {e}"))?
        .interface("org.freedesktop.DBus.ObjectManager")
        .map_err(|e| format!("Failed to create ObjectManager match rule: {e}"))?
        .path_namespace(BLUEZ_PATH_PREFIX)
        .map_err(|e| format!("Failed to create ObjectManager match rule: {e}"))?
        .build();

    dbus.add_match_rule(props_rule)
        .map_err(|e| {
            SUBSCRIBED.store(false, Ordering::SeqCst);
            format!("Failed to add properties match rule: {e}")
        })?;
    dbus.add_match_rule(obj_mgr_rule)
        .map_err(|e| {
            SUBSCRIBED.store(false, Ordering::SeqCst);
            format!("Failed to add ObjectManager match rule: {e}")
        })?;

    thread::spawn(move || {
        let iter = MessageIterator::from(&conn);
        // Per-path last-emit for PropertiesChanged throttling (RSSI bursts).
        let mut last_emit: HashMap<String, Instant> = HashMap::new();
        for msg in iter {
            let Ok(msg) = msg else { continue };
            let header = msg.header();
            let path = header
                .path()
                .map(|p| p.to_string())
                .unwrap_or_default();
            if path.is_empty() || !path.starts_with(BLUEZ_PATH_PREFIX) {
                continue;
            }
            let member = header.member().map(|m| m.to_string()).unwrap_or_default();
            let event_type: &'static str = match member.as_str() {
                "InterfacesAdded" => "interfaces_added",
                "InterfacesRemoved" => "interfaces_removed",
                "PropertiesChanged" => "properties_changed",
                _ => continue,
            };
            // Throttle only the noisy PropertiesChanged (RSSI) per path.
            // Added/removed always pass through immediately.
            if matches!(event_type, "properties_changed") {
                let now = Instant::now();
                if let Some(prev) = last_emit.get(&path) {
                    if now.duration_since(*prev) < PROPS_THROTTLE {
                        continue;
                    }
                }
                last_emit.insert(path.clone(), now);
            }

            let event = BluetoothEvent {
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
