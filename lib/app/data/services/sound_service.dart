import '../models/sound_device_model.dart';
import '../models/sound_stream_model.dart';
import '../repositories/sound_repo.dart';
import '../../../src/rust/api/sound.dart' as rust_api;

class SoundService implements SoundRepo {
  @override
  Future<SoundStateModel> getState() async {
    try {
      final s = await rust_api.getSoundState();
      return SoundStateModel(
        sinks: s.sinks.map(SoundDeviceModel.fromRust).toList(),
        sources: s.sources.map(SoundDeviceModel.fromRust).toList(),
        playback: s.playback.map(SoundStreamModel.fromRust).toList(),
        recording: s.recording.map(SoundStreamModel.fromRust).toList(),
        defaultSink: s.defaultSink,
        defaultSource: s.defaultSource,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setSinkVolume(String name, int percent) async {
    try {
      await rust_api.setSinkVolume(name: name, percent: percent);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setSourceVolume(String name, int percent) async {
    try {
      await rust_api.setSourceVolume(name: name, percent: percent);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setStreamVolume(int index, bool isPlayback, int percent) async {
    try {
      await rust_api.setStreamVolume(
        index: index,
        isPlayback: isPlayback,
        percent: percent,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setSinkMute(String name, bool mute) async {
    try {
      await rust_api.setSinkMute(name: name, mute: mute);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setSourceMute(String name, bool mute) async {
    try {
      await rust_api.setSourceMute(name: name, mute: mute);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setStreamMute(int index, bool isPlayback, bool mute) async {
    try {
      await rust_api.setStreamMute(
        index: index,
        isPlayback: isPlayback,
        mute: mute,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setDefaultSink(String name) async {
    try {
      await rust_api.setDefaultSink(name: name);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setDefaultSource(String name) async {
    try {
      await rust_api.setDefaultSource(name: name);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> moveStream(int index, bool isPlayback, String device) async {
    try {
      await rust_api.moveStream(
        index: index,
        isPlayback: isPlayback,
        device: device,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> setDevicePort(String device, String port, bool isSource) async {
    try {
      await rust_api.setDevicePort(
        device: device,
        port: port,
        isSource: isSource,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
