import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/theme/app_color.dart';
import '../../../controllers/app_controller.dart';
import '../../../widgets/settings_ui.dart';

class SettingsContent extends GetView<AppController> {
  const SettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader('Appearance'),
              SettingsCard(
                children: [
                  SettingsRow(
                    title: 'Theme',
                    description:
                        'Choose between light, dark, or follow the system theme.',
                    trailing: Obx(() {
                      return SettingsDropdown<ThemeMode>(
                        value: controller.themeMode.value,
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Light'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Dark'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('System'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) controller.setThemeMode(v);
                        },
                      );
                    }),
                  ),
                  SettingsRow(
                    title: 'List density',
                    description:
                        'Change how compact Bluetooth and WiFi lists are displayed.',
                    trailing: Obx(() {
                      return SettingsDropdown<DeviceLayoutMode>(
                        value: controller.layoutMode.value,
                        items: const [
                          DropdownMenuItem(
                            value: DeviceLayoutMode.grid,
                            child: Text('Comfort'),
                          ),
                          DropdownMenuItem(
                            value: DeviceLayoutMode.tile,
                            child: Text('Cozy'),
                          ),
                          DropdownMenuItem(
                            value: DeviceLayoutMode.compact,
                            child: Text('Compact'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) controller.setLayoutMode(v);
                        },
                      );
                    }),
                  ),
                  SettingsRow(
                    title: 'Accent color',
                    description:
                        'Pick your Everblush accent used for switches, focus rings, and selections.',
                    trailing: Obx(() {
                      final selected = controller.accent.value;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          for (final a in AppAccent.values)
                            _AccentDot(
                              accent: a,
                              selected: a == selected,
                              onTap: () => controller.setAccent(a),
                            ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
              const SettingsSectionHeader('Window'),
              SettingsCard(
                children: [
                  SettingsRow(
                    title: 'Hide title bar',
                    description:
                        'Hide the native window title bar. Keep the taskbar '
                        'toggle below on to still be able to close the window.',
                    trailing: Obx(() {
                      return SettingsSwitch(
                        value: controller.hideTitleBar.value,
                        onChanged: (value) {
                          controller.setHideTitleBar(value);
                        },
                      );
                    }),
                  ),
                  SettingsRow(
                    title: 'Show in taskbar',
                    description:
                        'Show the app icon in the system taskbar while it is '
                        'running.',
                    trailing: Obx(() {
                      return SettingsSwitch(
                        value: !controller.skipTaskbar.value,
                        onChanged: (value) {
                          controller.setSkipTaskbar(!value);
                        },
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = accent.color;

    return Tooltip(
      message: accent.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? (isDark ? Colors.white : Colors.black87)
                    : theme.dividerColor,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: _onAccent(color),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// Pick black/white check icon for contrast on the Everblush accent.
  Color _onAccent(Color c) {
    final lum = (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);
    return lum > 0.6 ? Colors.black87 : Colors.white;
  }
}
