import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track_model.dart';
import '../../core/storage/storage_service.dart';
import '../../core/window/desktop_floating_lyric_service.dart';
import '../../design_system/theme_provider.dart';

/// 桌面悬浮动效歌词小组件 (DesktopFloatingLyricBar)
/// 提供现代柔光质感、双行歌词轮播、鼠标拖拽移动、悬浮微控面板与锁定穿透功能
class DesktopFloatingLyricBar extends StatefulWidget {
  final VoidCallback onClose;
  final Offset? initialPosition;

  const DesktopFloatingLyricBar({
    super.key,
    required this.onClose,
    this.initialPosition,
  });

  @override
  State<DesktopFloatingLyricBar> createState() => _DesktopFloatingLyricBarState();
}

class _DesktopFloatingLyricBarState extends State<DesktopFloatingLyricBar> {
  late Offset _position;
  bool _isLocked = false;
  bool _isHovered = false;
  bool _isLargeFont = false;
  final DesktopFloatingLyricService _lyricService = DesktopFloatingLyricService.instance;

  @override
  void initState() {
    super.initState();
    _isLocked = _lyricService.isLocked || (StorageService.instance.getFloatingLyricLocked() ?? false);
    _isLargeFont = _lyricService.fontSizeLevel != 'normal';
    _position = widget.initialPosition ?? _lyricService.position ?? const Offset(360, 60);
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
    _lyricService.setLocked(_isLocked);
    StorageService.instance.saveFloatingLyricLocked(_isLocked);
  }

  void _toggleFontSize() {
    setState(() {
      _isLargeFont = !_isLargeFont;
    });
    _lyricService.cycleFontSize();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerService>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final track = player.currentTrack;

    // 计算当前歌词行与下一行
    String currentLine = '♪ Mellow Music · 润音 ♪';
    String nextLine = track != null
        ? (track.artist.isNotEmpty ? '${track.title} - ${track.artist}' : track.title)
        : '暂无播放曲目，请在主界面点播';

    if (track != null && track.lyrics.isNotEmpty) {
      int activeIndex = -1;
      for (int i = 0; i < track.lyrics.length; i++) {
        if (player.currentPosition >= track.lyrics[i].time) {
          activeIndex = i;
        }
      }
      if (activeIndex != -1) {
        currentLine = track.lyrics[activeIndex].text;
        if (activeIndex + 1 < track.lyrics.length) {
          nextLine = track.lyrics[activeIndex + 1].text;
        } else {
          nextLine = '··· 尾奏 ···';
        }
      } else {
        currentLine = track.lyrics.first.text;
        if (track.lyrics.length > 1) {
          nextLine = track.lyrics[1].text;
        }
      }
    }

    _lyricService.updateLyric(
      currentLine: currentLine,
      nextLine: nextLine,
      track: track,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 边界防溢出约束
        final maxX = max(20.0, constraints.maxWidth - 580);
        final maxY = max(20.0, constraints.maxHeight - 140);
        final clampedX = _position.dx.clamp(10.0, maxX);
        final clampedY = _position.dy.clamp(10.0, maxY);

        return Stack(
          children: [
            Positioned(
              left: clampedX,
              top: clampedY,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (!_isLocked) {
                    setState(() {
                      _position += details.delta;
                    });
                  }
                },
                onPanEnd: (_) {
                  if (!_isLocked) {
                    _lyricService.savePosition(_position);
                  }
                },
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 560,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: _isLocked ? 0.40 : 0.65)
                            : Colors.white.withValues(alpha: _isLocked ? 0.60 : 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _isHovered && !_isLocked
                              ? theme.accentColor.withValues(alpha: 0.45)
                              : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 顶部工具控制栏 (鼠标悬停或处于解锁状态时呈现)
                          if (!_isLocked && _isHovered) ...[
                            _buildControlToolbar(context, player, theme, isDark, track),
                            const SizedBox(height: 6),
                          ] else if (_isLocked && _isHovered) ...[
                            // 锁定状态下的微型解锁把手
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Tooltip(
                                  message: '已锁定歌词，点击解锁',
                                  child: InkWell(
                                    onTap: _toggleLock,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.lock_rounded,
                                        size: 14,
                                        color: theme.accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // 歌词主文本区 (支持点击穿透与直接视听)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              currentLine,
                              key: ValueKey<String>(currentLine),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: _isLargeFont ? 21.0 : 17.5,
                                fontWeight: FontWeight.w700,
                                color: theme.accentColor,
                                letterSpacing: 0.4,
                                shadows: [
                                  Shadow(
                                    color: theme.accentColor.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // 下一句歌词预告 (次级浅色文本)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              nextLine,
                              key: ValueKey<String>(nextLine),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: _isLargeFont ? 13.5 : 12.0,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlToolbar(
    BuildContext context,
    AudioPlayerService player,
    ThemeProvider theme,
    bool isDark,
    Track? track,
  ) {
    return Row(
      children: [
        // 拖拽手柄
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _position += details.delta;
            });
          },
          onPanEnd: (_) {
            _lyricService.savePosition(_position);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '拖拽',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 正在播放简标
        Expanded(
          child: Text(
            track != null ? '${track.title} · ${track.artist}' : '未在播放曲目',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ),

        // 播放控制微按钮集
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 16),
          color: isDark ? Colors.white70 : Colors.black54,
          tooltip: '上一曲',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          onPressed: () => player.previous(),
        ),
        IconButton(
          icon: Icon(
            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 18,
          ),
          color: theme.accentColor,
          tooltip: player.isPlaying ? '暂停' : '播放',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => player.togglePlay(),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 16),
          color: isDark ? Colors.white70 : Colors.black54,
          tooltip: '下一曲',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          onPressed: () => player.next(),
        ),
        const SizedBox(width: 6),

        // 窗口置顶按键 (Win32 HWND_TOPMOST)
        IconButton(
          icon: Icon(
            _lyricService.isAlwaysOnTop ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            size: 14,
          ),
          color: _lyricService.isAlwaysOnTop ? theme.accentColor : (isDark ? Colors.white70 : Colors.black54),
          tooltip: _lyricService.isAlwaysOnTop ? '取消窗口置顶' : '窗口始终置顶',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () {
            setState(() {});
            _lyricService.toggleAlwaysOnTop();
          },
        ),

        // 字体调节
        IconButton(
          icon: Icon(
            _isLargeFont ? Icons.text_decrease_rounded : Icons.text_increase_rounded,
            size: 15,
          ),
          color: isDark ? Colors.white70 : Colors.black54,
          tooltip: _isLargeFont ? '标准字号' : '放大字号',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: _toggleFontSize,
        ),

        // 锁定按键
        IconButton(
          icon: const Icon(Icons.lock_open_rounded, size: 14),
          color: isDark ? Colors.white70 : Colors.black54,
          tooltip: '锁定歌词位置',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: _toggleLock,
        ),

        // 关闭按键
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 14),
          color: isDark ? Colors.white70 : Colors.black54,
          tooltip: '关闭桌面歌词',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: widget.onClose,
        ),
      ],
    );
  }
}
