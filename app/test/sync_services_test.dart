import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mellow_music/core/sync/sync_data_model.dart';
import 'package:mellow_music/core/sync/webdav_sync_service.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';

void main() {
  group('1. 数据快照模型与序列化 (SyncSnapshot Serialization)', () {
    test('Track 与 SyncTrack 互转无损性测试', () {
      final originTrack = mockPresetTracks.first;
      final syncTrack = SyncTrack.fromTrack(originTrack);

      expect(syncTrack.id, originTrack.id);
      expect(syncTrack.title, originTrack.title);
      expect(syncTrack.artist, originTrack.artist);
      expect(syncTrack.durationMs, originTrack.duration.inMilliseconds);

      final restored = syncTrack.toTrack(isFavorite: true);
      expect(restored.id, originTrack.id);
      expect(restored.isFavorite, isTrue);
      expect(restored.duration, originTrack.duration);
    });

    test('SyncSnapshot 全量 JSON 序列化与反序列化测试', () {
      final now = DateTime.now();
      final track1 = SyncTrack(
        id: 'track-test-1',
        title: '测试曲目 1',
        artist: '测试歌手',
        album: '测试专辑',
        coverUrl: 'https://example.com/cover1.jpg',
        durationMs: 240000,
        source: 'kw',
      );

      final snapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'device-client-a',
        deviceName: 'Mellow Windows Client',
        timestamp: now,
        favorites: [
          SyncFavoriteItem(
            track: track1,
            updatedAt: now.subtract(const Duration(minutes: 10)),
            isRemoved: false,
          ),
        ],
        playlists: [
          SyncPlaylist(
            id: 'pl-1',
            name: '我的自建民谣歌单',
            description: '安静的吉他与清唱',
            coverUrl: 'https://example.com/pl.jpg',
            songs: [track1],
            updatedAt: now,
            isDeleted: false,
          ),
        ],
        history: [
          SyncHistoryItem(track: track1, playedAt: now),
        ],
        equalizer: SyncEqualizerConfig(
          isEnabled: true,
          presetName: 'bassBoost',
          bandGains: [6.0, 4.0, 2.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.0, 4.0],
          updatedAt: now,
        ),
        playbackState: SyncPlaybackState(
          currentTrackId: 'track-test-1',
          positionMs: 45000,
          durationMs: 240000,
          playbackMode: 'singleLoop',
          volume: 0.9,
          isPlaying: true,
          updatedAt: now,
        ),
        extra: {'customSettingKey': 'customValue'},
      );

      final jsonStr = snapshot.toRawJson();
      final decoded = SyncSnapshot.fromRawJson(jsonStr);

      expect(decoded.version, '1.0.0');
      expect(decoded.deviceId, 'device-client-a');
      expect(decoded.deviceName, 'Mellow Windows Client');
      expect(decoded.favorites.length, 1);
      expect(decoded.favorites.first.track.title, '测试曲目 1');
      expect(decoded.playlists.length, 1);
      expect(decoded.playlists.first.name, '我的自建民谣歌单');
      expect(decoded.history.length, 1);
      expect(decoded.equalizer.presetName, 'bassBoost');
      expect(decoded.equalizer.bandGains[0], 6.0);
      expect(decoded.playbackState.currentTrackId, 'track-test-1');
      expect(decoded.playbackState.playbackMode, 'singleLoop');
      expect(decoded.extra['customSettingKey'], 'customValue');
    });

    test('SPEC 7.2 LX-Sync 报文格式双向互转兼容性测试', () {
      final now = DateTime.now();
      final track = SyncTrack(
        id: 'kw_12345',
        title: '晴天',
        artist: '周杰伦',
        album: '叶惠美',
        coverUrl: 'https://cover.url',
        durationMs: 269000,
        source: 'kw',
      );

      final snapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'desktop-pc',
        deviceName: 'PC',
        timestamp: now,
        favorites: [SyncFavoriteItem(track: track, updatedAt: now)],
        playlists: [
          SyncPlaylist(
            id: 'user-list-1',
            name: '周杰伦精选',
            songs: [track],
            updatedAt: now,
          ),
        ],
        history: [SyncHistoryItem(track: track, playedAt: now)],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      // 1. 导出为 LX-Sync 报文
      final lxPayload = snapshot.toLxSyncPayload();
      expect(lxPayload['action'], 'sync_list');
      expect(lxPayload['version'], '1.0.0');
      final data = lxPayload['data'] as Map<String, dynamic>;
      expect(data.containsKey('defaultList'), isTrue);
      expect(data.containsKey('loveList'), isTrue);
      expect(data.containsKey('userList'), isTrue);

      final loveList = data['loveList'] as List;
      expect(loveList.length, 1);
      expect(loveList[0]['title'], '晴天');

      // 2. 从 LX-Sync 报文导入并重构快照
      final importedSnapshot = SyncSnapshot.fromLxSyncPayload(
        lxPayload,
        deviceId: 'imported-client',
        deviceName: 'LX-Phone',
      );

      expect(importedSnapshot.deviceId, 'imported-client');
      expect(importedSnapshot.favorites.length, 1);
      expect(importedSnapshot.favorites.first.track.id, 'kw_12345');
      expect(importedSnapshot.playlists.length, 1);
      expect(importedSnapshot.playlists.first.name, '周杰伦精选');
    });
  });

  group('2. 冲突解决算法 (Last-Write-Wins, LWW)', () {
    final t0 = DateTime(2026, 9, 20, 10, 0, 0);
    final t1 = DateTime(2026, 9, 20, 11, 0, 0);
    final t2 = DateTime(2026, 9, 20, 12, 0, 0);

    final trackA = const SyncTrack(
      id: 'song-a',
      title: 'Song A',
      artist: 'Artist A',
      album: 'Album A',
      coverUrl: '',
      durationMs: 180000,
      source: 'local',
    );
    final trackB = const SyncTrack(
      id: 'song-b',
      title: 'Song B',
      artist: 'Artist B',
      album: 'Album B',
      coverUrl: '',
      durationMs: 200000,
      source: 'local',
    );

    test('收藏列表 LWW：最新操作获胜 (软删除与新增冲突合并)', () {
      // 客户端 1：在 t0 收藏了 song-a，在 t1 收藏了 song-b
      final client1 = SyncSnapshot(
        deviceId: 'client-1',
        deviceName: 'Client 1',
        timestamp: t1,
        favorites: [
          SyncFavoriteItem(track: trackA, updatedAt: t0, isRemoved: false),
          SyncFavoriteItem(track: trackB, updatedAt: t1, isRemoved: false),
        ],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      // 客户端 2：在 t2 (最新) 取消收藏了 song-a (isRemoved = true)
      final client2 = SyncSnapshot(
        deviceId: 'client-2',
        deviceName: 'Client 2',
        timestamp: t2,
        favorites: [
          SyncFavoriteItem(track: trackA, updatedAt: t2, isRemoved: true),
        ],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      final merged = client1.merge(client2);

      expect(merged.favorites.length, 2);
      final favA = merged.favorites.firstWhere((f) => f.track.id == 'song-a');
      final favB = merged.favorites.firstWhere((f) => f.track.id == 'song-b');

      // song-a 在 t2 被取消收藏，t2 > t0，所以 isRemoved 应当为 true
      expect(favA.isRemoved, isTrue);
      expect(favA.updatedAt, t2);

      // song-b 仅 client1 拥有，应保留
      expect(favB.isRemoved, isFalse);
    });

    test('自建歌单 LWW：同名 ID 歌单按最新 updatedAt 合并，不同歌单取并集', () {
      final plAlphaV1 = SyncPlaylist(
        id: 'pl-1',
        name: '民谣合辑 (旧版)',
        songs: [trackA],
        updatedAt: t0,
      );
      final plAlphaV2 = SyncPlaylist(
        id: 'pl-1',
        name: '民谣合辑 (新版加歌)',
        songs: [trackA, trackB],
        updatedAt: t2,
      );
      final plBeta = SyncPlaylist(
        id: 'pl-2',
        name: '摇滚时代',
        songs: [trackB],
        updatedAt: t1,
      );

      final snapshotA = SyncSnapshot(
        deviceId: 'A',
        deviceName: 'A',
        timestamp: t0,
        playlists: [plAlphaV1],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      final snapshotB = SyncSnapshot(
        deviceId: 'B',
        deviceName: 'B',
        timestamp: t2,
        playlists: [plAlphaV2, plBeta],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      final merged = snapshotA.merge(snapshotB);

      expect(merged.playlists.length, 2);
      final mergedPl1 = merged.playlists.firstWhere((p) => p.id == 'pl-1');
      expect(mergedPl1.name, '民谣合辑 (新版加歌)');
      expect(mergedPl1.songs.length, 2);

      final mergedPl2 = merged.playlists.firstWhere((p) => p.id == 'pl-2');
      expect(mergedPl2.name, '摇滚时代');
    });

    test('播放历史与 EQ 配置及播放状态 LWW 合并', () {
      final snapshotA = SyncSnapshot(
        deviceId: 'A',
        deviceName: 'A',
        timestamp: t1,
        history: [
          SyncHistoryItem(track: trackA, playedAt: t0),
        ],
        equalizer: SyncEqualizerConfig(
          isEnabled: true,
          presetName: 'clearVocal',
          bandGains: List.filled(10, 2.0),
          updatedAt: t0,
        ),
        playbackState: SyncPlaybackState(
          currentTrackId: 'song-a',
          positionMs: 15000,
          durationMs: 180000,
          playbackMode: 'sequence',
          volume: 0.8,
          isPlaying: false,
          updatedAt: t0,
        ),
      );

      final snapshotB = SyncSnapshot(
        deviceId: 'B',
        deviceName: 'B',
        timestamp: t2,
        history: [
          SyncHistoryItem(track: trackB, playedAt: t2),
        ],
        equalizer: SyncEqualizerConfig(
          isEnabled: true,
          presetName: 'spatial3d',
          bandGains: List.filled(10, 4.0),
          updatedAt: t2,
        ),
        playbackState: SyncPlaybackState(
          currentTrackId: 'song-b',
          positionMs: 65000,
          durationMs: 200000,
          playbackMode: 'shuffle',
          volume: 1.0,
          isPlaying: true,
          updatedAt: t2,
        ),
      );

      final merged = snapshotA.merge(snapshotB);

      // 历史合并为 2 项并按时间降序排
      expect(merged.history.length, 2);
      expect(merged.history.first.track.id, 'song-b');
      expect(merged.history.last.track.id, 'song-a');

      // EQ 取 t2 的 spatial3d
      expect(merged.equalizer.presetName, 'spatial3d');
      expect(merged.equalizer.bandGains[0], 4.0);

      // 播放状态取 t2 的 song-b / shuffle / 65000ms
      expect(merged.playbackState.currentTrackId, 'song-b');
      expect(merged.playbackState.positionMs, 65000);
      expect(merged.playbackState.playbackMode, 'shuffle');
      expect(merged.playbackState.isPlaying, isTrue);
    });
  });

  group('3. WebDAV 云端备份与还原状态机测试 (WebDavSyncService)', () {
    late WebDavConfig config;
    final testSnapshot = SyncSnapshot(
      deviceId: 'local-dev',
      deviceName: 'Local Client',
      timestamp: DateTime(2026, 9, 21, 10, 0, 0),
      equalizer: SyncEqualizerConfig.defaultFlat(),
      playbackState: SyncPlaybackState.initial(),
    );

    setUp(() {
      config = const WebDavConfig(
        serverUrl: 'https://dav.jianguoyun.com/dav/',
        username: 'user@example.com',
        password: 'app-password-secret',
        remoteDirectory: '/mellow_music/',
        backupFileName: 'snapshot.json',
      );
    });

    test('testConnection 认证与探活成功', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isTrue);
        if (request.method == 'PROPFIND' || request.method == 'HEAD') {
          return http.Response('', 207); // 207 Multi-Status
        }
        return http.Response('Not Found', 404);
      });

      final service = WebDavSyncService(config: config, client: mockClient);
      final isConnected = await service.testConnection();

      expect(isConnected, isTrue);
      expect(service.status, WebDavSyncStatus.idle);
      expect(service.errorMessage, isNull);
    });

    test('testConnection 账号密码错误 (401 Unauthorized)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final service = WebDavSyncService(config: config, client: mockClient);
      final isConnected = await service.testConnection();

      expect(isConnected, isFalse);
      expect(service.status, WebDavSyncStatus.failed);
      expect(service.errorMessage, contains('401'));
    });

    test('首次备份流程：云端不存在 (404) -> 自动创建目录并上传本地快照', () async {
      var mkcolCalled = false;
      var putCalled = false;
      String? uploadedBody;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          // 云端尚无快照
          return http.Response('File not found', 404);
        } else if (request.method == 'MKCOL') {
          mkcolCalled = true;
          return http.Response('Created', 201);
        } else if (request.method == 'PUT') {
          putCalled = true;
          uploadedBody = request.body;
          return http.Response('Created', 201);
        }
        return http.Response('', 200);
      });

      final service = WebDavSyncService(config: config, client: mockClient);
      final result = await service.sync(testSnapshot);

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('首次备份成功'));
      expect(mkcolCalled, isTrue);
      expect(putCalled, isTrue);
      expect(uploadedBody, isNotNull);

      final uploadedSnapshot = SyncSnapshot.fromRawJson(uploadedBody!);
      expect(uploadedSnapshot.deviceId, 'local-dev');
      expect(service.status, WebDavSyncStatus.success);
    });

    test('双向增量同步：拉取云端旧快照 -> 执行 LWW 合并 -> 回传更新云端', () async {
      final tRemote = DateTime(2026, 9, 21, 12, 0, 0);
      final remoteSnapshot = SyncSnapshot(
        deviceId: 'remote-phone',
        deviceName: 'Remote Phone',
        timestamp: tRemote,
        favorites: [
          SyncFavoriteItem(
            track: const SyncTrack(
              id: 'remote-song-1',
              title: '云端独有新歌',
              artist: '歌手',
              album: '专辑',
              coverUrl: '',
              durationMs: 120000,
              source: 'wy',
            ),
            updatedAt: tRemote,
          ),
        ],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      var putUploadCount = 0;
      SyncSnapshot? finalSavedOnServer;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(remoteSnapshot.toRawJson(), 200, headers: {
            'content-type': 'application/json; charset=utf-8',
          });
        } else if (request.method == 'MKCOL') {
          return http.Response('OK', 200);
        } else if (request.method == 'PUT') {
          putUploadCount++;
          finalSavedOnServer = SyncSnapshot.fromRawJson(request.body);
          return http.Response('OK', 204);
        }
        return http.Response('', 200);
      });

      final service = WebDavSyncService(config: config, client: mockClient);
      final syncResult = await service.sync(testSnapshot);

      expect(syncResult.isSuccess, isTrue);
      expect(putUploadCount, 1);
      expect(finalSavedOnServer, isNotNull);
      expect(finalSavedOnServer!.favorites.length, 1);
      expect(finalSavedOnServer!.favorites.first.track.title, '云端独有新歌');
      expect(service.lastSyncTime, isNotNull);
    });

    test('自动定时同步开关与触发机制测试', () async {
      var syncCount = 0;
      final mockClient = MockClient((request) async {
        return http.Response(testSnapshot.toRawJson(), 200);
      });

      final autoConfig = config.copyWith(
        isAutoSyncEnabled: true,
        autoSyncInterval: const Duration(milliseconds: 50),
      );

      final service = WebDavSyncService(config: autoConfig, client: mockClient);
      service.startAutoSync(
        localSnapshotProvider: () async => testSnapshot,
        onMerged: (merged) async {
          syncCount++;
        },
      );

      // 等待定时器执行至少两次
      await Future.delayed(const Duration(milliseconds: 160));
      service.stopAutoSync();
      final currentCount = syncCount;

      expect(currentCount, greaterThanOrEqualTo(2));

      // 验证停止后不再自增
      await Future.delayed(const Duration(milliseconds: 100));
      expect(syncCount, currentCount);

      service.dispose();
    });
  });

  group('4. 局域网直连同步 (LX-Sync / LAN P2P) 互传测试', () {
    test('LanPairingInfo 配对协议解析与格式化测试', () {
      const uriStr = 'lxsync://192.168.1.188:23332?key=AUTH_TEST_KEY&name=My-Mac';
      final info = LanPairingInfo.fromUri(uriStr);

      expect(info, isNotNull);
      expect(info!.ip, '192.168.1.188');
      expect(info.port, 23332);
      expect(info.authKey, 'AUTH_TEST_KEY');
      expect(info.deviceName, 'My-Mac');

      final generatedUri = info.toUri();
      expect(generatedUri, contains('lxsync://192.168.1.188:23332'));
      expect(generatedUri, contains('key=AUTH_TEST_KEY'));
    });

    test('局域网服务端挂载、/sync/hello 握手探针与配对鉴权全链路测试', () async {
      final server = LanSyncServer();
      // 使用 127.0.0.1 和系统分配可用端口 (port: 0)
      final port = await server.start(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        authKey: 'SECRET123',
        deviceName: 'TestHostPC',
        deviceId: 'host-pc-01',
      );

      expect(server.isRunning, isTrue);
      expect(port, greaterThan(0));

      final client = LanSyncClient();

      // 1. 测试 /sync/hello 握手探针
      final device = await client.pingDevice('127.0.0.1', port: port);
      expect(device, isNotNull);
      expect(device!.name, 'TestHostPC');
      expect(device.id, 'host-pc-01');
      expect(device.port, port);

      // 2. 测试配对鉴权：错误密钥失败
      final wrongPair = await client.pair('127.0.0.1', port: port, authKey: 'WRONG');
      expect(wrongPair, isFalse);

      // 3. 测试配对鉴权：正确密钥成功
      final successPair =
          await client.pair('127.0.0.1', port: port, authKey: 'SECRET123');
      expect(successPair, isTrue);

      await server.stop();
      client.dispose();
    });

    test('局域网数据投送 (Push) 与 LX-Sync 报文流转测试', () async {
      final server = LanSyncServer();
      final port = await server.start(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        authKey: 'MY_KEY',
        deviceName: 'TestServer',
      );

      final client = LanSyncClient();
      final receivedFuture = server.onSnapshotReceived.first;

      final testSnapshot = SyncSnapshot(
        deviceId: 'sender-mobile',
        deviceName: 'Mobile Phone',
        timestamp: DateTime.now(),
        favorites: [
          SyncFavoriteItem(
            track: const SyncTrack(
              id: 'song-pushed-1',
              title: '投送的歌曲',
              artist: '歌手',
              album: '专辑',
              coverUrl: '',
              durationMs: 180000,
              source: 'local',
            ),
            updatedAt: DateTime.now(),
          ),
        ],
        equalizer: SyncEqualizerConfig.defaultFlat(),
        playbackState: SyncPlaybackState.initial(),
      );

      // 1. 无授权 Key 或错误 Key 投送被拒绝
      final unauthPush = await client.pushSnapshot(
        '127.0.0.1',
        testSnapshot,
        port: port,
        authKey: 'BAD_KEY',
      );
      expect(unauthPush, isFalse);

      // 2. 正确 Key 投送成功，服务端接收到对应快照
      final authPush = await client.pushSnapshot(
        '127.0.0.1',
        testSnapshot,
        port: port,
        authKey: 'MY_KEY',
      );
      expect(authPush, isTrue);

      final received = await receivedFuture.timeout(const Duration(seconds: 3));
      expect(received.deviceId, 'sender-mobile');
      expect(received.favorites.length, 1);
      expect(received.favorites.first.track.title, '投送的歌曲');

      // 3. 投送 LX-Sync 原生报文结构
      final lxReceivedFuture = server.onSnapshotReceived.first;
      final lxPayload = {
        'action': 'sync_list',
        'version': '1.0.0',
        'data': {
          'defaultList': [],
          'loveList': [
            {
              'id': 'lx-song-99',
              'title': 'LX 互通歌曲',
              'artist': 'LX 艺人',
              'album': 'LX 专辑',
              'durationMs': 210000,
              'source': 'kw',
            }
          ],
          'userList': [],
        }
      };

      final lxPush = await client.pushLxSyncPayload(
        '127.0.0.1',
        lxPayload,
        port: port,
        authKey: 'MY_KEY',
      );
      expect(lxPush, isTrue);

      final receivedLx =
          await lxReceivedFuture.timeout(const Duration(seconds: 3));
      expect(receivedLx.favorites.first.track.title, 'LX 互通歌曲');

      await server.stop();
      client.dispose();
      server.dispose();
    });

    test('LanSyncService 门面生命周期与 URI 自动生成', () async {
      final facade = LanSyncService();
      final port = await facade.startServer(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        authKey: 'SYNC_KEY_999',
        deviceName: 'Desktop Studio',
      );

      expect(facade.isServerRunning, isTrue);
      expect(facade.serverPort, port);
      expect(facade.serverAuthKey, 'SYNC_KEY_999');

      final pairingUri = facade.generatePairingUri('192.168.31.200');
      expect(pairingUri, startsWith('lxsync://192.168.31.200:$port'));
      expect(pairingUri, contains('key=SYNC_KEY_999'));

      await facade.stopServer();
      expect(facade.isServerRunning, isFalse);

      facade.dispose();
    });
  });
}
