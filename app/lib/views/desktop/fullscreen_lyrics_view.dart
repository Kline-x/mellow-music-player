import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _vinylController;
  late AnimationController _armController;
  final ScrollController _lyricScrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    _armController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _armController.dispose();
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
      if (!_armController.isAnimating && _armController.value < 1.0) _armController.forward();
    } else {
      if (_vinylController.isAnimating) _vinylController.stop();
      if (!_armController.isAnimating && _armController.value > 0.0) _armController.reverse();
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

    final lyricShortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      const SingleActivator(LogicalKeyboardKey.keyL): widget.onClose,
      const SingleActivator(LogicalKeyboardKey.space): () => player.togglePlay(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        player.seek(player.currentPosition - const Duration(seconds: 5));
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        player.seek(player.currentPosition + const Duration(seconds: 5));
      },
      const SingleActivator(LogicalKeyboardKey.keyM): () => player.toggleMute(),
    };

    return CallbackShortcuts(
      bindings: lyricShortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: MellowColors.canvas(isDark),
          body: Stack(
            children: [
              // 1. 全屏流体动态弥散光晕背景
              const Positioned.fill(
                child: AcousticMeshGlow(),
              ),

              // 左上角显式返回胶囊按钮 (ESC)
              Positioned(
                top: 24,
                left: 28,
                child: SoftButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  iconSize: 13,
                  label: '返回主界面 (ESC)',
                  isPill: true,
                  onTap: widget.onClose,
                ),
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
                      onTap: () => player.toggleFavorite(track.id, track),
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
                  // 左栏：微拟物黑胶大碟唱机与旋转唱针
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 黑胶唱机与动态唱针
                        SizedBox(
                          width: 340,
                          height: 330,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 1. 黑胶转动大碟
                              AnimatedBuilder(
                                animation: _vinylController,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: _vinylController.value * 2 * pi,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 290,
                                  height: 290,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF141416),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.accentColor.withValues(alpha: 0.28),
                                        blurRadius: 48,
                                        spreadRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        blurRadius: 36,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // 同心环光栅纹理 1
                                      Container(
                                        width: 250,
                                        height: 250,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.2),
                                        ),
                                      ),
                                      // 同心环光栅纹理 2
                                      Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.2),
                                        ),
                                      ),
                                      // 中心唱片封面
                                      Container(
                                        width: 126,
                                        height: 126,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black87, width: 3),
                                        ),
                                        child: ClipOval(
                                          child: MellowImage(
                                            url: track.coverUrl,
                                            width: 126,
                                            height: 126,
                                          ),
                                        ),
                                      ),
                                      // 轴心小金属转心
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          border: Border.all(color: Colors.black54, width: 2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 2. 真实旋转黑胶唱针 (Tonearm)
                              Positioned(
                                top: 0,
                                right: 30,
                                child: AnimatedBuilder(
                                  animation: _armController,
                                  builder: (context, child) {
                                    // 抬起状态为 -0.38 弧度 (~ -22 度)，搭在唱片状态为 0 弧度
                                    final angle = -0.38 * (1.0 - _armController.value);
                                    return Transform(
                                      alignment: Alignment.topRight,
                                      transform: Matrix4.rotationZ(angle),
                                      child: child,
                                    );
                                  },
                                  child: _TonearmWidget(accentColor: theme.accentColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          track.title,
                          style: TextStyle(
                            fontSize: 24,
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
                            fontSize: 14,
                            color: theme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // 进度条行 (带两端时间)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatDuration(player.currentPosition),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textMuted,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 320,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.5,
                                  activeTrackColor: theme.accentColor,
                                  inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                                  thumbColor: theme.accentColor,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                ),
                                child: Slider(
                                  value: player.currentPosition.inMilliseconds.clamp(0, track.duration.inMilliseconds).toDouble(),
                                  max: max(1.0, track.duration.inMilliseconds.toDouble()),
                                  onChanged: (val) => player.seek(Duration(milliseconds: val.toInt())),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              track.formattedDuration,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textMuted,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 控制按键行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SoftButton(
                              icon: player.playbackMode == PlaybackMode.singleLoop
                                  ? Icons.repeat_one_rounded
                                  : (player.playbackMode == PlaybackMode.shuffle
                                      ? Icons.shuffle_rounded
                                      : Icons.repeat_rounded),
                              iconSize: 18,
                              isCircle: true,
                              tooltip: player.playbackMode.label,
                              onTap: () => player.cyclePlaybackMode(),
                            ),
                            const SizedBox(width: 16),
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
                            const SizedBox(width: 16),
                            SoftButton(
                              icon: player.playbackMode == PlaybackMode.singleLoop
                                  ? Icons.repeat_one_rounded
                                  : (player.playbackMode == PlaybackMode.shuffle
                                      ? Icons.shuffle_rounded
                                      : Icons.repeat_rounded),
                              iconSize: 18,
                              isCircle: true,
                              tooltip: '播放模式: ${player.playbackMode.label}',
                              onTap: () => player.cyclePlaybackMode(),
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
                                          : (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35)),
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
    ),
    ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 拟物黑胶唱针微组件 (Tonearm - 支持旋转摆动物理质感)
class _TonearmWidget extends StatelessWidget {
  final Color accentColor;
  const _TonearmWidget({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 顶部转轴金属圆座
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
        // 银色唱臂连杆
        Container(
          width: 5,
          height: 86,
          margin: const EdgeInsets.only(right: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFCBD5E1), Color(0xFF64748B)],
            ),
            borderRadius: BorderRadius.circular(2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(1, 2),
              ),
            ],
          ),
        ),
        // 黑色唱头 (Stylus)
        Container(
          width: 16,
          height: 22,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF94A3B8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

