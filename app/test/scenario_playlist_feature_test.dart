import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';
import 'package:mellow_music/core/sources/scenario_playlist_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/common/playlist_detail_dialog.dart';
import 'package:mellow_music/views/desktop/desktop_scenario_view.dart';
import 'package:mellow_music/views/mobile/mobile_scenario_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('场景歌单推荐与自由搜索全套测试 (Scenario Playlist Feature Tests)', () {
    late ThemeProvider themeProvider;
    late AudioPlayerService audioPlayerService;
    late EqualizerManager equalizerManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.init();
      themeProvider = ThemeProvider();
      audioPlayerService = AudioPlayerService();
      equalizerManager = EqualizerManager();
      ScenarioPlaylistService.instance.clearCache();
    });

    Widget buildTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audioPlayerService),
          ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    test('SCENARIO-SERVICE-01: 场景预置清单完整性与核心场景关键词校验', () {
      final presets = ScenarioPlaylistService.presetScenarios;
      expect(presets.isNotEmpty, isTrue);

      // 验证核心场景（结婚、国庆、新年）
      final wedding = presets.firstWhere((s) => s.id == 'wedding');
      expect(wedding.title, '婚礼庆典');
      expect(wedding.keywords, contains('结婚'));
      expect(wedding.keywords, contains('婚礼'));

      final nationalDay = presets.firstWhere((s) => s.id == 'national_day');
      expect(nationalDay.title, '国庆华诞');
      expect(nationalDay.keywords, contains('国庆'));

      final newYear = presets.firstWhere((s) => s.id == 'new_year');
      expect(newYear.title, '新春贺岁');
      expect(newYear.keywords, contains('新年'));
      expect(newYear.keywords, contains('春节'));
    });

    test('SCENARIO-SERVICE-02: 场景歌单自由检索与详情解析', () async {
      final service = ScenarioPlaylistService.instance;

      // 搜结婚
      final weddingLists = await service.searchScenarioPlaylists('结婚');
      expect(weddingLists.isNotEmpty, isTrue);
      expect(weddingLists.first.title, contains('结婚'));

      // 搜国庆
      final nationalLists = await service.searchScenarioPlaylists('国庆');
      expect(nationalLists.isNotEmpty, isTrue);
      expect(nationalLists.first.title, contains('国庆'));

      // 搜新年
      final newYearLists = await service.searchScenarioPlaylists('新年');
      expect(newYearLists.isNotEmpty, isTrue);
      expect(newYearLists.first.title, contains('新年'));

      // 获取歌单详情
      final detail = await service.getScenarioPlaylistDetail(weddingLists.first.id);
      expect(detail, isNotNull);
      expect(detail!.tracks.isNotEmpty, isTrue);
    });

    test('SCENARIO-STORAGE-03: StorageService 场景搜索历史持久化管理', () async {
      final storage = StorageService.instance;

      await storage.clearScenarioSearchHistory();
      expect(storage.getScenarioSearchHistory(), isEmpty);

      await storage.addScenarioSearchHistory('结婚');
      await storage.addScenarioSearchHistory('国庆');
      await storage.addScenarioSearchHistory('新年');

      var history = storage.getScenarioSearchHistory();
      expect(history.length, 3);
      expect(history.first, '新年'); // 最近搜索置顶

      // 去重置顶
      await storage.addScenarioSearchHistory('结婚');
      history = storage.getScenarioSearchHistory();
      expect(history.length, 3);
      expect(history.first, '结婚');

      await storage.clearScenarioSearchHistory();
      expect(storage.getScenarioSearchHistory(), isEmpty);
    });

    testWidgets('SCENARIO-DESKTOP-04: 桌面端 DesktopScenarioPlaylistView 场景卡片切换与自由搜索', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        DesktopScenarioPlaylistView(onNavigate: (_, [__]) {}),
      ));
      await tester.pumpAndSettle();

      // 1. 验证标题与搜索框
      expect(find.text('场景歌单推荐'), findsOneWidget);
      expect(find.byKey(const Key('scenario_search_input')), findsOneWidget);

      // 2. 验证预置场景大卡片（婚礼庆典、国庆华诞、新春贺岁）
      expect(find.byKey(const Key('scenario_card_wedding')), findsOneWidget);
      expect(find.byKey(const Key('scenario_card_national_day')), findsOneWidget);
      expect(find.byKey(const Key('scenario_card_new_year')), findsOneWidget);

      // 3. 点击“国庆华诞”大卡片切换场景
      await tester.tap(find.byKey(const Key('scenario_card_national_day')));
      await tester.pumpAndSettle();
      expect(find.text('「国庆」精选公开歌单'), findsOneWidget);

      // 4. 点击“新春贺岁”大卡片切换场景
      await tester.tap(find.byKey(const Key('scenario_card_new_year')));
      await tester.pumpAndSettle();
      expect(find.text('「新年」精选公开歌单'), findsOneWidget);

      // 5. 自由搜索：输入“自驾”并点击搜索按钮
      final searchInput = find.byKey(const Key('scenario_search_input'));
      await tester.enterText(searchInput, '自驾');
      await tester.tap(find.byKey(const Key('scenario_search_button')));
      await tester.pumpAndSettle();

      expect(find.text('「自驾」精选公开歌单'), findsOneWidget);
    });

    testWidgets('SCENARIO-DESKTOP-05: 桌面端侧边栏场景歌单导航项与歌单广场横幅存在性', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audioPlayerService),
          ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
        ],
        child: const MaterialApp(home: DesktopScaffold()),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证侧边栏存在“场景歌单”
      expect(find.text('场景歌单'), findsOneWidget);

      // 点击侧边栏“场景歌单”进入视图
      await tester.tap(find.text('场景歌单'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('场景歌单推荐'), findsOneWidget);
    });

    testWidgets('SCENARIO-MOBILE-06: 移动端 MobileScenarioPlaylistPage 页面与场景过滤', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        MobileScenarioPlaylistPage(onBack: () {}),
      ));
      await tester.pumpAndSettle();

      // 1. 验证标题与搜索框
      expect(find.text('场景歌单推荐'), findsOneWidget);
      expect(find.byKey(const Key('mobile_scenario_search_input')), findsOneWidget);

      // 2. 验证场景标签（国庆华诞、新春贺岁）
      expect(find.byKey(const Key('mobile_scenario_tag_national_day')), findsOneWidget);
      expect(find.byKey(const Key('mobile_scenario_tag_new_year')), findsOneWidget);

      // 3. 点击“国庆华诞”切换
      await tester.tap(find.byKey(const Key('mobile_scenario_tag_national_day')));
      await tester.pumpAndSettle();
      expect(find.text('「国庆」场景公开歌单'), findsOneWidget);

      // 4. 自由搜索输入并点击搜索
      await tester.enterText(find.byKey(const Key('mobile_scenario_search_input')), '露营');
      await tester.tap(find.byKey(const Key('mobile_scenario_search_btn')));
      await tester.pumpAndSettle();
      expect(find.text('「露营」场景公开歌单'), findsOneWidget);
    });

    testWidgets('SCENARIO-DIALOG-07: 通用 PlaylistDetailDialog 曲目弹窗与播放/收藏交互', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testTracks = getAllKnownTracks().take(3).toList();
      final testPlaylist = ImportedPlaylist(
        id: 'test_wedding_100',
        title: '浪漫婚礼精选集',
        coverUrl: 'https://images.unsplash.com/photo-1519741497674-611481863552?w=600&q=80',
        description: '浪漫结婚婚礼仪式背景音乐精选',
        trackCount: testTracks.length,
        tracks: testTracks,
      );

      await tester.pumpWidget(buildTestApp(
        PlaylistDetailDialog(playlist: testPlaylist, isBottomSheet: false),
      ));
      await tester.pumpAndSettle();

      // 验证歌单信息
      expect(find.text('浪漫婚礼精选集'), findsOneWidget);
      expect(find.text('播放全部'), findsOneWidget);
      expect(find.text('收藏到我的歌单'), findsOneWidget);

      // 点击“播放全部”
      await tester.tap(find.text('播放全部'));
      await tester.pumpAndSettle();
      expect(audioPlayerService.playlist.length, testTracks.length);

      // 点击“收藏到我的歌单”
      await tester.tap(find.text('收藏到我的歌单'));
      await tester.pumpAndSettle();
      expect(audioPlayerService.importedPlaylists.any((p) => p.title == '浪漫婚礼精选集'), isTrue);
    });
  });
}
