import '../models/sound_device_model.dart';
import '../models/sound_stream_model.dart';

class SoundStateModel {
  final List<SoundDeviceModel> sinks;
  final List<SoundDeviceModel> sources;
  final List<SoundStreamModel> playback;
  final List<SoundStreamModel> recording;
  final String defaultSink;
  final String defaultSource;

  const SoundStateModel({
    required this.sinks,
    required this.sources,
    required this.playback,
    required this.recording,
    required this.defaultSink,
    required this.defaultSource,
  });
}

abstract class SoundRepo {
  Future<SoundStateModel> getState();
  Future<void> setSinkVolume(String name, int percent);
  Future<void> setSourceVolume(String name, int percent);
  Future<void> setStreamVolume(int index, bool isPlayback, int percent);
  Future<void> setSinkMute(String name, bool mute);
  Future<void> setSourceMute(String name, bool mute);
  Future<void> setStreamMute(int index, bool isPlayback, bool mute);
  Future<void> setDefaultSink(String name);
  Future<void> setDefaultSource(String name);
  Future<void> moveStream(int index, bool isPlayback, String device);
  Future<void> setDevicePort(String device, String port, bool isSource);
}
