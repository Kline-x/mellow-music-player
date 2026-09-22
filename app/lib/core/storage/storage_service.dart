import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/track_model.dart';

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
  static const _keyPlayHistory = 'mellow_audio_play_history';

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

  // --- 收藏红心与播放历史 ---

  Set<String>? getFavoriteIds() {
    final list = _prefs?.getStringList(_keyFavoriteIds);
    return list != null ? Set<String>.from(list) : null;
  }

  Future<bool> saveFavoriteIds(Set<String> ids) async =>
      (await _prefs?.setStringList(_keyFavoriteIds, ids.toList())) ?? false;

  List<Track>? getPlayHistory() {
    final raw = _prefs?.getString(_keyPlayHistory);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return Track(
          id: map['id'] as String? ?? '',
          title: map['title'] as String? ?? '',
          artist: map['artist'] as String? ?? '',
          album: map['album'] as String? ?? '',
          duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
          coverUrl: map['coverUrl'] as String? ?? '',
          audioUrl: map['audioUrl'] as String?,
          localPath: map['localPath'] as String?,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> savePlayHistory(List<Track> history) async {
    final list = history.map((t) => {
      'id': t.id,
      'title': t.title,
      'artist': t.artist,
      'album': t.album,
      'durationMs': t.duration.inMilliseconds,
      'coverUrl': t.coverUrl,
      if (t.audioUrl != null) 'audioUrl': t.audioUrl,
      if (t.localPath != null) 'localPath': t.localPath,
    }).toList();
    return (await _prefs?.setString(_keyPlayHistory, jsonEncode(list))) ?? false;
  }
}
