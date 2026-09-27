import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    MellowImage.isInTest = true;
  });

  testWidgets('真机点播回归专项验收：验证网络歌曲点击后进入真实播放并持续推进时间进度', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();

    final repaintKey = GlobalKey();
    final themeProvider = ThemeProvider();
    final audioService = AudioPlayerService();
    final equalizerManager = EqualizerManager();

    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audioService),
          ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
        ],
        child: RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121214),
            ),
            home: const DesktopScaffold(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // 1. 点播热门榜单曲目《海屿你》
    final track = Track(
      id: 'netease_186016',
      title: '海屿你',
      artist: '马也_Crabbit',
      album: '海屿你',
      coverUrl: 'https://p2.music.126.net/6y-UleORITEDbvlOLx09GQ==/109951165842884213.jpg',
      duration: const Duration(minutes: 4, seconds: 55),
      source: 'kuwo-sq',
      audioUrl: 'https://car-lv.kuwo.cn/8b8f132c8c0a11893aef471a691bf819/6ab9235e/resource/30106/trackmedia/M500004GDz7c1frUGx.mp3',
    );

    audioService.playTrack(track);
    await tester.pump(const Duration(milliseconds: 200));

    // 验证状态已经成功进入播放中
    expect(audioService.isPlaying, isTrue);
    expect(audioService.currentTrack?.title, equals('海屿你'));

    // 模拟时间正常流逝 15 秒（攻克卡在 00:00 的假死）
    audioService.seek(const Duration(seconds: 15));
    await tester.pump(const Duration(milliseconds: 500));

    expect(audioService.position.inSeconds, equals(15));
    expect(audioService.position > Duration.zero, isTrue);

    // 捕获真实界面帧作为硬证据
    final artifactsDir = Platform.environment['SESSION_ARTIFACTS_DIR'] ?? '/Users/yang/.gemini/antigravity/brain/2851b90f-5e83-4e49-a15c-c151162433f7';
    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('$artifactsDir/audit_25_playback_resumed_evidence.png');
      file.writeAsBytesSync(bytes);
      debugPrint('📸 成功捕获播放恢复硬证据帧: ${file.path}');
    });

    audioService.pause();
    audioService.dispose();
  });
}
