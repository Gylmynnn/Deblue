import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../models/bluetooth_event_model.dart';

class BluetoothEventService extends GetxService {
  final AppController _appController = Get.find<AppController>();
  final RxBool connected = false.obs;
  WebSocket? _socket;
  StreamSubscription? _subscription;
  Worker? _backendUrlWorker;

  final StreamController<BluetoothEventModel> _eventController =
      StreamController<BluetoothEventModel>.broadcast();

  Stream<BluetoothEventModel> get events => _eventController.stream;

  bool get isConnected => _socket != null;

  Future<void> connect() async {
    if (_socket != null) {
      return;
    }

    try {
      final wsUrl = _buildWebSocketUrl(_appController.backendUrl.value);
      _socket = await WebSocket.connect(wsUrl);
      connected.value = true;
      _subscription = _socket?.listen(
        _handleMessage,
        onError: (_) {
          _cleanup();
          _reconnectLater();
        },
        onDone: () {
          _cleanup();
          _reconnectLater();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _cleanup();
      _reconnectLater();
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _socket?.close();
    _cleanup();
  }

  void _handleMessage(dynamic message) {
    if (message is! String) {
      return;
    }
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final event = BluetoothEventModel.fromJson(decoded);
    _eventController.add(event);
  }

  void _cleanup() {
    _subscription = null;
    _socket = null;
    connected.value = false;
  }

  void _reconnectLater() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_socket == null) {
        connect();
      }
    });
  }

  String _buildWebSocketUrl(String backendUrl) {
    final uri = Uri.parse(backendUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/events',
    ).toString();
  }

  @override
  void onInit() {
    super.onInit();
    _backendUrlWorker = ever<String>(_appController.backendUrl, (_) async {
      await disconnect();
      await connect();
    });
  }

  @override
  void onClose() {
    _backendUrlWorker?.dispose();
    disconnect();
    _eventController.close();
    super.onClose();
  }
}
