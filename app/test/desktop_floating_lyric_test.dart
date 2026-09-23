import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/desktop/desktop_floating_lyric_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('DesktopFloatingLyricBar (桌面悬浮动效歌词小组件) 测试', () {
    testWidgets('悬浮歌词独立渲染与双行歌词随进度动态演算', (tester) async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);
      final theme = ThemeProvider();

      bool closed = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopFloatingLyricBar(
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. 验证默认第一行歌词正确显示
      final track = player.currentTrack!;
      expect(track.lyrics.isNotEmpty, isTrue);
      expect(find.text(track.lyrics[0].text), findsOneWidget);
      expect(find.text(track.lyrics[1].text), findsOneWidget);

      // 2. 模拟播放进度推进到第二句歌词时间点
      final secondLineTime = track.lyrics[1].time;
      player.seek(secondLineTime + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text(track.lyrics[1].text), findsOneWidget);

      // 3. 验证关闭回调触发
      expect(closed, isFalse);
    });

    testWidgets('悬浮歌词控制栏按钮 (播放/切歌/锁定/字号) 交互联动', (tester) async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);
      final theme = ThemeProvider();

      bool closed = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopFloatingLyricBar(
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 模拟鼠标移入悬浮歌词区域，激活微控工具栏
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(DesktopFloatingLyricBar)));
      await tester.pumpAndSettle();

      // 1. 验证播放/暂停按钮点击驱动 AudioPlayerService
      expect(player.isPlaying, isFalse);
      final playBtn = find.byTooltip('播放');
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();
      expect(player.isPlaying, isTrue);

      // 2. 验证下一曲切歌按钮
      final initialTrack = player.currentTrack!.id;
      final nextBtn = find.byTooltip('下一曲');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(player.currentTrack!.id, isNot(equals(initialTrack)));

      // 3. 验证锁定切换与落盘保存
      expect(StorageService.instance.getFloatingLyricLocked(), isFalse);
      final lockBtn = find.byTooltip('锁定歌词位置');
      expect(lockBtn, findsOneWidget);
      await tester.tap(lockBtn);
      await tester.pumpAndSettle();
      expect(StorageService.instance.getFloatingLyricLocked(), isTrue);

      // 4. 验证关闭按钮触发 onClose
      final closeBtn = find.byTooltip('关闭桌面歌词');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('DesktopScaffold 底栏桌面歌词按钮与显隐状态协同闭环', (tester) async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);
      final theme = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: const MaterialApp(
            home: DesktopScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. 初始状态下悬浮歌词未开启
      expect(find.byType(DesktopFloatingLyricBar), findsNothing);

      // 2. 点击底栏的「开启桌面歌词」按钮
      final toggleBtn = find.byTooltip('开启桌面歌词 (Ctrl+D)');
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // 3. 悬浮歌词组件已成功挂载呈现
      expect(find.byType(DesktopFloatingLyricBar), findsOneWidget);
      expect(StorageService.instance.getFloatingLyricEnabled(), isTrue);

      // 4. 再次点击底栏「关闭桌面歌词」按钮
      final closeToggleBtn = find.byTooltip('关闭桌面歌词 (Ctrl+D)');
      expect(closeToggleBtn, findsOneWidget);
      await tester.tap(closeToggleBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DesktopFloatingLyricBar), findsNothing);
      expect(StorageService.instance.getFloatingLyricEnabled(), isFalse);
    });
  });
}
