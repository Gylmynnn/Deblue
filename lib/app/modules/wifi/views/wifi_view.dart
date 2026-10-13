import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/theme/app_color.dart';
import '../../../controllers/app_controller.dart';
import '../../../data/models/wifi_network_model.dart';
import '../controllers/wifi_controller.dart';

class WifiContent extends GetView<WifiController> {
  const WifiContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Prompt for a password (to create a per-adapter profile) when the
    // saved profile is locked to another adapter.
    controller.onBoundProfile ??= (network, boundTo) {
      Get.dialog(_PasswordDialog(network: network, boundTo: boundTo));
    };
    return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = width < 700;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 14 : 24,
                isCompact ? 14 : 0,
                isCompact ? 14 : 24,
                isCompact ? 14 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WifiHeaderCard(isCompact: isCompact),
                  const SizedBox(height: 14),
                  const _AdapterBar(),
                  const SizedBox(height: 14),
                  _WifiSearchBar(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Networks',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 10),
                      Obx(() {
                        final total = controller.filteredNetworks.length;
                        return _StatusChip(
                          label: '$total found',
                          active: total > 0,
                        );
                      }),
                      const SizedBox(width: 8),
                      Obx(() {
                        final active = controller.activeNetwork;
                        if (active == null) return const SizedBox.shrink();
                        return _StatusChip(
                          label: 'Connected: ${active.ssid}',
                          active: true,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _NetworkList(isCompact: isCompact)),
                ],
              ),
            );
          },
        ),
      );
  }
}

class _AdapterBar extends GetView<WifiController> {
  const _AdapterBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final devices = controller.devices;
      if (devices.isEmpty) return const SizedBox.shrink();

      final selected = controller.selectedDevice.value;
      final value = devices.any((d) => d.iface == selected) ? selected : null;

      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.router_rounded),
              const SizedBox(width: 12),
              const Text(
                'Adapter',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    hint: const Text('Select adapter'),
                    isExpanded: true,
                    items: [
                      for (final dev in devices)
                        DropdownMenuItem(
                          value: dev.iface,
                          child: Text(
                            dev.displayLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (iface) {
                      if (iface != null) controller.setDevice(iface);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _WifiSearchBar extends GetView<WifiController> {  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          onChanged: (value) => controller.searchQuery.value = value,
          decoration: InputDecoration(
            hintText: 'Search network...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _WifiHeaderCard extends GetView<WifiController> {
  const _WifiHeaderCard({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.status.value;
      final enabled = status?.enabled ?? false;
      final connected = status?.connected ?? false;
      final scanning = controller.scanning.value;

      final subtitle = !enabled
          ? 'WiFi is disabled'
          : connected
          ? 'Connected to ${status!.activeSsid} (${status.activeSignal}%)'
          : 'Not connected';

      return Card(
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 16 : 22),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderMainInfo(
                      enabled: enabled,
                      connected: connected,
                      subtitle: subtitle,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              enabled ? 'WiFi On' : 'WiFi Off',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Switch(
                            value: enabled,
                            onChanged: (_) => controller.toggleWifi(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatusChip(
                          label: enabled ? 'Enabled' : 'Disabled',
                          active: enabled,
                        ),
                        FilledButton.icon(
                          onPressed: scanning || !enabled
                              ? null
                              : controller.rescan,
                          icon: scanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.radar_rounded),
                          label: Text(scanning ? 'Scanning' : 'Scan'),
                        ),
                        if (connected)
                          OutlinedButton.icon(
                            onPressed: controller.disconnectActive,
                            icon: const Icon(Icons.link_off_rounded),
                            label: const Text('Disconnect'),
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _HeaderMainInfo(
                        enabled: enabled,
                        connected: connected,
                        subtitle: subtitle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (connected)
                      OutlinedButton.icon(
                        onPressed: controller.disconnectActive,
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Disconnect'),
                      ),
                    if (connected) const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: scanning || !enabled
                          ? null
                          : controller.rescan,
                      icon: scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.radar_rounded),
                      label: Text(scanning ? 'Scanning' : 'Scan'),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: enabled,
                      onChanged: (_) => controller.toggleWifi(),
                    ),
                  ],
                ),
        ),
      );
    });
  }
}

class _HeaderMainInfo extends StatelessWidget {
  const _HeaderMainInfo({
    required this.enabled,
    required this.connected,
    required this.subtitle,
  });

  final bool enabled;
  final bool connected;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.red
        : connected
        ? AppColors.green
        : AppColors.blue;

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            !enabled
                ? Icons.wifi_off_rounded
                : connected
                ? Icons.wifi_rounded
                : Icons.wifi_find_rounded,
            color: color,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WiFi Manager',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                !enabled
                    ? 'WiFi Off'
                    : connected
                    ? 'Connected'
                    : 'Available Networks',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkList extends GetView<WifiController> {
  const _NetworkList({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    return Obx(() {
      if (controller.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final networks = controller.filteredNetworks;

      if (networks.isEmpty) {
        return const _EmptyNetworksState();
      }

      final layoutMode = appController.layoutMode.value;

      if (layoutMode == DeviceLayoutMode.compact) {
        return ListView.separated(
          itemCount: networks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            return _WifiCompactTile(
              key: ValueKey(networks[index].ssid),
              network: networks[index],
            );
          },
        );
      }

      if (layoutMode == DeviceLayoutMode.tile || isCompact) {
        return ListView.separated(
          itemCount: networks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            return _WifiTile(
              key: ValueKey(networks[index].ssid),
              network: networks[index],
            );
          },
        );
      }

      return GridView.builder(
        itemCount: networks.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(MediaQuery.sizeOf(context).width),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 190,
        ),
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          return _WifiGridCard(
            key: ValueKey(networks[index].ssid),
            network: networks[index],
          );
        },
      );
    });
  }

  int _getCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}

class _EmptyNetworksState extends GetView<WifiController> {
  const _EmptyNetworksState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.wifi_find_rounded,
                    color: AppColors.blue,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No networks found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try scanning again or move closer to the access point.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: controller.rescan,
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('Scan networks'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _signalIcon(int signal) {
  if (signal >= 80) return Icons.signal_wifi_4_bar_rounded;
  if (signal >= 60) return Icons.signal_wifi_4_bar_rounded;
  if (signal >= 40) return Icons.network_wifi_3_bar_rounded;
  if (signal >= 20) return Icons.network_wifi_2_bar_rounded;
  return Icons.network_wifi_1_bar_rounded;
}

class _WifiTile extends GetView<WifiController> {
  const _WifiTile({super.key, required this.network});

  final WifiNetworkModel network;

  @override
  Widget build(BuildContext context) {
    final bool inUse = network.inUse;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: inUse
              ? AppColors.green.withValues(alpha: 0.65)
              : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: inUse ? 1.4 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          _signalIcon(network.signal),
          color: inUse ? AppColors.green : AppColors.blue,
          size: 28,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                network.ssid,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (network.isSecured)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.lock_rounded, size: 14),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${network.signal}%'),
              Text('• ${network.security}'),
              if (network.band.isNotEmpty) Text('• ${network.band}'),
              if (network.saved) const Text('• Saved'),
              if (inUse) const Text('• Connected'),
            ],
          ),
        ),
        trailing: Obx(() {
          final busy = controller.isBusy(network.ssid);
          if (busy) {
            return const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (inUse)
                FilledButton(
                  onPressed: controller.disconnectActive,
                  child: const Text('Disconnect'),
                )
              else
                FilledButton(
                  onPressed: () => _onConnect(context),
                  child: const Text('Connect'),
                ),
              if (network.saved && !inUse) ...[
                const SizedBox(width: 4),
                _NetworkActionMenu(network: network),
              ],
            ],
          );
        }),
      ),
    );
  }

  void _onConnect(BuildContext context) {
    // Saved profiles and open networks connect directly; secured new
    // networks need a password first.
    if (network.saved || network.isOpen) {
      controller.connect(network);
      return;
    }
    Get.dialog(_PasswordDialog(network: network));
  }
}

class _WifiGridCard extends GetView<WifiController> {
  const _WifiGridCard({super.key, required this.network});

  final WifiNetworkModel network;

  @override
  Widget build(BuildContext context) {
    final bool inUse = network.inUse;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: inUse
              ? AppColors.green.withValues(alpha: 0.65)
              : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: inUse ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _signalIcon(network.signal),
                  color: inUse ? AppColors.green : AppColors.blue,
                  size: 26,
                ),
                if (network.isSecured)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.lock_rounded, size: 14),
                  ),
                const Spacer(),
                if (network.saved && !inUse)
                  _NetworkActionMenu(network: network),
              ],
            ),
            const Spacer(),
            Text(
              network.ssid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              inUse
                  ? 'Connected • ${network.signal}%'
                  : '${network.security}'
                      '${network.band.isNotEmpty ? ' • ${network.band}' : ''}',
            ),
            const SizedBox(height: 12),
            Obx(() {
              final busy = controller.isBusy(network.ssid);
              return SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () {
                          if (inUse) {
                            controller.disconnectActive();
                          } else if (network.saved || network.isOpen) {
                            controller.connect(network);
                          } else {
                            Get.dialog(_PasswordDialog(network: network));
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(inUse ? 'Disconnect' : 'Connect'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WifiCompactTile extends GetView<WifiController> {
  const _WifiCompactTile({super.key, required this.network});

  final WifiNetworkModel network;

  @override
  Widget build(BuildContext context) {
    final bool inUse = network.inUse;
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
          _signalIcon(network.signal),
          color: inUse ? AppColors.green : AppColors.cyan,
        ),
        title: Text(
          network.ssid,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${network.signal}% • ${network.security}'
          '${network.band.isNotEmpty ? ' • ${network.band}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Obx(() {
          final busy = controller.isBusy(network.ssid);
          if (busy) {
            return const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  if (inUse) {
                    controller.disconnectActive();
                  } else if (network.saved || network.isOpen) {
                    controller.connect(network);
                  } else {
                    Get.dialog(_PasswordDialog(network: network));
                  }
                },
                icon: Icon(
                  inUse ? Icons.link_off_rounded : Icons.link_rounded,
                ),
                tooltip: inUse ? 'Disconnect' : 'Connect',
              ),
              if (network.saved && !inUse)
                _NetworkActionMenu(network: network),
            ],
          );
        }),
      ),
    );
  }
}

class _NetworkActionMenu extends GetView<WifiController> {
  const _NetworkActionMenu({required this.network});
  final WifiNetworkModel network;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Network actions',
      onSelected: (value) async {
        if (value == 'forget') _showForgetDialog(context);
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: 'forget',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.red),
              title: Text('Forget'),
            ),
          ),
        ];
      },
    );
  }

  void _showForgetDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Forget network?'),
        content: Text('Remove saved network ${network.ssid}?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Get.back();
              await controller.forget(network);
            },
            child: const Text('Forget'),
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends GetView<WifiController> {
  const _PasswordDialog({required this.network, this.boundTo});

  final WifiNetworkModel network;

  /// Set when the saved profile is locked to another adapter: the typed
  /// password creates a new profile for the selected adapter instead.
  final String? boundTo;

  @override
  Widget build(BuildContext context) {
    final passwordController = TextEditingController();
    final obscure = true.obs;

    return AlertDialog(
      title: Text('Connect to ${network.ssid}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${network.security} • ${network.signal}%'
            '${network.band.isNotEmpty ? ' • ${network.band}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (boundTo != null) ...[
            const SizedBox(height: 8),
            Text(
              'Saved profile is locked to $boundTo. Enter the password to create a profile for ${controller.selectedDevice.value}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Obx(() {
            return TextField(
              controller: passwordController,
              obscureText: obscure.value,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure.value
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => obscure.value = !obscure.value,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _submit(passwordController.text),
            );
          }),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        FilledButton(
          onPressed: () => _submit(passwordController.text),
          child: const Text('Connect'),
        ),
      ],
    );
  }

  void _submit(String password) {
    if (password.isEmpty) return;
    Get.back();
    controller.connect(network, password: password);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: (active ? AppColors.greenLight : AppColors.darkSurfaceAlt)
            .withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
