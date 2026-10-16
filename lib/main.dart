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
  await GetStorage.init();

  final storage = GetStorage();
  final hideTitleBar =
      storage.read<bool>(AppController.hideTitleBarStorageKey) ?? true;
  final skipTaskbar =
      storage.read<bool>(AppController.skipTaskbarStorageKey) ?? false;

  final windowOptions = WindowOptions(
    titleBarStyle: hideTitleBar ? TitleBarStyle.hidden : TitleBarStyle.normal,
    skipTaskbar: skipTaskbar,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  AppBinding().dependencies();
  runApp(const DeSys());
}

class DeSys extends GetView<AppController> {
  const DeSys({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final accent = controller.accentColor;
      return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DeSys - System Settings',
        initialRoute: Routes.HOME,
        getPages: AppPages.routes,
        theme: AppTheme.light(accent: accent),
        darkTheme: AppTheme.dark(accent: accent),
        themeMode: controller.themeMode.value,
      );
    });
  }
}
