import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

enum DeviceLayoutMode { grid, tile, compact }

enum DeviceFilterMode { all, connected, paired }

class AppController extends GetxController {
  static const String _themeKey = 'theme_mode';
  static const String _layoutKey = 'layout_mode';
  static const String _backendUrlKey = 'backend_url';
  final GetStorage _storage = GetStorage();
  final RxString backendUrl = 'http://127.0.0.1:8787'.obs;
  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;
  final Rx<DeviceLayoutMode> layoutMode = DeviceLayoutMode.grid.obs;
  final RxString searchQuery = ''.obs;
  final Rx<DeviceFilterMode> filterMode = DeviceFilterMode.all.obs;

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
    super.onInit();
  }

  void _loadSettings() {
    final String? savedTheme = _storage.read<String>(_themeKey);
    final String? savedLayout = _storage.read<String>(_layoutKey);
    final savedBackendUrl = _storage.read<String>(_backendUrlKey);

    themeMode.value = _themeFromString(savedTheme);
    layoutMode.value = _layoutFromString(savedLayout);
    if (savedBackendUrl != null && savedBackendUrl.trim().isNotEmpty) {
      backendUrl.value = savedBackendUrl;
    }
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

  Future<void> setBackendUrl(String value) async {
    final url = value.trim();
    if (url.isEmpty) {
      return;
    }
    backendUrl.value = url;
    await _storage.write(_backendUrlKey, url);
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
}
