import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../sources/online_music_service.dart';

/// 播放器底层驱动抽象接口
abstract class AudioPlayerBackend {
  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;
  Stream<bool> get onPlayingChanged;
  Stream<void> get onPlayerComplete;

  Future<void> play(String uri);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// 真实物理音频驱动 (基于 audioplayers 全平台物理声卡输出)
class RealAudioPlayerBackend implements AudioPlayerBackend {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<bool> get onPlayingChanged =>
      _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);

  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  bool _hasSource = false;

  @override
  Future<void> play(String uri) async {
    final direct = await OnlineMusicService.unwrapRedirects(uri);
    _hasSource = true;
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      await _player.play(UrlSource(direct));
    } else {
      await _player.play(DeviceFileSource(direct));
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    await _player.resume();
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_hasSource) return;
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[RealAudioPlayerBackend] seek exception handled: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  @override
  Future<void> dispose() async {
    _hasSource = false;
    await _player.dispose();
  }
}

/// 内存轻量化状态驱动 (用于单测与无头环境)
class InMemoryAudioPlayerBackend implements AudioPlayerBackend {
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _completeController = StreamController<void>.broadcast();

  Duration _position = Duration.zero;
  final Duration _duration = const Duration(minutes: 3, seconds: 30);
  bool _isPlaying = false;
  double _volume = 1.0;

  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<bool> get onPlayingChanged => _playingController.stream;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> play(String uri) async {
    _isPlaying = true;
    _position = Duration.zero;
    _playingController.add(true);
    _positionController.add(Duration.zero);
    _durationController.add(_duration);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> resume() async {
    _isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _completeController.close();
  }
}

/// 智能自适应音频后端工厂
class AudioPlayerBackendFactory {
  static AudioPlayerBackend? defaultMockBackend;

  static AudioPlayerBackend create() {
    if (defaultMockBackend != null) {
      return defaultMockBackend!;
    }

    bool isTestEnv = false;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        isTestEnv = true;
      }
    } catch (_) {}

    if (isTestEnv) {
      return InMemoryAudioPlayerBackend();
    }

    try {
      return RealAudioPlayerBackend();
    } catch (e) {
      debugPrint('[AudioPlayerBackendFactory] 物理音频通道初始化异常，回退至内存驱动: $e');
      return InMemoryAudioPlayerBackend();
    }
  }
}
