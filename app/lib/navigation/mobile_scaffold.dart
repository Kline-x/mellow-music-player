import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/tokens.dart';
import '../design_system/theme_provider.dart';
import '../design_system/acoustic_mesh_glow.dart';
import '../design_system/mellow_image.dart';
import '../core/audio/audio_player_service.dart';
import '../core/audio/track_model.dart';
import '../views/mobile/mobile_tabs.dart';
import '../views/mobile/mobile_pages.dart';
import '../views/mobile/mobile_sheets.dart';

/// 移动端应用脚手架 (MobileScaffold)
class MobileScaffold extends StatefulWidget {
  const MobileScaffold({super.key});

  @override
  State<MobileScaffold> createState() => _MobileScaffoldState();
}

class _MobileScaffoldState extends State<MobileScaffold> {
  int _currentTab = 0;
  String? _subPageId;
  String? _subPageParam;

  void _navigateToPage(String pageId, [String? extra]) {
    setState(() {
      _subPageId = pageId;
      _subPageParam = extra;
    });
  }

  void _popSubPage() {
    setState(() {
      _subPageId = null;
      _subPageParam = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    // 如果处于二级页面状态，优先渲染二级页
    if (_subPageId != null) {
      return _buildSubPage();
    }

    return Scaffold(
      backgroundColor: theme.canvasColor,
      body: Stack(
        children: [
          // 全局弥散光晕背景
          const Positioned.fill(child: AcousticMeshGlow()),

          // 主体 Tab 页面
          SafeArea(
            child: Column(
              children: [
                // 顶部灵动岛状态栏
                _buildDynamicIslandHeader(context),

                // 4-Tab 视图切换
                Expanded(
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      MobileDiscoverTab(
                        onNavigatePage: _navigateToPage,
                        onOpenSearch: () => _navigateToPage('search'),
                      ),
                      MobileExploreTab(onNavigatePage: _navigateToPage),
                      MobileLibraryTab(onNavigatePage: _navigateToPage),
                      const MobileProfileTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 底部悬浮毛玻璃迷你播放条 (嵌 2px 极细实时播放进度条)
          _buildFloatingMiniPlayer(context),

          // 底部原生 4-Tab 毛玻璃导航栏
          _buildBottomTabBar(context),
        ],
      ),
    );
  }

  /// 顶部灵动岛状态栏 (Dynamic Island Header)
  Widget _buildDynamicIslandHeader(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final track = player.currentTrack ?? mockPresetTracks[0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Center(
        child: GestureDetector(
          key: const Key('dynamic_island_capsule'),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => MobilePlayerBottomSheet(onClose: () => Navigator.of(context).pop()),
            );
          },
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 跳动音频频谱 3 根竖线
                _buildDynamicIslandSpectrum(player.isPlaying, theme.accentColor),
                const SizedBox(width: 8),
                // 当前歌曲标题
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 播放小三角
                Icon(
                  player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: theme.accentColor,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 灵动岛频谱律动指示器
  Widget _buildDynamicIslandSpectrum(bool isPlaying, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 2.2,
          height: isPlaying ? 12 : 5,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 2.2),
        Container(
          width: 2.2,
          height: isPlaying ? 16 : 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 2.2),
        Container(
          width: 2.2,
          height: isPlaying ? 9 : 4,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      ],
    );
  }

  /// 底部悬浮毛玻璃胶囊播放条 (带 2px 极细实时进度条与红心收藏)
  Widget _buildFloatingMiniPlayer(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final track = player.currentTrack ?? mockPresetTracks[0];
    final isFav = player.isFavorite(track.id);

    final totalMs = player.duration.inMilliseconds;
    final currMs = player.position.inMilliseconds;
    final progress = (totalMs > 0) ? (currMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Positioned(
      left: 14,
      right: 14,
      bottom: 72,
      child: GestureDetector(
        key: const Key('mini_player_pill'),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MobilePlayerBottomSheet(onClose: () => Navigator.of(context).pop()),
          );
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: theme.borderColor.withValues(alpha: 0.6), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: theme.isDarkMode ? 0.35 : 0.1),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 嵌入式 2px 极细微播放进度条
              SizedBox(
                height: 2.2,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.borderColor.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  children: [
                    // 正方形专辑封面
                    MellowImage(
                      url: track.coverUrl,
                      width: 38,
                      height: 38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(width: 10),
                    // 歌名与歌手
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: theme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    // 心标收藏 (红心)
                    IconButton(
                      key: const Key('mini_player_fav_button'),
                      icon: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? const Color(0xFFEF4444) : theme.textMuted,
                        size: 20,
                      ),
                      onPressed: () => player.toggleFavorite(track.id),
                      visualDensity: VisualDensity.compact,
                    ),
                    // 实心圆形主色播放/暂停按钮
                    GestureDetector(
                      key: const Key('mini_player_play_button'),
                      onTap: () => player.togglePlay(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 下一首按钮
                    IconButton(
                      key: const Key('mini_player_next_button'),
                      icon: const Icon(Icons.skip_next_rounded, size: 22),
                      color: theme.textSecondary,
                      onPressed: () => player.next(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部毛玻璃 4-Tab 原生触控导航栏
  Widget _buildBottomTabBar(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: MellowColors.canvas(isDark).withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: theme.borderColor.withValues(alpha: 0.5), width: 0.8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabButton(0, '发现', Icons.explore_rounded),
            _buildTabButton(1, '探索', Icons.grid_view_rounded),
            _buildTabButton(2, '资料库', Icons.library_music_rounded),
            _buildTabButton(3, '我的', Icons.person_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final theme = context.watch<ThemeProvider>();
    final isSelected = _currentTab == index;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: isSelected
                  ? BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Icon(icon, color: isSelected ? theme.accentColor : theme.textMuted, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? theme.accentColor : theme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubPage() {
    switch (_subPageId) {
      case 'search':
        return MobileSearchPage(onBack: _popSubPage);
      case 'recommend':
        return MobileDailyRecommendPage(onBack: _popSubPage);
      case 'fm':
        return MobilePersonalFMPage(onBack: _popSubPage);
      case 'playlists':
        return MobilePlaylistSquarePage(onBack: _popSubPage);
      case 'toplist':
        return MobileToplistPage(onBack: _popSubPage);
      case 'radio':
        return MobileRadioPage(onBack: _popSubPage);
      case 'artists':
        return MobileArtistsPage(onBack: _popSubPage, onSelectArtist: (name) => _navigateToPage('artist_detail', name));
      case 'artist_detail':
        return MobileArtistDetailPage(artistName: _subPageParam ?? '巫娜', onBack: _popSubPage);
      case 'local':
        return MobileLocalMusicPage(onBack: _popSubPage);
      default:
        return MobileDailyRecommendPage(onBack: _popSubPage);
    }
  }
}
