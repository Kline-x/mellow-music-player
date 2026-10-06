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
import 'package:mellow_music/views/mobile/mobile_scenario_page.dart';

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
    testWidgets('发现页雷达推荐大卡片在播放队列为空时点击绝不空转，自动注入曲目并起播', (tester) async {
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

      // 点击「落日微风 · 精选推荐」大卡片
      final largeCard = find.text('落日微风 · 精选推荐');
      expect(largeCard, findsOneWidget);
      await tester.tap(largeCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证成功起播且队列不再为空
      expect(player.playlist.isNotEmpty, isTrue);
      expect(player.isPlaying, isTrue);
    });

    testWidgets('发现页雷达紧凑小卡片在冷启动时点击真实起播对应曲目', (tester) async {
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

      // 点击「慢冷治愈」卡片
      final miniCard = find.text('慢冷治愈');
      expect(miniCard, findsOneWidget);
      await tester.tap(miniCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证成功起播
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
  });
}
