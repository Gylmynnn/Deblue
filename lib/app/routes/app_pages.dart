// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/shell/views/shell_view.dart';
import '../modules/wifi/bindings/wifi_binding.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const ShellView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.WIFI,
      page: () => const ShellView(),
      binding: WifiBinding(),
    ),
  ];
}
