import 'dart:convert';
import 'dart:math';
import '../audio/track_model.dart';
import '../audio/equalizer_manager.dart';

/// 可同步的歌曲元数据简要快照
class SyncTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final int durationMs;
  final String source;
  final String? audioUrl;
  final String? localPath;

  const SyncTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.durationMs,
    required this.source,
    this.audioUrl,
    this.localPath,
  });

  factory SyncTrack.fromTrack(Track track) {
    return SyncTrack(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      coverUrl: track.coverUrl,
      durationMs: track.duration.inMilliseconds,
      source: track.source,
      audioUrl: track.audioUrl,
      localPath: track.localPath,
    );
  }

  Track toTrack({bool isFavorite = false}) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      coverUrl: coverUrl,
      duration: Duration(milliseconds: durationMs),
      source: source,
      audioUrl: audioUrl,
      localPath: localPath,
      isFavorite: isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'coverUrl': coverUrl,
        'durationMs': durationMs,
        'source': source,
        'audioUrl': audioUrl,
        'localPath': localPath,
      };

  factory SyncTrack.fromJson(Map<String, dynamic> json) => SyncTrack(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '未知曲目',
        artist: json['artist'] as String? ?? '未知歌手',
        album: json['album'] as String? ?? '未知专辑',
        coverUrl: json['coverUrl'] as String? ?? '',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        source: json['source'] as String? ?? 'local',
        audioUrl: json['audioUrl'] as String?,
        localPath: json['localPath'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncTrack &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          artist == other.artist;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ artist.hashCode;
}

/// 收藏项（带更新时间戳与墓碑标记，支持精确的 Last-Write-Wins 冲突裁决）
class SyncFavoriteItem {
  final SyncTrack track;
  final DateTime updatedAt;
  final bool isRemoved;

  const SyncFavoriteItem({
    required this.track,
    required this.updatedAt,
    this.isRemoved = false,
  });

  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
        'isRemoved': isRemoved,
      };

  factory SyncFavoriteItem.fromJson(Map<String, dynamic> json) =>
      SyncFavoriteItem(
        track: SyncTrack.fromJson(json['track'] as Map<String, dynamic>),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isRemoved: json['isRemoved'] as bool? ?? false,
      );
}

/// 自建歌单数据快照
class SyncPlaylist {
  final String id;
  final String name;
  final String description;
  final String coverUrl;
  final List<SyncTrack> songs;
  final DateTime updatedAt;
  final bool isDeleted;

  const SyncPlaylist({
    required this.id,
    required this.name,
    this.description = '',
    this.coverUrl = '',
    this.songs = const [],
    required this.updatedAt,
    this.isDeleted = false,
  });

  SyncPlaylist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    List<SyncTrack>? songs,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return SyncPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      songs: songs ?? this.songs,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'coverUrl': coverUrl,
        'songs': songs.map((s) => s.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
      };

  factory SyncPlaylist.fromJson(Map<String, dynamic> json) => SyncPlaylist(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '新建歌单',
        description: json['description'] as String? ?? '',
        coverUrl: json['coverUrl'] as String? ?? '',
        songs: (json['songs'] as List<dynamic>?)
                ?.map((item) => SyncTrack.fromJson(item as Map<String, dynamic>))
                .toList() ??
            const [],
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isDeleted: json['isDeleted'] as bool? ?? false,
      );
}

/// 播放历史记录项
class SyncHistoryItem {
  final SyncTrack track;
  final DateTime playedAt;

  const SyncHistoryItem({
    required this.track,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'playedAt': playedAt.toIso8601String(),
      };

  factory SyncHistoryItem.fromJson(Map<String, dynamic> json) =>
      SyncHistoryItem(
        track: SyncTrack.fromJson(json['track'] as Map<String, dynamic>),
        playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// 10 频段 EQ 均衡器配置快照
class SyncEqualizerConfig {
  final bool isEnabled;
  final String presetName;
  final List<double> bandGains;
  final DateTime updatedAt;

  const SyncEqualizerConfig({
    required this.isEnabled,
    required this.presetName,
    required this.bandGains,
    required this.updatedAt,
  });

  /// 从现有的 EqualizerManager 转换为快照
  factory SyncEqualizerConfig.fromManager(
    EqualizerManager manager, {
    DateTime? timestamp,
  }) {
    return SyncEqualizerConfig(
      isEnabled: manager.isEnabled,
      presetName: manager.currentPreset.name,
      bandGains: List<double>.from(manager.bandGains),
      updatedAt: timestamp ?? DateTime.now(),
    );
  }

  /// 默认平直预设
  factory SyncEqualizerConfig.defaultFlat() {
    return SyncEqualizerConfig(
      isEnabled: true,
      presetName: 'flat',
      bandGains: List.filled(10, 0.0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'presetName': presetName,
        'bandGains': bandGains,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SyncEqualizerConfig.fromJson(Map<String, dynamic> json) =>
      SyncEqualizerConfig(
        isEnabled: json['isEnabled'] as bool? ?? true,
        presetName: json['presetName'] as String? ?? 'flat',
        bandGains: (json['bandGains'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            List.filled(10, 0.0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// 播放进度与播放器状态快照
class SyncPlaybackState {
  final String? currentTrackId;
  final int positionMs;
  final int durationMs;
  final String playbackMode;
  final double volume;
  final bool isPlaying;
  final DateTime updatedAt;

  const SyncPlaybackState({
    this.currentTrackId,
    required this.positionMs,
    required this.durationMs,
    required this.playbackMode,
    required this.volume,
    required this.isPlaying,
    required this.updatedAt,
  });

  factory SyncPlaybackState.initial() => SyncPlaybackState(
        currentTrackId: null,
        positionMs: 0,
        durationMs: 0,
        playbackMode: 'sequence',
        volume: 0.85,
        isPlaying: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'currentTrackId': currentTrackId,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'playbackMode': playbackMode,
        'volume': volume,
        'isPlaying': isPlaying,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SyncPlaybackState.fromJson(Map<String, dynamic> json) =>
      SyncPlaybackState(
        currentTrackId: json['currentTrackId'] as String?,
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        playbackMode: json['playbackMode'] as String? ?? 'sequence',
        volume: (json['volume'] as num?)?.toDouble() ?? 0.85,
        isPlaying: json['isPlaying'] as bool? ?? false,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Mellow Music 多端同步完整数据快照模型
class SyncSnapshot {
  final String version;
  final String deviceId;
  final String deviceName;
  final DateTime timestamp;
  final List<SyncFavoriteItem> favorites;
  final List<SyncPlaylist> playlists;
  final List<SyncHistoryItem> history;
  final SyncEqualizerConfig equalizer;
  final SyncPlaybackState playbackState;
  final Map<String, dynamic> extra;

  const SyncSnapshot({
    this.version = '1.0.0',
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
    this.favorites = const [],
    this.playlists = const [],
    this.history = const [],
    required this.equalizer,
    required this.playbackState,
    this.extra = const {},
  });

  SyncSnapshot copyWith({
    String? version,
    String? deviceId,
    String? deviceName,
    DateTime? timestamp,
    List<SyncFavoriteItem>? favorites,
    List<SyncPlaylist>? playlists,
    List<SyncHistoryItem>? history,
    SyncEqualizerConfig? equalizer,
    SyncPlaybackState? playbackState,
    Map<String, dynamic>? extra,
  }) {
    return SyncSnapshot(
      version: version ?? this.version,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      timestamp: timestamp ?? this.timestamp,
      favorites: favorites ?? this.favorites,
      playlists: playlists ?? this.playlists,
      history: history ?? this.history,
      equalizer: equalizer ?? this.equalizer,
      playbackState: playbackState ?? this.playbackState,
      extra: extra ?? this.extra,
    );
  }

  /// 序列化为 Map
  Map<String, dynamic> toJson() => {
        'version': version,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'timestamp': timestamp.toIso8601String(),
        'favorites': favorites.map((f) => f.toJson()).toList(),
        'playlists': playlists.map((p) => p.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'equalizer': equalizer.toJson(),
        'playbackState': playbackState.toJson(),
        'extra': extra,
      };

  /// 反序列化
  factory SyncSnapshot.fromJson(Map<String, dynamic> json) => SyncSnapshot(
        version: json['version'] as String? ?? '1.0.0',
        deviceId: json['deviceId'] as String? ?? 'unknown-device',
        deviceName: json['deviceName'] as String? ?? 'Mellow Client',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        favorites: (json['favorites'] as List<dynamic>?)
                ?.map((e) =>
                    SyncFavoriteItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        playlists: (json['playlists'] as List<dynamic>?)
                ?.map((e) => SyncPlaylist.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        history: (json['history'] as List<dynamic>?)
                ?.map((e) =>
                    SyncHistoryItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        equalizer: json['equalizer'] != null
            ? SyncEqualizerConfig.fromJson(
                json['equalizer'] as Map<String, dynamic>)
            : SyncEqualizerConfig.defaultFlat(),
        playbackState: json['playbackState'] != null
            ? SyncPlaybackState.fromJson(
                json['playbackState'] as Map<String, dynamic>)
            : SyncPlaybackState.initial(),
        extra: json['extra'] as Map<String, dynamic>? ?? const {},
      );

  String toRawJson() => jsonEncode(toJson());

  factory SyncSnapshot.fromRawJson(String str) =>
      SyncSnapshot.fromJson(jsonDecode(str) as Map<String, dynamic>);

  /// 兼容 SPEC 7.2 的 LX-Sync 报文结构导出
  Map<String, dynamic> toLxSyncPayload() {
    return {
      'action': 'sync_list',
      'version': version,
      'data': {
        'defaultList': history.map((h) => h.track.toJson()).toList(),
        'loveList': favorites
            .where((f) => !f.isRemoved)
            .map((f) => f.track.toJson())
            .toList(),
        'userList': playlists
            .where((p) => !p.isDeleted)
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'list': p.songs.map((s) => s.toJson()).toList(),
                })
            .toList(),
      },
    };
  }

  /// 从 LX-Sync 报文导入构建快照
  factory SyncSnapshot.fromLxSyncPayload(
    Map<String, dynamic> payload, {
    required String deviceId,
    required String deviceName,
  }) {
    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final now = DateTime.now();

    final loveListJson = (data['loveList'] as List<dynamic>?) ?? [];
    final favorites = loveListJson.map((item) {
      final track = SyncTrack.fromJson(item as Map<String, dynamic>);
      return SyncFavoriteItem(track: track, updatedAt: now);
    }).toList();

    final userListJson = (data['userList'] as List<dynamic>?) ?? [];
    final playlists = userListJson.map((pl) {
      final map = pl as Map<String, dynamic>;
      final songsList = (map['list'] as List<dynamic>?) ?? [];
      return SyncPlaylist(
        id: map['id'] as String? ?? 'lx-pl-${Random().nextInt(10000)}',
        name: map['name'] as String? ?? '导入歌单',
        songs: songsList
            .map((s) => SyncTrack.fromJson(s as Map<String, dynamic>))
            .toList(),
        updatedAt: now,
      );
    }).toList();

    final defaultListJson = (data['defaultList'] as List<dynamic>?) ?? [];
    final history = defaultListJson.map((item) {
      return SyncHistoryItem(
        track: SyncTrack.fromJson(item as Map<String, dynamic>),
        playedAt: now,
      );
    }).toList();

    return SyncSnapshot(
      version: payload['version'] as String? ?? '1.0.0',
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: now,
      favorites: favorites,
      playlists: playlists,
      history: history,
      equalizer: SyncEqualizerConfig.defaultFlat(),
      playbackState: SyncPlaybackState.initial(),
    );
  }

  /// 冲突解决算法 (Last-Write-Wins, LWW)
  ///
  /// 当两端数据快照产生冲突时，基于时间戳逐层进行最细粒度 LWW 合并：
  /// 1. 收藏列表：基于 track.id 匹配，时间戳较新者获胜；若一方为软删除 (isRemoved)，遵从最新时间决策。
  /// 2. 自建歌单：基于 playlist.id 匹配，时间戳较新者获胜；未产生冲突的歌单取并集保留。
  /// 3. 播放历史：合并并按 playedAt 时间戳降序排序，去除完全重复项，保留最新 300 条。
  /// 4. EQ 均衡器配置：比较 updatedAt，取更新者的配置。
  /// 5. 播放进度与状态：比较 updatedAt，取更新者的播放状态。
  SyncSnapshot merge(SyncSnapshot other) {
    // 1. 收藏列表细粒度 LWW 合并
    final Map<String, SyncFavoriteItem> favMap = {};
    for (final item in favorites) {
      favMap[item.track.id] = item;
    }
    for (final otherItem in other.favorites) {
      final existing = favMap[otherItem.track.id];
      if (existing == null) {
        favMap[otherItem.track.id] = otherItem;
      } else {
        // Last-Write-Wins：比对修改时间戳
        if (otherItem.updatedAt.isAfter(existing.updatedAt)) {
          favMap[otherItem.track.id] = otherItem;
        }
      }
    }
    final mergedFavorites = favMap.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // 2. 自建歌单细粒度 LWW 合并
    final Map<String, SyncPlaylist> playlistMap = {};
    for (final p in playlists) {
      playlistMap[p.id] = p;
    }
    for (final otherP in other.playlists) {
      final existing = playlistMap[otherP.id];
      if (existing == null) {
        playlistMap[otherP.id] = otherP;
      } else {
        // Last-Write-Wins
        if (otherP.updatedAt.isAfter(existing.updatedAt)) {
          playlistMap[otherP.id] = otherP;
        }
      }
    }
    final mergedPlaylists = playlistMap.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // 3. 播放历史合并 (按播放时间降序排重，保留前 300 条)
    final List<SyncHistoryItem> allHistory = [...history, ...other.history];
    // 去重：同一首歌在相同秒内播放视为重复
    final Map<String, SyncHistoryItem> historyMap = {};
    for (final h in allHistory) {
      final key = '${h.track.id}_${h.playedAt.millisecondsSinceEpoch ~/ 1000}';
      if (!historyMap.containsKey(key) ||
          h.playedAt.isAfter(historyMap[key]!.playedAt)) {
        historyMap[key] = h;
      }
    }
    final mergedHistory = historyMap.values.toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    final trimmedHistory = mergedHistory.take(300).toList();

    // 4. EQ 均衡器配置 LWW
    final mergedEq = other.equalizer.updatedAt.isAfter(equalizer.updatedAt)
        ? other.equalizer
        : equalizer;

    // 5. 播放进度与状态 LWW
    final mergedPlayback =
        other.playbackState.updatedAt.isAfter(playbackState.updatedAt)
            ? other.playbackState
            : playbackState;

    // 6. 快照元数据更新
    final latestTimestamp =
        other.timestamp.isAfter(timestamp) ? other.timestamp : timestamp;

    return SyncSnapshot(
      version: version,
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: latestTimestamp,
      favorites: mergedFavorites,
      playlists: mergedPlaylists,
      history: trimmedHistory,
      equalizer: mergedEq,
      playbackState: mergedPlayback,
      extra: {...extra, ...other.extra},
    );
  }
}
