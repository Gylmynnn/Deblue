import 'package:flutter/material.dart';
import 'package:frontend/app/constants/theme/app_color.dart';
import 'package:frontend/app/controllers/app_controller.dart';
import 'package:frontend/app/data/models/device_model.dart';
import 'package:frontend/app/data/services/backend_process_service.dart';
import 'package:frontend/app/data/services/bluetooth_event_service.dart';
import 'package:frontend/app/modules/home/controllers/home_controller.dart';
import 'package:frontend/app/widgets/app_shell.dart';
import 'package:frontend/app/widgets/device_detail_dialog.dart';
import 'package:frontend/app/widgets/device_detail_panel.dart';
import 'package:get/get.dart';

class HomeView extends GetView<AppController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final layoutMode = controller.layoutMode.value;

      return AppShell(
        title: 'Devices',
        actions: [
          IconButton(
            onPressed: () {
              Get.find<HomeController>().refreshData();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        child: SafeArea(
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
                    _HeaderCard(isCompact: isCompact),
                    const SizedBox(height: 14),
                    _DeviceToolbar(isCompact: isCompact),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'Devices',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 10),
                        Obx(() {
                          final total =
                              Get.find<HomeController>().filteredDevices.length;

                          return _StatusChip(
                            label: '$total found',
                            active: total > 0,
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Obx(() {
                        final selectedDevice =
                            Get.find<HomeController>().selectedDevice.value;

                        final showDetailPanel =
                            selectedDevice != null &&
                            constraints.maxWidth >= 1100;

                        if (!showDetailPanel) {
                          return _PlaceholderDevices(
                            layoutMode: layoutMode,
                            isCompact: isCompact,
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PlaceholderDevices(
                                layoutMode: layoutMode,
                                isCompact: isCompact,
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 360,
                              child: DeviceDetailPanel(device: selectedDevice),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    });
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

class _DeviceToolbar extends GetView<AppController> {
  const _DeviceToolbar({required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: isCompact
            ? Column(
                children: [
                  _SearchField(controller: controller),
                  const SizedBox(height: 12),
                  _FilterSelector(controller: controller),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _SearchField(controller: controller)),
                  const SizedBox(width: 14),
                  _FilterSelector(controller: controller),
                ],
              ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: controller.setSearchQuery,
      decoration: InputDecoration(
        hintText: 'Search device...',
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
    );
  }
}

class _FilterSelector extends StatelessWidget {
  const _FilterSelector({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SegmentedButton<DeviceFilterMode>(
        selected: {controller.filterMode.value},
        onSelectionChanged: (value) {
          controller.setFilterMode(value.first);
        },
        segments: const [
          ButtonSegment(
            value: DeviceFilterMode.all,
            icon: Icon(Icons.apps_rounded),
            label: Text('All'),
          ),
          ButtonSegment(
            value: DeviceFilterMode.connected,
            icon: Icon(Icons.bluetooth_connected_rounded),
            label: Text('Connected'),
          ),
          ButtonSegment(
            value: DeviceFilterMode.paired,
            icon: Icon(Icons.verified_rounded),
            label: Text('Paired'),
          ),
        ],
      );
    });
  }
}

class _DeviceActionMenu extends GetView<HomeController> {
  const _DeviceActionMenu({required this.device});
  final DeviceModel device;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Device actions',
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
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.key_rounded),
                title: Text('Pair'),
              ),
            ),
          PopupMenuItem(
            value: 'trust',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                device.trusted
                    ? Icons.verified_user_rounded
                    : Icons.verified_user_outlined,
              ),
              title: Text(device.trusted ? 'Untrust' : 'Trust'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'remove',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.red),
              title: Text('Remove'),
            ),
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

class _HeaderCard extends GetView<HomeController> {
  const _HeaderCard({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final eventService = Get.find<BluetoothEventService>();
    final backendProcess = Get.find<BackendProcessService>();

    return Obx(() {
      final adapter = controller.adapter.value;
      final powered = adapter?.powered ?? false;
      final discovering = adapter?.discovering ?? false;
      final scanning = controller.scanning.value;
      final realtime = eventService.connected.value;
      final backendRunning = backendProcess.running.value;
      final backendStarting = backendProcess.starting.value;
      return Card(
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 16 : 22),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderMainInfo(
                      adapterName: adapter?.alias ?? 'Bluetooth Manager',
                      powered: powered,
                      discovering: discovering || scanning,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatusChip(
                          label: powered ? 'Enabled' : 'Disabled',
                          active: powered,
                        ),
                        _StatusChip(
                          label: backendRunning
                              ? 'Backend'
                              : backendStarting
                              ? 'Starting'
                              : 'Backend offline',
                          active: backendRunning,
                        ),
                        _StatusChip(
                          label: realtime ? 'Realtime' : 'Offline',
                          active: realtime,
                        ),
                        if (!backendRunning && !backendStarting)
                          FilledButton.icon(
                            onPressed: () async {
                              await backendProcess.ensureStarted();
                              await controller.refreshData();
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start Backend'),
                          ),
                        FilledButton.icon(
                          onPressed: scanning ? null : controller.scan,
                          icon: scanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                          label: Text(scanning ? 'Scanning' : 'Scan'),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _HeaderMainInfo(
                        adapterName: adapter?.alias ?? 'Bluetooth Manager',
                        powered: powered,
                        discovering: discovering || scanning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _StatusChip(
                      label: realtime ? 'Realtime' : 'Offline',
                      active: realtime,
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: scanning ? null : controller.scan,
                      icon: scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(scanning ? 'Scanning' : 'Scan'),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: powered,
                      onChanged: (_) {
                        controller.toggleBluetooth();
                      },
                    ),
                  ],
                ),
        ),
      );
    });
  }
}

class _PlaceholderDevices extends GetView<HomeController> {
  const _PlaceholderDevices({
    required this.layoutMode,
    required this.isCompact,
  });

  final DeviceLayoutMode layoutMode;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final devices = controller.filteredDevices;

      if (devices.isEmpty) {
        return const _EmptyDevicesState();
      }

      if (layoutMode == DeviceLayoutMode.compact) {
        return ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            return _DeviceCompactTile(
              key: ValueKey(devices[index].path),
              device: devices[index],
            );
          },
        );
      }

      if (layoutMode == DeviceLayoutMode.tile || isCompact) {
        return ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            return _DeviceTile(
              key: ValueKey(devices[index].path),
              device: devices[index],
            );
          },
        );
      }

      return GridView.builder(
        itemCount: devices.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(MediaQuery.sizeOf(context).width),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 170,
        ),
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          return _DeviceGridCard(
            key: ValueKey(devices[index].path),
            device: devices[index],
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

class _HeaderMainInfo extends StatelessWidget {
  const _HeaderMainInfo({
    required this.adapterName,
    required this.powered,
    required this.discovering,
  });

  final String adapterName;
  final bool powered;
  final bool discovering;

  @override
  Widget build(BuildContext context) {
    final color = powered ? AppColors.green : AppColors.red;

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
            powered
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_disabled_rounded,
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
                'Bluetooth Manager',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                adapterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                powered
                    ? discovering
                          ? 'Scanning nearby devices...'
                          : 'Adapter ready'
                    : 'Bluetooth adapter is disabled',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyDevicesState extends StatelessWidget {
  const _EmptyDevicesState();

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
                    Icons.bluetooth_searching_rounded,
                    color: AppColors.blue,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No devices found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try scanning again or make sure your Bluetooth device is discoverable.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Get.find<HomeController>().scan();
                  },
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Scan devices'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceGridCard extends GetView<HomeController> {
  const _DeviceGridCard({
    super.key,
    required this.device,
  });

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final bool connected = device.connected;

    return Obx(() {
      final bool selected = isSelectedDevice(device);
      final bool isLoading = controller.isDeviceLoading(device.path);
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected
                ? AppColors.green.withValues(alpha: 0.65)
                : Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: .circular(18),
          onTap: isLoading
              ? null
              : () {
                  showDeviceDetail(context, device);
                },
          child: Padding(
            padding: const .all(18),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Row(
                  children: [
                    Icon(
                      device.connected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.devices_rounded,
                      color: connected ? AppColors.green : AppColors.blue,
                    ),
                    const Spacer(),
                    if (isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      _DeviceActionMenu(device: device),
                  ],
                ),
                const Spacer(),
                Text(
                  device.nameOrUnknown,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: const TextStyle(fontWeight: .w800),
                ),
                const SizedBox(height: 6),
                Text(connected ? 'Connected' : 'Disconnected'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: device.paired ? 'Paired' : 'Unpaired',
                      active: device.paired,
                    ),
                    _StatusChip(
                      label: device.trusted ? 'Trusted' : 'Untrusted',
                      active: device.trusted,
                    ),
                    _StatusChip(
                      label: device.rssi == 0
                          ? 'No RSSI'
                          : 'RSSI ${device.rssi}',
                      active: device.rssi != 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _DeviceTile extends GetView<HomeController> {
  const _DeviceTile({
    super.key,
    required this.device,
  });
  final DeviceModel device;
  @override
  Widget build(BuildContext context) {
    final bool connected = device.connected;
    return Card(
      child: ListTile(
        onTap: () {
          showDeviceDetail(context, device);
        },
        leading: Icon(
          connected ? Icons.bluetooth_connected_rounded : Icons.devices_rounded,
          color: connected ? AppColors.green : AppColors.blue,
        ),
        title: Text(
          device.nameOrUnknown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          connected ? 'Connected' : device.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Obx(() {
          final isLoading = controller.isDeviceLoading(device.path);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () {
                        connected
                            ? controller.disconnect(device)
                            : controller.connect(device);
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(connected ? 'Disconnect' : 'Connect'),
              ),
              const SizedBox(width: 6),
              _DeviceActionMenu(device: device),
            ],
          );
        }),
      ),
    );
  }
}

class _DeviceCompactTile extends GetView<HomeController> {
  const _DeviceCompactTile({
    super.key,
    required this.device,
  });
  final DeviceModel device;
  @override
  Widget build(BuildContext context) {
    final bool connected = device.connected;
    return Card(
      child: ListTile(
        dense: true,
        onTap: () {
          showDeviceDetail(context, device);
        },
        leading: Icon(
          connected
              ? Icons.bluetooth_connected_rounded
              : Icons.bluetooth_rounded,
          color: connected ? AppColors.green : AppColors.cyan,
        ),
        title: Text(
          device.nameOrUnknown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Obx(() {
          final isLoading = controller.isDeviceLoading(device.path);
          return IconButton(
            onPressed: isLoading
                ? null
                : () {
                    connected
                        ? controller.disconnect(device)
                        : controller.connect(device);
                  },
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(connected ? Icons.link_off_rounded : Icons.link_rounded),
          );
        }),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (active ? AppColors.green : AppColors.darkSurfaceAlt).withValues(
          alpha: 0.18,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? AppColors.green : null,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
