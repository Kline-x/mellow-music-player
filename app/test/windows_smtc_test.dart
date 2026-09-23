import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/audio/windows_smtc_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('Windows SMTC (系统媒体控制) 与原生通道测试', () {
    late WindowsSmtcService smtc;
    late List<MethodCall> nativeCalls;

    setUp(() {
      smtc = WindowsSmtcService.instance;
      nativeCalls = [];

      // 模拟 Windows 原生通道拦截器
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(WindowsSmtcService.channelName), (call) async {
        nativeCalls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(WindowsSmtcService.channelName), null);
      smtc.dispose();
    });

    test('SMTC 服务生命周期初始化与元数据同步', () async {
      SmtcButtonAction? receivedAction;
      Duration? receivedSeek;

      await smtc.init(
        onAction: (action) => receivedAction = action,
        onSeek: (pos) => receivedSeek = pos,
      );

      expect(smtc.isInitialized, isTrue);

      // 1. 同步元数据
      final testTrack = mockPresetTracks[0];
      await smtc.updateMetadata(testTrack);
      expect(smtc.lastTrack?.id, testTrack.id);
      expect(smtc.lastTrack?.title, testTrack.title);

      // 2. 同步播放状态
      await smtc.updatePlaybackState(true);
      expect(smtc.lastIsPlaying, isTrue);

      await smtc.updatePlaybackState(false);
      expect(smtc.lastIsPlaying, isFalse);

      // 3. 同步时间线进度
      const pos = Duration(seconds: 45);
      const dur = Duration(minutes: 3, seconds: 20);
      await smtc.updateTimeline(pos, dur);
      expect(smtc.lastPosition, pos);
      expect(smtc.lastDuration, dur);

      // 4. 清理
      await smtc.clear();
      expect(smtc.lastTrack, isNull);
      expect(smtc.lastIsPlaying, isFalse);
    });

    test('Windows 系统级原生事件 (onButtonPressed & onSeekRequested) 准确路由', () async {
      final receivedActions = <SmtcButtonAction>[];
      Duration? seekTarget;

      await smtc.init(
        onAction: (action) => receivedActions.add(action),
        onSeek: (pos) => seekTarget = pos,
      );

      // 模拟来自 Windows 原生宿主的消息
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(WindowsSmtcService.channelName);

      // 1. 播放/暂停/切换事件
      for (final btn in ['play', 'pause', 'toggleplay', 'next', 'previous', 'stop']) {
        final byteData = channel.codec.encodeMethodCall(MethodCall('onButtonPressed', {'button': btn}));
        await messenger.handlePlatformMessage(WindowsSmtcService.channelName, byteData, (_) {});
      }

      expect(receivedActions, [
        SmtcButtonAction.play,
        SmtcButtonAction.pause,
        SmtcButtonAction.togglePlay,
        SmtcButtonAction.next,
        SmtcButtonAction.previous,
        SmtcButtonAction.stop,
      ]);

      // 2. 进度拖拽事件
      final seekByteData = channel.codec.encodeMethodCall(const MethodCall('onSeekRequested', {'positionMs': 90000}));
      await messenger.handlePlatformMessage(WindowsSmtcService.channelName, seekByteData, (_) {});

      expect(seekTarget, const Duration(seconds: 90));
    });

    test('AudioPlayerService 与 Windows SMTC 双向状态协同闭环', () async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      // 1. 播放曲目，验证 SMTC 自动接收到当前曲目元数据与播放中状态
      final trackToPlay = mockPresetTracks[2];
      player.playTrack(trackToPlay);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(smtc.lastTrack?.id, trackToPlay.id);
      expect(smtc.lastTrack?.title, trackToPlay.title);
      expect(smtc.lastIsPlaying, isTrue);

      // 2. 暂停播放
      player.pause();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(smtc.lastIsPlaying, isFalse);

      // 3. 恢复播放
      player.play();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(smtc.lastIsPlaying, isTrue);

      // 4. Seek 拖拽
      player.seek(const Duration(seconds: 35));
      expect(smtc.lastPosition, const Duration(seconds: 35));

      // 5. 模拟来自 Windows 系统任务栏/物理多媒体键的控制请求驱动播放器
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(WindowsSmtcService.channelName);

      // 系统发来 pause 指令
      var byteData = channel.codec.encodeMethodCall(const MethodCall('onButtonPressed', {'button': 'pause'}));
      await messenger.handlePlatformMessage(WindowsSmtcService.channelName, byteData, (_) {});
      expect(player.isPlaying, isFalse);

      // 系统发来 play 指令
      byteData = channel.codec.encodeMethodCall(const MethodCall('onButtonPressed', {'button': 'play'}));
      await messenger.handlePlatformMessage(WindowsSmtcService.channelName, byteData, (_) {});
      expect(player.isPlaying, isTrue);

      // 系统发来 next 指令
      final curIndex = player.currentIndex;
      byteData = channel.codec.encodeMethodCall(const MethodCall('onButtonPressed', {'button': 'next'}));
      await messenger.handlePlatformMessage(WindowsSmtcService.channelName, byteData, (_) {});
      expect(player.currentIndex, (curIndex + 1) % player.playlist.length);

      // 6. 清空队列同时触发 SMTC clear
      player.clearQueue();
      expect(smtc.lastTrack, isNull);
      expect(smtc.lastIsPlaying, isFalse);

      player.dispose();
    });
  });
}
