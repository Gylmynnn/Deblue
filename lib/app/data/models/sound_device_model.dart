import '../../../src/rust/api/sound.dart' as rust_api;

class SoundPortModel {
  final String name;
  final String description;

  const SoundPortModel({required this.name, required this.description});

  factory SoundPortModel.fromRust(rust_api.SoundPort p) {
    return SoundPortModel(name: p.name, description: p.description);
  }
}

class SoundDeviceModel {
  final String name;
  final String description;
  final int volumePercent;
  final bool muted;
  final bool isDefault;
  final bool isMonitor;
  final String activePort;
  final List<SoundPortModel> ports;

  const SoundDeviceModel({
    required this.name,
    required this.description,
    required this.volumePercent,
    required this.muted,
    required this.isDefault,
    required this.isMonitor,
    required this.activePort,
    required this.ports,
  });

  bool get hasPortChoice => ports.length > 1;

  String get displayName => description.isNotEmpty ? description : name;

  factory SoundDeviceModel.fromRust(rust_api.SoundDevice d) {
    return SoundDeviceModel(
      name: d.name,
      description: d.description,
      volumePercent: d.volumePercent,
      muted: d.muted,
      isDefault: d.isDefault,
      isMonitor: d.isMonitor,
      activePort: d.activePort,
      ports: d.ports.map(SoundPortModel.fromRust).toList(),
    );
  }
}
