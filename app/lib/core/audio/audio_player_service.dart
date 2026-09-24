import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'track_model.dart';
import 'player_backend.dart';
import 'windows_smtc_service.dart';
import 'windows_tray_service.dart';
import 'local_music_service.dart';
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
  final Map<String, Track> _cachedFavoriteTracks = {};
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
  String? _playbackNotice;

  // Getters
  List<Track> get playlist => List.unmodifiable(_playlist);
  List<Track> get playHistory => List.unmodifiable(_playHistory);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  int get currentIndex => _currentIndex;
  Duration get position => _position;
  Duration get currentPosition => _position;
  Duration get duration => _duration > Duration.zero ? _duration : (currentTrack?.duration ?? Duration.zero);
  bool get isPlaying => _isPlaying;
  PlaybackMode get playbackMode => _mode;
  double get volume => _volume;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  int get sleepTimerRemainingSeconds => _sleepTimerRemainingSeconds;
  bool get pauseAfterCurrent => _pauseAfterCurrent;
  String? get playbackNotice => _playbackNotice;

  void clearPlaybackNotice() {
    if (_playbackNotice != null) {
      _playbackNotice = null;
      notifyListeners();
    }
  }

  List<ImportedPlaylist> get importedPlaylists => List.unmodifiable(_importedPlaylists);
  List<Track> get localTracks => LocalMusicService.instance.localTracks;
  List<String> get localDirectories => LocalMusicService.instance.scannedDirectories;

  Future<int> scanLocalDirectory(String path) async {
    final count = await LocalMusicService.instance.scanDirectory(path);
    notifyListeners();
    return count;
  }

  void addLocalTrack(Track track) {
    LocalMusicService.instance.addLocalTrack(track);
    notifyListeners();
  }

  void removeLocalTrack(String trackId) {
    LocalMusicService.instance.removeLocalTrack(trackId);
    notifyListeners();
  }

  void clearLocalTracks() {
    LocalMusicService.instance.clearLocalTracks();
    notifyListeners();
  }

  void playLocalMusic({int startIndex = 0}) {
    final list = localTracks;
    if (list.isEmpty) return;
    playPlaylist(list, startIndex: startIndex);
  }

  List<Track> get favoriteTracks {
    final list = <Track>[];
    final addedIds = <String>{};
    for (final id in _favoriteIds) {
      if (!addedIds.add(id)) continue;
      // 1. 优先从缓存实体中取
      if (_cachedFavoriteTracks.containsKey(id)) {
        list.add(_cachedFavoriteTracks[id]!.copyWith(isFavorite: true));
        continue;
      }
      // 2. 从当前待播列表中取
      final fromPl = _playlist.where((t) => t.id == id).firstOrNull;
      if (fromPl != null) {
        _cachedFavoriteTracks[id] = fromPl;
        list.add(fromPl.copyWith(isFavorite: true));
        continue;
      }
      // 3. 从全局已知曲库中查找
      final known = findKnownTrackById(id);
      if (known != null) {
        _cachedFavoriteTracks[id] = known;
        list.add(known.copyWith(isFavorite: true));
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

  double _lastNonZeroVolume = 0.8;

  AudioPlayerService({AudioPlayerBackend? backend})
      : _backend = backend ?? AudioPlayerBackendFactory.create() {
    _loadFromStorage();
    _initAudioListeners();
    _initSmtc();
    WindowsTrayService.instance.init();
  }

  void _initSmtc() {
    WindowsSmtcService.instance.init(
      onAction: (action) {
        switch (action) {
          case SmtcButtonAction.play:
            play();
            break;
          case SmtcButtonAction.pause:
            pause();
            break;
          case SmtcButtonAction.togglePlay:
            togglePlay();
            break;
          case SmtcButtonAction.next:
            next();
            break;
          case SmtcButtonAction.previous:
            previous();
            break;
          case SmtcButtonAction.stop:
            pause();
            seek(Duration.zero);
            break;
        }
      },
      onSeek: (pos) => seek(pos),
    );
  }

  void _loadFromStorage() {
    final storage = StorageService.instance;

    // 1. 恢复音量
    final savedVolume = storage.getVolume();
    if (savedVolume != null) {
      _volume = savedVolume.clamp(0.0, 1.0);
      if (_volume > 0) _lastNonZeroVolume = _volume;
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

    // 3. 恢复红心收藏与实体
    final savedFavs = storage.getFavoriteIds();
    if (savedFavs != null) {
      _favoriteIds.clear();
      _favoriteIds.addAll(savedFavs);
    }
    final savedFavTracks = storage.getFavoriteTracks();
    if (savedFavTracks != null) {
      for (final t in savedFavTracks) {
        _cachedFavoriteTracks[t.id] = t;
      }
    }

    // 4. 恢复历史记录
    final savedHistory = storage.getPlayHistory();
    if (savedHistory != null && savedHistory.isNotEmpty) {
      _playHistory.clear();
      _playHistory.addAll(savedHistory);
    }

    // 5. 恢复导入歌单
    final savedPlaylists = storage.getImportedPlaylists();
    if (savedPlaylists != null && savedPlaylists.isNotEmpty) {
      _importedPlaylists.clear();
      _importedPlaylists.addAll(savedPlaylists);
    }
  }

  /// 从本地持久化重新载入（在多端云同步或离线快照合并后热刷新）
  void reloadFromStorage() {
    _loadFromStorage();
    notifyListeners();
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
        WindowsSmtcService.instance.updatePlaybackState(playing);
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
    StorageService.instance.saveImportedPlaylists(_importedPlaylists);
    notifyListeners();
  }

  /// 创建自建歌单
  ImportedPlaylist createCustomPlaylist(
    String title, {
    String? description,
    String? coverUrl,
    List<Track>? initialTracks,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tracks = List<Track>.from(initialTracks ?? []);
    final defaultCover = tracks.isNotEmpty
        ? tracks.first.coverUrl
        : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80';

    final pl = ImportedPlaylist(
      id: 'custom-$now',
      title: title.trim().isEmpty ? '我的自建歌单' : title.trim(),
      coverUrl: (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : defaultCover,
      description: description ?? '自建个性化歌单',
      trackCount: tracks.length,
      tracks: tracks,
      isCustom: true,
      createdAt: now,
    );

    _importedPlaylists.insert(0, pl);
    for (final t in tracks) {
      if (!_playlist.any((p) => p.id == t.id)) {
        _playlist.add(t);
      }
    }
    StorageService.instance.saveImportedPlaylists(_importedPlaylists);
    notifyListeners();
    return pl;
  }

  /// 删除歌单 (自建或已导入)
  bool deletePlaylist(String playlistId) {
    final prevLen = _importedPlaylists.length;
    _importedPlaylists.removeWhere((p) => p.id == playlistId);
    if (_importedPlaylists.length != prevLen) {
      StorageService.instance.saveImportedPlaylists(_importedPlaylists);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 重命名与编辑歌单
  bool renamePlaylist(String playlistId, String newTitle, [String? newDescription]) {
    final idx = _importedPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final old = _importedPlaylists[idx];
      _importedPlaylists[idx] = old.copyWith(
        title: newTitle.trim().isEmpty ? old.title : newTitle.trim(),
        description: newDescription ?? old.description,
      );
      StorageService.instance.saveImportedPlaylists(_importedPlaylists);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 将曲目添加到指定歌单 (若已存在则返回 false，未存在则加入并返回 true)
  bool addTrackToPlaylist(String playlistId, Track track) {
    final idx = _importedPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final old = _importedPlaylists[idx];
      if (old.tracks.any((t) => t.id == track.id)) {
        return false; // 已收录
      }
      final newTracks = List<Track>.from(old.tracks)..add(track);
      _importedPlaylists[idx] = old.copyWith(
        tracks: newTracks,
        trackCount: newTracks.length,
        coverUrl: (old.tracks.isEmpty && track.coverUrl.isNotEmpty) ? track.coverUrl : old.coverUrl,
      );
      if (!_playlist.any((p) => p.id == track.id)) {
        _playlist.add(track);
      }
      StorageService.instance.saveImportedPlaylists(_importedPlaylists);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 从指定歌单中移除曲目
  bool removeTrackFromPlaylist(String playlistId, String trackId) {
    final idx = _importedPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final old = _importedPlaylists[idx];
      final newTracks = old.tracks.where((t) => t.id != trackId).toList();
      _importedPlaylists[idx] = old.copyWith(
        tracks: newTracks,
        trackCount: newTracks.length,
      );
      StorageService.instance.saveImportedPlaylists(_importedPlaylists);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 检查某首歌曲是否已收录在指定歌单中
  bool isTrackInPlaylist(String playlistId, String trackId) {
    final pl = _importedPlaylists.where((p) => p.id == playlistId).firstOrNull;
    if (pl == null) return false;
    return pl.tracks.any((t) => t.id == trackId);
  }

  /// 一键将我喜欢的音乐批量导出为自建歌单
  ImportedPlaylist? exportFavoritesToPlaylist(String playlistTitle) {
    final favs = favoriteTracks;
    return createCustomPlaylist(
      playlistTitle.trim().isEmpty ? '我的心动精选歌单' : playlistTitle.trim(),
      description: '由「我喜欢的音乐」心动收藏一键导出 · 共 ${favs.length} 首',
      initialTracks: favs,
    );
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
    if (track.lyrics.isEmpty) {
      OnlineMusicService.fetchTrackLyric(track.id, title: track.title, artist: track.artist).then((lyrics) {
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
    WindowsSmtcService.instance.updatePlaybackState(false);
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
    WindowsTrayService.instance.updateTooltip(_playlist[_currentIndex]);
    _executeRealPlay(_playlist[_currentIndex]);
    notifyListeners();
    _loadLyricIfNeed(_playlist[_currentIndex]);
  }

  Future<void> _executeRealPlay(Track track) async {
    try {
      _playbackNotice = null;
      // 0. 本地文件优先直接播放，不经过网络音源解析
      if (track.localPath != null && track.localPath!.isNotEmpty) {
        await _backend.play(track.localPath!);
      } else {
        String? playUrl = track.audioUrl;
        // 1. 如果没有有效播放流或为假/受限链接，智能解析真实高保真音源 (消灭 404)
        if (playUrl == null ||
            playUrl.isEmpty ||
            playUrl.contains('soundhelix.com') ||
            playUrl.contains('nxinxz.com') ||
            playUrl.contains('music.163.com/song/media/outer/url')) {
          final resolved = await OnlineMusicService.resolvePlayableAudioUrl(
            track.title,
            track.artist,
            trackId: track.id,
            defaultUrl: playUrl,
          );
          if (resolved != null && resolved.isNotEmpty) {
            playUrl = resolved;
            final idx = _playlist.indexWhere((t) => t.id == track.id);
            if (idx != -1) {
              _playlist[idx] = _playlist[idx].copyWith(audioUrl: playUrl);
            }
          }
        }

        if (playUrl != null && playUrl.isNotEmpty) {
          await _backend.play(playUrl);
        } else {
          await _backend.resume();
        }
      }
      await _backend.setVolume(_volume);
      WindowsSmtcService.instance.updateMetadata(track);
      WindowsSmtcService.instance.updatePlaybackState(true);
      WindowsSmtcService.instance.updateTimeline(_position, duration);
      WindowsTrayService.instance.updateTooltip(track);
    } catch (e) {
      debugPrint('[AudioPlayerService] 初始音频播放失败，尝试静默换源: $e');
      if (track.localPath != null && track.localPath!.isNotEmpty) {
        return;
      }
      // 2. 发生网络波动或 404 限制时，启动静默 Fallback 换源重试
      try {
        final fallbackUrl = await OnlineMusicService.resolvePlayableAudioUrl(
          track.title,
          track.artist,
          trackId: track.id,
          forceRefresh: true,
        );
        if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
          await _backend.play(fallbackUrl);
          final idx = _playlist.indexWhere((t) => t.id == track.id);
          if (idx != -1) {
            _playlist[idx] = _playlist[idx].copyWith(audioUrl: fallbackUrl);
          }
          await _backend.setVolume(_volume);
          WindowsSmtcService.instance.updateMetadata(track);
          WindowsSmtcService.instance.updatePlaybackState(true);
          WindowsSmtcService.instance.updateTimeline(_position, duration);
          WindowsTrayService.instance.updateTooltip(track);
          return;
        }
      } catch (retryErr) {
        debugPrint('[AudioPlayerService] 换源重试亦异常: $retryErr');
      }

      _playbackNotice = '歌曲「${track.title}」音频资源加载失败，可能需要专属授权或网络受限';
      notifyListeners();
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
    WindowsSmtcService.instance.updateTimeline(_position, curDuration);
    notifyListeners();
  }

  void toggleFavorite([String? trackId, Track? trackModel]) {
    final id = trackId ?? trackModel?.id ?? currentTrack?.id;
    if (id == null) return;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      _cachedFavoriteTracks.remove(id);
    } else {
      _favoriteIds.add(id);
      // 捕获实体并缓存持久化
      final targetTrack = trackModel ??
          (currentTrack?.id == id ? currentTrack : null) ??
          _playlist.where((t) => t.id == id).firstOrNull ??
          findKnownTrackById(id);
      if (targetTrack != null) {
        _cachedFavoriteTracks[id] = targetTrack;
      }
    }
    StorageService.instance.saveFavoriteIds(_favoriteIds);
    StorageService.instance.saveFavoriteTracks(_cachedFavoriteTracks.values.toList());
    notifyListeners();
  }

  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  void setVolume(double val) {
    _volume = val.clamp(0.0, 1.0);
    if (_volume > 0) _lastNonZeroVolume = _volume;
    _backend.setVolume(_volume);
    StorageService.instance.saveVolume(_volume);
    notifyListeners();
  }

  void toggleMute() {
    if (_volume > 0) {
      setVolume(0);
    } else {
      setVolume(_lastNonZeroVolume);
    }
  }

  void clearPlayHistory() {
    _playHistory.clear();
    StorageService.instance.clearPlayHistory();
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
    WindowsSmtcService.instance.clear();
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
    WindowsSmtcService.instance.dispose();
    super.dispose();
  }
}
