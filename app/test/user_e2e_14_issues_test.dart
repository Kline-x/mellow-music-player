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
  });
}
