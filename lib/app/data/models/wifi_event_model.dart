import '../../../../src/rust/api/wifi.dart' as rust_api;

class WifiEventModel {
  final String type;
  final String path;

  const WifiEventModel({required this.type, required this.path});

  factory WifiEventModel.fromRust(rust_api.WifiEvent event) {
    return WifiEventModel(
      type: event.eventType,
      path: event.path,
    );
  }
}
