import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/design_system/mellow_logo.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/audio/windows_tray_service.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('Logo 视觉与品牌组件测试', () {
    testWidgets('MellowBrandLogo 组件渲染并具有指定尺寸与微光', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MellowBrandLogo(
                size: 48,
                borderRadius: 12,
                showGlow: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MellowBrandLogo), findsOneWidget);
      final size = tester.getSize(find.byType(MellowBrandLogo));
      expect(size.width, equals(48.0));
      expect(size.height, equals(48.0));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(MellowBrandLogo),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, equals(1));
    });
  });

  group('跨平台桌面托盘 (DesktopTrayService) 与窗口控制测试', () {
    late DesktopTrayService tray;
    late List<MethodCall> nativeTrayCalls;
    late List<MethodCall> nativeWindowCalls;

    setUp(() {
      tray = DesktopTrayService.instance;
      nativeTrayCalls = [];
      nativeWindowCalls = [];

      tray.setMockChannels(supported: true);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(DesktopTrayService.trayChannelName), (call) async {
        nativeTrayCalls.add(call);
        return true;
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(DesktopTrayService.windowChannelName), (call) async {
        nativeWindowCalls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(DesktopTrayService.trayChannelName), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(DesktopTrayService.windowChannelName), null);
      tray.dispose();
    });

    test('初始化托盘并下发初始配置至原生层', () async {
      await tray.init();
      expect(tray.isInitialized, isTrue);
      expect(tray.minimizeToTray, isTrue);

      final initCall = nativeTrayCalls.firstWhere((c) => c.method == 'init');
      expect(initCall.arguments['minimizeToTray'], isTrue);
      expect(initCall.arguments['defaultTooltip'], contains('Mellow Music'));
    });

    test('窗口最小化与隐藏到托盘方法调用通道验证', () async {
      await tray.init();

      await tray.hideWindow();
      expect(nativeTrayCalls.any((c) => c.method == 'hideWindow'), isTrue);

      await tray.showWindow();
      expect(nativeTrayCalls.any((c) => c.method == 'showWindow'), isTrue);

      await tray.minimizeWindow();
      expect(nativeWindowCalls.any((c) => c.method == 'minimize'), isTrue);
    });

    test('播放切歌时实时格式化并同步托盘 Tooltip', () async {
      await tray.init();

      final track = mockPresetTracks[0];
      await tray.updateTooltip(track);

      expect(tray.lastTooltip, contains(track.title));
      expect(tray.lastTooltip, contains(track.artist));
      expect(tray.lastTooltip, contains('Mellow Music'));
      expect(nativeTrayCalls.any((c) => c.method == 'updateTrayTooltip'), isTrue);
    });
  });

  group('桌面顶栏组件与交互集成测试', () {
    testWidgets('桌面顶栏成功渲染 MellowBrandLogo 且已移除冗余重复按钮', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService(backend: InMemoryAudioPlayerBackend());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: const MaterialApp(
            home: DesktopScaffold(),
          ),
        ),
      );

      await tester.pump();

      // 验证全新品牌 Logo 呈现在顶栏
      expect(find.byType(MellowBrandLogo), findsOneWidget);

      // 验证右上角重复按钮已精简移除（最小化到托盘、日夜切换、设置等重复入口不再出现在顶栏）
      expect(find.byTooltip('最小化到托盘'), findsNothing);
      expect(find.byTooltip('设置'), findsNothing);

      audioService.dispose();
    });
  });
}
