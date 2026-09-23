import 'dart:convert';
import 'package:http/http.dart' as http;
import '../audio/track_model.dart';

/// 导入与自建歌单模型
class ImportedPlaylist {
  final String id;
  final String title;
  final String coverUrl;
  final String description;
  final int trackCount;
  final List<Track> tracks;
  final bool isCustom;
  final int createdAt;

  const ImportedPlaylist({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.trackCount,
    required this.tracks,
    this.isCustom = false,
    int? createdAt,
  }) : createdAt = createdAt ?? 0;

  ImportedPlaylist copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? description,
    int? trackCount,
    List<Track>? tracks,
    bool? isCustom,
    int? createdAt,
  }) {
    return ImportedPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      trackCount: trackCount ?? this.trackCount,
      tracks: tracks ?? this.tracks,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 在线音乐与公开歌单服务引擎 (对标 AlgerMusicPlayer 核心能力)
class OnlineMusicService {
  static const Duration _timeout = Duration(seconds: 6);

  /// 1. 全网在线音乐实时检索
  static Future<List<Track>> searchOnlineTracks(String query, {int limit = 20}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final uri = Uri.parse(
        'https://music.163.com/api/search/get/web?s=${Uri.encodeComponent(cleanQuery)}&type=1&offset=0&total=true&limit=$limit',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.163.com/',
      }).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final songs = data['result']?['songs'] as List?;
        if (songs != null && songs.isNotEmpty) {
          final results = <Track>[];
          for (final item in songs) {
            final id = item['id']?.toString() ?? '';
            final name = item['name']?.toString() ?? '未知曲目';
            final artists = (item['artists'] as List?)
                    ?.map((a) => a['name']?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .join(' / ') ??
                '未知歌手';
            final album = item['album']?['name']?.toString() ?? '未知专辑';
            final durationMs = (item['duration'] as num?)?.toInt() ?? 240000;
            final duration = Duration(milliseconds: durationMs);

            // 封面（网易云 album.picUrl 或 artist.img1v1Url）
            final coverUrl = item['album']?['picUrl']?.toString() ??
                'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80';

            final audioUrl = 'https://music.163.com/song/media/outer/url?id=$id.mp3';

            results.add(Track(
              id: 'netease_$id',
              title: name,
              artist: artists,
              album: album,
              coverUrl: coverUrl,
              duration: duration,
              source: 'netease-online',
              audioUrl: audioUrl,
              lyrics: const [],
            ));
          }
          return results;
        }
      }
    } catch (_) {
      // 网络波动或超时，静默返回空，由上层触发本地降级逻辑
    }
    return [];
  }

  /// 2. 网易云/公开歌单解析与一键导入
  static Future<ImportedPlaylist?> importNeteasePlaylist(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    // 提取歌单数字 ID（支持直接数字、或带 id= 的链接）
    String? playlistId;
    final idMatch = RegExp(r'id=(\d+)').firstMatch(cleanInput);
    if (idMatch != null) {
      playlistId = idMatch.group(1);
    } else if (RegExp(r'^\d+$').hasMatch(cleanInput)) {
      playlistId = cleanInput;
    }

    if (playlistId == null) return null;

    try {
      final uri = Uri.parse('https://music.163.com/api/playlist/detail?id=$playlistId');
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.163.com/',
      }).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final result = data['result'];
        if (result != null) {
          final title = result['name']?.toString() ?? '导入歌单';
          final coverUrl = result['coverImgUrl']?.toString() ??
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80';
          final description = result['description']?.toString() ?? '来自网易云音乐公开歌单';
          final tracksJson = result['tracks'] as List? ?? [];

          final parsedTracks = <Track>[];
          for (final item in tracksJson) {
            final id = item['id']?.toString() ?? '';
            final name = item['name']?.toString() ?? '未知曲目';
            final artists = (item['artists'] as List?)
                    ?.map((a) => a['name']?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .join(' / ') ??
                '未知歌手';
            final album = item['album']?['name']?.toString() ?? '未知专辑';
            final durationMs = (item['duration'] as num?)?.toInt() ?? 240000;
            final duration = Duration(milliseconds: durationMs);
            final itemCover = item['album']?['picUrl']?.toString() ?? coverUrl;
            final audioUrl = 'https://music.163.com/song/media/outer/url?id=$id.mp3';

            parsedTracks.add(Track(
              id: 'netease_$id',
              title: name,
              artist: artists,
              album: album,
              coverUrl: itemCover,
              duration: duration,
              source: 'netease-playlist',
              audioUrl: audioUrl,
              lyrics: const [],
            ));
          }

          return ImportedPlaylist(
            id: playlistId,
            title: title,
            coverUrl: coverUrl,
            description: description,
            trackCount: parsedTracks.length,
            tracks: parsedTracks,
          );
        }
      }
    } catch (_) {
      // 容错处理
    }
    return null;
  }

  /// 3. 获取单曲真实 LRC 歌词
  static Future<List<LyricLine>> fetchTrackLyric(String trackId) async {
    final pureId = trackId.replaceAll('netease_', '');
    try {
      final uri = Uri.parse(
        'https://music.163.com/api/song/lyric?os=pc&id=$pureId&lv=-1&kv=-1&tv=-1',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.163.com/',
      }).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final lrcStr = data['lrc']?['lyric']?.toString();
        if (lrcStr != null && lrcStr.isNotEmpty) {
          return LyricLine.parseLrc(lrcStr);
        }
      }
    } catch (_) {}
    return [];
  }
}
