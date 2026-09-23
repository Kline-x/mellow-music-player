import '../audio/track_model.dart';

/// 音质档位枚举
enum AudioQuality {
  k128k('128k', '128K', '128K 标准音质', 128),
  k320k('320k', '320K', '320K 高品质', 320),
  flac('flac', 'FLAC', 'FLAC 无损音质', 960),
  flac24bit('flac24bit', 'Hi-Res', 'Hi-Res 24bit 母带', 1920);

  final String value;
  final String label;
  final String displayName;
  final int bitrate; // kbps

  const AudioQuality(this.value, this.label, this.displayName, this.bitrate);

  /// 降级链（按音质从高到低回退）
  List<AudioQuality> get fallbackChain {
    switch (this) {
      case AudioQuality.flac24bit:
        return [AudioQuality.flac, AudioQuality.k320k, AudioQuality.k128k];
      case AudioQuality.flac:
        return [AudioQuality.k320k, AudioQuality.k128k];
      case AudioQuality.k320k:
        return [AudioQuality.k128k];
      case AudioQuality.k128k:
        return [];
    }
  }

  /// 从字符串解析音质档位
  static AudioQuality fromString(String val) {
    final normalized = val.trim().toLowerCase();
    for (final q in AudioQuality.values) {
      if (q.value == normalized || q.label.toLowerCase() == normalized) {
        return q;
      }
    }
    if (normalized.contains('24bit') || normalized.contains('hires') || normalized.contains('hi-res')) {
      return AudioQuality.flac24bit;
    }
    if (normalized.contains('flac') || normalized.contains('lossless') || normalized.contains('ape')) {
      return AudioQuality.flac;
    }
    if (normalized.contains('320')) {
      return AudioQuality.k320k;
    }
    return AudioQuality.k128k;
  }

  /// 尝试安全解析
  static AudioQuality? tryParse(String? val) {
    if (val == null || val.isEmpty) return null;
    try {
      return fromString(val);
    } catch (_) {
      return null;
    }
  }
}

/// 六维主流音源标识常量
class LxPlatformId {
  static const String kw = 'kw'; // 酷我
  static const String kg = 'kg'; // 酷狗
  static const String tx = 'tx'; // QQ 音乐
  static const String wy = 'wy'; // 网易云音乐
  static const String mg = 'mg'; // 咪咕音乐
  static const String mellow = 'mellow'; // 润音官方预设源

  static const List<String> allPlatforms = [kw, kg, tx, wy, mg, mellow];

  /// 获取平台中文显示名
  static String getPlatformName(String id) {
    switch (id.toLowerCase()) {
      case kw:
        return '酷我音乐';
      case kg:
        return '酷狗音乐';
      case tx:
        return 'QQ音乐';
      case wy:
        return '网易云音乐';
      case mg:
        return '咪咕音乐';
      case mellow:
        return '润音官方源';
      default:
        return '第三方音源 ($id)';
    }
  }
}

/// 音源元数据模型
class LxSourceMetadata {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String? homepage;
  final List<AudioQuality> supportedQualities;
  final List<String> supportedActions; // search, musicUrl, lyric, pic, leaderboard, playlist
  final bool isEnabled;
  final bool isBuiltIn;
  final String? scriptContent;
  final String? subscribeUrl;
  final Map<String, String>? headers;

  const LxSourceMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    this.homepage,
    this.supportedQualities = const [
      AudioQuality.k128k,
      AudioQuality.k320k,
      AudioQuality.flac,
      AudioQuality.flac24bit,
    ],
    this.supportedActions = const [
      'search',
      'musicUrl',
      'lyric',
      'pic',
      'leaderboard',
      'playlist',
    ],
    this.isEnabled = true,
    this.isBuiltIn = false,
    this.scriptContent,
    this.subscribeUrl,
    this.headers,
  });

  /// 从 JS 注释头自动解析元数据 (如 @name, @description, @version, @author)
  factory LxSourceMetadata.fromScriptHeader(String script, {String? defaultId}) {
    String extract(String tag, String fallback) {
      final reg = RegExp(r'@' + tag + r'\s+([^\r\n]+)', caseSensitive: false);
      final m = reg.firstMatch(script);
      return m != null ? m.group(1)!.trim() : fallback;
    }

    final name = extract('name', '自定义第三方音源');
    final desc = extract('description', '第三方导入的音乐解析脚本');
    final ver = extract('version', '1.0.0');
    final author = extract('author', 'Community');
    final homepage = extract('homepage', '');
    final id = defaultId ?? extract('id', 'custom_${name.hashCode.abs().toRadixString(16)}');

    return LxSourceMetadata(
      id: id,
      name: name,
      description: desc,
      version: ver,
      author: author,
      homepage: homepage.isNotEmpty ? homepage : null,
      isBuiltIn: false,
      isEnabled: true,
      scriptContent: script,
    );
  }

  LxSourceMetadata copyWith({
    String? id,
    String? name,
    String? description,
    String? version,
    String? author,
    String? homepage,
    List<AudioQuality>? supportedQualities,
    List<String>? supportedActions,
    bool? isEnabled,
    bool? isBuiltIn,
    String? scriptContent,
    String? subscribeUrl,
    Map<String, String>? headers,
  }) {
    return LxSourceMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      homepage: homepage ?? this.homepage,
      supportedQualities: supportedQualities ?? this.supportedQualities,
      supportedActions: supportedActions ?? this.supportedActions,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      scriptContent: scriptContent ?? this.scriptContent,
      subscribeUrl: subscribeUrl ?? this.subscribeUrl,
      headers: headers ?? this.headers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'version': version,
      'author': author,
      'homepage': homepage,
      'supportedQualities': supportedQualities.map((q) => q.value).toList(),
      'supportedActions': supportedActions,
      'isEnabled': isEnabled,
      'isBuiltIn': isBuiltIn,
      'scriptContent': scriptContent,
      'subscribeUrl': subscribeUrl,
      'headers': headers,
    };
  }

  factory LxSourceMetadata.fromJson(Map<String, dynamic> json) {
    return LxSourceMetadata(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? '未命名音源',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'Unknown',
      homepage: json['homepage'] as String?,
      supportedQualities: (json['supportedQualities'] as List<dynamic>?)
              ?.map((e) => AudioQuality.fromString(e.toString()))
              .toList() ??
          AudioQuality.values,
      supportedActions: (json['supportedActions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['search', 'musicUrl', 'lyric', 'pic', 'leaderboard', 'playlist'],
      isEnabled: json['isEnabled'] as bool? ?? true,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      scriptContent: json['scriptContent'] as String?,
      subscribeUrl: json['subscribeUrl'] as String?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }
}

/// 歌曲检索与元数据模型
class LxSongInfo {
  final String id; // 全局复合 ID，如 "kw_1001" 或纯数字
  final String songMid; // 原始平台 ID
  final String title;
  final String artist;
  final String album;
  final String? albumId;
  final String source; // kw, kg, tx, wy, mg, mellow 等
  final Duration duration;
  final String? coverUrl;
  final List<AudioQuality> availableQualities;
  final Map<String, dynamic>? types;
  final Map<String, dynamic>? extra;

  const LxSongInfo({
    required this.id,
    required this.songMid,
    required this.title,
    required this.artist,
    required this.album,
    this.albumId,
    required this.source,
    required this.duration,
    this.coverUrl,
    this.availableQualities = const [
      AudioQuality.k128k,
      AudioQuality.k320k,
      AudioQuality.flac,
    ],
    this.types,
    this.extra,
  });

  /// 转换为现有播放底座的 Track 对象
  Track toTrack({String? audioUrl, List<LyricLine>? lyrics}) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      coverUrl: coverUrl ?? '',
      duration: duration,
      source: source,
      audioUrl: audioUrl,
      lyrics: lyrics ?? const [],
    );
  }

  /// 从 Track 模型转换
  static LxSongInfo fromTrack(Track track) {
    return LxSongInfo(
      id: track.id,
      songMid: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      source: track.source,
      duration: track.duration,
      coverUrl: track.coverUrl,
    );
  }

  LxSongInfo copyWith({
    String? id,
    String? songMid,
    String? title,
    String? artist,
    String? album,
    String? albumId,
    String? source,
    Duration? duration,
    String? coverUrl,
    List<AudioQuality>? availableQualities,
    Map<String, dynamic>? types,
    Map<String, dynamic>? extra,
  }) {
    return LxSongInfo(
      id: id ?? this.id,
      songMid: songMid ?? this.songMid,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      source: source ?? this.source,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      availableQualities: availableQualities ?? this.availableQualities,
      types: types ?? this.types,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'songMid': songMid,
      'title': title,
      'artist': artist,
      'album': album,
      'albumId': albumId,
      'source': source,
      'durationMs': duration.inMilliseconds,
      'coverUrl': coverUrl,
      'availableQualities': availableQualities.map((q) => q.value).toList(),
      'types': types,
      'extra': extra,
    };
  }

  factory LxSongInfo.fromJson(Map<String, dynamic> json) {
    return LxSongInfo(
      id: json['id'] as String? ?? json['songMid']?.toString() ?? '',
      songMid: json['songMid']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '未知歌曲',
      artist: json['artist'] as String? ?? '群星',
      album: json['album'] as String? ?? '单曲',
      albumId: json['albumId']?.toString(),
      source: json['source'] as String? ?? LxPlatformId.mellow,
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      coverUrl: json['coverUrl'] as String?,
      availableQualities: (json['availableQualities'] as List<dynamic>?)
              ?.map((e) => AudioQuality.fromString(e.toString()))
              .toList() ??
          [AudioQuality.k128k, AudioQuality.k320k, AudioQuality.flac],
      types: json['types'] as Map<String, dynamic>?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }
}

/// 搜索结果模型
class LxSearchResult {
  final String query;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;
  final List<LxSongInfo> list;
  final String source;

  const LxSearchResult({
    required this.query,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
    required this.list,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'page': page,
      'limit': limit,
      'total': total,
      'hasMore': hasMore,
      'list': list.map((s) => s.toJson()).toList(),
      'source': source,
    };
  }

  factory LxSearchResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'] as List<dynamic>? ?? [];
    return LxSearchResult(
      query: json['query'] as String? ?? '',
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      list: rawList.map((e) => LxSongInfo.fromJson(e as Map<String, dynamic>)).toList(),
      source: json['source'] as String? ?? LxPlatformId.mellow,
    );
  }
}

/// 榜单定义模型
class LxLeaderboard {
  final String id;
  final String name;
  final String source;
  final String? coverUrl;
  final String? description;
  final String? updateTime;
  final int total;

  const LxLeaderboard({
    required this.id,
    required this.name,
    required this.source,
    this.coverUrl,
    this.description,
    this.updateTime,
    this.total = 100,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source': source,
      'coverUrl': coverUrl,
      'description': description,
      'updateTime': updateTime,
      'total': total,
    };
  }

  factory LxLeaderboard.fromJson(Map<String, dynamic> json) {
    return LxLeaderboard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '排行榜',
      source: json['source'] as String? ?? LxPlatformId.mellow,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      updateTime: json['updateTime'] as String?,
      total: (json['total'] as num?)?.toInt() ?? 100,
    );
  }
}

/// 榜单详情 (附带曲目列表)
class LxLeaderboardDetail {
  final LxLeaderboard board;
  final List<LxSongInfo> songs;
  final int page;
  final int limit;

  const LxLeaderboardDetail({
    required this.board,
    required this.songs,
    this.page = 1,
    this.limit = 30,
  });
}

/// 歌单广场模型
class LxPlaylist {
  final String id;
  final String title;
  final String source;
  final String? coverUrl;
  final String? creator;
  final int? playCount;
  final String? description;
  final List<String> tags;

  const LxPlaylist({
    required this.id,
    required this.title,
    required this.source,
    this.coverUrl,
    this.creator,
    this.playCount,
    this.description,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'coverUrl': coverUrl,
      'creator': creator,
      'playCount': playCount,
      'description': description,
      'tags': tags,
    };
  }

  factory LxPlaylist.fromJson(Map<String, dynamic> json) {
    return LxPlaylist(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '精选歌单',
      source: json['source'] as String? ?? LxPlatformId.mellow,
      coverUrl: json['coverUrl'] as String?,
      creator: json['creator'] as String?,
      playCount: (json['playCount'] as num?)?.toInt(),
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

/// 歌单详情模型
class LxPlaylistDetail {
  final LxPlaylist playlist;
  final List<LxSongInfo> songs;

  const LxPlaylistDetail({
    required this.playlist,
    required this.songs,
  });
}

/// 歌词解析结果
class LxLyricResult {
  final String songId;
  final String lyric; // 标准 LRC 歌词
  final String? tlyric; // 翻译歌词
  final String? rlyric; // 罗马音
  final String? lxlyric; // 逐字高精歌词

  const LxLyricResult({
    required this.songId,
    required this.lyric,
    this.tlyric,
    this.rlyric,
    this.lxlyric,
  });

  /// 解析为 LyricLine 列表
  List<LyricLine> toLyricLines() {
    final lines = <LyricLine>[];
    final rawLines = lyric.split('\n');

    // 如果有翻译歌词，建立时间戳匹配表
    final transMap = <int, String>{};
    if (tlyric != null && tlyric!.isNotEmpty) {
      for (final tLine in tlyric!.split('\n')) {
        final parsed = LyricLine.parse(tLine);
        if (parsed != null) {
          transMap[parsed.time.inMilliseconds ~/ 100] = parsed.text;
        }
      }
    }

    for (final raw in rawLines) {
      final parsed = LyricLine.parse(raw);
      if (parsed != null) {
        final key = parsed.time.inMilliseconds ~/ 100;
        final trans = transMap[key];
        lines.add(LyricLine(
          time: parsed.time,
          text: parsed.text,
          translation: trans,
        ));
      }
    }
    return lines;
  }
}

/// URL 解析换源与降级结果
class LxUrlResolveResult {
  final String url;
  final AudioQuality quality; // 实际获得的音质
  final AudioQuality requestedQuality; // 用户请求的音质
  final String source; // 实际命中的音源
  final String requestedSource; // 初始请求的音源
  final int bitrate; // 比特率 (kbps)
  final bool isQualityFallback; // 是否发生了音质降级
  final bool isSourceFallback; // 是否发生了音源降级
  final List<String> fallbackChain; // 降级路径追踪
  final Map<String, String>? headers; // 播放请求头

  const LxUrlResolveResult({
    required this.url,
    required this.quality,
    required this.requestedQuality,
    required this.source,
    required this.requestedSource,
    required this.bitrate,
    this.isQualityFallback = false,
    this.isSourceFallback = false,
    this.fallbackChain = const [],
    this.headers,
  });

  @override
  String toString() {
    return 'LxUrlResolveResult(url: $url, quality: ${quality.value}, source: $source, '
        'qualityFallback: $isQualityFallback, sourceFallback: $isSourceFallback, chain: $fallbackChain)';
  }
}

/// 错误类型枚举
enum LxSourceErrorType {
  notFound,
  unsupportedQuality,
  networkTimeout,
  networkError,
  scriptError,
  sourceDisabled,
  rateLimited,
  unknown,
}

/// 音源沙箱异常
class LxSourceException implements Exception {
  final String message;
  final LxSourceErrorType type;
  final String? sourceId;
  final Object? originalException;

  const LxSourceException(
    this.message, {
    this.type = LxSourceErrorType.unknown,
    this.sourceId,
    this.originalException,
  });

  @override
  String toString() => 'LxSourceException[$type] (Source: $sourceId): $message';
}
