import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/common/modals.dart';

void main() {
  group('批次 2 业务数据真实化与无死区交互专项验收套件', () {
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

    testWidgets('BATCH2-TOPLIST: 四大官方巅峰榜单曲目真实独立，彻底消灭雷同假数据', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 切换至“巅峰榜单”
      final toplistNavItem = find.text('巅峰榜单');
      await tester.tap(toplistNavItem);
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证四大榜单均有其独有的特色歌曲，无完全雷同
      // 飙升榜特色歌曲：乌梅子酱
      expect(find.text('乌梅子酱'), findsOneWidget);
      // 热歌榜特色歌曲：十年
      expect(find.text('十年'), findsOneWidget);
      // 新歌榜特色歌曲：漠河舞厅
      expect(find.text('漠河舞厅'), findsOneWidget);
      // 原创榜特色歌曲：米店
      expect(find.text('米店'), findsOneWidget);

      // 2. 点击“播放全部榜单”，验证播放列表被载入全部榜单汇总曲库
      final playAllBtn = find.text('播放全部榜单');
      await tester.tap(playAllBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(audioPlayerService.isPlaying, isTrue);
      // 汇总曲库排重后歌曲数量大于等于 15 首
      expect(audioPlayerService.playlist.length, greaterThanOrEqualTo(15));

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('BATCH2-ARTIST: 歌手详情页头像与代表作真实绑定，杜绝全员同一张女性照片', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 切换至“热门歌手”
      final artistsNavItem = find.text('热门歌手');
      await tester.tap(artistsNavItem);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证四大歌手卡片存在
      expect(find.text('巫娜'), findsOneWidget);
      expect(find.text('周杰伦'), findsOneWidget);
      expect(find.text('Beyond'), findsOneWidget);
      expect(find.text('伯远'), findsOneWidget);

      // 1. 下钻进入周杰伦详情页
      await tester.tap(find.text('周杰伦'));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证周杰伦专属认证信息与专属头像
      final jayProfile = getArtistProfileByName('周杰伦');
      expect(find.text(jayProfile.bio), findsOneWidget);
      final jayAvatarFinder = find.byWidgetPredicate((w) => w is MellowAvatar && w.url == jayProfile.avatarUrl);
      expect(jayAvatarFinder, findsOneWidget);

      // 验证周杰伦专属代表作存在（晴天、花海）
      expect(find.text('晴天'), findsOneWidget);
      expect(find.text('花海'), findsOneWidget);
      // 不应包含巫娜的专属曲目
      expect(find.text('七弦清音'), findsNothing);

      // 点击“返回歌手列表”
      await tester.tap(find.text('返回歌手列表'));
      await tester.pump(const Duration(milliseconds: 300));

      // 2. 下钻进入巫娜详情页
      await tester.tap(find.text('巫娜'));
      await tester.pump(const Duration(milliseconds: 300));

      final wnProfile = getArtistProfileByName('巫娜');
      expect(find.text(wnProfile.bio), findsOneWidget);
      final wnAvatarFinder = find.byWidgetPredicate((w) => w is MellowAvatar && w.url == wnProfile.avatarUrl);
      expect(wnAvatarFinder, findsOneWidget);
      // 验证巫娜头像与周杰伦头像绝不相同
      expect(wnProfile.avatarUrl, isNot(equals(jayProfile.avatarUrl)));

      // 验证巫娜专属代表作存在
      expect(find.text('七弦清音'), findsOneWidget);
      expect(find.text('流水行云'), findsOneWidget);
      // 不应包含周杰伦的专属曲目
      expect(find.text('晴天'), findsNothing);

      // 点击播放巫娜热门代表作
      final playHitsBtn = find.text('播放热门代表作');
      await tester.tap(playHitsBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(audioPlayerService.isPlaying, isTrue);
      expect(audioPlayerService.currentTrack?.artist, equals('巫娜'));

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('BATCH2-EQ: EQ 均衡器弹窗小视口自适应，杜绝 RenderFlex 像素溢出', (tester) async {
      // 模拟移动端超窄屏幕 (360x780)
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
            ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EqualizerModal(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证标题正常显示且未抛出 RenderFlex 溢出异常
      expect(find.text('声学 10 频段均衡器 (EQ)'), findsOneWidget);
      expect(find.text('均衡器已启用'), findsOneWidget);
      expect(find.text('恢复默认 (Flat)'), findsOneWidget);

      // 2. 验证预设选择切换生效
      // 横向平移预设选择栏使后方胶囊完整呈现
      await tester.drag(find.byType(SingleChildScrollView).at(1), const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 100));
      final bassBtn = find.text('澎湃低音 (Bass Boost)');
      await tester.tap(bassBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(equalizerManager.currentPreset, equals(EqualizerPreset.bassBoost));

      // 3. 验证直通原声开关点击生效
      final toggleSwitch = find.byType(Switch);
      await tester.tap(toggleSwitch);
      await tester.pump(const Duration(milliseconds: 100));
      expect(equalizerManager.isEnabled, isFalse);
      expect(find.text('直通原声 (已旁路)'), findsOneWidget);
    });
  });
}
