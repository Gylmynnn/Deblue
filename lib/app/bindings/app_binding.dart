import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../data/services/bluetooth_service.dart';
import '../data/services/bluetooth_event_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AppController>(AppController(), permanent: true);
    Get.put<BluetoothService>(BluetoothService(), permanent: true);
    Get.put<BluetoothEventService>(BluetoothEventService(), permanent: true);
  }
}
