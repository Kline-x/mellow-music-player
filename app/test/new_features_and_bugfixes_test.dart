import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';
import 'package:mellow_music/core/sync/sync_data_model.dart';
import 'package:mellow_music/core/services/version_check_service.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('三大专项特性与Bug修复全量回归套件', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.init();
    });

    test('1. 局域网协同：LanDevice 模型与近场直连免密互信机制验证', () {
      // 1.1 校验 LanDevice 携带 authKey 的序列化与反序列化
      final dev = LanDevice(
        id: 'device-win-01',
        name: 'Windows 4K PC',
        ip: '192.168.1.8',
        port: 23332,
        version: '1.2.0',
        authKey: 'SECRET99',
        lastSeen: DateTime(2026, 9, 30),
      );
      final json = dev.toJson();
      expect(json['authKey'], 'SECRET99');

      final fromJson = LanDevice.fromJson(json);
      expect(fromJson.authKey, 'SECRET99');
      expect(fromJson.name, 'Windows 4K PC');

      // 1.2 校验 LanSyncServer 的近场免密直投模式属性
      final server = LanSyncServer();
      expect(server.allowLanDirectPush, true);
      server.allowLanDirectPush = false;
      expect(server.allowLanDirectPush, false);
    });

    test('2. 在线更新：多镜像候选节点生成与版本清单解析验证', () {
      const originalUrl =
          'https://github.com/Kline-x/mellow-music-player/releases/download/v1.1.1/mellow-music-windows-setup.exe';
      final candidates =
          VersionCheckService.buildAcceleratedDownloadUrls(originalUrl);

      // 断言生成了国内高速镜像代理节点，且原链接排在候选队列中
      expect(candidates.any((u) => u.contains('ghproxy.net')), isTrue);
      expect(candidates.any((u) => u.contains('ghfast.top')), isTrue);
      expect(candidates.contains(originalUrl), isTrue);

      // 校验版本清单解析
      final manifestJson = {
        'versionCode': 4,
        'versionName': '1.2.0',
        'publishDate': '2026-09-30',
        'releaseNotes': '全新在线更新与协同',
        'platforms': {
          'windows': {
            'downloadUrl': originalUrl,
            'fileSize': 42000000,
            'installMode': 'in_app_download'
          }
        }
      };

      final info = AppVersionInfo.fromJson(manifestJson);
      expect(info.versionCode, 4);
      expect(info.versionName, '1.2.0');
      expect(info.platforms.containsKey('windows'), isTrue);
      expect(info.platforms['windows']?.fileSize, 42000000);
    });

    testWidgets('3. 播放历史：DesktopHistoryView渲染与微任务切歌调度稳定性验证',
        (tester) async {
      final player = AudioPlayerService();
      final theme = ThemeProvider();

      // 先播放两首歌曲建立足迹
      const track1 = Track(
        id: 'hist-1',
        title: '历史曲目 1',
        artist: '测试歌手 1',
        album: '测试专辑 1',
        duration: Duration(minutes: 3),
        coverUrl: 'https://example.com/c1.png',
      );
      const track2 = Track(
        id: 'hist-2',
        title: '历史曲目 2',
        artist: '测试歌手 2',
        album: '测试专辑 2',
        duration: Duration(minutes: 4),
        coverUrl: 'https://example.com/c2.png',
      );

      player.playTrack(track1);
      player.playTrack(track2);
      expect(player.playHistory.length, 2);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopHistoryView(onNavigate: (_, [__]) {}),
            ),
          ),
        ),
      );

      // 验证历史页面歌曲行正常渲染
      expect(find.text('历史曲目 1'), findsOneWidget);
      expect(find.text('历史曲目 2'), findsOneWidget);

      // 点击第一行触发切歌，验证微任务执行与 0 崩溃
      await tester.tap(find.text('历史曲目 1'));
      await tester.pumpAndSettle();

      expect(player.currentTrack?.id, 'hist-1');
      player.dispose();
    });

    test('4. 音频服务：音源切换互斥防重锁验证', () async {
      final player = AudioPlayerService();
      const track = Track(
        id: 'switch-test',
        title: '晴天',
        artist: '周杰伦',
        album: '叶惠美',
        duration: Duration(minutes: 4),
        coverUrl: 'https://example.com/c.png',
      );

      // 模拟音源切换调用，验证防重锁安全返回
      final f1 = player.switchSource(track, 'netease-online');
      final f2 = player.switchSource(track, 'qq-online');

      // 由于第一路正在请求，第二路会被互斥锁直接拦截或排队
      final r2 = await f2;
      expect(r2, isFalse);

      await f1;
    });
  });
}
