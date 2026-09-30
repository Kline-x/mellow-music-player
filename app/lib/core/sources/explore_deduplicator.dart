import '../audio/track_model.dart';

/// 探索曲库多样性去重与丰富度过滤引擎 (ExploreDeduplicator)
///
/// 解决外部音源同一专辑/串烧歌手导致的大量相同封面、同一歌手霸屏以及重复版本问题。
class ExploreDeduplicator {
  ExploreDeduplicator._();

  /// 各流派多元子检索词库，确保检索池多样性
  static const Map<String, List<String>> genreKeywords = {
    '全部': [
      '华语流行经典',
      '热歌排行榜',
      '欧美流行精选',
      '独立摇滚',
      '清新民谣',
      '律动电子',
      '经典钢琴纯音乐',
      '国风新韵',
    ],
    '华语': [
      '华语经典',
      '流行新声',
      '国风流行',
      '华语独立音乐',
      '华语金曲榜',
      '港台经典',
    ],
    '流行': [
      '热门流行歌曲',
      '欧美流行精选',
      '流行热歌',
      '都市流行',
      '轻快流行律动',
      '流行民谣',
    ],
    '摇滚': [
      '经典摇滚',
      '摇滚精选老歌',
      '独立摇滚',
      '英伦摇滚',
      '流行摇滚',
      '重低音摇滚',
    ],
    '民谣': [
      '民谣精选',
      '城市民谣',
      '民谣吉他弹唱',
      '民谣诗人',
      '治愈民谣',
      '民谣新声',
    ],
    '电子': [
      '电音精选',
      '电子律动',
      'Synthwave复古合成器',
      'EDM热歌',
      '氛围纯音电子',
      'Future Bass',
    ],
    '古典': [
      '古典交响名曲',
      '经典钢琴独奏',
      '大提琴醇厚古典',
      '莫扎特肖邦精选',
      '浪漫主义古典乐',
      '巴洛克室内乐',
    ],
  };

  /// 清洗歌曲标题，去除 (Live)、[Remix]、- 伴奏 等附加后缀
  static String cleanTitle(String raw) {
    var t = raw.trim();
    // 移除各类括号及其内容
    t = t.replaceAll(RegExp(r'\s*[\(\[（【].*?[\)\]）】]'), '');
    // 移除尾部常见修饰词（如 - 伴奏、- Live等）
    t = t.replaceAll(RegExp(r'\s*-\s*(伴奏|Live|Remix|DJ版|高品质|纯音乐|片段).*$', caseSensitive: false), '');
    return t.trim().toLowerCase();
  }

  /// 核心多样性过滤算法：
  /// 1. ID 唯一性去重；
  /// 2. 封面 URL 严格去重（同一封面最多展示 1 首）；
  /// 3. 歌手频次平滑（同一歌手默认最多展示 maxPerArtist 首，默认 1）；
  /// 4. 标题主干去重（避免 Live、Remix、伴奏版本重复展示）；
  /// 5. 限制最大结果数 maxCount。
  static List<Track> filterDiverseTracks(
    List<Track> rawTracks, {
    int maxCount = 24,
    int maxPerArtist = 1,
  }) {
    final List<Track> result = [];
    final Set<String> seenIds = {};
    final Set<String> seenCovers = {};
    final Map<String, int> artistCounts = {};
    final Set<String> seenTitles = {};

    for (final track in rawTracks) {
      // 1. 基本 ID 去重
      final trackId = track.id.trim();
      if (trackId.isNotEmpty && seenIds.contains(trackId)) {
        continue;
      }

      // 2. 封面 URL 严格去重 (忽略空封面或无效封面)
      final cover = track.coverUrl.trim();
      final hasCover = cover.isNotEmpty && cover.startsWith('http');
      if (hasCover && seenCovers.contains(cover)) {
        continue;
      }

      // 3. 歌手频次平滑
      final artist = track.artist.trim().toLowerCase();
      if (artist.isNotEmpty) {
        final count = artistCounts[artist] ?? 0;
        if (count >= maxPerArtist) {
          continue;
        }
      }

      // 4. 标题主干去重
      final clean = cleanTitle(track.title);
      if (clean.isNotEmpty && seenTitles.contains(clean)) {
        continue;
      }

      // 满足所有多样性要求，加入结果集
      if (trackId.isNotEmpty) seenIds.add(trackId);
      if (hasCover) seenCovers.add(cover);
      if (artist.isNotEmpty) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      }
      if (clean.isNotEmpty) seenTitles.add(clean);
      result.add(track);

      if (result.length >= maxCount) {
        break;
      }
    }

    return result;
  }
}
