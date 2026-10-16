import '../../../src/rust/api/sound.dart' as rust_api;

class SoundEventModel {
  final String eventType;
  final String detail;

  const SoundEventModel({required this.eventType, required this.detail});

  factory SoundEventModel.fromRust(rust_api.SoundEvent e) {
    return SoundEventModel(eventType: e.eventType, detail: e.detail);
  }
}
