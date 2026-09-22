import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/soft_button.dart';
import '../../design_system/recessed_well.dart';
import '../../design_system/mellow_image.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/equalizer_manager.dart';
import '../../core/audio/track_model.dart';

/// 1. 播放队列抽屉 (Queue Drawer / Sheet)
class PlaybackQueueView extends StatelessWidget {
  final VoidCallback? onClose;
  const PlaybackQueueView({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerService>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MellowColors.card(isDark),
        borderRadius: const BorderRadius.horizontal(left: MellowRadii.r24),
        boxShadow: isDark ? MellowShadows.floatingPillDark : MellowShadows.floatingPillLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '待播队列',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共 ${player.playlist.length} 首曲目',
                    style: TextStyle(fontSize: 12, color: theme.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  SoftButton(
                    icon: Icons.delete_outline_rounded,
                    isCircle: true,
                    tooltip: '清空列表',
                    onTap: () {
                      player.clearQueue();
                    },
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 8),
                    SoftButton(
                      icon: Icons.close_rounded,
                      isCircle: true,
                      onTap: onClose,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: player.playlist.isEmpty
                ? Center(
                    child: Text(
                      '待播列表为空',
                      style: TextStyle(color: theme.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: player.playlist.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = player.playlist[index];
                      final isCurrent = index == player.currentIndex;

                      return SoftCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        borderRadius: MellowRadii.borderR16,
                        color: isCurrent
                            ? theme.accentColor.withOpacity(0.12)
                            : null,
                        onTap: () => player.playTrack(track),
                        child: Row(
                          children: [
                            MellowImage(
                              url: track.coverUrl,
                              width: 42,
                              height: 42,
                              borderRadius: MellowRadii.borderR8,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                      color: isCurrent ? theme.accentColor : theme.textPrimary,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent) ...[
                              Icon(Icons.graphic_eq_rounded, size: 18, color: theme.accentColor),
                              const SizedBox(width: 8),
                            ],
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: theme.textMuted,
                              onPressed: () => player.removeTrackAt(index),
                            ),
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

/// 2. 声学 10 频段 EQ 调节弹窗 (Equalizer Modal)
class EqualizerModal extends StatelessWidget {
  const EqualizerModal({super.key});

  @override
  Widget build(BuildContext context) {
    final eq = context.watch<EqualizerManager>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SoftCard(
        width: 640,
        padding: const EdgeInsets.all(24),
        borderRadius: MellowRadii.borderR24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withOpacity(0.15),
                        borderRadius: MellowRadii.borderR12,
                      ),
                      child: Icon(Icons.tune_rounded, color: theme.accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '声学 10 频段硬件均衡器 (DSP EQ)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          '基于 libmpv firequalizer 高保真声学校准',
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                SoftButton(
                  icon: Icons.close_rounded,
                  isCircle: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 预设选择胶囊
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: EqualizerPreset.values.map((preset) {
                  final isSelected = eq.currentPreset == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SoftButton(
                      label: preset.label,
                      isActive: isSelected,
                      isPill: true,
                      onTap: () => eq.applyPreset(preset),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // 10 频段滑块流
            RecessedWell(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              borderRadius: MellowRadii.borderR20,
              child: SizedBox(
                height: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (index) {
                    final freq = EqualizerManager.frequencyBands[index];
                    final gain = eq.bandGains[index];

                    return Column(
                      children: [
                        Text(
                          '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: gain != 0 ? theme.accentColor : theme.textMuted,
                          ),
                        ),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                activeTrackColor: theme.accentColor,
                                inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                                thumbColor: theme.accentColor,
                                overlayColor: theme.accentColor.withOpacity(0.15),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              ),
                              child: Slider(
                                value: gain,
                                min: -12.0,
                                max: 12.0,
                                onChanged: (val) => eq.setBandGain(index, val),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          freq,
                          style: TextStyle(fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 底部重置与直通
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Switch.adaptive(
                      value: eq.isEnabled,
                      activeColor: theme.accentColor,
                      onChanged: (_) => eq.toggleEnabled(),
                    ),
                    Text(
                      eq.isEnabled ? '均衡器已启用' : '直通原声 (已旁路)',
                      style: TextStyle(fontSize: 13, color: theme.textSecondary),
                    ),
                  ],
                ),
                SoftButton(
                  label: '恢复默认 (Flat)',
                  icon: Icons.refresh_rounded,
                  onTap: () => eq.reset(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. 睡眠定时器弹窗 (Sleep Timer Modal)
class SleepTimerModal extends StatelessWidget {
  const SleepTimerModal({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerService>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    final remaining = player.sleepTimerRemainingSeconds;
    final hasActiveTimer = player.sleepTimerMinutes != null;

    final minutesOptions = [15, 30, 45, 60, 90];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: SoftCard(
        width: 380,
        padding: const EdgeInsets.all(24),
        borderRadius: MellowRadii.borderR24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withOpacity(0.15),
                        borderRadius: MellowRadii.borderR12,
                      ),
                      child: Icon(Icons.bedtime_rounded, color: theme.accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '睡眠定时器',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
                SoftButton(
                  icon: Icons.close_rounded,
                  isCircle: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (hasActiveTimer) ...[
              RecessedWell(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('倒计时进行中', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '剩余 ${remaining ~/ 60} 分 ${remaining % 60} 秒后停止播放',
                            style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    SoftButton(
                      label: '取消',
                      onTap: () => player.cancelSleepTimer(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              '选择关闭时间',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: minutesOptions.map((mins) {
                final isCurrent = player.sleepTimerMinutes == mins;
                return SoftButton(
                  label: '$mins 分钟',
                  isActive: isCurrent,
                  isPill: true,
                  onTap: () {
                    player.startSleepTimer(mins);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              borderRadius: MellowRadii.borderR16,
              onTap: () {
                player.startSleepTimer(999, pauseAfterCurrentSong: true);
                Navigator.of(context).pop();
              },
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded, size: 20, color: theme.accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('播放完当前曲目后停止', style: TextStyle(fontSize: 13.5, color: theme.textPrimary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. 全局快捷联想搜索浮层 (Quick Search Modal - Ctrl+K)
class QuickSearchOverlay extends StatefulWidget {
  const QuickSearchOverlay({super.key});

  @override
  State<QuickSearchOverlay> createState() => _QuickSearchOverlayState();
}

class _QuickSearchOverlayState extends State<QuickSearchOverlay> {
  final TextEditingController _controller = TextEditingController();
  List<Track> _results = [];

  @override
  void initState() {
    super.initState();
    _results = mockPresetTracks;
  }

  void _onSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _results = mockPresetTracks;
      } else {
        _results = mockPresetTracks
            .where((t) =>
                t.title.toLowerCase().contains(query.toLowerCase()) ||
                t.artist.toLowerCase().contains(query.toLowerCase()) ||
                t.album.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 20, right: 20),
      child: SoftCard(
        width: 580,
        padding: const EdgeInsets.all(20),
        borderRadius: MellowRadii.borderR24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RecessedWell(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: MellowRadii.borderR20,
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: theme.accentColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onSearch,
                      style: TextStyle(color: theme.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '搜索歌曲、歌手、专辑或歌单 (按 ESC 退出)...',
                        hintStyle: TextStyle(color: theme.textMuted, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      color: theme.textMuted,
                      onPressed: () {
                        _controller.clear();
                        _onSearch('');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('无匹配结果，支持通过音源全网搜索', style: TextStyle(color: theme.textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final track = _results[index];
                        return SoftCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          borderRadius: MellowRadii.borderR12,
                          onTap: () {
                            player.playTrack(track);
                            Navigator.of(context).pop();
                          },
                          child: Row(
                            children: [
                              MellowImage(
                                url: track.coverUrl,
                                width: 36,
                                height: 36,
                                borderRadius: MellowRadii.borderR8,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${track.artist} · ${track.album}',
                                      style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.play_circle_fill_rounded, size: 24, color: theme.accentColor),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
