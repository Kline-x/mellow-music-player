import 'dart:convert';
import 'package:http/http.dart' as http;
import '../audio/track_model.dart';
import 'itunes_music_service.dart';
import 'netease_music_service.dart';

export 'netease_music_service.dart' show NeteaseMusicService, NeteaseQuality, NeteaseStreamResult;
export 'itunes_music_service.dart' show ItunesMusicService;

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

/// 在线音乐与公开歌单服务引擎 (多源真实高保真音频引擎：酷我高保真 + 网易云真实流 + iTunes 官方试听)
class OnlineMusicService {
  static const Duration _timeout = Duration(seconds: 6);
  static final Map<String, String> _urlCache = {};

  /// 可注入的真实音源子服务实例（便于单元测试 Mock）
  static NeteaseMusicService neteaseService = NeteaseMusicService();
  static ItunesMusicService itunesService = ItunesMusicService();

  /// 是否启用酷我搜索源（默认 true，单测可置为 false 隔离外部网络）
  static bool enableKuwoSearch = true;

  /// 按归一化后的 title + artist 去重，保留先出现的真实来源。
  static List<Track> dedupeByTitleArtist(List<Track> tracks) {
    final seen = <String>{};
    final result = <Track>[];
    for (final track in tracks) {
      final key = '${_normalizeForMatch(track.title)}|${_normalizeForMatch(track.artist)}';
      if (seen.add(key)) result.add(track);
    }
    return result;
  }

  static String _normalizeForMatch(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[·、,，.。!！?？()（）\[\]【】\-_/]'), '');
  }

  /// 1. 全网多音源真实音乐并发实时检索 (网易云 + 酷我高保真 + iTunes 官方保底，消灭 404)
  static Future<List<Track>> searchOnlineTracks(String query, {int page = 1, int limit = 30}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final errors = <Object>[];

    Future<List<Track>?> trySource(Future<List<Track>> Function() source) async {
      try {
        return await source();
      } catch (e) {
        errors.add(e);
        return null;
      }
    }

    final offset = (page - 1) * limit;
    final kuwoPn = page - 1;

    final neteaseFuture = trySource(() => neteaseService.search(cleanQuery, limit: limit, offset: offset));
    final kuwoFuture = enableKuwoSearch
        ? trySource(() => _searchKuwoTracks(cleanQuery, limit: limit, page: kuwoPn))
        : Future<List<Track>?>.value(null);
    final itunesFuture = page == 1
        ? trySource(() => itunesService.search(cleanQuery, limit: limit))
        : Future<List<Track>?>.value(null);

    final perSource = await Future.wait([neteaseFuture, kuwoFuture, itunesFuture]);

    final merged = <Track>[
      ...?perSource[0],
      ...?perSource[1],
      ...?perSource[2],
    ];

    if (merged.isEmpty && errors.isNotEmpty) {
      throw Exception('在线曲库请求失败：${errors.first}');
    }

    return dedupeByTitleArtist(merged);
  }

  /// 真实全网公开歌单搜索 (网易云千万优质歌单)
  static Future<List<ImportedPlaylist>> searchOnlinePlaylists(String query, {int limit = 20, int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    try {
      final offset = (page - 1) * limit;
      return await neteaseService.searchPlaylists(cleanQuery, limit: limit, offset: offset);
    } catch (_) {
      return [];
    }
  }

  /// 真实全网歌手档案搜索
  static Future<List<ArtistProfile>> searchOnlineArtists(String query, {int limit = 20, int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    try {
      final offset = (page - 1) * limit;
      return await neteaseService.searchArtists(cleanQuery, limit: limit, offset: offset);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Track>> _searchKuwoTracks(String cleanQuery, {required int limit, int page = 0}) async {
    final kwUri = Uri.parse(
      'http://search.kuwo.cn/r.s?client=kt&all=${Uri.encodeComponent(cleanQuery)}&pn=$page&rn=$limit&vipver=1&ft=music&encoding=utf8&rformat=json&mobi=1',
    );
    final kwResp = await http.get(kwUri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }).timeout(_timeout);

    if (kwResp.statusCode != 200) return [];

    final data = jsonDecode(utf8.decode(kwResp.bodyBytes));
    final songs = data['abslist'] as List?;
    if (songs == null || songs.isEmpty) return [];

    final results = <Track>[];
    for (final item in songs) {
      final rawMid = (item['DC_TARGETID'] ?? item['MUSICRID'] ?? '').toString();
      final mid = rawMid.replaceAll('MUSIC_', '');
      if (mid.isEmpty) continue;

      final rawName = item['SONGNAME']?.toString() ?? '未知曲目';
      final name = rawName.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      final rawArtist = item['ARTIST']?.toString() ?? '未知歌手';
      final artist = rawArtist
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&', ' / ')
          .replaceAll('###', ' / ')
          .trim();

      final rawAlbum = item['ALBUM']?.toString() ?? '未知专辑';
      final album = rawAlbum.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      final durationSec = int.tryParse(item['DURATION']?.toString() ?? '240') ?? 240;
      final duration = Duration(seconds: durationSec);

      final albumPic = item['web_albumpic_short']?.toString();
      final mvPic = item['hts_MVPIC']?.toString();
      String coverUrl;
      if (albumPic != null && albumPic.isNotEmpty) {
        coverUrl = 'https://img1.kuwo.cn/star/albumcover/$albumPic';
      } else if (mvPic != null && mvPic.isNotEmpty) {
        coverUrl = mvPic;
      } else {
        coverUrl = NeteaseMusicService.fallbackCoverFor(name, artist);
      }

      final audioUrl = 'http://music.nxinxz.com/kw.php?id=$mid&level=standard&type=mp3';
      _urlCache['$name::$artist'] = audioUrl;

      results.add(Track(
        id: 'kw_$mid',
        title: name.isEmpty ? '未知曲目' : name,
        artist: artist.isEmpty ? '群星' : artist,
        album: album.isEmpty ? '单曲' : album,
        coverUrl: coverUrl,
        duration: duration,
        source: 'kuwo-sq',
        audioUrl: audioUrl,
        lyrics: const [],
      ));
    }
    return results;
  }

  /// 真实高保真音源智能解析与 Fallback 调度 (严格过滤失效提示音，精准匹配原声)
  static Future<String?> resolvePlayableAudioUrl(
    String title,
    String artist, {
    String? trackId,
    String? defaultUrl,
    bool forceRefresh = false,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    final cacheKey = '$cleanTitle::$cleanArtist';

    if (!forceRefresh && _urlCache.containsKey(cacheKey)) {
      final cached = _urlCache[cacheKey]!;
      if (cached.isNotEmpty && !cached.contains('588957081') && !cached.contains('/nf/')) {
        return cached;
      }
    }

    // 若原有链接为有效外部独立链接且不是已知 404/302 的网易云 outer 或 soundhelix 或 nxinxz
    if (!forceRefresh &&
        defaultUrl != null &&
        defaultUrl.isNotEmpty &&
        !defaultUrl.contains('soundhelix.com') &&
        !defaultUrl.contains('nxinxz.com') &&
        !defaultUrl.contains('588957081') &&
        !defaultUrl.contains('/nf/') &&
        !defaultUrl.contains('music.163.com/song/media/outer/url')) {
      final unwrapped = await unwrapRedirects(defaultUrl);
      if (!unwrapped.contains('588957081') && !unwrapped.contains('/nf/')) {
        return unwrapped;
      }
    }

    // 0. 若为网易云真实曲目 ID，优先尝试网易云原生高品质增强流
    final neId = NeteaseMusicService.pureSongId(trackId ?? defaultUrl ?? '');
    if (neId != null) {
      try {
        final res = await neteaseService.resolveStreamUrl(neId);
        if (res.isPlayable && res.url != null && res.url!.isNotEmpty) {
          final directUrl = await unwrapRedirects(res.url!);
          _urlCache[cacheKey] = directUrl;
          return directUrl;
        }
      } catch (_) {}
    }

    // 1. 跨音源智能解析：通过多层精准词条在 Kuwo 高保真音轨库中匹配真实音频
    final firstArtist = cleanArtist.split(RegExp(r'[/,&、·]')).first.trim();
    final strippedTitle = cleanTitle.replaceAll(RegExp(r'\(.*?\)|\[.*?\]|（.*?）'), '').trim();
    final candidateQueries = <String>{
      '$cleanTitle $firstArtist'.trim(),
      if (strippedTitle.isNotEmpty && strippedTitle != cleanTitle) '$strippedTitle $firstArtist'.trim(),
      cleanTitle,
      if (strippedTitle.isNotEmpty && strippedTitle != cleanTitle) strippedTitle,
    };

    final targetTitleNorm = _normalizeForMatch(cleanTitle);
    final targetArtistNorm = _normalizeForMatch(cleanArtist);

    for (final q in candidateQueries) {
      if (q.isEmpty) continue;
      try {
        final uri = Uri.parse(
          'http://search.kuwo.cn/r.s?client=kt&all=${Uri.encodeComponent(q)}&pn=0&rn=5&vipver=1&ft=music&encoding=utf8&rformat=json&mobi=1',
        );
        final resp = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }).timeout(_timeout);

        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          final songs = data['abslist'] as List?;
          if (songs != null && songs.isNotEmpty) {
            // 智能挑选最契合目标曲目名称与歌手的原曲，避免误取 live/remix 或无关歌曲
            Map<String, dynamic>? bestSong;
            for (final item in songs) {
              if (item is! Map) continue;
              final sName = _normalizeForMatch(item['SONGNAME']?.toString() ?? '');
              final sArtist = _normalizeForMatch(item['ARTIST']?.toString() ?? '');
              if (sName == targetTitleNorm && (sArtist.contains(targetArtistNorm) || targetArtistNorm.contains(sArtist))) {
                bestSong = item.cast<String, dynamic>();
                break;
              }
              if (sName.contains(targetTitleNorm) && (sArtist.contains(targetArtistNorm) || targetArtistNorm.contains(sArtist))) {
                bestSong ??= item.cast<String, dynamic>();
              }
            }
            final firstSong = songs.first;
            if (bestSong == null && firstSong is Map) {
              bestSong = firstSong.cast<String, dynamic>();
            }

            if (bestSong != null) {
              final rawMid = (bestSong['DC_TARGETID'] ?? bestSong['MUSICRID'] ?? '').toString();
              final mid = rawMid.replaceAll('MUSIC_', '');
              if (mid.isNotEmpty) {
                // 1.1 尝试 Kuwo convert_url，但严格过滤兜底失效提示音（588957081.mp3 / /nf/ 占位流）
                try {
                  final antiUri = Uri.parse(
                    'http://antiserver.kuwo.cn/anti.s?type=convert_url&rid=$mid&format=mp3&response=url',
                  );
                  final antiResp = await http.get(antiUri, headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  }).timeout(const Duration(seconds: 4));
                  if (antiResp.statusCode == 200) {
                    final antiUrl = antiResp.body.trim();
                    if ((antiUrl.startsWith('http://') || antiUrl.startsWith('https://')) &&
                        !antiUrl.contains('588957081') &&
                        !antiUrl.contains('/nf/')) {
                      _urlCache[cacheKey] = antiUrl;
                      return antiUrl;
                    }
                  }
                } catch (_) {}

                // 1.2 若 anti.s 为 VIP 占位流或失败，跟进 nxinxz 真实直链
                try {
                  final streamUrl = 'http://music.nxinxz.com/kw.php?id=$mid&level=standard&type=mp3';
                  final unwrapped = await unwrapRedirects(streamUrl);
                  if (unwrapped.isNotEmpty &&
                      !unwrapped.contains('nxinxz.com') &&
                      !unwrapped.contains('588957081') &&
                      !unwrapped.contains('/nf/')) {
                    _urlCache[cacheKey] = unwrapped;
                    return unwrapped;
                  }
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. 真实网易云原生音频流 Fallback
    try {
      final neTracks = await neteaseService.search('$cleanTitle $firstArtist', limit: 3);
      for (final nt in neTracks) {
        final pureId = NeteaseMusicService.pureSongId(nt.id);
        if (pureId != null) {
          final res = await neteaseService.resolveStreamUrl(pureId);
          if (res.isPlayable && res.url != null && res.url!.isNotEmpty) {
            final directUrl = await unwrapRedirects(res.url!);
            _urlCache[cacheKey] = directUrl;
            return directUrl;
          }
        }
      }
    } catch (_) {}

    // 3. iTunes 官方高可用试听流兜底（确保列表必定有声）
    try {
      final itunesList = await itunesService.search('$cleanTitle $firstArtist', limit: 2);
      if (itunesList.isNotEmpty && itunesList.first.audioUrl != null) {
        final iUrl = itunesList.first.audioUrl!;
        _urlCache[cacheKey] = iUrl;
        return iUrl;
      }
    } catch (_) {}

    // 如果无法解析，回退默认并展开重定向
    if (defaultUrl != null && defaultUrl.isNotEmpty) {
      return await unwrapRedirects(defaultUrl);
    }
    return defaultUrl;
  }

  /// 针对指定目标音源主动解析 (支持用户主动手动换源)
  static Future<String?> resolveUrlFromSpecificSource(
    String title,
    String artist,
    String targetSource, {
    String? trackId,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    final firstArtist = cleanArtist.split(RegExp(r'[/,&、·]')).first.trim();

    if (targetSource.contains('kuwo')) {
      try {
        final uri = Uri.parse(
          'http://search.kuwo.cn/r.s?client=kt&all=${Uri.encodeComponent('$cleanTitle $firstArtist')}&pn=0&rn=3&vipver=1&ft=music&encoding=utf8&rformat=json&mobi=1',
        );
        final resp = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          final songs = data['abslist'] as List?;
          if (songs != null && songs.isNotEmpty) {
            final rawMid = (songs.first['DC_TARGETID'] ?? songs.first['MUSICRID'] ?? '').toString();
            final mid = rawMid.replaceAll('MUSIC_', '');
            if (mid.isNotEmpty) {
              final streamUrl = 'http://music.nxinxz.com/kw.php?id=$mid&level=standard&type=mp3';
              final unwrapped = await unwrapRedirects(streamUrl);
              if (unwrapped.isNotEmpty && !unwrapped.contains('nxinxz.com') && !unwrapped.contains('588957081')) {
                return unwrapped;
              }
            }
          }
        }
      } catch (_) {}
    } else if (targetSource.contains('netease')) {
      try {
        final neTracks = await neteaseService.search('$cleanTitle $firstArtist', limit: 3);
        for (final nt in neTracks) {
          final pureId = NeteaseMusicService.pureSongId(nt.id);
          if (pureId != null) {
            final res = await neteaseService.resolveStreamUrl(pureId);
            if (res.isPlayable && res.url != null && res.url!.isNotEmpty) {
              return await unwrapRedirects(res.url!);
            }
          }
        }
      } catch (_) {}
    } else if (targetSource.contains('itunes')) {
      try {
        final itunesList = await itunesService.search('$cleanTitle $firstArtist', limit: 2);
        if (itunesList.isNotEmpty && itunesList.first.audioUrl != null) {
          return itunesList.first.audioUrl!;
        }
      } catch (_) {}
    }

    return resolvePlayableAudioUrl(title, artist, trackId: trackId, forceRefresh: true);
  }

  /// 展开任意 HTTP 301/302 重定向，获取最终物理直接可播放地址
  static Future<String> unwrapRedirects(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return url;
    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(url))..followRedirects = false;
      req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
      final response = await client.send(req).timeout(const Duration(seconds: 4));
      if (response.isRedirect && response.headers.containsKey('location')) {
        final loc = response.headers['location']!;
        if (loc.startsWith('http')) return loc;
      }
    } catch (_) {}
    return url;
  }

  /// 2. 网易云/公开歌单解析与一键导入
  static Future<ImportedPlaylist?> importNeteasePlaylist(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    try {
      final result = await neteaseService.importPlaylist(cleanInput);
      if (result != null) return result;
    } catch (_) {}

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
            final rawItemCover = item['album']?['picUrl']?.toString();
            final itemCover = (rawItemCover != null && rawItemCover.isNotEmpty)
                ? rawItemCover
                : (coverUrl.isNotEmpty ? coverUrl : NeteaseMusicService.fallbackCoverFor(name, artists));
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
    } catch (_) {}
    return null;
  }

  /// 3. 获取单曲真实 LRC 歌词 (支持 Kuwo 与 网易云双向解析)
  static Future<List<LyricLine>> fetchTrackLyric(String trackId, {String? title, String? artist}) async {
    // 1. 若为 Kuwo 音轨
    if (trackId.startsWith('kw_')) {
      final mid = trackId.replaceAll('kw_', '');
      try {
        final uri = Uri.parse('http://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=$mid');
        final resp = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          final lrclist = data['data']?['lrclist'] as List?;
          if (lrclist != null && lrclist.isNotEmpty) {
            final parsed = <LyricLine>[];
            for (final line in lrclist) {
              final timeSec = double.tryParse(line['time']?.toString() ?? '0') ?? 0.0;
              final lineText = line['lineLyric']?.toString() ?? '';
              if (lineText.trim().isNotEmpty) {
                parsed.add(LyricLine(
                  time: Duration(milliseconds: (timeSec * 1000).toInt()),
                  text: lineText.trim(),
                ));
              }
            }
            if (parsed.isNotEmpty) return parsed;
          }
        }
      } catch (_) {}
    }

    // 2. 若为网易云音轨或 fallback
    final pureId = trackId.replaceAll('netease_', '');
    try {
      final lyrics = await neteaseService.fetchLyric(pureId);
      if (lyrics.isNotEmpty) return lyrics;
    } catch (_) {}

    // 3. 兜底尝试通过标题+歌手检索 Kuwo 歌词
    if (title != null && title.trim().isNotEmpty) {
      try {
        final kwUri = Uri.parse(
          'http://search.kuwo.cn/r.s?client=kt&all=${Uri.encodeComponent('$title ${artist ?? ""}'.trim())}&pn=0&rn=1&vipver=1&ft=music&encoding=utf8&rformat=json&mobi=1',
        );
        final kwResp = await http.get(kwUri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }).timeout(_timeout);
        if (kwResp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(kwResp.bodyBytes));
          final songs = data['abslist'] as List?;
          if (songs != null && songs.isNotEmpty) {
            final rawMid = (songs.first['DC_TARGETID'] ?? songs.first['MUSICRID'] ?? '').toString().replaceAll('MUSIC_', '');
            if (rawMid.isNotEmpty) {
              return await fetchTrackLyric('kw_$rawMid');
            }
          }
        }
      } catch (_) {}
    }

    return [];
  }

  /// 4. 实时抓取官方巅峰榜单真实曲库（支持名称与真实歌单 ID）
  static Future<List<Track>> fetchToplistTracks(String chartTitleOrId, {int limit = 50}) async {
    const chartMap = {
      '飙升榜': '19723756',
      '热歌榜': '3778678',
      '新歌榜': '3779629',
      '原创榜': '2884035',
      '黑胶VIP榜': '71384707',
      '黑胶VIP爱听榜': '71384707',
      '电音榜': '1978921795',
      '华语金曲榜': '4395559',
      'ACG动漫榜': '71385702',
      '欧美热歌榜': '28095138',
      '日本热歌榜': '28095777',
      '韩国热歌榜': '28095139',
      '英国UK榜': '180106',
      'Billboard榜': '60198',
      '达人榜': '991319590',
      '实时榜': '18176153161',
    };
    final pid = chartMap[chartTitleOrId] ?? (RegExp(r'^\d+$').hasMatch(chartTitleOrId) ? chartTitleOrId : null);
    if (pid == null) return [];

    final playlist = await importNeteasePlaylist(pid);
    if (playlist != null && playlist.tracks.isNotEmpty) {
      return playlist.tracks.take(limit).toList();
    }
    return [];
  }

  /// 5. 抓取所有 60+ 官方真实排行榜单元数据
  static Future<List<Map<String, dynamic>>> fetchAllToplists() async {
    return neteaseService.fetchAllToplists();
  }

  /// 6. 抓取真实热门歌手分类列表
  static Future<List<Map<String, dynamic>>> fetchArtistList({
    int area = -1,
    int type = -1,
    int limit = 50,
  }) async {
    return neteaseService.fetchArtistList(area: area, type: type, limit: limit);
  }

  /// 7. 抓取歌手真实热门 50 首单曲
  static Future<List<Track>> fetchArtistTopSongs(String artistId, {String? artistName}) async {
    try {
      final songs = await neteaseService.fetchArtistTopSongs(artistId);
      if (songs.isNotEmpty) return songs;
    } catch (_) {}

    if (artistName != null && artistName.isNotEmpty) {
      try {
        final searched = await searchOnlineTracks(artistName, limit: 50);
        if (searched.isNotEmpty) return searched;
      } catch (_) {}
    }
    return const [];
  }
}
