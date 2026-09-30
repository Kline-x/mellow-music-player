import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mellow_music/core/sync/lan_sync_service.dart';
import 'package:mellow_music/core/sync/sync_data_model.dart';

void main() {
  HttpOverrides.global = null;
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('局域网近场同步真实 HTTP 端口网络通信真机验收套件', () {
    late LanSyncServer server;
    late int port;

    setUp(() async {
      server = LanSyncServer();
      port = await server.start(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        allowLanDirectPush: true,
      );
    });

    tearDown(() async {
      await server.stop();
    });

    test('1. 真实网络探针 /sync/hello 响应包含 allowDirectPush 标记', () async {
      final client = http.Client();
      try {
        final res = await client.get(Uri.parse('http://127.0.0.1:$port/sync/hello'));
        expect(res.statusCode, 200);
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        expect(map['status'], 'ok');
        expect(map['action'], 'hello');
        expect(map['allowDirectPush'], isTrue);
      } finally {
        client.close();
      }
    });

    test('2. 真实网络投送 /sync/push 近场免密互信直传快照成功接收', () async {
      final client = http.Client();
      SyncSnapshot? receivedSnapshot;
      server.onSnapshotReceived.listen((snap) {
        receivedSnapshot = snap;
      });

      try {
        final payload = {
          'deviceId': 'peer-win-01',
          'deviceName': 'Windows 4K Native',
          'timestamp': DateTime.now().toIso8601String(),
          'favorites': [
            {
              'trackId': 'track-real-push-1',
              'addedAt': DateTime.now().toIso8601String(),
              'track': {
                'id': 'track-real-push-1',
                'title': '稻香',
                'artist': '周杰伦',
                'album': '魔杰座',
                'duration': 223,
              }
            }
          ],
          'playlists': [
            {
              'id': 'pl-real-1',
              'name': '近场测试合流歌单',
              'trackCount': 1,
              'tracks': []
            }
          ],
          'history': []
        };

        final res = await client.post(
          Uri.parse('http://127.0.0.1:$port/sync/push'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        );

        expect(res.statusCode, 200);
        final resJson = jsonDecode(res.body) as Map<String, dynamic>;
        expect(resJson['status'], 'received');

        // 验证服务端真正接收并解析完成
        await Future.delayed(const Duration(milliseconds: 100));
        expect(receivedSnapshot, isNotNull);
        expect(receivedSnapshot!.deviceId, 'peer-win-01');
        expect(receivedSnapshot!.favorites.length, 1);
        expect(receivedSnapshot!.favorites.first.track.title, '稻香');
        expect(receivedSnapshot!.playlists.length, 1);
        expect(receivedSnapshot!.playlists.first.name, '近场测试合流歌单');
      } finally {
        client.close();
      }
    });

    test('3. 强制密码模式下：错误密钥被 401 拦截，正确密钥顺利放行', () async {
      await server.stop();
      final securePort = await server.start(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        authKey: 'SUPER_KEY_888',
        allowLanDirectPush: false,
      );

      final client = http.Client();
      try {
        final dummyPayload = {
          'deviceId': 'auth-tester',
          'deviceName': 'Tester',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // 3.1 传递错误密钥 -> 401 Unauthorized
        final resBad = await client.post(
          Uri.parse('http://127.0.0.1:$securePort/sync/push'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'x-auth-key': 'WRONG_KEY',
          },
          body: jsonEncode(dummyPayload),
        );
        expect(resBad.statusCode, 401);

        // 3.2 传递正确密钥 -> 200 OK
        final resGood = await client.post(
          Uri.parse('http://127.0.0.1:$securePort/sync/push'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'x-auth-key': 'SUPER_KEY_888',
          },
          body: jsonEncode(dummyPayload),
        );
        expect(resGood.statusCode, 200);
      } finally {
        client.close();
      }
    });
  });
}
