import 'dart:math';
import '../audio/track_model.dart';

/// 每日专属推荐曲库引擎 (基于自然日期生成高保真推荐池与动态问候语)
class DailyRecommendService {
  static final DailyRecommendService instance = DailyRecommendService._internal();
  DailyRecommendService._internal();

  /// 获取当前动态问候语
  String getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 5 && hour < 11) {
      return '早安 · 晨光清冽，愿美妙旋律唤醒一整天的好心情';
    } else if (hour >= 11 && hour < 14) {
      return '午安 · 阳光温热，在慵懒午后邂逅动听音符';
    } else if (hour >= 14 && hour < 18) {
      return '午后漫步 · 惬意茶歇，让灵动节奏抚平疲惫';
    } else if (hour >= 18 && hour < 22) {
      return '晚安 · 暮色渐浓，把一天的烦扰融化在清音里';
    } else {
      return '夜深了 · 华灯初歇，戴上耳机享受独属于你的纯净静谧';
    }
  }

  /// 获取当天格式化日期标签
  String getFormattedDay() {
    final now = DateTime.now();
    return now.day.toString().padLeft(2, '0');
  }

  /// 获取星期标签
  String getFormattedWeekday() {
    final now = DateTime.now();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[now.weekday - 1];
  }

  /// 获取月份与年份标签
  String getFormattedMonthYear() {
    final now = DateTime.now();
    return '${now.year}年${now.month}月';
  }

  /// 依据当天日期确定性生成 25~30 首高保真每日推荐单曲
  List<Track> getDailyRecommendTracks({int limit = 28}) {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);

    // 基础高质量候选曲目池（包含预设精选与全平台核心真实曲目）
    final allCandidates = <Track>[
      ...mockPresetTracks,
      ...mockJayChouTracks,
      ...mockWuNaTracks,
      ...mockBeyondTracks,
      ...mockBoYuanTracks,
      ...toplistSurgeTracks,
      ...toplistHotTracks,
      ...toplistNewTracks,
      ...toplistOriginTracks,
    ];

    // 按标题和歌手去重
    final uniqueMap = <String, Track>{};
    for (final t in allCandidates) {
      final key = '${t.title.trim()}_${t.artist.trim()}';
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = t;
      }
    }
    final pool = uniqueMap.values.toList();

    // 根据当日种子进行伪随机打乱排序，保证每天同一天内稳定相同，次日自动焕新
    pool.shuffle(random);

    return pool.take(limit.clamp(1, pool.length)).toList();
  }
}
