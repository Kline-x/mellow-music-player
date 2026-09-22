import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/track_model.dart';
import '../sources/online_music_service.dart';

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
}

