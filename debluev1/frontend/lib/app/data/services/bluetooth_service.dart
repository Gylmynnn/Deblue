import 'package:frontend/app/data/repositories/bluetooth_repo.dart';
import 'package:get/get.dart';
import '../models/adapter_model.dart';
import '../models/device_model.dart';
import 'api_service.dart';

class BluetoothService implements BluetoothRepo {
  final ApiService _api = Get.find<ApiService>();

  @override
  Future<AdapterModel?> getAdapter() async {
    final Response response = await _api.get('/adapter');
    _throwIfError(response);
    return AdapterModel.fromJson(response.body['data']);
  }

  @override
  Future<List<DeviceModel>> getDevices() async {
    final Response response = await _api.get('/devices');
    _throwIfError(response);
    final List<dynamic> data = response.body['data'] ?? [];
    return data.map((dynamic item) => DeviceModel.fromJson(item)).toList();
  }

  @override
  Future<void> startScan() async {
    final Response response = await _api.post('/scan/start', {});
    _throwIfError(response);
  }

  @override
  Future<void> stopScan() async {
    final Response response = await _api.post('/scan/stop', {});
    _throwIfError(response);
  }

  @override
  Future<void> setPower(bool powered) async {
    final Response response = await _api.post('/adapter/power', {
      'powered': powered,
    });
    _throwIfError(response);
  }

  @override
  Future<void> connect(String path) async {
    final Response response = await _api.post('/devices/connect', {
      'path': path,
    });
    _throwIfError(response);
  }

  @override
  Future<void> disconnect(String path) async {
    final Response response = await _api.post('/devices/disconnect', {
      'path': path,
    });
    _throwIfError(response);
  }

  @override
  Future<void> pair(String path) async {
    final Response response = await _api.post('/devices/pair', {'path': path});
    _throwIfError(response);
  }

  @override
  Future<void> remove(String path) async {
    final Response response = await _api.post('/devices/remove', {
      'path': path,
    });
    _throwIfError(response);
  }

  @override
  Future<void> trust(String path) async {
    final Response response = await _api.post('/devices/trust', {'path': path});
    _throwIfError(response);
  }

  @override
  Future<void> untrust(String path) async {
    final Response response = await _api.post('/devices/untrust', {
      'path': path,
    });
    _throwIfError(response);
  }

  void _throwIfError(Response response) {
    if (response.isOk) {
      return;
    }
    final body = response.body;
    if (body is Map) {
      final error = body['error'];
      final message = body['message'];
      if (error != null && error.toString().trim().isNotEmpty) {
        throw Exception(error.toString());
      }
      if (message != null && message.toString().trim().isNotEmpty) {
        throw Exception(message.toString());
      }
    }

    final statusText = response.statusText;
    if (statusText != null && statusText.trim().isNotEmpty) {
      throw Exception(statusText);
    }
    throw Exception('Request failed with status ${response.statusCode}');
  }
}
