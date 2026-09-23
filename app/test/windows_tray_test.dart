import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/audio/windows_tray_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('Windows 原生系统托盘与常驻后台控制测试', () {
    late WindowsTrayService tray;
    late List<MethodCall> nativeCalls;

    setUp(() {
      tray = WindowsTrayService.instance;
      nativeCalls = [];

      // 拦截托盘原生通道
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(WindowsTrayService.channelName), (call) async {
        nativeCalls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(WindowsTrayService.channelName), null);
      tray.dispose();
    });

    test('托盘基础初始化与默认状态读取', () async {
      await tray.init();

      expect(tray.isInitialized, isTrue);
      // 默认开启最小化到托盘
      expect(tray.minimizeToTray, isTrue);
      expect(StorageService.instance.getMinimizeToTray(), isTrue);
    });

    test('切换与持久化最小化到托盘偏好', () async {
      await tray.init();

      await tray.setMinimizeToTray(false);
      expect(tray.minimizeToTray, isFalse);
      expect(StorageService.instance.getMinimizeToTray(), isFalse);

      await tray.setMinimizeToTray(true);
      expect(tray.minimizeToTray, isTrue);
      expect(StorageService.instance.getMinimizeToTray(), isTrue);
    });

    test('托盘 Tooltip 悬浮提示词格式化与同步', () async {
      await tray.init();

      final track = mockPresetTracks[0];
      await tray.updateTooltip(track);

      expect(tray.lastTooltip, contains(track.title));
      expect(tray.lastTooltip, contains(track.artist));
      expect(tray.lastTooltip, contains('Mellow Music'));
    });

    test('窗口显示与隐藏指令通过通道正常分发', () async {
      await tray.init();

      await tray.showWindow();
      await tray.hideWindow();

      expect(tray.isInitialized, isTrue);
    });

    test('AudioPlayerService 切歌时自动更新托盘 Tooltip', () async {
      await tray.init();

      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final track = mockPresetTracks[1];
      player.playTrack(track);

      expect(tray.lastTooltip, contains(track.title));
      expect(tray.lastTooltip, contains(track.artist));

      player.dispose();
    });
  });
}
