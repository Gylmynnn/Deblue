import '../../../src/rust/api/sound.dart' as rust_api;

class SoundStreamModel {
  final int index;
  final String appName;
  final String streamName;
  final int volumePercent;
  final bool muted;
  final String device;

  const SoundStreamModel({
    required this.index,
    required this.appName,
    required this.streamName,
    required this.volumePercent,
    required this.muted,
    required this.device,
  });

  String get label => appName.isNotEmpty ? appName : 'Stream $index';

  String get subtitle {
    final parts = <String>[];
    if (streamName.isNotEmpty && streamName != appName) parts.add(streamName);
    if (device.isNotEmpty) parts.add(device);
    parts.add('$volumePercent%');
    if (muted) parts.add('Muted');
    return parts.join(' • ');
  }

  factory SoundStreamModel.fromRust(rust_api.SoundStream s) {
    return SoundStreamModel(
      index: s.index,
      appName: s.appName,
      streamName: s.streamName,
      volumePercent: s.volumePercent,
      muted: s.muted,
      device: s.device,
    );
  }
}
