import 'package:flutter/material.dart';
import 'package:frontend/app/bindings/app_binding.dart';
import 'package:frontend/app/constants/theme/app_theme.dart' show AppTheme;
import 'package:frontend/app/controllers/app_controller.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:window_manager/window_manager.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await GetStorage.init();
  AppBinding().dependencies();
  runApp(const Deblue());
}

class Deblue extends GetView<AppController> {
  const Deblue({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Deblue Bluetooth Manager',
        initialRoute: Routes.HOME,
        getPages: AppPages.routes,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: controller.themeMode.value,
      );
    });
  }
}
