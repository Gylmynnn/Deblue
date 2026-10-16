import 'dart:async';
import 'package:get/get.dart';

import '../../../data/models/sound_device_model.dart';
import '../../../data/models/sound_stream_model.dart';
import '../../../data/services/sound_event_service.dart';
import '../../../data/services/sound_service.dart';

class SoundController extends GetxController {
  final SoundService _service = Get.find<SoundService>();
  final SoundEventService _eventService = Get.find<SoundEventService>();

  StreamSubscription? _eventSubscription;
  Timer? _refreshDebounce;
  bool _refreshing = false;
  bool _refreshQueued = false;

  final RxBool loading = false.obs;
  final RxList<SoundDeviceModel> sinks = <SoundDeviceModel>[].obs;
  final RxList<SoundDeviceModel> sources = <SoundDeviceModel>[].obs;
  final RxList<SoundStreamModel> playback = <SoundStreamModel>[].obs;
  final RxList<SoundStreamModel> recording = <SoundStreamModel>[].obs;
  final RxString defaultSink = ''.obs;
  final RxString defaultSource = ''.obs;

  /// In-progress slider positions (no backend round-trip until release).
  final RxMap<String, double> drafts = <String, double>{}.obs;
  final RxSet<String> busyIds = <String>{}.obs;

  /// Non-monitor inputs — monitors clutter the mixer, real mics first.
  List<SoundDeviceModel> get inputs =>
      sources.where((s) => !s.isMonitor).toList();

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  @override
  void onClose() {
    _eventSubscription?.cancel();
    _refreshDebounce?.cancel();
    _eventService.disconnect();
    super.onClose();
  }

  Future<void> _init() async {
    await refreshData();
    _connectEventStream();
  }

  double volumeFor(String key, int actual) =>
      drafts[key] ?? actual.toDouble();

  void previewVolume(String key, double value) => drafts[key] = value;

  void clearDraft(String key) => drafts.remove(key);

  bool isBusy(String id) => busyIds.contains(id);

  void _setBusy(String id, bool value) {
    if (value) {
      busyIds.add(id);
    } else {
      busyIds.remove(id);
    }
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    try {
      _setBusy(id, true);
      await action();
      await refreshData(silent: true);
    } catch (e) {
      Get.snackbar('Sound Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      _setBusy(id, false);
    }
  }

  Future<void> _connectEventStream() async {
    await _eventService.connect();
    _eventSubscription = _eventService.events.listen((_) {
      _refreshDebounce?.cancel();
      // pactl subscribe bursts on volume drags; coalesce into one refresh.
      _refreshDebounce = Timer(const Duration(milliseconds: 600), () {
        // Drop slider drafts touched by our own writes — server state wins.
        drafts.clear();
        refreshData(silent: true);
      });
    });
  }

  Future<void> refreshData({bool silent = false}) async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      if (!silent) loading.value = true;
      final state = await _service.getState();
      sinks.assignAll(state.sinks);
      sources.assignAll(state.sources);
      playback.assignAll(state.playback);
      recording.assignAll(state.recording);
      defaultSink.value = state.defaultSink;
      defaultSource.value = state.defaultSource;
    } catch (e) {
      Get.snackbar('Sound Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (!silent) loading.value = false;
      _refreshing = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        refreshData(silent: silent);
      }
    }
  }

  Future<void> commitDeviceVolume(
    SoundDeviceModel dev,
    bool isSource,
    double value,
  ) async {
    final pct = value.round().clamp(0, 150);
    clearDraft(_deviceKey(dev, isSource));
    await _run('vol:${dev.name}', () {
      if (isSource) {
        return _service.setSourceVolume(dev.name, pct);
      }
      return _service.setSinkVolume(dev.name, pct);
    });
  }

  Future<void> toggleDeviceMute(SoushQueued) {
        _refreshQueued = false;
        refreshData(silent: silent);
      }
    }
  }

  Future<void> commitDeviceVolume(
    SoundDeviceModel dev,
    bool isSource,
    double value,
  ) async {
    final pct = value.round().clamp(0, 150);
    clearDraft(_deviceKey(dev, isSource));
    await _run('vol:${dev.name}', () {
      if (isSource) {
        return _service.setSourceVolume(dev.name, pct);
      }
      return _service.setSinkVolume(dev.name, pct);
    });
  }

  Future<void> toggleDeviceMute(SoundDeviceModel dev, bool isSource) async {
    await _run('mute:${dev.name}', () {
      if (isSource) {
        return _service.setSourceMute(dev.name, !dev.muted);
      }
      return _service.setSinkMute(dev.name, !dev.muted);
    });
  }

  Future<void> setDefault(SoundDeviceModel dev, bool isSource) async {
    await _run('def:${dev.name}', () {
      if (isSource) {
        return _service.setDefaultSource(dev.name);
      }
      return _service.setDefaultSink(dev.name);
    });
  }

  Future<void> setPort(SoundDeviceModel dev, String port, bool isSource) async {
    await _run('port:${dev.name}', () {
      return _service.setDevicePort(dev.name, port, isSource);
    });
  }

  Future<void> commitStreamVolume(
    SoundStreamModel s,
    bool isPlayback,
    double value,
  ) async {
    final pct = value.round().clamp(0, 150);
    clearDraft(_streamKey(s, isPlayback));
    await _run('svol:${s.index}', () {
      return _service.setStreamVolume(s.index, isPlayback, pct);
    });
  }

  Future<void> toggleStreamMute(SoundStreamModel s, bool isPlayback) async {
    await _run('smute:${s.index}', () {
      return _service.setStreamMute(s.index, isPlayback, !s.muted);
    });
  }

  Future<void> moveStream(
    SoundStreamModel s,
    bool isPlayback,
    String device,
  ) async {
    await _run('smove:${s.index}', () {
      return _service.moveStream(s.index, isPlayback, device);
    });
  }

  String _deviceKey(SoundDeviceModel dev, bool isSource) =>
      '${isSource ? 'src' : 'sink'}:${dev.name}';

  String _streamKey(SoundStreamModel s, bool isPlayback) =>
      '${isPlayback ? 'pb' : 'rec'}:${s.index}';

  String deviceDraftKey(SoundDeviceModel dev, bool isSource) =>
      _deviceKey(dev, isSource);

  String streamDraftKey(SoundStreamModel s, bool isPlayback) =>
      _streamKey(s, isPlayback);
}
