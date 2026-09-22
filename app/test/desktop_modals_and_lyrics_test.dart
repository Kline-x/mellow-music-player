import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/desktop/fullscreen_lyrics_view.dart';

void main() {
  group('PC 桌面端核心交互弹窗与巨幕全屏歌词专项验收套件', () {
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

    testWidgets('MODAL-01: 10 频段专业声学 EQ 均衡器唤起与预设切换', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 点击底栏右侧 EQ 按钮
      final eqButton = find.byTooltip('10 频段专业声学 EQ');
      expect(eqButton, findsOneWidget);
      await tester.tap(eqButton);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证 EQ 弹窗渲染
      expect(find.text('声学 10 频段硬件均衡器 (DSP EQ)'), findsOneWidget);

      // 点击“澎湃低音 (Bass Boost)”预设
      final bassPreset = find.text('澎湃低音 (Bass Boost)');
      if (bassPreset.evaluate().isNotEmpty) {
        await tester.tap(bassPreset.first);
        await tester.pump(const Duration(milliseconds: 100));
        expect(equalizerManager.currentPreset, EqualizerPreset.bassBoost);
      }

      // 关闭弹窗
      final closeButton = find.byIcon(Icons.close_rounded);
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('MODAL-02: 睡眠定时器沙漏弹窗快捷设置与状态响应', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 点击底栏右侧沙漏按钮
      final sleepTimerBtn = find.byTooltip('设置睡眠定时器');
      expect(sleepTimerBtn, findsOneWidget);
      await tester.tap(sleepTimerBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证睡眠定时器弹窗渲染
      expect(find.text('睡眠定时器'), findsOneWidget);
      expect(find.text('30 分钟'), findsOneWidget);

      // 点击 30 分钟选项
      await tester.tap(find.text('30 分钟'));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证定时器已启动 (剩余秒数约 1800 秒)
      expect(audioPlayerService.sleepTimerMinutes, 30);
      expect(audioPlayerService.sleepTimerRemainingSeconds, inInclusiveRange(1790, 1800));

      // 清除定时器
      audioPlayerService.cancelSleepTimer();
      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('LYRICS-01: 巨幕全屏歌词页面展开与平滑返回工作台', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 点击展开巨幕全屏歌词
      final lyricsBtn = find.byTooltip('展开巨幕全屏歌词');
      expect(lyricsBtn, findsOneWidget);
      await tester.tap(lyricsBtn);
      await tester.pump(const Duration(milliseconds: 400));

      // 验证全屏歌词挂载
      expect(find.byType(DesktopFullscreenLyricsView), findsOneWidget);

      // 点击右上角退出全屏按钮
      final closeLyricsBtn = find.byIcon(Icons.fullscreen_exit_rounded);
      expect(closeLyricsBtn, findsOneWidget);
      await tester.tap(closeLyricsBtn);
      await tester.pump(const Duration(milliseconds: 400));

      // 验证已回到主桌面视图
      expect(find.byType(DesktopFullscreenLyricsView), findsNothing);

      audioPlayerService.pause();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
