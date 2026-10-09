import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'track_model.dart';
import 'player_backend.dart';
import 'windows_smtc_service.dart';
import 'windows_tray_service.dart';
import 'local_music_service.dart';
import 'equalizer_manager.dart';
import '../sources/online_music_service.dart';
import '../sources/lx_script_sandbox.dart';
import '../sources/lx_source_model.dart';
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

  /// 真机与正式客户端初始曲库绝对纯净 (零 Mock 数据)，仅在离线单测模式保留测试夹具
  static bool get isRunningInTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final List<Track> _playlist = isRunningInTest ? List.from(mockPresetTracks) : [];
  final List<Track> _playHistory = [];
  final Set<String> _favoriteIds = {};
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
  Timer? _playbackNoticeTimer;
  Timer? _autoSkipTimer;
  int _consecutiveFailures = 0;
  bool _isSwitchingSource = false;
  String? _currentLoadedTrackId;
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

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

  AudioQuality? _actualQuality;
  AudioQuality? get actualQuality => _actualQuality;
  String get actualQualityLabel {
    if (_actualQuality != null) {
      switch (_actualQuality!) {
        case AudioQuality.flac24bit:
          return 'Hi-Res · 24bit';
        case AudioQuality.flac:
          return 'SQ · FLAC';
        case AudioQuality.k320k:
          return 'HQ · 320K';
        case AudioQuality.k128k:
          return '标准 · 128K';
      }
    }
    final url = currentTrack?.audioUrl?.toLowerCase() ?? '';
    if (url.contains('flac24bit') || url.contains('24bit') || url.contains('hires')) {
      return 'Hi-Res · 24bit';
    }
    if (url.contains('flac') || url.contains('ape') || url.contains('sq')) {
      return 'SQ · FLAC';
    }
    if (url.contains('320k') || url.contains('hq')) {
      return 'HQ · 320K';
    }
    return '标准 · 128K';
  }

  void _setPlaybackNotice(String message, {int autoDismissSeconds = 4}) {
    if (_isDisposed) return;
    _playbackNoticeTimer?.cancel();
    _playbackNotice = message;
    notifyListeners();
    if (autoDismissSeconds > 0) {
      _playbackNoticeTimer = Timer(Duration(seconds: autoDismissSeconds), () {
        if (_isDisposed) return;
        _playbackNotice = null;
        notifyListeners();
      });
    }
  }

  void clearPlaybackNotice() {
    if (_isDisposed) return;
    _playbackNoticeTimer?.cancel();
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

  /// 扫描移动端/系统常见音乐存储路径
  Future<int> scanDeviceMusicDirectories() async {
    int totalAdded = 0;
    final candidateDirs = [
      '/sdcard/Music',
      '/sdcard/Download',
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Android/media',
    ];
    for (final d in candidateDirs) {
      if (Directory(d).existsSync()) {
        totalAdded += await LocalMusicService.instance.scanDirectory(d);
      }
    }
    notifyListeners();
    return totalAdded;
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
  int _playSessionId = 0;

  AudioPlayerService({AudioPlayerBackend? backend})
      : _backend = backend ?? AudioPlayerBackendFactory.create() {
    _loadFromStorage();
    _initAudioListeners();
    _initEqualizerListener();
    _initSmtc();
    WindowsTrayService.instance.init();
  }

  void _initEqualizerListener() {
    EqualizerManager.instance.addListener(_onEqualizerChanged);
  }

  void _onEqualizerChanged() {
    // 监听声学均衡器配置变更，联动通知状态刷新
    notifyListeners();
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

    // 3. 恢复红心收藏与实体 (带沙盒历史脏数据自动清洗升级守卫)
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

    // 历史假数据升级自动清洗守卫：
    // 若尚未清洗过，且本地收藏只包含历史老预设 ID（如 track-1, track-3, track-5, track-6 或老预设4首），
    // 则彻底清空并持久化重置为干净状态，避免用户真机沙盒出现未收藏的默认4首歌。
    if (!storage.hasCleanedLegacyFavorites()) {
      const legacyMockIds = {'track-1', 'track-3', 'track-5', 'track-6', 'netease_160488', 'netease_1357375695', 'netease_448316848', 'netease_1330348068'};
      if (_favoriteIds.isNotEmpty && _favoriteIds.every((id) => legacyMockIds.contains(id))) {
        _favoriteIds.clear();
        _cachedFavoriteTracks.clear();
        storage.saveFavoriteIds(_favoriteIds);
        storage.saveFavoriteTracks([]);
      } else {
        final toRemove = _favoriteIds.where((id) => id.startsWith('track-')).toList();
        if (toRemove.isNotEmpty) {
          _favoriteIds.removeAll(toRemove);
          for (final rid in toRemove) {
            _cachedFavoriteTracks.remove(rid);
          }
          storage.saveFavoriteIds(_favoriteIds);
          storage.saveFavoriteTracks(_cachedFavoriteTracks.values.toList());
        }
      }
      storage.markCleanedLegacyFavorites();
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
        : 'https://p2.music.126.net/L3cE6x8y2g6n7Q0o4w0z_g==/109951165123987114.jpg';

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

  // 追加多首歌曲到当前待播列表
  void appendPlaylist(List<Track> tracks) {
    if (tracks.isEmpty) return;
    _playlist.addAll(tracks);
    notifyListeners();
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
    final track = currentTrack;
    if (track == null) return;

    // 若当前音源已在声卡中装载就绪且处于暂停态，直接恢复播放，保持当前进度
    if (!_isPlaying && _currentLoadedTrackId == track.id) {
      _isPlaying = true;
      _backend.resume().catchError((e) {
        debugPrint('[AudioPlayerService] 恢复播放异常，自动重新加载: $e');
        _executeRealPlay(track);
      });
      WindowsSmtcService.instance.updatePlaybackState(true);
      notifyListeners();
      return;
    }

    _isPlaying = true;
    _executeRealPlay(track);
    notifyListeners();
  }

  void pause() {
    _playSessionId++;
    _autoSkipTimer?.cancel();
    _isPlaying = false;
    _backend.pause();
    WindowsSmtcService.instance.updatePlaybackState(false);
    notifyListeners();
  }

  void playTrack(Track track) {
    final isSameTrack = currentTrack?.id == track.id;
    final index = _playlist.indexWhere((t) => t.id == track.id);
    if (index != -1) {
      _currentIndex = index;
    } else {
      _playlist.insert(0, track);
      _currentIndex = 0;
    }

    // 若点击的正是当前暂停曲目，无缝恢复播放
    if (isSameTrack && !_isPlaying && _currentLoadedTrackId == track.id) {
      play();
      return;
    }

    _position = Duration.zero;
    _currentLoadedTrackId = null;
    _recordHistory(_playlist[_currentIndex]);
    _isPlaying = true;
    WindowsTrayService.instance.updateTooltip(_playlist[_currentIndex]);
    _executeRealPlay(_playlist[_currentIndex]);
    notifyListeners();
    _loadLyricIfNeed(_playlist[_currentIndex]);
  }

  Future<void> _executeRealPlay(Track track) async {
    final session = ++_playSessionId;
    _autoSkipTimer?.cancel();
    try {
      _playbackNotice = null;
      _actualQuality = null;
      // 0. 本地文件优先直接播放，不经过网络音源解析
      if (track.localPath != null && track.localPath!.isNotEmpty) {
        final path = track.localPath!.toLowerCase();
        if (path.endsWith('.flac') || path.endsWith('.wav')) {
          _actualQuality = AudioQuality.flac;
        } else {
          _actualQuality = AudioQuality.k320k;
        }
        await _backend.play(track.localPath!);
        if (session != _playSessionId) return;
        _currentLoadedTrackId = track.id;
      } else {
        String? playUrl = track.audioUrl;

        // 若当前音频流不存在或为受限/失效链接，统一调用高速解析管道
        final bool isUnusableUrl = playUrl == null ||
            playUrl.isEmpty ||
            playUrl.contains('music.163.com/song/media/outer/url') ||
            playUrl.contains('soundhelix.com') ||
            playUrl.contains('nxinxz.com') ||
            playUrl.contains('588957081') ||
            playUrl.contains('/nf/');

        if (isUnusableUrl) {
          final resolved = await OnlineMusicService.resolvePlayableAudioUrl(
            track.title,
            track.artist,
            trackId: track.id,
            defaultUrl: playUrl,
          );
          if (session != _playSessionId) return;
          if (resolved != null && resolved.isNotEmpty) {
            playUrl = resolved;
            final idx = _playlist.indexWhere((t) => t.id == track.id);
            if (idx != -1) {
              final activeSource = _inferSourceFromUrl(playUrl, track.source);
              _playlist[idx] = _playlist[idx].copyWith(audioUrl: playUrl, source: activeSource);
            }
          }
        } else {
          // 若已有外链，轻量展开校验重定向
          final unwrapped = await OnlineMusicService.unwrapRedirects(playUrl);
          if (session != _playSessionId) return;
          if (unwrapped.isNotEmpty && !unwrapped.contains('/404') && !unwrapped.contains('588957081') && !unwrapped.contains('/nf/')) {
            playUrl = unwrapped;
          } else {
            // 若外链重定向后失效，启动一次快速换源
            final resolved = await OnlineMusicService.resolvePlayableAudioUrl(
              track.title,
              track.artist,
              trackId: track.id,
              forceRefresh: true,
            );
            if (session != _playSessionId) return;
            if (resolved != null && resolved.isNotEmpty) {
              playUrl = resolved;
              final idx = _playlist.indexWhere((t) => t.id == track.id);
              if (idx != -1) {
                final activeSource = _inferSourceFromUrl(playUrl, track.source);
                _playlist[idx] = _playlist[idx].copyWith(audioUrl: playUrl, source: activeSource);
              }
            }
          }
        }

        if (session != _playSessionId) return;

        if (playUrl != null && playUrl.isNotEmpty) {
          final safePlayUrl = OnlineMusicService.upgradeToSecureUrl(playUrl);
          if (_actualQuality == null) {
            final lower = safePlayUrl.toLowerCase();
            if (lower.contains('flac24bit') || lower.contains('24bit') || lower.contains('hires')) {
              _actualQuality = AudioQuality.flac24bit;
            } else if (lower.contains('flac') || lower.contains('ape') || lower.contains('sq')) {
              _actualQuality = AudioQuality.flac;
            } else if (lower.contains('320k') || lower.contains('hq')) {
              _actualQuality = AudioQuality.k320k;
            } else {
              _actualQuality = LxSourceEngine.instance.preferredQuality;
            }
          }
          await _backend.play(safePlayUrl);
          if (session != _playSessionId) return;
          _currentLoadedTrackId = track.id;
          _consecutiveFailures = 0;
        } else {
          throw Exception('全网音源暂未匹配到有效可播放音频流');
        }
      }
      if (session != _playSessionId) return;
      await _backend.setVolume(_volume);
      if (session != _playSessionId) return;
      WindowsSmtcService.instance.updateMetadata(track);
      WindowsSmtcService.instance.updatePlaybackState(true);
      WindowsSmtcService.instance.updateTimeline(_position, duration);
      WindowsTrayService.instance.updateTooltip(track);
      notifyListeners();
    } catch (e) {
      if (session != _playSessionId) return;
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
        if (session != _playSessionId) return;
        if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
          final safeFallbackUrl = OnlineMusicService.upgradeToSecureUrl(fallbackUrl);
          await _backend.play(safeFallbackUrl);
          if (session != _playSessionId) return;
          _consecutiveFailures = 0;
          final idx = _playlist.indexWhere((t) => t.id == track.id);
          if (idx != -1) {
            final activeSource = _inferSourceFromUrl(fallbackUrl, track.source);
            _playlist[idx] = _playlist[idx].copyWith(audioUrl: fallbackUrl, source: activeSource);
          }
          await _backend.setVolume(_volume);
          if (session != _playSessionId) return;
          WindowsSmtcService.instance.updateMetadata(track);
          WindowsSmtcService.instance.updatePlaybackState(true);
          WindowsSmtcService.instance.updateTimeline(_position, duration);
          WindowsTrayService.instance.updateTooltip(track);
          return;
        }
      } catch (retryErr) {
        debugPrint('[AudioPlayerService] 换源重试亦异常: $retryErr');
      }

      if (_isDisposed || session != _playSessionId) return;

      // 3. 所有音源均不可用时，给用户清晰浮动提示并快速自动跳播下一首 (500ms 快速平滑切歌)
      _consecutiveFailures++;
      if (_consecutiveFailures >= 5) {
        _setPlaybackNotice('连续多首歌曲全网暂无可播放音频，已为您自动暂停播放', autoDismissSeconds: 5);
        _isPlaying = false;
        _consecutiveFailures = 0;
        if (!_isDisposed) notifyListeners();
        return;
      }

      _setPlaybackNotice('「${track.title}」全网音源暂不可用，已自动跳播下一首', autoDismissSeconds: 3);
      _autoSkipTimer?.cancel();
      if (_isDisposed) return;
      _autoSkipTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isDisposed || session != _playSessionId || _playlist.isEmpty || !_isPlaying) return;
        next();
      });
    }
  }

  /// 依据解析出的物理音频直链，诚实推断真实的声学音源标签
  static String _inferSourceFromUrl(String url, String originalSource) {
    if (url.contains('kuwo.cn')) return 'kuwo-sq';
    if (url.contains('126.net') || url.contains('163.com')) return 'netease-online';
    if (url.contains('qq.com') || url.contains('tencent.com')) return 'qq-online';
    if (url.contains('kugou.com')) return 'kugou-online';
    if (url.contains('migu.cn')) return 'migu-online';
    if (url.contains('apple.com') || url.contains('mzstatic.com')) return 'itunes-preview';
    if (url.contains('mellow') || originalSource.contains('preset') || originalSource.contains('mellow')) return 'mellow-preset';
    return originalSource;
  }

  /// 主动为当前歌曲或指定歌曲切换音源 (酷我/网易云/QQ/酷狗/咪咕/润音官方/iTunes/落雪脚本)
  Future<bool> switchSource(Track track, String newSource) async {
    if (_isSwitchingSource) {
      debugPrint('[AudioPlayerService] 音源切换中，忽略高频重复触发');
      return false;
    }
    _isSwitchingSource = true;
    final currentPos = _position;
    final isCurrent = currentTrack?.id == track.id;
    try {
      String? newUrl = await OnlineMusicService.resolveUrlFromSpecificSource(
        track.title,
        track.artist,
        newSource,
        trackId: track.id,
      );

      // 若第三方社区脚本私有服务器离线或超时，自动无缝启动全网高保真多源平滑兜底
      if (newUrl == null || newUrl.isEmpty) {
        newUrl = await OnlineMusicService.resolvePlayableAudioUrl(
          track.title,
          track.artist,
          defaultUrl: track.audioUrl,
          trackId: track.id,
        );
      }

      if (newUrl != null && newUrl.isNotEmpty) {
        final updated = track.copyWith(source: newSource, audioUrl: newUrl);
        final idx = _playlist.indexWhere((t) => t.id == track.id);
        if (idx != -1) {
          _playlist[idx] = updated;
        }
        if (isCurrent) {
          if (idx == -1 && _playlist.isNotEmpty && _currentIndex < _playlist.length) {
            _playlist[_currentIndex] = updated;
          }
          await _backend.play(newUrl);
          if (currentPos > Duration.zero) {
            await _backend.seek(currentPos);
          }
          await _backend.resume();
          _isPlaying = true;
        }
        _setPlaybackNotice('已成功切换至【${formatSourceDisplayName(newSource)}】音源播放', autoDismissSeconds: 3);
        notifyListeners(); // 显式触发全局 UI 与弹窗即时刷新
        return true;
      }
    } catch (e) {
      debugPrint('[AudioPlayerService] 主动切换音源失败: $e');
    } finally {
      _isSwitchingSource = false;
    }
    _setPlaybackNotice('切换音源失败，【${formatSourceDisplayName(newSource)}】暂未收录该歌曲', autoDismissSeconds: 4);
    notifyListeners();
    return false;
  }

  static String formatSourceDisplayName(String source) {
    if (source.contains('sixyin')) return '六音无损源';
    if (source.contains('huibq')) return 'Huibq无损源';
    if (source.contains('ikun')) return 'ikun加速源';
    if (source.contains('lx_official') || source == 'lx_official_builtin') return '落雪官方源';
    if (source.contains('alger')) return 'Alger官方源';
    if (source.contains('kuwo') || source == 'kw') return '酷我高保真';
    if (source.contains('netease') || source == 'wy') return '网易云音乐';
    if (source.contains('qq') || source.contains('tx') || source.contains('tencent')) return 'QQ音乐';
    if (source.contains('kugou') || source == 'kg') return '酷狗音乐';
    if (source.contains('migu') || source == 'mg') return '咪咕音乐';
    if (source.contains('itunes')) return 'iTunes官方';
    if (source.contains('preset')) return '原生高保真';
    if (source.contains('mellow')) return '润音官方保真源';
    if (source.contains('lx') || source.contains('custom') || source.contains('script')) return '落雪扩展源';
    if (source.contains('local')) return '本地音频';
    return '内置音源';
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
    _currentLoadedTrackId = null;
    _recordHistory(_playlist[_currentIndex]);
    _isPlaying = true;
    WindowsTrayService.instance.updateTooltip(_playlist[_currentIndex]);
    _executeRealPlay(_playlist[_currentIndex]);
    notifyListeners();
    _loadLyricIfNeed(_playlist[_currentIndex]);
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
    _currentLoadedTrackId = null;
    _recordHistory(_playlist[_currentIndex]);
    _isPlaying = true;
    WindowsTrayService.instance.updateTooltip(_playlist[_currentIndex]);
    _executeRealPlay(_playlist[_currentIndex]);
    notifyListeners();
    _loadLyricIfNeed(_playlist[_currentIndex]);
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
    try {
      _backend.seek(_position);
    } catch (e) {
      debugPrint('[AudioPlayerService] seek exception caught: $e');
    }
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

  void clearHistory() => clearPlayHistory();

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
    if (_isDisposed) return;
    _playHistory.removeWhere((t) => t.id == track.id);
    _playHistory.insert(0, track);
    if (_playHistory.length > 50) {
      _playHistory.removeLast();
    }
    StorageService.instance.savePlayHistory(_playHistory);
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completeSub?.cancel();
    _sleepTimer?.cancel();
    _playbackNoticeTimer?.cancel();
    _autoSkipTimer?.cancel();
    EqualizerManager.instance.removeListener(_onEqualizerChanged);
    _backend.dispose();
    WindowsSmtcService.instance.dispose();
    super.dispose();
  }
}
