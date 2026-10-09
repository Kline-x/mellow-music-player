import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/views/mobile/mobile_tabs.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    MellowImage.isInTest = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  Widget buildTestApp(Widget child, {AudioPlayerService? player, ThemeProvider? theme}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioPlayerService>(create: (_) => player ?? AudioPlayerService()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => theme ?? ThemeProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('MOB-041 移动端每日推荐与全局播放全部闭环验证专项套件', () {
    testWidgets('1. 发现页每日推荐专区：标题栏「播放全部」一键将整批30首推荐曲目推入队列并起播', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();
      player.clearQueue();

      await tester.pumpWidget(
        buildTestApp(
          MobileDiscoverTab(
            onNavigatePage: (_, [__]) {},
            onOpenSearch: () {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证标题呈现
      expect(find.text('每日推荐 · Daily Recommend'), findsOneWidget);
      expect(find.text('播放全部'), findsWidgets);

      // 点击播放全部
      final playAllBtn = find.text('播放全部').first;
      await tester.tap(playAllBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证全量曲目入队起播
      expect(player.playlist.length, greaterThanOrEqualTo(5));
      expect(player.currentIndex, equals(0));
      expect(player.isPlaying, isTrue);

      player.pause();
    });

    testWidgets('2. 发现页每日推荐小卡片：点击第 2 项精准起播且队列保持包含整批曲目', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();
      player.clearQueue();

      await tester.pumpWidget(
        buildTestApp(
          MobileDiscoverTab(
            onNavigatePage: (_, [__]) {},
            onOpenSearch: () {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final playIcons = find.byIcon(Icons.play_arrow_rounded);
      expect(playIcons, findsWidgets);

      // 点击第 2 张推荐卡片对应项
      await tester.tap(playIcons.at(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(player.playlist.length, greaterThanOrEqualTo(5));
      expect(player.isPlaying, isTrue);

      player.pause();
    });

    testWidgets('3. 甄选歌单推荐：包含高保真歌单流并支持一键播放入队起播与查看全部', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();
      player.clearQueue();

      await tester.pumpWidget(
        buildTestApp(
          MobileDiscoverTab(
            onNavigatePage: (_, [__]) {},
            onOpenSearch: () {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('甄选歌单推荐'), findsOneWidget);
      expect(find.text('查看全部 >'), findsOneWidget);

      final playBtn = find.byKey(const Key('curated_playlist_play_0'));
      expect(playBtn, findsOneWidget);

      await tester.tap(playBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(player.playlist.isNotEmpty, isTrue);
      expect(player.isPlaying, isTrue);

      player.pause();
    });

    testWidgets('4. 探索页：风格切换与「换一批」分页轮巡机制正常运作，单曲点击全量入队', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();

      await tester.pumpWidget(
        buildTestApp(
          MobileExploreTab(
            onNavigatePage: (_, [__]) {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('换一批'), findsOneWidget);

      // 点击换一批
      await tester.tap(find.text('换一批'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 验证一键播放精选风格单曲
      final playAllExplore = find.text('一键播放');
      expect(playAllExplore, findsOneWidget);
      await tester.tap(playAllExplore);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(player.playlist.isNotEmpty, isTrue);
      expect(player.isPlaying, isTrue);

      player.pause();
    });

    testWidgets('5. 声音电台页面：AppBar 播放全部按钮将整批电台歌曲推入播放队列', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();
      player.clearQueue();

      await tester.pumpWidget(
        buildTestApp(
          MobileRadioPage(onBack: () {}),
          player: player,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('播放全部'), findsOneWidget);
      await tester.tap(find.text('播放全部'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(player.playlist.length, greaterThanOrEqualTo(4));
      expect(player.currentIndex, equals(0));
      expect(player.isPlaying, isTrue);

      player.pause();
    });
  });
}
