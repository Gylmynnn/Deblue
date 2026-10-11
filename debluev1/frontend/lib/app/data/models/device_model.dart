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
