import 'package:flutter/material.dart';
import 'package:frontend/app/constants/theme/app_color.dart';
import 'package:frontend/app/controllers/app_controller.dart';
import 'package:frontend/app/routes/app_pages.dart';
import 'package:get/get.dart';

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
            appBar: AppBar(title: Text(title), actions: actions),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: child,
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
                ],
              ),
            ),
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
    final currentRoute = Get.currentRoute;

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
          const SizedBox(height: 26),
          _SidebarItem(
            icon: Icons.bluetooth_rounded,
            label: 'Devices',
            active: currentRoute == Routes.HOME,
            onTap: () {
              if (Get.currentRoute != Routes.HOME) {
                Get.offNamed(Routes.HOME);
              }
            },
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            active: currentRoute == Routes.SETTINGS,
            onTap: () {
              if (Get.currentRoute != Routes.SETTINGS) {
                Get.offNamed(Routes.SETTINGS);
              }
            },
          ),
          const Spacer(),
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
                'Bluetint',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text('Local Bluetooth UI', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : null;

    return Material(
      color: active
          ? AppColors.green.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
