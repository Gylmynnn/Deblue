import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';

/// Obsidian-style shell:
/// left = slim sidebar with search + grouped nav,
/// right = simple content column with thin divider.
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
        final isDesktop = constraints.maxWidth >= 800;

        if (!isDesktop) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                ...actions,
                IconButton(
                  icon: Obx(() {
                    return Icon(
                      controller.isDarkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 20,
                    );
                  }),
                  onPressed: controller.toggleTheme,
                  tooltip: 'Toggle theme',
                ),
              ],
            ),
            drawer: const Drawer(child: SafeArea(child: _SidebarBody())),
            body: child,
          );
        }

        final theme = Theme.of(context);
        return Scaffold(
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 250,
                  child: _SidebarBody(),
                ),
                Container(
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _SlimTopBar(title: title, actions: actions),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlimTopBar extends StatelessWidget {
  const _SlimTopBar({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// Shared body used in desktop sidebar and mobile drawer.
class _SidebarBody extends GetView<AppController> {
  const _SidebarBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: [
        // Search like "Search settings..." in the reference.
        TextField(
          onChanged: controller.setSearchQuery,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Search settings...',
            prefixIcon: Icon(Icons.search_rounded, size: 18),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _GroupLabel('Options'),
        const SizedBox(height: 4),
        const _SidebarNav(),
        const SizedBox(height: 16),
        _GroupLabel('Appearance'),
        const SizedBox(height: 4),
        Obx(() {
          final isDark = controller.isDarkMode;
          return _NavItem(
            icon: isDark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            label: isDark ? 'Dark mode' : 'Light mode',
            selected: false,
            trailingWidget: Switch(
              value: isDark,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => controller.toggleTheme(),
            ),
            onTap: controller.toggleTheme,
          );
        }),
        const SizedBox(height: 2),
        Obx(() {
          final mode = controller.layoutMode.value;
          return _NavItem(
            icon: Icons.view_list_outlined,
            label: 'List density',
            selected: false,
            trailingText: _layoutLabel(mode),
            onTap: () => _cycleLayout(),
          );
        }),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'DeSys • v1.0.0',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String _layoutLabel(DeviceLayoutMode mode) {
    switch (mode) {
      case DeviceLayoutMode.grid:
        return 'Comfort';
      case DeviceLayoutMode.tile:
        return 'Cozy';
      case DeviceLayoutMode.compact:
        return 'Compact';
    }
  }

  void _cycleLayout() {
    final current = controller.layoutMode.value;
    final next = switch (current) {
      DeviceLayoutMode.grid => DeviceLayoutMode.tile,
      DeviceLayoutMode.tile => DeviceLayoutMode.compact,
      DeviceLayoutMode.compact => DeviceLayoutMode.grid,
    };
    controller.setLayoutMode(next);
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
      ),
    );
  }
}

class _SidebarNav extends GetView<AppController> {
  const _SidebarNav();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final module = controller.selectedModule.value;
      return Column(
        children: [
          _NavItem(
            icon: Icons.bluetooth_rounded,
            label: 'Bluetooth',
            selected: module == SystemModule.bluetooth,
            onTap: () => _goTo(SystemModule.bluetooth),
          ),
          _NavItem(
            icon: Icons.wifi_rounded,
            label: 'WiFi',
            selected: module == SystemModule.wifi,
            onTap: () => _goTo(SystemModule.wifi),
          ),
          const _NavItem(
            icon: Icons.volume_up_outlined,
            label: 'Sound',
            selected: false,
            enabled: false,
            trailingText: 'Soon',
          ),
        ],
      );
    });
  }

  void _goTo(SystemModule module) {
    controller.setModule(module);
    final ctx = Get.context;
    if (ctx == null) return;
    final scaffold = Scaffold.maybeOf(ctx);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(ctx).pop();
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.enabled = true,
    this.trailingText,
    this.trailingWidget,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final String? trailingText;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBg =
        isDark ? const Color(0xFF333333) : const Color(0xFFE8EAED);

    final fg = enabled
        ? theme.textTheme.bodyLarge?.color
        : theme.textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: fg,
                    ),
                  ),
                ),
                if (trailingWidget != null) trailingWidget!
                else if (trailingText != null)
                  Text(
                    trailingText!,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
