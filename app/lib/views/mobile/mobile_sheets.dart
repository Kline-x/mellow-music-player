import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/soft_button.dart';
import '../../design_system/acoustic_mesh_glow.dart';
import '../../design_system/mellow_image.dart';
import '../../core/audio/audio_player_service.dart';
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

  void _scrollToActiveLine(int index, [double viewportHeight = 400]) {
    if (index != _lastActiveIndex && _lyricScrollController.hasClients) {
      _lastActiveIndex = index;
      final targetOffset = max(0.0, index * 44.0 - (viewportHeight / 2) + 22.0);
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
    final track = player.currentTrack;
    if (track == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, size: 48, color: theme.textMuted),
              const SizedBox(height: 16),
              Text('暂未播放任何歌曲', style: TextStyle(color: theme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('前往发现页或搜索以挑选心仪单曲', style: TextStyle(color: theme.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              SoftButton(label: '返回', onTap: widget.onClose, isPill: true),
            ],
          ),
        ),
      );
    }

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
    final overlayStyle = isDark
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

    final topPadding = MediaQuery.viewPaddingOf(context).top;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final effectiveTop = max(topPadding, 20.0);

    return Scaffold(
      backgroundColor: theme.canvasColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Stack(
          children: [
            // 全屏声学弥散流光背景 (100% 覆盖状态栏与整个屏幕，彻底消除顶切断层)
            const Positioned.fill(child: AcousticMeshGlow()),

            // 顶部状态栏与天顶极柔羽化渐变 (无硬切线，保证系统状态栏与播放顶栏天衣无缝、浑然一体)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: effectiveTop + 56.0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.22 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 主体内容
            Column(
              children: [
                // 沉浸式一体化顶栏 (纯净无框、温润通透，与声学光晕浑然天成)
                Padding(
                  padding: EdgeInsets.only(
                    top: effectiveTop + 4.0,
                    left: 16.0,
                    right: 16.0,
                    bottom: 4.0,
                  ),
                  child: SizedBox(
                    height: 44.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 左侧纯净收起手势按钮 (无生硬灰色圆底，轻灵通透)
                        IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 30,
                            color: theme.textPrimary.withValues(alpha: 0.9),
                          ),
                          tooltip: '收起',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          onPressed: widget.onClose,
                        ),

                        // 顶栏正中纯净留白：彻底避开居中前摄打孔，消除对撞怪异感，呈现大气质感
                        const Spacer(),

                        // 右侧纯净操作组 (红心喜爱 + 加入歌单，消除补丁式灰圆底)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: player.isFavorite(track.id) ? Colors.pinkAccent : theme.textSecondary.withValues(alpha: 0.85),
                                size: 22,
                              ),
                              tooltip: '红心收藏',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                              onPressed: () => player.toggleFavorite(track.id),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.bookmark_add_outlined,
                                color: theme.textSecondary.withValues(alpha: 0.85),
                                size: 22,
                              ),
                              tooltip: '收藏至歌单',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                              onPressed: () => showDialog(context: context, builder: (_) => AddToPlaylistModal(track: track)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 中间滑动区：0 为黑胶唱盘，1 为全屏歌词 (带动态视口高度居中感知)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availH = constraints.maxHeight;
                      // 根据视口可用高度动态计算黑胶唱片尺寸，紧凑屏幕自动弹性收拢，彻底杜绝内容挤压与顶部顶出
                      final double discSize = (availH * 0.56).clamp(170.0, 260.0);
                      final double innerCoverSize = discSize * 0.42;
                      final double spacingBelowDisc = (availH < 380) ? 14.0 : 28.0;

                      if (_currentPage == 1) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToActiveLine(activeLineIndex, constraints.maxHeight);
                        });
                      }
                      return PageView(
                        controller: _pageController,
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        children: [
                      // 页面 1: 黑胶大碟 (支持点击翻转至歌词)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pageController.animateToPage(
                          1,
                          duration: MellowDurations.normal,
                          curve: MellowDurations.standard,
                        ),
                        child: Center(
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
                                  width: discSize,
                                  height: discSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF141414),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
                                    ],
                                    border: Border.all(color: const Color(0xFF282828), width: max(3.0, discSize * 0.02)),
                                  ),
                                  child: Center(
                                    child: MellowImage(
                                      url: track.coverUrl,
                                      width: innerCoverSize,
                                      height: innerCoverSize,
                                      borderRadius: MellowRadii.borderPill,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: spacingBelowDisc),
                              Text(track.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(track.artist, style: TextStyle(fontSize: 13.5, color: theme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => SourceSwitcherModal(track: track),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: theme.accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.accentColor.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.swap_calls_rounded, size: 13, color: theme.accentColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${AudioPlayerService.formatSourceDisplayName(track.source)} · 点击换源',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: theme.accentColor,
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

                      // 页面 2: 全屏动效歌词流
                      track.lyrics.isEmpty
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _pageController.animateToPage(
                                0,
                                duration: MellowDurations.normal,
                                curve: MellowDurations.standard,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: theme.accentColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.music_note_rounded, size: 32, color: theme.accentColor),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '纯音乐，请欣赏',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '暂无匹配歌词 · 点击返回唱片',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
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
                  );
                },
              ),
            ),

                // 底部胶囊进度条与控制台
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, max(bottomPadding, 16)),
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

                      // 歌词/唱片、EQ、音量与定时器辅助入口 (FittedBox 自适应弹性缩放，保证小屏零溢出)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: _currentPage == 1 ? theme.accentColor : null,
                                backgroundColor: _currentPage == 1 ? theme.accentColor.withValues(alpha: 0.12) : null,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(
                                _currentPage == 0 ? Icons.lyrics_rounded : Icons.album_rounded,
                                size: 16,
                                color: _currentPage == 1 ? theme.accentColor : null,
                              ),
                              label: Text(
                                _currentPage == 0 ? '歌词' : '唱片',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _currentPage == 1 ? FontWeight.bold : FontWeight.normal,
                                  color: _currentPage == 1 ? theme.accentColor : null,
                                ),
                              ),
                              onPressed: () {
                                final targetPage = _currentPage == 0 ? 1 : 0;
                                _pageController.animateToPage(
                                  targetPage,
                                  duration: MellowDurations.normal,
                                  curve: MellowDurations.standard,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('EQ', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                showDialog(context: context, builder: (_) => const EqualizerModal());
                              },
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: Icon(
                                player.volume > 0.5
                                    ? Icons.volume_up_rounded
                                    : (player.volume > 0 ? Icons.volume_down_rounded : Icons.volume_off_rounded),
                                size: 16,
                              ),
                              label: Text('音量 ${(player.volume * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                showDialog(context: context, builder: (_) => const _MobileVolumeDialog());
                              },
                            ),
                            const SizedBox(width: 6),
                            Builder(
                              builder: (context) {
                                final hasTimer = player.sleepTimerMinutes != null;
                                final remainingSec = player.sleepTimerRemainingSeconds;
                                final timerText = hasTimer
                                    ? (player.pauseAfterCurrent ? '播完停' : '${(remainingSec / 60).ceil()}分')
                                    : '定时';
                                return TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: hasTimer ? theme.accentColor : null,
                                    backgroundColor: hasTimer ? theme.accentColor.withValues(alpha: 0.12) : null,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: Icon(
                                    hasTimer ? Icons.hourglass_top_rounded : Icons.bedtime_rounded,
                                    size: 16,
                                    color: hasTimer ? theme.accentColor : null,
                                  ),
                                  label: Text(
                                    timerText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: hasTimer ? FontWeight.bold : FontWeight.normal,
                                      color: hasTimer ? theme.accentColor : null,
                                    ),
                                  ),
                                  onPressed: () {
                                    showDialog(context: context, builder: (_) => const SleepTimerModal());
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// 2. 移动端待播队列底部弹层 (MobileQueueBottomSheet)
class MobileQueueBottomSheet extends StatelessWidget {
  const MobileQueueBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: MellowRadii.r28),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('当前播放队列 (${player.playlist.length})', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SoftButton(
                    icon: Icons.delete_outline_rounded,
                    isCircle: true,
                    tooltip: '清空队列',
                    onTap: () => player.clearQueue(),
                  ),
                  const SizedBox(width: 8),
                  SoftButton(
                    icon: Icons.close_rounded,
                    isCircle: true,
                    tooltip: '关闭',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: player.playlist.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final t = player.playlist[idx];
                final isCur = idx == player.currentIndex;

                return SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  borderRadius: MellowRadii.borderR12,
                  color: isCur ? theme.accentColor.withValues(alpha: 0.12) : null,
                  onTap: () {
                    player.playTrack(t);
                  },
                  child: Row(
                    children: [
                      MellowImage(url: t.coverUrl, width: 38, height: 38, borderRadius: MellowRadii.borderR8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCur ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13.5,
                                color: isCur ? theme.accentColor : theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isCur ? theme.accentColor.withValues(alpha: 0.8) : theme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCur) Icon(Icons.graphic_eq_rounded, color: theme.accentColor, size: 20),
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

/// 移动端音量微调弹层组件
class _MobileVolumeDialog extends StatelessWidget {
  const _MobileVolumeDialog();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.borderColor.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      player.volume > 0.5
                          ? Icons.volume_up_rounded
                          : (player.volume > 0 ? Icons.volume_down_rounded : Icons.volume_off_rounded),
                      color: theme.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '软音量微调',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary),
                    ),
                  ],
                ),
                Text(
                  '${(player.volume * 100).toInt()}%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.accentColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.accentColor,
                inactiveTrackColor: theme.borderColor.withValues(alpha: 0.4),
                thumbColor: theme.accentColor,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 4,
              ),
              child: Slider(
                value: player.volume.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: (v) => player.setVolume(v),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => player.setVolume(0.0),
                  child: const Text('静音', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => player.setVolume(0.5),
                  child: const Text('50%', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => player.setVolume(1.0),
                  child: const Text('100%', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
