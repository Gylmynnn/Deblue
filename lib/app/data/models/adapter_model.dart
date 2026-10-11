import '../../../../src/rust/api/bluetooth.dart' as rust_api;

class AdapterModel {
  final bool powered;
  final bool discovering;
  final String address;
  final String name;
  final String alias;

  const AdapterModel({
    required this.powered,
    required this.discovering,
    required this.address,
    required this.name,
    required this.alias,
  });

  factory AdapterModel.fromRust(rust_api.AdapterInfo info) {
    return AdapterModel(
      powered: info.powered,
      discovering: info.discovering,
      address: info.address,
      name: info.name,
      alias: info.alias,
    );
  }

  factory AdapterModel.fromJson(Map<String, dynamic> json) {
    return AdapterModel(
      powered: json['powered'] ?? false,
      discovering: json['discovering'] ?? false,
      address: json['address'] ?? '',
      name: json['name'] ?? '',
      alias: json['alias'] ?? '',
    );
  }
}
