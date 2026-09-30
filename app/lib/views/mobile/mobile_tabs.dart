import 'dart:math';
import 'package:flutter/material.dart';
import '../../design_system/mellow_image.dart';
import '../../design_system/mellow_logo.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/soft_button.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track_model.dart';
import '../../core/sources/online_music_service.dart';
import '../../core/sources/scenario_playlist_service.dart';
import '../../core/sources/explore_deduplicator.dart';
import '../common/modals.dart';
import '../common/update_dialog.dart';
import '../../core/services/version_check_service.dart';

/// 1. 移动端 Tab 1: 发现音乐 (MobileDiscoverTab - 1:1 原型复刻)
class MobileDiscoverTab extends StatelessWidget {
  final Function(String pageId, [String? extra]) onNavigatePage;
  final VoidCallback onOpenSearch;

  const MobileDiscoverTab({
    super.key,
    required this.onNavigatePage,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        // 1. 顶部 Header (发现音乐 + Mobile 胶囊 + 白瓷日夜按钮 + 圆角头像)
        _buildHeader(context),
        const SizedBox(height: 14),

        // 2. 全幅药丸圆角搜索框
        _buildSearchPill(context),
        const SizedBox(height: 20),

        // 3. 五大彩色微拟物金刚区大圆角卡片
        _buildKingKongSection(context),
        const SizedBox(height: 26),

        // 4. 专属雷达 · Daily Mixes (1 + 4 不对称网格矩阵)
        _buildDailyMixesRadar(context),
        const SizedBox(height: 26),

        // 5. 新碟与精选专栏 (横向水平滑动卡片流)
        _buildNewAlbumsSection(context),
      ],
    );
  }

  /// 顶部 Header: 发现音乐 + Mobile 胶囊 + 白瓷微拟物凸起按钮 + 圆角用户头像
  Widget _buildHeader(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：发现音乐 + Mobile 浅蓝细描边胶囊
          Row(
            children: [
              Text(
                '发现音乐',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: theme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Mobile',
                  style: TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // 右侧：白瓷微拟物凸起日夜按钮 + 圆角头像
          Row(
            children: [
              // 白瓷微拟物日夜模式切换按钮
              GestureDetector(
                onTap: () => theme.toggleTheme(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.borderColor.withValues(alpha: 0.8), width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.wb_sunny_rounded,
                    color: theme.accentColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 圆角头像
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.accentColor.withValues(alpha: 0.3), width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const MellowImage(
                    url: 'https://p2.music.126.net/cW3ZzXz8q3n2ZpE4I_pG2w==/109951165432654366.jpg',
                    width: 36,
                    height: 36,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 全幅圆角药丸搜索框 (搜索歌曲、歌手、专辑、播客... + 麦克风图标)
  Widget _buildSearchPill(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return GestureDetector(
      onTap: onOpenSearch,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2028) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.borderColor.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: theme.accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '搜索歌曲、歌手、专辑、播客...',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.mic_none_rounded, size: 20, color: theme.textMuted),
          ],
        ),
      ),
    );
  }

  /// 五大彩色微拟物金刚区大圆角微矩形卡片
  Widget _buildKingKongSection(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildKingKongCard(
          context,
          label: '每日推荐',
          icon: Icons.calendar_today_rounded,
          bgColor: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.35) : const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          onTap: () => onNavigatePage('recommend'),
        ),
        _buildKingKongCard(
          context,
          label: '歌单广场',
          icon: Icons.grid_view_rounded,
          bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFDCFCE7),
          iconColor: const Color(0xFF16A34A),
          onTap: () => onNavigatePage('playlists'),
        ),
        _buildKingKongCard(
          context,
          label: '排行榜',
          icon: Icons.leaderboard_rounded,
          bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          onTap: () => onNavigatePage('toplist'),
        ),
        _buildKingKongCard(
          context,
          label: '声音电台',
          icon: Icons.radio_rounded,
          bgColor: isDark ? const Color(0xFF581C87).withValues(alpha: 0.35) : const Color(0xFFF3E8FF),
          iconColor: const Color(0xFF9333EA),
          onTap: () => onNavigatePage('radio'),
        ),
        _buildKingKongCard(
          context,
          label: '私人漫游',
          icon: Icons.podcasts_rounded,
          bgColor: isDark ? const Color(0xFF831843).withValues(alpha: 0.35) : const Color(0xFFFCE7F3),
          iconColor: const Color(0xFFDB2777),
          onTap: () => onNavigatePage('fm'),
        ),
      ],
    );
  }

  Widget _buildKingKongCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = context.watch<ThemeProvider>();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 专属雷达 · Daily Mixes (1 + 4 不对称网格矩阵)
  Widget _buildDailyMixesRadar(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行：左侧“专属雷达 · Daily Mixes”，右侧“更新于 06:00”
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '专属雷达 · Daily Mixes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '更新于 06:00',
              style: TextStyle(
                fontSize: 11,
                color: theme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 不对称矩阵：左侧 1 大卡片 + 右侧 2x2 四张紧凑小卡片
        SizedBox(
          height: 216,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧大卡片 (落日微风 · 私人漫游)
              Expanded(
                child: _buildRadarLargeCard(
                  context,
                  title: '落日微风 · 私人漫游',
                  subtitle: '周杰伦 / 告五人 / M83',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/58/8d/6d/588d6d61-fbac-148a-86bd-0030ce076ac1/23UM1IM57281.rgb.jpg/600x600bb.jpg',
                  onPlay: () {
                    if (player.playlist.isNotEmpty) {
                      player.playTrack(player.playlist[0]);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),

              // 右侧 2x2 紧凑卡片矩阵 (上图下文架构)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRadarMiniCard(
                              context,
                              title: '午夜霓虹',
                              artist: 'M83',
                              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/cb/7b/a9/cb7ba903-b5f1-cc21-90db-7a81b7aa0997/724596951057.jpg/600x600bb.jpg',
                              onPlay: () async {
                                final t = player.playlist.where(
                                  (x) => x.title.contains('Midnight') || x.artist.contains('M83'),
                                ).firstOrNull;
                                if (t != null) {
                                  player.playTrack(t);
                                } else {
                                  final searched = await OnlineMusicService.searchOnlineTracks('Midnight M83', limit: 1);
                                  if (searched.isNotEmpty) player.playTrack(searched.first);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRadarMiniCard(
                              context,
                              title: '慢冷治愈',
                              artist: '梁静茹',
                              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/bf/f0/11/bff01142-f4f0-f9c4-f497-007f43e42783/BD0018-_-_Fall_In_Love_Songs.jpg/600x600bb.jpg',
                              onPlay: () {
                                if (player.playlist.length > 1) {
                                  player.playTrack(player.playlist[1]);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRadarMiniCard(
                              context,
                              title: 'Golden Hour',
                              artist: 'JVKE',
                              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/8d/1a/7b/8d1a7b44-316f-7c7f-4380-935673fb697a/5056167175650.jpg/600x600bb.jpg',
                              onPlay: () {
                                if (player.playlist.length > 2) {
                                  player.playTrack(player.playlist[2]);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRadarMiniCard(
                              context,
                              title: '爱在西元前',
                              artist: '周杰伦',
                              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/8c/47/86/8c47862d-e254-8b49-30cf-d1f05ebba05b/23UM1IM56855.rgb.jpg/600x600bb.jpg',
                              onPlay: () {
                                if (player.playlist.length > 3) {
                                  player.playTrack(player.playlist[3]);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadarLargeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String coverUrl,
    required VoidCallback onPlay,
  }) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderColor.withValues(alpha: 0.6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上部封面 + 右下角悬浮白瓷毛玻璃播放圆钮
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      child: MellowImage(
                        url: coverUrl,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  // 右下角悬浮白色毛玻璃圆形播放按钮
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 底部文字介绍
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarMiniCard(
    BuildContext context, {
    required String title,
    required String artist,
    required String coverUrl,
    required VoidCallback onPlay,
  }) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderColor.withValues(alpha: 0.6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上部封面，内嵌微型播放角标
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MellowImage(
                        url: coverUrl,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black87,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 下部歌名与歌手
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: theme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 新碟与精选专栏 (横向水平滑动卡片流)
  Widget _buildNewAlbumsSection(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final albums = [
      {
        'title': 'Hurry Up, Dreaming',
        'artist': 'M83',
        'year': '2011 · 电子梦幻',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/cb/7b/a9/cb7ba903-b5f1-cc21-90db-7a81b7aa0997/724596951057.jpg/600x600bb.jpg',
      },
      {
        'title': '范特西 Fantasy',
        'artist': '周杰伦',
        'year': '2001 · 华语经典',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/8c/47/86/8c47862d-e254-8b49-30cf-d1f05ebba05b/23UM1IM56855.rgb.jpg/600x600bb.jpg',
      },
      {
        'title': '爱人错过',
        'artist': '告五人',
        'year': '2019 · 独立摇滚',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/10/ba/77/10ba77f4-47ae-8cb6-2913-cf49b78452b5/1..jpg/600x600bb.jpg',
      },
      {
        'title': '静夜琴思',
        'artist': '巫娜',
        'year': '2020 · 东方禅意',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/69/49/61/694961f3-1414-355e-66e4-9649ba13ec55/23UM1IM57770.rgb.jpg/600x600bb.jpg',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '新碟与精选专栏',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => onNavigatePage('playlists'),
              child: Row(
                children: [
                  Text(
                    '全部 48 专',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.textMuted,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: theme.textMuted),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: albums.map((item) {
              return Container(
                width: 124,
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    if (player.playlist.isNotEmpty) {
                      player.playTrack(player.playlist[0]);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            MellowImage(
                              url: item['cover']!,
                              width: 124,
                              height: 124,
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['title']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${item['artist']} · ${item['year']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 2. 移动端 Tab 2: 探索全库 (MobileExploreTab)
class MobileExploreTab extends StatefulWidget {
  final Function(String pageId, [String? extra]) onNavigatePage;
  const MobileExploreTab({super.key, required this.onNavigatePage});

  @override
  State<MobileExploreTab> createState() => _MobileExploreTabState();
}

class _MobileExploreTabState extends State<MobileExploreTab> with SingleTickerProviderStateMixin {
  String _currentTag = '全部';
  final List<String> _tags = ['全部', '华语', '流行', '摇滚', '民谣', '电子', '古典'];
  List<Track> _tracks = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  late AnimationController _refreshAnimController;

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadExploreTracks(_currentTag);
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadExploreTracks(String tag, {bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() => _isRefreshing = true);
      _refreshAnimController.repeat();
    } else {
      setState(() {
        _isLoading = true;
        _tracks = [];
      });
    }

    try {
      final subQueries = List<String>.from(ExploreDeduplicator.genreKeywords[tag] ?? [tag]);
      subQueries.shuffle(Random());
      // 选取前 2~3 个子关键词并发拉取以保证曲库广度
      final selectedQueries = subQueries.take(3).toList();

      final futures = selectedQueries.map((q) => OnlineMusicService.searchOnlineTracks(q, limit: 16));
      final nestedResults = await Future.wait(futures);

      // 交错洗牌合并结果池
      final List<Track> combined = [];
      int maxLen = 0;
      for (final list in nestedResults) {
        if (list.length > maxLen) maxLen = list.length;
      }
      for (int i = 0; i < maxLen; i++) {
        for (final list in nestedResults) {
          if (i < list.length) {
            combined.add(list[i]);
          }
        }
      }

      // 执行多维度去重：同封面过滤、同歌手频次限制1首、标题主干去重
      final deduped = ExploreDeduplicator.filterDiverseTracks(
        combined,
        maxCount: 22,
        maxPerArtist: 1,
      );

      if (mounted) {
        setState(() {
          _tracks = deduped;
          _isLoading = false;
          _isRefreshing = false;
        });
        _refreshAnimController.reset();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        _refreshAnimController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return RefreshIndicator(
      onRefresh: () => _loadExploreTracks(_currentTag, refresh: true),
      color: theme.accentColor,
      backgroundColor: theme.cardColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
        children: [
          // 1. 顶部 Header 与换一批按键
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '探索音乐全库',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: theme.textPrimary, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '多元声学流派 · 场景精选与风格雷达',
                      style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 换一批按键
              GestureDetector(
                onTap: _isRefreshing ? null : () => _loadExploreTracks(_currentTag, refresh: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: MellowRadii.borderPill,
                    border: Border.all(color: theme.borderColor.withValues(alpha: 0.6), width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: theme.isDarkMode ? 0.25 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: _refreshAnimController,
                        child: Icon(Icons.refresh_rounded, size: 14, color: theme.accentColor),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '换一批',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. 风格流派横向选择器
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _tags.map((tag) {
                final isSel = _currentTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SoftButton(
                    label: tag,
                    isActive: isSel,
                    isPill: true,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    onTap: () {
                      if (_currentTag == tag) return;
                      setState(() => _currentTag = tag);
                      _loadExploreTracks(tag);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // 3. 精选场景歌单推荐专区 (横向滑动卡片)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 13,
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '场景歌单推荐',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: theme.textPrimary),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => widget.onNavigatePage('scenarios'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '全部场景',
                      style: TextStyle(fontSize: 11.5, color: theme.accentColor, fontWeight: FontWeight.w600),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: theme.accentColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: ScenarioPlaylistService.presetScenarios.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final scenario = ScenarioPlaylistService.presetScenarios[idx];
                return GestureDetector(
                  onTap: () => widget.onNavigatePage('scenarios'),
                  child: Container(
                    width: 142,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: scenario.gradient.map((c) => c.withValues(alpha: theme.isDarkMode ? 0.78 : 0.88)).toList(),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: MellowRadii.borderR16,
                      boxShadow: [
                        BoxShadow(
                          color: scenario.gradient.first.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(scenario.icon, color: Colors.white, size: 16),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scenario.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              scenario.description,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 9.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          // 4. 流派精选单曲网格标题与状态
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 13,
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_currentTag 精选风格单曲',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: theme.textPrimary),
                  ),
                ],
              ),
              if (_tracks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.12),
                    borderRadius: MellowRadii.borderPill,
                  ),
                  child: Text(
                    '多样性精选 · ${_tracks.length} 首',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.accentColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. 单曲网格列表或加载中
          if (_isLoading && _tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor)),
                    const SizedBox(height: 12),
                    Text(
                      '正在汇集多元声学曲目...',
                      style: TextStyle(fontSize: 12, color: theme.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else if (_tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_off_rounded, size: 40, color: theme.textMuted),
                    const SizedBox(height: 8),
                    Text('暂无推荐曲目', style: TextStyle(fontSize: 13, color: theme.textMuted)),
                    const SizedBox(height: 10),
                    SoftButton(
                      label: '重试刷新',
                      onTap: () => _loadExploreTracks(_currentTag),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.77,
              ),
              itemCount: _tracks.length,
              itemBuilder: (context, idx) {
                final t = _tracks[idx];
                final isCurrent = player.currentTrack?.id == t.id;

                return SoftCard(
                  padding: const EdgeInsets.all(9),
                  onTap: () => player.playTrack(t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: MellowImage(
                                url: t.coverUrl,
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: MellowRadii.borderR12,
                              ),
                            ),
                            // 当前正在播放微标签或悬浮播放按钮
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isCurrent ? theme.accentColor : Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isCurrent && player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.title,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12.5,
                          color: isCurrent ? theme.accentColor : theme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.artist,
                        style: TextStyle(fontSize: 11, color: theme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 3. 移动端 Tab 3: 我的资料库 (MobileLibraryTab)
class MobileLibraryTab extends StatelessWidget {
  final Function(String pageId, [String? extra]) onNavigatePage;
  const MobileLibraryTab({super.key, required this.onNavigatePage});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final favCount = player.favoriteTracks.isNotEmpty
        ? player.favoriteTracks.length
        : player.favoriteIds.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('我的音乐资料库', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 16),

        // 核心分类入口行
        Row(
          children: [
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                onTap: () => onNavigatePage('local'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.folder_special_rounded, color: theme.accentColor, size: 28),
                    const SizedBox(height: 10),
                    Text('本地与下载', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                    Text('离线音乐管理', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                onTap: () => onNavigatePage('artists'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Color(0xFF8B5CF6), size: 28),
                    const SizedBox(height: 10),
                    Text('关注歌手', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                    Text('4 位入驻音乐人', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 局域网多端同步快捷入口
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: MellowRadii.borderR16,
          onTap: () => showDialog(
            context: context,
            builder: (_) => const LanPairingModal(),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cell_tower_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('局域网多端同步中心', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('与 macOS / Windows 桌面端近场直连互传', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 我喜欢的音乐卡片
        SoftCard(
          padding: const EdgeInsets.all(16),
          onTap: () => onNavigatePage('favorites'),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF472B6)]),
                  borderRadius: MellowRadii.borderR16,
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我喜欢的音乐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('已收藏 $favCount 首心动单曲', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: theme.accentColor, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 自建与导入歌单区域
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('自建与收藏歌单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const CreatePlaylistModal(),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: theme.accentColor),
                        const SizedBox(width: 2),
                        Text('新建', style: TextStyle(color: theme.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const ImportPlaylistModal(),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.borderColor.withValues(alpha: 0.5),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_link_rounded, size: 14, color: theme.textSecondary),
                        const SizedBox(width: 2),
                        Text('导入', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (player.importedPlaylists.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.library_music_rounded, size: 36, color: theme.textMuted),
                  const SizedBox(height: 8),
                  Text('暂无自建或导入歌单', style: TextStyle(fontSize: 13, color: theme.textMuted)),
                  const SizedBox(height: 12),
                  SoftButton(
                    label: '新建自建歌单',
                    icon: Icons.add_rounded,
                    isActive: true,
                    isPill: true,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const CreatePlaylistModal(),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final pl in player.importedPlaylists)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                onTap: () => player.playPlaylist(pl.tracks),
                child: Row(
                  children: [
                    MellowImage(url: pl.coverUrl, width: 50, height: 50, borderRadius: MellowRadii.borderR12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pl.title,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (pl.isCustom ? theme.accentColor : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                                  borderRadius: MellowRadii.borderPill,
                                ),
                                child: Text(
                                  pl.isCustom ? '自建' : '导入',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: pl.isCustom ? theme.accentColor : const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('包含 ${pl.trackCount} 首曲目', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.play_circle_fill_rounded, color: theme.accentColor, size: 26),
                      onPressed: () => player.playPlaylist(pl.tracks),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: theme.textMuted, size: 18),
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: MellowRadii.borderR12),
                      onSelected: (action) {
                        if (action == 'delete') {
                          player.deletePlaylist(pl.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已删除歌单「${pl.title}」')),
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('删除歌单', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// 4. 移动端 Tab 4: 个人与设置中心 (MobileProfileTab)
class MobileProfileTab extends StatelessWidget {
  const MobileProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // 用户卡片
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const MellowAvatar(
                radius: 28,
                url: 'https://p2.music.126.net/L3cE6x8y2g6n7Q0o4w0z_g==/109951165123987114.jpg',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Mellow 音乐探索家', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textPrimary)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.accentColor,
                            borderRadius: MellowRadii.borderR8,
                          ),
                          child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('享受温润微质感 · 声学生态已连接', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 主题切换卡片
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('界面主题与质感', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: theme.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '温润白瓷',
                      icon: Icons.light_mode_rounded,
                      isActive: !isDark,
                      onTap: () => theme.setDarkMode(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftButton(
                      label: '深石墨夜间',
                      icon: Icons.dark_mode_rounded,
                      isActive: isDark,
                      onTap: () => theme.setDarkMode(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 强调色选择
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('声学柔光主色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: theme.textPrimary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: AccentColorType.values.map((type) {
                  final isSelected = theme.accentType == type;
                  return GestureDetector(
                    onTap: () => theme.setAccentType(type),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: type.getColor(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: type.getColor(isDark).withValues(alpha: 0.35), blurRadius: 8),
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 多端协同与系统功能
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('多端协同与系统', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: theme.textPrimary)),
              const SizedBox(height: 12),
              SoftButton(
                icon: Icons.cell_tower_rounded,
                label: '局域网多端同步中心',
                isPill: false,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const LanPairingModal(),
                ),
              ),
              const SizedBox(height: 10),
              SoftButton(
                icon: Icons.system_update_alt_rounded,
                label: '检查新版本更新',
                isPill: false,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final service = VersionCheckService();
                    final newVersion = await service.checkLatestVersion();
                    if (!context.mounted) return;
                    if (newVersion != null) {
                      await UpdateDialog.show(context, newVersion);
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('已是最新版本 (v${service.currentVersionName})'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('检查更新失败: $e'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const MellowBrandLogo(size: 44, borderRadius: 12, showGlow: true),
              const SizedBox(height: 8),
              Text('Mellow Music · 润音', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary)),
              const SizedBox(height: 4),
              Text('Modern Soft UI 全平台温润声学音乐播放器', style: TextStyle(fontSize: 11, color: theme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
