import '../models/wifi_device_model.dart';
import '../models/wifi_network_model.dart';
import '../models/wifi_status_model.dart';

abstract class WifiRepo {
  Future<List<WifiDeviceModel>> getDevices();
  Future<WifiStatusModel?> getStatus(String device);
  Future<List<WifiNetworkModel>> getNetworks(String device);
  Future<void> requestScan();
  Future<void> setEnabled(bool enabled);
  Future<void> connectSaved(String ssid, String device);
  Future<void> connectNew(String ssid, String password, String device);
  Future<void> disconnect(String device);
  Future<int> forget(String ssid);
}
