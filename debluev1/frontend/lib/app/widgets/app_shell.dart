import 'package:flutter/material.dart';
import 'package:frontend/app/constants/theme/app_color.dart';
import 'package:frontend/app/controllers/app_controller.dart';
import 'package:frontend/app/routes/app_pages.dart';
import 'package:get/get.dart';

// Cache gradients to avoid recomputation
class _GradientCache {
  static final Map<String, LinearGradient> _cache = {};

  static LinearGradient getMobileGradient(BuildContext context) {
    final key = 'mobile_${Theme.of(context).brightness}';
    return _cache.putIfAbsent(key, () {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (isDark) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            AppColors.darkSurface.withValues(alpha: 0.45),
          ],
        );
      } else {
        // Light mode: Cool gradient with subtle blue tone
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lightBg,
            AppColors.lightSurfaceAlt.withValues(alpha: 0.3),
          ],
        );
      }
    });
  }

  static LinearGradient getDesktopGradient(BuildContext context) {
    final key = 'desktop_${Theme.of(context).brightness}';
    return _cache.putIfAbsent(key, () {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (isDark) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            AppColors.darkSurface.withValues(alpha: 0.58),
          ],
        );
      } else {
        // Light mode: Cool gradient with subtle blue tone
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lightBg,
            AppColors.lightSurfaceAlt.withValues(alpha: 0.45),
          ],
        );
      }
    });
  }
}

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
            drawer: const _MobileDrawer(),
            body: Container(
              decoration: BoxDecoration(
                gradient: _GradientCache.getMobileGradient(context),
              ),
              child: child,
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: _GradientCache.getDesktopGradient(context),
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
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              borderRadius: .circular(18),
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

  void _showAppearanceModal(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Appearance',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned(
                left: offset.dx,
                top: offset.dy + size.height + 8,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: const _AppearancePopover(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutModal(BuildContext context) {
    showDialog(context: context, builder: (context) => const _AboutModal());
  }
}

class _MobileDrawer extends GetView<AppController> {
  const _MobileDrawer();

  @override
  Widget build(BuildContext context) {
    final currentRoute = Get.currentRoute;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const _DrawerBrand(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                children: [
                  _DrawerItem(
                    icon: Icons.bluetooth_rounded,
                    label: 'Devices',
                    active: currentRoute == Routes.HOME,
                    onTap: () {
                      if (Get.currentRoute != Routes.HOME) {
                        Get.offNamed(Routes.HOME);
                      }
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DrawerItem(
                    icon: Icons.palette_rounded,
                    label: 'Appearance',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      _showAppearanceModal(context);
                    },
                    indent: true,
                  ),
                  const SizedBox(height: 4),
                  _DrawerItem(
                    icon: Icons.info_rounded,
                    label: 'About',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutModal(context);
                    },
                    indent: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Obx(() {
                return _ThemeQuickToggle(
                  isDark: controller.isDarkMode,
                  onTap: controller.toggleTheme,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppearanceModal(BuildContext context) {
    Get.bottomSheet(
      BottomSheet(
        onClosing: () {},
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Appearance'),
            toolbarHeight: 80,
            leadingWidth: 100,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: Navigator.of(context).pop,
            ),
          ),
          body: const SingleChildScrollView(
            child: Padding(padding: .all(16), child: _AppearancePopover()),
          ),
        ),
      ),
    );
  }

  void _showAboutModal(BuildContext context) {
    Get.bottomSheet(
      BottomSheet(onClosing: () {}, builder: (context) => _AboutModal()),
    );
    // showModalBottomSheet(
    //   context: context,
    //   isScrollControlled: true,
    //   builder: (context) => const _AboutModal(),
    // );
  }
}

class _DrawerBrand extends StatelessWidget {
  const _DrawerBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                Text('Bluetooth Manager', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
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
              Text('Bluetooth Manager', style: TextStyle(fontSize: 12)),
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
    this.indent = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool indent;

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
          padding: EdgeInsets.symmetric(
            horizontal: indent ? 24 : 14,
            vertical: 13,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: indent ? 18 : 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: indent ? 13 : 14,
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

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.indent = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : null;

    return Material(
      borderRadius: .circular(12),
      color: active
          ? AppColors.green.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: .circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: indent ? 32 : 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: indent ? 18 : 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: indent ? 13 : 14,
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

// Appearance Popover
class _AppearancePopover extends GetView<AppController> {
  const _AppearancePopover();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Material(
        borderRadius: .only(topLeft: .circular(12), topRight: .circular(12)),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            // color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Appearance',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      // Close button only for popover (not in bottom sheet)
                      if (Navigator.canPop(context) &&
                          MediaQuery.of(context).size.width >= 900)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          iconSize: 20,
                          onPressed: Navigator.of(context).pop,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Theme',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ThemeModeSelector(
                    value: controller.themeMode.value,
                    onChanged: controller.setThemeMode,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Device Layout',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LayoutModeSelector(
                    value: controller.layoutMode.value,
                    onChanged: controller.setLayoutMode,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// About Modal
class _AboutModal extends StatelessWidget {
  const _AboutModal();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('About'),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: Navigator.of(context).pop,
          ),
        ),
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
      showSelectedIcon: false,
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
      style: ButtonStyle(
        padding: .all(.symmetric(vertical: 16)),
        iconSize: .all(32),
      ),
      expandedInsets: .all(12),
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
