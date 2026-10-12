import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import '../models/bluetooth_event_model.dart';
import '../../../../src/rust/api/bluetooth.dart' as rust_api;

class BluetoothEventService extends GetxService {
  final RxBool connected = false.obs;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  static const int _maxReconnectDelaySec = 30;

  final StreamController<BluetoothEventModel> _eventController =
      StreamController<BluetoothEventModel>.broadcast();

  Stream<BluetoothEventModel> get events => _eventController.stream;

  bool get isConnected => connected.value;

  Future<void> connect() async {
    if (_subscription != null || _disposed) {
      return;
    }

    try {
      final rustStream = rust_api.subscribeBluetoothEvents();
      _subscription = rustStream.listen(
        (event) {
          _reconnectAttempts = 0;
          connected.value = true;
          if (!_eventController.isClosed) {
            _eventController.add(BluetoothEventModel.fromRust(event));
          }
        },
        onError: (_) {
          connected.value = false;
          _subscription = null;
          _scheduleReconnect();
        },
        onDone: () {
          connected.value = false;
          _subscription = null;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
      connected.value = true;
    } catch (_) {
      connected.value = false;
      _subscription = null;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer?.isActive == true) return;
    // Capped exponential backoff with jitter: 1,2,4...30s max.
    final backoff = min(1 << min(_reconnectAttempts, 5), _maxReconnectDelaySec);
    final jitter = Random().nextInt(1000);
    _reconnectAttempts++;
    _reconnectTimer = Timer(
      Duration(seconds: backoff, milliseconds: jitter),
      () {
        if (!_disposed && _subscription == null) connect();
      },
    );
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    await _subscription?.cancel();
    _subscription = null;
    connected.value = false;
  }

  @override
  void onClose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    // Order matters: cancel native subscription before closing the broadcast
    // controller to avoid add-after-close races from in-flight Rust events.
    disconnect().then((_) {
      if (!_eventController.isClosed) _eventController.close();
    });
    super.onClose();
  }
}
