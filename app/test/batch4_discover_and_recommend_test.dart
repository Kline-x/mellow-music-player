import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

void main() {
  group('批次 4 首页推荐与歌手头像单点源专项验收套件', () {
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

    testWidgets('BATCH4-DISCOVER-ARTISTS: 发现首页推荐歌手头像统一从 mockArtistsProfiles 单点源读取', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证首页底部推荐歌手卡片存在
      expect(find.text('热门入驻与关注歌手'), findsOneWidget);
      expect(find.text('巫娜'), findsOneWidget);
      expect(find.text('周杰伦'), findsOneWidget);
      expect(find.text('Beyond'), findsOneWidget);
      expect(find.text('伯远'), findsOneWidget);

      // 2. 验证巫娜头像取自 mockArtistsProfiles 专属东方典雅头像，绝非欧美金发模特 (photo-1534528741775)
      final wnProfile = getArtistProfileByName('巫娜');
      final wnAvatarFinder = find.byWidgetPredicate((w) => w is MellowAvatar && w.url == wnProfile.avatarUrl);
      expect(wnAvatarFinder, findsOneWidget);
      expect(wnProfile.avatarUrl.contains('534528741775'), isFalse);
    });

    testWidgets('BATCH4-DISCOVER-PLAYLISTS: 发现首页甄选歌单推荐点击触发整单连播', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 点击“东方禅境 · 幽篁古筝琴韵精选”歌单卡片
      final playlistCard = find.text('东方禅境 · 幽篁古筝琴韵精选');
      expect(playlistCard, findsOneWidget);
      await tester.tap(playlistCard);
      await tester.pump(const Duration(milliseconds: 100));

      // 验证播放器被唤醒且载入整张歌单（4首古琴专曲）
      expect(audioPlayerService.isPlaying, isTrue);
      expect(audioPlayerService.currentTrack?.artist, equals('巫娜'));
      expect(audioPlayerService.playlist.length, equals(mockWuNaTracks.length));

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('BATCH4-MOBILE-RECOMMEND: 移动端每日推荐二级页播放全部整单连播', (tester) async {
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
            home: MobileDailyRecommendPage(onBack: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 验证“播放全部 (6首)”按钮点击生效并载入 6 首曲目
      final playAllBtn = find.text('播放全部 (6首)');
      expect(playAllBtn, findsOneWidget);
      await tester.tap(playAllBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(audioPlayerService.isPlaying, isTrue);
      expect(audioPlayerService.playlist.length, equals(mockPresetTracks.length));
      expect(audioPlayerService.currentTrack?.title, equals(mockPresetTracks[0].title));

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
