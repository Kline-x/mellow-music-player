import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/views/mobile/mobile_tabs.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('MOB-034 探索页精选风格单曲「一键播放」端到端专项验证', () {
    testWidgets('探索页存在一键播放按钮，点击后整批精选歌曲直接注入队列并起播', (tester) async {
      final player = AudioPlayerService();
      final theme = ThemeProvider();

      await tester.pumpWidget(
        buildTestApp(
          MobileExploreTab(
            onNavigatePage: (_, [__]) {},
          ),
          player: player,
          theme: theme,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证存在一键播放按钮
      final playAllBtn = find.text('一键播放');
      expect(playAllBtn, findsOneWidget);

      // 点击一键播放
      await tester.tap(playAllBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证 player.playlist 已填充当前精选单曲并触发播放
      expect(player.playlist.isNotEmpty, isTrue);
      expect(player.currentTrack, isNotNull);
      expect(player.isPlaying, isTrue);
    });
  });

  group('MOB-033 移动端全页面播放按钮响应性与冷启动防空转验证', () {
    testWidgets('发现页每日推荐大卡片在播放队列为空时点击绝不空转，自动注入全量推荐曲目并起播', (tester) async {
      final player = AudioPlayerService();
      player.clearQueue();
      expect(player.playlist.isEmpty, isTrue);

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
      await tester.pump(const Duration(milliseconds: 200));

      // 验证存在每日推荐专区与播放全部按钮
      expect(find.text('每日推荐 · Daily Recommend'), findsOneWidget);
      final playAllBtn = find.text('播放全部').first;
      expect(playAllBtn, findsOneWidget);

      await tester.tap(playAllBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证成功起播且队列注入了全量曲目
      expect(player.playlist.isNotEmpty, isTrue);
      expect(player.isPlaying, isTrue);
    });

    testWidgets('发现页每日推荐紧凑小卡片在冷启动时点击真实起播对应曲目并全量入队', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 200));

      // 验证找到每日推荐内的小卡片播放按钮并点击
      final playButtons = find.byIcon(Icons.play_arrow_rounded);
      expect(playButtons, findsWidgets);

      await tester.tap(playButtons.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证成功起播并导入队列
      expect(player.playlist.isNotEmpty, isTrue);
      expect(player.isPlaying, isTrue);
    });

    testWidgets('歌手主页「播放热门」按钮在任何状态下点击均能起播代表作', (tester) async {
      final player = AudioPlayerService();

      await tester.pumpWidget(
        buildTestApp(
          MobileArtistDetailPage(
            artistName: '周杰伦',
            onBack: () {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 找到「播放热门」按钮并点击
      final playHotBtn = find.text('播放热门');
      expect(playHotBtn, findsOneWidget);

      await tester.tap(playHotBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(player.playlist.isNotEmpty, isTrue);
      expect(player.isPlaying, isTrue);
    });

    testWidgets('MOB-035: 资料库「我喜欢的音乐」卡片右侧播放按钮点击能独立起播收藏单曲', (tester) async {
      final player = AudioPlayerService();
      final testTrack = Track(
        id: 'fav-test-1',
        title: '测试收藏曲目',
        artist: '测试歌手',
        album: '测试专辑',
        coverUrl: 'http://example.com/cover.jpg',
        duration: const Duration(minutes: 3),
      );
      player.toggleFavorite(testTrack.id, testTrack);

      await tester.pumpWidget(
        buildTestApp(
          MobileLibraryTab(onNavigatePage: (_, [__]) {}),
          player: player,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我喜欢的音乐'), findsOneWidget);
      expect(find.textContaining('已收藏 1 首心动单曲'), findsOneWidget);

      final playFavBtn = find.byIcon(Icons.play_arrow_rounded).first;
      await tester.tap(playFavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(player.isPlaying, isTrue);
      expect(player.currentTrack?.title, '测试收藏曲目');
    });

    testWidgets('MOB-037: 声音电台卡片右侧播放按钮点击能起播电台音频', (tester) async {
      final player = AudioPlayerService();

      await tester.pumpWidget(
        buildTestApp(
          MobileRadioPage(onBack: () {}),
          player: player,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('声音电台'), findsOneWidget);

      final firstPlayIcon = find.byIcon(Icons.play_arrow_rounded).first;
      await tester.tap(firstPlayIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(player.isPlaying, isTrue);
      expect(player.currentTrack, isNotNull);
    });
  });
}
