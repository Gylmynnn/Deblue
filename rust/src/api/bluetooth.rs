use std::collections::HashMap;
use std::ops::Deref;
use std::thread;
use zbus::blocking::Connection;
use zbus::blocking::fdo::DBusProxy;
use zbus::blocking::MessageIterator;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};
use zbus::MatchRule;
use crate::frb_generated::StreamSink;

const BLUEZ_SERVICE: &str = "org.bluez";
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

fn get_system_connection() -> Result<Connection, String> {
    Connection::system().map_err(|e| format!("Failed to connect to system bus: {e}"))
}

fn resolve_adapter_path(conn: &Connection) -> String {
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
    let conn = get_system_connection()?;
    let adapter_path = resolve_adapter_path(&conn);

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
}

pub fn set_adapter_power(powered: bool) -> Result<(), String> {
    let conn = get_system_connection()?;
    let adapter_path = resolve_adapter_path(&conn);

    conn.call_method(
        Some(BLUEZ_SERVICE),
        adapter_path.as_str(),
        Some("org.freedesktop.DBus.Properties"),
        "Set",
        &("org.bluez.Adapter1", "Powered", Value::from(powered)),
    ).map_err(|e| format!("Failed to set adapter power: {e}"))?;

    Ok(())
}

pub fn start_scan() -> Result<(), String> {
    let conn = get_system_connection()?;
    let adapter_path = resolve_adapter_path(&conn);

    conn.call_method(
        Some(BLUEZ_SERVICE),
        adapter_path.as_str(),
        Some("org.bluez.Adapter1"),
        "StartDiscovery",
        &(),
    ).map_err(|e| format!("Failed to start scan: {e}"))?;

    Ok(())
}

pub fn stop_scan() -> Result<(), String> {
    let conn = get_system_connection()?;
    let adapter_path = resolve_adapter_path(&conn);

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
}

pub fn get_devices() -> Result<Vec<BluetoothDevice>, String> {
    let conn = get_system_connection()?;

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
}

pub fn connect_device(path: String) -> Result<(), String> {
    let conn = get_system_connection()?;

    conn.call_method(
        Some(BLUEZ_SERVICE),
        path.as_str(),
        Some("org.bluez.Device1"),
        "Connect",
        &(),
    ).map_err(|e| format!("Failed to connect device: {e}"))?;

    Ok(())
}

pub fn disconnect_device(path: String) -> Result<(), String> {
    let conn = get_system_connection()?;

    conn.call_method(
        Some(BLUEZ_SERVICE),
        path.as_str(),
        Some("org.bluez.Device1"),
        "Disconnect",
        &(),
    ).map_err(|e| format!("Failed to disconnect device: {e}"))?;

    Ok(())
}

pub fn pair_device(path: String) -> Result<(), String> {
    let conn = get_system_connection()?;

    conn.call_method(
        Some(BLUEZ_SERVICE),
        path.as_str(),
        Some("org.bluez.Device1"),
        "Pair",
        &(),
    ).map_err(|e| format!("Failed to pair device: {e}"))?;

    Ok(())
}

pub fn set_device_trusted(path: String, trusted: bool) -> Result<(), String> {
    let conn = get_system_connection()?;

    conn.call_method(
        Some(BLUEZ_SERVICE),
        path.as_str(),
        Some("org.freedesktop.DBus.Properties"),
        "Set",
        &("org.bluez.Device1", "Trusted", Value::from(trusted)),
    ).map_err(|e| format!("Failed to set device trust: {e}"))?;

    Ok(())
}

pub fn remove_device(path: String) -> Result<(), String> {
    let conn = get_system_connection()?;
    let adapter_path = resolve_adapter_path(&conn);
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
}

pub fn subscribe_bluetooth_events(sink: StreamSink<BluetoothEvent>) -> Result<(), String> {
    let conn = get_system_connection()?;
    let dbus = DBusProxy::new(&conn)
        .map_err(|e| format!("Failed to create DBusProxy: {e}"))?;

    let props_rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .interface("org.freedesktop.DBus.Properties")
        .map_err(|e| format!("Failed to create properties match rule: {e}"))?
        .build();

    let obj_mgr_rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .interface("org.freedesktop.DBus.ObjectManager")
        .map_err(|e| format!("Failed to create ObjectManager match rule: {e}"))?
        .build();

    let _ = dbus.add_match_rule(props_rule);
    let _ = dbus.add_match_rule(obj_mgr_rule);

    thread::spawn(move || {
        let iter = MessageIterator::from(&conn);
        for msg in iter {
            if let Ok(msg) = msg {
                let path = msg
                    .header()
                    .path()
                    .map(|p| p.to_string())
                    .unwrap_or_default();

                let event = BluetoothEvent {
                    event_type: "bluetooth_event".to_string(),
                    path,
                };

                if sink.add(event).is_err() {
                    // Dart stream listener has closed/canceled
                    break;
                }
            }
        }
    });

    Ok(())
}
