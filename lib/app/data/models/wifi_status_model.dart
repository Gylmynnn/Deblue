import '../../../../src/rust/api/wifi.dart' as rust_api;

class WifiStatusModel {
  final bool enabled;
  final bool connected;
  final String activeSsid;
  final int activeSignal;
  final String device;

  const WifiStatusModel({
    required this.enabled,
    required this.connected,
    required this.activeSsid,
    required this.activeSignal,
    required this.device,
  });

  factory WifiStatusModel.fromRust(rust_api.WifiStatus status) {
    return WifiStatusModel(
      enabled: status.enabled,
      connected: status.connected,
      activeSsid: status.activeSsid,
      activeSignal: status.activeSignal,
      device: status.device,
    );
  }
}
