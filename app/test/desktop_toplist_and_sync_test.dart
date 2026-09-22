import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';

void main() {
  group('PC 桌面端排行榜消灭死白与多端协同中心专项验收套件', () {
    late ThemeProvider themeProvider;
    late AudioPlayerService audioPlayerService;
    late EqualizerManager equalizerManager;

    setUp(() {
      themeProvider = ThemeProvider();
      audioPlayerService = AudioPlayerService();
      equalizerManager = EqualizerManager();
    });

    Widget buildDesktopApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audioPlayerService),
          ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
        ],
        child: const MaterialApp(
          home: DesktopScaffold(),
        ),
      );
    }

    testWidgets('PC-TOPLIST-01: 巅峰排行榜横向双栏高密度布局验证，彻底消灭死白荒漠', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 点击侧边栏切换至“巅峰榜单”
      final toplistNavItem = find.text('巅峰榜单');
      expect(toplistNavItem, findsOneWidget);
      await tester.tap(toplistNavItem);
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证榜单主标题与描述
      expect(find.text('官方巅峰排行榜'), findsOneWidget);
      expect(find.text('汇聚全网多源权威数据，实时追踪流行脉搏'), findsOneWidget);

      // 2. 验证四大官方榜单封面及标识存在
      expect(find.text('飙升榜'), findsWidgets);
      expect(find.text('热歌榜'), findsWidgets);
      expect(find.text('新歌榜'), findsWidgets);
      expect(find.text('原创榜'), findsWidgets);

      // 3. 验证 Top 5 排行榜歌曲列表存在 (每个榜单 5 首，四榜单均有 1, 2, 3 标号)
      expect(find.text('1'), findsAtLeastNWidgets(4));
      expect(find.text('2'), findsAtLeastNWidgets(4));
      expect(find.text('3'), findsAtLeastNWidgets(4));

      // 4. 点击第一首单曲直接点播
      final firstSongItem = find.text('1').first;
      await tester.tap(firstSongItem);
      await tester.pump(const Duration(milliseconds: 100));

      // 验证正在播放状态被唤醒
      expect(audioPlayerService.isPlaying, isTrue);

      // 暂停播放以销毁周期性定时器
      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PC-SYNC-01: 多端协同与云端同步中心闭环验证 (WebDAV + LAN P2P)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 点击侧边栏切换至“多端同步中心”
      final syncNavItem = find.text('多端同步中心');
      expect(syncNavItem, findsOneWidget);
      await tester.tap(syncNavItem);
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证同步中心标题与特性
      expect(find.text('多端协同与云端同步中心'), findsOneWidget);
      expect(find.text('支持 WebDAV 私有云盘实时双向热备，与局域网近场毫秒级 P2P 跨端流转'), findsOneWidget);

      // 2. 验证数据指标健康看板
      expect(find.text('本地红心收藏'), findsOneWidget);
      expect(find.text('自建与导入歌单'), findsOneWidget);
      expect(find.text('播放足迹历史'), findsOneWidget);

      // 3. 验证 WebDAV 模块与云端备份触发诚实提示
      expect(find.text('WebDAV 私有云盘同步'), findsOneWidget);
      final backupBtn = find.text('立即云端备份');
      expect(backupBtn, findsOneWidget);
      await tester.tap(backupBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('云端同步功能尚未完整接入，请勿依赖此页面备份数据'), findsOneWidget);

      // 4. 滚动到局域网协同设备模块
      final lanTitle = find.text('局域网近场设备协同 (LAN P2P)');
      await tester.scrollUntilVisible(lanTitle, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 100));

      // 验证局域网近场协同模块与当前未发现配对设备的真实状态
      expect(lanTitle, findsOneWidget);
      expect(find.text('当前未发现局域网配对设备'), findsOneWidget);

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
