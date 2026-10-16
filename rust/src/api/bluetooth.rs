use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::sync::OnceLock;
use std::thread;
use zbus::blocking::fdo::DBusProxy;
use zbus::blocking::Connection;
use zbus::blocking::MessageIterator;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};

use crate::common::bus::{self, get_all_props, with_connection};
use crate::common::error::ApiResult;
use crate::common::events::{self, ThrottleMap, PROPS_THROTTLE};
use crate::common::props;
use crate::frb_generated::StreamSink;

const BLUEZ_SERVICE: &str = "org.bluez";
const BLUEZ_PATH_PREFIX: &str = "/org/bluez";
const DEFAULT_ADAPTER_PATH: &str = "/org/bluez/hci0";
const IFACE_ADAPTER: &str = "org.bluez.Adapter1";
const IFACE_DEVICE: &str = "org.bluez.Device1";
const IFACE_PROPS: &str = "org.freedesktop.DBus.Properties";
const IFACE_OBJ_MGR: &str = "org.freedesktop.DBus.ObjectManager";

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

/// Guard so repeated Dart `connect()` calls don't spawn duplicate threads.
static SUBSCRIBED: AtomicBool = AtomicBool::new(false);

/// Resolved adapter path cache — avoids one `GetManagedObjects` per call.
static ADAPTER_PATH_CACHE: OnceLock<Mutex<Option<String>>> = OnceLock::new();

fn adapter_cache() -> &'static Mutex<Option<String>> {
    ADAPTER_PATH_CACHE.get_or_init(|| Mutex::new(None))
}

fn resolve_adapter_path_uncached(conn: &Connection) -> String {
    if let Ok(reply) = conn.call_method(
        Some(BLUEZ_SERVICE),
        "/",
        Some(IFACE_OBJ_MGR),
        "GetManagedObjects",
        &(),
    ) {
        type Objects = HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>;
        if let Ok(objects) = reply.body().deserialize::<Objects>() {
            for (path, ifaces) in &objects {
                if ifaces.contains_key(IFACE_ADAPTER) {
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

fn device_method(path: &str, method: &str) -> ApiResult<()> {
    with_connection(|conn| {
        conn.call_method(Some(BLUEZ_SERVICE), path, Some(IFACE_DEVICE), method, &())
            .map_err(|e| format!("Failed to {method} device: {e}"))?;
        Ok(())
    })
}

pub fn get_adapter() -> ApiResult<AdapterInfo> {
    with_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);
        let props = get_all_props(conn, BLUEZ_SERVICE, &adapter_path, IFACE_ADAPTER)?;
        Ok(AdapterInfo {
            powered: props::get_bool(&props, "Powered"),
            discovering: props::get_bool(&props, "Discovering"),
            address: props::get_string(&props, "Address"),
            name: props::get_string(&props, "Name"),
            alias: props::get_string(&props, "Alias"),
        })
    })
}

pub fn set_adapter_power(powered: bool) -> ApiResult<()> {
    with_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);
        conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some(IFACE_PROPS),
            "Set",
            &(IFACE_ADAPTER, "Powered", Value::from(powered)),
        )
        .map_err(|e| format!("Failed to set adapter power: {e}"))?;
        Ok(())
    })
}

pub fn start_scan() -> ApiResult<()> {
    with_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);
        conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some(IFACE_ADAPTER),
            "StartDiscovery",
            &(),
        )
        .map_err(|e| format!("Failed to start scan: {e}"))?;
        Ok(())
    })
}

pub fn stop_scan() -> ApiResult<()> {
    with_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);
        let result = conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some(IFACE_ADAPTER),
            "StopDiscovery",
            &(),
        );
        if let Err(e) = result {
            let msg = e.to_string();
            if !msg.contains("No discovery started") && !msg.contains("InProgress") {
                return Err(format!("Failed to stop scan: {msg}"));
            }
        }
        Ok(())
    })
}

pub fn get_devices() -> ApiResult<Vec<BluetoothDevice>> {
    with_connection(|conn| {
        let reply = conn
            .call_method(
                Some(BLUEZ_SERVICE),
                "/",
                Some(IFACE_OBJ_MGR),
                "GetManagedObjects",
                &(),
            )
            .map_err(|e| format!("Failed to get managed objects: {e}"))?;
        type Objects = HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>;
        let objects: Objects = reply
            .body()
            .deserialize()
            .map_err(|e| format!("Failed to deserialize managed objects: {e}"))?;

        let devices = objects
            .into_iter()
            .filter_map(|(path, ifaces)| {
                let p = ifaces.get(IFACE_DEVICE)?;
                let mut name = props::get_string(p, "Name");
                if name.is_empty() {
                    name = props::get_string(p, "Alias");
                }
                Some(BluetoothDevice {
                    path: path.to_string(),
                    name,
                    address: props::get_string(p, "Address"),
                    connected: props::get_bool(p, "Connected"),
                    paired: props::get_bool(p, "Paired"),
                    trusted: props::get_bool(p, "Trusted"),
                    rssi: props::get_i16(p, "RSSI"),
                })
            })
            .collect();
        Ok(devices)
    })
}

pub fn connect_device(path: String) -> ApiResult<()> {
    device_method(&path, "Connect")
}

pub fn disconnect_device(path: String) -> ApiResult<()> {
    device_method(&path, "Disconnect")
}

pub fn pair_device(path: String) -> ApiResult<()> {
    device_method(&path, "Pair")
}

pub fn set_device_trusted(path: String, trusted: bool) -> ApiResult<()> {
    with_connection(|conn| {
        conn.call_method(
            Some(BLUEZ_SERVICE),
            path.as_str(),
            Some(IFACE_PROPS),
            "Set",
            &(IFACE_DEVICE, "Trusted", Value::from(trusted)),
        )
        .map_err(|e| format!("Failed to set device trust: {e}"))?;
        Ok(())
    })
}

pub fn remove_device(path: String) -> ApiResult<()> {
    with_connection(|conn| {
        let adapter_path = resolve_adapter_path(conn);
        let dev_path = zbus::zvariant::ObjectPath::try_from(path.as_str())
            .map_err(|e| format!("Invalid device path: {e}"))?;
        conn.call_method(
            Some(BLUEZ_SERVICE),
            adapter_path.as_str(),
            Some(IFACE_ADAPTER),
            "RemoveDevice",
            &(dev_path,),
        )
        .map_err(|e| format!("Failed to remove device: {e}"))?;
        Ok(())
    })
}

pub fn subscribe_bluetooth_events(sink: StreamSink<BluetoothEvent>) -> ApiResult<()> {
    // Idempotent: Dart may call connect() again after rebuilds/hot-restart.
    if SUBSCRIBED.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    let conn = bus::system_connection().inspect_err(|_| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
    })?;
    let dbus = DBusProxy::new(&conn).map_err(|e| {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        format!("Failed to create DBusProxy: {e}")
    })?;

    // Only BlueZ signals under /org/bluez — otherwise every PropertiesChanged
    // on the system bus (NM, UPower, ...) would wake the Dart isolate.
    let props_rule = events::signal_rule(BLUEZ_SERVICE, IFACE_PROPS, BLUEZ_PATH_PREFIX)?;
    let obj_mgr_rule = events::signal_rule(BLUEZ_SERVICE, IFACE_OBJ_MGR, BLUEZ_PATH_PREFIX)?;
    if let Err(e) = dbus.add_match_rule(props_rule) {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        return Err(format!("Failed to add properties match rule: {e}"));
    }
    if let Err(e) = dbus.add_match_rule(obj_mgr_rule) {
        SUBSCRIBED.store(false, Ordering::SeqCst);
        return Err(format!("Failed to add ObjectManager match rule: {e}"));
    }

    thread::spawn(move || {
        let mut throttle = ThrottleMap::new(PROPS_THROTTLE);
        for msg in MessageIterator::from(&conn) {
            let Ok(msg) = msg else { continue };
            let header = msg.header();
            let path = header.path().map(|p| p.to_string()).unwrap_or_default();
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
            // Throttle only noisy PropertiesChanged (RSSI); Added/Removed
            // always pass through immediately.
            if !throttle.should_emit(&path, event_type == "properties_changed") {
                continue;
            }
            let event = BluetoothEvent {
                event_type: event_type.to_string(),
                path,
            };
            if sink.add(event).is_err() {
                break; // Dart listener closed/canceled.
            }
        }
        SUBSCRIBED.store(false, Ordering::SeqCst);
    });

    Ok(())
}
