import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/tokens.dart';
import '../design_system/theme_provider.dart';
import '../design_system/soft_card.dart';
import '../design_system/soft_button.dart';
import '../design_system/recessed_well.dart';
import '../design_system/acoustic_mesh_glow.dart';
import '../design_system/mellow_image.dart';
import '../core/audio/audio_player_service.dart';
import '../core/audio/track_model.dart';
import '../views/desktop/desktop_views.dart';
import '../views/desktop/fullscreen_lyrics_view.dart';
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

  void _navigateTo(String viewId, [String? extra]) {
    setState(() {
      _activeView = viewId;
      if (viewId == 'artist_detail') {
        _artistDetailParam = extra ?? '巫娜';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    if (_isFullscreenLyrics) {
      return DesktopFullscreenLyricsView(
        onClose: () => setState(() => _isFullscreenLyrics = false),
      );
    }

    return Scaffold(
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
        ],
      ),
    );
  }

  // 顶部拟物标题栏
  Widget _buildTitleBar(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: MellowColors.canvas(isDark).withOpacity(0.6),
        border: Border(bottom: BorderSide(color: theme.borderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // Mac 交通灯
          Row(
            children: [
              _buildTrafficLight(const Color(0xFFFF5F56)),
              const SizedBox(width: 8),
              _buildTrafficLight(const Color(0xFFFFBD2E)),
              const SizedBox(width: 8),
              _buildTrafficLight(const Color(0xFF27C93F)),
            ],
          ),
          const SizedBox(width: 28),

          // 品牌与名称
          Row(
            children: [
              Icon(Icons.waves_rounded, color: theme.accentColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Mellow Music · 润音',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: theme.textPrimary),
              ),
            ],
          ),
          const Spacer(),

          // 居中/全局快捷搜索栏 (⌘ K)
          GestureDetector(
            onTap: () => showDialog(context: context, builder: (_) => const QuickSearchOverlay()),
            child: RecessedWell(
              width: 320,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              borderRadius: MellowRadii.borderPill,
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 16, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '即时搜索全网歌曲、歌手、歌单...',
                      style: TextStyle(fontSize: 12.5, color: theme.textMuted),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                      borderRadius: MellowRadii.borderR8,
                    ),
                    child: Text('⌘ K', style: TextStyle(fontSize: 10, color: theme.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // 移动端视口预览切换
          SoftButton(
            icon: Icons.smartphone_rounded,
            tooltip: '切换移动端视口预览',
            isCircle: true,
            onTap: () => theme.toggleMobilePreview(),
          ),
          const SizedBox(width: 10),

          // 主题切换
          SoftButton(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: isDark ? '切换温润白瓷模式' : '切换深石墨夜间模式',
            isCircle: true,
            onTap: () => theme.toggleTheme(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficLight(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // 左侧悬浮胶囊侧边栏
  Widget _buildSidebar(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: ListView(
        children: [
          _buildNavGroupTitle('在线音乐'),
          _buildNavItem('discover', '发现音乐', Icons.explore_rounded),
          _buildNavItem('playlists', '歌单广场', Icons.queue_music_rounded),
          _buildNavItem('toplist', '巅峰榜单', Icons.leaderboard_rounded),
          _buildNavItem('artists', '热门歌手', Icons.people_alt_rounded),
          _buildNavItem('podcast', '声音电台', Icons.radio_rounded),
          const SizedBox(height: 18),

          _buildNavGroupTitle('我的资料库'),
          _buildNavItem('favorite', '我喜欢的音乐', Icons.favorite_rounded),
          _buildNavItem('history', '播放历史', Icons.history_rounded),
          _buildNavItem('local', '本地与下载', Icons.folder_special_rounded),
          const SizedBox(height: 18),

          _buildNavGroupTitle('系统与生态'),
          _buildNavItem('settings', '个性化设置', Icons.tune_rounded),
          _buildNavItem('sources', 'LX 音源管理', Icons.integration_instructions_rounded),
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
    final theme = context.watch<ThemeProvider>();
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
      case 'history':
        return DesktopHistoryView(onNavigate: _navigateTo);
      case 'local':
        return DesktopLocalMusicView(onNavigate: _navigateTo);
      case 'settings':
        return DesktopSettingsView(onNavigate: _navigateTo);
      case 'sources':
        return DesktopSourceManagerView(onNavigate: _navigateTo);
      default:
        return DesktopDiscoverView(onNavigate: _navigateTo);
    }
  }

  // 底部签名级悬浮播放底栏 (Pill Dock Player)
  Widget _buildBottomPlayerDock(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;
    final track = player.currentTrack ?? mockPresetTracks[0];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SoftCard(
        isFloatingPill: true,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        borderRadius: MellowRadii.borderPill,
        child: Row(
          children: [
            // 歌曲信息卡片
            MellowImage(
              url: track.coverUrl,
              width: 48,
              height: 48,
              borderRadius: MellowRadii.borderR12,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => player.toggleFavorite(track.id),
                      child: Icon(
                        player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 16,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${track.artist} · ${track.album}',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 32),

            // 核心播放控制器与进度条
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 进度条
                  Row(
                    children: [
                      Text(
                        '${(player.currentPosition.inSeconds ~/ 60).toString().padLeft(2, '0')}:${(player.currentPosition.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: theme.textMuted),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            activeTrackColor: theme.accentColor,
                            inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                            thumbColor: theme.accentColor,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: player.currentPosition.inMilliseconds.clamp(0, track.duration.inMilliseconds).toDouble(),
                            max: max(1.0, track.duration.inMilliseconds.toDouble()),
                            onChanged: (val) => player.seek(Duration(milliseconds: val.toInt())),
                          ),
                        ),
                      ),
                      Text(
                        track.formattedDuration,
                        style: TextStyle(fontSize: 11, color: theme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // 控制按键
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    player.playbackMode == PlaybackMode.singleLoop
                        ? Icons.repeat_one_rounded
                        : (player.playbackMode == PlaybackMode.shuffle ? Icons.shuffle_rounded : Icons.repeat_rounded),
                    size: 20,
                  ),
                  tooltip: player.playbackMode.label,
                  onPressed: () => player.cyclePlaybackMode(),
                ),
                SoftButton(
                  icon: Icons.skip_previous_rounded,
                  iconSize: 20,
                  isCircle: true,
                  onTap: () => player.previous(),
                ),
                const SizedBox(width: 8),
                SoftButton(
                  icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  iconSize: 26,
                  isActive: true,
                  isCircle: true,
                  padding: const EdgeInsets.all(12),
                  onTap: () => player.togglePlay(),
                ),
                const SizedBox(width: 8),
                SoftButton(
                  icon: Icons.skip_next_rounded,
                  iconSize: 20,
                  isCircle: true,
                  onTap: () => player.next(),
                ),
              ],
            ),
            const SizedBox(width: 24),

            // 实用工具组 (EQ, 定时器, 歌词, 队列, 音量)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: '声学 10 频段 EQ',
                  onPressed: () => showDialog(context: context, builder: (_) => const EqualizerModal()),
                ),
                IconButton(
                  icon: const Icon(Icons.bedtime_rounded, size: 20),
                  tooltip: '睡眠定时器',
                  onPressed: () => showDialog(context: context, builder: (_) => const SleepTimerModal()),
                ),
                IconButton(
                  icon: const Icon(Icons.subtitles_rounded, size: 20),
                  tooltip: '巨幕歌词 (MusicFull)',
                  onPressed: () => setState(() => _isFullscreenLyrics = true),
                ),
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded, size: 20),
                  tooltip: '待播队列',
                  onPressed: () => setState(() => _isQueueOpen = !_isQueueOpen),
                ),
                const SizedBox(width: 6),
                // 音量滑块
                Icon(player.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 18, color: theme.textSecondary),
                SizedBox(
                  width: 90,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: theme.accentColor,
                      thumbColor: theme.accentColor,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
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
      ),
    );
  }
}
