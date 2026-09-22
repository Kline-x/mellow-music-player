import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/tokens.dart';
import '../design_system/theme_provider.dart';
import '../design_system/soft_card.dart';
import '../design_system/acoustic_mesh_glow.dart';
import '../design_system/mellow_image.dart';
import '../core/audio/audio_player_service.dart';
import '../core/audio/track_model.dart';
import '../views/mobile/mobile_tabs.dart';
import '../views/mobile/mobile_pages.dart';
import '../views/mobile/mobile_sheets.dart';
import '../views/common/modals.dart';

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
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;
    final track = player.currentTrack ?? mockPresetTracks[0];

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
                        onOpenSearch: () => showDialog(context: context, builder: (_) => const QuickSearchOverlay()),
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

          // 底部悬浮 Mini 播放胶囊 (点击展开全屏播放器)
          Positioned(
            left: 16,
            right: 16,
            bottom: 74,
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MobilePlayerBottomSheet(onClose: () => Navigator.of(context).pop()),
                );
              },
              child: SoftCard(
                isFloatingPill: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                borderRadius: MellowRadii.borderPill,
                child: Row(
                  children: [
                    MellowImage(
                      url: track.coverUrl,
                      width: 38,
                      height: 38,
                      borderRadius: MellowRadii.borderPill,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(track.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary)),
                          Text(track.artist, style: TextStyle(fontSize: 11, color: theme.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: theme.accentColor, size: 28),
                      onPressed: () => player.togglePlay(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 24),
                      color: theme.textSecondary,
                      onPressed: () => player.next(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部原生 4-Tab 触控导航栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: MellowColors.canvas(isDark).withValues(alpha: 0.85),
                border: Border(top: BorderSide(color: theme.borderColor.withValues(alpha: 0.5))),
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
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicIslandHeader(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.waves_rounded, color: theme.accentColor, size: 20),
              const SizedBox(width: 6),
              Text('润音 · Mellow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textPrimary)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search_rounded, size: 22),
                color: theme.textPrimary,
                onPressed: () => showDialog(context: context, builder: (_) => const QuickSearchOverlay()),
              ),
              IconButton(
                icon: Icon(theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                color: theme.textPrimary,
                onPressed: () => theme.toggleTheme(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final theme = context.watch<ThemeProvider>();
    final isSelected = _currentTab == index;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? theme.accentColor : theme.textMuted, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.accentColor : theme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubPage() {
    switch (_subPageId) {
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
