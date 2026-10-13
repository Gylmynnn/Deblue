import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:window_manager/window_manager.dart';

import 'app/bindings/app_binding.dart';
import 'app/constants/theme/app_theme.dart';
import 'app/controllers/app_controller.dart';
import 'app/routes/app_pages.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await GetStorage.init();
  AppBinding().dependencies();
  runApp(const DeSys());
}

class DeSys extends GetView<AppController> {
  const DeSys({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DeSys - System Settings',
        initialRoute: Routes.HOME,
        getPages: AppPages.routes,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: controller.themeMode.value,
      );
    });
  }
}
