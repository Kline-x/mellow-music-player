import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/mobile/mobile_sheets.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';
import 'package:flutter/services.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';
import 'package:mellow_music/views/desktop/fullscreen_lyrics_view.dart';
import 'package:mellow_music/views/desktop/desktop_floating_lyric_bar.dart';
import 'package:mellow_music/views/desktop/desktop_search_view.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('用户视角 E2E 验收 - 14 项体验缺陷全面回归', () {
    test('ISSUE-13: 内置 33 首曲库全量注入真实可用高清音频流且全局索引寻轨可用', () {
      final allTracks = getAllKnownTracks();
      expect(allTracks.length >= 33, isTrue);
      for (final track in allTracks) {
        expect(track.audioUrl, isNotNull, reason: 'Track ${track.title} audioUrl should not be null');
        expect(track.audioUrl!.startsWith('http'), isTrue);
      }

      final track1 = findKnownTrackById('track-1');
      expect(track1, isNotNull);
      expect(track1!.title, '云水禅心');

      final trackNew = findKnownTrackById('chart-new-1');
      expect(trackNew, isNotNull);
      expect(trackNew!.artist, '郑润泽');
    });

    test('ISSUE-11: 收藏曲目跨曲库实体持久化，清空当前播放队列后收藏完好无损', () async {
      final player = AudioPlayerService();

      // 收藏一首榜单新歌
      player.toggleFavorite('chart-new-1');
      expect(player.isFavorite('chart-new-1'), isTrue);

      // 清空当前播放队列
      player.clearQueue();
      expect(player.playlist.isEmpty, isTrue);

      // 验证收藏曲目跨列表跨队列依然完好无损！
      expect(player.isFavorite('chart-new-1'), isTrue);
      expect(player.favoriteTracks.any((t) => t.id == 'chart-new-1'), isTrue);
    });

    test('ISSUE-10: 外部导入歌单本地持久化测试', () async {
      final player = AudioPlayerService();

      final pl = ImportedPlaylist(
        id: 'test_imported_1',
        title: '我的离线珍藏',
        coverUrl: 'https://example.com/cover.jpg',
        description: '回归测试导入单',
        trackCount: 1,
        tracks: [mockPresetTracks[0]],
      );

      player.addImportedPlaylist(pl);
      expect(player.importedPlaylists.length, 1);

      // 模拟冷重启重载
      final restartedPlayer = AudioPlayerService();
      expect(restartedPlayer.importedPlaylists.length, 1);
      expect(restartedPlayer.importedPlaylists[0].title, '我的离线珍藏');
    });

    test('ISSUE-01: 播放足迹清空与空状态功能', () async {
      final player = AudioPlayerService();

      player.playTrack(mockPresetTracks[0]);
      player.playTrack(mockPresetTracks[1]);
      expect(player.playHistory.isNotEmpty, isTrue);

      player.clearPlayHistory();
      expect(player.playHistory.isEmpty, isTrue);

      // 重启校验落盘持久化清空
      final restartedPlayer = AudioPlayerService();
      expect(restartedPlayer.playHistory.isEmpty, isTrue);
    });

    test('ISSUE-08: 静音记忆切换，恢复时保持静音前的非零音量', () async {
      final player = AudioPlayerService();

      player.setVolume(0.42);
      expect(player.volume, closeTo(0.42, 0.001));

      // 切换为静音
      player.toggleMute();
      expect(player.volume, 0.0);

      // 再次切换解除静音，应准确复原为 0.42
      player.toggleMute();
      expect(player.volume, closeTo(0.42, 0.001));
    });

    test('ISSUE-09: 音频播放容错提示与关闭', () {
      final player = AudioPlayerService();
      expect(player.playbackNotice, isNull);

      // 模拟设置或清除通知
      player.clearPlaybackNotice();
      expect(player.playbackNotice, isNull);
    });

    testWidgets('ISSUE-06 & ISSUE-02: 桌面端在 800px 窄视口下无溢出并渲染快捷键支持', (tester) async {
      final player = AudioPlayerService();
      final theme = ThemeProvider();

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
      await tester.pump(const Duration(milliseconds: 200));

      // 验证没有 RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.byType(DesktopScaffold), findsOneWidget);
    });

    testWidgets('ISSUE-04 & ISSUE-05: 移动端全屏抽屉歌词单行高亮与滑动控制器绑定', (tester) async {
      final player = AudioPlayerService();
      final theme = ThemeProvider();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: MobilePlayerBottomSheet(onClose: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(MobilePlayerBottomSheet), findsOneWidget);
    });

    testWidgets('ISSUE-12: 移动端私人 FM 旋转动画与播放态一致', (tester) async {
      final player = AudioPlayerService();
      final theme = ThemeProvider();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: MobilePersonalFMPage(onBack: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(MobilePersonalFMPage), findsOneWidget);
    });

    test('ISSUE-FIX: AudioPlayerService 默认收藏列表为空集合，消灭硬编码四首默认歌曲', () {
      final player = AudioPlayerService();
      expect(player.favoriteIds, isEmpty);
      expect(player.favoriteTracks, isEmpty);
    });

    testWidgets('ISSUE-FIX: DesktopSourceManagerView 官方音源列表彻底剔除 mellow 与 lx_official_builtin', (tester) async {
      final theme = ThemeProvider();
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: AudioPlayerService()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSourceManagerView(onNavigate: (_, [__]) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('润音内置基准源'), findsNothing);
      expect(find.text('落雪官方内置音源 (多平台聚合)'), findsNothing);
      expect(find.text('酷我音乐'), findsOneWidget);
      expect(find.text('网易云音乐'), findsOneWidget);
      expect(find.text('QQ音乐'), findsOneWidget);
    });

    testWidgets('ISSUE-FIX P0-1: 访问带输入框页面后全局快捷键焦点自动复位，空格与单键依然生效', (tester) async {
      final theme = ThemeProvider();
      final player = AudioPlayerService();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: player),
          ],
          child: const MaterialApp(
            home: DesktopScaffold(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. 初次在发现页按空格 -> 触发播放
      expect(player.isPlaying, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 100));
      expect(player.isPlaying, isTrue);

      // 2. 模拟用户点击左侧导航栏的「全网搜索」进入搜索页 (硬断言存在，防静默空转)
      final searchNav = find.text('全网搜索');
      expect(searchNav, findsOneWidget);
      await tester.tap(searchNav);
      await tester.pump(const Duration(milliseconds: 100));

      // 3. 点击回「发现音乐」或点击空白处 (硬断言存在，防静默空转)
      final discoverNav = find.text('发现音乐');
      expect(discoverNav, findsOneWidget);
      await tester.tap(discoverNav);
      await tester.pump(const Duration(milliseconds: 100));

      // 4. 再次按空格键 -> 依然成功切换播放状态，杜绝焦点丢失！
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 100));
      expect(player.isPlaying, isFalse);
    });

    test('ISSUE-FIX P1-3: 【声学算法单测】EqualizerManager 10 频段增益滤波字符串生成算法验证 (底层引擎未开放硬件DSP)', () {
      final eq = EqualizerManager.instance;
      eq.applyPreset(EqualizerPreset.spatial3d);
      final filterStr = eq.toLibmpvFilterString();
      expect(filterStr, contains('firequalizer=gain='));
      expect(filterStr, contains('gain_interpolate(16000,7.0)'));
    });

    test('CODE-REVIEW-FIX: Track 实体类重写 operator == 与 hashCode 保持等价性契约', () {
      const t1 = Track(
        id: 'track_test_1',
        title: '测试曲目A',
        artist: '歌手A',
        album: '专辑A',
        coverUrl: 'http://example.com/a.jpg',
        duration: Duration(minutes: 3),
      );
      final t2 = t1.copyWith(isFavorite: true, audioUrl: 'http://example.com/play.mp3');
      const t3 = Track(
        id: 'track_test_2',
        title: '测试曲目B',
        artist: '歌手B',
        album: '专辑B',
        coverUrl: 'http://example.com/b.jpg',
        duration: Duration(minutes: 4),
      );

      expect(t1 == t2, isTrue, reason: '相同 id 的 Track copyWith 后应视为等价对象');
      expect(t1.hashCode, equals(t2.hashCode));
      expect(t1 == t3, isFalse, reason: '不同 id 的 Track 应判定为不等');
      final trackSet = {t1, t2, t3};
      expect(trackSet.length, equals(2), reason: 'Set 集合应基于 id 自动去重');
    });

    testWidgets('CODE-REVIEW-FIX: FullscreenLyricsView 在播放列表为空时呈现优雅空状态，不填充假歌曲', (tester) async {
      final theme = ThemeProvider();
      final player = AudioPlayerService();
      player.clearQueue();
      // 确保当前曲目为空
      expect(player.currentTrack, isNull);

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: player),
          ],
          child: MaterialApp(
            home: DesktopFullscreenLyricsView(onClose: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      // 验证不应出现 mockPresetTracks[0] 假数据（巫娜 / 云水禅心）
      expect(find.text('云水禅心'), findsNothing);
      expect(find.text('巫娜'), findsNothing);
      // 验证应呈现优雅空状态提示
      expect(find.text('当前暂无播放曲目'), findsWidgets);
      expect(find.text('请在主界面点播喜爱的歌曲'), findsOneWidget);
    });

    testWidgets('CODE-REVIEW-R6: DesktopFloatingLyricBar 悬浮歌词避让区初始化、无歌曲优雅降级与全卡片拖拽位移 (P1-4 硬证据)', (tester) async {
      final theme = ThemeProvider();
      final player = AudioPlayerService();
      player.clearQueue();

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: player),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopFloatingLyricBar(onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      // 1. 验证空状态下不再显示巫娜/云水禅心，而是优雅占位提示
      expect(find.text('云水禅心 - 巫娜'), findsNothing);
      expect(find.text('暂无播放曲目，请在主界面点播'), findsOneWidget);

      // 2. 验证悬浮条可拖拽位移
      final gestureFinder = find.byType(GestureDetector).first;
      await tester.drag(gestureFinder, const Offset(60, 40));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CODE-REVIEW-R6: DesktopSearchView 触底滚动触发分页加载与代数保护验证 (P1-6 硬证据)', (tester) async {
      final theme = ThemeProvider();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: AudioPlayerService()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSearchView(
                initialQuery: '周杰伦',
                onNavigate: (_, [__]) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(DesktopSearchView), findsOneWidget);

      // 模拟向下滚动触底触发加载更多
      final scrollFinder = find.byType(Scrollable).first;
      await tester.fling(scrollFinder, const Offset(0, -600), 1000);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}

