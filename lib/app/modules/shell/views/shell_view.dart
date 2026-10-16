import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/app_controller.dart';
import '../../../widgets/app_shell.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/views/home_view.dart';
import '../../settings/views/settings_view.dart';
import '../../sound/controllers/sound_controller.dart';
import '../../sound/views/sound_view.dart';
import '../../wifi/controllers/wifi_controller.dart';
import '../../wifi/views/wifi_view.dart';

/// Root shell: sidebar tabs switch modules through an [IndexedStack], so
/// switching between modules never reloads state (lists, scroll
/// positions and event subscriptions stay alive — unlike route navigation
/// which disposes and rebuilds everything).
class ShellView extends GetView<AppController> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    // Controllers are permanent (see AppBinding); just resolve them here.
    final homeController = Get.find<HomeController>();
    final wifiController = Get.find<WifiController>();
    final soundController = Get.find<SoundController>();

    return Obx(() {
      final module = controller.selectedModule.value;

      return AppShell(
        title: switch (module) {
          SystemModule.bluetooth => 'Bluetooth',
          SystemModule.wifi => 'WiFi',
          SystemModule.sound => 'Sound',
          SystemModule.settings => 'Settings',
        },
        actions: switch (module) {
          SystemModule.bluetooth => [
            IconButton(
              onPressed: homeController.refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              tooltip: 'Refresh',
            ),
          ],
          SystemModule.wifi => [
            IconButton(
              onPressed: wifiController.refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              tooltip: 'Refresh',
            ),
          ],
          SystemModule.sound => [
            IconButton(
              onPressed: soundController.refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              tooltip: 'Refresh',
            ),
          ],
          SystemModule.settings => const [],
        },
        child: IndexedStack(
          index: module.index,
          children: const [
            HomeContent(),
            WifiContent(),
            SoundContent(),
            SettingsContent()
          ],
        ),
      );
    });
  }
}
