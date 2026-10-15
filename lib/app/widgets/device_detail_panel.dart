import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/device_model.dart';
import '../modules/home/controllers/home_controller.dart';
import 'settings_ui.dart';

class DeviceDetailPanel extends GetView<HomeController> {
  const DeviceDetailPanel({super.key, required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isDeviceLoading(device.path);
      final connected = device.connected;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Device'),
          SettingsCard(
            children: [
              SettingsRow(
                title: device.nameOrUnknown,
                description:
                    device.address.isEmpty ? 'No address' : device.address,
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: controller.clearSelectedDevice,
                  tooltip: 'Close',
                ),
              ),
              SettingsRow(
                title: 'Status',
                description:
                    '${connected ? 'Connected' : 'Disconnected'} • ${device.paired ? 'Paired' : 'Unpaired'} • ${device.trusted ? 'Trusted' : 'Untrusted'}',
                trailing: SettingsButton(
                  label: connected ? 'Disconnect' : 'Connect',
                  enabled: !isLoading,
                  onPressed: isLoading
                      ? null
                      : () => connected
                          ? controller.disconnect(device)
                          : controller.connect(device),
                ),
              ),
              if (!device.paired)
                SettingsRow(
                  title: 'Pairing',
                  description: 'Pair this device to enable connection.',
                  trailing: SettingsButton(
                    label: 'Pair',
                    enabled: !isLoading,
                    onPressed:
                        isLoading ? null : () => controller.pair(device),
                  ),
                ),
              SettingsRow(
                title: 'Trust',
                description: 'Trusted devices connect automatically.',
                trailing: SettingsButton(
                  label: device.trusted ? 'Untrust' : 'Trust',
                  enabled: !isLoading,
                  onPressed: isLoading
                      ? null
                      : () => controller.toggleTrust(device),
                ),
              ),
              SettingsRow(
                title: 'Remove',
                description:
                    'Remove ${device.nameOrUnknown} from paired devices.',
                trailing: SettingsButton(
                  label: 'Remove',
                  enabled: !isLoading,
                  onPressed: isLoading ? null : () => _confirmRemove(),
                ),
              ),
              SettingsRow(
                title: 'Details',
                description:
                    'RSSI ${device.rssi == 0 ? '-' : device.rssi}\n${device.path}',
                trailing: const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      );
    });
  }

  void _confirmRemove() {
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
              controller.clearSelectedDevice();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
