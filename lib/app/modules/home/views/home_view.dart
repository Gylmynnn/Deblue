import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/app_controller.dart';
import '../../../data/models/device_model.dart';
import '../../../widgets/device_detail_dialog.dart';
import '../../../widgets/device_detail_panel.dart';
import '../../../widgets/settings_ui.dart';
import '../controllers/home_controller.dart';

class HomeContent extends GetView<AppController> {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Obx(() {
          final selected =
              Get.find<HomeController>().selectedDevice.value;
          final showDetail =
              selected != null && constraints.maxWidth >= 1100;

          if (!showDetail) {
            return _SettingsScroll(child: _MainColumn());
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SettingsScroll(child: _MainColumn())),
              Container(
                width: 1,
                color: Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.6),
              ),
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DeviceDetailPanel(device: selected),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class _SettingsScroll extends StatelessWidget {
  const _SettingsScroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: child,
        ),
      ),
    );
  }
}

class _MainColumn extends GetView<AppController> {
  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          final adapter = home.adapter.value;
          final powered = adapter?.powered ?? false;
          final discovering =
              (adapter?.discovering ?? false) || home.scanning.value;
          final scanning = home.scanning.value;

          final statusText = !powered
              ? 'Bluetooth adapter is disabled'
              : discovering
                  ? 'Scanning nearby devices...'
                  : 'Adapter ready${adapter != null ? ' • ${adapter.alias}' : ''}';

          return SettingsCard(
            children: [
              SettingsRow(
                title: 'Bluetooth',
                description: statusText,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsButton(
                      label: scanning ? 'Scanning' : 'Scan',
                      onPressed: scanning || !powered ? null : home.scan,
                      enabled: !scanning && powered,
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: powered,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      onChanged: (_) => home.toggleBluetooth(),
                    ),
                  ],
                ),
              ),
              SettingsRow(
                title: 'Automatic discovery',
                description:
                    'Turn this off to prevent the app from checking for nearby devices.',
                trailing: Switch(
                  value: powered,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (_) => home.toggleBluetooth(),
                ),
              ),
              SettingsRow(
                title: 'Show',
                description: 'Change which devices are listed.',
                trailing: Obx(() {
                  return SettingsDropdown<DeviceFilterMode>(
                    value: controller.filterMode.value,
                    items: const [
                      DropdownMenuItem(
                        value: DeviceFilterMode.all,
                        child: Text('All'),
                      ),
                      DropdownMenuItem(
                        value: DeviceFilterMode.connected,
                        child: Text('Connected'),
                      ),
                      DropdownMenuItem(
                        value: DeviceFilterMode.paired,
                        child: Text('Paired'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.setFilterMode(v);
                    },
                  );
                }),
              ),
            ],
          );
        }),
        Obx(() {
          final total = home.filteredDevices.length;
          return SettingsSectionHeader(
              'Devices${total > 0 ? ' • $total found' : ''}');
        }),
        _DeviceListCard(),
      ],
    );
  }
}

class _DeviceListCard extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
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

      final devices = controller.filteredDevices;
      if (devices.isEmpty) {
        return SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No devices found',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try scanning again or make sure your device is discoverable.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SettingsButton(
                    label: 'Scan devices',
                    onPressed: controller.scan,
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return SettingsCard(
        children: [
          for (var i = 0; i < devices.length; i++) ...[
            _DeviceRow(device: devices[i]),
            if (i != devices.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.5),
              ),
          ],
        ],
      );
    });
  }
}

class _DeviceRow extends GetView<HomeController> {
  const _DeviceRow({required this.device});
  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final connected = device.connected;
    final subtitle = connected
        ? 'Connected • ${device.address}'
        : device.paired
            ? 'Paired • ${device.address}'
            : device.address.isEmpty
                ? 'Not paired'
                : device.address;

    return GetBuilder<HomeController>(
      id: 'device_${device.path}',
      builder: (c) {
        final isLoading = c.isDeviceLoading(device.path);
        final selected = c.selectedDevice.value?.path == device.path;
        return SettingsListTile(
          selected: selected,
          title: device.nameOrUnknown,
          subtitle: subtitle,
          leading: Icon(
            connected
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_rounded,
            size: 20,
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.8),
          ),
          onTap: () => showDeviceDetail(context, device),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                SettingsButton(
                  label: connected ? 'Disconnect' : 'Connect',
                  onPressed: () => connected
                      ? c.disconnect(device)
                      : c.connect(device),
                ),
              _DeviceActionMenu(device: device),
            ],
          ),
        );
      },
    );
  }
}

bool isSelectedDevice(DeviceModel device) {
  final selected = Get.find<HomeController>().selectedDevice.value;
  return selected?.path == device.path;
}

void showDeviceDetail(BuildContext context, DeviceModel device) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
  final homeC = Get.find<HomeController>();
  if (isDesktop) {
    homeC.selectDevice(device);
    return;
  }
  Get.dialog(DeviceDetailDialog(device: device));
}

class _DeviceActionMenu extends GetView<HomeController> {
  const _DeviceActionMenu({required this.device});
  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Device actions',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 19,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'pair':
            await controller.pair(device);
            break;
          case 'trust':
            await controller.toggleTrust(device);
            break;
          case 'remove':
            _showRemoveDialog(context);
            break;
        }
      },
      itemBuilder: (context) {
        return [
          if (!device.paired)
            const PopupMenuItem(
              value: 'pair',
              child: Text('Pair'),
            ),
          PopupMenuItem(
            value: 'trust',
            child: Text(device.trusted ? 'Untrust' : 'Trust'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove'),
          ),
        ];
      },
    );
  }

  void _showRemoveDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Remove device?'),
        content: Text('Remove ${device.nameOrUnknown} from paired devices?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Get.back();
              await controller.remove(device);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
