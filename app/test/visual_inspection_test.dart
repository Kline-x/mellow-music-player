import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';

void main() {
  setUpAll(() {
    MellowImage.isInTest = true;
  });

  testWidgets('批量捕获桌面端所有关键页面的高保真渲染帧', (tester) async {
    final repaintKey = GlobalKey();
    final themeProvider = ThemeProvider();
    final audioService = AudioPlayerService();
    final equalizerManager = EqualizerManager();

    // 注入模拟音轨以展示播放状态
    final mockTrack = Track(
      id: 'mock_1',
      title: '青花瓷 · 经典中国风',
      artist: '周杰伦',
      album: '我很忙',
      duration: const Duration(seconds: 239),
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
      source: 'lx_aggregate',
    );
    audioService.playTrack(mockTrack);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
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
              brightness: Brightness.light,
              scaffoldBackgroundColor: themeProvider.canvasColor,
            ),
            home: const DesktopScaffold(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    Future<void> captureFrame(String filename) async {
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();
        final envDir = Platform.environment['VISUAL_INSPECT_DIR'];
        final targetDir = envDir != null && envDir.isNotEmpty
            ? Directory(envDir)
            : Directory('${Directory.systemTemp.path}/mellow_visual_inspect');
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }
        File('${targetDir.path}/$filename').writeAsBytesSync(bytes);
      });
    }

    // 1. 发现音乐 (Discover)
    await captureFrame('inspect_01_discover.png');

    // 2. 点击全网搜索 (Search)
    await tester.tap(find.text('全网搜索'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_02_search.png');

    // 3. 点击歌单广场 (Playlists)
    await tester.tap(find.text('歌单广场'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_03_playlists.png');

    // 4. 点击巅峰榜单 (Toplist)
    await tester.tap(find.text('巅峰榜单'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_04_toplist.png');

    // 5. 点击热门歌手 (Artists)
    await tester.tap(find.text('热门歌手'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_05_artists.png');

    // 6. 点击我喜欢的音乐 (Favorites)
    await tester.tap(find.text('我喜欢的音乐'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_06_favorites.png');

    // 7. 点击 LX 音源管理 (Sources)
    await tester.tap(find.text('LX 音源管理'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_07_sources.png');

    // 8. 滚动侧栏并点击个性化设置 (Settings)
    await tester.scrollUntilVisible(find.text('个性化设置'), 50.0, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('个性化设置'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_08_settings.png');

    // 9. 展开巨幕全屏歌词 (Lyrics)
    await tester.tap(find.byTooltip('展开巨幕全屏歌词'));
    await tester.pump(const Duration(milliseconds: 300));
    await captureFrame('inspect_09_fullscreen_lyrics.png');

    // 清理
    audioService.pause();
    audioService.dispose();
  });
}
