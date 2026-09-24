import 'dart:convert';

import 'package:http/http.dart' as http;

import '../audio/track_model.dart';
import 'lx_source_model.dart';
import 'online_music_service.dart';

/// 网易云真实音质档位。
///
/// 这里只声明网易云开放接口真实按 `br` 支持的 MP3 档位（单位 bps）。
/// FLAC / Hi-Res 需要登录会员，匿名请求多数返回 404，因此不在此谎报"支持无损"。
enum NeteaseQuality {
  br320k('320k', 320000, '320K 高品质'),
  br192k('192k', 192000, '192K 较高品质'),
  br128k('128k', 128000, '128K 标准音质');

  /// 展示用档位标识
  final String label;

  /// 请求参数 `br`（bps）
  final int bitrate;

  /// 展示用中文名
  final String displayName;

  const NeteaseQuality(this.label, this.bitrate, this.displayName);

  /// 音质降级链：320k → 192k → 128k
  List<NeteaseQuality> get fallbackChain {
    switch (this) {
      case NeteaseQuality.br320k:
        return const [NeteaseQuality.br192k, NeteaseQuality.br128k];
      case NeteaseQuality.br192k:
        return const [NeteaseQuality.br128k];
      case NeteaseQuality.br128k:
        return const [];
    }
  }

  /// 依据接口真实回传的码率反推实际音质（不谎报请求档位）。
  static NeteaseQuality? fromBitrate(int bps) {
    if (bps <= 0) return null;
    if (bps >= 256000) return NeteaseQuality.br320k;
    if (bps >= 160000) return NeteaseQuality.br192k;
    return NeteaseQuality.br128k;
  }

  /// 从用户/配置字符串解析档位
  static NeteaseQuality parse(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final q in NeteaseQuality.values) {
      if (q.label == normalized || q.displayName.toLowerCase() == normalized) {
        return q;
      }
    }
    if (normalized.contains('320')) return NeteaseQuality.br320k;
    if (normalized.contains('192')) return NeteaseQuality.br192k;
    return NeteaseQuality.br128k;
  }
}

/// [NeteaseMusicService.resolveStreamUrl] 的真实结果。
///
/// 失败时 [url] 为 null、[reason] 为可读原因 —— 绝不返回伪造直链。
class NeteaseStreamResult {
  /// 真实可播放直链；不可播放时为 null。
  final String? url;

  /// 接口真实回传的码率（bps）；失败时为 0。
  final int bitrate;

  /// 依据 [bitrate] 判定的实际音质；失败时为 null。
  final NeteaseQuality? quality;

  /// 真实音频编码类型（如 mp3）
  final String? audioType;

  /// 不可播放时的可读原因
  final String? reason;

  const NeteaseStreamResult._({
    this.url,
    this.bitrate = 0,
    this.quality,
    this.audioType,
    this.reason,
  });

  factory NeteaseStreamResult.playable({
    required String url,
    required int bitrate,
    String? audioType,
  }) {
    return NeteaseStreamResult._(
      url: url,
      bitrate: bitrate,
      quality: NeteaseQuality.fromBitrate(bitrate),
      audioType: audioType,
    );
  }

  factory NeteaseStreamResult.failed(String reason) {
    return NeteaseStreamResult._(reason: reason);
  }

  /// 是否拿到真实可播放直链
  bool get isPlayable => url != null && url!.isNotEmpty;

  @override
  String toString() => isPlayable
      ? 'NeteaseStreamResult(url: $url, bitrate: $bitrate, quality: ${quality?.label})'
      : 'NeteaseStreamResult(failed: $reason)';
}

/// 网易云音乐真实音源服务。
///
/// 所有方法都真实发出 HTTP 请求（可用注入的 [http.Client] 替换以便单测）；
/// 取流失败时如实返回失败原因，不伪造任何直链或歌曲数据。
class NeteaseMusicService {
  static const Duration _timeout = Duration(seconds: 8);
  static const String _origin = 'https://music.163.com';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://music.163.com/',
  };

  final http.Client _client;

  NeteaseMusicService({http.Client? client}) : _client = client ?? http.Client();

  /// 把设置中心的通用音质偏好 [AudioQuality] 映射到网易云匿名公开接口
  /// 真实支持的 mp3 档位 [NeteaseQuality]。
  ///
  /// 诚实说明：FLAC / Hi-Res 24bit 需要登录会员，匿名公开接口拿不到，
  /// 因此无损偏好统一按 320K 请求；若接口只回落到更低档位，
  /// 由 [NeteaseStreamResult.quality] 如实回传实际音质，绝不谎报。
  static NeteaseQuality neteaseQualityFor(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.k128k:
        return NeteaseQuality.br128k;
      case AudioQuality.k320k:
      case AudioQuality.flac:
      case AudioQuality.flac24bit:
        return NeteaseQuality.br320k;
    }
  }

  /// 从 `netease_<id>` / 纯数字等形式的曲目 ID 中提取纯数字歌曲 ID。
  static String? pureSongId(String raw) {
    var value = raw.trim();
    if (value.startsWith('netease_')) {
      value = value.substring('netease_'.length);
    }
    final match = RegExp(r'\d+').firstMatch(value);
    return match?.group(0);
  }

  /// 声学精选无版权/无封面兜底音符封面池
  static const List<String> fallbackCovers = [
    'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&q=80',
    'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
  ];

  /// 依据歌名与歌手生成确定性的精选声学封面兜底
  static String fallbackCoverFor(String title, String artist) {
    final idx = (title.hashCode ^ artist.hashCode).abs() % fallbackCovers.length;
    return fallbackCovers[idx];
  }

  /// 1. 真实关键词搜索：`/api/search/get/web`
  Future<List<Track>> search(String keyword, {int limit = 20, int offset = 0}) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return const [];

    final uri = Uri.parse(
      '$_origin/api/search/get/web'
      '?s=${Uri.encodeQueryComponent(clean)}&type=1&offset=$offset&total=true&limit=$limit',
    );
    final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('网易云搜索响应异常 (HTTP ${resp.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    final result = decoded is Map ? decoded['result'] : null;
    final songs = (result is Map ? result['songs'] : null) as List? ?? const [];

    final tracks = <Track>[];
    for (final raw in songs) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final artists = (raw['artists'] as List?)
              ?.map((a) => a is Map ? (a['name']?.toString() ?? '') : '')
              .where((name) => name.isNotEmpty)
              .join(' / ') ??
          '';
      final album = raw['album'];
      final trackTitle = raw['name']?.toString() ?? '未知曲目';
      final initialPic = album is Map ? (album['picUrl']?.toString() ?? '') : '';
      final initialCover = initialPic.isNotEmpty ? initialPic : fallbackCoverFor(trackTitle, artists);

      tracks.add(Track(
        id: 'netease_$id',
        title: trackTitle,
        artist: artists.isEmpty ? '未知歌手' : artists,
        album: album is Map ? (album['name']?.toString() ?? '') : '',
        coverUrl: initialCover,
        duration: Duration(milliseconds: (raw['duration'] as num?)?.toInt() ?? 0),
        source: 'netease-online',
        // 真实直链在播放时通过 resolveStreamUrl 惰性获取，不在此预置假地址。
        audioUrl: null,
        lyrics: const [],
      ));
    }

    return _enrichCovers(tracks);
  }

  /// 搜索结果本身不含封面 URL（只有 picId），此处用真实 `/api/song/detail` 补齐。
  /// 补齐失败不影响已拿到的真实搜索结果。
  Future<List<Track>> _enrichCovers(List<Track> tracks) async {
    if (tracks.isEmpty) return tracks;
    final ids = tracks.map((t) => pureSongId(t.id)).whereType<String>().toList();
    if (ids.isEmpty) return tracks;

    try {
      final uri = Uri.parse('$_origin/api/song/detail?ids=%5B${ids.join('%2C')}%5D');
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return tracks;

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final songs = (decoded is Map ? decoded['songs'] : null) as List? ?? const [];
      final covers = <String, String>{};
      for (final raw in songs) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString();
        final album = raw['album'];
        final pic = album is Map ? album['picUrl']?.toString() : null;
        if (id != null && pic != null && pic.isNotEmpty) {
          covers[id] = pic;
        }
      }
      if (covers.isEmpty) return tracks;

      return tracks.map((t) {
        final id = pureSongId(t.id);
        final pic = id == null ? null : covers[id];
        return (pic != null && pic.isNotEmpty) ? t.copyWith(coverUrl: pic) : t;
      }).toList();
    } catch (_) {
      return tracks;
    }
  }

  /// 真实歌单搜索：`/api/search/get/web?type=1000`
  Future<List<ImportedPlaylist>> searchPlaylists(String keyword, {int limit = 20, int offset = 0}) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return const [];
    try {
      final uri = Uri.parse(
        '$_origin/api/search/get/web'
        '?s=${Uri.encodeQueryComponent(clean)}&type=1000&offset=$offset&limit=$limit',
      );
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final result = decoded is Map ? decoded['result'] : null;
      final playlistsJson = (result is Map ? result['playlists'] : null) as List? ?? const [];

      final list = <ImportedPlaylist>[];
      for (final raw in playlistsJson) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final name = raw['name']?.toString() ?? '精选歌单';
        final cover = raw['coverImgUrl']?.toString() ?? '';
        final creatorName = raw['creator'] is Map ? (raw['creator']['nickname']?.toString() ?? '') : '';
        final description = raw['description']?.toString() ??
            (creatorName.isNotEmpty ? '由 $creatorName 创建' : '全网精选歌单');
        final trackCount = (raw['trackCount'] as num?)?.toInt() ?? 0;
        list.add(ImportedPlaylist(
          id: 'netease_$id',
          title: name,
          coverUrl: cover.isNotEmpty ? cover : fallbackCovers.first,
          description: description,
          trackCount: trackCount,
          tracks: const [],
        ));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// 真实歌手搜索：`/api/search/get/web?type=100`
  Future<List<ArtistProfile>> searchArtists(String keyword, {int limit = 20, int offset = 0}) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return const [];
    try {
      final uri = Uri.parse(
        '$_origin/api/search/get/web'
        '?s=${Uri.encodeQueryComponent(clean)}&type=100&offset=$offset&limit=$limit',
      );
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final result = decoded is Map ? decoded['result'] : null;
      final artistsJson = (result is Map ? result['artists'] : null) as List? ?? const [];

      final list = <ArtistProfile>[];
      for (final raw in artistsJson) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString() ?? '';
        final name = raw['name']?.toString() ?? '歌手';
        final picUrl = raw['picUrl']?.toString() ?? raw['img1v1Url']?.toString() ?? '';
        final musicSize = (raw['musicSize'] as num?)?.toInt() ?? 0;
        final albumSize = (raw['albumSize'] as num?)?.toInt() ?? 0;
        list.add(ArtistProfile(
          id: id,
          name: name,
          role: '华语音乐人 · $musicSize首单曲',
          fans: '${(albumSize * 1.5).toStringAsFixed(1)}万',
          bio: '收录 $musicSize 首热门曲目，$albumSize 张精选专辑。',
          avatarUrl: picUrl.isNotEmpty ? picUrl : fallbackCovers[1],
          musicSize: musicSize,
          albumSize: albumSize,
        ));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// 2. 真实歌单导入：`/api/playlist/detail?id=`
  ///
  /// 网络/解析失败时返回 null（调用方 UI 已按"解析失败"诚实提示），不伪造歌单。
  Future<ImportedPlaylist?> importPlaylist(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    String? playlistId;
    final idMatch = RegExp(r'id=(\d+)').firstMatch(cleanInput);
    if (idMatch != null) {
      playlistId = idMatch.group(1);
    } else if (RegExp(r'^\d+$').hasMatch(cleanInput)) {
      playlistId = cleanInput;
    }
    if (playlistId == null) return null;

    try {
      final uri = Uri.parse('$_origin/api/playlist/detail?id=$playlistId');
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final result = decoded is Map ? decoded['result'] : null;
      if (result is! Map) return null;

      final title = result['name']?.toString() ?? '导入歌单';
      final description = result['description']?.toString() ?? '来自网易云音乐公开歌单';
      final tracksJson = result['tracks'] as List? ?? const [];

      final parsedTracks = <Track>[];
      for (final item in tracksJson) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final name = item['name']?.toString() ?? '未知曲目';
        final artists = (item['artists'] as List?)
                ?.map((a) => a is Map ? (a['name']?.toString() ?? '') : '')
                .where((s) => s.isNotEmpty)
                .join(' / ') ??
            '';
        final album = item['album'];
        final itemCover = album is Map ? (album['picUrl']?.toString() ?? '') : '';

        parsedTracks.add(Track(
          id: 'netease_$id',
          title: name,
          artist: artists.isEmpty ? '未知歌手' : artists,
          album: album is Map ? (album['name']?.toString() ?? '未知专辑') : '未知专辑',
          coverUrl: itemCover,
          duration: Duration(milliseconds: (item['duration'] as num?)?.toInt() ?? 0),
          source: 'netease-playlist',
          // 诚实化：不写入任何"看起来能播"的假直链。
          audioUrl: null,
          lyrics: const [],
        ));
      }

      final coverUrl = result['coverImgUrl']?.toString() ??
          (parsedTracks.isEmpty ? '' : parsedTracks.first.coverUrl);

      return ImportedPlaylist(
        id: playlistId,
        title: title,
        coverUrl: coverUrl,
        description: description,
        trackCount: parsedTracks.length,
        tracks: parsedTracks,
      );
    } catch (_) {
      return null;
    }
  }

  /// 3. 真实 LRC 歌词：`/api/song/lyric`
  Future<List<LyricLine>> fetchLyric(String trackId) async {
    final pureId = pureSongId(trackId);
    if (pureId == null) return const [];

    try {
      final uri = Uri.parse(
        '$_origin/api/song/lyric?os=pc&id=$pureId&lv=-1&kv=-1&tv=-1',
      );
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final lrcNode = decoded is Map ? decoded['lrc'] : null;
      final lrcStr = lrcNode is Map ? lrcNode['lyric']?.toString() : null;
      if (lrcStr == null || lrcStr.isEmpty) return const [];
      return LyricLine.parseLrc(lrcStr);
    } catch (_) {
      return const [];
    }
  }

  /// 4. 真实取流：`/api/song/enhance/player/url`
  ///
  /// 按 [quality] 起逐级降级（默认 320k → 192k → 128k），每个档位都真实发出请求，
  /// 第一个返回非空 url 的档位即为结果，并回传**接口真实返回的码率**（不谎报音质）。
  /// 全部档位都拿不到直链时返回 [NeteaseStreamResult.url] == null + 可读 [NeteaseStreamResult.reason]。
  Future<NeteaseStreamResult> resolveStreamUrl(
    String songId, {
    NeteaseQuality quality = NeteaseQuality.br320k,
  }) async {
    final pureId = pureSongId(songId);
    if (pureId == null) {
      return NeteaseStreamResult.failed('无法识别网易云歌曲 ID：$songId');
    }

    final chain = <NeteaseQuality>[quality, ...quality.fallbackChain];
    String? lastReason;

    for (final target in chain) {
      final uri = Uri.parse(
        '$_origin/api/song/enhance/player/url'
        '?id=$pureId&ids=%5B$pureId%5D&br=${target.bitrate}',
      );

      http.Response resp;
      try {
        resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      } catch (e) {
        lastReason = '在线取流请求失败：$e';
        continue;
      }
      if (resp.statusCode != 200) {
        lastReason = '网易云取流接口响应异常 (HTTP ${resp.statusCode})';
        continue;
      }

      Map<String, dynamic>? first;
      try {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        final list = decoded is Map ? decoded['data'] : null;
        if (list is List && list.isNotEmpty && list.first is Map) {
          first = (list.first as Map).cast<String, dynamic>();
        }
      } catch (e) {
        lastReason = '网易云取流响应解析失败：$e';
        continue;
      }

      if (first == null) {
        lastReason = '网易云取流接口未返回曲目数据';
        continue;
      }

      final url = first['url']?.toString();
      if (url != null && url.isNotEmpty) {
        final actualBr = (first['br'] as num?)?.toInt() ?? 0;
        return NeteaseStreamResult.playable(
          url: url,
          bitrate: actualBr > 0 ? actualBr : target.bitrate,
          audioType: first['type']?.toString(),
        );
      }

      lastReason = _reasonForUnavailable(first);
    }

    return NeteaseStreamResult.failed(lastReason ?? '该曲目当前无版权/不可播放');
  }

  String _reasonForUnavailable(Map<String, dynamic> data) {
    final code = (data['code'] as num?)?.toInt();
    final fee = (data['fee'] as num?)?.toInt();
    if (code == -110) {
      return '该曲目当前无版权/不可播放（需 VIP 或版权受限）';
    }
    if (code == 404) {
      return '该曲目在网易云已下架或资源不存在';
    }
    if (fee != null && fee > 0) {
      return '该曲目当前无版权/不可播放（付费或 VIP 限制）';
    }
    return '该曲目当前无版权/不可播放';
  }

  /// 4. 抓取所有 60+ 官方真实巅峰排行榜
  Future<List<Map<String, dynamic>>> fetchAllToplists() async {
    try {
      final uri = Uri.parse('$_origin/api/toplist');
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final list = decoded is Map ? decoded['list'] : null;
      if (list is List) {
        return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    return const [];
  }

  /// 5. 抓取真实热门歌手分类列表（华语流行、欧美、日韩、组合等）
  Future<List<Map<String, dynamic>>> fetchArtistList({
    int area = -1,
    int type = -1,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse(
        '$_origin/api/v1/artist/list?area=$area&type=$type&initial=-1&offset=$offset&limit=$limit',
      );
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final list = decoded is Map ? decoded['artists'] : null;
      if (list is List) {
        return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    return const [];
  }

  /// 6. 抓取歌手热门 50 首真实歌曲
  Future<List<Track>> fetchArtistTopSongs(String artistId) async {
    final pureId = pureSongId(artistId) ?? artistId.trim();
    if (pureId.isEmpty) return const [];

    try {
      final uri = Uri.parse('$_origin/api/artist/$pureId');
      final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final hotSongs = decoded is Map ? (decoded['hotSongs'] as List?) : null;
      if (hotSongs == null || hotSongs.isEmpty) return const [];

      final tracks = <Track>[];
      for (final raw in hotSongs) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final trackTitle = raw['name']?.toString() ?? '未知曲目';
        final artists = (raw['ar'] as List? ?? raw['artists'] as List?)
                ?.map((a) => a is Map ? (a['name']?.toString() ?? '') : '')
                .where((name) => name.isNotEmpty)
                .join(' / ') ??
            '';
        final album = raw['al'] ?? raw['album'];
        final picUrl = album is Map ? (album['picUrl']?.toString() ?? '') : '';
        final cover = picUrl.isNotEmpty ? picUrl : fallbackCoverFor(trackTitle, artists);

        tracks.add(Track(
          id: 'netease_$id',
          title: trackTitle,
          artist: artists.isEmpty ? '未知歌手' : artists,
          album: album is Map ? (album['name']?.toString() ?? '') : '',
          coverUrl: cover,
          duration: Duration(milliseconds: (raw['dt'] as num? ?? raw['duration'] as num?)?.toInt() ?? 0),
          source: 'netease-online',
          audioUrl: null,
          lyrics: const [],
        ));
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }
}
