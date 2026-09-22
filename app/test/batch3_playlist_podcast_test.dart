import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

void main() {
  group('批次 3 歌单广场与播客电台真实化专项验收套件', () {
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

    testWidgets('BATCH3-PLAYLIST-SQUARE: 歌单广场分类标签联动筛选与整单播放闭环', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 切换至“歌单广场”
      final playlistSquareNav = find.text('歌单广场');
      await tester.tap(playlistSquareNav);
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证默认展示精选推荐歌单（包含华语经典流行金曲堂、不朽摇滚等）
      expect(find.text('歌单广场'), findsWidgets);
      expect(find.text('华语经典流行金曲堂'), findsOneWidget);
      expect(find.text('不朽摇滚 · 岁月沉思录'), findsOneWidget);

      // 2. 点击分类标签“古风雅乐”，验证列表筛选联动生效
      final guFengTag = find.text('古风雅乐');
      await tester.tap(guFengTag);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证展示古风歌单，不展示摇滚歌单
      expect(find.text('空山新雨 · 禅意清音集'), findsOneWidget);
      expect(find.text('不朽摇滚 · 岁月沉思录'), findsNothing);

      // 3. 点击该歌单卡片，验证整单被载入播放队列并触发播放
      await tester.tap(find.text('空山新雨 · 禅意清音集'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(audioPlayerService.isPlaying, isTrue);
      expect(audioPlayerService.currentTrack?.title, equals('云水禅心'));
      // 队列包含该歌单全部曲目（3首及以上）
      expect(audioPlayerService.playlist.length, greaterThanOrEqualTo(3));

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('BATCH3-PODCAST: 声音电台专区点击点播专属电台音频节目与真实解说歌词', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 切换至“声音电台”
      final podcastNav = find.text('声音电台');
      await tester.tap(podcastNav);
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证 4 大电台节目存在
      expect(find.text('深夜治愈故事馆'), findsOneWidget);
      expect(find.text('助眠白噪音与雨声'), findsOneWidget);
      expect(find.text('音乐背后的人文故事'), findsOneWidget);
      expect(find.text('科技前沿早知道'), findsOneWidget);

      // 2. 点击“助眠白噪音与雨声”，验证播放的是专属自然白噪音节目
      await tester.tap(find.text('助眠白噪音与雨声'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(audioPlayerService.isPlaying, isTrue);
      expect(audioPlayerService.currentTrack?.title, equals('松针夜雨 · 深林空溪'));
      expect(audioPlayerService.currentTrack?.artist, equals('自然声学实验室'));
      // 验证歌词为声学环境说明，而非流行歌曲歌词
      expect(audioPlayerService.currentTrack?.lyrics.any((l) => l.text.contains('粉红噪声')), isTrue);

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('BATCH3-HONEST-TEXT: 我喜欢的音乐诚实展示本地安全持久化存储，无虚假云端宣传', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 切换至“我喜欢的音乐”
      final favNav = find.text('我喜欢的音乐');
      await tester.tap(favNav);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证诚实标注本地持久化存储
      expect(find.textContaining('本地安全持久化存储'), findsOneWidget);
      // 绝不包含“实时云端同步”虚假宣传
      expect(find.textContaining('实时云端同步'), findsNothing);
    });

    testWidgets('BATCH3-MOBILE-RADIO: 移动端声音电台二级页真实音频点播验证', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
            ChangeNotifierProvider<AudioPlayerService>.value(value: audioPlayerService),
          ],
          child: MaterialApp(
            home: MobileRadioPage(onBack: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 验证移动端显示真实电台节目与听众数
      expect(find.text('深夜治愈故事馆'), findsOneWidget);
      expect(find.text('24.8万在听'), findsOneWidget);

      // 点击播放深夜治愈故事馆
      await tester.tap(find.text('深夜治愈故事馆'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(audioPlayerService.isPlaying, isTrue);
      expect(audioPlayerService.currentTrack?.title, equals('伴月入眠 · 晚安夜读'));

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
