import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sync/sync_data_model.dart';
import 'package:mellow_music/core/sync/webdav_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('A. 10 频段硬件均衡器 (EQ) 与声学引擎增强测试', () {
    test('EQ-1: 验证新增三大预设（纯享电音、现场摇滚、沉浸古典）各频段特征曲线', () {
      final eq = EqualizerManager.instance;

      // 1. 切换至纯享电音
      eq.applyPreset(EqualizerPreset.electronic);
      expect(eq.currentPreset, EqualizerPreset.electronic);
      // 检查低频重低音 (31Hz: +6.0dB) 与高频提升 (16kHz: +6.0dB)
      expect(eq.bandGains[0], 6.0);
      expect(eq.bandGains[1], 5.0);
      expect(eq.bandGains[9], 6.0);

      // 2. 切换至现场摇滚
      eq.applyPreset(EqualizerPreset.rock);
      expect(eq.currentPreset, EqualizerPreset.rock);
      // 现场感凸显中低频与泛音 (125Hz: +3.0dB, 4kHz: +4.0dB)
      expect(eq.bandGains[2], 3.0);
      expect(eq.bandGains[7], 4.0);

      // 3. 切换至沉浸古典
      eq.applyPreset(EqualizerPreset.classical);
      expect(eq.currentPreset, EqualizerPreset.classical);
      // 声场大动态 (31Hz: +3.0dB, 16kHz: +4.0dB)
      expect(eq.bandGains[0], 3.0);
      expect(eq.bandGains[9], 4.0);
    });

    test('EQ-2: 频段增益微调自动转为 Custom 预设并自动持久化', () async {
      final eq = EqualizerManager.instance;
      eq.applyPreset(EqualizerPreset.flat);

      // 调节第 4 频段 (250Hz) 为 +3.5 dB
      eq.setBandGain(3, 3.5);

      expect(eq.currentPreset, EqualizerPreset.custom);
      expect(eq.bandGains[3], 3.5);

      // 检查底层 StorageService 是否已完成持久化
      final storage = StorageService.instance;
      expect(storage.getEqualizerPreset(), 'custom');
      final savedGains = storage.getEqualizerGains();
      expect(savedGains, isNotNull);
      expect(savedGains![3], 3.5);
    });

    test('EQ-3: 模拟冷启动状态恢复 (Cold Boot Restoration)', () {
      // 预先向存储写入 EQ 配置
      final storage = StorageService.instance;
      storage.saveEqualizerPreset('rock');
      storage.saveEqualizerEnabled(true);
      final customGains = [2.0, 3.0, 4.0, 1.0, 0.0, 0.0, 1.0, 2.0, 3.0, 4.0];
      storage.saveEqualizerGains(customGains);

      // 实例化一个新的 EqualizerManager
      final restoredEq = EqualizerManager();
      expect(restoredEq.currentPreset, EqualizerPreset.rock);
      expect(restoredEq.isEnabled, isTrue);
      expect(restoredEq.bandGains, customGains);
    });
  });

  group('B. 多端同步中心 (Sync Center) 真实快照采集与应用测试', () {
    test('SYNC-1: 从运行态一键导出 SyncSnapshot 全量数据快照', () {
      final player = AudioPlayerService();
      final eq = EqualizerManager.instance;

      // 模拟添加独有红心歌曲
      final testTrack = const Track(
        id: 'unique-sync-test-song',
        title: '独有同步测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        coverUrl: '',
        duration: Duration(minutes: 3),
      );
      player.toggleFavorite(testTrack.id, testTrack);

      // 调节 EQ 为纯享电音
      eq.applyPreset(EqualizerPreset.electronic);

      // 采集快照
      final snapshot = SyncSnapshot.createFromAppState(player: player, eqManager: eq);

      // 验证快照包含新增红心
      expect(snapshot.favorites.any((f) => f.track.id == 'unique-sync-test-song'), isTrue);
      expect(snapshot.equalizer.presetName, 'electronic');
      expect(snapshot.equalizer.bandGains[0], 6.0);
    });

    test('SYNC-2: 将外部 SyncSnapshot 应用恢复至运行态 (applyToAppState)', () async {
      final player = AudioPlayerService();
      final eq = EqualizerManager.instance;

      final now = DateTime.now();
      final importedTrack = SyncTrack(
        id: 'imported-cloud-song-1',
        title: '云端同步金曲',
        artist: '云端歌手',
        album: '云端特辑',
        coverUrl: 'https://example.com/cover.jpg',
        durationMs: 180000,
        source: 'kw',
      );

      final externalSnapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'cloud-server-node',
        deviceName: 'Nextcloud Cloud Backup',
        timestamp: now,
        favorites: [
          SyncFavoriteItem(track: importedTrack, updatedAt: now, isRemoved: false),
        ],
        playlists: [
          SyncPlaylist(
            id: 'cloud-playlist-101',
            name: '远端云盘收藏单',
            songs: [importedTrack],
            updatedAt: now,
            isDeleted: false,
          ),
        ],
        equalizer: SyncEqualizerConfig(
          isEnabled: true,
          presetName: 'classical',
          bandGains: [3.0, 2.5, 2.0, 1.0, -0.5, -0.5, 1.0, 2.5, 3.5, 4.0],
          updatedAt: now,
        ),
        playbackState: SyncPlaybackState.initial(),
      );

      // 还原至系统
      await SyncSnapshot.applyToAppState(externalSnapshot, player: player, eqManager: eq);

      // 验证 Player 内存与收藏状态已被唤醒更新
      expect(player.favoriteTracks.any((t) => t.id == 'imported-cloud-song-1'), isTrue);
      expect(player.importedPlaylists.any((p) => p.id == 'cloud-playlist-101'), isTrue);

      // 验证 EQ 设置已被正确恢复为古典预设
      expect(eq.currentPreset, EqualizerPreset.classical);
      expect(eq.bandGains[0], 3.0);
      expect(eq.bandGains[9], 4.0);
    });

    test('SYNC-3: LWW (Last-Write-Wins) 智能合并算法', () {
      final baseTime = DateTime(2026, 3, 1, 10, 0);
      final earlierTime = baseTime.subtract(const Duration(hours: 2));
      final laterTime = baseTime.add(const Duration(hours: 2));

      final trackA = SyncTrack(
        id: 'song-a',
        title: 'Song A',
        artist: 'Artist A',
        album: 'Album A',
        coverUrl: '',
        durationMs: 200000,
        source: 'kw',
      );
      final trackB = SyncTrack(
        id: 'song-b',
        title: 'Song B',
        artist: 'Artist B',
        album: 'Album B',
        coverUrl: '',
        durationMs: 220000,
        source: 'kw',
      );

      // 设备 A 本地快照：较晚更新了 song-a（取消收藏）
      final localSnapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'device-a',
        deviceName: 'PC A',
        timestamp: laterTime,
        favorites: [
          SyncFavoriteItem(track: trackA, updatedAt: laterTime, isRemoved: true),
        ],
        playlists: [],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      // 远端快照：较早的时间收藏了 song-a，并且拥有独有的 song-b
      final remoteSnapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'device-b',
        deviceName: 'Phone B',
        timestamp: earlierTime,
        favorites: [
          SyncFavoriteItem(track: trackA, updatedAt: earlierTime, isRemoved: false),
          SyncFavoriteItem(track: trackB, updatedAt: earlierTime, isRemoved: false),
        ],
        playlists: [],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      // 合并
      final merged = localSnapshot.merge(remoteSnapshot);

      // 验证 song-a 采用较新的 laterTime (isRemoved: true)
      final favA = merged.favorites.firstWhere((f) => f.track.id == 'song-a');
      expect(favA.isRemoved, isTrue);

      // 验证 song-b 被合并引入 (isRemoved: false)
      final favB = merged.favorites.firstWhere((f) => f.track.id == 'song-b');
      expect(favB.isRemoved, isFalse);
    });
  });

  group('C. WebDavSyncService 网络与协议层联调测试', () {
    test('WEBDAV-1: uploadSnapshot 遇到未建目录自动 MKCOL 并成功 PUT 上传', () async {
      final config = WebDavConfig(
        serverUrl: 'https://dav.example.com/dav',
        username: 'user_mellow',
        password: 'pwd_password',
        remoteDirectory: '/mellow_music_sync/',
      );

      final mockClient = MockClient((request) async {
        if (request.method == 'PROPFIND') {
          // 模拟目录不存在
          return http.Response('Not Found', 404);
        } else if (request.method == 'MKCOL') {
          // 模拟创建目录成功
          return http.Response('Created', 201);
        } else if (request.method == 'PUT') {
          // 验证带有 Basic Auth 请求头
          expect(request.headers['Authorization'], startsWith('Basic '));
          // 验证上传的正文是有效的 JSON 快照
          final decoded = jsonDecode(request.body) as Map<String, dynamic>;
          expect(decoded['version'], '1.0.0');
          return http.Response('Snapshot saved', 201);
        }
        return http.Response('Bad Request', 400);
      });

      final snapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'mock-device',
        deviceName: 'Mock Client',
        timestamp: DateTime.now(),
        favorites: [],
        playlists: [],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      final result = await WebDavSyncService.uploadSnapshotDirect(config, snapshot, client: mockClient);
      expect(result.isSuccess, isTrue);
    });

    test('WEBDAV-2: downloadSnapshot 成功拉取并解析云端数据快照', () async {
      final config = WebDavConfig(
        serverUrl: 'https://dav.example.com/dav',
        username: 'user_mellow',
        password: 'pwd_password',
        remoteDirectory: '/mellow_music_sync/',
      );

      final sampleSnapshotJson = jsonEncode({
        'version': '1.0.0',
        'deviceId': 'remote-cloud',
        'deviceName': 'Remote WebDAV NAS',
        'timestamp': DateTime.now().toIso8601String(),
        'favorites': [
          {
            'track': {
              'id': 'cloud-1',
              'title': '远端快照歌曲',
              'artist': 'Cloud Singer',
              'album': 'Cloud Album',
              'coverUrl': '',
              'durationMs': 210000,
              'source': 'kw',
            },
            'updatedAt': DateTime.now().toIso8601String(),
            'isRemoved': false,
          }
        ],
        'playlists': [],
        'history': [],
        'equalizer': {
          'isEnabled': true,
          'presetName': 'flat',
          'bandGains': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
          'updatedAt': DateTime.now().toIso8601String(),
        },
        'playbackState': {
          'currentTrackId': null,
          'positionMs': 0,
          'durationMs': 0,
          'playbackMode': 'sequence',
          'volume': 0.85,
          'isPlaying': false,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      });

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(sampleSnapshotJson, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final result = await WebDavSyncService.downloadSnapshotDirect(config, client: mockClient);
      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.favorites.length, 1);
      expect(result.data!.favorites.first.track.title, '远端快照歌曲');
    });
  });
}
