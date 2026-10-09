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
import '../../core/sources/daily_recommend_service.dart';
import '../common/modals.dart';
import '../common/update_dialog.dart';
import '../../core/services/version_check_service.dart';

/// 1. 移动端 Tab 1: 发现音乐 (MobileDiscoverTab - 1:1 原型复刻)
class MobileDiscoverTab extends StatefulWidget {
  final Function(String pageId, [String? extra]) onNavigatePage;
  final VoidCallback onOpenSearch;

  const MobileDiscoverTab({
    super.key,
    required this.onNavigatePage,
    required this.onOpenSearch,
  });

  @override
  State<MobileDiscoverTab> createState() => _MobileDiscoverTabState();
}

class _MobileDiscoverTabState extends State<MobileDiscoverTab> {
  List<ImportedPlaylist> _curatedPlaylists = [];
  bool _isLoadingPlaylists = true;

  @override
  void initState() {
    super.initState();
    // 预热今日推荐曲库与甄选歌单推荐
    DailyRecommendService.instance.getDailyRecommendTracksAsync();
    _initCuratedPlaylists();
  }

  void _initCuratedPlaylists() async {
    final mockFallback = [
      ImportedPlaylist(
        id: 'netease_3778678',
        title: '云音乐热歌榜 · 甄选精选集',
        coverUrl: 'https://p1.music.126.net/GhhuF6Ep5Tq9IEvLndCN6w==/18708190348409091.jpg',
        description: '全网超高人气的甄选流行歌曲，随旋律开启沉浸心流',
        trackCount: 200,
        tracks: getAllKnownTracks(),
      ),
      ImportedPlaylist(
        id: 'netease_3779629',
        title: '新歌风向标 · 官方新碟首发',
        coverUrl: 'https://p1.music.126.net/N2HO5xfYEqyvEiqJvAueQQ==/18740076185638788.jpg',
        description: '甄选每周最新华语高保真单曲与原创佳作',
        trackCount: 100,
        tracks: getAllKnownTracks().reversed.toList(),
      ),
      ImportedPlaylist(
        id: 'netease_2884035',
        title: '宝藏原创榜 · 独立声学精粹',
        coverUrl: 'https://p1.music.126.net/sBzD11nforcuh1jdLSgX7g==/18740076185638788.jpg',
        description: '挖掘极具生命力的小众优质旋律与好声音',
        trackCount: 100,
        tracks: getAllKnownTracks(),
      ),
      ImportedPlaylist(
        id: 'netease_19723756',
        title: '官方飙升榜 · 今日潮流热浪',
        coverUrl: 'https://p1.music.126.net/DrrB9-Kq-4bKHgU4s_kOyw==/18740076185638788.jpg',
        description: '100首每日急速上升的潜质金曲与爆款',
        trackCount: 98,
        tracks: getAllKnownTracks(),
      ),
    ];

    if (mounted) {
      setState(() {
        _curatedPlaylists = mockFallback;
        _isLoadingPlaylists = false;
      });
    }

    try {
      final fetched = await OnlineMusicService.searchOnlinePlaylists('精选', limit: 6);
      if (fetched.isNotEmpty && mounted) {
        setState(() {
          _curatedPlaylists = fetched;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DailyRecommendService.instance,
      builder: (context, _) {
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

            // 4. 每日推荐专区 (替代原专属雷达，点播放按钮播放全部歌曲)
            _buildDailyRecommendSection(context),
            const SizedBox(height: 26),

            // 5. 甄选歌单推荐 (替代原新碟专栏，与PC端完全一致，支持下钻与一键播放)
            _buildCuratedPlaylistsSection(context),
          ],
        );
      },
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
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
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
      onTap: widget.onOpenSearch,
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
          onTap: () => widget.onNavigatePage('recommend'),
        ),
        _buildKingKongCard(
          context,
          label: '歌单广场',
          icon: Icons.grid_view_rounded,
          bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFDCFCE7),
          iconColor: const Color(0xFF16A34A),
          onTap: () => widget.onNavigatePage('playlists'),
        ),
        _buildKingKongCard(
          context,
          label: '排行榜',
          icon: Icons.leaderboard_rounded,
          bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          onTap: () => widget.onNavigatePage('toplist'),
        ),
        _buildKingKongCard(
          context,
          label: '声音电台',
          icon: Icons.radio_rounded,
          bgColor: isDark ? const Color(0xFF581C87).withValues(alpha: 0.35) : const Color(0xFFF3E8FF),
          iconColor: const Color(0xFF9333EA),
          onTap: () => widget.onNavigatePage('radio'),
        ),
        _buildKingKongCard(
          context,
          label: '热门歌手',
          icon: Icons.people_alt_rounded,
          bgColor: isDark ? const Color(0xFF831843).withValues(alpha: 0.35) : const Color(0xFFFCE7F3),
          iconColor: const Color(0xFFDB2777),
          onTap: () => widget.onNavigatePage('artists'),
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

  /// 每日推荐 · Daily Recommend (1 + 4 不对称网格矩阵 + 一键播放全部)
  Widget _buildDailyRecommendSection(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final dailyService = DailyRecommendService.instance;
    final tracks = dailyService.getDailyRecommendTracks(limit: 30);

    final primaryTrack = tracks.isNotEmpty ? tracks[0] : null;
    final subTracks = tracks.length > 1 ? tracks.sublist(1, tracks.length >= 5 ? 5 : tracks.length) : <Track>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行：左侧“每日推荐 · Daily Recommend”，右侧微拟物“播放全部”按钮与更新时间
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onNavigatePage('recommend'),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '每日推荐 · Daily Recommend',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: theme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 播放全部微拟物药丸按钮 (MOB-041 播放歌单内全部歌曲)
            GestureDetector(
              onTap: () {
                if (tracks.isNotEmpty) {
                  player.playPlaylist(tracks, startIndex: 0);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.accentColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 15, color: theme.accentColor),
                    const SizedBox(width: 3),
                    Text(
                      '播放全部',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: theme.accentColor,
                      ),
                    ),
                  ],
                ),
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
              // 左侧大卡片 (首推单曲，点击直接播放全部)
              Expanded(
                child: _buildDailyLargeCard(
                  context,
                  track: primaryTrack,
                  onPlay: () {
                    if (tracks.isNotEmpty) {
                      player.playPlaylist(tracks, startIndex: 0);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),

              // 右侧 2x2 紧凑小卡片矩阵 (点击精准播放对应项并把全部30首推入队列)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDailyMiniCard(
                              context,
                              track: subTracks.isNotEmpty ? subTracks[0] : null,
                              onPlay: () {
                                if (tracks.length > 1) {
                                  player.playPlaylist(tracks, startIndex: 1);
                                } else if (tracks.isNotEmpty) {
                                  player.playPlaylist(tracks, startIndex: 0);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDailyMiniCard(
                              context,
                              track: subTracks.length > 1 ? subTracks[1] : null,
                              onPlay: () {
                                if (tracks.length > 2) {
                                  player.playPlaylist(tracks, startIndex: 2);
                                } else if (tracks.isNotEmpty) {
                                  player.playPlaylist(tracks, startIndex: 0);
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
                            child: _buildDailyMiniCard(
                              context,
                              track: subTracks.length > 2 ? subTracks[2] : null,
                              onPlay: () {
                                if (tracks.length > 3) {
                                  player.playPlaylist(tracks, startIndex: 3);
                                } else if (tracks.isNotEmpty) {
                                  player.playPlaylist(tracks, startIndex: 0);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDailyMiniCard(
                              context,
                              track: subTracks.length > 3 ? subTracks[3] : null,
                              onPlay: () {
                                if (tracks.length > 4) {
                                  player.playPlaylist(tracks, startIndex: 4);
                                } else if (tracks.isNotEmpty) {
                                  player.playPlaylist(tracks, startIndex: 0);
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

  Widget _buildDailyLargeCard(
    BuildContext context, {
    required Track? track,
    required VoidCallback onPlay,
  }) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final title = track?.title ?? '今日推荐曲目';
    final String subtitle;
    if (track == null) {
      subtitle = '智能汇集今日灵感音乐';
    } else {
      final a = track.artist.trim();
      final alb = track.album.trim();
      subtitle = (alb.isEmpty || alb == a || alb.contains(a)) ? a : '$a · $alb';
    }
    final coverUrl = track?.coverUrl ?? '';

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
                      child: coverUrl.isNotEmpty
                          ? MellowImage(
                              url: coverUrl,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: theme.accentColor.withValues(alpha: 0.1),
                              child: Icon(Icons.music_note_rounded, size: 40, color: theme.accentColor),
                            ),
                    ),
                  ),
                  // 右下角悬浮白色毛玻璃圆形播放按钮
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
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
                        size: 22,
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

  Widget _buildDailyMiniCard(
    BuildContext context, {
    required Track? track,
    required VoidCallback onPlay,
  }) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final title = track?.title ?? '精选推荐';
    final artist = track?.artist ?? '未知歌手';
    final coverUrl = track?.coverUrl ?? '';

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
                      child: coverUrl.isNotEmpty
                          ? MellowImage(
                              url: coverUrl,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: theme.accentColor.withValues(alpha: 0.1),
                              child: Icon(Icons.music_note_rounded, size: 20, color: theme.accentColor),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
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
                        size: 14,
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

  /// 甄选歌单推荐 (对齐 PC 端设计语言，横滑瀑布流卡片 + 悬浮白瓷播放圆钮 + 下钻全量详情)
  Widget _buildCuratedPlaylistsSection(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final playlists = _curatedPlaylists.isNotEmpty
        ? _curatedPlaylists
        : player.importedPlaylists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onNavigatePage('playlists'),
              child: Row(
                children: [
                  Text(
                    '甄选歌单推荐',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: theme.textMuted),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onNavigatePage('playlists'),
              child: Row(
                children: [
                  Text(
                    '查看全部 >',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingPlaylists && playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(playlists.length, (idx) {
                final item = playlists[idx];
                final desc = item.description.isNotEmpty
                    ? item.description
                    : '甄选推荐歌单 · ${item.trackCount > 0 ? item.trackCount : (item.tracks.isNotEmpty ? item.tracks.length : 30)}首';

                return Container(
                  width: 136,
                  margin: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // 接入 MobileScaffold 子栈，保持顶部灵动岛与底部 MiniPlayer 持续驻留
                      widget.onNavigatePage(
                        'playlist_detail',
                        'playlist:::${item.id}:::${item.title}:::${item.coverUrl}:::$desc',
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              MellowImage(
                                url: item.coverUrl,
                                width: 136,
                                height: 136,
                              ),
                              // 右下角悬浮白瓷毛玻璃圆形播放按钮
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: GestureDetector(
                                  key: Key('curated_playlist_play_$idx'),
                                  onTap: () async {
                                    if (item.tracks.isNotEmpty) {
                                      player.playPlaylist(item.tracks, startIndex: 0);
                                    } else {
                                      final detail = await OnlineMusicService.importNeteasePlaylist(item.id);
                                      if (detail != null && detail.tracks.isNotEmpty) {
                                        player.playPlaylist(detail.tracks, startIndex: 0);
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.95),
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
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
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
                          desc,
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
                );
              }),
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
  final Map<String, int> _tagPageMap = {};
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
      _tagPageMap[tag] = (_tagPageMap[tag] ?? 1) + 1;
      setState(() => _isRefreshing = true);
      _refreshAnimController.repeat();
    } else {
      _tagPageMap.putIfAbsent(tag, () => 1);
      setState(() {
        _isLoading = true;
        _tracks = [];
      });
    }

    final currentPage = _tagPageMap[tag] ?? 1;

    try {
      final subQueries = List<String>.from(ExploreDeduplicator.genreKeywords[tag] ?? [tag]);
      subQueries.shuffle(Random());
      // 选取前 2~3 个子关键词并发拉取以保证曲库广度
      final selectedQueries = subQueries.take(3).toList();

      final futures = selectedQueries.map((q) => OnlineMusicService.searchOnlineTracks(q, page: currentPage, limit: 16));
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

      final allKnown = getAllKnownTracks();
      final offset = allKnown.isNotEmpty ? ((currentPage - 1) * 8) % allKnown.length : 0;
      final rotated = allKnown.isNotEmpty ? [...allKnown.sublist(offset), ...allKnown.sublist(0, offset)] : allKnown;
      final fallback = rotated.take(22).toList();

      final finalTracks = deduped.isNotEmpty ? deduped : fallback;
      if (mounted) {
        setState(() {
          _tracks = finalTracks;
          _isLoading = false;
          _isRefreshing = false;
        });
        _refreshAnimController.reset();
      }
    } catch (_) {
      final allKnown = getAllKnownTracks();
      final offset = allKnown.isNotEmpty ? ((currentPage - 1) * 8) % allKnown.length : 0;
      final rotated = allKnown.isNotEmpty ? [...allKnown.sublist(offset), ...allKnown.sublist(0, offset)] : allKnown;
      final fallback = rotated.take(22).toList();
      if (mounted) {
        setState(() {
          _tracks = fallback;
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

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
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
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onNavigatePage('scenarios'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    child: Stack(
                      children: [
                        Column(
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
                        // 场景右上角一键播放全部歌曲按钮
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                final playlists = await ScenarioPlaylistService.instance.searchScenarioPlaylists(scenario.primaryKeyword, limit: 1);
                                if (playlists.isNotEmpty && playlists.first.tracks.isNotEmpty) {
                                  player.playPlaylist(playlists.first.tracks, startIndex: 0);
                                  return;
                                }
                              } catch (_) {}
                              try {
                                final tracks = await OnlineMusicService.searchOnlineTracks(scenario.primaryKeyword, limit: 15);
                                if (tracks.isNotEmpty) {
                                  player.playPlaylist(tracks, startIndex: 0);
                                }
                              } catch (_) {}
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                            ),
                          ),
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
              Expanded(
                child: Row(
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
                    Flexible(
                      child: Text(
                        '$_currentTag 精选风格单曲',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: theme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_tracks.isNotEmpty)
                SoftButton(
                  icon: Icons.play_arrow_rounded,
                  label: '一键播放',
                  isPill: true,
                  isActive: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  onTap: () {
                    if (_tracks.isNotEmpty) {
                      player.playPlaylist(_tracks, startIndex: 0);
                    }
                  },
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
                  onTap: () => player.playPlaylist(_tracks, startIndex: idx),
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
                              child: GestureDetector(
                                onTap: () {
                                  if (isCurrent) {
                                    player.togglePlay();
                                  } else {
                                    player.playPlaylist(_tracks, startIndex: idx);
                                  }
                                },
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
                onTap: () => onNavigatePage('history'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 28),
                    const SizedBox(height: 10),
                    Text('播放历史', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                    Text('最近播放 · ${context.watch<AudioPlayerService>().playHistory.length} 首', style: TextStyle(fontSize: 11, color: theme.textMuted)),
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (player.favoriteTracks.isNotEmpty) {
                    player.playPlaylist(player.favoriteTracks, startIndex: 0);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('暂无收藏歌曲，快去探索并添加心动单曲吧'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: theme.accentColor, size: 22),
                ),
              ),
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
class MobileProfileTab extends StatefulWidget {
  const MobileProfileTab({super.key});

  @override
  State<MobileProfileTab> createState() => _MobileProfileTabState();
}

class _MobileProfileTabState extends State<MobileProfileTab> {
  bool _isCheckingUpdateMobile = false;

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
                      label: '跟随系统',
                      icon: Icons.brightness_auto_rounded,
                      isActive: theme.appThemeMode == AppThemeMode.system,
                      onTap: () => theme.setThemeMode(AppThemeMode.system),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SoftButton(
                      label: '温润白瓷',
                      icon: Icons.light_mode_rounded,
                      isActive: theme.appThemeMode == AppThemeMode.light,
                      onTap: () => theme.setThemeMode(AppThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SoftButton(
                      label: '深石墨黑',
                      icon: Icons.dark_mode_rounded,
                      isActive: theme.appThemeMode == AppThemeMode.dark,
                      onTap: () => theme.setThemeMode(AppThemeMode.dark),
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const LanPairingModal(),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: theme.isDarkMode ? 0.6 : 0.9),
                    borderRadius: MellowRadii.borderR16,
                    border: Border.all(color: theme.borderColor.withValues(alpha: 0.5), width: 0.8),
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
                      Icon(Icons.chevron_right_rounded, size: 20, color: theme.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setTileState) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isCheckingUpdateMobile
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setTileState(() => _isCheckingUpdateMobile = true);
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
                                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 85),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('检查更新失败: $e'),
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 85),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setTileState(() => _isCheckingUpdateMobile = false);
                              }
                            }
                          },
                    onLongPress: () async {
                      try {
                        final service = VersionCheckService();
                        final mockVersion = await service.checkLatestVersion(forceMock: true);
                        if (!context.mounted) return;
                        if (mockVersion != null) {
                          await UpdateDialog.show(context, mockVersion);
                        }
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: theme.isDarkMode ? 0.6 : 0.9),
                        borderRadius: MellowRadii.borderR16,
                        border: Border.all(color: theme.borderColor.withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _isCheckingUpdateMobile
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: theme.accentColor,
                                    ),
                                  )
                                : Icon(Icons.system_update_alt_rounded, color: theme.accentColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCheckingUpdateMobile ? '正在检测最新版本...' : '检查新版本更新',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isCheckingUpdateMobile ? '正在连接高可用镜像源并比对版本...' : '检测 GitHub Releases 最新稳定版本',
                                  style: TextStyle(fontSize: 11, color: theme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (!_isCheckingUpdateMobile)
                            Icon(Icons.chevron_right_rounded, size: 20, color: theme.textMuted),
                        ],
                      ),
                    ),
                  );
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
