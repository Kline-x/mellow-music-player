import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'track_model.dart';
import 'player_backend.dart';
import '../sources/online_music_service.dart';
import '../storage/storage_service.dart';

/// 播放循环模式
enum PlaybackMode {
  sequence('列表循环'),
  singleLoop('单曲循环'),
  shuffle('随机漫游');

  final String label;
  const PlaybackMode(this.label);
}

/// 播放器核心业务与状态管理服务 (物理声卡双流引擎 + 真实落盘持久化)
class AudioPlayerService extends ChangeNotifier {
  final AudioPlayerBackend _backend;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<void>? _completeSub;

  final List<Track> _playlist = List.from(mockPresetTracks);
  final List<Track> _playHistory = [];
  final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};
  final List<ImportedPlaylist> _importedPlaylists = [];

  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlaybackMode _mode = PlaybackMode.sequence;
  double _volume = 0.85;

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
  Duration get position => _position;
  Duration get duration => _duration > Duration.zero ? _duration : (currentTrack?.duration ?? Duration.zero);
  PlaybackMode get playbackMode => _mode;
  double get volume => _volume;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  int get sleepTimerRemainingSeconds => _sleepTimerRemainingSeconds;
  bool get pauseAfterCurrent => _pauseAfterCurrent;

  List<ImportedPlaylist> get importedPlaylists => List.unmodifiable(_importedPlaylists);

  List<Track> get favoriteTracks {
    final list = <Track>[];
    final addedIds = <String>{};
    for (final t in _playlist) {
      if (_favoriteIds.contains(t.id) && addedIds.add(t.id)) {
        list.add(t.copyWith(isFavorite: true));
      }
    }
    for (final t in mockPresetTracks) {
      if (_favoriteIds.contains(t.id) && addedIds.add(t.id)) {
        list.add(t.copyWith(isFavorite: true));
      }
    }
    return list;
  }

  Track? get currentTrack {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length) return null;
    return _playlist[_currentIndex].copyWith(
      isFavorite: _favoriteIds.contains(_playlist[_currentIndex].id),
    );
  }

  AudioPlayerService({AudioPlayerBackend? backend})
      : _backend = backend ?? AudioPlayerBackendFactory.create() {
    _loadFromStorage();
    _initAudioListeners();
    if (_playlist.isNotEmpty) {
      _recordHistory(_playlist[0]);
    }
  }

  void _loadFromStorage() {
    final storage = StorageService.instance;

    // 1. 恢复音量
    final savedVolume = storage.getVolume();
    if (savedVolume != null) {
      _volume = savedVolume.clamp(0.0, 1.0);
      _backend.setVolume(_volume);
    }

    // 2. 恢复播放模式
    final savedMode = storage.getPlaybackMode();
    if (savedMode != null) {
      for (final m in PlaybackMode.values) {
        if (m.name == savedMode) {
          _mode = m;
          break;
        }
      }
    }

    // 3. 恢复红心收藏
    final savedFavs = storage.getFavoriteIds();
    if (savedFavs != null) {
      _favoriteIds.clear();
      _favoriteIds.addAll(savedFavs);
    }

    // 4. 恢复历史记录
    final savedHistory = storage.getPlayHistory();
    if (savedHistory != null && savedHistory.isNotEmpty) {
      _playHistory.clear();
      _playHistory.addAll(savedHistory);
    }
  }

  void _initAudioListeners() {
    _positionSub = _backend.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _durationSub = _backend.onDurationChanged.listen((d) {
      if (d > Duration.zero) {
        _duration = d;
        notifyListeners();
      }
    });

    _playingSub = _backend.onPlayingChanged.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });

    _completeSub = _backend.onPlayerComplete.listen((_) {
      _onTrackCompleted();
    });
  }

  void _onTrackCompleted() {
    if (_pauseAfterCurrent) {
      pause();
      cancelSleepTimer();
      return;
    }
    if (_mode == PlaybackMode.singleLoop) {
      seek(Duration.zero);
      play();
    } else {
      next();
    }
  }

  // 导入外部歌单
  void addImportedPlaylist(ImportedPlaylist playlist) {
    _importedPlaylists.removeWhere((p) => p.id == playlist.id);
    _importedPlaylists.insert(0, playlist);
    for (final t in playlist.tracks) {
      if (!_playlist.any((p) => p.id == t.id)) {
        _playlist.add(t);
      }
    }
    notifyListeners();
  }

  // 一键替换为新歌单并播放
  void playPlaylist(List<Track> tracks, {int startIndex = 0}) {
    if (tracks.isEmpty) return;
    _playlist.clear();
    _playlist.addAll(tracks);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    _position = Duration.zero;
    _recordHistory(_playlist[_currentIndex]);
    playTrack(_playlist[_currentIndex]);
    _loadLyricIfNeed(_playlist[_currentIndex]);
  }

  void _loadLyricIfNeed(Track track) {
    if (track.lyrics.isEmpty && track.id.startsWith('netease_')) {
      OnlineMusicService.fetchTrackLyric(track.id).then((lyrics) {
        if (lyrics.isNotEmpty) {
          final idx = _playlist.indexWhere((t) => t.id == track.id);
          if (idx != -1) {
            _playlist[idx] = _playlist[idx].copyWith(lyrics: lyrics);
            notifyListeners();
          }
        }
      });
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
    final track = currentTrack;
    if (track != null) {
      _executeRealPlay(track);
    }
    notifyListeners();
  }

  void pause() {
    _isPlaying = false;
    _backend.pause();
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
    _isPlaying = true;
    _executeRealPlay(_playlist[_currentIndex]);
    notifyListeners();
    _loadLyricIfNeed(_playlist[_currentIndex]);
  }

  Future<void> _executeRealPlay(Track track) async {
    try {
      if (track.audioUrl != null && track.audioUrl!.isNotEmpty) {
        await _backend.play(track.audioUrl!);
      } else if (track.localPath != null && track.localPath!.isNotEmpty) {
        await _backend.play(track.localPath!);
      } else {
        await _backend.resume();
      }
      await _backend.setVolume(_volume);
    } catch (e) {
      debugPrint('[AudioPlayerService] 真实音频播放调度异常: $e');
    }
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
      _executeRealPlay(_playlist[_currentIndex]);
    }
    notifyListeners();
  }

  void previous() {
    if (_playlist.isEmpty) return;
    if (_position.inSeconds > 3) {
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
      _executeRealPlay(_playlist[_currentIndex]);
    }
    notifyListeners();
  }

  void seek(Duration target) {
    final curDuration = duration;
    if (target < Duration.zero) {
      _position = Duration.zero;
    } else if (curDuration > Duration.zero && target > curDuration) {
      _position = curDuration;
    } else {
      _position = target;
    }
    _backend.seek(_position);
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
    StorageService.instance.saveFavoriteIds(_favoriteIds);
    notifyListeners();
  }

  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  void setVolume(double val) {
    _volume = val.clamp(0.0, 1.0);
    _backend.setVolume(_volume);
    StorageService.instance.saveVolume(_volume);
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
    StorageService.instance.savePlaybackMode(_mode.name);
    notifyListeners();
  }

  void setPlaybackMode(PlaybackMode mode) {
    _mode = mode;
    StorageService.instance.savePlaybackMode(_mode.name);
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
    StorageService.instance.savePlayHistory(_playHistory);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completeSub?.cancel();
    _sleepTimer?.cancel();
    _backend.dispose();
    super.dispose();
  }
}
