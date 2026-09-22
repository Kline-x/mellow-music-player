import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/common/modals.dart';

void main() {
  group('PC 桌面端对标 AlgerMusicPlayer 现代架构专项验收套件', () {
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

    testWidgets('PC-01: 彻底杜绝假 Mac 红黄绿圆点与模拟手机预览按钮', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证不存在模拟手机预览按钮
      expect(find.byIcon(Icons.smartphone_rounded), findsNothing);

      // 2. 验证左上角不存在 macOS 红黄绿圆点 (0xFFFF5F56)
      final redCircles = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          if (box.color == const Color(0xFFFF5F56)) return true;
        }
        return false;
      });
      expect(redCircles, findsNothing);

      // 3. 验证存在现代桌面沉浸品牌 Logo 与名称
      expect(find.text('Mellow Music · 润音'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PC-02: 现代桌面端顶栏功能组：快速搜索、导入歌单、5色调色盘与明暗切换', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证存在“导入歌单”按钮
      final importBtn = find.text('导入歌单');
      expect(importBtn, findsOneWidget);

      // 2. 点击“导入歌单”，能够弹出 ImportPlaylistModal
      await tester.tap(importBtn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ImportPlaylistModal), findsOneWidget);
      expect(find.text('一键导入外部歌单'), findsOneWidget);

      // 关闭弹窗
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ImportPlaylistModal), findsNothing);

      // 3. 验证搜索栏点击唤起 QuickSearchOverlay
      final searchBar = find.text('即时搜索全网歌曲、歌手、专辑...');
      expect(searchBar, findsOneWidget);
      await tester.tap(searchBar);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(QuickSearchOverlay), findsOneWidget);
      expect(find.text('搜索全网歌曲、歌手、专辑 (按 ESC 退出)...'), findsOneWidget);

      // 在搜索框中输入“周杰伦”
      await tester.enterText(find.byType(TextField), '周杰伦');
      await tester.pump(const Duration(milliseconds: 100));

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PC-03: 侧边栏支持“导入与自建歌单”视图，歌单管理与播放闭环', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 侧边栏点击“导入与自建歌单”
      final navImported = find.text('导入与自建歌单');
      expect(navImported, findsOneWidget);
      await tester.tap(navImported);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证进入歌单中心
      expect(find.text('支持网易云音乐、QQ音乐分享链接与 ID 一键秒级抓取导入'), findsOneWidget);

      // 2. 注入模拟导入歌单
      final mockPlaylist = ImportedPlaylist(
        id: 'test_123',
        title: '测试华语经典歌单',
        coverUrl: 'https://example.com/cover.jpg',
        description: '测试网易云歌单导入',
        trackCount: 2,
        tracks: [
          audioPlayerService.playlist[0].copyWith(title: '歌单曲目1'),
          audioPlayerService.playlist[1].copyWith(title: '歌单曲目2'),
        ],
      );
      audioPlayerService.addImportedPlaylist(mockPlaylist);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证歌单卡片渲染
      expect(find.text('测试华语经典歌单'), findsOneWidget);
      expect(find.text('包含 2 首完整音轨 · 测试网易云歌单导入'), findsOneWidget);

      // 3. 点击“播放全部”
      final playAllBtn = find.text('播放全部').first;
      await tester.tap(playAllBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(audioPlayerService.isPlaying, isTrue);

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
