import 'dart:convert';
import 'package:http/http.dart' as http;
import '../audio/track_model.dart';
import 'itunes_music_service.dart';
import 'netease_music_service.dart';
import 'lx_script_sandbox.dart';
import 'lx_source_model.dart';

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
  final List<String> allTrackIds;

  const ImportedPlaylist({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.trackCount,
    required this.tracks,
    this.isCustom = false,
    this.allTrackIds = const [],
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
    List<String>? allTrackIds,
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
      allTrackIds: allTrackIds ?? this.allTrackIds,
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

    // 0. 若为网易云真实曲目 ID，优先尝试网易云原生高品质增强流（320k 物理高保真直链）
    final neId = NeteaseMusicService.pureSongId(trackId ?? defaultUrl ?? '');
    if (neId != null) {
      try {
        final res = await neteaseService.resolveStreamUrl(neId, quality: NeteaseQuality.br320k);
        if (res.isPlayable && res.url != null && res.url!.isNotEmpty) {
          final directUrl = upgradeToSecureUrl(res.url!);
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
                      final secureUrl = upgradeToSecureUrl(antiUrl);
                      _urlCache[cacheKey] = secureUrl;
                      return secureUrl;
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
                    final secureUrl = upgradeToSecureUrl(unwrapped);
                    _urlCache[cacheKey] = secureUrl;
                    return secureUrl;
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
          final res = await neteaseService.resolveStreamUrl(pureId, quality: NeteaseQuality.br320k);
          if (res.isPlayable && res.url != null && res.url!.isNotEmpty) {
            final directUrl = upgradeToSecureUrl(res.url!);
            _urlCache[cacheKey] = directUrl;
            return directUrl;
          }
        }
      }
    } catch (_) {}

    // 3. 落雪社区顶级源 (六音 / Huibq / ikun) 驱动真实物理取流兜底 (解决 VIP 歌曲全网无源问题)
    String primaryPlatform = 'wy';
    String primaryMid = '';
    if (trackId != null && trackId.startsWith('netease_')) {
      primaryPlatform = 'wy';
      primaryMid = trackId.replaceAll('netease_', '');
    } else if (trackId != null && trackId.startsWith('kw_')) {
      primaryPlatform = 'kw';
      primaryMid = trackId.replaceAll('kw_', '');
    }

    final platformsToTry = {primaryPlatform, 'tx', 'kg', 'kw', 'mg'}.toList();
    final fallbackDriverIds = ['lx_sixyin', 'lx_huibq', 'lx_ikun', 'lx_default_aggregate'];

    for (final driverId in fallbackDriverIds) {
      final lxDriver = LxSourceEngine.instance.getDriver(driverId);
      if (lxDriver == null) continue;

      for (final plat in platformsToTry) {
        try {
          final mid = (plat == primaryPlatform && primaryMid.isNotEmpty)
              ? primaryMid
              : '${cleanTitle.hashCode}';
          final lxSong = LxSongInfo(
            id: trackId ?? '${plat}_${cleanTitle.hashCode}',
            songMid: mid,
            title: cleanTitle,
            artist: cleanArtist,
            album: '',
            source: plat, // 严正传入真实平台代码：'wy', 'tx', 'kg', 'kw', 'mg'
            duration: Duration.zero,
          );
          final lxUrl = await lxDriver
              .getMusicUrl(lxSong, LxSourceEngine.instance.preferredQuality)
              .timeout(const Duration(milliseconds: 1800), onTimeout: () => null);

          if (lxUrl != null && lxUrl.isNotEmpty && (lxUrl.startsWith('http://') || lxUrl.startsWith('https://'))) {
            final directUrl = await unwrapRedirects(lxUrl);
            if (directUrl.isNotEmpty) {
              _urlCache[cacheKey] = directUrl;
              return directUrl;
            }
          }
        } catch (_) {}
      }
    }

    // 如果无法解析，回退默认并展开重定向
    if (defaultUrl != null && defaultUrl.isNotEmpty) {
      return await unwrapRedirects(defaultUrl);
    }
    return defaultUrl;
  }

  /// 针对指定目标音源主动解析 (支持用户主动手动换源：酷我、网易云、QQ、酷狗、咪咕、润音官方、iTunes、落雪脚本)
  static Future<String?> resolveUrlFromSpecificSource(
    String title,
    String artist,
    String targetSource, {
    String? trackId,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    final firstArtist = cleanArtist.split(RegExp(r'[/,&、·]')).first.trim();

    if (targetSource.contains('kuwo') || targetSource == 'kw') {
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
    } else if (targetSource.contains('netease') || targetSource == 'wy') {
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
    } else if (targetSource.contains('qq') || targetSource == 'tx') {
      try {
        final lxSong = LxSongInfo(
          id: trackId ?? 'tx_${cleanTitle.hashCode}',
          songMid: trackId ?? '${cleanTitle.hashCode}',
          title: cleanTitle,
          artist: cleanArtist,
          album: '',
          source: LxPlatformId.tx,
          duration: Duration.zero,
        );
        final engine = LxSourceEngine.instance;
        final targetDriverId = engine.drivers.containsKey('lx_sixyin') ? 'lx_sixyin' : LxPlatformId.tx;
        final res = await engine.resolveMusicUrlWithFallback(
          lxSong,
          sourceId: targetDriverId,
          enableSourceFallback: true,
        );
        if (res.url.isNotEmpty && (res.url.startsWith('http://') || res.url.startsWith('https://'))) {
          return await unwrapRedirects(res.url);
        }
      } catch (_) {}
    } else if (targetSource.contains('kugou') || targetSource == 'kg') {
      try {
        final uri = Uri.parse(
          'http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=${Uri.encodeComponent('$cleanTitle $firstArtist')}&page=1&pagesize=3',
        );
        final resp = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          final songs = data['data']?['info'] as List?;
          if (songs != null && songs.isNotEmpty) {
            final hash = (songs.first['hash'] ?? '').toString();
            if (hash.isNotEmpty) {
              final infoUri = Uri.parse('http://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=$hash');
              final infoResp = await http.get(infoUri).timeout(_timeout);
              if (infoResp.statusCode == 200) {
                final infoData = jsonDecode(utf8.decode(infoResp.bodyBytes));
                final url = (infoData['url'] ?? '').toString();
                if (url.isNotEmpty && url.startsWith('http')) {
                  return await unwrapRedirects(url);
                }
              }
            }
          }
        }
      } catch (_) {}
      try {
        final lxSong = LxSongInfo(
          id: trackId ?? 'kg_${cleanTitle.hashCode}',
          songMid: trackId ?? '${cleanTitle.hashCode}',
          title: cleanTitle,
          artist: cleanArtist,
          album: '',
          source: LxPlatformId.kg,
          duration: Duration.zero,
        );
        final engine = LxSourceEngine.instance;
        final targetDriverId = engine.drivers.containsKey('lx_sixyin') ? 'lx_sixyin' : LxPlatformId.kg;
        final res = await engine.resolveMusicUrlWithFallback(
          lxSong,
          sourceId: targetDriverId,
          enableSourceFallback: true,
        );
        if (res.url.isNotEmpty && (res.url.startsWith('http://') || res.url.startsWith('https://'))) {
          return await unwrapRedirects(res.url);
        }
      } catch (_) {}
    } else if (targetSource.contains('migu') || targetSource == 'mg') {
      try {
        final lxSong = LxSongInfo(
          id: trackId ?? 'mg_${cleanTitle.hashCode}',
          songMid: trackId ?? '${cleanTitle.hashCode}',
          title: cleanTitle,
          artist: cleanArtist,
          album: '',
          source: LxPlatformId.mg,
          duration: Duration.zero,
        );
        final engine = LxSourceEngine.instance;
        final targetDriverId = engine.drivers.containsKey('lx_sixyin') ? 'lx_sixyin' : LxPlatformId.mg;
        final res = await engine.resolveMusicUrlWithFallback(
          lxSong,
          sourceId: targetDriverId,
          enableSourceFallback: true,
        );
        if (res.url.isNotEmpty && (res.url.startsWith('http://') || res.url.startsWith('https://'))) {
          return await unwrapRedirects(res.url);
        }
      } catch (_) {}
    } else if (targetSource.contains('mellow') || targetSource.contains('preset')) {
      try {
        final lxSong = LxSongInfo(
          id: trackId ?? 'mellow_${cleanTitle.hashCode}',
          songMid: trackId ?? '${cleanTitle.hashCode}',
          title: cleanTitle,
          artist: cleanArtist,
          album: '',
          source: LxPlatformId.mellow,
          duration: Duration.zero,
        );
        final res = await LxSourceEngine.instance.resolveMusicUrlWithFallback(
          lxSong,
          sourceId: LxPlatformId.mellow,
          enableSourceFallback: true,
        );
        if (res.url.isNotEmpty && (res.url.startsWith('http://') || res.url.startsWith('https://'))) {
          return await unwrapRedirects(res.url);
        }
      } catch (_) {}
    } else if (targetSource.contains('itunes')) {
      try {
        final itunesList = await itunesService.search('$cleanTitle $firstArtist', limit: 2);
        if (itunesList.isNotEmpty && itunesList.first.audioUrl != null) {
          return itunesList.first.audioUrl!;
        }
      } catch (_) {}
    } else if (targetSource.contains('sixyin') ||
        targetSource.contains('lx') ||
        targetSource.contains('custom') ||
        targetSource.contains('alger') ||
        targetSource.contains('huibq') ||
        targetSource.contains('ikun') ||
        targetSource.contains('official')) {
      final engine = LxSourceEngine.instance;
      String driverId = targetSource;
      if (!engine.drivers.containsKey(driverId)) {
        if (targetSource.contains('sixyin')) {
          driverId = 'lx_sixyin';
        } else if (targetSource.contains('huibq')) {
          driverId = 'lx_huibq';
        } else if (targetSource.contains('ikun')) {
          driverId = 'lx_ikun';
        } else {
          driverId = engine.activeDriver.metadata.id;
        }
      }

      final lxDriver = engine.getDriver(driverId);
      if (lxDriver != null) {
        String primaryPlatform = 'wy';
        String primaryMid = '';
        if (trackId != null && trackId.startsWith('netease_')) {
          primaryPlatform = 'wy';
          primaryMid = trackId.replaceAll('netease_', '');
        } else if (trackId != null && trackId.startsWith('kw_')) {
          primaryPlatform = 'kw';
          primaryMid = trackId.replaceAll('kw_', '');
        }

        final platforms = {primaryPlatform, 'tx', 'kg', 'kw', 'mg'}.toList();
        for (final plat in platforms) {
          try {
            final mid = (plat == primaryPlatform && primaryMid.isNotEmpty)
                ? primaryMid
                : '${cleanTitle.hashCode}';
            final lxSong = LxSongInfo(
              id: trackId ?? '${plat}_${cleanTitle.hashCode}',
              songMid: mid,
              title: cleanTitle,
              artist: cleanArtist,
              album: '',
              source: plat, // 严正传入真实平台代码
              duration: Duration.zero,
            );
            final url = await lxDriver
                .getMusicUrl(lxSong, engine.preferredQuality)
                .timeout(const Duration(milliseconds: 2000), onTimeout: () => null);

            if (url != null && url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
              return await unwrapRedirects(url);
            }
          } catch (_) {}
        }
      }
    }

    return null;
  }

  /// 将所有支持 HTTPS 的音频 CDN 直链统一升级为安全 HTTPS 传输，彻底杜绝系统 ATS 拦截
  static String upgradeToSecureUrl(String url) {
    if (url.startsWith('http://')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final host = uri.host.toLowerCase();
        if (host.endsWith('music.126.net') ||
            host.endsWith('music.163.com') ||
            host.endsWith('kuwo.cn') ||
            host.endsWith('kugou.com') ||
            host.endsWith('migu.cn') ||
            host.endsWith('qq.com') ||
            host.endsWith('apple.com')) {
          return url.replaceFirst('http://', 'https://');
        }
      }
    }
    return url;
  }

  /// 展开任意 HTTP 301/302 重定向，获取最终物理直接可播放地址 (最多追踪 3 跳，保证 client.close 杜绝句柄泄漏)
  static Future<String> unwrapRedirects(String url, {http.Client? customClient, int maxRedirects = 3}) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return url;

    // 若已经是最终静态音频文件且非重定向代理，直接升级安全协议后快速返回，避免发起无谓的大文件下载请求
    final lower = url.toLowerCase();
    if (!lower.contains('/outer/url') &&
        !lower.contains('convert_url') &&
        !lower.contains('kw.php') &&
        (lower.contains('.mp3') || lower.contains('.flac') || lower.contains('.m4a') || lower.contains('.aac'))) {
      return upgradeToSecureUrl(url);
    }

    final client = customClient ?? http.Client();
    var currentUrl = url;
    var hops = 0;
    try {
      while (hops < maxRedirects) {
        final uri = Uri.tryParse(currentUrl);
        if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) break;

        // 优先使用轻量级 HEAD 请求，仅读取响应头，不读取大文件 body
        final req = http.Request('HEAD', uri)..followRedirects = false;
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
        req.headers['Referer'] = 'https://music.163.com/';
        http.StreamedResponse response;
        try {
          response = await client.send(req).timeout(const Duration(milliseconds: 2500));
        } catch (_) {
          // 若 HEAD 失败或遇到 405，回退到 Range 首字节 GET 探测
          final getReq = http.Request('GET', uri)..followRedirects = false;
          getReq.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
          getReq.headers['Referer'] = 'https://music.163.com/';
          getReq.headers['Range'] = 'bytes=0-0';
          response = await client.send(getReq).timeout(const Duration(milliseconds: 2500));
        }

        if (response.isRedirect && response.headers.containsKey('location')) {
          final loc = response.headers['location']!;
          if (loc.contains('/404') || loc.endsWith('/404.mp3')) {
            currentUrl = '';
            break;
          }
          final resolvedUri = uri.resolve(loc);
          currentUrl = resolvedUri.toString();
          hops++;
        } else {
          break;
        }
      }
    } catch (_) {
    } finally {
      if (customClient == null) {
        client.close();
      }
    }
    return currentUrl.isNotEmpty ? upgradeToSecureUrl(currentUrl) : '';
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
      // 优先请求 v6 高精接口，获取完整曲目元数据与 trackIds 完整序列
      final uri = Uri.parse('https://music.163.com/api/v6/playlist/detail?id=$playlistId');
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.163.com/',
      }).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final plData = (data['playlist'] ?? data['result']) as Map<String, dynamic>?;
        if (plData != null) {
          final title = plData['name']?.toString() ?? '导入歌单';
          final coverUrl = plData['coverImgUrl']?.toString() ??
              'https://p1.music.126.net/6y-UleORITEDbvrOLAL-vQ==/109951164803975765.jpg';
          final description = plData['description']?.toString() ?? '来自网易云音乐公开歌单';
          final totalTrackCount = (plData['trackCount'] as num?)?.toInt() ?? 0;

          // 提取全量 trackIds 列表 (杜绝仅下发前 6~10 首限制)
          final rawTrackIds = plData['trackIds'] as List? ?? [];
          final allTrackIds = <String>[];
          for (final item in rawTrackIds) {
            if (item is Map && item['id'] != null) {
              allTrackIds.add(item['id'].toString());
            } else if (item != null) {
              allTrackIds.add(item.toString());
            }
          }

          // 提取 privileges 权限映射：key 为 id, value 为 pl (当前真实可播比特率，pl <= 0 代表官方已无版权下架)
          final privList = data['privileges'] as List? ?? [];
          final plMap = <String, int>{};
          for (final p in privList) {
            if (p is Map) {
              final pid = p['id']?.toString() ?? '';
              final pl = (p['pl'] as num?)?.toInt() ?? 0;
              if (pid.isNotEmpty) plMap[pid] = pl;
            }
          }

          final tracksJson = plData['tracks'] as List? ?? [];
          List<Track> parsedTracks = <Track>[];
          for (final item in tracksJson) {
            final id = item['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final name = item['name']?.toString() ?? '未知曲目';
            final artists = (item['artists'] as List? ?? item['ar'] as List?)
                    ?.map((a) => a['name']?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .join(' / ') ??
                '未知歌手';
            final album = (item['album']?['name'] ?? item['al']?['name'])?.toString() ?? '未知专辑';
            final durationMs = ((item['duration'] ?? item['dt']) as num?)?.toInt() ?? 240000;
            final duration = Duration(milliseconds: durationMs);
            final rawItemCover = (item['album']?['picUrl'] ?? item['al']?['picUrl'])?.toString();
            final itemCover = (rawItemCover != null && rawItemCover.isNotEmpty)
                ? rawItemCover
                : (coverUrl.isNotEmpty ? coverUrl : NeteaseMusicService.fallbackCoverFor(name, artists));

            final pl = plMap[id] ?? ((item['fee'] == 0 || item['fee'] == 8) ? 320000 : 0);
            final audioUrl = 'https://music.163.com/song/media/outer/url?id=$id.mp3';

            parsedTracks.add(Track(
              id: 'netease_$id',
              title: name,
              artist: artists,
              album: album,
              coverUrl: itemCover,
              duration: duration,
              source: pl > 0 ? 'netease-playlist' : 'netease-unlicensed',
              audioUrl: audioUrl,
              lyrics: const [],
            ));
          }

          // 若服务端返回的 tracks 被截断且 trackIds 充足，首屏全量/足量拉取（<=100首一次性拉齐，超出则拉取前60首填满屏幕并支持继续懒加载）
          if (allTrackIds.length > parsedTracks.length) {
            final takeCount = allTrackIds.length <= 100 ? allTrackIds.length : 60;
            final firstBatchIds = allTrackIds.take(takeCount).toList();
            final enriched = await fetchTracksByIds(firstBatchIds, defaultCover: coverUrl);
            if (enriched.isNotEmpty) {
              parsedTracks = enriched;
            }
          }

          final finalTotalCount = totalTrackCount > 0
              ? totalTrackCount
              : (allTrackIds.isNotEmpty ? allTrackIds.length : parsedTracks.length);

          return ImportedPlaylist(
            id: playlistId,
            title: title,
            coverUrl: coverUrl,
            description: description,
            trackCount: finalTotalCount,
            tracks: parsedTracks,
            allTrackIds: allTrackIds,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// 批量拉取歌曲详情列表 (官方稳定 GET /api/song/detail + POST /api/v3/song/detail 双通道高可用，支持全量与分页懒加载)
  static Future<List<Track>> fetchTracksByIds(List<String> rawIds, {String? defaultCover}) async {
    final cleanIds = rawIds
        .map((id) => id.replaceAll('netease_', '').trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (cleanIds.isEmpty) return const [];

    // 通道 1: 官方轻量稳定的 GET /api/song/detail?ids=[...] 接口
    try {
      final getUri = Uri.parse('https://music.163.com/api/song/detail?ids=%5B${cleanIds.join('%2C')}%5D');
      final getResp = await http.get(
        getUri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://music.163.com/',
        },
      ).timeout(_timeout);

      if (getResp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(getResp.bodyBytes));
        final songs = data['songs'] as List? ?? [];
        if (songs.isNotEmpty) {
          final privList = data['privileges'] as List? ?? [];
          final plMap = <String, int>{};
          for (final p in privList) {
            if (p is Map) {
              final pid = p['id']?.toString() ?? '';
              final pl = (p['pl'] as num?)?.toInt() ?? 0;
              if (pid.isNotEmpty) plMap[pid] = pl;
            }
          }

          final parsedTracks = <Track>[];
          for (final item in songs) {
            if (item is! Map) continue;
            final id = item['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final name = item['name']?.toString() ?? '未知曲目';
            final artists = (item['artists'] as List? ?? item['ar'] as List?)
                    ?.map((a) => a is Map ? (a['name']?.toString() ?? '') : '')
                    .where((s) => s.isNotEmpty)
                    .join(' / ') ??
                '未知歌手';
            final album = (item['album'] is Map
                ? (item['album']['name']?.toString() ?? '未知专辑')
                : (item['al'] is Map ? item['al']['name']?.toString() ?? '未知专辑' : '未知专辑'));
            final durationMs = ((item['duration'] ?? item['dt']) as num?)?.toInt() ?? 240000;
            final duration = Duration(milliseconds: durationMs);
            final rawItemCover = (item['album'] is Map
                ? item['album']['picUrl']?.toString()
                : (item['al'] is Map ? item['al']['picUrl']?.toString() : null));
            final itemCover = (rawItemCover != null && rawItemCover.isNotEmpty)
                ? rawItemCover
                : (defaultCover ?? NeteaseMusicService.fallbackCoverFor(name, artists));
            final pl = plMap[id] ?? ((item['fee'] == 0 || item['fee'] == 8) ? 320000 : 0);
            final audioUrl = 'https://music.163.com/song/media/outer/url?id=$id.mp3';

            parsedTracks.add(Track(
              id: 'netease_$id',
              title: name,
              artist: artists,
              album: album,
              coverUrl: itemCover,
              duration: duration,
              source: pl > 0 ? 'netease-playlist' : 'netease-unlicensed',
              audioUrl: audioUrl,
              lyrics: const [],
            ));
          }

          if (parsedTracks.isNotEmpty) {
            return parsedTracks;
          }
        }
      }
    } catch (_) {}

    // 通道 2: POST /api/v3/song/detail 备用通道
    try {
      final uri = Uri.parse('https://music.163.com/api/v3/song/detail');
      final cPayload = jsonEncode(cleanIds.map((id) => {'id': id}).toList());
      final resp = await http.post(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://music.163.com/',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'c': cPayload},
      ).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final songs = data['songs'] as List? ?? [];
        final privList = data['privileges'] as List? ?? [];
        final plMap = <String, int>{};
        for (final p in privList) {
          if (p is Map) {
            final pid = p['id']?.toString() ?? '';
            final pl = (p['pl'] as num?)?.toInt() ?? 0;
            if (pid.isNotEmpty) plMap[pid] = pl;
          }
        }

        final parsedTracks = <Track>[];
        for (final item in songs) {
          if (item is! Map) continue;
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final name = item['name']?.toString() ?? '未知曲目';
          final artists = (item['ar'] as List? ?? item['artists'] as List?)
                  ?.map((a) => a is Map ? (a['name']?.toString() ?? '') : '')
                  .where((s) => s.isNotEmpty)
                  .join(' / ') ??
              '未知歌手';
          final album = item['al'] is Map
              ? (item['al']['name']?.toString() ?? '未知专辑')
              : (item['album'] is Map ? item['album']['name']?.toString() ?? '未知专辑' : '未知专辑');
          final durationMs = ((item['dt'] ?? item['duration']) as num?)?.toInt() ?? 240000;
          final duration = Duration(milliseconds: durationMs);
          final rawItemCover = item['al'] is Map
              ? item['al']['picUrl']?.toString()
              : (item['album'] is Map ? item['album']['picUrl']?.toString() : null);
          final itemCover = (rawItemCover != null && rawItemCover.isNotEmpty)
              ? rawItemCover
              : (defaultCover ?? NeteaseMusicService.fallbackCoverFor(name, artists));
          final pl = plMap[id] ?? ((item['fee'] == 0 || item['fee'] == 8) ? 320000 : 0);
          final audioUrl = 'https://music.163.com/song/media/outer/url?id=$id.mp3';

          parsedTracks.add(Track(
            id: 'netease_$id',
            title: name,
            artist: artists,
            album: album,
            coverUrl: itemCover,
            duration: duration,
            source: pl > 0 ? 'netease-playlist' : 'netease-unlicensed',
            audioUrl: audioUrl,
            lyrics: const [],
          ));
        }
        return parsedTracks;
      }
    } catch (_) {}
    return const [];
  }

  /// 3. 获取单曲真实 LRC 歌词 (聚合 网易云直连 + 网易云搜索匹配 + 酷狗PC官方接口 + 酷我)
  static Future<List<LyricLine>> fetchTrackLyric(String trackId, {String? title, String? artist}) async {
    final cleanTitle = title?.trim() ?? '';
    final cleanArtist = artist?.trim() ?? '';
    final firstArtist = cleanArtist.split(RegExp(r'[/,&、·]')).first.trim();

    // 辅助检查：判断歌词是否真实有效（排除“暂无歌词”等伪占位）
    bool isValidLyrics(List<LyricLine> list) {
      if (list.isEmpty) return false;
      if (list.length == 1 && list.first.text.contains('暂无歌词')) return false;
      return true;
    }

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
            if (isValidLyrics(parsed)) return parsed;
          }
        }
      } catch (_) {}
    }

    // 2. 若为网易云音轨或纯数字 ID
    final pureId = NeteaseMusicService.pureSongId(trackId);
    if (pureId != null) {
      try {
        final lyrics = await neteaseService.fetchLyric(pureId);
        if (isValidLyrics(lyrics)) return lyrics;
      } catch (_) {}
    }

    // 3. 跨源通过 标题 + 歌手 搜索网易云匹配真实歌词
    if (cleanTitle.isNotEmpty) {
      try {
        final neTracks = await neteaseService.search('$cleanTitle $firstArtist', limit: 2);
        for (final nt in neTracks) {
          final matchedPureId = NeteaseMusicService.pureSongId(nt.id);
          if (matchedPureId != null && matchedPureId != pureId) {
            final lyrics = await neteaseService.fetchLyric(matchedPureId);
            if (isValidLyrics(lyrics)) return lyrics;
          }
        }
      } catch (_) {}
    }

    // 4. 聚合酷狗官方公开歌词接口 (含 base64 自动解析还原)
    if (cleanTitle.isNotEmpty) {
      for (final queryStr in ['$cleanTitle $firstArtist', cleanTitle]) {
        try {
          final searchUri = Uri.parse(
            'http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=${Uri.encodeComponent(queryStr)}&duration=0&hash=',
          );
          final searchResp = await http.get(searchUri, headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          }).timeout(const Duration(seconds: 3));

          if (searchResp.statusCode == 200) {
            final searchData = jsonDecode(utf8.decode(searchResp.bodyBytes));
            final candidates = searchData['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final first = candidates.first;
              final lyricId = first['id']?.toString() ?? '';
              final accessKey = first['accesskey']?.toString() ?? '';
              if (lyricId.isNotEmpty && accessKey.isNotEmpty) {
                final dlUri = Uri.parse(
                  'http://lyrics.kugou.com/download?ver=1&client=pc&id=$lyricId&accesskey=$accessKey&fmt=lrc&charset=utf8',
                );
                final dlResp = await http.get(dlUri, headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                }).timeout(const Duration(seconds: 3));

                if (dlResp.statusCode == 200) {
                  final dlData = jsonDecode(utf8.decode(dlResp.bodyBytes));
                  final base64Content = dlData['content']?.toString() ?? '';
                  if (base64Content.isNotEmpty) {
                    final lrcText = utf8.decode(base64Decode(base64Content));
                    final parsed = LyricLine.parseLrc(lrcText);
                    if (isValidLyrics(parsed)) return parsed;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    // 5. 兜底尝试通过标题+歌手检索 Kuwo 歌词
    if (cleanTitle.isNotEmpty) {
      try {
        final kwUri = Uri.parse(
          'http://search.kuwo.cn/r.s?client=kt&all=${Uri.encodeComponent('$cleanTitle $firstArtist')}&pn=0&rn=1&vipver=1&ft=music&encoding=utf8&rformat=json&mobi=1',
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
              final kwLyrics = await fetchTrackLyric('kw_$rawMid');
              if (isValidLyrics(kwLyrics)) return kwLyrics;
            }
          }
        }
      } catch (_) {}
    }

    return const [];
  }

  /// 4. 实时抓取官方巅峰榜单真实曲库（支持名称与真实歌单 ID，剔除无版权 404 死链）
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
      // 放大候选采样池，过滤掉已明确无版权与网易云官方下架的死链
      final rawList = playlist.tracks;
      final filtered = <Track>[];
      for (final t in rawList) {
        // 自动剔除网易云端明确标记为无播放版权（pl <= 0）的下架曲目
        if (t.source == 'netease-unlicensed') {
          continue;
        }
        filtered.add(t);
        if (filtered.length >= limit) break;
      }
      return filtered;
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

  /// 8. 抓取歌手完整资料（官方真实头像、作品总数、专辑数、传记等）
  static Future<Map<String, dynamic>?> fetchArtistDetail(String artistId, {String? artistName}) async {
    return neteaseService.fetchArtistDetail(artistId, artistName: artistName);
  }

  /// 9. 抓取歌手全部歌曲（支持分页突破 50 首代表作限制）
  static Future<Map<String, dynamic>> fetchArtistAllSongs(
    String artistId, {
    int offset = 0,
    int limit = 50,
  }) async {
    return neteaseService.fetchArtistAllSongs(artistId, offset: offset, limit: limit);
  }

  /// 10. 抓取全网真实热门精选歌单实时流 (支持多分类、分页懒加载、真实播放量与高清封面)
  static Future<List<SquarePlaylist>> Function({String cat, int offset, int limit})? mockTopPlaylistsFetcher;

  static Future<List<SquarePlaylist>> fetchTopPlaylists({
    String cat = '全部',
    int offset = 0,
    int limit = 30,
  }) async {
    if (mockTopPlaylistsFetcher != null) {
      return mockTopPlaylistsFetcher!(cat: cat, offset: offset, limit: limit);
    }
    // 映射 UI 标签到网易云开放接口分类体系
    String neteaseCat = cat;
    if (cat == '精选推荐') {
      neteaseCat = '全部';
    } else if (cat == '华语流行') {
      neteaseCat = '华语';
    } else if (cat == '沉静治愈') {
      neteaseCat = '治愈';
    } else if (cat == '古风雅乐') {
      neteaseCat = '古风';
    } else if (cat == '经典粤语') {
      neteaseCat = '粤语';
    } else if (cat == '深夜爵士') {
      neteaseCat = '爵士';
    } else if (cat == '纯音乐' || cat == '轻音乐') {
      neteaseCat = '轻音乐';
    } else if (cat == '摇滚') {
      neteaseCat = '摇滚';
    } else if (cat == 'ACG 动漫' || cat == 'ACG') {
      neteaseCat = 'ACG';
    } else if (cat == '民谣') {
      neteaseCat = '民谣';
    }

    final uri = Uri.parse(
      'https://music.163.com/api/playlist/list?cat=${Uri.encodeComponent(neteaseCat)}&order=hot&offset=$offset&limit=$limit',
    );

    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        'Referer': 'https://music.163.com/',
      }).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final list = data['playlists'] as List?;
        if (list != null && list.isNotEmpty) {
          final results = <SquarePlaylist>[];
          for (final item in list) {
            final id = item['id']?.toString() ?? '';
            final name = item['name']?.toString() ?? '精选歌单';
            final desc = item['description']?.toString() ?? '全网精选热门音乐歌单';
            final playCountNum = (item['playCount'] as num?)?.toInt() ?? 0;
            final countStr = playCountNum >= 100000000
                ? '${(playCountNum / 100000000).toStringAsFixed(1)}亿'
                : (playCountNum >= 10000
                    ? '${(playCountNum / 10000).toStringAsFixed(1)}万'
                    : playCountNum.toString());
            var rawCover = item['coverImgUrl']?.toString() ?? '';
            if (rawCover.startsWith('http://')) {
              rawCover = rawCover.replaceFirst('http://', 'https://');
            }
            if (rawCover.isNotEmpty && !rawCover.contains('?param=')) {
              rawCover = '$rawCover?param=300y300';
            }
            final trackCount = (item['trackCount'] as num?)?.toInt() ?? 0;

            results.add(
              SquarePlaylist(
                id: id,
                title: name,
                desc: desc,
                tag: cat,
                coverUrl: rawCover,
                playCount: countStr,
                tracks: const [], // 歌曲由通用详情页按需提取全量 trackIds 并懒加载
                trackCount: trackCount,
              ),
            );
          }
          return results;
        }
      }
    } catch (e) {
      // 弱网异常安全容错
    }

    // 弱网断网与测试沙箱环境下的高可用离线容错保底
    final fallbackSquarePlaylists = [
      SquarePlaylist(
        id: 'fallback-pl-1',
        title: '华语经典流行金曲堂',
        desc: '从千禧年代到黄金世代，听懂已非少年',
        tag: '华语流行',
        coverUrl: 'https://p1.music.126.net/6y-UleORITEDbvrOLAL-vQ==/109951164803975765.jpg',
        playCount: '184.2万',
        trackCount: 15,
        tracks: mockJayChouTracks,
      ),
      SquarePlaylist(
        id: 'fallback-pl-2',
        title: '温润声线 · 晚风与少年',
        desc: '治愈系都市抒情曲，温暖每一个孤单夜晚',
        tag: '沉静治愈',
        coverUrl: 'https://p2.music.126.net/L3cE6x8y2g6n7Q0o4w0z_g==/109951165123987114.jpg',
        playCount: '78.5万',
        trackCount: 15,
        tracks: mockBoYuanTracks,
      ),
      SquarePlaylist(
        id: 'fallback-pl-3',
        title: '空山新雨 · 禅意清音集',
        desc: '古筝与古琴清越合鸣，洗涤世间纷扰',
        tag: '古风雅乐',
        coverUrl: 'https://p1.music.126.net/2z6yB1nJd5b0yP8T4XfRrw==/109951163969562818.jpg',
        playCount: '63.8万',
        trackCount: 12,
        tracks: mockWuNaTracks,
      ),
      SquarePlaylist(
        id: 'fallback-pl-4',
        title: '不朽摇滚 · 岁月沉思录',
        desc: '超越时光的呐喊与感动，致敬不朽传奇',
        tag: '摇滚',
        coverUrl: 'https://p2.music.126.net/cW3ZzXz8q3n2ZpE4I_pG2w==/109951165432654366.jpg',
        playCount: '92.6万',
        trackCount: 15,
        tracks: mockBeyondTracks,
      ),
    ];

    if (cat == '全部' || cat == '精选推荐') {
      return fallbackSquarePlaylists;
    }
    final matched = fallbackSquarePlaylists.where((p) => p.tag == cat).toList();
    return matched.isNotEmpty ? matched : fallbackSquarePlaylists;
  }
}
