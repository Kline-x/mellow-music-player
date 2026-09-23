import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('自建歌单管理系统与单曲收录测试', () {
    test('创建自建歌单生命周期与属性默认值', () {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final pl = player.createCustomPlaylist(
        '深夜疗愈自选集',
        description: '睡前安静聆听的古筝与纯音乐',
        initialTracks: [mockPresetTracks[0]],
      );

      expect(pl.id.startsWith('custom-'), isTrue);
      expect(pl.title, '深夜疗愈自选集');
      expect(pl.description, '睡前安静聆听的古筝与纯音乐');
      expect(pl.isCustom, isTrue);
      expect(pl.trackCount, 1);
      expect(pl.tracks.length, 1);
      expect(pl.tracks.first.id, mockPresetTracks[0].id);

      // 验证已加入 player.importedPlaylists
      expect(player.importedPlaylists.any((p) => p.id == pl.id), isTrue);

      player.dispose();
    });

    test('单曲添加至歌单与查重防重复收录', () {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final pl = player.createCustomPlaylist('经典华语精选');
      final track1 = mockPresetTracks[1];
      final track2 = mockPresetTracks[2];

      // 1. 添加第 1 首
      final added1 = player.addTrackToPlaylist(pl.id, track1);
      expect(added1, isTrue);
      expect(player.isTrackInPlaylist(pl.id, track1.id), isTrue);

      // 2. 重复添加相同歌曲，应当被拦截并返回 false
      final dupAdd = player.addTrackToPlaylist(pl.id, track1);
      expect(dupAdd, isFalse);

      // 3. 添加第 2 首
      final added2 = player.addTrackToPlaylist(pl.id, track2);
      expect(added2, isTrue);

      final updatedPl = player.importedPlaylists.firstWhere((p) => p.id == pl.id);
      expect(updatedPl.trackCount, 2);
      expect(updatedPl.tracks.map((t) => t.id).toList(), [track1.id, track2.id]);

      player.dispose();
    });

    test('从歌单中移除单曲', () {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final track1 = mockPresetTracks[0];
      final track2 = mockPresetTracks[1];
      final pl = player.createCustomPlaylist('待精简歌单', initialTracks: [track1, track2]);

      expect(player.isTrackInPlaylist(pl.id, track1.id), isTrue);
      expect(player.isTrackInPlaylist(pl.id, track2.id), isTrue);

      // 移除 track1
      final removed = player.removeTrackFromPlaylist(pl.id, track1.id);
      expect(removed, isTrue);
      expect(player.isTrackInPlaylist(pl.id, track1.id), isFalse);
      expect(player.isTrackInPlaylist(pl.id, track2.id), isTrue);

      final updatedPl = player.importedPlaylists.firstWhere((p) => p.id == pl.id);
      expect(updatedPl.trackCount, 1);
      expect(updatedPl.tracks.first.id, track2.id);

      player.dispose();
    });

    test('重命名与编辑歌单信息', () {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final pl = player.createCustomPlaylist('旧名称', description: '旧简介');
      final renamed = player.renamePlaylist(pl.id, '新歌单名称', '更新后的歌单简介');

      expect(renamed, isTrue);
      final updated = player.importedPlaylists.firstWhere((p) => p.id == pl.id);
      expect(updated.title, '新歌单名称');
      expect(updated.description, '更新后的歌单简介');

      player.dispose();
    });

    test('一键将我喜欢的音乐批量导出为新歌单', () {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      // 确保两首收藏在 favoriteTracks 中
      if (!player.isFavorite(mockPresetTracks[0].id)) {
        player.toggleFavorite(mockPresetTracks[0].id, mockPresetTracks[0]);
      }
      if (!player.isFavorite(mockPresetTracks[1].id)) {
        player.toggleFavorite(mockPresetTracks[1].id, mockPresetTracks[1]);
      }

      final exported = player.exportFavoritesToPlaylist('我的心动精选集');
      expect(exported, isNotNull);
      expect(exported!.title, '我的心动精选集');
      expect(exported.isCustom, isTrue);
      expect(exported.trackCount, greaterThanOrEqualTo(2));
      expect(exported.tracks.any((t) => t.id == mockPresetTracks[0].id), isTrue);

      player.dispose();
    });

    test('删除歌单', () {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final pl = player.createCustomPlaylist('即将删除的歌单');
      expect(player.importedPlaylists.any((p) => p.id == pl.id), isTrue);

      final deleted = player.deletePlaylist(pl.id);
      expect(deleted, isTrue);
      expect(player.importedPlaylists.any((p) => p.id == pl.id), isFalse);

      player.dispose();
    });

    test('自建歌单落盘持久化与冷重启还原', () async {
      // 1. 在第一个实例中创建歌单
      final backend1 = InMemoryAudioPlayerBackend();
      final player1 = AudioPlayerService(backend: backend1);

      player1.createCustomPlaylist(
        '持久化测试歌单',
        description: '测试重启后是否保留',
        initialTracks: [mockPresetTracks[0], mockPresetTracks[1]],
      );
      player1.dispose();

      // 2. 模拟冷重启，创建全新实例并从 StorageService 加载
      final backend2 = InMemoryAudioPlayerBackend();
      final player2 = AudioPlayerService(backend: backend2);

      final persisted = player2.importedPlaylists.where((p) => p.title == '持久化测试歌单').firstOrNull;
      expect(persisted, isNotNull);
      expect(persisted!.isCustom, isTrue);
      expect(persisted.trackCount, 2);
      expect(persisted.description, '测试重启后是否保留');

      player2.dispose();
    });
  });
}
