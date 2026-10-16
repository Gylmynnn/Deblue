//! Cached system-bus connection + `Properties.GetAll` helper.
//!
//! FRB dispatches calls on a worker pool. Dialling + `Hello` on every call
//! costs a round-trip, so each worker thread keeps one cached [`Connection`].
//! [`with_connection`] reuses it and reconnects once when the cached
//! connection looks dead.

use std::cell::RefCell;
use std::collections::HashMap;
use zbus::blocking::Connection;
use zbus::zvariant::OwnedValue;

use super::error::ApiResult;

thread_local! {
    static TLS_CONN: RefCell<Option<Connection>> = const { RefCell::new(None) };
}

pub fn system_connection() -> ApiResult<Connection> {
    Connection::system().map_err(|e| format!("Failed to connect to system bus: {e}"))
}

fn is_transport_error(msg: &str) -> bool {
    msg.contains("connection closed")
        || msg.contains("disconnected")
        || msg.contains("I/O error")
        || msg.contains("Broken pipe")
}

/// Run `f` with the thread-local connection, reconnecting once when the
/// cached connection fails with a transport error.
pub fn with_connection<T>(f: impl Fn(&Connection) -> ApiResult<T>) -> ApiResult<T> {
    let retry = TLS_CONN
        .try_with(|cell| {
            // Try the cached connection first without holding the borrow
            // across a reconnect.
            let cached = {
                let slot = cell.borrow();
                match slot.as_ref() {
                    Some(conn) => match f(conn) {
                        Ok(v) => Some(Ok(v)),
                        Err(e) if is_transport_error(&e) => None,
                        Err(e) => Some(Err(e)),
                    },
                    None => None,
                }
            };
            if let Some(result) = cached {
                return result;
            }
            // (Re)connect and retry once.
            let fresh = system_connection()?;
            let result = f(&fresh);
            *cell.borrow_mut() = Some(fresh);
            result
        })
        .map_err(|_| "Thread-local storage inaccessible".to_string())?;
    retry
}

/// `org.freedesktop.DBus.Properties.GetAll(iface)` on `path`.
pub fn get_all_props(
    conn: &Connection,
    service: &str,
    path: &str,
    iface: &str,
) -> ApiResult<HashMap<String, OwnedValue>> {
    let reply = conn
        .call_method(
            Some(service),
            path,
            Some("org.freedesktop.DBus.Properties"),
            "GetAll",
            &(iface,),
        )
        .map_err(|e| format!("Failed to get properties for {path}: {e}"))?;
    reply
        .body()
        .deserialize()
        .map_err(|e| format!("Failed to deserialize properties for {path}: {e}"))
}
