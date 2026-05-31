import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsController extends GetxController {
  /// TextEditingController untuk Backend URL
  late TextEditingController backendUrlController;

  @override
  void onInit() {
    super.onInit();
    // Initialize with empty, will be set in view when controller is available
    backendUrlController = TextEditingController();
  }

  @override
  void onClose() {
    // Dispose TextEditingController untuk menghindari memory leak
    backendUrlController.dispose();
    super.onClose();
  }

  /// Set initial backend URL value
  void setInitialUrl(String url) {
    backendUrlController.text = url;
  }
}
