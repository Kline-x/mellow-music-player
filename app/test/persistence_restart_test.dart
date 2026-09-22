import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/design_system/tokens.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0-02 冷重启与本地真实持久化回归套件 (Persistence Restart Test)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.init();
    });

    test('主题、强调色与光晕浓度在冷重启后 100% 完整留存', () async {
      // 1. 会话 1：用户修改主题与偏好设置
      final theme1 = ThemeProvider();
      expect(theme1.isDarkMode, false);
      expect(theme1.accentType, AccentColorType.blue);

      theme1.setDarkMode(true);
      theme1.setAccentType(AccentColorType.emerald);
      theme1.setGlowIntensity(0.9);

      expect(theme1.isDarkMode, true);
      expect(theme1.accentType, AccentColorType.emerald);
      expect(theme1.glowIntensity, 0.9);

      // 2. 模拟应用彻底关闭退出，冷启动重新实例化 ThemeProvider
      final theme2 = ThemeProvider();

      // 3. 断言数据完整还原，绝无归零
      expect(theme2.isDarkMode, true, reason: '重启后应保持深色模式');
      expect(theme2.accentType, AccentColorType.emerald, reason: '重启后应保持翡翠绿强调色');
      expect(theme2.glowIntensity, 0.9, reason: '重启后应保持设置的光晕浓度');
    });

    test('红心收藏、音量、播放模式与足迹在冷重启后 100% 完整留存', () async {
      // 1. 会话 1：用户调整播放器状态与收藏
      final audio1 = AudioPlayerService();
      audio1.setVolume(0.42);
      audio1.setPlaybackMode(PlaybackMode.shuffle);

      // 操作收藏：加入一首全新歌曲，并取消 track-1 的收藏
      audio1.toggleFavorite('custom-stream-song-999');
      if (audio1.isFavorite('track-1')) {
        audio1.toggleFavorite('track-1');
      }

      // 添加历史足迹
      audio1.playTrack(const Track(
        id: 'history-song-888',
        title: '测试持久化曲目',
        artist: '独立艺术家',
        album: '回归专辑',
        duration: Duration(minutes: 3),
        coverUrl: 'https://example.com/cover.png',
      ));

      expect(audio1.volume, 0.42);
      expect(audio1.playbackMode, PlaybackMode.shuffle);
      expect(audio1.isFavorite('custom-stream-song-999'), true);
      expect(audio1.isFavorite('track-1'), false);
      expect(audio1.playHistory.any((t) => t.id == 'history-song-888'), true);

      // 释放会话 1
      audio1.dispose();

      // 2. 模拟冷重启：启动全新 AudioPlayerService 实例
      final audio2 = AudioPlayerService();

      // 3. 断言全部偏好与业务状态成功从 SharedPreferences 恢复
      expect(audio2.volume, 0.42, reason: '音量应精准恢复');
      expect(audio2.playbackMode, PlaybackMode.shuffle, reason: '播放模式应保持随机漫游');
      expect(audio2.isFavorite('custom-stream-song-999'), true, reason: '新增收藏必须存在');
      expect(audio2.isFavorite('track-1'), false, reason: '已取消的收藏不可复活');
      expect(audio2.playHistory.any((t) => t.id == 'history-song-888'), true, reason: '历史足迹必须完整留存');

      audio2.dispose();
    });
  });
}
