import 'dart:async';
import 'package:get/get.dart';

import '../../../controllers/app_controller.dart';
import '../../../data/models/adapter_model.dart';
import '../../../data/models/device_model.dart';
import '../../../data/services/bluetooth_event_service.dart';
import '../../../data/services/bluetooth_service.dart';

class HomeController extends GetxController {
  final AppController _appController = Get.find<AppController>();
  final BluetoothService _service = Get.find<BluetoothService>();
  final BluetoothEventService _eventService = Get.find<BluetoothEventService>();

  StreamSubscription? _eventSubscription;
  Timer? _refreshDebounce;
  bool _refreshing = false;
  bool _refreshQueued = false;
  final RxBool loading = false.obs;
  final RxBool scanning = false.obs;
  final Rxn<AdapterModel> adapter = Rxn<AdapterModel>();
  final RxList<DeviceModel> devices = <DeviceModel>[].obs;
  final RxSet<String> loadingDevicePaths = <String>{}.obs;
  final Rxn<DeviceModel> selectedDevice = Rxn<DeviceModel>();

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  @override
  void onClose() {
    _eventSubscription?.cancel();
    _refreshDebounce?.cancel();
    // Don't leave the native Rust listener thread + D-Bus match rules alive.
    _eventService.disconnect();
    super.onClose();
  }

  Future<void> _init() async {
    await refreshData();
    _connectEventStream();
  }

  List<DeviceModel> get filteredDevices {
    final filter = _appController.filterMode.value;

    return devices.where((device) {
      final matchesFilter = switch (filter) {
        DeviceFilterMode.all => true,
        DeviceFilterMode.connected => device.connected,
        DeviceFilterMode.paired => device.paired,
      };

      return matchesFilter;
    }).toList();
  }

  void selectDevice(DeviceModel device) {
    final oldPath = selectedDevice.value?.path;
    selectedDevice.value = device;
    // Only rebuild the two affected cards instead of the whole list.
    if (oldPath != null) update(['device_$oldPath']);
    update(['device_${device.path}']);
  }

  void clearSelectedDevice() {
    final oldPath = selectedDevice.value?.path;
    selectedDevice.value = null;
    if (oldPath != null) update(['device_$oldPath']);
  }

  Future<void> _connectEventStream() async {
    await _eventService.connect();
    _eventSubscription = _eventService.events.listen((_) {
      _refreshDebounce?.cancel();
      // 1000ms: BlueZ RSSI PropertiesChanged can burst at tens/sec during
      // discovery; the Rust side already throttles per-path to 800ms.
      _refreshDebounce = Timer(const Duration(milliseconds: 1000), () {
        refreshData(silent: true);
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
    // Targeted rebuild of just this card (GetBuilder id in home_view).
    update(['device_$path']);
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
      await refreshData(silent: true);
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

  Future<void> refreshData({bool silent = false}) async {
    // Coalesce overlapping refreshes (event burst + scan + manual).
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      if (!silent) loading.value = true;
      // Parallelize the two FFI round-trips instead of sequential awaits.
      final results = await Future.wait([
        _service.getAdapter(),
        _service.getDevices(),
      ]);
      adapter.value = results[0] as AdapterModel?;
      final latestDevices = results[1] as List<DeviceModel>;
      devices.assignAll(latestDevices);
      final selected = selectedDevice.value;
      if (selected != null) {
        final updatedSelected = latestDevices.firstWhereOrNull(
          (device) => device.path == selected.path,
        );
        selectedDevice.value = updatedSelected;
      }
    } catch (error) {
      Get.snackbar(
        'Bluetooth Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (!silent) loading.value = false;
      _refreshing = false;
      // Run one coalesced refresh if requests arrived while busy.
      if (_refreshQueued) {
        _refreshQueued = false;
        refreshData(silent: silent);
      }
    }
  }

  Future<void> toggleBluetooth() async {
    final current = adapter.value;
    if (current == null) {
      return;
    }
    try {
      await _service.setPower(!current.powered);
      await refreshData();
      Get.snackbar(
        'Bluetooth Updated',
        !current.powered ? 'Bluetooth enabled' : 'Bluetooth disabled',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'Bluetooth Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      loading.value = false;
    }
  }
}
