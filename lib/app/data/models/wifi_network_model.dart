import '../../../../src/rust/api/wifi.dart' as rust_api;

class WifiNetworkModel {
  final String ssid;
  final String bssid;
  final int signal;
  final int frequency;
  final String security;
  final bool inUse;
  final bool saved;

  const WifiNetworkModel({
    required this.ssid,
    required this.bssid,
    required this.signal,
    required this.frequency,
    required this.security,
    required this.inUse,
    required this.saved,
  });

  bool get isOpen => security.toLowerCase() == 'open';
  bool get isSecured => !isOpen;

  /// Radio band derived from the AP frequency: 2.4 / 5 / 6 GHz.
  String get band {
    if (frequency <= 0) return '';
    if (frequency < 3000) return '2.4 GHz';
    if (frequency < 6000) return '5 GHz';
    return '6 GHz';
  }

  factory WifiNetworkModel.fromRust(rust_api.WifiNetwork net) {
    return WifiNetworkModel(
      ssid: net.ssid,
      bssid: net.bssid,
      signal: net.signal,
      frequency: net.frequency,
      security: net.security,
      inUse: net.inUse,
      saved: net.saved,
    );
  }
}
