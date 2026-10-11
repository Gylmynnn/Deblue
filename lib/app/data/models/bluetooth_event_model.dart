import '../../../../src/rust/api/bluetooth.dart' as rust_api;

class BluetoothEventModel {
  final String type;
  final String path;

  const BluetoothEventModel({required this.type, required this.path});

  factory BluetoothEventModel.fromRust(rust_api.BluetoothEvent event) {
    return BluetoothEventModel(
      type: event.eventType,
      path: event.path,
    );
  }

  factory BluetoothEventModel.fromJson(Map<String, dynamic> json) {
    return BluetoothEventModel(
      type: json['type'] ?? '',
      path: json['path'] ?? '',
    );
  }
}
