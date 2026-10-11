import '../models/adapter_model.dart';
import '../models/device_model.dart';
import '../repositories/bluetooth_repo.dart';
import '../../../../src/rust/api/bluetooth.dart' as rust_api;

class BluetoothService implements BluetoothRepo {
  @override
  Future<AdapterModel?> getAdapter() async {
    try {
      final info = await rust_api.getAdapter();
      return AdapterModel.fromRust(info);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<List<DeviceModel>> getDevices() async {
    try {
      final devices = await rust_api.getDevices();
      return devices.map(DeviceModel.fromRust).toList();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> startScan() async {
    try {
      await rust_api.startScan();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await rust_api.stopScan();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setPower(bool powered) async {
    try {
      await rust_api.setAdapterPower(powered: powered);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> connect(String path) async {
    try {
      await rust_api.connectDevice(path: path);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> disconnect(String path) async {
    try {
      await rust_api.disconnectDevice(path: path);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> pair(String path) async {
    try {
      await rust_api.pairDevice(path: path);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> trust(String path) async {
    try {
      await rust_api.setDeviceTrusted(path: path, trusted: true);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> untrust(String path) async {
    try {
      await rust_api.setDeviceTrusted(path: path, trusted: false);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> remove(String path) async {
    try {
      await rust_api.removeDevice(path: path);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
