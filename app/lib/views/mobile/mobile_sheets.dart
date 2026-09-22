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
import '../common/modals.dart';

/// 1. 移动端全屏播放器/歌词页 (大黑胶与动效歌词横滑切换)
class MobilePlayerBottomSheet extends StatefulWidget {
  final VoidCallback onClose;
  const MobilePlayerBottomSheet({super.key, required this.onClose});

  @override
  State<MobilePlayerBottomSheet> createState() => _MobilePlayerBottomSheetState();
}

class _MobilePlayerBottomSheetState extends State<MobilePlayerBottomSheet>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _turntableController;
  final ScrollController _lyricScrollController = ScrollController();
  int _currentPage = 0; // 0: 黑胶大碟, 1: 全屏歌词
  int _lastActiveIndex = -1;
  double? _dragPositionMs;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _turntableController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _turntableController.dispose();
    _lyricScrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index) {
    if (index != _lastActiveIndex && _lyricScrollController.hasClients) {
      _lastActiveIndex = index;
      final targetOffset = max(0.0, index * 48.0 - 120.0);
      _lyricScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
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
      if (!_turntableController.isAnimating) _turntableController.repeat();
    } else {
      if (_turntableController.isAnimating) _turntableController.stop();
    }

    int activeLineIndex = 0;
    for (int i = 0; i < track.lyrics.length; i++) {
      if (player.currentPosition >= track.lyrics[i].time) {
        activeLineIndex = i;
      }
    }
    if (_currentPage == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(activeLineIndex);
      });
    }

    return Scaffold(
      backgroundColor: theme.canvasColor,
      body: Stack(
        children: [
          // 弥散光晕背景
          const Positioned.fill(child: AcousticMeshGlow()),

          // 主体内容
          SafeArea(
            child: Column(
              children: [
                // 顶部返回与切换指示条
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                        onPressed: widget.onClose,
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _pageController.animateToPage(0, duration: MellowDurations.normal, curve: MellowDurations.standard),
                            child: Text('唱片', style: TextStyle(fontWeight: _currentPage == 0 ? FontWeight.bold : FontWeight.normal, color: _currentPage == 0 ? theme.accentColor : theme.textMuted)),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => _pageController.animateToPage(1, duration: MellowDurations.normal, curve: MellowDurations.standard),
                            child: Text('歌词', style: TextStyle(fontWeight: _currentPage == 1 ? FontWeight.bold : FontWeight.normal, color: _currentPage == 1 ? theme.accentColor : theme.textMuted)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.pink, size: 22),
                        onPressed: () => player.toggleFavorite(track.id),
                      ),
                    ],
                  ),
                ),

                // 中间滑动区：0 为黑胶唱盘，1 为全屏歌词
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      // 页面 1: 黑胶大碟
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _turntableController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _turntableController.value * 2 * pi,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 260,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF141414),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
                                  ],
                                  border: Border.all(color: const Color(0xFF282828), width: 5),
                                ),
                                child: Center(
                                  child: MellowImage(
                                    url: track.coverUrl,
                                    width: 110,
                                    height: 110,
                                    borderRadius: MellowRadii.borderPill,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(track.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                            const SizedBox(height: 4),
                            Text(track.artist, style: TextStyle(fontSize: 14, color: theme.textSecondary)),
                          ],
                        ),
                      ),

                      // 页面 2: 全屏动效歌词流
                      ListView.builder(
                        controller: _lyricScrollController,
                        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
                        itemCount: track.lyrics.length,
                        itemBuilder: (context, idx) {
                          final line = track.lyrics[idx];
                          final isActive = idx == activeLineIndex;
                          return GestureDetector(
                            onTap: () => player.seek(line.time),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                line.text,
                                style: TextStyle(
                                  fontSize: isActive ? 20 : 15,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                  color: isActive ? theme.accentColor : theme.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 底部胶囊进度条与控制台
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    children: [
                      // 进度条
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: theme.accentColor,
                          inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                          thumbColor: theme.accentColor,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: (_dragPositionMs ?? player.currentPosition.inMilliseconds.toDouble())
                              .clamp(0.0, max(1.0, track.duration.inMilliseconds.toDouble())),
                          max: max(1.0, track.duration.inMilliseconds.toDouble()),
                          onChanged: (val) {
                            setState(() {
                              _dragPositionMs = val;
                            });
                          },
                          onChangeEnd: (val) {
                            player.seek(Duration(milliseconds: val.toInt()));
                            setState(() {
                              _dragPositionMs = null;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              () {
                                final posSeconds = ((_dragPositionMs ?? player.currentPosition.inMilliseconds) / 1000).toInt();
                                return '${(posSeconds ~/ 60).toString().padLeft(2, '0')}:${(posSeconds % 60).toString().padLeft(2, '0')}';
                              }(),
                              style: TextStyle(fontSize: 11, color: theme.textMuted),
                            ),
                            Text(track.formattedDuration, style: TextStyle(fontSize: 11, color: theme.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 控制按钮排
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              player.playbackMode == PlaybackMode.singleLoop
                                  ? Icons.repeat_one_rounded
                                  : (player.playbackMode == PlaybackMode.shuffle ? Icons.shuffle_rounded : Icons.repeat_rounded),
                              color: theme.textSecondary,
                            ),
                            onPressed: () => player.cyclePlaybackMode(),
                          ),
                          SoftButton(
                            icon: Icons.skip_previous_rounded,
                            iconSize: 26,
                            isCircle: true,
                            onTap: () => player.previous(),
                          ),
                          SoftButton(
                            icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            iconSize: 32,
                            isActive: true,
                            isCircle: true,
                            padding: const EdgeInsets.all(16),
                            onTap: () => player.togglePlay(),
                          ),
                          SoftButton(
                            icon: Icons.skip_next_rounded,
                            iconSize: 26,
                            isCircle: true,
                            onTap: () => player.next(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music_rounded),
                            color: theme.textSecondary,
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => const MobileQueueBottomSheet(),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // EQ 与定时器辅助入口
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('均衡器 EQ', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              showDialog(context: context, builder: (_) => const EqualizerModal());
                            },
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            icon: const Icon(Icons.bedtime_rounded, size: 16),
                            label: const Text('睡眠定时', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              showDialog(context: context, builder: (_) => const SleepTimerModal());
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. 移动端待播队列底部弹层 (MobileQueueBottomSheet)
class MobileQueueBottomSheet extends StatelessWidget {
  const MobileQueueBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: MellowRadii.r28),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('当前播放队列 (${player.playlist.length})', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              SoftButton(
                icon: Icons.delete_outline_rounded,
                isCircle: true,
                onTap: () => player.clearQueue(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: player.playlist.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final t = player.playlist[idx];
                final isCur = idx == player.currentIndex;

                return SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  borderRadius: MellowRadii.borderR12,
                  color: isCur ? theme.accentColor.withValues(alpha: 0.12) : null,
                  onTap: () {
                    player.playTrack(t);
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    children: [
                      MellowImage(url: t.coverUrl, width: 36, height: 36, borderRadius: MellowRadii.borderR8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.title,
                          style: TextStyle(fontWeight: isCur ? FontWeight.bold : FontWeight.normal, color: isCur ? theme.accentColor : theme.textPrimary),
                        ),
                      ),
                      if (isCur) Icon(Icons.graphic_eq_rounded, color: theme.accentColor, size: 18),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
