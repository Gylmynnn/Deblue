import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../data/services/bluetooth_service.dart';
import '../data/services/bluetooth_event_service.dart';
import '../data/services/sound_event_service.dart';
import '../data/services/sound_service.dart';
import '../data/services/wifi_service.dart';
import '../data/services/wifi_event_service.dart';
import '../modules/home/controllers/home_controller.dart';
import '../modules/sound/controllers/sound_controller.dart';
import '../modules/wifi/controllers/wifi_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AppController>(AppController(), permanent: true);
    Get.put<BluetoothService>(BluetoothService(), permanent: true);
    Get.put<BluetoothEventService>(BluetoothEventService(), permanent: true);
    Get.put<WifiService>(WifiService(), permanent: true);
    Get.put<WifiEventService>(WifiEventService(), permanent: true);
    Get.put<SoundService>(SoundService(), permanent: true);
    Get.put<SoundEventService>(SoundEventService(), permanent: true);
    // Module controllers are permanent so switching sidebar tabs never
    // reloads state (scroll position, lists, event subscriptions stay alive).
    Get.put<HomeController>(HomeController(), permanent: true);
    Get.put<WifiController>(WifiController(), permanent: true);
    Get.put<SoundController>(SoundController(), permanent: true);
  }
}
