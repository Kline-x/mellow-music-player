import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/sources/scenario_playlist_service.dart';
import 'package:mellow_music/core/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('E2E-FINAL-VERIFY: 场景歌单端到端全链路业务流真机回归闭环', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();

    final scenariosToTest = [
      '结婚',
      '国庆',
      '新年',
      '自驾',
      '助眠',
      '露营',
      '咖啡',
    ];

    for (final word in scenariosToTest) {
      final playlists = await ScenarioPlaylistService.instance.searchScenarioPlaylists(word, limit: 5);
      expect(playlists.isNotEmpty, isTrue, reason: '场景【$word】检索结果不可为空');

      final top1 = playlists.first;
      expect(top1.title.isNotEmpty, isTrue);

      // 解析该歌单曲目
      final detail = await ScenarioPlaylistService.instance.getScenarioPlaylistDetail(top1.id);
      expect(detail, isNotNull, reason: '歌单详情不可为 null');
      expect(detail!.tracks.isNotEmpty, isTrue, reason: '歌单内曲目数量不可为空');
    }

    // 验证搜索历史管理
    final history = StorageService.instance.getScenarioSearchHistory();
    expect(history.length, greaterThanOrEqualTo(scenariosToTest.length));
    expect(history.contains('结婚'), isTrue);
    expect(history.contains('国庆'), isTrue);
    expect(history.contains('新年'), isTrue);
  });
}
