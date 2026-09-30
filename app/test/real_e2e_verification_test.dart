// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';

void main() {
  test('真实网络环境下的场景歌单与超大歌单全量拉取实测验证', () async {
    print('>>> [E2E 实测 1] 请求婚礼场景真实歌单 416104421 (81首)...');
    final pl81 = await OnlineMusicService.importNeteasePlaylist('416104421');
    expect(pl81, isNotNull);
    print('>>> [E2E 实测 1] 标题: ${pl81!.title}');
    print('>>> [E2E 实测 1] 外部标注总数: ${pl81.trackCount}');
    print('>>> [E2E 实测 1] 首屏真实解析曲目数: ${pl81.tracks.length}');
    print('>>> [E2E 实测 1] 全量曲目ID数: ${pl81.allTrackIds.length}');
    expect(pl81.tracks.length, greaterThanOrEqualTo(10));
    expect(pl81.allTrackIds.length, equals(81));
    print('>>> [E2E 实测 1] 首首歌: ${pl81.tracks.first.title} - ${pl81.tracks.first.artist}');
    print('>>> [E2E 实测 1] 末首歌: ${pl81.tracks.last.title} - ${pl81.tracks.last.artist}');

    print('>>> [E2E 实测 2] 请求超大歌单 24381616 (1268首)...');
    final plLarge = await OnlineMusicService.importNeteasePlaylist('24381616');
    expect(plLarge, isNotNull);
    print('>>> [E2E 实测 2] 标题: ${plLarge!.title}');
    print('>>> [E2E 实测 2] 外部标注总数: ${plLarge.trackCount}');
    print('>>> [E2E 实测 2] 首屏秒开拉取数: ${plLarge.tracks.length}');
    print('>>> [E2E 实测 2] 全量ID列表数: ${plLarge.allTrackIds.length}');
    // 首屏毫秒级秒开（>=1首），并且携带全量 ID 供后台无感流式增量懒加载
    expect(plLarge.tracks.length, greaterThanOrEqualTo(1));
    expect(plLarge.allTrackIds.length, greaterThan(1000));
    print('>>> [E2E 实测 2] 成功通过！');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
