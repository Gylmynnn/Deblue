import 'package:get/get.dart';
import '../../../controllers/app_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.find<AppController>().setModule(SystemModule.bluetooth);
  }
}
