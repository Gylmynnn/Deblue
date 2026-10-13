import 'package:get/get.dart';
import '../../../controllers/app_controller.dart';

class WifiBinding extends Bindings {
  @override
  void dependencies() {
    Get.find<AppController>().setModule(SystemModule.wifi);
  }
}
