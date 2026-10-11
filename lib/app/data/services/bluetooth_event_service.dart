import 'dart:async';
import 'package:get/get.dart';
import '../models/bluetooth_event_model.dart';
import '../../../../src/rust/api/bluetooth.dart' as rust_api;

class BluetoothEventService extends GetxService {
  final RxBool connected = false.obs;
  StreamSubscription? _subscription;

  final StreamController<BluetoothEventModel> _eventController =
      StreamController<BluetoothEventModel>.broadcast();

  Stream<BluetoothEventModel> get events => _eventController.stream;

  bool get isConnected => connected.value;

  Future<void> connect() async {
    if (_subscription != null) {
      return;
    }

    try {
      final rustStream = rust_api.subscribeBluetoothEvents();
      _subscription = rustStream.listen(
        (event) {
          connected.value = true;
          _eventController.add(BluetoothEventModel.fromRust(event));
        },
        onError: (err) {
          connected.value = false;
        },
        onDone: () {
          connected.value = false;
        },
      );
      connected.value = true;
    } catch (_) {
      connected.value = false;
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    connected.value = false;
  }

  @override
  void onClose() {
    disconnect();
    _eventController.close();
    super.onClose();
  }
}
