import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../../controllers/app_controller.dart';

class BackendProcessService extends GetxService {
  final AppController _appController = Get.find<AppController>();

  Process? _process;
  static HttpClient? _httpClient;

  final RxBool starting = false.obs;
  final RxBool running = false.obs;
  final RxString errorMessage = ''.obs;

  /// Singleton HttpClient instance untuk menghindari memory leak
  static HttpClient get _getHttpClient {
    _httpClient ??= HttpClient();
    return _httpClient!;
  }

  Future<void> ensureStarted() async {
    if (starting.value) {
      return;
    }

    starting.value = true;
    errorMessage.value = '';

    try {
      final isAlreadyRunning = await _isBackendReady();
      if (isAlreadyRunning) {
        running.value = true;
        return;
      }
      final executablePath = await _prepareBackendBinary();
      _process = await Process.start(
        executablePath,
        [],
        mode: ProcessStartMode.detachedWithStdio,
      );

      _process?.stdout.transform(SystemEncoding().decoder).listen((line) {
        // Optional debug log
        // print('[backend] $line');
      });

      _process?.stderr.transform(SystemEncoding().decoder).listen((line) {
        // Optional debug log
        // print('[backend:error] $line');
      });

      final ready = await _waitUntilReady();

      if (!ready) {
        running.value = false;
        errorMessage.value = 'Backend failed to start';
        return;
      }

      running.value = true;
    } catch (error) {
      running.value = false;
      errorMessage.value = error.toString();
    } finally {
      starting.value = false;
    }
  }

  Future<bool> _waitUntilReady() async {
    for (var i = 0; i < 20; i++) {
      final ready = await _isBackendReady();

      if (ready) {
        return true;
      }

      await Future.delayed(
        const Duration(milliseconds: 250),
      );
    }

    return false;
  }

  Future<bool> _isBackendReady() async {
    try {
      final uri = Uri.parse(
        _appController.backendUrl.value,
      );

      // Use singleton HttpClient instance
      final client = _getHttpClient;

      final request = await client
          .getUrl(uri)
          .timeout(const Duration(milliseconds: 700));

      final response = await request
          .close()
          .timeout(const Duration(milliseconds: 700));

      await response.drain();

      // Don't close singleton client, just keep it for reuse
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<String> _prepareBackendBinary() async {
    final supportDir = Directory(
      path.join(
        Platform.environment['HOME'] ?? Directory.current.path,
        '.local',
        'share',
        'bluetooth-manager',
      ),
    );

    if (!supportDir.existsSync()) {
      supportDir.createSync(recursive: true);
    }

    final targetFile = File(
      path.join(
        supportDir.path,
        'deblue',
      ),
    );

    final byteData = await rootBundle.load(
      'assets/bin/linux/deblue',
    );

    await targetFile.writeAsBytes(
      byteData.buffer.asUint8List(),
      flush: true,
    );

    await Process.run(
      'chmod',
      ['+x', targetFile.path],
    );

    return targetFile.path;
  }

  Future<void> stopOwnedBackend() async {
    _process?.kill();
    _process = null;
    running.value = false;
  }

  @override
  void onClose() {
    // Close singleton HttpClient when service is closed
    _httpClient?.close(force: true);
    _httpClient = null;
    
    // Sengaja tidak kill backend jika ingin backend tetap hidup.
    // Kalau ingin backend mati saat Flutter ditutup, uncomment:
    // stopOwnedBackend();

    super.onClose();
  }
}
