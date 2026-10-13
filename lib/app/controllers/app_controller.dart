import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

enum DeviceLayoutMode { grid, tile, compact }

enum DeviceFilterMode { all, connected, paired }

enum SystemModule { bluetooth, wifi }

class AppController extends GetxController {
  static const String _themeKey = 'theme_mode';
  static const String _layoutKey = 'layout_mode';
  static const String _moduleKey = 'module';
  final GetStorage _storage = GetStorage();

  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;
  final Rx<DeviceLayoutMode> layoutMode = DeviceLayoutMode.grid.obs;
  final Rx<SystemModule> selectedModule = SystemModule.bluetooth.obs;
  final RxString searchQuery = ''.obs;
  final RxString debouncedSearchQuery = ''.obs;
  final Rx<DeviceFilterMode> filterMode = DeviceFilterMode.all.obs;
  Worker? _searchDebounce;

  void setSearchQuery(String value) {
    searchQuery.value = value;
  }

  void setFilterMode(DeviceFilterMode mode) {
    filterMode.value = mode;
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  @override
  void onInit() {
    _loadSettings();
    // Debounce search so every keystroke doesn't recompute the device filter
    // (which does O(N) toLowerCase + toList) and rebuild the list twice.
    _searchDebounce = debounce(
      searchQuery,
      (value) => debouncedSearchQuery.value = value.trim().toLowerCase(),
      time: const Duration(milliseconds: 300),
    );
    super.onInit();
  }

  @override
  void onClose() {
    _searchDebounce?.dispose();
    super.onClose();
  }

  void _loadSettings() {
    final String? savedTheme = _storage.read<String>(_themeKey);
    final String? savedLayout = _storage.read<String>(_layoutKey);
    final String? savedModule = _storage.read<String>(_moduleKey);

    themeMode.value = _themeFromString(savedTheme);
    layoutMode.value = _layoutFromString(savedLayout);
    selectedModule.value = _moduleFromString(savedModule);
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
      case 'bluetooth':
      default:
        return SystemModule.bluetooth;
    }
  }
}
