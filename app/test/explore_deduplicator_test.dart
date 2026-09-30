import 'package:flutter_test/flutter_test.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/explore_deduplicator.dart';

void main() {
  group('探索曲库去重与多样性算法测试 (ExploreDeduplicator Tests)', () {
    test('标题清洗功能正确移除各类修饰后缀', () {
      expect(ExploreDeduplicator.cleanTitle('晴天 (Live)'), equals('晴天'));
      expect(ExploreDeduplicator.cleanTitle('七里香 [Remix]'), equals('七里香'));
      expect(ExploreDeduplicator.cleanTitle('青花瓷【3D环绕版】'), equals('青花瓷'));
      expect(ExploreDeduplicator.cleanTitle('稻香 - 伴奏'), equals('稻香'));
      expect(ExploreDeduplicator.cleanTitle('夜曲 - DJ版'), equals('夜曲'));
      expect(ExploreDeduplicator.cleanTitle('简单爱（现场版）'), equals('简单爱'));
      expect(ExploreDeduplicator.cleanTitle('纯净音乐'), equals('纯净音乐'));
    });

    test('封面去重机制：相同封面图片 URL 的重复曲目被过滤', () {
      final List<Track> rawTracks = [
        const Track(
          id: '1',
          title: '曲目A',
          artist: '歌手1',
          album: '专辑A',
          coverUrl: 'https://example.com/same_cover.jpg',
          duration: Duration(seconds: 200),
          audioUrl: 'https://example.com/1.mp3',
        ),
        const Track(
          id: '2',
          title: '曲目B',
          artist: '歌手2',
          album: '专辑B',
          coverUrl: 'https://example.com/same_cover.jpg', // 相同封面
          duration: Duration(seconds: 180),
          audioUrl: 'https://example.com/2.mp3',
        ),
        const Track(
          id: '3',
          title: '曲目C',
          artist: '歌手3',
          album: '专辑C',
          coverUrl: 'https://example.com/diff_cover.jpg', // 不同封面
          duration: Duration(seconds: 210),
          audioUrl: 'https://example.com/3.mp3',
        ),
      ];

      final result = ExploreDeduplicator.filterDiverseTracks(rawTracks, maxCount: 10);
      expect(result.length, equals(2));
      expect(result[0].id, equals('1'));
      expect(result[1].id, equals('3'));
    });

    test('歌手频次平滑：单次推荐中同一歌手最多只保留一首代表作', () {
      final List<Track> rawTracks = [
        const Track(
          id: '101',
          title: '第一首歌',
          artist: 'DJ沐渔',
          album: 'DJ专辑1',
          coverUrl: 'https://example.com/cover1.jpg',
          duration: Duration(seconds: 180),
          audioUrl: 'https://example.com/101.mp3',
        ),
        const Track(
          id: '102',
          title: '第二首歌',
          artist: 'DJ沐渔', // 同一歌手
          album: 'DJ专辑2',
          coverUrl: 'https://example.com/cover2.jpg',
          duration: Duration(seconds: 200),
          audioUrl: 'https://example.com/102.mp3',
        ),
        const Track(
          id: '103',
          title: '第三首歌',
          artist: '周杰伦',
          album: '范特西',
          coverUrl: 'https://example.com/cover3.jpg',
          duration: Duration(seconds: 240),
          audioUrl: 'https://example.com/103.mp3',
        ),
      ];

      final result = ExploreDeduplicator.filterDiverseTracks(rawTracks, maxCount: 10, maxPerArtist: 1);
      expect(result.length, equals(2));
      expect(result.map((t) => t.artist).toList(), equals(['DJ沐渔', '周杰伦']));
    });

    test('标题变体去重：同歌曲的不同版本（原版、Live版、伴奏版）只保留第一版', () {
      final List<Track> rawTracks = [
        const Track(
          id: '201',
          title: '青花瓷',
          artist: '歌手甲',
          album: '我很忙',
          coverUrl: 'https://example.com/cover_a.jpg',
          duration: Duration(seconds: 240),
          audioUrl: 'https://example.com/201.mp3',
        ),
        const Track(
          id: '202',
          title: '青花瓷 (Live)',
          artist: '歌手乙',
          album: '演唱会',
          coverUrl: 'https://example.com/cover_b.jpg',
          duration: Duration(seconds: 250),
          audioUrl: 'https://example.com/202.mp3',
        ),
        const Track(
          id: '203',
          title: '菊花台',
          artist: '歌手丙',
          album: '依然范特西',
          coverUrl: 'https://example.com/cover_c.jpg',
          duration: Duration(seconds: 300),
          audioUrl: 'https://example.com/203.mp3',
        ),
      ];

      final result = ExploreDeduplicator.filterDiverseTracks(rawTracks, maxCount: 10);
      expect(result.length, equals(2));
      expect(result[0].title, equals('青花瓷'));
      expect(result[1].title, equals('菊花台'));
    });

    test('流派词库全量覆盖验证', () {
      final expectedGenres = ['全部', '华语', '流行', '摇滚', '民谣', '电子', '古典'];
      for (final g in expectedGenres) {
        expect(ExploreDeduplicator.genreKeywords.containsKey(g), isTrue);
        expect(ExploreDeduplicator.genreKeywords[g]!.isNotEmpty, isTrue);
      }
    });

    test('最大截断数量限制', () {
      final List<Track> tracks = List.generate(
        30,
        (i) => Track(
          id: 't_$i',
          title: '歌曲 $i',
          artist: '独特歌手 $i',
          album: '专辑 $i',
          coverUrl: 'https://example.com/cov_$i.jpg',
          duration: const Duration(seconds: 180),
          audioUrl: 'https://example.com/audio_$i.mp3',
        ),
      );

      final result = ExploreDeduplicator.filterDiverseTracks(tracks, maxCount: 12);
      expect(result.length, equals(12));
    });
  });
}
