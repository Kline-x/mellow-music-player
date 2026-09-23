import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';
import 'package:mellow_music/core/sync/sync_data_model.dart';

void main() {
  HttpOverrides.global = null;

  group('LanPairingInfo 协议转换测试', () {
    test('标准 lxsync:// 协议生成与反向解析', () {
      const info = LanPairingInfo(
        ip: '192.168.1.120',
        port: 23332,
        authKey: 'ABCD99',
        deviceName: 'MacBook Pro',
      );
      final uri = info.toUri();
      expect(uri, startsWith('lxsync://192.168.1.120:23332?'));
      expect(uri, contains('key=ABCD99'));

      final parsed = LanPairingInfo.fromUri(uri);
      expect(parsed, isNotNull);
      expect(parsed!.ip, '192.168.1.120');
      expect(parsed.port, 23332);
      expect(parsed.authKey, 'ABCD99');
      expect(parsed.deviceName, 'MacBook Pro');
    });

    test('解析非法 URI 时返回 null', () {
      expect(LanPairingInfo.fromUri('http://192.168.1.1'), isNull);
      expect(LanPairingInfo.fromUri('not-a-uri'), isNull);
    });
  });

  group('LanDevice 序列化与相等性测试', () {
    test('LanDevice toJson & fromJson', () {
      final now = DateTime.now();
      final dev = LanDevice(
        id: 'node-1',
        name: 'iPhone 15',
        ip: '192.168.1.55',
        port: 23332,
        version: '1.2.0',
        lastSeen: now,
      );

      final json = dev.toJson();
      final deserialized = LanDevice.fromJson(json);

      expect(deserialized.id, 'node-1');
      expect(deserialized.name, 'iPhone 15');
      expect(deserialized.ip, '192.168.1.55');
      expect(deserialized.port, 23332);
      expect(deserialized.version, '1.2.0');
    });
  });

  group('LanSyncServer 与 LanSyncClient 真实网络握手与投送测试', () {
    late LanSyncServer server;
    late LanSyncClient client;
    late int serverPort;
    const testAuthKey = 'TEST_KEY_123';

    setUp(() async {
      server = LanSyncServer();
      client = LanSyncClient();
      // 在本地 Loopback 启动服务端
      serverPort = await server.start(
        address: InternetAddress.loopbackIPv4,
        port: 0, // 系统分配端口
        authKey: testAuthKey,
        deviceName: 'Test Server',
        deviceId: 'server-01',
      );
    });

    tearDown(() async {
      server.dispose();
      client.dispose();
    });

    test('握手探针 /sync/hello 返回正确服务端设备信息', () async {
      final device = await client.pingDevice('127.0.0.1', port: serverPort);
      expect(device, isNotNull);
      expect(device!.name, 'Test Server');
      expect(device.id, 'server-01');
      expect(device.port, serverPort);
    });

    test('配对认证 /sync/pair 验证密钥', () async {
      final pass = await client.pair('127.0.0.1', port: serverPort, authKey: testAuthKey);
      expect(pass, isTrue);

      final fail = await client.pair('127.0.0.1', port: serverPort, authKey: 'WRONG_KEY');
      expect(fail, isFalse);
    });

    test('快照推送 /sync/push 传输并在服务端正确还原', () async {
      final now = DateTime.now();
      final track = SyncTrack(
        id: 'net_101',
        title: '局域网传输测试曲目',
        artist: '测试歌手',
        album: '测试专辑',
        coverUrl: '',
        durationMs: 240000,
        source: 'lx_netease',
      );

      final snapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'client-node',
        deviceName: 'Client Device',
        timestamp: now,
        favorites: [
          SyncFavoriteItem(track: track, updatedAt: now, isRemoved: false),
        ],
        playlists: [
          SyncPlaylist(
            id: 'pl_lan',
            name: 'P2P 局域网分享歌单',
            songs: [track],
            updatedAt: now,
            isDeleted: false,
          ),
        ],
        equalizer: SyncEqualizerConfig(
          isEnabled: true,
          presetName: 'rock',
          bandGains: [3.0, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0],
          updatedAt: now,
        ),
        playbackState: SyncPlaybackState.initial(),
      );

      final receiveFuture = server.onSnapshotReceived.first;

      final success = await client.pushSnapshot(
        '127.0.0.1',
        snapshot,
        port: serverPort,
        authKey: testAuthKey,
      );

      expect(success, isTrue);

      final received = await receiveFuture.timeout(const Duration(seconds: 3));
      expect(received.favorites.length, 1);
      expect(received.favorites.first.track.title, '局域网传输测试曲目');
      expect(received.playlists.length, 1);
      expect(received.playlists.first.name, 'P2P 局域网分享歌单');
      expect(received.equalizer.presetName, 'rock');
    });

    test('LX-Sync 格式自动兼容接收与解析', () async {
      final lxPayload = {
        'action': 'sync_list',
        'data': {
          'defaultList': [
            {
              'id': 'lx_song_1',
              'name': 'LX 格式曲目',
              'singer': '周杰伦',
              'albumName': '范特西',
              'interval': '03:45',
              'source': 'kw',
            }
          ],
          'userList': [
            {
              'id': 'lx_list_1',
              'name': '外部导入歌单',
              'list': [
                {
                  'id': 'lx_song_2',
                  'name': '枫',
                  'singer': '周杰伦',
                  'albumName': '11月的萧邦',
                  'interval': '04:35',
                  'source': 'kw',
                }
              ]
            }
          ]
        }
      };

      final receiveFuture = server.onSnapshotReceived.first;

      final success = await client.pushLxSyncPayload(
        '127.0.0.1',
        lxPayload,
        port: serverPort,
        authKey: testAuthKey,
      );

      expect(success, isTrue);

      final received = await receiveFuture.timeout(const Duration(seconds: 3));
      expect(received.favorites.length, 1);
      expect(received.favorites.first.track.title, 'LX 格式曲目');
      expect(received.playlists.length, 1);
      expect(received.playlists.first.name, '外部导入歌单');
    });
  });

  group('LanSyncService 门面与实用工具方法', () {
    test('getSubnetPrefix 提取子网前缀', () {
      expect(LanSyncService.getSubnetPrefix('192.168.31.50'), '192.168.31');
      expect(LanSyncService.getSubnetPrefix('10.0.4.12'), '10.0.4');
    });

    test('getLocalIPv4 返回合法格式的 IPv4 地址', () async {
      final ip = await LanSyncService.getLocalIPv4();
      expect(ip, isNotEmpty);
      expect(ip.split('.').length, 4);
    });
  });
}
