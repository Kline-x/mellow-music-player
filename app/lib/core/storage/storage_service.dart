import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/track_model.dart';
import '../sources/online_music_service.dart';
import '../sync/webdav_sync_service.dart';

/// 本地轻量化 KV 数据落盘持久化服务 (基于 SharedPreferences)
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();

  SharedPreferences? _prefs;

  StorageService._();

  /// 允许在测试中注入 mock 或重置
  static void setMockInstance(StorageService mock) {
    _instance = mock;
  }

  Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('StorageService 未初始化，请先调用 StorageService.instance.init()');
    }
    return _prefs!;
  }

  // Keys 常量
  static const _keyIsDarkMode = 'mellow_theme_is_dark';
  static const _keyAccentType = 'mellow_theme_accent_type';
  static const _keyGlowIntensity = 'mellow_theme_glow_intensity';
  static const _keyVolume = 'mellow_audio_volume';
  static const _keyPlaybackMode = 'mellow_audio_playback_mode';
  static const _keyFavoriteIds = 'mellow_audio_favorite_ids';
  static const _keyFavoriteTracks = 'mellow_audio_favorite_tracks';
  static const _keyPlayHistory = 'mellow_audio_play_history';
  static const _keyImportedPlaylists = 'mellow_audio_imported_playlists';
  static const _keyFloatingLyricEnabled = 'mellow_floating_lyric_enabled';
  static const _keyFloatingLyricLocked = 'mellow_floating_lyric_locked';
  static const _keyFloatingLyricAlwaysOnTop = 'mellow_floating_lyric_on_top';
  static const _keyFloatingLyricPosX = 'mellow_floating_lyric_pos_x';
  static const _keyFloatingLyricPosY = 'mellow_floating_lyric_pos_y';
  static const _keyFloatingLyricFontSize = 'mellow_floating_lyric_font_size';
  static const _keyLocalTracks = 'mellow_audio_local_tracks';
  static const _keyLocalDirectories = 'mellow_audio_local_directories';
  static const _keyMinimizeToTray = 'mellow_minimize_to_tray';
  static const _keyFollowedArtists = 'mellow_followed_artists';
  static const _keyEqualizerGains = 'mellow_equalizer_gains';
  static const _keyEqualizerPreset = 'mellow_equalizer_preset';
  static const _keyEqualizerEnabled = 'mellow_equalizer_enabled';
  static const _keyWebDavConfig = 'mellow_webdav_config';
  static const _keyCustomScripts = 'mellow_custom_scripts';
  static const _keyActiveSourceId = 'mellow_active_source_id';
  static const _keyPreferredQuality = 'mellow_preferred_quality';
  static const _keySearchHistory = 'mellow_search_history';

  // --- 搜索历史记录持久化 ---
  List<String> getSearchHistory() => _prefs?.getStringList(_keySearchHistory) ?? [];
  Future<bool> saveSearchHistory(List<String> history) async =>
      (await _prefs?.setStringList(_keySearchHistory, history)) ?? false;
  Future<void> addSearchHistory(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    final list = getSearchHistory().where((k) => k != clean).toList();
    list.insert(0, clean);
    if (list.length > 30) list.removeRange(30, list.length);
    await saveSearchHistory(list);
  }
  Future<void> removeSearchHistory(String keyword) async {
    final list = getSearchHistory().where((k) => k != keyword).toList();
    await saveSearchHistory(list);
  }
  Future<void> clearSearchHistory() async {
    await _prefs?.remove(_keySearchHistory);
  }

  // --- 系统托盘与常驻偏好 ---
  bool getMinimizeToTray() => _prefs?.getBool(_keyMinimizeToTray) ?? true;
  Future<bool> saveMinimizeToTray(bool value) async =>
      (await _prefs?.setBool(_keyMinimizeToTray, value)) ?? false;

  // --- 均衡器 EQ 偏好 ---
  List<double>? getEqualizerGains() {
    final raw = _prefs?.getStringList(_keyEqualizerGains);
    if (raw == null) return null;
    return raw.map((s) => double.tryParse(s) ?? 0.0).toList();
  }
  Future<bool> saveEqualizerGains(List<double> gains) async {
    final list = gains.map((g) => g.toStringAsFixed(1)).toList();
    return (await _prefs?.setStringList(_keyEqualizerGains, list)) ?? false;
  }
  String? getEqualizerPreset() => _prefs?.getString(_keyEqualizerPreset);
  Future<bool> saveEqualizerPreset(String preset) async =>
      (await _prefs?.setString(_keyEqualizerPreset, preset)) ?? false;
  bool getEqualizerEnabled() => _prefs?.getBool(_keyEqualizerEnabled) ?? true;
  Future<bool> saveEqualizerEnabled(bool enabled) async =>
      (await _prefs?.setBool(_keyEqualizerEnabled, enabled)) ?? false;

  // --- WebDAV 配置 ---
  WebDavConfig? getWebDavConfig() {
    final raw = _prefs?.getString(_keyWebDavConfig);
    if (raw == null || raw.isEmpty) return null;
    try {
      return WebDavConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
  Future<bool> saveWebDavConfig(WebDavConfig config) async {
    return (await _prefs?.setString(_keyWebDavConfig, jsonEncode(config.toJson()))) ?? false;
  }

  // --- 自定义音源脚本与音源引擎配置 ---
  List<String>? getCustomScripts() => _prefs?.getStringList(_keyCustomScripts);
  Future<bool> saveCustomScripts(List<String> scripts) async =>
      (await _prefs?.setStringList(_keyCustomScripts, scripts)) ?? false;

  String? getActiveSourceId() => _prefs?.getString(_keyActiveSourceId);
  Future<bool> saveActiveSourceId(String id) async =>
      (await _prefs?.setString(_keyActiveSourceId, id)) ?? false;

  String? getPreferredQuality() => _prefs?.getString(_keyPreferredQuality);
  Future<bool> savePreferredQuality(String quality) async =>
      (await _prefs?.setString(_keyPreferredQuality, quality)) ?? false;

  // --- 本地扫描曲库与目录偏好 ---

  List<Track>? getLocalTracks() {
    final raw = _prefs?.getString(_keyLocalTracks);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => _deserializeTrack(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveLocalTracks(List<Track> tracks) async {
    final list = tracks.map((t) => _serializeTrack(t)).toList();
    return (await _prefs?.setString(_keyLocalTracks, jsonEncode(list))) ?? false;
  }

  List<String>? getLocalDirectories() => _prefs?.getStringList(_keyLocalDirectories);

  Future<bool> saveLocalDirectories(List<String> dirs) async {
    return (await _prefs?.setStringList(_keyLocalDirectories, dirs)) ?? false;
  }

  // --- 桌面悬浮歌词偏好 ---
  bool? getFloatingLyricEnabled() => _prefs?.getBool(_keyFloatingLyricEnabled);
  Future<bool> saveFloatingLyricEnabled(bool value) async =>
      (await _prefs?.setBool(_keyFloatingLyricEnabled, value)) ?? false;

  bool? getFloatingLyricLocked() => _prefs?.getBool(_keyFloatingLyricLocked);
  Future<bool> saveFloatingLyricLocked(bool value) async =>
      (await _prefs?.setBool(_keyFloatingLyricLocked, value)) ?? false;

  bool? getFloatingLyricAlwaysOnTop() => _prefs?.getBool(_keyFloatingLyricAlwaysOnTop);
  Future<bool> saveFloatingLyricAlwaysOnTop(bool value) async =>
      (await _prefs?.setBool(_keyFloatingLyricAlwaysOnTop, value)) ?? false;

  double? getFloatingLyricPosX() => _prefs?.getDouble(_keyFloatingLyricPosX);
  double? getFloatingLyricPosY() => _prefs?.getDouble(_keyFloatingLyricPosY);
  Future<bool> saveFloatingLyricPosition(double x, double y) async {
    final r1 = await _prefs?.setDouble(_keyFloatingLyricPosX, x) ?? false;
    final r2 = await _prefs?.setDouble(_keyFloatingLyricPosY, y) ?? false;
    return r1 && r2;
  }

  String? getFloatingLyricFontSize() => _prefs?.getString(_keyFloatingLyricFontSize);
  Future<bool> saveFloatingLyricFontSize(String size) async =>
      (await _prefs?.setString(_keyFloatingLyricFontSize, size)) ?? false;

  // --- 主题偏好 ---

  bool? getIsDarkMode() => _prefs?.getBool(_keyIsDarkMode);
  Future<bool> saveIsDarkMode(bool value) async =>
      (await _prefs?.setBool(_keyIsDarkMode, value)) ?? false;

  String? getAccentType() => _prefs?.getString(_keyAccentType);
  Future<bool> saveAccentType(String name) async =>
      (await _prefs?.setString(_keyAccentType, name)) ?? false;

  double? getGlowIntensity() => _prefs?.getDouble(_keyGlowIntensity);
  Future<bool> saveGlowIntensity(double value) async =>
      (await _prefs?.setDouble(_keyGlowIntensity, value)) ?? false;

  // --- 音频播放偏好 ---

  double? getVolume() => _prefs?.getDouble(_keyVolume);
  Future<bool> saveVolume(double value) async =>
      (await _prefs?.setDouble(_keyVolume, value)) ?? false;

  String? getPlaybackMode() => _prefs?.getString(_keyPlaybackMode);
  Future<bool> savePlaybackMode(String mode) async =>
      (await _prefs?.setString(_keyPlaybackMode, mode)) ?? false;

  // --- 收藏红心与曲目池 ---

  Set<String>? getFavoriteIds() {
    final list = _prefs?.getStringList(_keyFavoriteIds);
    return list != null ? Set<String>.from(list) : null;
  }

  Future<bool> saveFavoriteIds(Set<String> ids) async =>
      (await _prefs?.setStringList(_keyFavoriteIds, ids.toList())) ?? false;

  List<Track>? getFavoriteTracks() {
    final raw = _prefs?.getString(_keyFavoriteTracks);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => _deserializeTrack(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveFavoriteTracks(List<Track> tracks) async {
    final list = tracks.map((t) => _serializeTrack(t)).toList();
    return (await _prefs?.setString(_keyFavoriteTracks, jsonEncode(list))) ?? false;
  }

  // --- 播放足迹历史 ---

  List<Track>? getPlayHistory() {
    final raw = _prefs?.getString(_keyPlayHistory);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => _deserializeTrack(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> savePlayHistory(List<Track> history) async {
    final list = history.map((t) => _serializeTrack(t)).toList();
    return (await _prefs?.setString(_keyPlayHistory, jsonEncode(list))) ?? false;
  }

  Future<bool> clearPlayHistory() async =>
      (await _prefs?.remove(_keyPlayHistory)) ?? false;

  // --- 导入与自建歌单落盘 ---

  List<ImportedPlaylist>? getImportedPlaylists() {
    final raw = _prefs?.getString(_keyImportedPlaylists);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final tracksList = (map['tracks'] as List<dynamic>? ?? [])
            .map((t) => _deserializeTrack(t as Map<String, dynamic>))
            .toList();
        return ImportedPlaylist(
          id: map['id'] as String? ?? '',
          title: map['title'] as String? ?? '',
          coverUrl: map['coverUrl'] as String? ?? '',
          description: map['description'] as String? ?? '',
          trackCount: tracksList.length,
          tracks: tracksList,
          isCustom: map['isCustom'] as bool? ?? false,
          createdAt: map['createdAt'] as int? ?? 0,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveImportedPlaylists(List<ImportedPlaylist> playlists) async {
    final list = playlists.map((pl) => {
      'id': pl.id,
      'title': pl.title,
      'coverUrl': pl.coverUrl,
      'description': pl.description,
      'isCustom': pl.isCustom,
      'createdAt': pl.createdAt,
      'tracks': pl.tracks.map((t) => _serializeTrack(t)).toList(),
    }).toList();
    return (await _prefs?.setString(_keyImportedPlaylists, jsonEncode(list))) ?? false;
  }

  Map<String, dynamic> _serializeTrack(Track t) => {
    'id': t.id,
    'title': t.title,
    'artist': t.artist,
    'album': t.album,
    'durationMs': t.duration.inMilliseconds,
    'coverUrl': t.coverUrl,
    if (t.audioUrl != null) 'audioUrl': t.audioUrl,
    if (t.localPath != null) 'localPath': t.localPath,
    'lyrics': t.lyrics.map((l) => {'ms': l.time.inMilliseconds, 'text': l.text}).toList(),
  };

  Track _deserializeTrack(Map<String, dynamic> map) {
    final lyricsList = (map['lyrics'] as List<dynamic>? ?? []).map((l) {
      final lmap = l as Map<String, dynamic>;
      return LyricLine(
        time: Duration(milliseconds: lmap['ms'] as int? ?? 0),
        text: lmap['text'] as String? ?? '',
      );
    }).toList();

    return Track(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
      coverUrl: map['coverUrl'] as String? ?? '',
      audioUrl: map['audioUrl'] as String?,
      localPath: map['localPath'] as String?,
      lyrics: lyricsList,
    );
  }

  // --- 关注歌手持久化 ---

  Set<String> getFollowedArtists() {
    final list = _prefs?.getStringList(_keyFollowedArtists);
    return list != null ? Set<String>.from(list) : <String>{};
  }

  Future<bool> saveFollowedArtists(Set<String> artists) async {
    return (await _prefs?.setStringList(_keyFollowedArtists, artists.toList())) ?? false;
  }

  bool isArtistFollowed(String name) => getFollowedArtists().contains(name.trim());

  Future<bool> toggleArtistFollow(String name) async {
    final set = getFollowedArtists();
    final trimmed = name.trim();
    if (set.contains(trimmed)) {
      set.remove(trimmed);
    } else {
      set.add(trimmed);
    }
    return await saveFollowedArtists(set);
  }
}

