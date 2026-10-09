import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../design_system/tokens.dart';
import '../design_system/theme_provider.dart';
import '../design_system/acoustic_mesh_glow.dart';
import '../design_system/mellow_image.dart';
import '../core/audio/audio_player_service.dart';
import '../core/audio/equalizer_manager.dart';
import '../core/sync/lan_sync_service.dart';
import '../core/sync/sync_data_model.dart';
import '../views/mobile/mobile_tabs.dart';
import '../views/mobile/mobile_pages.dart';
import '../views/mobile/mobile_scenario_page.dart';
import '../views/mobile/mobile_sheets.dart';

/// 移动端应用脚手架 (MobileScaffold)
class MobileScaffold extends StatefulWidget {
  const MobileScaffold({super.key});

  @override
  State<MobileScaffold> createState() => _MobileScaffoldState();
}

class _SubPageEntry {
  final String pageId;
  final String? param;
  const _SubPageEntry(this.pageId, [this.param]);
}

class _MobileScaffoldState extends State<MobileScaffold> {
  int _currentTab = 0;
  final List<_SubPageEntry> _subPageStack = [];

  String? get _subPageId => _subPageStack.isEmpty ? null : _subPageStack.last.pageId;
  String? get _subPageParam => _subPageStack.isEmpty ? null : _subPageStack.last.param;

  StreamSubscription<SyncSnapshot>? _snapshotSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LanSyncService.instance.ensureServerRunning();
      } catch (_) {}
    });

    _snapshotSub = LanSyncService.instance.onSnapshotReceived.listen((incoming) async {
      if (!mounted) return;
      final player = context.read<AudioPlayerService>();
      final eq = EqualizerManager.instance;
      final local = SyncSnapshot.createFromAppState(player: player, eqManager: eq);
      final merged = local.merge(incoming);
      await SyncSnapshot.applyToAppState(merged, player: player, eqManager: eq);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('收到局域网设备无线快照！已智能合并 ${merged.favorites.length} 首红心、${merged.playlists.length} 个歌单'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    super.dispose();
  }

  void _navigateToPage(String pageId, [String? extra]) {
    setState(() {
      _subPageStack.add(_SubPageEntry(pageId, extra));
    });
  }

  void _popSubPage() {
    setState(() {
      if (_subPageStack.isNotEmpty) {
        _subPageStack.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final bool canPop = _subPageId == null;

    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;

    final overlayStyle = theme.isDarkMode
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    final Widget content = _subPageId != null
        ? Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: theme.canvasColor,
            body: Stack(
              children: [
                _buildSubPage(),
                _buildFloatingMiniPlayer(context, bottom: 16 + viewPaddingBottom),
                _buildPlaybackNoticeBanner(context),
              ],
            ),
          )
        : Scaffold(
            resizeToAvoidBottomInset: false,
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
                _buildFloatingMiniPlayer(context, bottom: 72 + viewPaddingBottom),

                // 底部原生 4-Tab 毛玻璃导航栏
                _buildBottomTabBar(context),

                // 全局浮动播放通知胶囊
                _buildPlaybackNoticeBanner(context),
              ],
            ),
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_subPageId != null) {
            _popSubPage();
          }
        },
        child: content,
      ),
    );
  }

  /// 顶部灵动岛状态栏 (Dynamic Island / 原子通知胶囊 - 支持轻扫切歌、长按暂停与点击展开)
  Widget _buildDynamicIslandHeader(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final track = player.currentTrack;
    if (track == null) {
      return const SizedBox(height: 38);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Center(
        child: GestureDetector(
          key: const Key('dynamic_island_capsule'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => MobilePlayerBottomSheet(onClose: () => Navigator.of(context).pop()),
            );
          },
          onLongPress: () {
            player.togglePlay();
          },
          onHorizontalDragEnd: (details) {
            final vx = details.primaryVelocity ?? 0;
            if (vx < -150) {
              player.next();
            } else if (vx > 150) {
              player.previous();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: theme.accentColor.withValues(alpha: player.isPlaying ? 0.18 : 0.0),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ],
              border: Border.all(
                color: player.isPlaying
                    ? theme.accentColor.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 呼吸跳动音频频谱 3 根竖线
                _buildDynamicIslandSpectrum(player.isPlaying, theme.accentColor),
                const SizedBox(width: 8),
                // 当前歌曲标题与微型歌手
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 播放控制小圆钮 (点触或长按切播)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => player.togglePlay(),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: theme.accentColor,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 灵动岛频谱律动指示器 (支持波浪音阶高度平滑律动)
  Widget _buildDynamicIslandSpectrum(bool isPlaying, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 2.2,
          height: isPlaying ? 12 : 5,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 2.2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 2.2,
          height: isPlaying ? 16 : 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 2.2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          width: 2.2,
          height: isPlaying ? 10 : 4,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      ],
    );
  }

  /// 底部悬浮毛玻璃胶囊播放条 (带 2px 极细实时进度条与红心收藏)
  Widget _buildFloatingMiniPlayer(BuildContext context, {double bottom = 72}) {
    // 当软键盘弹起（如在搜索页打字）时，平滑隐藏 MiniPlayer，避免垫高遮挡搜索联想词及历史记录
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (isKeyboardOpen) return const SizedBox.shrink();

    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();
    final isFav = player.isFavorite(track.id);

    final totalMs = player.duration.inMilliseconds;
    final currMs = player.position.inMilliseconds;
    final progress = (totalMs > 0) ? (currMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Positioned(
      left: 14,
      right: 14,
      bottom: bottom,
      child: GestureDetector(
        key: const Key('mini_player_pill'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MobilePlayerBottomSheet(onClose: () => Navigator.of(context).pop()),
          );
        },
        onVerticalDragEnd: (details) {
          final vy = details.primaryVelocity ?? 0;
          if (vy < -150) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => MobilePlayerBottomSheet(onClose: () => Navigator.of(context).pop()),
            );
          }
        },
        onHorizontalDragEnd: (details) {
          final vx = details.primaryVelocity ?? 0;
          if (vx < -150) {
            player.next();
          } else if (vx > 150) {
            player.previous();
          }
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: MellowColors.canvas(isDark).withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: theme.borderColor.withValues(alpha: 0.5), width: 0.8)),
        ),
        child: SizedBox(
          height: 64,
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
      ),
    );
  }

  /// 全局悬浮播放通知胶囊 (ISSUE-MOB-04 优雅容错与换源提醒)
  Widget _buildPlaybackNoticeBanner(BuildContext context) {
    final player = context.watch<AudioPlayerService>();
    final notice = player.playbackNotice;
    if (notice == null || notice.isEmpty) return const SizedBox.shrink();

    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Positioned(
      top: topInset + 10,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  notice,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => player.clearPlaybackNotice(),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final theme = context.watch<ThemeProvider>();
    final isSelected = _currentTab == index;

    return GestureDetector(
      onTap: () => setState(() {
        _currentTab = index;
        _subPageStack.clear();
      }),
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
        return MobilePlaylistSquarePage(
          onBack: _popSubPage,
          onOpenScenarios: () => _navigateToPage('scenarios'),
        );
      case 'scenarios':
        return MobileScenarioPlaylistPage(
          onBack: _popSubPage,
          onNavigatePage: _navigateToPage,
        );
      case 'toplist':
        return MobileToplistPage(
          onBack: _popSubPage,
          onSelectToplist: (chart) => _navigateToPage('toplist_detail', chart),
        );
      case 'toplist_detail':
      case 'playlist_detail':
        return MobileToplistDetailPage(
          chartName: _subPageParam ?? '飙升榜',
          onBack: _popSubPage,
        );
      case 'radio':
        return MobileRadioPage(onBack: _popSubPage);
      case 'artists':
        return MobileArtistsPage(onBack: _popSubPage, onSelectArtist: (name) => _navigateToPage('artist_detail', name));
      case 'artist_detail':
        return MobileArtistDetailPage(artistName: _subPageParam ?? '巫娜', onBack: _popSubPage);
      case 'local':
        return MobileLocalMusicPage(onBack: _popSubPage);
      case 'history':
        return MobileHistoryPage(onBack: _popSubPage);
      case 'favorites':
        return MobileFavoritesPage(onBack: _popSubPage);
      default:
        return MobileDailyRecommendPage(onBack: _popSubPage);
    }
  }
}
