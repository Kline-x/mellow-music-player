import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../design_system/tokens.dart';
import '../design_system/theme_provider.dart';
import '../design_system/soft_button.dart';
import '../design_system/recessed_well.dart';
import '../design_system/acoustic_mesh_glow.dart';
import '../design_system/mellow_image.dart';
import '../core/audio/audio_player_service.dart';
import '../core/storage/storage_service.dart';
import '../core/window/desktop_floating_lyric_service.dart';
import '../views/desktop/desktop_views.dart';
import '../views/desktop/desktop_search_view.dart';
import '../views/desktop/fullscreen_lyrics_view.dart';
import '../views/desktop/desktop_floating_lyric_bar.dart';
import '../views/common/modals.dart';

/// 桌面端完整工作台脚手架 (DesktopScaffold)
class DesktopScaffold extends StatefulWidget {
  const DesktopScaffold({super.key});

  @override
  State<DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<DesktopScaffold> {
  String _activeView = 'discover';
  String? _artistDetailParam;
  bool _isQueueOpen = false;
  bool _isFullscreenLyrics = false;
  bool _isFloatingLyricEnabled = false;
  double? _dragPositionMs;

  @override
  void initState() {
    super.initState();
    _isFloatingLyricEnabled = DesktopFloatingLyricService.instance.isEnabled ||
        (StorageService.instance.getFloatingLyricEnabled() ?? false);
    DesktopFloatingLyricService.instance.addListener(_onFloatingLyricChanged);
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKeyEvent);
  }

  void _onFloatingLyricChanged() {
    if (mounted) {
      setState(() {
        _isFloatingLyricEnabled = DesktopFloatingLyricService.instance.isEnabled;
      });
    }
  }

  void _toggleFloatingLyric() {
    DesktopFloatingLyricService.instance.toggleEnabled();
  }

  @override
  void dispose() {
    DesktopFloatingLyricService.instance.removeListener(_onFloatingLyricChanged);
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKeyEvent);
    super.dispose();
  }

  bool _handleGlobalHardwareKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final player = context.read<AudioPlayerService>();
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.mediaPlayPause) {
      player.togglePlay();
      return true;
    } else if (key == LogicalKeyboardKey.mediaPlay) {
      player.play();
      return true;
    } else if (key == LogicalKeyboardKey.mediaPause) {
      player.pause();
      return true;
    } else if (key == LogicalKeyboardKey.mediaTrackNext) {
      player.next();
      return true;
    } else if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      player.previous();
      return true;
    } else if (key == LogicalKeyboardKey.mediaStop) {
      player.pause();
      return true;
    }
    return false;
  }

  // 浏览器级真实导航历史栈
  final List<Map<String, String?>> _history = [
    {'view': 'discover', 'extra': null}
  ];
  int _historyIndex = 0;

  void _navigateTo(String viewId, [String? extra]) {
    if (_activeView == viewId && _artistDetailParam == extra) return;
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add({'view': viewId, 'extra': extra});
    _historyIndex = _history.length - 1;

    setState(() {
      _activeView = viewId;
      if (viewId == 'artist_detail') {
        _artistDetailParam = extra ?? '周杰伦';
      }
    });
  }

  void _goBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      final item = _history[_historyIndex];
      setState(() {
        _activeView = item['view']!;
        _artistDetailParam = item['extra'];
      });
    }
  }

  void _goForward() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      final item = _history[_historyIndex];
      setState(() {
        _activeView = item['view']!;
        _artistDetailParam = item['extra'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    if (_isFullscreenLyrics) {
      return DesktopFullscreenLyricsView(
        onClose: () => setState(() => _isFullscreenLyrics = false),
      );
    }

    final shortcuts = <ShortcutActivator, VoidCallback>{
      // 1. 空格播放 / 暂停
      const SingleActivator(LogicalKeyboardKey.space): () => player.togglePlay(),
      // 2. 全局搜索 (Ctrl+K / Cmd+K)
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
        _navigateTo('search');
      },
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
        _navigateTo('search');
      },
      // 3. 快退 5 秒 / 快进 5 秒
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        player.seek(player.currentPosition - const Duration(seconds: 5));
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        player.seek(player.currentPosition + const Duration(seconds: 5));
      },
      // 4. 音量调节
      const SingleActivator(LogicalKeyboardKey.arrowUp): () => player.setVolume(player.volume + 0.05),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () => player.setVolume(player.volume - 0.05),
      // 5. 静音切换
      const SingleActivator(LogicalKeyboardKey.keyM): () => player.toggleMute(),
      // 6. 巨幕全屏歌词
      const SingleActivator(LogicalKeyboardKey.keyL): () {
        setState(() => _isFullscreenLyrics = !_isFullscreenLyrics);
      },
      // 7. 待播队列抽屉
      const SingleActivator(LogicalKeyboardKey.keyQ): () {
        setState(() => _isQueueOpen = !_isQueueOpen);
      },
      // 8. ESC 退出全屏或抽屉
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_isFullscreenLyrics) {
          setState(() => _isFullscreenLyrics = false);
        } else if (_isQueueOpen) {
          setState(() => _isQueueOpen = false);
        }
      },
      // 9. 硬件多媒体按键直通绑定
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () => player.togglePlay(),
      const SingleActivator(LogicalKeyboardKey.mediaPlay): () => player.play(),
      const SingleActivator(LogicalKeyboardKey.mediaPause): () => player.pause(),
      const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () => player.next(),
      const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () => player.previous(),
      const SingleActivator(LogicalKeyboardKey.mediaStop): () => player.pause(),
      const SingleActivator(LogicalKeyboardKey.audioVolumeMute): () => player.toggleMute(),
      const SingleActivator(LogicalKeyboardKey.audioVolumeUp): () => player.setVolume(player.volume + 0.05),
      const SingleActivator(LogicalKeyboardKey.audioVolumeDown): () => player.setVolume(player.volume - 0.05),
      // 10. 桌面悬浮动效歌词显隐切换 (Ctrl+D / Cmd+D)
      const SingleActivator(LogicalKeyboardKey.keyD, control: true): _toggleFloatingLyric,
      const SingleActivator(LogicalKeyboardKey.keyD, meta: true): _toggleFloatingLyric,
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.canvasColor,
          body: Stack(
            children: [
              // 1. 全局声学弥散流体光晕背景
              const Positioned.fill(child: AcousticMeshGlow()),

              // 2. 主体工作台三栏布局
              Positioned.fill(
                child: Column(
                  children: [
                    // 顶部拟物标题栏 (TitleBar)
                    _buildTitleBar(context),

                    // 主体区域：左侧微凹胶囊侧边栏 + 中央页面插槽
                    Expanded(
                      child: Row(
                        children: [
                          // 左侧侧边栏
                          _buildSidebar(context),

                          // 中央工作区
                          Expanded(
                            child: ClipRRect(
                              child: _buildCurrentView(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 底部签名级悬浮播放底栏 (Pill Dock Player)
                    _buildBottomPlayerDock(context),
                  ],
                ),
              ),

              // 3. 右侧滑出的待播队列抽屉
              if (_isQueueOpen)
                Positioned(
                  top: 54,
                  bottom: 96,
                  right: 16,
                  child: PlaybackQueueView(
                    onClose: () => setState(() => _isQueueOpen = false),
                  ),
                ),

              // 4. 异常提示横幅 (ISSUE-09 友好容错)
              if (player.playbackNotice != null)
                Positioned(
                  top: 58,
                  left: 236,
                  right: 24,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.92),
                        borderRadius: MellowRadii.borderPill,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              player.playbackNotice!,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
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
                ),

              // 5. 桌面悬浮动效歌词小组件 (Desktop Floating Lyric Bar)
              if (_isFloatingLyricEnabled)
                DesktopFloatingLyricBar(
                  onClose: _toggleFloatingLyric,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 顶部现代桌面沉浸应用栏  // 顶部沉浸式拟物风格导航条 (集成标题、窗口控制区对齐与即时全局搜索)
  Widget _buildTitleBar(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;
        return Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
          decoration: BoxDecoration(
            color: MellowColors.canvas(isDark).withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: theme.borderColor.withValues(alpha: 0.6), width: 0.8)),
          ),
          child: Row(
            children: [
              // 品牌与路由导航
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.graphic_eq_rounded, color: theme.accentColor, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCompact ? '润音' : 'Mellow Music · 润音',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: theme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: isCompact ? 10 : 18),
                  // 路由前进后退按钮 (真实多级导航栈)
                  Row(
                    children: [
                      SoftButton(
                        icon: Icons.chevron_left_rounded,
                        iconSize: 20,
                        tooltip: _historyIndex > 0 ? '后退' : '无更早历史',
                        isCircle: true,
                        padding: const EdgeInsets.all(6),
                        onTap: _historyIndex > 0 ? _goBack : null,
                      ),
                      const SizedBox(width: 4),
                      SoftButton(
                        icon: Icons.chevron_right_rounded,
                        iconSize: 20,
                        tooltip: _historyIndex < _history.length - 1 ? '前进' : '无前进历史',
                        isCircle: true,
                        padding: const EdgeInsets.all(6),
                        onTap: _historyIndex < _history.length - 1 ? _goForward : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // 居中/全局全网即时搜索栏 (弹性自适应防溢出，Ctrl/Cmd+K)
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: GestureDetector(
                      onTap: () => _navigateTo('search'),
                      child: RecessedWell(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: MellowRadii.borderPill,
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 18, color: theme.accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isCompact ? '搜索歌曲/歌手...' : '即时搜索全网歌曲、歌手、专辑...',
                                style: TextStyle(fontSize: 12.5, color: theme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                borderRadius: MellowRadii.borderR8,
                              ),
                              child: Text(
                                '⌘K',
                                style: TextStyle(fontSize: 10, color: theme.textSecondary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 右侧专业工具集 (对标 AlgerMusicPlayer)
              Row(
                children: [
                  // 1. 导入外部歌单
                  SoftButton(
                    icon: Icons.queue_music_rounded,
                    label: isCompact ? null : '导入歌单',
                    tooltip: '导入外部歌单',
                    isPill: !isCompact,
                    isCircle: isCompact,
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 7),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const ImportPlaylistModal(),
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 10),
                    // 2. 5大声学强调色调色盘选择微胶囊
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: MellowRadii.borderPill,
                        border: Border.all(color: theme.borderColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: AccentColorType.values.map((type) {
                          final isCurrent = theme.accentType == type;
                          final color = type.getColor(isDark);
                          return GestureDetector(
                            onTap: () => theme.setAccentType(type),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: isCurrent ? 15 : 10,
                              height: isCurrent ? 15 : 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                                boxShadow: isCurrent
                                    ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),

                  // 3. 主题明暗切换
                  SoftButton(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    tooltip: isDark ? '切换温润白瓷模式' : '切换深石墨夜间模式',
                    isCircle: true,
                    onTap: () => theme.toggleTheme(),
                  ),
                  const SizedBox(width: 6),

                  // 4. 设置中心
                  SoftButton(
                    icon: Icons.settings_rounded,
                    tooltip: '设置与多端同步',
                    isCircle: true,
                    onTap: () => _navigateTo('settings'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 左侧现代化自适应侧边栏 (支持完整滚动，避让底栏)
  Widget _buildSidebar(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.borderColor.withValues(alpha: 0.5), width: 0.8)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        children: [
          _buildNavGroupTitle('在线音乐'),
          _buildNavItem('discover', '发现音乐', Icons.explore_rounded),
          _buildNavItem('search', '全网搜索', Icons.search_rounded),
          _buildNavItem('playlists', '歌单广场', Icons.queue_music_rounded),
          _buildNavItem('toplist', '巅峰榜单', Icons.leaderboard_rounded),
          _buildNavItem('artists', '热门歌手', Icons.people_alt_rounded),
          _buildNavItem('podcast', '声音电台', Icons.radio_rounded),
          const SizedBox(height: 18),

          _buildNavGroupTitle('我的资料库'),
          _buildNavItem('favorite', '我喜欢的音乐', Icons.favorite_rounded),
          _buildNavItem('imported', '导入与自建歌单', Icons.library_music_rounded),
          _buildNavItem('history', '播放历史', Icons.history_rounded),
          _buildNavItem('local', '本地与下载', Icons.folder_special_rounded),
          const SizedBox(height: 18),

          _buildNavGroupTitle('系统与生态'),
          _buildNavItem('sync', '多端同步中心', Icons.cloud_sync_rounded),
          _buildNavItem('sources', 'LX 音源管理', Icons.integration_instructions_rounded),
          _buildNavItem('settings', '个性化设置', Icons.tune_rounded),
        ],
      ),
    );
  }

  Widget _buildNavGroupTitle(String title) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textMuted, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildNavItem(String id, String label, IconData icon) {
    final isSelected = _activeView == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SoftButton(
        label: label,
        icon: icon,
        isActive: isSelected,
        isPill: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () => _navigateTo(id),
      ),
    );
  }

  // 当前激活主页面
  Widget _buildCurrentView() {
    switch (_activeView) {
      case 'discover':
        return DesktopDiscoverView(onNavigate: _navigateTo);
      case 'search':
        return DesktopSearchView(onNavigate: _navigateTo);
      case 'playlists':
        return DesktopPlaylistSquareView(onNavigate: _navigateTo);
      case 'toplist':
        return DesktopToplistView(onNavigate: _navigateTo);
      case 'artists':
        return DesktopArtistsView(onNavigate: _navigateTo);
      case 'artist_detail':
        return DesktopArtistDetailView(artistName: _artistDetailParam ?? '巫娜', onNavigate: _navigateTo);
      case 'podcast':
        return DesktopPodcastView(onNavigate: _navigateTo);
      case 'favorite':
        return DesktopFavoriteView(onNavigate: _navigateTo);
      case 'imported':
        return DesktopImportedPlaylistsView(onNavigate: _navigateTo);
      case 'history':
        return DesktopHistoryView(onNavigate: _navigateTo);
      case 'local':
        return DesktopLocalMusicView(onNavigate: _navigateTo);
      case 'settings':
        return DesktopSettingsView(onNavigate: _navigateTo);
      case 'sources':
        return DesktopSourceManagerView(onNavigate: _navigateTo);
      case 'sync':
        return DesktopSyncView(onNavigate: _navigateTo);
      default:
        return DesktopDiscoverView(onNavigate: _navigateTo);
    }
  }

  // 底部现代化沉浸通栏播放栏 (Docked Glass Player Bar)
  Widget _buildBottomPlayerDock(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;
    final track = player.currentTrack;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: 78,
      padding: EdgeInsets.symmetric(horizontal: screenWidth < 900 ? 12 : 24, vertical: 6),
      decoration: BoxDecoration(
        color: MellowColors.card(isDark).withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: theme.borderColor.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. 左侧：正在播放曲目信息 (若空闲则展示优雅空状态)
          SizedBox(
            width: screenWidth < 900 ? 190 : 250,
            child: track == null
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: theme.accentColor.withValues(alpha: 0.1),
                          child: Icon(Icons.music_note_rounded, size: 24, color: theme.accentColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '润音 · 暂无播放曲目',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '点击全网搜索开启真实音乐',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () => setState(() => _isFullscreenLyrics = true),
                          child: MellowImage(
                            url: track.coverUrl,
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => player.toggleFavorite(track.id),
                                  child: Icon(
                                    player.isFavorite(track.id)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: player.isFavorite(track.id)
                                        ? const Color(0xFFEF4444)
                                        : theme.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => AddToPlaylistModal(track: track),
                                  ),
                                  child: Tooltip(
                                    message: '收录到歌单',
                                    child: Icon(
                                      Icons.playlist_add_rounded,
                                      size: 19,
                                      color: theme.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${track.artist} · ${track.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          // 2. 中央：核心播放控制器与微细平滑进度条
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth < 900 ? 6 : 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 控制按键行 (自适应缩放防溢出)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            player.playbackMode == PlaybackMode.singleLoop
                                ? Icons.repeat_one_rounded
                                : (player.playbackMode == PlaybackMode.shuffle
                                    ? Icons.shuffle_rounded
                                    : Icons.repeat_rounded),
                            size: 19,
                          ),
                          color: player.playbackMode == PlaybackMode.sequence
                              ? theme.textMuted
                              : theme.accentColor,
                          tooltip: player.playbackMode.label,
                          onPressed: () => player.cyclePlaybackMode(),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, size: 22),
                          color: theme.textPrimary,
                          tooltip: '上一首',
                          onPressed: () => player.previous(),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => player.togglePlay(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.accentColor.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 22),
                          color: theme.textPrimary,
                          tooltip: '下一首',
                          onPressed: () => player.next(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  // 进度条行 (带拖拽防抖保护，松手再 seek)
                  Row(
                    children: [
                      Text(
                        _formatSeconds(((_dragPositionMs ?? player.currentPosition.inMilliseconds) / 1000).toInt()),
                        style: TextStyle(fontSize: 10.5, color: theme.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 18,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.5,
                              activeTrackColor: theme.accentColor,
                              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                              thumbColor: theme.accentColor,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                            ),
                            child: Slider(
                              value: track == null
                                  ? 0.0
                                  : (_dragPositionMs ?? player.currentPosition.inMilliseconds.toDouble())
                                      .clamp(0.0, max(1.0, track.duration.inMilliseconds.toDouble())),
                              max: max(1.0, track?.duration.inMilliseconds.toDouble() ?? 1.0),
                              onChanged: track == null
                                  ? null
                                  : (val) {
                                      setState(() => _dragPositionMs = val);
                                    },
                              onChangeEnd: track == null
                                  ? null
                                  : (val) {
                                      player.seek(Duration(milliseconds: val.toInt()));
                                      setState(() => _dragPositionMs = null);
                                    },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        track?.formattedDuration ?? '00:00',
                        style: TextStyle(fontSize: 10.5, color: theme.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. 右侧：专业音效工具与音量调节
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 18),
                color: theme.textSecondary,
                tooltip: '10 频段专业声学 EQ',
                visualDensity: VisualDensity.compact,
                onPressed: () => showDialog(context: context, builder: (_) => const EqualizerModal()),
              ),
              IconButton(
                icon: const Icon(Icons.hourglass_bottom_rounded, size: 18),
                color: player.sleepTimerMinutes != null ? theme.accentColor : theme.textSecondary,
                tooltip: player.sleepTimerMinutes != null
                    ? '睡眠定时进行中 (${player.sleepTimerRemainingSeconds ~/ 60}分)'
                    : '设置睡眠定时器',
                visualDensity: VisualDensity.compact,
                onPressed: () => showDialog(context: context, builder: (_) => const SleepTimerModal()),
              ),
              IconButton(
                icon: const Icon(Icons.lyrics_rounded, size: 18),
                color: _isFullscreenLyrics ? theme.accentColor : theme.textSecondary,
                tooltip: '展开巨幕全屏歌词',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _isFullscreenLyrics = true),
              ),
              IconButton(
                icon: const Icon(Icons.subtitles_rounded, size: 18),
                color: _isFloatingLyricEnabled ? theme.accentColor : theme.textSecondary,
                tooltip: _isFloatingLyricEnabled ? '关闭桌面歌词 (Ctrl+D)' : '开启桌面歌词 (Ctrl+D)',
                visualDensity: VisualDensity.compact,
                onPressed: _toggleFloatingLyric,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, size: 18),
                color: _isQueueOpen ? theme.accentColor : theme.textSecondary,
                tooltip: '待播队列 (Q)',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _isQueueOpen = !_isQueueOpen),
              ),
              const SizedBox(width: 4),
              // 音量图标 (点击静音/记忆恢复)
              GestureDetector(
                onTap: () => player.toggleMute(),
                child: Icon(
                  player.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 18,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 70,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: theme.accentColor,
                    inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                    thumbColor: theme.accentColor,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                  ),
                  child: Slider(
                    value: player.volume,
                    onChanged: (v) => player.setVolume(v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
