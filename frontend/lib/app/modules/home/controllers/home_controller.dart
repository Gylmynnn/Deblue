import 'dart:async';

import 'package:frontend/app/controllers/app_controller.dart';
import 'package:frontend/app/data/models/adapter_model.dart';
import 'package:frontend/app/data/models/device_model.dart';
import 'package:frontend/app/data/services/bluetooth_event_service.dart';
import 'package:frontend/app/data/services/bluetooth_service.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  final AppController _appController = Get.find<AppController>();
  final BluetoothService _service = Get.find<BluetoothService>();
  final BluetoothEventService _eventService = Get.find<BluetoothEventService>();

  late StreamSubscription? _eventSubscription;
  late Timer? _refreshDebounce;
  final RxBool loading = false.obs;
  final RxBool scanning = false.obs;
  final Rxn<AdapterModel> adapter = Rxn<AdapterModel>();
  final RxList<DeviceModel> devices = <DeviceModel>[].obs;
  final RxSet<String> loadingDevicePaths = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshData();
    _connectEventStream();
  }

  @override
  void onClose() {
    _eventSubscription?.cancel();
    _refreshDebounce?.cancel();
    super.onClose();
  }

  List<DeviceModel> get filteredDevices {
    final query = _appController.searchQuery.value.toLowerCase().trim();
    final filter = _appController.filterMode.value;

    return devices.where((device) {
      final matchesSearch =
          device.name.toLowerCase().contains(query) ||
          device.address.toLowerCase().contains(query);

      final matchesFilter = switch (filter) {
        DeviceFilterMode.all => true,
        DeviceFilterMode.connected => device.connected,
        DeviceFilterMode.paired => device.paired,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _connectEventStream() async {
    await _eventService.connect();
    _eventSubscription = _eventService.events.listen((_) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
        refreshData();
      });
    });
  }

  bool isDeviceLoading(String path) {
    return loadingDevicePaths.contains(path);
  }

  void _setDeviceLoading(String path, bool value) {
    if (value) {
      loadingDevicePaths.add(path);
    } else {
      loadingDevicePaths.remove(path);
    }
  }

  Future<void> _runDeviceAction({
    required DeviceModel device,
    required Future<void> Function() action,
    required String successTitle,
    required String successMessage,
  }) async {
    try {
      _setDeviceLoading(device.path, true);

      await action();
      await refreshData();

      Get.snackbar(
        successTitle,
        successMessage,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _setDeviceLoading(device.path, false);
    }
  }

  Future<void> scan() async {
    var scanStarted = false;
    try {
      scanning.value = true;
      await _service.startScan();
      scanStarted = true;
      await Future.delayed(const Duration(seconds: 4));
      await refreshData();
    } catch (error) {
      Get.snackbar(
        'Scan Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (scanStarted) {
        try {
          await _service.stopScan();
        } catch (_) {}
      }

      scanning.value = false;

      await refreshData();
    }
  }

  Future<void> connect(DeviceModel device) async {
    await _runDeviceAction(
      device: device,
      action: () => _service.connect(device.path),
      successTitle: 'Connected',
      successMessage: '${device.nameOrUnknown} connected',
    );
  }

  Future<void> disconnect(DeviceModel device) async {
    await _runDeviceAction(
      device: device,
      action: () => _service.disconnect(device.path),
      successTitle: 'Disconnected',
      successMessage: '${device.nameOrUnknown} disconnected',
    );
  }

  Future<void> pair(DeviceModel device) async {
    await _runDeviceAction(
      device: device,
      action: () => _service.pair(device.path),
      successTitle: 'Paired',
      successMessage: '${device.nameOrUnknown} paired successfully',
    );
  }

  Future<void> toggleTrust(DeviceModel device) async {
    final willTrust = !device.trusted;

    await _runDeviceAction(
      device: device,
      action: () {
        if (device.trusted) {
          return _service.untrust(device.path);
        }
        return _service.trust(device.path);
      },
      successTitle: willTrust ? 'Trusted' : 'Untrusted',
      successMessage: '${device.nameOrUnknown} updated',
    );
  }

  Future<void> remove(DeviceModel device) async {
    await _runDeviceAction(
      device: device,
      action: () => _service.remove(device.path),
      successTitle: 'Removed',
      successMessage: '${device.nameOrUnknown} removed',
    );
  }

  Future<void> refreshData() async {
    try {
      loading.value = true;
      adapter.value = await _service.getAdapter();
      devices.assignAll(await _service.getDevices());
    } catch (error) {
      Get.snackbar(
        'Backend Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      loading.value = false;
    }
  }

  Future<void> toggleBluetooth() async {
    final current = adapter.value;
    if (current == null) {
      return;
    }
    await _service.setPower(!current.powered);
    await refreshData();
  }
}
