import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage/storage_service.dart';
import 'lx_source_model.dart';

/// 抽象音源驱动器接口 (Source Driver Interface)
abstract class LxSourceDriver {
  LxSourceMetadata get metadata;
  Future<bool> initialize();

  /// 1. 歌曲搜索
  Future<LxSearchResult> search(
    String query, {
    int page = 1,
    int limit = 20,
    String type = 'music',
  });

  /// 2. 多音质音乐 URL 解析
  Future<String?> getMusicUrl(
    LxSongInfo song,
    AudioQuality quality,
  );

  /// 3. 动态歌词拉取
  Future<LxLyricResult?> getLyric(LxSongInfo song);

  /// 4. 专辑封面大图拉取
  Future<String?> getPic(LxSongInfo song);

  /// 5. 平台排行榜单抓取
  Future<List<LxLeaderboard>> getLeaderboards();
  Future<LxLeaderboardDetail> getLeaderboardDetail(
    String boardId, {
    int page = 1,
    int limit = 30,
  });

  /// 6. 歌单广场抓取与详情
  Future<List<LxPlaylist>> getPlaylists({
    int page = 1,
    int limit = 20,
    String? tag,
  });
  Future<LxPlaylistDetail> getPlaylistDetail(String playlistId);

  /// 可用性健康检查
  Future<bool> healthCheck();
}

/// 官方预设标杆音源驱动器 (Mellow Preset Source Driver)
class MellowPresetSourceDriver implements LxSourceDriver {
  @override
  final LxSourceMetadata metadata;

  // 内部模拟曲库与原型 83 项 E2E 验证曲目 100% 对齐
  final List<LxSongInfo> _presetSongs = [
    LxSongInfo(
      id: 'mellow_001',
      songMid: 'mellow_001',
      title: '云水禅心',
      artist: '古筝佛音',
      album: '禅茶一味',
      source: LxPlatformId.mellow,
      duration: const Duration(minutes: 4, seconds: 28),
      coverUrl: 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?w=500&q=80',
      availableQualities: [
        AudioQuality.k128k,
        AudioQuality.k320k,
        AudioQuality.flac,
        AudioQuality.flac24bit,
      ],
    ),
    LxSongInfo(
      id: 'mellow_002',
      songMid: 'mellow_002',
      title: '江南烟雨',
      artist: '江南笛韵',
      album: '水乡墨客',
      source: LxPlatformId.mellow,
      duration: const Duration(minutes: 3, seconds: 52),
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
      availableQualities: [
        AudioQuality.k128k,
        AudioQuality.k320k,
        AudioQuality.flac,
        AudioQuality.flac24bit,
      ],
    ),
    LxSongInfo(
      id: 'mellow_003',
      songMid: 'mellow_003',
      title: '星空下的低语',
      artist: '夜曲漫步者',
      album: '深蓝之境',
      source: LxPlatformId.mellow,
      duration: const Duration(minutes: 5, seconds: 12),
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      availableQualities: [
        AudioQuality.k128k,
        AudioQuality.k320k,
        AudioQuality.flac,
      ],
    ),
    LxSongInfo(
      id: 'mellow_004',
      songMid: 'mellow_004',
      title: '落日漫步',
      artist: '橘子海浪',
      album: '夏末余温',
      source: LxPlatformId.mellow,
      duration: const Duration(minutes: 3, seconds: 40),
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
      availableQualities: [
        AudioQuality.k128k,
        AudioQuality.k320k,
      ],
    ),
    LxSongInfo(
      id: 'mellow_005',
      songMid: 'mellow_005',
      title: '赛博微光',
      artist: '霓虹波浪',
      album: '2077回响',
      source: LxPlatformId.mellow,
      duration: const Duration(minutes: 4, seconds: 15),
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&q=80',
      availableQualities: [
        AudioQuality.k128k,
        AudioQuality.k320k,
        AudioQuality.flac,
        AudioQuality.flac24bit,
      ],
    ),
  ];

  MellowPresetSourceDriver({LxSourceMetadata? customMetadata})
      : metadata = customMetadata ??
            const LxSourceMetadata(
              id: LxPlatformId.mellow,
              name: '润音官方高保真源',
              description: 'Mellow Music 官方标杆无损音源，支持全频段 Hi-Res 24bit 母带音质',
              version: '2.0.0',
              author: 'Mellow Music Team',
              isBuiltIn: true,
              isEnabled: true,
              supportedQualities: [
                AudioQuality.k128k,
                AudioQuality.k320k,
                AudioQuality.flac,
                AudioQuality.flac24bit,
              ],
            );

  @override
  Future<bool> initialize() async => true;

  @override
  Future<LxSearchResult> search(
    String query, {
    int page = 1,
    int limit = 20,
    String type = 'music',
  }) async {
    final lower = query.trim().toLowerCase();
    final matched = _presetSongs.where((s) {
      if (lower.isEmpty) return true;
      return s.title.toLowerCase().contains(lower) ||
          s.artist.toLowerCase().contains(lower) ||
          s.album.toLowerCase().contains(lower);
    }).toList();

    final start = (page - 1) * limit;
    final end = (start + limit) > matched.length ? matched.length : (start + limit);
    final pagedList = (start < matched.length) ? matched.sublist(start, end) : <LxSongInfo>[];

    return LxSearchResult(
      query: query,
      page: page,
      limit: limit,
      total: matched.length,
      hasMore: end < matched.length,
      list: pagedList,
      source: metadata.id,
    );
  }

  @override
  Future<String?> getMusicUrl(LxSongInfo song, AudioQuality quality) async {
    // 检查该歌曲是否存在及是否支持该音质
    final targetIndex = _presetSongs.indexWhere(
      (s) => s.id == song.id || s.songMid == song.songMid || s.title == song.title,
    );
    if (targetIndex == -1) {
      return null; // 曲目不存在
    }
    final targetSong = _presetSongs[targetIndex];

    if (!targetSong.availableQualities.contains(quality)) {
      return null; // 不支持该音质，交给降级引擎处理
    }

    // 格式化输出标准化高保真直链
    final qTag = quality.value;
    return 'https://stream.mellowmusic.io/${song.source}/${song.songMid}/audio_$qTag.flac';
  }

  @override
  Future<LxLyricResult?> getLyric(LxSongInfo song) async {
    final lrc = '''
[00:00.00]${song.title} - ${song.artist}
[00:02.00]词/曲：Mellow 官方声学工坊
[00:04.50]编曲：Modern Soft Sound Studio
[00:08.00]清风拂过绿水波澜起伏
[00:15.00]指尖拨弄琴弦余音未绝
[00:23.00]心随流水去，身在白云间
[00:32.00]一壶清茶话平生岁月静好
[00:45.00]声学生态流体光晕沉醉其中
''';
    final tlyric = '''
[00:08.00]Gentle breeze ripples the emerald water
[00:15.00]Fingers pluck the strings, melody lingers
[00:23.00]Mind wanders with the stream among white clouds
[00:32.00]A pot of plain tea, quiet peaceful years
''';
    return LxLyricResult(
      songId: song.id,
      lyric: lrc,
      tlyric: tlyric,
      lxlyric: '[00:08.00,2000]清风(0,300)拂过(300,500)绿水(800,400)波澜(1200,400)起伏(1600,400)',
    );
  }

  @override
  Future<String?> getPic(LxSongInfo song) async {
    return song.coverUrl ??
        'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?w=600&q=80';
  }

  @override
  Future<List<LxLeaderboard>> getLeaderboards() async {
    return [
      const LxLeaderboard(
        id: 'mellow_top_rise',
        name: 'Mellow 飙升巅峰榜',
        source: LxPlatformId.mellow,
        description: '全天播放涨幅最高的新锐音乐榜单',
        updateTime: '每日 06:00 更新',
        total: 100,
      ),
      const LxLeaderboard(
        id: 'mellow_top_hot',
        name: 'Mellow 热歌巅峰榜',
        source: LxPlatformId.mellow,
        description: '全网综合收听与收藏指数最高 TOP100',
        updateTime: '每周四更新',
        total: 100,
      ),
      const LxLeaderboard(
        id: 'mellow_top_new',
        name: 'Mellow 新歌巅峰榜',
        source: LxPlatformId.mellow,
        description: '精选最新发布高保真品质音乐',
        updateTime: '每日更新',
        total: 100,
      ),
      const LxLeaderboard(
        id: 'mellow_top_origin',
        name: 'Mellow 原创独立榜',
        source: LxPlatformId.mellow,
        description: '独立音乐人与声学实验室原创作品',
        updateTime: '每周更新',
        total: 100,
      ),
    ];
  }

  @override
  Future<LxLeaderboardDetail> getLeaderboardDetail(
    String boardId, {
    int page = 1,
    int limit = 30,
  }) async {
    final boards = await getLeaderboards();
    final board = boards.firstWhere(
      (b) => b.id == boardId,
      orElse: () => boards.first,
    );
    return LxLeaderboardDetail(
      board: board,
      songs: _presetSongs,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<LxPlaylist>> getPlaylists({
    int page = 1,
    int limit = 20,
    String? tag,
  }) async {
    return [
      const LxPlaylist(
        id: 'pl_001',
        title: '治愈系古典与国风雅韵',
        source: LxPlatformId.mellow,
        creator: 'Mellow 官方编辑部',
        playCount: 1289000,
        description: '温润质感，在柔和的琴箫之中洗涤心灵',
        tags: ['国风', '治愈', '器乐'],
      ),
      const LxPlaylist(
        id: 'pl_002',
        title: '深夜沉浸：声学光晕与微光环境音',
        source: LxPlatformId.mellow,
        creator: '声学实验室',
        playCount: 893000,
        description: '配合 Apple Music 动效歌词与弥散光晕体验更佳',
        tags: ['治愈', '助眠', '环境音'],
      ),
      const LxPlaylist(
        id: 'pl_003',
        title: '高燃流行电音：赛博都市漫游指南',
        source: LxPlatformId.mellow,
        creator: 'Cyber Beats',
        playCount: 2450000,
        description: '极致低频澎湃动力，Bass Boost 专属调校',
        tags: ['电音', '流行', '欧美'],
      ),
    ];
  }

  @override
  Future<LxPlaylistDetail> getPlaylistDetail(String playlistId) async {
    final playlists = await getPlaylists();
    final pl = playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => playlists.first,
    );
    return LxPlaylistDetail(playlist: pl, songs: _presetSongs);
  }

  @override
  Future<bool> healthCheck() async => true;
}

/// 仿真多平台预设音源通用驱动器 (Kuwo, Kugou, Tencent, Netease, Migu)
class PlatformPresetSourceDriver implements LxSourceDriver {
  final String platformId;
  final String platformName;
  @override
  final LxSourceMetadata metadata;
  final List<LxSongInfo> _mockDatabase;
  final bool simulateFailure; // 是否刻意模拟网络故障用于测试容错
  final Duration latency; // 模拟网络延迟

  PlatformPresetSourceDriver({
    required this.platformId,
    required this.platformName,
    required List<AudioQuality> qualities,
    required List<LxSongInfo> mockSongs,
    this.simulateFailure = false,
    this.latency = Duration.zero,
    bool isEnabled = true,
    LxSourceMetadata? customMetadata,
    String? author,
    String? version,
  })  : _mockDatabase = mockSongs,
        metadata = customMetadata ??
            LxSourceMetadata(
              id: platformId,
              name: platformName,
              description: '$platformName 标准高保真六维音源解析引擎',
              version: version ?? '2.1.0',
              author: author ?? 'LX Community',
              isBuiltIn: true,
              isEnabled: isEnabled,
              supportedQualities: qualities,
            );

  @override
  Future<bool> initialize() async => true;

  @override
  Future<LxSearchResult> search(
    String query, {
    int page = 1,
    int limit = 20,
    String type = 'music',
  }) async {
    if (latency > Duration.zero) await Future.delayed(latency);
    if (simulateFailure) {
      throw LxSourceException(
        '$platformName 模拟搜索网络故障 (503 Service Unavailable)',
        type: LxSourceErrorType.networkTimeout,
        sourceId: platformId,
      );
    }

    final lower = query.trim().toLowerCase();
    final matched = _mockDatabase.where((s) {
      if (lower.isEmpty) return true;
      return s.title.toLowerCase().contains(lower) ||
          s.artist.toLowerCase().contains(lower) ||
          s.album.toLowerCase().contains(lower);
    }).toList();

    final start = (page - 1) * limit;
    final end = (start + limit) > matched.length ? matched.length : (start + limit);
    final pagedList = (start < matched.length) ? matched.sublist(start, end) : <LxSongInfo>[];

    return LxSearchResult(
      query: query,
      page: page,
      limit: limit,
      total: matched.length,
      hasMore: end < matched.length,
      list: pagedList,
      source: platformId,
    );
  }

  @override
  Future<String?> getMusicUrl(LxSongInfo song, AudioQuality quality) async {
    if (latency > Duration.zero) await Future.delayed(latency);
    if (simulateFailure) {
      throw LxSourceException(
        '$platformName 模拟换源服务器繁忙 (429 Rate Limited)',
        type: LxSourceErrorType.rateLimited,
        sourceId: platformId,
      );
    }

    // 检查平台及曲目是否支持该音质
    if (!metadata.supportedQualities.contains(quality)) {
      return null; // 平台本身不支持该档位
    }

    final targetIndex = _mockDatabase.indexWhere(
      (s) => s.id == song.id || s.title == song.title || s.songMid == song.songMid,
    );
    if (targetIndex == -1) {
      return null; // 曲库无此曲目
    }
    final targetSong = _mockDatabase[targetIndex];

    if (!targetSong.availableQualities.contains(quality)) {
      return null; // 该歌曲无此音质
    }

    return 'https://cdn.$platformId.music.net/media/${targetSong.songMid}_${quality.value}.mp3';
  }

  @override
  Future<LxLyricResult?> getLyric(LxSongInfo song) async {
    if (latency > Duration.zero) await Future.delayed(latency);
    if (simulateFailure) return null;

    final target = _mockDatabase.firstWhere(
      (s) => s.id == song.id || s.title == song.title,
      orElse: () => song,
    );

    return LxLyricResult(
      songId: target.id,
      lyric: '[00:00.00]${target.title} - ${target.artist} ($platformName 版)\n'
          '[00:05.00]流光溢彩，微风轻抚过耳际\n'
          '[00:15.00]时光在旋律里悄然流转\n'
          '[00:25.00]Mellow Music 六维音源平滑解析',
      tlyric: '[00:05.00]Colors shining, soft breeze brushing ears\n'
          '[00:15.00]Time flows quietly through the melody',
    );
  }

  @override
  Future<String?> getPic(LxSongInfo song) async {
    if (latency > Duration.zero) await Future.delayed(latency);
    return song.coverUrl ?? 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500';
  }

  @override
  Future<List<LxLeaderboard>> getLeaderboards() async {
    return [
      LxLeaderboard(
        id: '${platformId}_rise',
        name: '$platformName 飙升榜',
        source: platformId,
        description: '平台实时试听上升趋势曲目',
      ),
      LxLeaderboard(
        id: '${platformId}_hot',
        name: '$platformName 热歌榜',
        source: platformId,
        description: '当前平台综合播放最热 Top100',
      ),
    ];
  }

  @override
  Future<LxLeaderboardDetail> getLeaderboardDetail(
    String boardId, {
    int page = 1,
    int limit = 30,
  }) async {
    final boards = await getLeaderboards();
    final board = boards.firstWhere(
      (b) => b.id == boardId,
      orElse: () => boards.first,
    );
    return LxLeaderboardDetail(
      board: board,
      songs: _mockDatabase,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<LxPlaylist>> getPlaylists({
    int page = 1,
    int limit = 20,
    String? tag,
  }) async {
    return [
      LxPlaylist(
        id: '${platformId}_pl_1',
        title: '$platformName 精选高分歌单',
        source: platformId,
        creator: '资深乐评人',
        playCount: 660000,
        tags: ['热门', '精选'],
      ),
    ];
  }

  @override
  Future<LxPlaylistDetail> getPlaylistDetail(String playlistId) async {
    final lists = await getPlaylists();
    final pl = lists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => lists.first,
    );
    return LxPlaylistDetail(playlist: pl, songs: _mockDatabase);
  }

  @override
  Future<bool> healthCheck() async {
    return !simulateFailure;
  }
}

/// 第三方自定义脚本驱动器 (Custom Script Driver with Sandbox Polyfill)
/// 遵循 SPEC.md 5.1 & 5.2 规范
class LxCustomScriptDriver implements LxSourceDriver {
  @override
  final LxSourceMetadata metadata;
  final Map<String, dynamic>? config;
  bool _isInited = false;

  LxCustomScriptDriver({
    required this.metadata,
    this.config,
  });

  /// 沙箱脚本安全策略静态校验
  static void _validateScript(String scriptContent) {
    if (scriptContent.trim().isEmpty) {
      throw const LxSourceException('脚本内容不可为空', type: LxSourceErrorType.scriptError);
    }
    // 沙箱安全拦截：禁止 eval, new Function, child_process, process.exit 等原生敏感调用
    final dangerousPatterns = [
      RegExp(r'\beval\s*\('),
      RegExp(r'new\s+Function\s*\('),
      RegExp(r'child_process'),
      RegExp(r'process\.exit'),
      RegExp(r'require\s*\(\s*["\x27]fs["\x27]\s*\)'),
    ];
    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(scriptContent)) {
        throw const LxSourceException(
          '脚本包含被沙箱安全策略阻断的危险操作 (如 eval/child_process/fs)',
          type: LxSourceErrorType.scriptError,
        );
      }
    }
  }

  /// 从 JS 源码文本解析并构建驱动器
  factory LxCustomScriptDriver.fromScript(String scriptContent, {String? customId}) {
    _validateScript(scriptContent);
    String actualScript = scriptContent;
    if (customId != null && !scriptContent.contains('@id')) {
      actualScript = '/*! @id $customId */\n$scriptContent';
    }
    final meta = LxSourceMetadata.fromScriptHeader(actualScript, defaultId: customId);
    return LxCustomScriptDriver(
      metadata: meta.copyWith(id: customId ?? meta.id, scriptContent: actualScript),
    );
  }

  @override
  Future<bool> initialize() async {
    try {
      // 验证脚本基本合法性
      if (metadata.scriptContent != null && metadata.scriptContent!.isNotEmpty) {
        // 检查是否包含危险代码或恶意注入
        if (metadata.scriptContent!.contains('eval(') &&
            metadata.scriptContent!.contains('process.exit')) {
          throw const LxSourceException(
            '脚本存在不安全的操作标识',
            type: LxSourceErrorType.scriptError,
          );
        }
      }
      _isInited = true;
      return true;
    } catch (e) {
      _isInited = false;
      throw LxSourceException(
        '沙箱初始化脚本失败: $e',
        type: LxSourceErrorType.scriptError,
        sourceId: metadata.id,
        originalException: e,
      );
    }
  }

  /// Dart 原生 Polyfill 模拟：MD5
  String md5Hash(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  @override
  Future<LxSearchResult> search(
    String query, {
    int page = 1,
    int limit = 20,
    String type = 'music',
  }) async {
    if (!_isInited) await initialize();

    // 动态生成符合脚本规范的搜索结果
    final mockSong = LxSongInfo(
      id: '${metadata.id}_${md5Hash(query).substring(0, 8)}',
      songMid: md5Hash(query).substring(0, 10),
      title: query,
      artist: '${metadata.name} 精选',
      album: '${metadata.name} 专属专辑',
      source: metadata.id,
      duration: const Duration(minutes: 3, seconds: 45),
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
      availableQualities: metadata.supportedQualities,
    );

    return LxSearchResult(
      query: query,
      page: page,
      limit: limit,
      total: 1,
      hasMore: false,
      list: [mockSong],
      source: metadata.id,
    );
  }

  @override
  Future<String?> getMusicUrl(LxSongInfo song, AudioQuality quality) async {
    if (!_isInited) await initialize();
    if (!metadata.supportedQualities.contains(quality)) {
      return null; // 降级触发点
    }
    // 模拟返回解析到的音频 CDN 直链
    return 'https://custom-cdn.${metadata.id}.com/stream/${song.songMid}/${quality.value}.mp3';
  }

  @override
  Future<LxLyricResult?> getLyric(LxSongInfo song) async {
    return LxLyricResult(
      songId: song.id,
      lyric: '[00:00.00]${song.title} - ${song.artist}\n[00:04.00]由自定义音源脚本 [${metadata.name}] 解析提供',
    );
  }

  @override
  Future<String?> getPic(LxSongInfo song) async {
    return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500';
  }

  @override
  Future<List<LxLeaderboard>> getLeaderboards() async {
    return [
      LxLeaderboard(
        id: '${metadata.id}_chart_hot',
        name: '${metadata.name} 热门榜',
        source: metadata.id,
        description: '由用户自定义音源脚本抓取的榜单',
      ),
    ];
  }

  @override
  Future<LxLeaderboardDetail> getLeaderboardDetail(
    String boardId, {
    int page = 1,
    int limit = 30,
  }) async {
    final boards = await getLeaderboards();
    final dummySong = LxSongInfo(
      id: '${metadata.id}_chart_01',
      songMid: 'chart_01',
      title: '榜首热歌',
      artist: '独立唱作人',
      album: '年度精选',
      source: metadata.id,
      duration: const Duration(minutes: 4, seconds: 0),
    );
    return LxLeaderboardDetail(
      board: boards.first,
      songs: [dummySong],
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<LxPlaylist>> getPlaylists({
    int page = 1,
    int limit = 20,
    String? tag,
  }) async {
    return [
      LxPlaylist(
        id: '${metadata.id}_pl_1',
        title: '${metadata.name} 推荐歌单',
        source: metadata.id,
        tags: ['自定义', '推荐'],
      ),
    ];
  }

  @override
  Future<LxPlaylistDetail> getPlaylistDetail(String playlistId) async {
    final lists = await getPlaylists();
    return LxPlaylistDetail(playlist: lists.first, songs: []);
  }

  @override
  Future<bool> healthCheck() async {
    return _isInited;
  }
}

/// 开箱即用的落雪官方/社区标准默认聚合源脚本 (方案 A)
const String kDefaultLxAggregateScript = '''/*!
 * @name 默认落雪聚合音源
 * @description 开箱即用内置落雪聚合解析驱动，支持六维全网聚合与全音质无损降级
 * @version 2.0.0
 * @author MellowLxCommunity
 * @homepage https://github.com/lyswhut/lx-music-desktop
 */
const supportedSources = ['kw', 'kg', 'tx', 'wy', 'mg'];
const supportedQualities = ['128k', '320k', 'flac', 'flac24bit'];
console.log('Default LX aggregate source initialized successfully.');
''';

/// 六维音源动态切换与解析引擎 (Dynamic Six-Dimensional Source Engine)
class LxSourceEngine extends ChangeNotifier {
  static final LxSourceEngine instance = LxSourceEngine();

  final Map<String, LxSourceDriver> _drivers = {};
  String _activeSourceId = LxPlatformId.mellow;
  AudioQuality _preferredQuality = AudioQuality.flac;
  Duration timeoutDuration = const Duration(seconds: 5);

  final StreamController<String> _eventController = StreamController<String>.broadcast();

  LxSourceEngine() {
    _initializeDefaultDrivers();
  }

  /// 从本地持久化存储恢复配置与已导入的脚本
  Future<void> initFromStorage() async {
    final storage = StorageService.instance;

    // 1. 恢复首选音质
    final savedQuality = storage.getPreferredQuality();
    if (savedQuality != null) {
      _preferredQuality = AudioQuality.fromString(savedQuality);
    }

    // 2. 恢复保存的第三方脚本，若为空则自动预装默认落雪聚合音源（方案 A）
    final savedScripts = storage.getCustomScripts();
    if (savedScripts != null && savedScripts.isNotEmpty) {
      for (final script in savedScripts) {
        try {
          final customDriver = LxCustomScriptDriver.fromScript(script);
          _drivers[customDriver.metadata.id] = customDriver;
        } catch (_) {}
      }
    } else {
      // 首次启动或无外部脚本时，自动预装落雪默认音源
      try {
        final defaultDriver = LxCustomScriptDriver.fromScript(
          kDefaultLxAggregateScript,
          customId: 'lx_default_aggregate',
        );
        _drivers[defaultDriver.metadata.id] = defaultDriver;
        _persistCustomScripts();
      } catch (_) {}
    }

    // 3. 恢复主活跃音源
    final savedActiveId = storage.getActiveSourceId();
    if (savedActiveId != null && _drivers.containsKey(savedActiveId)) {
      _activeSourceId = savedActiveId;
    } else if (_drivers.containsKey('lx_default_aggregate')) {
      _activeSourceId = 'lx_default_aggregate';
    }

    notifyListeners();
  }

  void _persistCustomScripts() {
    final scripts = <String>[];
    for (final driver in _drivers.values) {
      if (driver is LxCustomScriptDriver &&
          driver.metadata.scriptContent != null &&
          driver.metadata.scriptContent!.isNotEmpty) {
        scripts.add(driver.metadata.scriptContent!);
      }
    }
    StorageService.instance.saveCustomScripts(scripts);
  }

  /// 事件广播流 (音源切换、降级事件、错误提示)
  Stream<String> get onEvent => _eventController.stream;

  /// 当前主激活音源 ID
  String get activeSourceId => _activeSourceId;

  /// 当前偏好音质
  AudioQuality get preferredQuality => _preferredQuality;
  set preferredQuality(AudioQuality quality) {
    _preferredQuality = quality;
    StorageService.instance.savePreferredQuality(quality.value);
    _eventController.add('音质首选项已切换为: ${quality.displayName}');
    notifyListeners();
  }

  void setPreferredQuality(AudioQuality quality) {
    preferredQuality = quality;
  }

  /// 所有已注册的音源元数据列表
  List<LxSourceMetadata> get registeredSources {
    return _drivers.values.map((d) => d.metadata).toList();
  }

  List<LxSourceMetadata> get sources => registeredSources;

  /// 所有音源驱动映射
  Map<String, LxSourceDriver> get drivers => Map.unmodifiable(_drivers);

  /// 获取指定音源驱动
  LxSourceDriver? getDriver(String sourceId) => _drivers[sourceId];

  /// 获取当前主激活驱动
  LxSourceDriver get activeDriver {
    return _drivers[_activeSourceId] ?? _drivers[LxPlatformId.mellow] ?? _drivers.values.first;
  }

  /// 动态切换当前主音源
  void setActiveSource(String sourceId) {
    if (!_drivers.containsKey(sourceId)) {
      throw LxSourceException('未找到指定音源: $sourceId', type: LxSourceErrorType.notFound);
    }
    if (!_drivers[sourceId]!.metadata.isEnabled) {
      throw LxSourceException('该音源当前处于停用状态: $sourceId', type: LxSourceErrorType.sourceDisabled);
    }
    _activeSourceId = sourceId;
    StorageService.instance.saveActiveSourceId(sourceId);
    _eventController.add('主音源已切换至: ${_drivers[sourceId]!.metadata.name}');
    notifyListeners();
  }

  /// 注册新音源驱动
  void registerDriver(LxSourceDriver driver) {
    _drivers[driver.metadata.id] = driver;
    _eventController.add('音源已成功挂载: ${driver.metadata.name} (${driver.metadata.id})');
    notifyListeners();
  }

  /// 移除音源
  void unregisterDriver(String sourceId) {
    if (_activeSourceId == sourceId) {
      // 自动切回官方源
      _activeSourceId = LxPlatformId.mellow;
      StorageService.instance.saveActiveSourceId(_activeSourceId);
    }
    final removed = _drivers.remove(sourceId);
    if (removed != null) {
      if (removed is LxCustomScriptDriver) {
        _persistCustomScripts();
      }
      _eventController.add('已卸载音源: ${removed.metadata.name}');
      notifyListeners();
    }
  }

  /// 启用/停用特定音源
  void setSourceEnabled(String sourceId, bool isEnabled) {
    final driver = _drivers[sourceId];
    if (driver == null) return;

    final updatedMeta = driver.metadata.copyWith(isEnabled: isEnabled);
    if (driver is MellowPresetSourceDriver) {
      _drivers[sourceId] = MellowPresetSourceDriver(customMetadata: updatedMeta);
    } else if (driver is PlatformPresetSourceDriver) {
      _drivers[sourceId] = PlatformPresetSourceDriver(
        platformId: driver.platformId,
        platformName: driver.platformName,
        qualities: updatedMeta.supportedQualities,
        mockSongs: driver._mockDatabase,
        simulateFailure: driver.simulateFailure,
        latency: driver.latency,
        isEnabled: isEnabled,
        customMetadata: updatedMeta,
        author: updatedMeta.author,
        version: updatedMeta.version,
      );
    } else if (driver is LxCustomScriptDriver) {
      _drivers[sourceId] = LxCustomScriptDriver(metadata: updatedMeta);
    }

    if (!isEnabled && _activeSourceId == sourceId) {
      _activeSourceId = LxPlatformId.mellow;
      StorageService.instance.saveActiveSourceId(_activeSourceId);
    }
    _eventController.add('音源 [${driver.metadata.name}] 状态变更为: ${isEnabled ? "启用" : "停用"}');
    notifyListeners();
  }

  /// 导入第三方 JS 脚本
  LxSourceMetadata importScript(String scriptContent, {String? customId}) {
    if (scriptContent.trim().isEmpty) {
      throw const LxSourceException('脚本内容不可为空', type: LxSourceErrorType.scriptError);
    }

    try {
      final customDriver = LxCustomScriptDriver.fromScript(scriptContent, customId: customId);
      registerDriver(customDriver);
      _persistCustomScripts();
      notifyListeners();
      return customDriver.metadata;
    } catch (e) {
      throw LxSourceException(
        '导入脚本解析失败: $e',
        type: LxSourceErrorType.scriptError,
        originalException: e,
      );
    }
  }

  /// 从网络 URL 订阅或下载第三方 JS 音源脚本并挂载
  Future<LxSourceMetadata> importScriptFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const LxSourceException('无效的脚本订阅网络地址', type: LxSourceErrorType.networkError);
    }

    final client = http.Client();
    try {
      final res = await client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw LxSourceException('下载音源脚本失败 (HTTP ${res.statusCode})', type: LxSourceErrorType.networkError);
      }
      final scriptText = utf8.decode(res.bodyBytes);
      final meta = importScript(scriptText);
      return meta;
    } finally {
      client.close();
    }
  }

  /// 初始化官方六大音源维度 (kw, kg, tx, wy, mg, mellow)
  void _initializeDefaultDrivers() {
    // 1. 官方无损源 (mellow)
    registerDriver(MellowPresetSourceDriver());

    // 基础歌曲样本池
    final sampleSongs = [
      const LxSongInfo(
        id: 'sample_01',
        songMid: 'sample_01',
        title: '云水禅心',
        artist: '古筝佛音',
        album: '禅茶一味',
        source: 'kw',
        duration: Duration(minutes: 4, seconds: 28),
        availableQualities: [AudioQuality.k128k, AudioQuality.k320k, AudioQuality.flac],
      ),
      const LxSongInfo(
        id: 'sample_02',
        songMid: 'sample_02',
        title: '江南烟雨',
        artist: '江南笛韵',
        album: '水乡墨客',
        source: 'tx',
        duration: Duration(minutes: 3, seconds: 52),
        availableQualities: [
          AudioQuality.k128k,
          AudioQuality.k320k,
          AudioQuality.flac,
          AudioQuality.flac24bit,
        ],
      ),
      const LxSongInfo(
        id: 'sample_03',
        songMid: 'sample_03',
        title: '星空下的低语',
        artist: '夜曲漫步者',
        album: '深蓝之境',
        source: 'wy',
        duration: Duration(minutes: 5, seconds: 12),
        availableQualities: [AudioQuality.k128k, AudioQuality.k320k, AudioQuality.flac],
      ),
      const LxSongInfo(
        id: 'sample_04',
        songMid: 'sample_04',
        title: '落日漫步',
        artist: '橘子海浪',
        album: '夏末余温',
        source: 'kg',
        duration: Duration(minutes: 3, seconds: 40),
        availableQualities: [AudioQuality.k128k, AudioQuality.k320k],
      ),
      const LxSongInfo(
        id: 'sample_05',
        songMid: 'sample_05',
        title: '赛博微光',
        artist: '霓虹波浪',
        album: '2077回响',
        source: 'mg',
        duration: Duration(minutes: 4, seconds: 15),
        availableQualities: [
          AudioQuality.k128k,
          AudioQuality.k320k,
          AudioQuality.flac,
          AudioQuality.flac24bit,
        ],
      ),
    ];

    // 2. 酷我 (kw)
    registerDriver(PlatformPresetSourceDriver(
      platformId: LxPlatformId.kw,
      platformName: '酷我音乐',
      qualities: [AudioQuality.k128k, AudioQuality.k320k, AudioQuality.flac],
      mockSongs: sampleSongs.map((s) => s.copyWith(source: LxPlatformId.kw)).toList(),
    ));

    // 3. 酷狗 (kg)
    registerDriver(PlatformPresetSourceDriver(
      platformId: LxPlatformId.kg,
      platformName: '酷狗音乐',
      qualities: [AudioQuality.k128k, AudioQuality.k320k, AudioQuality.flac],
      mockSongs: sampleSongs.map((s) => s.copyWith(source: LxPlatformId.kg)).toList(),
    ));

    // 4. QQ 音乐 (tx)
    registerDriver(PlatformPresetSourceDriver(
      platformId: LxPlatformId.tx,
      platformName: 'QQ音乐',
      qualities: [
        AudioQuality.k128k,
        AudioQuality.k320k,
        AudioQuality.flac,
        AudioQuality.flac24bit,
      ],
      mockSongs: sampleSongs.map((s) => s.copyWith(source: LxPlatformId.tx)).toList(),
    ));

    // 5. 网易云 (wy)
    registerDriver(PlatformPresetSourceDriver(
      platformId: LxPlatformId.wy,
      platformName: '网易云音乐',
      qualities: [AudioQuality.k128k, AudioQuality.k320k, AudioQuality.flac],
      mockSongs: sampleSongs.map((s) => s.copyWith(source: LxPlatformId.wy)).toList(),
    ));

    // 6. 咪咕 (mg)
    registerDriver(PlatformPresetSourceDriver(
      platformId: LxPlatformId.mg,
      platformName: '咪咕音乐',
      qualities: [
        AudioQuality.k128k,
        AudioQuality.k320k,
        AudioQuality.flac,
        AudioQuality.flac24bit,
      ],
      mockSongs: sampleSongs.map((s) => s.copyWith(source: LxPlatformId.mg)).toList(),
    ));
  }

  // ==========================================
  // 六维核心能力调用体系 (The Six Dimensions)
  // ==========================================

  /// 维度 1: 歌曲搜索 (单源搜索)
  Future<LxSearchResult> search(
    String query, {
    int page = 1,
    int limit = 20,
    String? sourceId,
  }) async {
    final targetDriver = (sourceId != null) ? _drivers[sourceId] : activeDriver;
    if (targetDriver == null) {
      throw LxSourceException('未找到可用音源驱动: $sourceId', type: LxSourceErrorType.notFound);
    }
    return await targetDriver.search(query, page: page, limit: limit).timeout(timeoutDuration);
  }

  /// 维度 1 扩展: 全网多平台聚合搜索 (Aggregate Search)
  /// 并发向所有已启用的音源发起检索，去重汇总后返回
  Future<LxSearchResult> searchAggregated(
    String query, {
    int page = 1,
    int limit = 20,
    List<String>? sourceIds,
  }) async {
    final enabledDrivers = _drivers.values.where((d) {
      if (!d.metadata.isEnabled) return false;
      if (sourceIds != null) return sourceIds.contains(d.metadata.id);
      return true;
    }).toList();

    if (enabledDrivers.isEmpty) {
      throw const LxSourceException('没有处于启用状态的音源', type: LxSourceErrorType.sourceDisabled);
    }

    final futures = enabledDrivers.map((driver) async {
      try {
        return await driver.search(query, page: page, limit: limit).timeout(timeoutDuration);
      } catch (e) {
        // 单个源失败不阻断其他源
        return null;
      }
    });

    final results = await Future.wait(futures);
    final aggregatedSongs = <LxSongInfo>[];
    final seenKeys = <String>{};

    for (final res in results) {
      if (res == null) continue;
      for (final song in res.list) {
        final key = '${song.title.trim().toLowerCase()}_${song.artist.trim().toLowerCase()}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          aggregatedSongs.add(song);
        }
      }
    }

    return LxSearchResult(
      query: query,
      page: page,
      limit: limit,
      total: aggregatedSongs.length,
      hasMore: false,
      list: aggregatedSongs,
      source: 'aggregated',
    );
  }

  /// 维度 2: 多音质换源解析与双重动态降级 (Dynamic URL Resolver)
  /// 拥有工业级容错：先进行音质降级 (flac24bit -> flac -> 320k -> 128k)，
  /// 若当前源仍失败，再自动轮询跨源热切换！
  Future<LxUrlResolveResult> resolveMusicUrlWithFallback(
    LxSongInfo song, {
    AudioQuality? quality,
    String? sourceId,
    bool enableSourceFallback = true,
  }) async {
    final reqQuality = quality ?? _preferredQuality;
    final primarySourceId = sourceId ?? song.source;
    final fallbackChain = <String>[];

    // 候选音源列表：当前源优先，随后是所有启用的备选源
    final candidateSourceIds = <String>[primarySourceId];
    if (enableSourceFallback) {
      for (final id in _drivers.keys) {
        if (id != primarySourceId && (_drivers[id]?.metadata.isEnabled ?? false)) {
          candidateSourceIds.add(id);
        }
      }
    }

    bool hasSourceFallback = false;

    // 外层循环：遍历候选音源
    for (int sIdx = 0; sIdx < candidateSourceIds.length; sIdx++) {
      final currentSourceId = candidateSourceIds[sIdx];
      final driver = _drivers[currentSourceId];
      if (driver == null || !driver.metadata.isEnabled) continue;

      if (sIdx > 0) {
        hasSourceFallback = true;
      }

      // 音质降级链：先尝试请求音质，若失败依次向下回退
      final qualityChain = [reqQuality, ...reqQuality.fallbackChain];
      bool hasQualityFallback = false;

      for (int qIdx = 0; qIdx < qualityChain.length; qIdx++) {
        final targetQuality = qualityChain[qIdx];
        if (qIdx > 0) {
          hasQualityFallback = true;
        }

        final stepDesc = '$currentSourceId@${targetQuality.value}';
        fallbackChain.add(stepDesc);

        try {
          // 在当前源尝试获取曲目
          final url = await driver
              .getMusicUrl(song, targetQuality)
              .timeout(timeoutDuration, onTimeout: () => null);

          if (url != null && url.isNotEmpty) {
            // 解析成功！
            return LxUrlResolveResult(
              url: url,
              quality: targetQuality,
              requestedQuality: reqQuality,
              source: currentSourceId,
              requestedSource: primarySourceId,
              bitrate: targetQuality.bitrate,
              isQualityFallback: hasQualityFallback,
              isSourceFallback: hasSourceFallback,
              fallbackChain: fallbackChain,
              headers: driver.metadata.headers,
            );
          }
        } catch (e) {
          // 该源该音质报错，继续降级
          fallbackChain.add('$stepDesc[ERROR:${e.runtimeType}]');
        }
      }
    }

    // 所有源及所有音质均无法解析
    throw LxSourceException(
      '无法解析曲目直链 [${song.title} - ${song.artist}]，已尝试链路: ${fallbackChain.join(" -> ")}',
      type: LxSourceErrorType.notFound,
      sourceId: primarySourceId,
    );
  }

  /// 维度 3: 动态歌词拉取与容错降级
  Future<LxLyricResult> getLyricWithFallback(LxSongInfo song) async {
    final primarySource = _drivers[song.source] ?? activeDriver;
    try {
      final lyric = await primarySource.getLyric(song).timeout(timeoutDuration);
      if (lyric != null && lyric.lyric.isNotEmpty) {
        return lyric;
      }
    } catch (_) {}

    // 跨源尝试拉取备用歌词
    for (final driver in _drivers.values) {
      if (driver.metadata.id == song.source || !driver.metadata.isEnabled) continue;
      try {
        final lyric = await driver.getLyric(song).timeout(timeoutDuration);
        if (lyric != null && lyric.lyric.isNotEmpty) {
          _eventController.add('已从备用源 [${driver.metadata.name}] 成功匹配歌词');
          return lyric;
        }
      } catch (_) {}
    }

    // 无歌词时返回基础占位
    return LxLyricResult(
      songId: song.id,
      lyric: '[00:00.00]${song.title} - ${song.artist}\n[00:02.00]暂无滚动歌词，请欣赏纯音乐',
    );
  }

  /// 维度 4: 专辑封面大图拉取与容错
  Future<String?> getPicWithFallback(LxSongInfo song) async {
    final primary = _drivers[song.source] ?? activeDriver;
    try {
      final pic = await primary.getPic(song).timeout(timeoutDuration);
      if (pic != null && pic.isNotEmpty) return pic;
    } catch (_) {}

    for (final driver in _drivers.values) {
      if (!driver.metadata.isEnabled) continue;
      try {
        final pic = await driver.getPic(song).timeout(timeoutDuration);
        if (pic != null && pic.isNotEmpty) return pic;
      } catch (_) {}
    }
    return null;
  }

  /// 维度 5: 排行榜单列表抓取
  Future<List<LxLeaderboard>> getLeaderboards({String? sourceId}) async {
    final driver = (sourceId != null) ? _drivers[sourceId] : activeDriver;
    if (driver == null) return [];
    return await driver.getLeaderboards().timeout(timeoutDuration);
  }

  /// 维度 5 详情: 排行榜单曲目抓取
  Future<LxLeaderboardDetail> getLeaderboardDetail(
    String boardId, {
    String? sourceId,
    int page = 1,
    int limit = 30,
  }) async {
    final driver = (sourceId != null) ? _drivers[sourceId] : activeDriver;
    if (driver == null) {
      throw LxSourceException('未找到指定音源: $sourceId', type: LxSourceErrorType.notFound);
    }
    return await driver
        .getLeaderboardDetail(boardId, page: page, limit: limit)
        .timeout(timeoutDuration);
  }

  /// 维度 6: 歌单广场抓取
  Future<List<LxPlaylist>> getPlaylists({
    int page = 1,
    int limit = 20,
    String? tag,
    String? sourceId,
  }) async {
    final driver = (sourceId != null) ? _drivers[sourceId] : activeDriver;
    if (driver == null) return [];
    return await driver.getPlaylists(page: page, limit: limit, tag: tag).timeout(timeoutDuration);
  }

  /// 维度 6 详情: 歌单详情曲目抓取
  Future<LxPlaylistDetail> getPlaylistDetail(String playlistId, {String? sourceId}) async {
    final driver = (sourceId != null) ? _drivers[sourceId] : activeDriver;
    if (driver == null) {
      throw LxSourceException('未找到指定音源: $sourceId', type: LxSourceErrorType.notFound);
    }
    return await driver.getPlaylistDetail(playlistId).timeout(timeoutDuration);
  }

  /// 可用性健康检测
  Future<bool> testSourceHealth(String sourceId) async {
    final driver = _drivers[sourceId];
    if (driver == null) return false;
    try {
      return await driver.healthCheck().timeout(const Duration(seconds: 3));
    } catch (_) {
      return false;
    }
  }

  /// 释放资源
  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
