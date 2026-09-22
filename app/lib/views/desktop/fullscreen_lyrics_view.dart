import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/soft_button.dart';
import '../../design_system/acoustic_mesh_glow.dart';
import '../../design_system/mellow_image.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track_model.dart';

/// 桌面端巨幕沉浸动效大屏歌词 (MusicFull)
class DesktopFullscreenLyricsView extends StatefulWidget {
  final VoidCallback onClose;
  const DesktopFullscreenLyricsView({super.key, required this.onClose});

  @override
  State<DesktopFullscreenLyricsView> createState() => _DesktopFullscreenLyricsViewState();
}

class _DesktopFullscreenLyricsViewState extends State<DesktopFullscreenLyricsView>
    with SingleTickerProviderStateMixin {
  late AnimationController _vinylController;
  final ScrollController _lyricScrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _lyricScrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index) {
    if (index != _lastActiveIndex && _lyricScrollController.hasClients) {
      _lastActiveIndex = index;
      final targetOffset = max(0.0, index * 64.0 - 180.0);
      _lyricScrollController.animateTo(
        targetOffset,
        duration: MellowDurations.lyricScroll,
        curve: MellowDurations.smooth,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerService>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final track = player.currentTrack ?? mockPresetTracks[0];

    if (player.isPlaying) {
      if (!_vinylController.isAnimating) _vinylController.repeat();
    } else {
      if (_vinylController.isAnimating) _vinylController.stop();
    }

    // 计算当前歌词激活行
    int activeLineIndex = 0;
    for (int i = 0; i < track.lyrics.length; i++) {
      if (player.currentPosition >= track.lyrics[i].time) {
        activeLineIndex = i;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveLine(activeLineIndex);
    });

    return Scaffold(
      backgroundColor: MellowColors.canvas(isDark),
      body: Stack(
        children: [
          // 1. 全屏流体动态弥散光晕背景
          const Positioned.fill(
            child: AcousticMeshGlow(),
          ),

          // 2. 右上角浮动关闭与控制条
          Positioned(
            top: 24,
            right: 28,
            child: Row(
              children: [
                SoftButton(
                  icon: player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  iconSize: 20,
                  isCircle: true,
                  onTap: () => player.toggleFavorite(track.id),
                ),
                const SizedBox(width: 12),
                SoftButton(
                  icon: Icons.fullscreen_exit_rounded,
                  isCircle: true,
                  tooltip: '退出全屏 (ESC)',
                  onTap: widget.onClose,
                ),
              ],
            ),
          ),

          // 3. 双栏巨幕内容区
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
              child: Row(
                children: [
                  // 左栏：微凹黑胶大碟唱机与转动唱片
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 黑胶大碟
                        AnimatedBuilder(
                          animation: _vinylController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _vinylController.value * 2 * pi,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 320,
                            height: 320,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF111111),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.55),
                                  blurRadius: 36,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                              border: Border.all(color: const Color(0xFF282828), width: 6),
                            ),
                            child: Center(
                              child: MellowImage(
                                url: track.coverUrl,
                                width: 130,
                                height: 130,
                                borderRadius: MellowRadii.borderPill,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          track.title,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${track.artist} · ${track.album}',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: theme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 迷你进度指示
                        SizedBox(
                          width: 280,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SoftButton(
                              icon: Icons.skip_previous_rounded,
                              isCircle: true,
                              onTap: () => player.previous(),
                            ),
                            const SizedBox(width: 16),
                            SoftButton(
                              icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              iconSize: 28,
                              isActive: true,
                              isCircle: true,
                              padding: const EdgeInsets.all(14),
                              onTap: () => player.togglePlay(),
                            ),
                            const SizedBox(width: 16),
                            SoftButton(
                              icon: Icons.skip_next_rounded,
                              isCircle: true,
                              onTap: () => player.next(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 48),

                  // 右栏：Apple Music 动效歌词系统
                  Expanded(
                    flex: 6,
                    child: track.lyrics.isEmpty
                        ? Center(
                            child: Text(
                              '纯音乐，请静心聆听',
                              style: TextStyle(fontSize: 18, color: theme.textMuted),
                            ),
                          )
                        : ListView.builder(
                            controller: _lyricScrollController,
                            padding: const EdgeInsets.symmetric(vertical: 180),
                            itemCount: track.lyrics.length,
                            itemBuilder: (context, idx) {
                              final line = track.lyrics[idx];
                              final isActive = idx == activeLineIndex;

                              return GestureDetector(
                                onTap: () => player.seek(line.time),
                                child: AnimatedContainer(
                                  duration: MellowDurations.normal,
                                  curve: MellowDurations.smooth,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: AnimatedDefaultTextStyle(
                                    duration: MellowDurations.normal,
                                    style: TextStyle(
                                      fontSize: isActive ? 26 : 18,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      color: isActive
                                          ? theme.accentColor
                                          : (isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.35)),
                                      height: 1.4,
                                    ),
                                    child: Text(line.text),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
