import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/theme/app_color.dart';
import '../controllers/app_controller.dart';

class AppShell extends GetView<AppController> {
  const AppShell({
    super.key,
    required this.child,
    required this.title,
    this.actions = const [],
  });

  final Widget child;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (!isDesktop) {
          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                ...actions,
                IconButton(
                  icon: Obx(() {
                    return Icon(
                      controller.isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    );
                  }),
                  onPressed: controller.toggleTheme,
                  tooltip: 'Toggle theme',
                ),
              ],
            ),
            body: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child,
            ),
          );
        }

        return Scaffold(
          body: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Row(
                children: [
                  const _Sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _DesktopTopBar(title: title, actions: actions),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

class _Sidebar extends GetView<AppController> {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SidebarBrand(),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.65),
            ),
            child: Obx(() {
              return _LayoutModeSelector(
                value: controller.layoutMode.value,
                onChanged: controller.setLayoutMode,
              );
            }),
          ),
          const SizedBox(height: 12),
          Obx(() {
            return _ThemeQuickToggle(
              isDark: controller.isDarkMode,
              onTap: controller.toggleTheme,
            );
          }),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.bluetooth_audio_rounded,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deblue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text('Bluetooth Manager (v2 Rust)', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeQuickToggle extends StatelessWidget {
  const _ThemeQuickToggle({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: isDark ? AppColors.purple : AppColors.yellow,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isDark ? 'Dark mode' : 'Light mode',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
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
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16)),
        iconSize: WidgetStatePropertyAll(32),
      ),
      expandedInsets: const EdgeInsets.all(12),
      showSelectedIcon: false,
      multiSelectionEnabled: false,
      emptySelectionAllowed: false,
      segments: const [
        ButtonSegment(
          value: DeviceLayoutMode.grid,
          icon: Icon(Icons.grid_view_rounded),
          tooltip: 'Grid',
        ),
        ButtonSegment(
          value: DeviceLayoutMode.tile,
          icon: Icon(Icons.view_agenda_rounded),
          tooltip: 'Tile',
        ),
        ButtonSegment(
          value: DeviceLayoutMode.compact,
          icon: Icon(Icons.view_headline_rounded),
          tooltip: 'Compact',
        ),
      ],
      selected: {value},
      onSelectionChanged: (values) {
        onChanged(values.first);
      },
    );
  }
}
