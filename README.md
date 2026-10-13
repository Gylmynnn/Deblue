# DeSys - Linux System Settings Manager

DeSys is a unified Linux System Settings app built with **Flutter**, **GetX**, and **Rust** via **Flutter Rust Bridge (v2)**.

It started as Deblue (Bluetooth Manager, `debluev1` Go backend → v2 embedded Rust). It is now renamed to DeSys to cover all system settings modules: **Bluetooth, WiFi, Sound, ...**

The Rust core talks directly to system daemons via D-Bus (`zbus`): BlueZ for Bluetooth, NetworkManager for WiFi.

---

## Architecture Overview

```
+--------------------------------------------------------------+
|                           DeSys                              |
|                                                              |
|  +---------------------------+  +--------------------------+ |
|  |    Flutter UI (GetX)      |  |     Rust Core (zbus)     | |
|  |                           |  |                          | |
|  | - Sidebar modules         |  | - BlueZ D-Bus Adapter    | |
|  |   (Bluetooth, WiFi, ...)  |  | - NetworkManager (WiFi)  | |
|  | - Custom Window & Themes  |  | - Device Operations     | |
|  | - GetX Controllers        |  | - D-Bus Signal Listener  | |
|  +-------------+-------------+  +------------+-------------+ |
|                |                             |               |
|                +<==== Flutter Rust Bridge ===>+              |
|                     (In-Process FFI Stream)                  |
+--------------------------------------------------------------+
                                |
                                v
                  Linux Daemons (BlueZ, NetworkManager)
```

---

## Project Structure

- `rust/`: Rust crate (`rust_lib_desys`) containing system integrations using `zbus`.
  - `src/api/bluetooth.rs`: Adapter discovery, device actions (connect, disconnect, pair, trust, remove), scan operations, and real-time event streaming.
  - `src/api/wifi.rs` (planned): NetworkManager scan, connect, disconnect, saved networks, WiFi toggle, event streaming.
- `lib/`: Flutter frontend application (`desys` package).
  - `app/data/services/bluetooth_service.dart`: Implements `BluetoothRepo` calling Rust bridge functions.
  - `app/data/services/bluetooth_event_service.dart`: Listens to the Rust event stream.
  - `app/modules/home/`: Bluetooth module (to become one sidebar module among WiFi/Sound).
  - `app/widgets/app_shell.dart`: Sidebar shell (`DeSys` brand).
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
