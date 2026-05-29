import 'package:flutter/material.dart';
import 'package:frontend/app/constants/theme/app_color.dart';
import 'package:frontend/app/data/models/device_model.dart';
import 'package:frontend/app/modules/home/controllers/home_controller.dart';
import 'package:get/get.dart';


class DeviceDetailDialog extends GetView<HomeController> {
  const DeviceDetailDialog({
    super.key,
    required this.device,
  });

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final isLoading = controller.isDeviceLoading(device.path);
            final connected = device.connected;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogHeader(device: device),
                const SizedBox(height: 22),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      label: connected ? 'Connected' : 'Disconnected',
                      icon: connected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      active: connected,
                    ),
                    _InfoChip(
                      label: device.paired ? 'Paired' : 'Unpaired',
                      icon: Icons.key_rounded,
                      active: device.paired,
                    ),
                    _InfoChip(
                      label: device.trusted ? 'Trusted' : 'Untrusted',
                      icon: Icons.verified_user_rounded,
                      active: device.trusted,
                    ),
                    _InfoChip(
                      label: device.rssi == 0 ? 'No RSSI' : 'RSSI ${device.rssi}',
                      icon: Icons.signal_cellular_alt_rounded,
                      active: device.rssi != 0,
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _InfoRow(
                  label: 'Address',
                  value: device.address,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Path',
                  value: device.path,
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                connected
                                    ? await controller.disconnect(device)
                                    : await controller.connect(device);

                                Get.back();
                              },
                        icon: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                connected
                                    ? Icons.link_off_rounded
                                    : Icons.link_rounded,
                              ),
                        label: Text(
                          connected ? 'Disconnect' : 'Connect',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () {
                        Get.back();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!device.paired)
                      OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                await controller.pair(device);
                                Get.back();
                              },
                        icon: const Icon(Icons.key_rounded),
                        label: const Text('Pair'),
                      ),
                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              await controller.toggleTrust(device);
                              Get.back();
                            },
                      icon: Icon(
                        device.trusted
                            ? Icons.verified_user_rounded
                            : Icons.verified_user_outlined,
                      ),
                      label: Text(
                        device.trusted ? 'Untrust' : 'Trust',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              _confirmRemove(context);
                            },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.red,
                      ),
                      label: const Text('Remove'),
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

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.device,
  });

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final color = device.connected ? AppColors.green : AppColors.blue;

    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            device.connected
                ? Icons.bluetooth_connected_rounded
                : Icons.devices_rounded,
            color: color,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Device Detail',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                device.nameOrUnknown,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.active,
  });

  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : Theme.of(context).iconTheme.color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: (active ? AppColors.green : Theme.of(context).colorScheme.surface)
            .withValues(alpha: active ? 0.16 : 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? AppColors.green.withValues(alpha: 0.24)
              : Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? AppColors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
