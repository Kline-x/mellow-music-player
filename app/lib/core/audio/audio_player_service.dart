import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'track_model.dart';

/// 播放循环模式
enum PlaybackMode {
  sequence('列表循环'),
  singleLoop('单曲循环'),
  shuffle('随机漫游');

  final String label;
  const PlaybackMode(this.label);
}

/// 播放器核心业务与状态管理服务 (双流架构)
class AudioPlayerService extends ChangeNotifier {
  final List<Track> _playlist = List.from(mockPresetTracks);
  final List<Track> _playHistory = [];
  final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};

  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  PlaybackMode _mode = PlaybackMode.sequence;
  double _volume = 0.85;

  Timer? _positionTicker;
  Timer? _sleepTimer;
  int? _sleepTimerMinutes;
  int _sleepTimerRemainingSeconds = 0;
  bool _pauseAfterCurrent = false;

  // Getters
  List<Track> get playlist => List.unmodifiable(_playlist);
  List<Track> get playHistory => List.unmodifiable(_playHistory);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _position;
  PlaybackMode get playbackMode => _mode;
  double get volume => _volume;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  int get sleepTimerRemainingSeconds => _sleepTimerRemainingSeconds;
  bool get pauseAfterCurrent => _pauseAfterCurrent;

  Track? get currentTrack {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length) return null;
    return _playlist[_currentIndex].copyWith(
      isFavorite: _favoriteIds.contains(_playlist[_currentIndex].id),
    );
  }

  AudioPlayerService() {
    if (_playlist.isNotEmpty) {
      _recordHistory(_playlist[0]);
    }
  }

  // 核心播放控制
  void togglePlay() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (_playlist.isEmpty) return;
    _isPlaying = true;
    _startPositionTicker();
    notifyListeners();
  }

  void pause() {
    _isPlaying = false;
    _positionTicker?.cancel();
    notifyListeners();
  }

  void playTrack(Track track) {
    final index = _playlist.indexWhere((t) => t.id == track.id);
    if (index != -1) {
      _currentIndex = index;
    } else {
      _playlist.insert(0, track);
      _currentIndex = 0;
    }
    _position = Duration.zero;
    _recordHistory(_playlist[_currentIndex]);
    play();
  }

  void next() {
    if (_playlist.isEmpty) return;
    if (_mode == PlaybackMode.shuffle) {
      final random = Random();
      _currentIndex = random.nextInt(_playlist.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    _position = Duration.zero;
    _recordHistory(_playlist[_currentIndex]);
    if (_isPlaying) {
      play();
    } else {
      notifyListeners();
    }
  }

  void previous() {
    if (_playlist.isEmpty) return;
    if (_position.inSeconds > 3) {
      // 超过3秒则重头播放当前歌曲
      seek(Duration.zero);
      return;
    }
    if (_mode == PlaybackMode.shuffle) {
      final random = Random();
      _currentIndex = random.nextInt(_playlist.length);
    } else {
      _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }
    _position = Duration.zero;
    _recordHistory(_playlist[_currentIndex]);
    if (_isPlaying) {
      play();
    } else {
      notifyListeners();
    }
  }

  void seek(Duration target) {
    final duration = currentTrack?.duration ?? Duration.zero;
    if (target < Duration.zero) {
      _position = Duration.zero;
    } else if (target > duration) {
      _position = duration;
    } else {
      _position = target;
    }
    notifyListeners();
  }

  void toggleFavorite([String? trackId]) {
    final id = trackId ?? currentTrack?.id;
    if (id == null) return;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();
  }

  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  void setVolume(double val) {
    _volume = val.clamp(0.0, 1.0);
    notifyListeners();
  }

  void cyclePlaybackMode() {
    switch (_mode) {
      case PlaybackMode.sequence:
        _mode = PlaybackMode.singleLoop;
        break;
      case PlaybackMode.singleLoop:
        _mode = PlaybackMode.shuffle;
        break;
      case PlaybackMode.shuffle:
        _mode = PlaybackMode.sequence;
        break;
    }
    notifyListeners();
  }

  void setPlaybackMode(PlaybackMode mode) {
    _mode = mode;
    notifyListeners();
  }

  // 队列操作
  void addToQueue(Track track) {
    _playlist.add(track);
    notifyListeners();
  }

  void removeTrackAt(int index) {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (_currentIndex >= _playlist.length) {
        _currentIndex = max(0, _playlist.length - 1);
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    _playlist.clear();
    _currentIndex = 0;
    _position = Duration.zero;
    pause();
  }

  // 睡眠定时器
  void startSleepTimer(int minutes, {bool pauseAfterCurrentSong = false}) {
    cancelSleepTimer();
    _sleepTimerMinutes = minutes;
    _pauseAfterCurrent = pauseAfterCurrentSong;
    _sleepTimerRemainingSeconds = minutes * 60;

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemainingSeconds > 0) {
        _sleepTimerRemainingSeconds--;
        notifyListeners();
      } else {
        cancelSleepTimer();
        pause();
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerMinutes = null;
    _sleepTimerRemainingSeconds = 0;
    _pauseAfterCurrent = false;
    notifyListeners();
  }

  void _recordHistory(Track track) {
    _playHistory.removeWhere((t) => t.id == track.id);
    _playHistory.insert(0, track);
    if (_playHistory.length > 50) {
      _playHistory.removeLast();
    }
  }

  // 60fps 高刷进度驱动 (前台丝滑歌词插值，每 50ms 模拟推进)
  void _startPositionTicker() {
    _positionTicker?.cancel();
    _positionTicker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final track = currentTrack;
      if (track == null) return;

      final nextPos = _position + const Duration(milliseconds: 50);
      if (nextPos >= track.duration) {
        if (_pauseAfterCurrent) {
          pause();
          cancelSleepTimer();
          return;
        }

        if (_mode == PlaybackMode.singleLoop) {
          _position = Duration.zero;
        } else {
          next();
        }
      } else {
        _position = nextPos;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _positionTicker?.cancel();
    _sleepTimer?.cancel();
    super.dispose();
  }
}
