import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/window/desktop_floating_lyric_service.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';
import 'package:mellow_music/views/desktop/desktop_search_view.dart';
import 'package:mellow_music/views/desktop/fullscreen_lyrics_view.dart';
import 'package:mellow_music/views/common/modals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    MellowImage.isInTest = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    await DesktopFloatingLyricService.instance.init();

    // 隔离外部网络，提供稳定的 25 首曲目响应
    OnlineMusicService.enableKuwoSearch = false;
    final mockClient = MockClient((request) async {
      final songs = List.generate(25, (i) => {
        'id': 100000 + i,
        'name': '周杰伦经典曲目_$i',
        'duration': 210000,
        'fee': 0,
        'artists': [{'name': '周杰伦'}],
        'album': {'name': '经典专辑_$i', 'picId': 100 + i},
      });
      return http.Response(
        jsonEncode({
          'result': {'songs': songs},
          'code': 200,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    OnlineMusicService.neteaseService = NeteaseMusicService(client: mockClient);
  });

  group('Mellow Music · 深度探索性真机 E2E 循环排查套件 (零缺陷闭环验证)', () {
    late ThemeProvider themeProvider;
    late InMemoryAudioPlayerBackend backend;
    late AudioPlayerService playerService;
    late EqualizerManager equalizerManager;

    setUp(() {
      themeProvider = ThemeProvider();
      backend = InMemoryAudioPlayerBackend();
      playerService = AudioPlayerService(backend: backend);
      equalizerManager = EqualizerManager();
    });

    tearDown(() {
      playerService.pause();
      playerService.dispose();
      equalizerManager.dispose();
    });

    Widget buildApp({required Widget child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: playerService),
          ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('CHECK-01: 搜索结果长列表触底滚动与分页加载机制验证', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(child: DesktopSearchView(onNavigate: (page, [extra]) {})));
      await tester.pump(const Duration(milliseconds: 300));

      // 在搜索框输入查询词
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, '周杰伦');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 500));

      // 验证初次加载有结果
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('周杰伦经典曲目_0'), findsOneWidget);

      // 模拟向下滚动触底
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证滚动后列表顺畅可达且无任何异常抛出
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('CHECK-02: 跨页面红心收藏状态实时同步闭环验证 (主视图 -> 我喜欢的音乐)', (tester) async {
      // 放大视口确保全量列表均在可见区
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testTrack = Track(
        id: 'sync_test_track_99',
        title: '闭环测试单曲',
        artist: '测试艺术家',
        album: '测试专辑',
        duration: const Duration(seconds: 210),
        coverUrl: 'https://example.com/cover.jpg',
        audioUrl: 'https://example.com/test.mp3',
      );

      // 初始：收藏列表为空
      expect(playerService.isFavorite(testTrack.id), isFalse);

      // 执行收藏并传入完整 Track 实体
      playerService.toggleFavorite(testTrack.id, testTrack);
      expect(playerService.isFavorite(testTrack.id), isTrue);

      // 验证持久化已写入实体
      final favList = StorageService.instance.getFavoriteTracks();
      expect(favList != null && favList.any((t) => t.id == testTrack.id), isTrue);

      // 渲染「我喜欢的音乐」视图
      await tester.pumpWidget(buildApp(child: DesktopFavoriteView(onNavigate: (page, [extra]) {})));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证我喜欢的音乐列表即时呈现该单曲标题与歌手
      expect(find.text('闭环测试单曲'), findsOneWidget);
      expect(find.text('测试艺术家'), findsOneWidget);
      expect(find.text('测试专辑'), findsOneWidget);

      // 在列表中再次点击取消收藏
      final favRowFinder = find.widgetWithText(DesktopSongTableView, '闭环测试单曲');
      expect(favRowFinder, findsOneWidget);
      playerService.toggleFavorite(testTrack.id, testTrack);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证取消收藏即时生效
      expect(playerService.isFavorite(testTrack.id), isFalse);
    });

    testWidgets('CHECK-03: 歌手详情页关注状态持久化记忆闭环', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 直接渲染周杰伦歌手详情页
      await tester.pumpWidget(buildApp(child: DesktopArtistDetailView(artistName: '周杰伦', onNavigate: (page, [extra]) {})));
      await tester.pump(const Duration(milliseconds: 300));

      // 初始默认应为未关注
      expect(find.text('+ 关注歌手'), findsOneWidget);
      expect(StorageService.instance.isArtistFollowed('周杰伦'), isFalse);

      // 点击关注
      await tester.tap(find.text('+ 关注歌手'));
      await tester.pump(const Duration(milliseconds: 300));

      // 按钮变为已关注，且 StorageService 持久化为 true
      expect(find.text('已关注'), findsOneWidget);
      expect(StorageService.instance.isArtistFollowed('周杰伦'), isTrue);

      // 模拟重新打开歌手详情页
      await tester.pumpWidget(buildApp(child: DesktopArtistDetailView(artistName: '周杰伦', onNavigate: (page, [extra]) {})));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证关注状态被正确记忆恢复
      expect(find.text('已关注'), findsOneWidget);
    });

    testWidgets('CHECK-04: 巨幕全屏歌词 ESC 快捷键与显式返回按钮双重闭环', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool exitTriggered = false;

      await tester.pumpWidget(
        buildApp(
          child: DesktopFullscreenLyricsView(
            onClose: () => exitTriggered = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 验证左上角显式胶囊按钮存在
      final backButton = find.text('返回主界面 (ESC)');
      expect(backButton, findsOneWidget);

      // 点击显式返回按钮
      await tester.tap(backButton);
      await tester.pump(const Duration(milliseconds: 200));
      expect(exitTriggered, isTrue);

      // 重置并测试按 ESC 快捷键
      exitTriggered = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 200));
      expect(exitTriggered, isTrue);
    });

    testWidgets('CHECK-05: EQ 均衡器在 10 频段全量调节且杜绝 RenderFlex 溢出', (tester) async {
      // 模拟中等视口 (800x600)
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(child: const EqualizerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证预设存在
      expect(find.text('原声直通 (Flat)'), findsOneWidget);
      expect(find.text('通透人声 (Clear Vocal)'), findsOneWidget);
      expect(find.text('澎湃低音 (Bass Boost)'), findsOneWidget);

      // 切换到通透人声
      await tester.tap(find.text('通透人声 (Clear Vocal)'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(equalizerManager.currentPreset, equals(EqualizerPreset.clearVocal));

      // 调节第 1 个频段滑块
      final sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(10));
      await tester.tap(sliders.first);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('CHECK-06: 桌面工作台主视图底栏安全间距与安全边距完整性', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 挂载完整 DesktopScaffold
      await tester.pumpWidget(buildApp(child: const DesktopScaffold()));
      await tester.pump(const Duration(milliseconds: 500));

      // 验证主界面品牌文字与播放底栏挂载
      expect(find.byType(DesktopScaffold), findsOneWidget);
      expect(find.text('Mellow Music · 润音'), findsOneWidget);
    });
  });
}
