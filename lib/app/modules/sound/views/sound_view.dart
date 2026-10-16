import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/sound_device_model.dart';
import '../../../data/models/sound_stream_model.dart';
import '../../../widgets/settings_ui.dart';
import '../controllers/sound_controller.dart';

class SoundContent extends GetView<SoundController> {
  const SoundContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                final total = controller.sinks.length;
                final def = controller.defaultSink.value;
                final suffix = total > 0 ? ' • $total found' : '';
                final conn = def.isNotEmpty ? ' • Default: $def' : '';
                return SettingsSectionHeader('Output$suffix$conn');
              }),
              _DeviceListCard(isSource: false),
              Obx(() {
                final total = controller.inputs.length;
                final def = controller.defaultSource.value;
                final suffix = total > 0 ? ' • $total found' : '';
                final conn = def.isNotEmpty ? ' • Default: $def' : '';
                return SettingsSectionHeader('Input$suffix$conn');
              }),
              _DeviceListCard(isSource: true),
              Obx(() {
                final total = controller.playback.length;
                return SettingsSectionHeader(
                    'Applications${total > 0 ? ' • $total playing' : ''}');
              }),
              _StreamListCard(isPlayback: true),
              Obx(() {
                final total = controller.recording.length;
                return SettingsSectionHeader(
                    'Recording${total > 0 ? ' • $total active' : ''}');
              }),
              _StreamListCard(isPlayback: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceListCard extends GetView<SoundController> {
  const _DeviceListCard({required this.isSource});

  final bool isSource;

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

      final devices =
          isSource ? controller.inputs : controller.sinks.toList();
      if (devices.isEmpty) {
        return SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSource ? 'No input devices' : 'No output devices',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check that PipeWire / PulseAudio is running.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SettingsButton(
                    label: 'Refresh',
                    onPressed: controller.refreshData,
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
            _DeviceBlock(device: devices[i], isSource: isSource),
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

class _DeviceBlock extends GetView<SoundController> {
  const _DeviceBlock({required this.device, required this.isSource});

  final SoundDeviceModel device;
  final bool isSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draftKey = controller.deviceDraftKey(device, isSource);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSource ? Icons.mic_outlined : Icons.speaker_outlined,
                size: 20,
                color: theme.textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (device.isDefault) ...[
                          const SizedBox(width: 8),
                          _DefaultChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.muted
                          ? 'Muted • ${device.volumePercent}%'
                          : '${device.volumePercent}%${device.hasPortChoice ? ' • ${device.activePort}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!device.isDefault)
                SettingsButton(
                  label: 'Default',
                  primary: false,
                  onPressed: () =>
                      controller.setDefault(device, isSource),
                ),
              Obx(() {
                final busy = controller.isBusy('mute:${device.name}');
                if (busy) {
                  return const SizedBox(
                    height: kSettingsControlHeight,
                    width: kSettingsControlHeight,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return SettingsSwitch(
                  value: !device.muted,
                  onChanged: (_) =>
                      controller.toggleDeviceMute(device, isSource),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  final value =
                      controller.volumeFor(draftKey, device.volumePercent);
                  return Slider(
                    value: value.clamp(0, 150).toDouble(),
                    min: 0,
                    max: 150,
                    divisions: 150,
                    label: '${value.round()}%',
                    onChanged: (v) =>
                        controller.previewVolume(draftKey, v),
                    onChangeEnd: (v) => controller.commitDeviceVolume(
                        device, isSource, v),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final value =
                    controller.volumeFor(draftKey, device.volumePercent);
                return SizedBox(
                  width: 44,
                  child: Text(
                    '${value.round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              }),
            ],
          ),
          if (device.hasPortChoice)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text('Port', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  SettingsDropdown<String>(
                    value: device.ports.any((p) => p.name == device.activePort)
                        ? device.activePort
                        : device.ports.first.name,
                    items: [
                      for (final p in device.ports)
                        DropdownMenuItem(
                          value: p.name,
                          child: Text(
                            p.description.isNotEmpty ? p.description : p.name,
                          ),
                        ),
                    ],
                    onChanged: (port) {
                      if (port != null) {
                        controller.setPort(device, port, isSource);
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DefaultChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Default',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _StreamListCard extends GetView<SoundController> {
  const _StreamListCard({required this.isPlayback});

  final bool isPlayback;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final streams =
          isPlayback ? controller.playback : controller.recording.toList();

      if (!controller.loading.value && streams.isEmpty) {
        return SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPlayback ? 'Nothing playing' : 'Nothing recording',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPlayback
                        ? 'Per-app volume controls appear here while audio plays.'
                        : 'Per-app recording controls appear here while capturing.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return SettingsCard(
        children: [
          for (var i = 0; i < streams.length; i++) ...[
            _StreamBlock(stream: streams[i], isPlayback: isPlayback),
            if (i != streams.length - 1)
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

class _StreamBlock extends GetView<SoundController> {
  const _StreamBlock({required this.stream, required this.isPlayback});

  final SoundStreamModel stream;
  final bool isPlayback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draftKey = controller.streamDraftKey(stream, isPlayback);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.audiotrack_outlined,
                size: 20,
                color: theme.textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stream.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stream.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MoveDropdown(stream: stream, isPlayback: isPlayback),
              Obx(() {
                final busy = controller.isBusy('smute:${stream.index}');
                if (busy) {
                  return const SizedBox(
                    height: kSettingsControlHeight,
                    width: kSettingsControlHeight,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return SettingsSwitch(
                  value: !stream.muted,
                  onChanged: (_) =>
                      controller.toggleStreamMute(stream, isPlayback),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  final value =
                      controller.volumeFor(draftKey, stream.volumePercent);
                  return Slider(
                    value: value.clamp(0, 150).toDouble(),
                    min: 0,
                    max: 150,
                    divisions: 150,
                    label: '${value.round()}%',
                    onChanged: (v) =>
                        controller.previewVolume(draftKey, v),
                    onChangeEnd: (v) => controller.commitStreamVolume(
                        stream, isPlayback, v),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final value =
                    controller.volumeFor(draftKey, stream.volumePercent);
                return SizedBox(
                  width: 44,
                  child: Text(
                    '${value.round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveDropdown extends GetView<SoundController> {
  const _MoveDropdown({required this.stream, required this.isPlayback});

  final SoundStreamModel stream;
  final bool isPlayback;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final targets =
          isPlayback ? controller.sinks.toList() : controller.inputs;
      if (targets.length < 2) return const SizedBox.shrink();
      final names = targets.map((d) => d.name).toList();
      final value = names.contains(stream.device) ? stream.device : names.first;
      return SettingsDropdown<String>(
        value: value,
        items: [
          for (final d in targets)
            DropdownMenuItem(
              value: d.name,
              child: Text(d.displayName),
            ),
        ],
        onChanged: (dest) {
          if (dest != null && dest != stream.device) {
            controller.moveStream(stream, isPlayback, dest);
          }
        },
      );
    });
  }
}
