import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/tokens.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/design_system/soft_card.dart';
import 'package:mellow_music/design_system/soft_button.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/navigation/mobile_scaffold.dart';

Widget createTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AudioPlayerService()),
      ChangeNotifierProvider(create: (_) => EqualizerManager()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  setUpAll(() {
    MellowImage.isInTest = true;
  });

  group('1. ThemeProvider 与 Modern Soft UI 状态测试', () {
    test('主题切换与 5 大声学强调色测试', () {
      final theme = ThemeProvider();
      expect(theme.isDarkMode, false);
      expect(theme.accentType, AccentColorType.blue);

      theme.toggleTheme();
      expect(theme.isDarkMode, true);

      theme.setAccentType(AccentColorType.pink);
      expect(theme.accentType, AccentColorType.pink);
      expect(theme.accentColor, AccentColorType.pink.darkColor);

      theme.setGlowIntensity(0.85);
      expect(theme.glowIntensity, 0.85);
    });

    testWidgets('SoftCard 与 SoftButton 基础渲染与交互测试', (tester) async {
      bool buttonClicked = false;
      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: SoftCard(
              child: SoftButton(
                label: '播放音乐',
                icon: Icons.play_arrow_rounded,
                onTap: () => buttonClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('播放音乐'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.text('播放音乐'));
      await tester.pumpAndSettle();
      expect(buttonClicked, true);
    });
  });

  group('2. AudioPlayerService 播放状态机测试', () {
    test('曲目切歌、循环模式与收藏逻辑', () {
      final player = AudioPlayerService();
      expect(player.playlist.isNotEmpty, true);
      expect(player.isPlaying, false);

      // 播放 / 暂停
      player.play();
      expect(player.isPlaying, true);

      player.pause();
      expect(player.isPlaying, false);

      // 切歌 Next
      final firstId = player.currentTrack?.id;
      player.next();
      expect(player.currentTrack?.id != firstId, true);

      // 模式循环
      expect(player.playbackMode, PlaybackMode.sequence);
      player.cyclePlaybackMode();
      expect(player.playbackMode, PlaybackMode.singleLoop);
      player.cyclePlaybackMode();
      expect(player.playbackMode, PlaybackMode.shuffle);

      // 收藏切换
      final trackId = player.currentTrack!.id;
      final initialFav = player.isFavorite(trackId);
      player.toggleFavorite(trackId);
      expect(player.isFavorite(trackId), !initialFav);
    });

    test('睡眠定时器倒计时启动与取消', () {
      final player = AudioPlayerService();
      expect(player.sleepTimerMinutes, null);

      player.startSleepTimer(30);
      expect(player.sleepTimerMinutes, 30);
      expect(player.sleepTimerRemainingSeconds, 1800);

      player.cancelSleepTimer();
      expect(player.sleepTimerMinutes, null);
      expect(player.sleepTimerRemainingSeconds, 0);
    });
  });

  group('3. EqualizerManager 声学 10 频段 EQ 测试', () {
    test('预设套用与 firequalizer 滤镜参数生成', () {
      final eq = EqualizerManager();
      expect(eq.currentPreset, EqualizerPreset.flat);
      expect(eq.bandGains.every((g) => g == 0.0), true);

      eq.applyPreset(EqualizerPreset.bassBoost);
      expect(eq.currentPreset, EqualizerPreset.bassBoost);
      expect(eq.bandGains[0], 7.0);

      final filterStr = eq.toLibmpvFilterString();
      expect(filterStr.contains('firequalizer='), true);
      expect(filterStr.contains('gain_interpolate(31,7.0)'), true);
    });
  });

  group('4. 桌面端工作台 (DesktopScaffold) 挂载与导航测试', () {
    testWidgets('桌面端 12 视图导航切换测试', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const DesktopScaffold()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证标题栏与侧边栏
      expect(find.text('Mellow Music · 润音'), findsOneWidget);
      expect(find.text('发现音乐'), findsOneWidget);
      expect(find.text('歌单广场'), findsOneWidget);
      expect(find.text('巅峰榜单'), findsOneWidget);

      // 点击切换到歌单广场
      await tester.tap(find.text('歌单广场'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('发现属于你的音乐磁场'), findsOneWidget);

      // 点击切换到巅峰榜单
      await tester.tap(find.text('巅峰榜单'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('官方巅峰排行榜'), findsOneWidget);

      // 点击切换到我喜欢的音乐
      await tester.tap(find.text('我喜欢的音乐'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('一键播放全部'), findsOneWidget);
    });
  });

  group('5. 移动端应用 (MobileScaffold) 原生 4-Tab 挂载与二级页下钻测试', () {
    testWidgets('移动端 4-Tab 切换与每日推荐二级页下钻', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const MobileScaffold()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证 4-Tab 底部栏存在
      expect(find.text('发现'), findsOneWidget);
      expect(find.text('探索'), findsOneWidget);
      expect(find.text('资料库'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);

      // 验证 5 大金刚区入口存在
      expect(find.text('每日推荐'), findsOneWidget);
      expect(find.text('私人漫游'), findsOneWidget);

      // 点击每日推荐金刚区进入二级页
      await tester.tap(find.text('每日推荐'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证进入每日推荐二级页
      expect(find.text('专属声学日推 · 每日 06:00 更新'), findsOneWidget);

      // 点击返回
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 回到发现主页
      expect(find.text('专属雷达 · Daily Mixes'), findsOneWidget);
    });
  });
}
