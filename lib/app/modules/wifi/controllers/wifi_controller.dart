import 'dart:async';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/models/wifi_device_model.dart';
import '../../../data/models/wifi_network_model.dart';
import '../../../data/models/wifi_status_model.dart';
import '../../../data/services/wifi_event_service.dart';
import '../../../data/services/wifi_service.dart';

class WifiController extends GetxController {
  final WifiService _service = Get.find<WifiService>();
  final WifiEventService _eventService = Get.find<WifiEventService>();
  final GetStorage _storage = GetStorage();

  static const String _deviceKey = 'wifi_device';

  StreamSubscription? _eventSubscription;
  Timer? _refreshDebounce;
  bool _refreshing = false;
  bool _refreshQueued = false;

  final RxBool loading = false.obs;
  final RxBool scanning = false.obs;
  final Rxn<WifiStatusModel> status = Rxn<WifiStatusModel>();
  final RxList<WifiNetworkModel> networks = <WifiNetworkModel>[].obs;
  final RxList<WifiDeviceModel> devices = <WifiDeviceModel>[].obs;
  final RxString selectedDevice = ''.obs;
  final RxSet<String> busySsids = <String>{}.obs;

  /// Hook set by the view to prompt for a password when the saved profile
  /// is locked to another adapter (avoids a view import cycle).
  void Function(WifiNetworkModel network, String boundTo)? onBoundProfile;

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
    selectedDevice.value = _storage.read<String>(_deviceKey) ?? '';
    await refreshData();
    _connectEventStream();
  }

  List<WifiNetworkModel> get filteredNetworks {
    return networks.toList();
  }

  WifiNetworkModel? get activeNetwork {
    return networks.firstWhereOrNull((net) => net.inUse);
  }

  Future<void> setDevice(String iface) async {
    selectedDevice.value = iface;
    await _storage.write(_deviceKey, iface);
    await refreshData();
  }

  void _reconcileSelection() {
    final known = devices.map((d) => d.iface).toSet();
    if (selectedDevice.value.isNotEmpty &&
        known.contains(selectedDevice.value)) {
      return;
    }
    // Saved adapter unplugged (or first run): prefer the connected one,
    // otherwise the first available.
    final connected =
        devices.firstWhereOrNull((d) => d.connected)?.iface ?? '';
    final next = connected.isNotEmpty
        ? connected
        : (devices.isNotEmpty ? devices.first.iface : '');
    selectedDevice.value = next;
    _storage.write(_deviceKey, next);
  }

  Future<void> _connectEventStream() async {
    await _eventService.connect();
    _eventSubscription = _eventService.events.listen((_) {
      _refreshDebounce?.cancel();
      // NM PropertiesChanged can burst during scans/strength updates;
      // the Rust side already throttles per-path to 800ms.
      _refreshDebounce = Timer(const Duration(milliseconds: 1000), () {
        refreshData(silent: true);
      });
    });
  }

  bool isBusy(String ssid) => busySsids.contains(ssid);

  void _setBusy(String ssid, bool value) {
    if (value) {
      busySsids.add(ssid);
    } else {
      busySsids.remove(ssid);
    }
  }

  Future<void> _runNetworkAction({
    required String ssid,
    required Future<void> Function() action,
    required String successTitle,
    required String successMessage,
  }) async {
    try {
      _setBusy(ssid, true);
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
      _setBusy(ssid, false);
    }
  }

  Future<void> rescan() async {
    var scanRequested = false;
    try {
      scanning.value = true;
      await _service.requestScan();
      scanRequested = true;
      // A full multi-band scan takes a while and APs trickle in over
      // several seconds; poll so 5 GHz results are not missed.
      // (The event stream also triggers silent refreshes meanwhile.)
      for (var i = 0; i < 6; i++) {
        await Future.delayed(const Duration(seconds: 2));
        await refreshData(silent: true);
      }
    } catch (error) {
      Get.snackbar(
        'Scan Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      scanning.value = false;
      if (scanRequested) await refreshData();
    }
  }

  Future<void> connect(WifiNetworkModel network, {String password = ''}) async {
    if (network.inUse) return;
    // An explicitly typed password (or a never-saved network) always goes
    // through profile creation on the selected adapter.
    if (password.isNotEmpty || !network.saved) {
      await _connectWithPassword(network, password);
      return;
    }
    // Saved profile: activate it on the selected adapter — but never let a
    // profile locked to another adapter hijack the connection there.
    try {
      _setBusy(network.ssid, true);
      await _service.connectSaved(network.ssid, selectedDevice.value);
      await refreshData();
      Get.snackbar(
        'Connected',
        'Connected to ${network.ssid}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      final boundTo = _parseBoundError(error.toString());
      if (boundTo == null) {
        Get.snackbar(
          'Error',
          error.toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
      } else if (network.isOpen) {
        // Create a portable open profile on the selected adapter.
        await _connectWithPassword(network, '');
      } else {
        // Ask for the password to create a profile for this adapter.
        _setBusy(network.ssid, false);
        onBoundProfile?.call(network, boundTo);
        if (onBoundProfile == null) {
          Get.snackbar(
            'Profile bound elsewhere',
            '${network.ssid} is saved for $boundTo, not ${selectedDevice.value}',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }
    } finally {
      _setBusy(network.ssid, false);
    }
  }

  /// Parses Rust's `PROFILE_BOUND_TO:<iface,...>:<ssid>` error.
  /// Returns the bound interface list, or null when unrelated.
  String? _parseBoundError(String message) {
    const marker = 'PROFILE_BOUND_TO:';
    final idx = message.indexOf(marker);
    if (idx < 0) return null;
    final rest = message.substring(idx + marker.length);
    final sep = rest.lastIndexOf(':');
    if (sep <= 0) return null;
    return rest.substring(0, sep);
  }

  Future<void> _connectWithPassword(
    WifiNetworkModel network,
    String password,
  ) async {
    await _runNetworkAction(
      ssid: network.ssid,
      action: () =>
          _service.connectNew(network.ssid, password, selectedDevice.value),
      successTitle: 'Connected',
      successMessage: 'Connected to ${network.ssid}',
    );
  }

  Future<void> disconnectActive() async {
    final active = status.value;
    final ssid = active?.activeSsid ?? '';
    try {
      if (ssid.isNotEmpty) _setBusy(ssid, true);
      await _service.disconnect(selectedDevice.value);
      await refreshData();
      Get.snackbar(
        'Disconnected',
        'WiFi disconnected',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (ssid.isNotEmpty) _setBusy(ssid, false);
    }
  }

  Future<void> forget(WifiNetworkModel network) async {
    try {
      _setBusy(network.ssid, true);
      final count = await _service.forget(network.ssid);
      await refreshData();
      Get.snackbar(
        'Forgotten',
        count > 1
            ? 'Removed $count saved profiles for ${network.ssid}'
            : 'Removed saved network ${network.ssid}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _setBusy(network.ssid, false);
    }
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
      // Devices first: the selection may need reconciling (adapter
      // unplugged) before querying status/networks for it.
      devices.assignAll(await _service.getDevices());
      _reconcileSelection();
      final device = selectedDevice.value;
      // Parallelize the two FFI round-trips instead of sequential awaits.
      final results = await Future.wait([
        _service.getStatus(device),
        _service.getNetworks(device),
      ]);
      status.value = results[0] as WifiStatusModel?;
      networks.assignAll(results[1] as List<WifiNetworkModel>);
    } catch (error) {
      Get.snackbar(
        'WiFi Error',
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

  Future<void> toggleWifi() async {
    final current = status.value;
    if (current == null) return;
    try {
      await _service.setEnabled(!current.enabled);
      await refreshData();
      Get.snackbar(
        'WiFi Updated',
        !current.enabled ? 'WiFi enabled' : 'WiFi disabled',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'WiFi Error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      loading.value = false;
    }
  }
}
