import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/local_music_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    LocalMusicService.instance.clearLocalTracks();
  });

  group('LocalMusicService (本地音乐扫描与曲库引擎) 测试', () {
    test('音频文件名智能解析与元数据提取', () {
      final service = LocalMusicService.instance;

      // 1. 标准 "歌手 - 歌曲名.flac"
      final file1 = File('/tmp/music/周杰伦 - 晴天.flac');
      final track1 = service.parseAudioFile(file1);
      expect(track1.artist, '周杰伦');
      expect(track1.title, '晴天');
      expect(track1.album, contains('FLAC'));
      expect(track1.localPath, file1.path);
      expect(track1.audioUrl, isNull);

      // 2. 下划线分隔 "歌手_歌曲名.wav"
      final file2 = File('/tmp/music/Beyond_海阔天空.wav');
      final track2 = service.parseAudioFile(file2);
      expect(track2.artist, 'Beyond');
      expect(track2.title, '海阔天空');
      expect(track2.album, contains('WAV'));

      // 3. 仅歌曲名 "七里香.mp3"
      final file3 = File('/tmp/music/七里香.mp3');
      final track3 = service.parseAudioFile(file3);
      expect(track3.title, '七里香');
      expect(track3.artist, '本地音乐');
      expect(track3.album, contains('MP3'));
    });

    test('本地目录音频文件真实遍历与格式嗅探过滤', () async {
      final service = LocalMusicService.instance;

      // 创建测试临时目录与音频假文件
      final tempDir = Directory.systemTemp.createTempSync('mellow_music_scan_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final f1 = File(p.join(tempDir.path, '林俊杰 - 江南.flac'))..createSync();
      final f2 = File(p.join(tempDir.path, '陈奕迅 - 十年.mp3'))..createSync();
      final f3 = File(p.join(tempDir.path, '无损试音 - 渡口.wav'))..createSync();
      // 非音频文件应被完全过滤
      File(p.join(tempDir.path, 'album_info.txt')).createSync();
      File(p.join(tempDir.path, 'cover.jpg')).createSync();

      // 执行扫描
      final addedCount = await service.scanDirectory(tempDir.path);
      expect(addedCount, 3);
      expect(service.localTracks.length, 3);
      expect(service.scannedDirectories, contains(tempDir.path));

      // 验证曲目信息
      final titles = service.localTracks.map((t) => t.title).toList();
      expect(titles, containsAll(['江南', '十年', '渡口']));

      // 验证非音频文件未被收录
      expect(titles.contains('album_info'), isFalse);
    });

    test('本地曲库持久化落盘与冷重启恢复', () async {
      final service = LocalMusicService.instance;

      final tempDir = Directory.systemTemp.createTempSync('mellow_persist_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      File(p.join(tempDir.path, '王菲 - 红豆.flac')).createSync();
      await service.scanDirectory(tempDir.path);

      expect(service.localTracks.length, 1);
      expect(service.localTracks.first.title, '红豆');

      // 模拟应用冷重启：清空内存并从 StorageService 重新加载
      service.loadFromStorage();
      expect(service.localTracks.length, 1);
      expect(service.localTracks.first.title, '红豆');
      expect(service.localTracks.first.artist, '王菲');
    });

    test('AudioPlayerService 与本地曲库播放闭环集成', () async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final tempDir = Directory.systemTemp.createTempSync('mellow_player_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      File(p.join(tempDir.path, '周杰伦 - 枫.flac')).createSync();
      File(p.join(tempDir.path, '陶喆 - 爱很简单.mp3')).createSync();

      await player.scanLocalDirectory(tempDir.path);
      expect(player.localTracks.length, 2);

      // 1. 播放全部本地曲目
      player.playLocalMusic();
      expect(player.isPlaying, isTrue);
      expect(player.playlist.length, 2);
      expect(player.currentTrack?.title, '枫');

      // 2. 移除单曲
      final trackToRemove = player.localTracks.first.id;
      player.removeLocalTrack(trackToRemove);
      expect(player.localTracks.length, 1);
      expect(player.localTracks.first.title, '爱很简单');

      // 3. 清空本地曲库
      player.clearLocalTracks();
      expect(player.localTracks.isEmpty, isTrue);

      player.dispose();
    });
  });
}
