import '../../../../src/rust/api/wifi.dart' as rust_api;

/// Maps kernel driver names to friendly vendor labels so the adapter
/// picker shows hardware (e.g. "Intel", "Qualcomm Atheros") instead of
/// raw interface names like wlan0/wlan1.
String vendorLabelForDriver(String driver) {
  final d = driver.toLowerCase();
  if (d.isEmpty) return 'Unknown adapter';
  if (d.startsWith('iwl') || d.contains('intel')) return 'Intel';
  if (d.startsWith('ath') || d.contains('atheros') || d == 'carl9170') {
    return 'Qualcomm Atheros';
  }
  if (d.startsWith('mt76') || d.startsWith('mt79') || d.contains('mediatek')) {
    return 'MediaTek';
  }
  if (d.startsWith('rtw') ||
      d.startsWith('rtl') ||
      d.contains('realtek')) {
    return 'Realtek';
  }
  if (d.startsWith('brcm') || d == 'b43' || d.contains('broadcom')) {
    return 'Broadcom';
  }
  if (d.startsWith('mwl') || d.contains('marvell')) return 'Marvell';
  if (d.contains('apple')) return 'Apple';
  return driver;
}

class WifiDeviceModel {
  final String iface;
  final int state;
  final bool connected;
  final String activeSsid;
  final String driver;
  final String hwAddress;
  final String udi;

  const WifiDeviceModel({
    required this.iface,
    required this.state,
    required this.connected,
    required this.activeSsid,
    required this.driver,
    required this.hwAddress,
    required this.udi,
  });

  /// Heuristic: USB sysfs path means an external (dongle) adapter,
  /// PCI/SDIO means built-in.
  bool get isUsb => udi.contains('/usb');

  String get vendorLabel => vendorLabelForDriver(driver);

  /// e.g. "Intel (wlan0)" or "Qualcomm Atheros (wlan1, USB) • MySSID"
  String get displayLabel {
    final bus = isUsb ? ', USB' : '';
    final base = '$vendorLabel ($iface$bus)';
    if (activeSsid.isNotEmpty) return '$base • $activeSsid';
    return base;
  }

  factory WifiDeviceModel.fromRust(rust_api.WifiDevice dev) {
    return WifiDeviceModel(
      iface: dev.iface,
      state: dev.state,
      connected: dev.connected,
      activeSsid: dev.activeSsid,
      driver: dev.driver,
      hwAddress: dev.hwAddress,
      udi: dev.udi,
    );
  }
}
