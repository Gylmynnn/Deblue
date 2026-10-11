import '../../../../src/rust/api/bluetooth.dart' as rust_api;

class DeviceModel {
  final String path;
  final String name;
  final String address;
  final bool connected;
  final bool paired;
  final bool trusted;
  final int rssi;

  const DeviceModel({
    required this.path,
    required this.name,
    required this.address,
    required this.connected,
    required this.paired,
    required this.trusted,
    required this.rssi,
  });

  String get nameOrUnknown {
    if (name.trim().isEmpty) {
      return 'Unknown Device';
    }
    return name;
  }

  factory DeviceModel.fromRust(rust_api.BluetoothDevice dev) {
    return DeviceModel(
      path: dev.path,
      name: dev.name,
      address: dev.address,
      connected: dev.connected,
      paired: dev.paired,
      trusted: dev.trusted,
      rssi: dev.rssi,
    );
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      connected: json['connected'] ?? false,
      paired: json['paired'] ?? false,
      trusted: json['trusted'] ?? false,
      rssi: json['rssi'] ?? 0,
    );
  }
}
