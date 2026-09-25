import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/window/desktop_floating_lyric_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/desktop/desktop_floating_lyric_bar.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    await DesktopFloatingLyricService.instance.init();
  });

  group('1. DesktopFloatingLyricService 系统级服务与原生通道测试', () {
    late List<MethodCall> nativeCalls;

    setUp(() {
      nativeCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(DesktopFloatingLyricService.channelName), (call) async {
        nativeCalls.add(call);
        if (call.method == 'isAlwaysOnTop') return false;
        if (call.method == 'isClickThrough') return false;
        return true;
      });
      DesktopFloatingLyricService.instance.setMockMethodChannel(
        const MethodChannel(DesktopFloatingLyricService.channelName),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(DesktopFloatingLyricService.channelName), null);
    });

    test('服务初始化与本地持久化偏好恢复', () async {
      final service = DesktopFloatingLyricService.instance;
      expect(service.isInitialized, isTrue);
      expect(service.isEnabled, isFalse);
      expect(service.isLocked, isFalse);
      expect(service.isAlwaysOnTop, isFalse);
      expect(service.fontSizeLevel, equals('normal'));

      // 修改配置
      await service.setEnabled(true);
      await service.setLocked(true);
      await service.setAlwaysOnTop(true);
      await service.setFontSizeLevel('large');
      await service.savePosition(const Offset(350, 180));

      expect(StorageService.instance.getFloatingLyricEnabled(), isTrue);
      expect(StorageService.instance.getFloatingLyricLocked(), isTrue);
      expect(StorageService.instance.getFloatingLyricAlwaysOnTop(), isTrue);
      expect(StorageService.instance.getFloatingLyricFontSize(), equals('large'));
      expect(StorageService.instance.getFloatingLyricPosX(), equals(350.0));
      expect(StorageService.instance.getFloatingLyricPosY(), equals(180.0));

      // 重新 init 模拟冷启动
      await service.init();
      expect(service.isEnabled, isTrue);
      expect(service.isLocked, isTrue);
      expect(service.isAlwaysOnTop, isTrue);
      expect(service.fontSizeLevel, equals('large'));
      expect(service.position, equals(const Offset(350, 180)));
    });

    test('字号档位平滑循环切换 cycleFontSize', () async {
      final service = DesktopFloatingLyricService.instance;
      await service.setFontSizeLevel('normal');

      await service.cycleFontSize();
      expect(service.fontSizeLevel, equals('large'));

      await service.cycleFontSize();
      expect(service.fontSizeLevel, equals('xlarge'));

      await service.cycleFontSize();
      expect(service.fontSizeLevel, equals('normal'));
    });

    test('接收来自系统托盘的 toggleFloatingLyric 原生回调', () async {
      final service = DesktopFloatingLyricService.instance;
      await service.setEnabled(false);

      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(DesktopFloatingLyricService.channelName);
      final toggleByteData = channel.codec.encodeMethodCall(const MethodCall('toggleFloatingLyric'));

      await messenger.handlePlatformMessage(DesktopFloatingLyricService.channelName, toggleByteData, (_) {});
      expect(service.isEnabled, isTrue);

      await messenger.handlePlatformMessage(DesktopFloatingLyricService.channelName, toggleByteData, (_) {});
      expect(service.isEnabled, isFalse);
    });

    test('接收来自原生层的 onAlwaysOnTopChanged 状态广播', () async {
      final service = DesktopFloatingLyricService.instance;
      await service.setAlwaysOnTop(false);

      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(DesktopFloatingLyricService.channelName);
      final onTopByteData = channel.codec.encodeMethodCall(
        const MethodCall('onAlwaysOnTopChanged', {'alwaysOnTop': true}),
      );

      await messenger.handlePlatformMessage(DesktopFloatingLyricService.channelName, onTopByteData, (_) {});
      expect(service.isAlwaysOnTop, isTrue);
      expect(StorageService.instance.getFloatingLyricAlwaysOnTop(), isTrue);
    });
  });

  group('2. DesktopFloatingLyricBar (桌面悬浮动效歌词小组件) UI 与交互测试', () {
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

      // 3. 验证关闭回调未被触发
      expect(closed, isFalse);
    });

    testWidgets('悬浮歌词控制栏按钮 (播放/切歌/置顶/锁定/字号) 交互联动', (tester) async {
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
      await gesture.moveTo(tester.getCenter(find.byType(BackdropFilter)));
      await tester.pump(const Duration(milliseconds: 200));

      // 1. 验证播放/暂停按钮点击驱动 AudioPlayerService
      expect(player.isPlaying, isFalse);
      final playBtn = find.byTooltip('播放');
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(player.isPlaying, isTrue);

      // 2. 验证下一曲切歌按钮
      final initialTrack = player.currentTrack!.id;
      final nextBtn = find.byTooltip('下一曲');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(player.currentTrack!.id, isNot(equals(initialTrack)));

      // 3. 验证窗口始终置顶按键
      final pinBtn = find.byTooltip('窗口始终置顶');
      expect(pinBtn, findsOneWidget);
      await tester.tap(pinBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(DesktopFloatingLyricService.instance.isAlwaysOnTop, isTrue);

      // 4. 验证锁定切换与落盘保存
      expect(StorageService.instance.getFloatingLyricLocked() ?? false, isFalse);
      final lockBtn = find.byTooltip('锁定歌词位置');
      expect(lockBtn, findsOneWidget);
      await tester.tap(lockBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(StorageService.instance.getFloatingLyricLocked(), isTrue);

      // 解锁恢复常规工具栏
      final unlockBtn = find.byTooltip('已锁定歌词，点击解锁');
      expect(unlockBtn, findsOneWidget);
      await tester.tap(unlockBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(StorageService.instance.getFloatingLyricLocked(), isFalse);

      // 5. 验证关闭按钮触发 onClose
      final closeBtn = find.byTooltip('关闭桌面歌词');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(closed, isTrue);
    });
  });

  group('3. DesktopSettingsView 桌面歌词与置顶穿透配置项测试', () {
    testWidgets('设置中心展示桌面悬浮歌词与 Win32 原生置顶穿透配置', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final theme = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSettingsView(onNavigate: (page, [extra]) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证标题与徽章
      expect(find.text('桌面悬浮歌词与置顶穿透'), findsOneWidget);
      expect(find.text(Platform.isWindows ? 'Win32 原生置顶 / 穿透' : '桌面动效视窗'), findsOneWidget);
      expect(find.text('开启桌面悬浮动效歌词'), findsOneWidget);
      expect(find.text('主窗口始终置顶 (Always on Top)'), findsOneWidget);
      expect(find.text('锁定歌词与鼠标点击穿透 (Click-Through)'), findsOneWidget);
      expect(find.text('歌词字号档位'), findsOneWidget);

      // 点击放大字号
      final largeChip = find.text('放大');
      expect(largeChip, findsOneWidget);
      await tester.tap(largeChip);
      await tester.pumpAndSettle();
      expect(DesktopFloatingLyricService.instance.fontSizeLevel, equals('large'));

      // 点击超大字号
      final xlargeChip = find.text('超大');
      expect(xlargeChip, findsOneWidget);
      await tester.tap(xlargeChip);
      await tester.pumpAndSettle();
      expect(DesktopFloatingLyricService.instance.fontSizeLevel, equals('xlarge'));
    });
  });

  group('4. DesktopScaffold 底栏桌面歌词按钮与快捷键协同闭环', () {
    testWidgets('DesktopScaffold 底栏桌面歌词按钮与显隐状态协同闭环', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      await tester.pump(const Duration(milliseconds: 200));

      // 1. 初始状态下悬浮歌词未开启
      expect(find.byType(DesktopFloatingLyricBar), findsNothing);

      // 2. 点击底栏的「开启桌面歌词」按钮
      final toggleBtn = find.byTooltip('开启桌面歌词 (Ctrl+D)');
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // 3. 悬浮歌词组件已成功挂载呈现
      expect(find.byType(DesktopFloatingLyricBar), findsOneWidget);
      expect(StorageService.instance.getFloatingLyricEnabled(), isTrue);
      expect(DesktopFloatingLyricService.instance.isEnabled, isTrue);

      // 4. 再次点击底栏「关闭桌面歌词」按钮
      final closeToggleBtn = find.byTooltip('关闭桌面歌词 (Ctrl+D)');
      expect(closeToggleBtn, findsOneWidget);
      await tester.tap(closeToggleBtn);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DesktopFloatingLyricBar), findsNothing);
      expect(StorageService.instance.getFloatingLyricEnabled(), isFalse);
      expect(DesktopFloatingLyricService.instance.isEnabled, isFalse);
    });
  });
}
