import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';

class _AllowAllHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('扩大半径探索排查专项验证', () {
    test('1. 连续快速切歌代数安全机制：快速连续点播5首，最终稳定播放在最后选中的曲目', () async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final tracks = List.generate(5, (i) => Track(
        id: 'test-track-$i',
        title: '测试曲目 $i',
        artist: '测试歌手',
        album: '测试专辑',
        coverUrl: '',
        duration: const Duration(minutes: 3),
        source: 'test',
        audioUrl: 'https://example.com/stream_$i.mp3',
      ));

      // 连续快速点播
      for (final t in tracks) {
        player.playTrack(t);
      }

      await Future.delayed(const Duration(milliseconds: 300));
      expect(player.currentTrack?.id, equals('test-track-4'));
      expect(player.isPlaying, isTrue);
      expect(backend.isPlaying, isTrue);
    });

    test('2. 进度拖拽 seek 与播放状态保持', () async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final track = Track(
        id: 'test-seek',
        title: '拖拽测试',
        artist: '歌手',
        album: '专辑',
        coverUrl: '',
        duration: const Duration(minutes: 4),
        source: 'test',
        audioUrl: 'https://example.com/seek.mp3',
      );

      player.playTrack(track);
      await Future.delayed(const Duration(milliseconds: 200));

      // 执行 seek 到 60 秒
      player.seek(const Duration(seconds: 60));
      expect(backend.position.inSeconds, equals(60));
      expect(player.isPlaying, isTrue);
    });

    test('3. 音量调节与静音记忆', () async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      player.setVolume(0.5);
      expect(player.volume, equals(0.5));
      expect(backend.volume, equals(0.5));

      // 静音
      player.setVolume(0.0);
      expect(player.volume, equals(0.0));
      expect(backend.volume, equals(0.0));
    });

    test('4. 播放模式切换 (列表循环 -> 单曲循环 -> 随机漫游)', () {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      expect(player.playbackMode, equals(PlaybackMode.sequence));
      player.cyclePlaybackMode();
      expect(player.playbackMode, equals(PlaybackMode.singleLoop));
      player.cyclePlaybackMode();
      expect(player.playbackMode, equals(PlaybackMode.shuffle));
      player.cyclePlaybackMode();
      expect(player.playbackMode, equals(PlaybackMode.sequence));
    });

    test('5. 真实热歌榜前列曲目可播放性全面探测', () async {
      HttpOverrides.global = _AllowAllHttpOverrides();
      final hotSongs = [
        {'title': '海屿你', 'artist': '马也_Crabbit'},
        {'title': '明知故犯', 'artist': '胡鸿钧'},
        {'title': '于是', 'artist': '郑润泽'},
        {'title': '小城夏天', 'artist': 'LBI利比'},
        {'title': '从前说', 'artist': '小阿七'},
      ];

      for (final s in hotSongs) {
        final url = await OnlineMusicService.resolvePlayableAudioUrl(s['title']!, s['artist']!);
        expect(url, isNotNull, reason: '${s['title']} 应能通过多源智能聚合成功提取到物理可播放直链');
        expect(url!.startsWith('http'), isTrue);
      }
    });
  });
}
