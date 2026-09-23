import 'dart:convert';

import 'package:http/http.dart' as http;

import '../audio/track_model.dart';

/// iTunes 公开试听库搜索服务。
///
/// 只返回**真实可播放**的结果：每条都带 iTunes 官方 30 秒试听直链（`previewUrl`）
/// 与真实封面（`artworkUrl100` → 600x600）。拿不到 `previewUrl` 的条目直接丢弃，
/// 以保证"列表里的每一首都点得响"。
class ItunesMusicService {
  static const Duration _timeout = Duration(seconds: 8);

  final http.Client _client;

  ItunesMusicService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Track>> search(String query, {int limit = 20}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': cleanQuery,
      'entity': 'song',
      'limit': '$limit',
    });
    final resp = await _client.get(uri).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('在线曲库响应异常 (HTTP ${resp.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    final items = (decoded is Map ? decoded['results'] : null) as List? ?? const [];
    final results = <Track>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final previewUrl = raw['previewUrl']?.toString();
      if (previewUrl == null || previewUrl.isEmpty) continue; // 不可播放 → 不进列表

      final trackId = raw['trackId']?.toString() ?? '';
      final name = raw['trackName']?.toString() ?? '未知曲目';
      final artist = raw['artistName']?.toString() ?? '未知歌手';
      final album = raw['collectionName']?.toString() ?? '';
      final durationMs = (raw['trackTimeMillis'] as num?)?.toInt() ?? 30000;
      final artwork = raw['artworkUrl100']?.toString() ?? '';

      results.add(Track(
        id: 'itunes_${trackId.isEmpty ? previewUrl.hashCode : trackId}',
        title: name,
        artist: artist,
        album: album,
        coverUrl: artwork.replaceAll('100x100bb', '600x600bb'),
        duration: Duration(milliseconds: durationMs),
        source: 'itunes-preview',
        audioUrl: previewUrl,
        lyrics: const [],
      ));
    }
    return results;
  }
}
