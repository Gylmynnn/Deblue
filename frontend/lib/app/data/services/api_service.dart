import 'package:get/get.dart';

import '../../controllers/app_controller.dart';

class ApiService extends GetConnect {
  final AppController _appController = Get.find<AppController>();
  @override
  void onInit() {
    httpClient.baseUrl = _appController.backendUrl.value;
    httpClient.timeout = const Duration(seconds: 10);
    ever<String>(_appController.backendUrl, (url) {
      httpClient.baseUrl = url;
    });
    super.onInit();
  }
}
