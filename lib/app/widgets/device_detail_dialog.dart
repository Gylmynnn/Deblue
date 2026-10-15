import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/device_model.dart';
import '../modules/home/controllers/home_controller.dart';
import 'settings_ui.dart';

class DeviceDetailDialog extends GetView<HomeController> {
  const DeviceDetailDialog({super.key, required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final isLoading = controller.isDeviceLoading(device.path);
            final connected = device.connected;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsCard(
                  children: [
                    SettingsRow(
                      title: device.nameOrUnknown,
                      description: device.address.isEmpty
                          ? 'No address'
                          : device.address,
                      trailing: const SizedBox.shrink(),
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
                            : () async {
                                connected
                                    ? await controller.disconnect(device)
                                    : await controller.connect(device);
                                Get.back();
                              },
                      ),
                    ),
                    if (!device.paired)
                      SettingsRow(
                        title: 'Pairing',
                        description: 'Pair this device to enable connection.',
                        trailing: SettingsButton(
                          label: 'Pair',
                          enabled: !isLoading,
                          onPressed: isLoading
                              ? null
                              : () async {
                                  await controller.pair(device);
                                  Get.back();
                                },
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
                            : () async {
                                await controller.toggleTrust(device);
                                Get.back();
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    SettingsButton(
                      label: 'Remove',
                      enabled: !isLoading,
                      onPressed:
                          isLoading ? null : () => _confirmRemove(context),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Remove device?'),
        content: Text(
          'Remove ${device.nameOrUnknown} from paired devices?',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Get.back();
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
