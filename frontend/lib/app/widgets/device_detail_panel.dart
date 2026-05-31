import 'package:flutter/material.dart';
import 'package:frontend/app/constants/theme/app_color.dart';
import 'package:frontend/app/data/models/device_model.dart';
import 'package:frontend/app/modules/home/controllers/home_controller.dart';
import 'package:get/get.dart';


class DeviceDetailPanel extends GetView<HomeController> {
  const DeviceDetailPanel({
    super.key,
    required this.device,
  });

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isDeviceLoading(device.path);
      final connected = device.connected;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DeviceIcon(device: device),
                  const Spacer(),
                  IconButton(
                    onPressed: controller.clearSelectedDevice,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                device.nameOrUnknown,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),

              const SizedBox(height: 6),

              Text(
                device.address.isEmpty ? 'No address' : device.address,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 20),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PanelChip(
                    label: connected ? 'Connected' : 'Disconnected',
                    icon: connected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_disabled_rounded,
                    active: connected,
                  ),
                  _PanelChip(
                    label: device.paired ? 'Paired' : 'Unpaired',
                    icon: Icons.key_rounded,
                    active: device.paired,
                  ),
                  _PanelChip(
                    label: device.trusted ? 'Trusted' : 'Untrusted',
                    icon: Icons.verified_user_rounded,
                    active: device.trusted,
                  ),
                  _PanelChip(
                    label: device.rssi == 0 ? 'No RSSI' : 'RSSI ${device.rssi}',
                    icon: Icons.signal_cellular_alt_rounded,
                    active: device.rssi != 0,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _InfoBox(
                label: 'D-Bus Path',
                value: device.path,
              ),

              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed: isLoading
                    ? null
                    : () {
                        connected
                            ? controller.disconnect(device)
                            : controller.connect(device);
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        connected ? Icons.link_off_rounded : Icons.link_rounded,
                      ),
                label: Text(
                  connected ? 'Disconnect' : 'Connect',
                ),
              ),

              const SizedBox(height: 10),

              if (!device.paired)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            controller.pair(device);
                          },
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Pair device'),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          controller.toggleTrust(device);
                        },
                  icon: Icon(
                    device.trusted
                        ? Icons.verified_user_rounded
                        : Icons.verified_user_outlined,
                  ),
                  label: Text(
                    device.trusted ? 'Untrust device' : 'Trust device',
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          _confirmRemove();
                        },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.red,
                  ),
                  label: const Text('Remove device'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _confirmRemove() {
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

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({
    required this.device,
  });

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final color = device.connected ? AppColors.green : AppColors.blue;

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        device.connected
            ? Icons.bluetooth_connected_rounded
            : Icons.devices_rounded,
        color: color,
        size: 34,
      ),
    );
  }
}

class _PanelChip extends StatelessWidget {
  const _PanelChip({
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
        horizontal: 11,
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
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
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
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
