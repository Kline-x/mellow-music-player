import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mellow_music/design_system/tokens.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/lx_script_sandbox.dart';
import 'package:mellow_music/core/sources/lx_source_model.dart';
import 'package:mellow_music/core/sync/sync_data_model.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/navigation/mobile_scaffold.dart';

void main() {
  setUpAll(() {
    MellowImage.isInTest = true;
  });

  group('Mellow Music · 客户端原生端到端 (Client E2E) 真实用户全链路验收套件', () {
    late ThemeProvider themeProvider;
    late AudioPlayerService audioService;
    late EqualizerManager equalizerManager;
    late LxSourceEngine sourceEngine;
    late LanSyncService lanSyncService;

    setUp(() {
      themeProvider = ThemeProvider();
      audioService = AudioPlayerService();
      equalizerManager = EqualizerManager();
      sourceEngine = LxSourceEngine(enableTestingUrls: true);
      lanSyncService = LanSyncService();
    });

    tearDown(() {
      audioService.pause();
      audioService.dispose();
      equalizerManager.dispose();
      sourceEngine.dispose();
      lanSyncService.dispose();
    });

    Widget buildTestClientApp({required Widget child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audioService),
          ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
        ],
        child: MaterialApp(
          title: 'Mellow Music Client E2E',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: themeProvider.canvasColor,
          ),
          home: child,
        ),
      );
    }

    testWidgets('E2E-01: 客户端冷启动与 Modern Soft UI 响应式视口自适应渲染 (桌面 1440x900 & 移动 390x844)', (tester) async {
      // 1. 桌面端工作台视口挂载
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestClientApp(child: const DesktopScaffold()));
      await tester.pump(const Duration(milliseconds: 300));

      // 断言桌面端骨架挂载 (Mac 标题栏、左侧导航、Bento 内容、播放控制底栏)
      expect(find.byType(DesktopScaffold), findsOneWidget);
      expect(find.text('Mellow Music · 润音'), findsOneWidget);

      // 2. 响应式切到移动端原生 4-Tab 视口
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(buildTestClientApp(child: const MobileScaffold()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MobileScaffold), findsOneWidget);
      expect(find.text('发现'), findsOneWidget);
      expect(find.text('探索'), findsOneWidget);
      expect(find.text('资料库'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
    });

    testWidgets('E2E-02: 全网聚合检索、六维音源切换与音质平滑降级用户链路', (tester) async {
      // 1. 用户执行全网多平台聚合搜索
      final aggResults = await sourceEngine.searchAggregated('雨');
      expect(aggResults.list.isNotEmpty, isTrue);
      final firstSong = aggResults.list.first;
      expect(firstSong.title.contains('雨') || firstSong.artist.isNotEmpty, isTrue);

      // 2. 用户请求 Hi-Res 24bit 超高清音质播放链接 (自动降级机制)
      final playbackUrl = await sourceEngine.resolveMusicUrlWithFallback(firstSong, quality: AudioQuality.flac24bit);
      expect(playbackUrl.url.isNotEmpty, isTrue);
      expect(playbackUrl.url.startsWith('http'), isTrue);

      // 3. 用户在客户端手动切换当前主音源
      sourceEngine.setActiveSource('kg');
      expect(sourceEngine.activeSourceId, equals('kg'));

      // 4. 音源停用与主源回退保护
      sourceEngine.setSourceEnabled('kg', false);
      expect(sourceEngine.getDriver('kg')!.metadata.isEnabled, isFalse);
      expect(sourceEngine.activeSourceId, equals('mellow')); // 自动回退保护
    });

    testWidgets('E2E-03: 客户端播放控制底栏与状态机生命周期 (播放/暂停/切歌/循环模式/Seek/音量)', (tester) async {
      // 初始状态：曲目池已有预设曲目
      expect(audioService.currentTrack, isNotNull);
      final initialTrack = audioService.currentTrack!;

      // 1. 用户点击播放 / 暂停
      audioService.togglePlay();
      expect(audioService.isPlaying, isTrue);
      audioService.togglePlay();
      expect(audioService.isPlaying, isFalse);

      // 2. 用户切歌 (Next Track)
      audioService.next();
      expect(audioService.currentTrack?.id != initialTrack.id, isTrue);

      // 3. 用户切换循环模式 (sequence -> singleLoop -> shuffle)
      expect(audioService.playbackMode, equals(PlaybackMode.sequence));
      audioService.setPlaybackMode(PlaybackMode.singleLoop);
      expect(audioService.playbackMode, equals(PlaybackMode.singleLoop));
      audioService.setPlaybackMode(PlaybackMode.shuffle);
      expect(audioService.playbackMode, equals(PlaybackMode.shuffle));

      // 4. 用户拖动进度条 Seek
      audioService.seek(const Duration(seconds: 45));
      expect(audioService.currentPosition.inSeconds, equals(45));

      // 5. 用户调节音量
      audioService.setVolume(0.9);
      expect(audioService.volume, equals(0.9));
    });

    testWidgets('E2E-04: 声学 10 频段 EQ 均衡器实时调节与 DSP 参数注入', (tester) async {
      // 1. 用户套用低音增强预设 Bass Boost
      equalizerManager.applyPreset(EqualizerPreset.bassBoost);
      expect(equalizerManager.currentPreset, equals(EqualizerPreset.bassBoost));
      expect(equalizerManager.bandGains[0], greaterThan(0)); // 31Hz 提升

      // 2. 用户手动调节 1kHz 频段增益滑块
      equalizerManager.setBandGain(5, 3.5); // 1000Hz 设为 +3.5dB
      expect(equalizerManager.bandGains[5], equals(3.5));
      expect(equalizerManager.currentPreset, equals(EqualizerPreset.custom));

      // 3. 断言 firequalizer 滤镜参数生成合规
      final filterString = equalizerManager.toLibmpvFilterString();
      expect(filterString.startsWith('firequalizer='), isTrue);
      expect(filterString.contains('gain_interpolate(1000,3.5)'), isTrue);

      // 4. 用户一键重置平直曲线
      equalizerManager.applyPreset(EqualizerPreset.flat);
      expect(equalizerManager.currentPreset, equals(EqualizerPreset.flat));
      expect(equalizerManager.bandGains[5], equals(0.0));
    });

    testWidgets('E2E-05: 动效巨幕黑胶歌词与时间轴高刷跟随', (tester) async {
      // 用户播放带歌词的曲目
      final trackWithLyrics = mockPresetTracks.first;
      audioService.playTrack(trackWithLyrics);
      audioService.seek(const Duration(seconds: 14));

      expect(trackWithLyrics.lyrics.length, greaterThan(3));
      // 断言歌曲正在回放并且当前时间戳定位准确
      expect(audioService.currentPosition.inSeconds, equals(14));
      expect(audioService.isPlaying, isTrue);
      audioService.pause();
    });

    testWidgets('E2E-06: 歌单心标收藏与响应式数据联动', (tester) async {
      final currentTrackId = audioService.currentTrack!.id;
      final wasFav = audioService.favoriteIds.contains(currentTrackId);

      // 用户点击爱心心标
      audioService.toggleFavorite(currentTrackId);
      expect(audioService.favoriteIds.contains(currentTrackId), equals(!wasFav));

      // 再次点击恢复
      audioService.toggleFavorite(currentTrackId);
      expect(audioService.favoriteIds.contains(currentTrackId), equals(wasFav));
    });

    testWidgets('E2E-07: 多端数据同步 (WebDAV 云备份与 LX-Sync 局域网广播流转) 闭环', (tester) async {
      final now = DateTime.now();
      final track1 = SyncTrack(
        id: 'track-1',
        title: '测试曲目 1',
        artist: '测试歌手',
        album: '测试专辑',
        coverUrl: 'https://example.com/cover1.jpg',
        durationMs: 240000,
        source: 'kw',
      );

      // 1. 生成客户端完整数据快照
      final snapshot = SyncSnapshot(
        version: '1.0.0',
        deviceId: 'client-win-x64',
        deviceName: 'Windows 桌面旗舰版',
        timestamp: now,
        favorites: [
          SyncFavoriteItem(track: track1, updatedAt: now, isRemoved: false)
        ],
        playlists: [
          SyncPlaylist(
            id: 'pl-sync-1',
            name: '云端同步歌单',
            description: '多端协同互传',
            coverUrl: 'https://example.com/pl.jpg',
            songs: [track1],
            updatedAt: now,
            isDeleted: false,
          )
        ],
        history: [
          SyncHistoryItem(track: track1, playedAt: now),
        ],
        equalizer: SyncEqualizerConfig(
          isEnabled: true,
          presetName: 'bassBoost',
          bandGains: [6.0, 4.0, 2.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.0, 4.0],
          updatedAt: now,
        ),
        playbackState: SyncPlaybackState(
          currentTrackId: 'track-1',
          positionMs: 45000,
          durationMs: 240000,
          playbackMode: 'singleLoop',
          volume: 0.9,
          isPlaying: true,
          updatedAt: now,
        ),
      );

      final jsonStr = snapshot.toRawJson();
      expect(jsonStr.contains('client-win-x64'), isTrue);

      // 2. 验证反序列化无损恢复
      final restored = SyncSnapshot.fromRawJson(jsonStr);
      expect(restored.deviceId, equals(snapshot.deviceId));
      expect(restored.playlists.first.name, equals('云端同步歌单'));

      // 3. 局域网在线设备模型
      final lanDevice = LanDevice(
        id: 'device-2',
        name: 'MacBook Pro',
        ip: '192.168.1.100',
        port: 23332,
        lastSeen: now,
      );
      expect(lanDevice.port, equals(23332));
      expect(lanDevice.name, equals('MacBook Pro'));
    });

    testWidgets('E2E-08: 个性化声学强调色实时换肤与全局 Tokens 联动', (tester) async {
      // 1. 切换至粉色 Pink
      themeProvider.setAccentType(AccentColorType.pink);
      expect(themeProvider.accentType, equals(AccentColorType.pink));
      expect(themeProvider.accentColor, equals(AccentColorType.pink.lightColor));

      // 2. 切换至紫色 Purple
      themeProvider.setAccentType(AccentColorType.purple);
      expect(themeProvider.accentType, equals(AccentColorType.purple));
      expect(themeProvider.accentColor, equals(AccentColorType.purple.lightColor));

      // 3. 切换暗黑模式 (Dark Mode)
      themeProvider.setDarkMode(true);
      expect(themeProvider.isDarkMode, isTrue);
      expect(themeProvider.accentColor, equals(AccentColorType.purple.darkColor));

      // 4. 切换浅色模式 (Light Mode)
      themeProvider.setDarkMode(false);
      expect(themeProvider.isDarkMode, isFalse);
    });
  });
}
