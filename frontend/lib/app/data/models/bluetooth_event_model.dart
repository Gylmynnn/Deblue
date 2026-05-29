class BluetoothEventModel {
  final String type;
  final String path;

  const BluetoothEventModel({required this.type, required this.path});

  factory BluetoothEventModel.fromJson(Map<String, dynamic> json) {
    return BluetoothEventModel(
      type: json['type'] ?? '',
      path: json['path'] ?? '',
    );
  }
}
