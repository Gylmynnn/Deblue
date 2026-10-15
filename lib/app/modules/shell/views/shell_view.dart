import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/app_controller.dart';
import '../../../widgets/app_shell.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/views/home_view.dart';
import '../../wifi/controllers/wifi_controller.dart';
import '../../wifi/views/wifi_view.dart';

/// Root shell: sidebar tabs switch modules through an [IndexedStack], so
/// switching between Bluetooth and WiFi never reloads state (lists, scroll
/// positions and event subscriptions stay alive — unlike route navigation
/// which disposes and rebuilds everything).
class ShellView extends GetView<AppController> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    // Controllers are permanent (see AppBinding); just resolve them here.
    final homeController = Get.find<HomeController>();
    final wifiController = Get.find<WifiController>();

    return Obx(() {
      final module = controller.selectedModule.value;
      final isWifi = module == SystemModule.wifi;

      return AppShell(
        title: isWifi ? 'WiFi' : 'Bluetooth',
        actions: [
          IconButton(
            onPressed: () {
              if (isWifi) {
                wifiController.refreshData();
              } else {
                homeController.refreshData();
              }
            },
            icon: const Icon(Icons.refresh_rounded, size: 19),
            tooltip: 'Refresh',
          ),
        ],
        child: IndexedStack(
          index: module.index,
          children: const [
            HomeContent(),
            WifiContent(),
          ],
        ),
      );
    });
  }
}
