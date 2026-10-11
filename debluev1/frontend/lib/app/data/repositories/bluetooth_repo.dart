import 'package:frontend/app/data/models/adapter_model.dart';
import 'package:frontend/app/data/models/device_model.dart';

abstract class BluetoothRepo {
  Future<AdapterModel?> getAdapter();
  Future<List<DeviceModel>> getDevices();
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> setPower(bool powered);
  Future<void> connect(String path);
  Future<void> disconnect(String path);
  Future<void> pair(String path);
  Future<void> trust(String path);
  Future<void> untrust(String path);
  Future<void> remove(String path);
}
