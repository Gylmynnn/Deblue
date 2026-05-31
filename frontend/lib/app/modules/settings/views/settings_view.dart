import 'package:flutter/material.dart';
import 'package:frontend/app/constants/theme/app_color.dart';
import 'package:frontend/app/controllers/app_controller.dart';
import 'package:frontend/app/modules/home/controllers/home_controller.dart';
import 'package:frontend/app/modules/settings/controllers/settings_controller.dart';
import 'package:get/get.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    
    // Set initial URL value
    controller.setInitialUrl(appController.backendUrl.value);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 700;
            final maxWidth = isCompact ? double.infinity : 760.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.all(isCompact ? 14 : 24),
                  children: [
                    _SettingsSection(
                      title: 'Appearance',
                      children: [
                        Obx(() {
                          return _ThemeModeSelector(
                            value: appController.themeMode.value,
                            onChanged: appController.setThemeMode,
                          );
                        }),
                        const SizedBox(height: 14),
                        Obx(() {
                          return _LayoutModeSelector(
                            value: appController.layoutMode.value,
                            onChanged: appController.setLayoutMode,
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'Backend',
                      children: [
                        TextField(
                          controller: controller.backendUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Backend URL',
                            hintText: 'http://127.0.0.1:8787',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) async {
                            await appController.setBackendUrl(value);

                            Get.snackbar(
                              'Saved',
                              'Backend URL updated',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await appController.setBackendUrl(
                                    controller.backendUrlController.text,
                                  );

                                  Get.snackbar(
                                    'Saved',
                                    'Backend URL updated',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                },
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('Save Backend URL'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              onPressed: () {
                                Get.find<HomeController>().refreshData();
                              },
                              icon: const Icon(Icons.wifi_find_rounded),
                              tooltip: 'Test connection',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'About',
                      children: const [
                        ListTile(
                          leading: Icon(
                            Icons.bluetooth_rounded,
                            color: AppColors.green,
                          ),
                          title: Text('Bluetooth Manager'),
                          subtitle: Text(
                            'Flutter + GetX frontend with Go BlueZ backend.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_rounded),
          label: Text('Dark'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_rounded),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.computer_rounded),
          label: Text('System'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (values) {
        onChanged(values.first);
      },
    );
  }
}

class _LayoutModeSelector extends StatelessWidget {
  const _LayoutModeSelector({required this.value, required this.onChanged});

  final DeviceLayoutMode value;
  final ValueChanged<DeviceLayoutMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DeviceLayoutMode>(
      segments: const [
        ButtonSegment(
          value: DeviceLayoutMode.grid,
          icon: Icon(Icons.grid_view_rounded),
          label: Text('Grid'),
        ),
        ButtonSegment(
          value: DeviceLayoutMode.tile,
          icon: Icon(Icons.view_agenda_rounded),
          label: Text('Tile'),
        ),
        ButtonSegment(
          value: DeviceLayoutMode.compact,
          icon: Icon(Icons.view_headline_rounded),
          label: Text('Compact'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (values) {
        onChanged(values.first);
      },
    );
  }
}
