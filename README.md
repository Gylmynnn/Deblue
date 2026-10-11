# Deblue v2 - Bluetooth Manager

Deblue v2 is a unified Linux Bluetooth Manager built with **Flutter**, **GetX**, and **Rust** via **Flutter Rust Bridge (v2)**.

In v2, the previous external Go REST/WebSocket backend from `debluev1` has been migrated into an embedded native Rust module communicating directly with Linux BlueZ via D-Bus (`zbus`).

---

## Architecture Overview

```
+--------------------------------------------------------------+
|                         Deblue v2                            |
|                                                              |
|  +---------------------------+  +--------------------------+ |
|  |    Flutter UI (GetX)      |  |     Rust Core (zbus)     | |
|  |                           |  |                          | |
|  | - Home & Settings Views   |  | - BlueZ D-Bus Adapter    | |
|  | - Custom Window & Themes  |  | - Device Operations     | |
|  | - GetX Controllers        |  | - D-Bus Signal Listener  | |
|  +-------------+-------------+  +------------+-------------+ |
|                |                             |               |
|                +<==== Flutter Rust Bridge ===>+              |
|                     (In-Process FFI Stream)                  |
+--------------------------------------------------------------+
                               |
                               v
                       Linux BlueZ Daemon
```

### Improvements from v1
- **Unified single project:** No need to build, bundle, or spawn a separate Go daemon process.
- **Direct in-process FFI:** Eliminates localhost HTTP/WebSocket overhead and port conflicts (`8787`).
- **Real-time Event Streaming:** BlueZ D-Bus property changes stream natively into Dart using FRB streams.
- **Identical UI & State Management:** Preserves all themes, layout options (Grid, Tile, Compact), filters, and dialogs using GetX.

---

## Project Structure

- `rust/`: Rust crate containing BlueZ integration using `zbus`.
  - `src/api/bluetooth.rs`: Adapter discovery, device actions (connect, disconnect, pair, trust, remove), scan operations, and real-time event streaming.
- `lib/`: Flutter frontend application.
  - `app/data/services/bluetooth_service.dart`: Implements `BluetoothRepo` calling Rust bridge functions.
  - `app/data/services/bluetooth_event_service.dart`: Listens to the Rust event stream.
  - `app/modules/home/`: Home controller and views.
  - `app/widgets/`: Window shell, device cards, detail panels, and dialogs.
  - `src/rust/`: Generated Dart bindings from `flutter_rust_bridge_codegen`.

---

## Development & Build

### Prerequisites
- Flutter SDK (>= 3.13)
- Rust & Cargo (>= 1.80)
- `flutter_rust_bridge_codegen` (v2.13.0)
- Linux packages: `libgtk-3-dev`, `libayatana-appindicator3-dev` (or standard Flutter Linux build dependencies)

### Generating Bindings (if Rust API changes)
```bash
flutter_rust_bridge_codegen generate
```

### Running the App
```bash
flutter run -d linux
```

### Building Release Bundle
```bash
flutter build linux --release
```
