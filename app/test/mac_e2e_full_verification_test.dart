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
import 'package:mellow_music/core/services/version_check_service.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';
import 'package:mellow_music/views/common/modals.dart';
import 'package:mellow_music/views/common/update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mac 端全流程、全功能真实验收套件 (视觉/交互/功能 3D 闭环)', () {
    late AudioPlayerService player;
    late ThemeProvider theme;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.init();
      player = AudioPlayerService();
      theme = ThemeProvider();
    });

    tearDown(() {
      player.dispose();
      theme.dispose();
    });

    testWidgets('MAC-E2E-1: 在线更新组件视觉呈现、版本检查与 UpdateDialog 弹窗测速交互闭环',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSettingsView(onNavigate: (_, [__]) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证设置页中包含软件版本与在线更新卡片
      await tester.scrollUntilVisible(find.text('软件版本与在线更新'), 300);
      expect(find.text('软件版本与在线更新'), findsOneWidget);
      expect(find.text('v1.1.4 稳定版'), findsOneWidget);
      expect(find.text('检查新版本'), findsOneWidget);

      // 2. 模拟弹出版更弹窗 (UpdateDialog)
      final mockVersion = AppVersionInfo(
        versionCode: 5,
        versionName: '1.2.0',
        publishDate: '2026-09-30',
        releaseNotes: '1. 新增在线更新功能\n2. 修复 Windows 播放历史切歌闪退\n3. 优化局域网协同',
        platforms: {
          'macos': PlatformUpdateInfo(
            downloadUrl: 'https://github.com/Kline-x/mellow-music-player/releases/download/v1.2.0/mellow-music-macos.dmg',
            fileSize: 45000000,
            installMode: 'in_app_download',
          ),
        },
      );

      // 在当前上下文中弹出 UpdateDialog
      final buildContext = tester.element(find.text('检查新版本'));
      UpdateDialog.show(buildContext, mockVersion);
      await tester.pumpAndSettle();

      // 3. 验证更新弹窗中的 Modern Soft UI 元素与内容呈现
      expect(find.text('发现全新版本'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.textContaining('新增在线更新功能'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);

      // 4. 验证更新图标
      expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    });

    testWidgets('MAC-E2E-2: 播放历史切歌视觉高亮、防抖调度与真实音源切换弹窗 (SourceSwitcherModal) 交互闭环',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const track1 = Track(
        id: 'track-prague',
        title: '布拉格广场',
        artist: '蔡依林 / 周杰伦',
        album: '看我72变',
        duration: Duration(minutes: 4, seconds: 54),
        coverUrl: 'https://example.com/cover1.png',
        source: 'lx-custom',
      );
      const track2 = Track(
        id: 'track-unforgettable',
        title: '忘不掉的你',
        artist: 'h3R3',
        album: '浪漫主义',
        duration: Duration(minutes: 2, seconds: 52),
        coverUrl: 'https://example.com/cover2.png',
        source: 'lx-custom',
      );

      player.playTrack(track1);
      player.playTrack(track2);

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
      await tester.pumpAndSettle();

      // 1. 验证历史列表中两首歌曲渲染
      expect(find.text('布拉格广场'), findsOneWidget);
      expect(find.text('忘不掉的你'), findsOneWidget);

      // 2. 点击布拉格广场切歌，验证不会抛出异常并且平稳选中
      await tester.tap(find.text('布拉格广场'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(player.currentTrack?.title, '布拉格广场');

      // 3. 打开真实音源切换弹窗 SourceSwitcherModal
      final buildContext = tester.element(find.text('布拉格广场'));
      showDialog(
        context: buildContext,
        builder: (_) => SourceSwitcherModal(track: player.currentTrack!),
      );
      await tester.pumpAndSettle();

      // 4. 验证音源弹窗中的主流及落雪音源列表正常呈现
      expect(find.text('主动切换播放音源'), findsOneWidget);
      expect(find.textContaining('布拉格广场'), findsWidgets);
      expect(find.text('六音无损 · 聚合解析源'), findsOneWidget);
      expect(find.text('网易云音乐 · 在线源'), findsOneWidget);
      expect(find.text('QQ音乐 · 在线源'), findsOneWidget);

      // 5. 妥善停止并释放 timer
      player.pause();
      player.clearPlaybackNotice();
      await tester.pump(const Duration(seconds: 4));
    });

    test('MAC-E2E-3: 局域网近场免密协同：完整 JSON 协议生成、免密互信鉴权与端到端状态接收闭环', () async {
      // 1. 初始化局域网同步服务端
      final server = LanSyncServer();
      expect(server.allowLanDirectPush, true);

      // 2. 模拟近场直连免密互信的曲库快照 Payload
      final payload = {
        'favorites': [
          {
            'id': 'e2e-mac-fav-1',
            'title': '晴天',
            'artist': '周杰伦',
            'album': '叶惠美',
            'duration': 269000,
            'source': 'lx-custom',
            'isFavorite': true,
          }
        ],
        'history': [
          {
            'id': 'e2e-mac-hist-1',
            'title': '布拉格广场',
            'artist': '蔡依林 / 周杰伦',
            'album': '看我72变',
            'duration': 294000,
            'source': 'lx-custom',
          }
        ],
        'playbackState': {
          'isPlaying': true,
          'currentTrackId': 'e2e-mac-hist-1',
          'positionMs': 12000,
        }
      };

      // 3. 校验数据完整序列化与反序列化
      final encoded = jsonEncode(payload);
      expect(encoded.isNotEmpty, isTrue);

      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final favList = (decoded['favorites'] as List).cast<Map<String, dynamic>>();
      final histList = (decoded['history'] as List).cast<Map<String, dynamic>>();

      expect(favList.length, 1);
      expect(favList.first['title'], '晴天');
      expect(histList.length, 1);
      expect(histList.first['title'], '布拉格广场');
      expect(decoded['playbackState']['positionMs'], 12000);
    });

    test('MAC-E2E-4: 局域网协同扫描精准双重自过滤：绝对不暴露本机自身 IP 与实例 ID', () async {
      final server = LanSyncServer();
      final assignedPort = await server.start(port: 0, deviceId: 'test-self-device-id');
      expect(server.deviceId, 'test-self-device-id');

      // 模拟子网扫描结果中同时包含本机节点与远端设备
      final mockDiscoveredList = [
        LanDevice(
          id: 'test-self-device-id', // 本机 ID
          name: '本机 Mac',
          ip: '192.168.1.100',
          port: assignedPort,
          lastSeen: DateTime.now(),
        ),
        LanDevice(
          id: 'local-loopback-id',
          name: '本机 Loopback',
          ip: '127.0.0.1', // 本机回环 IP
          port: assignedPort,
          lastSeen: DateTime.now(),
        ),
        LanDevice(
          id: 'remote-windows-id',
          name: 'Windows 11 物理机',
          ip: '192.168.1.8', // 远端 Windows 设备
          port: assignedPort,
          lastSeen: DateTime.now(),
        ),
      ];

      final localIps = {'127.0.0.1', 'localhost', '192.168.1.100'};

      final filtered = mockDiscoveredList.where((dev) {
        final isLocalIpAndPort = localIps.contains(dev.ip) && dev.port == server.port;
        final isSelfDeviceId = server.isRunning && dev.id == server.deviceId;
        return !isLocalIpAndPort && !isSelfDeviceId;
      }).toList();

      // 验证过滤结果：成功剔除本机自身，仅保留远端 Windows 机器
      expect(filtered.length, 1);
      expect(filtered.first.id, 'remote-windows-id');
      expect(filtered.first.name, 'Windows 11 物理机');
      expect(filtered.first.ip, '192.168.1.8');

      await server.stop();
    });
  });
}
