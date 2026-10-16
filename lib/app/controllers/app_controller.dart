import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:window_manager/window_manager.dart';

import '../constants/theme/app_color.dart';

enum DeviceLayoutMode { grid, tile, compact }

enum DeviceFilterMode { all, connected, paired }

enum SystemModule { bluetooth, wifi, sound, settings }

class AppController extends GetxController {
  static const String _themeKey = 'theme_mode';
  static const String _layoutKey = 'layout_mode';
  static const String _moduleKey = 'module';
  static const String _accentKey = 'accent_color';
  static const String hideTitleBarStorageKey = 'hide_title_bar';
  static const String skipTaskbarStorageKey = 'skip_taskbar';
  final GetStorage _storage = GetStorage();

  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;
  final Rx<DeviceLayoutMode> layoutMode = DeviceLayoutMode.grid.obs;
  final Rx<SystemModule> selectedModule = SystemModule.bluetooth.obs;
  final Rx<DeviceFilterMode> filterMode = DeviceFilterMode.all.obs;
  final Rx<AppAccent> accent = AppAccent.blue.obs;
  final RxBool hideTitleBar = true.obs;
  final RxBool skipTaskbar = false.obs;

  void setFilterMode(DeviceFilterMode mode) {
    filterMode.value = mode;
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  @override
  void onInit() {
    _loadSettings();
    super.onInit();
  }

  void _loadSettings() {
    final String? savedTheme = _storage.read<String>(_themeKey);
    final String? savedLayout = _storage.read<String>(_layoutKey);
    final String? savedModule = _storage.read<String>(_moduleKey);
    final String? savedAccent = _storage.read<String>(_accentKey);

    themeMode.value = _themeFromString(savedTheme);
    layoutMode.value = _layoutFromString(savedLayout);
    selectedModule.value = _moduleFromString(savedModule);
    accent.value = AppAccentX.fromString(savedAccent);
    hideTitleBar.value = _storage.read<bool>(hideTitleBarStorageKey) ?? true;
    skipTaskbar.value = _storage.read<bool>(skipTaskbarStorageKey) ?? false;
  }

  Color get accentColor => accent.value.color;

  Future<void> setAccent(AppAccent value) async {
    accent.value = value;
    await _storage.write(_accentKey, value.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _storage.write(_themeKey, _themeToString(mode));
  }

  Future<void> toggleTheme() async {
    final nextMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  Future<void> setLayoutMode(DeviceLayoutMode mode) async {
    layoutMode.value = mode;
    await _storage.write(_layoutKey, mode.name);
  }

  Future<void> setModule(SystemModule module) async {
    selectedModule.value = module;
    await _storage.write(_moduleKey, module.name);
  }

  Future<void> setHideTitleBar(bool value) async {
    hideTitleBar.value = value;
    await _storage.write(hideTitleBarStorageKey, value);
    await windowManager.setTitleBarStyle(
      value ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );
  }

  Future<void> setSkipTaskbar(bool value) async {
    skipTaskbar.value = value;
    await _storage.write(skipTaskbarStorageKey, value);
    await windowManager.setSkipTaskbar(value);
  }

  ThemeMode _themeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  String _themeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  DeviceLayoutMode _layoutFromString(String? value) {
    switch (value) {
      case 'tile':
        return DeviceLayoutMode.tile;
      case 'compact':
        return DeviceLayoutMode.compact;
      case 'grid':
      default:
        return DeviceLayoutMode.grid;
    }
  }

  SystemModule _moduleFromString(String? value) {
    switch (value) {
      case 'wifi':
        return SystemModule.wifi;
      case 'sound':
        return SystemModule.sound;
      case 'settings':
        return SystemModule.settings;
      case 'bluetooth':
      default:
        return SystemModule.bluetooth;
    }
  }
}
