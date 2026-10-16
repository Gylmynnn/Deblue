import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/app_controller.dart';
import '../../../data/models/wifi_network_model.dart';
import '../../../widgets/settings_ui.dart';
import '../controllers/wifi_controller.dart';

class WifiContent extends GetView<WifiController> {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    controller.onBoundProfile ??= (network, boundTo) {
      Get.dialog(_PasswordDialog(network: network, boundTo: boundTo));
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                final status = controller.status.value;
                final enabled = status?.enabled ?? false;
                final connected = status?.connected ?? false;
                final scanning = controller.scanning.value;

                final desc = !enabled
                    ? 'Turn this off to prevent the app from checking for networks.'
                    : connected
                    ? 'Connected to ${status!.activeSsid} (${status.activeSignal}%)'
                    : 'Not connected. Turn this on to scan for networks.';

                return SettingsCard(
                  children: [
                    SettingsRow(
                      title: 'Wifi',
                      description: desc,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SettingsButton(
                            label: scanning ? 'Scanning' : 'Scan',
                            enabled: !scanning && enabled,
                            onPressed: scanning || !enabled
                                ? null
                                : controller.rescan,
                          ),
                          const SizedBox(width: 10),
                          SettingsSwitch(
                            value: enabled,
                            onChanged: (_) => controller.toggleWifi(),
                          ),
                        ],
                      ),
                    ),
                    SettingsRow(
                      title: 'Adapter',
                      description: 'Change which wireless adapter is used.',
                      trailing: Obx(() {
                        final devices = controller.devices;
                        if (devices.isEmpty) {
                          return Text(
                            'No adapter',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        }
                        final selected = controller.selectedDevice.value;
                        final value = devices.any((d) => d.iface == selected)
                            ? selected
                            : devices.first.iface;
                        return SettingsDropdown<String>(
                          value: value,
                          items: [
                            for (final dev in devices)
                              DropdownMenuItem(
                                value: dev.iface,
                                child: Text(dev.displayLabel),
                              ),
                          ],
                          onChanged: (iface) {
                            if (iface != null) controller.setDevice(iface);
                          },
                        );
                      }),
                    ),
                    if (connected)
                      SettingsRow(
                        title: 'Connected network',
                        description:
                            'Learn how to manage saved networks and get help.',
                        trailing: SettingsButton(
                          label: 'Disconnect',
                          onPressed: controller.disconnectActive,
                        ),
                      ),
                  ],
                );
              }),
              Obx(() {
                final total = controller.filteredNetworks.length;
                final active = controller.activeNetwork;
                final suffix = total > 0 ? ' • $total found' : '';
                final conn = active != null
                    ? ' • Connected: ${active.ssid}'
                    : '';
                return SettingsSectionHeader('Networks$suffix$conn');
              }),
              _NetworkListCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkListCard extends GetView<WifiController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Subscribe to density so changing it rebuilds the list immediately.
      final density = Get.find<AppController>().layoutMode.value;
      final listPadding = switch (density) {
        DeviceLayoutMode.grid => kComfortListPadding,
        DeviceLayoutMode.tile => kCozyListPadding,
        DeviceLayoutMode.compact => kCompactListPadding,
      };
      if (controller.loading.value) {
        return const SettingsCard(
          children: [
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      }

      final networks = controller.filteredNetworks;
      if (networks.isEmpty) {
        return SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No networks found',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try scanning again or move closer to the access point.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SettingsButton(
                    label: 'Scan networks',
                    onPressed: controller.rescan,
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return SettingsCard(
        children: [
          for (var i = 0; i < networks.length; i++) ...[
            _WifiRow(network: networks[i], contentPadding: listPadding),
            if (i != networks.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
          ],
        ],
      );
    });
  }
}

IconData _signalIcon(int signal) {
  if (signal >= 60) return Icons.signal_wifi_4_bar_rounded;
  if (signal >= 40) return Icons.network_wifi_3_bar_rounded;
  if (signal >= 20) return Icons.network_wifi_2_bar_rounded;
  return Icons.network_wifi_1_bar_rounded;
}

class _WifiRow extends GetView<WifiController> {
  const _WifiRow({required this.network, this.contentPadding});
  final WifiNetworkModel network;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final inUse = network.inUse;
    final subtitle =
        '${network.signal}% • ${network.security}${network.band.isNotEmpty ? ' • ${network.band}' : ''}${network.saved ? ' • Saved' : ''}${inUse ? ' • Connected' : ''}';

    return SettingsListTile(
      selected: inUse,
      title: network.ssid.isEmpty ? '(Hidden network)' : network.ssid,
      subtitle: subtitle,
      contentPadding: contentPadding,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _signalIcon(network.signal),
            size: 19,
            color: Theme.of(context).textTheme.bodyMedium?.color
                ?.withValues(alpha: 0.8),
          ),
          if (network.isSecured) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.lock_rounded,
              size: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ],
        ],
      ),
      trailing: Obx(() {
        final busy = controller.isBusy(network.ssid);
        if (busy) {
          return const SizedBox(
            height: kSettingsControlHeight,
            width: 36,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SettingsButton(
              label: inUse ? 'Disconnect' : 'Connect',
              onPressed: () {
                if (inUse) {
                  controller.disconnectActive();
                } else if (network.saved || network.isOpen) {
                  controller.connect(network);
                } else {
                  Get.dialog(_PasswordDialog(network: network));
                }
              },
            ),
            if (network.saved && !inUse) _NetworkActionMenu(network: network),
          ],
        );
      }),
    );
  }
}

class _NetworkActionMenu extends GetView<WifiController> {
  const _NetworkActionMenu({required this.network});
  final WifiNetworkModel network;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSettingsControlHeight,
      width: kSettingsControlHeight,
      child: PopupMenuButton<String>(
        tooltip: 'Network actions',
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 19,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
        onSelected: (value) async {
          if (value == 'forget') _showForgetDialog(context);
        },
        itemBuilder: (context) {
          return const [PopupMenuItem(value: 'forget', child: Text('Forget'))];
        },
      ),
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
                prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => obscure.value = !obscure.value,
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
