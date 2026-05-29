import 'package:frontend/app/data/services/api_service.dart';
import 'package:frontend/app/data/services/bluetooth_service.dart';
import 'package:frontend/app/data/services/bluetooth_event_service.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AppController>(AppController(), permanent: true);
    Get.put<ApiService>(ApiService(), permanent: true);
    Get.put<BluetoothService>(BluetoothService(), permanent: true);
    Get.put<BluetoothEventService>(BluetoothEventService(), permanent: true);
  }
}
