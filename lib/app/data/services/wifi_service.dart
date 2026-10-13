import '../models/wifi_device_model.dart';
import '../models/wifi_network_model.dart';
import '../models/wifi_status_model.dart';
import '../repositories/wifi_repo.dart';
import '../../../../src/rust/api/wifi.dart' as rust_api;

class WifiService implements WifiRepo {
  @override
  Future<List<WifiDeviceModel>> getDevices() async {
    try {
      final devices = await rust_api.getDevices();
      return devices.map(WifiDeviceModel.fromRust).toList();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<WifiStatusModel?> getStatus(String device) async {
    try {
      final status = await rust_api.getWifiStatus(device: device);
      return WifiStatusModel.fromRust(status);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<List<WifiNetworkModel>> getNetworks(String device) async {
    try {
      final networks = await rust_api.getNetworks(device: device);
      return networks.map(WifiNetworkModel.fromRust).toList();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> requestScan() async {
    try {
      await rust_api.requestScan();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await rust_api.setWifiEnabled(enabled: enabled);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> connectSaved(String ssid, String device) async {
    try {
      await rust_api.connectSaved(ssid: ssid, device: device);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> connectNew(
    String ssid,
    String password,
    String device,
  ) async {
    try {
      await rust_api.connectNew(
        ssid: ssid,
        password: password,
        device: device,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> disconnect(String device) async {
    try {
      await rust_api.disconnect(device: device);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<int> forget(String ssid) async {
    try {
      return await rust_api.forget(ssid: ssid);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
