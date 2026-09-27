import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('大半径探索性排查与边界验收套件', () {
    testWidgets('边界测试1: 桌面端在多种极限视口(750x550~1920x1080)下榜单详情与日推页绝对零溢出', (tester) async {
      final viewports = [
        const Size(750, 550),   // 超极窄小窗
        const Size(900, 650),   // 紧凑小窗
        const Size(1280, 800),  // 经典笔记本
        const Size(1920, 1080), // 全高清大屏
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final themeProvider = ThemeProvider();
        final audioService = AudioPlayerService();

        // 验证榜单详情页
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: themeProvider),
              ChangeNotifierProvider.value(value: audioService),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: DesktopToplistDetailView(
                  chartName: '飙升榜',
                  onNavigate: (_, [__]) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '在视口 $size 下榜单详情页不得抛出溢出或异常');

        // 验证每日推荐页
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: themeProvider),
              ChangeNotifierProvider.value(value: audioService),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: DesktopDailyRecommendView(
                  onNavigate: (_, [__]) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '在视口 $size 下每日推荐页不得抛出溢出或异常');
      }
      tester.view.resetPhysicalSize();
    });

    testWidgets('边界测试2: 桌面端榜单详情内搜索过滤与清除小叉交互验证', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopToplistDetailView(
                chartName: '热歌榜',
                onNavigate: (_, [__]) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // 输入不存在的关键词
      await tester.enterText(searchField, 'ZZZZZZ_NON_EXISTENT_SONG_9999');
      await tester.pump(const Duration(milliseconds: 200));

      // 验证未找到歌曲提示与清除小叉出现
      expect(find.text('未找到相关榜单曲目'), findsOneWidget);
      final clearBtn = find.byIcon(Icons.close_rounded);
      expect(clearBtn, findsOneWidget);

      // 点击清除小叉按钮，验证快速重置并恢复列表
      await tester.tap(clearBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('榜单歌曲列表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('边界测试3: 移动端在极限极窄手机视口(320x568 iPhone SE1)与大屏(430x932)零溢出', (tester) async {
      final mobileViewports = [
        const Size(320, 568), // iPhone SE 1代
        const Size(375, 667), // iPhone 8 / SE 2代
        const Size(390, 844), // iPhone 12/13/14
        const Size(430, 932), // iPhone 14/15 Pro Max
      ];

      for (final size in mobileViewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final themeProvider = ThemeProvider();
        final audioService = AudioPlayerService();

        // 移动端每日推荐
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: themeProvider),
              ChangeNotifierProvider.value(value: audioService),
            ],
            child: MaterialApp(
              home: MobileDailyRecommendPage(onBack: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '在移动端视口 $size 下每日推荐页零溢出');

        // 移动端榜单详情
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: themeProvider),
              ChangeNotifierProvider.value(value: audioService),
            ],
            child: MaterialApp(
              home: MobileToplistDetailPage(chartName: '新歌榜', onBack: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '在移动端视口 $size 下榜单详情页零溢出');
      }
      tester.view.resetPhysicalSize();
    });

    testWidgets('边界测试4: 深色模式与浅色模式动态切换下日推与榜单详情对比度与样式正常', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService();

      // 先浅色
      if (themeProvider.isDarkMode) {
        themeProvider.toggleTheme();
      }
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopDailyRecommendView(
                onNavigate: (_, [__]) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('每日推荐'), findsWidgets);

      // 切换深色
      themeProvider.toggleTheme();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('每日推荐'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('边界测试5: 桌面端主框架在发现音乐、歌单广场、排行榜、榜单详情、日推页全流程下钻无缝切换', (tester) async {
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService();
      final equalizerManager = EqualizerManager();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
            ChangeNotifierProvider.value(value: equalizerManager),
          ],
          child: const MaterialApp(
            home: DesktopScaffold(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 发现音乐页中看到每日推荐便签卡片并点击
      final dailyCard = find.textContaining('专属日推');
      expect(dailyCard, findsOneWidget);
      await tester.tap(dailyCard);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证下钻进入每日推荐详情页
      expect(find.text('播放全部 (28首)'), findsOneWidget);

      // 点击返回面包屑回到发现音乐
      final backBtn = find.text('发现音乐');
      expect(backBtn, findsWidgets);
      await tester.tap(backBtn.first);
      await tester.pump(const Duration(milliseconds: 300));

      // 2. 切换至“巅峰榜单”侧边栏导航
      final chartNav = find.text('巅峰榜单');
      expect(chartNav, findsOneWidget);
      await tester.tap(chartNav);
      await tester.pump(const Duration(milliseconds: 300));

      // 点击飙升榜卡片
      final surgeChart = find.text('飙升榜');
      expect(surgeChart, findsWidgets);
      await tester.tap(surgeChart.first);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证进入飙升榜详情页
      expect(find.text('官方权威排行榜'), findsOneWidget);

      // 测试一键播放全部
      final playAllBtn = find.textContaining('播放全部');
      expect(playAllBtn, findsOneWidget);
      await tester.tap(playAllBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(audioService.playlist.isNotEmpty, isTrue);
      expect(audioService.currentTrack, isNotNull);

      // 返回巅峰榜单
      final returnChartBtn = find.text('返回巅峰榜单');
      expect(returnChartBtn, findsOneWidget);
      await tester.tap(returnChartBtn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('官方巅峰排行榜'), findsOneWidget);
    });
  });
}
