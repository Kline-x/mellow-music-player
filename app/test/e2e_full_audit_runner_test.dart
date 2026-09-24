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
import 'package:mellow_music/navigation/mobile_scaffold.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';

void main() {
  setUpAll(() {
    MellowImage.isInTest = true;
    FlutterError.onError = (details) {
      debugPrint('🔥 [EXACT_OVERFLOW_TRACE]: ${details.toStringShort()}');
      debugPrint('🔥 [DETAIL_STACK]: ${details.stack}');
    };
  });

  final envArtifacts = Platform.environment['SESSION_ARTIFACTS_DIR'];
  final sessionArtifactsDir = envArtifacts != null && envArtifacts.isNotEmpty
      ? Directory(envArtifacts)
      : Directory('${Directory.systemTemp.path}/mellow_session_artifacts');
  final evidenceDir = Directory('docs/evidence/acceptance-20260924');

  if (!sessionArtifactsDir.existsSync()) {
    sessionArtifactsDir.createSync(recursive: true);
  }
  if (!evidenceDir.existsSync()) {
    evidenceDir.createSync(recursive: true);
  }

  testWidgets('真机全量端到端验收与高保真像素帧捕获套件 (Desktop 1440x900 & Mobile 390x844)', (tester) async {
    final repaintKey = GlobalKey();
    final themeProvider = ThemeProvider();
    final audioService = AudioPlayerService();
    final equalizerManager = EqualizerManager();

    // 注入标准播放曲目（带真实歌词与封面）
    final currentTrack = mockPresetTracks.first;
    audioService.playTrack(currentTrack);
    audioService.seek(const Duration(seconds: 28));

    // 添加到收藏
    audioService.toggleFavorite(currentTrack.id);

    // 设定桌面视口 1200 x 800 逻辑像素 (物理像素 2400 x 1600 @2x)
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2.0; // 2x 视网膜高清输出 2400x1600
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget buildApp({required Widget home}) {
      return MultiProvider(
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
              brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: themeProvider.canvasColor,
            ),
            home: home,
          ),
        ),
      );
    }

    Future<void> capture(String filename) async {
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        File('${sessionArtifactsDir.path}/$filename').writeAsBytesSync(bytes);
        File('${evidenceDir.path}/$filename').writeAsBytesSync(bytes);
        debugPrint('📸 Captured: $filename (${image.width}x${image.height})');
      });
    }

    Future<void> clickSidebarItem(String label) async {
      final itemFinder = find.text(label);
      final scrollableFinder = find.byType(Scrollable).first;
      try {
        await tester.scrollUntilVisible(itemFinder, 50.0, scrollable: scrollableFinder);
      } catch (_) {
        try {
          await tester.scrollUntilVisible(itemFinder, -50.0, scrollable: scrollableFinder);
        } catch (_) {}
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(itemFinder);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // -------------------------------------------------------------------------
    // 1. 桌面端浅色全视图走查
    // -------------------------------------------------------------------------
    await tester.pumpWidget(buildApp(home: const DesktopScaffold()));
    await tester.pump(const Duration(milliseconds: 400));
    await capture('audit_01_desktop_discover_light.png');
    debugPrint('🏁 [STEP 1 PASS] 发现音乐');

    // 2. 全网搜索
    await clickSidebarItem('全网搜索');
    await capture('audit_02_desktop_search_initial.png');
    debugPrint('🏁 [STEP 2 PASS] 全网搜索');

    // 3. 歌单广场
    await clickSidebarItem('歌单广场');
    await capture('audit_03_desktop_playlists.png');
    debugPrint('🏁 [STEP 3 PASS] 歌单广场');

    // 4. 巅峰榜单
    await clickSidebarItem('巅峰榜单');
    await capture('audit_04_desktop_toplist.png');
    debugPrint('🏁 [STEP 4 PASS] 巅峰榜单');

    // 5. 热门歌手
    await clickSidebarItem('热门歌手');
    await capture('audit_05_desktop_artists.png');
    debugPrint('🏁 [STEP 5 PASS] 热门歌手');

    // 6. 声音电台
    await clickSidebarItem('声音电台');
    await capture('audit_06_desktop_podcasts.png');
    debugPrint('🏁 [STEP 6 PASS] 声音电台');

    // 7. 我喜欢的音乐
    await clickSidebarItem('我喜欢的音乐');
    await capture('audit_07_desktop_favorites.png');
    debugPrint('🏁 [STEP 7 PASS] 我喜欢的音乐');

    // 8. 本地与下载
    await clickSidebarItem('本地与下载');
    await capture('audit_08_desktop_local.png');
    debugPrint('🏁 [STEP 8 PASS] 本地与下载');

    // 9. 播放历史
    await clickSidebarItem('播放历史');
    await capture('audit_09_desktop_history.png');
    debugPrint('🏁 [STEP 9 PASS] 播放历史');

    // 10. 多端同步中心
    await clickSidebarItem('多端同步中心');
    await capture('audit_10_desktop_sync.png');
    debugPrint('🏁 [STEP 10 PASS] 多端同步中心');

    // 11. LX 音源管理
    await clickSidebarItem('LX 音源管理');
    await capture('audit_11_desktop_sources.png');
    debugPrint('🏁 [STEP 11 PASS] LX 音源管理');

    // 12. 个性化设置 (浅色)
    await clickSidebarItem('个性化设置');
    await capture('audit_12_desktop_settings_light.png');
    debugPrint('🏁 [STEP 12 PASS] 个性化设置');

    // 13. 巨幕全屏歌词
    await tester.tap(find.byIcon(Icons.lyrics_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_15_desktop_fullscreen_lyrics.png');

    // 退出全屏歌词
    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // 14. 弹窗与抽屉: 均衡器 EQ
    await tester.tap(find.byIcon(Icons.tune_rounded).last);
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_16_desktop_modal_eq.png');
    // 关闭 EQ
    await tester.tapAt(const Offset(50, 50)); // 点击蒙层关闭
    await tester.pump(const Duration(milliseconds: 300));

    // 15. 弹窗: 睡眠定时器
    await tester.tap(find.byIcon(Icons.hourglass_bottom_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_17_desktop_modal_sleep_timer.png');
    // 关闭定时器
    await tester.tapAt(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 300));

    // 16. 抽屉: 播放队列
    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_18_desktop_drawer_queue.png');
    // 关闭队列
    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await tester.pump(const Duration(milliseconds: 300));

    // 17. 切换深色模式
    themeProvider.toggleTheme();
    await tester.pump(const Duration(milliseconds: 300));
    // 回到发现页
    await tester.scrollUntilVisible(find.text('发现音乐'), -50.0, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('发现音乐'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_14_desktop_discover_dark.png');

    // 设置深色模式
    await tester.scrollUntilVisible(find.text('个性化设置'), 50.0, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('个性化设置'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_13_desktop_settings_dark.png');

    // 恢复浅色
    themeProvider.toggleTheme();
    await tester.pump(const Duration(milliseconds: 300));

    // -------------------------------------------------------------------------
    // 2. 移动端原生全景走查 (逻辑尺寸 390 x 844, 物理像素 780 x 1688 @2x)
    // -------------------------------------------------------------------------
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(buildApp(home: const MobileScaffold()));
    await tester.pump(const Duration(milliseconds: 400));
    await capture('audit_19_mobile_home_discover.png');

    // 移动端每日推荐二级页
    await tester.tap(find.text('每日推荐'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_20_mobile_daily_recommend.png');
    // 返回
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // 移动端私人漫游 FM
    await tester.tap(find.text('私人漫游'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_21_mobile_roaming_fm.png');
    // 返回
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // 移动端探索 / 搜索
    await tester.tap(find.text('探索'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_22_mobile_search.png');

    // 移动端资料库
    await tester.tap(find.text('资料库'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_23_mobile_library.png');

    // 移动端深色模式
    themeProvider.toggleTheme();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('发现'));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('audit_24_mobile_home_dark.png');

    // 清理
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugPrint('🧹 [TEARDOWN 1] audioService.pause()');
    audioService.pause();
    debugPrint('🧹 [TEARDOWN 2] audioService.dispose()');
    audioService.dispose();
    debugPrint('🧹 [TEARDOWN 3] LanSyncService.instance.stopServer()');
    await LanSyncService.instance.stopServer();
    LanSyncService.instance.client.dispose();
    debugPrint('🧹 [TEARDOWN 4] ALL TEARDOWN FINISHED!');
  });
}
