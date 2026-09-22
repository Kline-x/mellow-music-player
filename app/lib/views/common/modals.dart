import 'dart:async';
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
import '../../core/sources/online_music_service.dart';

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
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = player.playlist[index];
                      final isCurrent = index == player.currentIndex;

                      return SoftCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        borderRadius: MellowRadii.borderR16,
                        color: isCurrent
                            ? theme.accentColor.withValues(alpha: 0.12)
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
                        color: theme.accentColor.withValues(alpha: 0.15),
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
                                overlayColor: theme.accentColor.withValues(alpha: 0.15),
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
                      activeTrackColor: theme.accentColor,
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
                        color: theme.accentColor.withValues(alpha: 0.15),
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
  bool _isLoading = false;
  Timer? _debounce;

  final List<String> _hotTags = ['周杰伦', '告五人', '落日飞车', '陈奕迅', '轻音乐', '粤语经典'];

  @override
  void initState() {
    super.initState();
    _results = mockPresetTracks;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    final clean = query.trim();

    // 先执行本地即时匹配
    if (clean.isEmpty) {
      setState(() {
        _results = mockPresetTracks;
        _isLoading = false;
      });
      return;
    }

    final localMatches = mockPresetTracks
        .where((t) =>
            t.title.toLowerCase().contains(clean.toLowerCase()) ||
            t.artist.toLowerCase().contains(clean.toLowerCase()) ||
            t.album.toLowerCase().contains(clean.toLowerCase()))
        .toList();

    setState(() {
      _results = localMatches;
      _isLoading = true;
    });

    // 防抖 350ms 发起全网在线歌曲实时搜索
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final onlineSongs = await OnlineMusicService.searchOnlineTracks(clean);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (onlineSongs.isNotEmpty) {
          // 合并结果，排重
          final combined = List<Track>.from(localMatches);
          final existingIds = combined.map((e) => e.id).toSet();
          for (final song in onlineSongs) {
            if (!existingIds.contains(song.id)) {
              combined.add(song);
            }
          }
          _results = combined;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 20, right: 20),
      child: SoftCard(
        width: 620,
        padding: const EdgeInsets.all(22),
        borderRadius: MellowRadii.borderR24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        hintText: '搜索全网歌曲、歌手、专辑 (按 ESC 退出)...',
                        hintStyle: TextStyle(color: theme.textMuted, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.accentColor,
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
                  IconButton(
                    key: const Key('quick_search_close_button'),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: theme.textMuted,
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 热搜标签
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _hotTags.map((tag) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = tag;
                    _onSearch(tag);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.1),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 12, color: theme.accentColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          _isLoading ? '正在全网检索高品质音源...' : '无匹配结果，支持任意关键词搜索全网',
                          style: TextStyle(color: theme.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final track = _results[index];
                        final isOnline = track.source.startsWith('netease');

                        return SoftCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          borderRadius: MellowRadii.borderR16,
                          onTap: () {
                            player.playTrack(track);
                            Navigator.of(context).pop();
                          },
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
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            track.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: theme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isOnline) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: theme.accentColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '在线音源',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: theme.accentColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${track.artist} · ${track.album}',
                                      style: TextStyle(fontSize: 12, color: theme.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.play_circle_fill_rounded, size: 28, color: theme.accentColor),
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

/// 5. 导入外部歌单弹窗 (Import Playlist Modal - AlgerMusicPlayer 杀手级能力)
class ImportPlaylistModal extends StatefulWidget {
  const ImportPlaylistModal({super.key});

  @override
  State<ImportPlaylistModal> createState() => _ImportPlaylistModalState();
}

class _ImportPlaylistModalState extends State<ImportPlaylistModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;
  ImportedPlaylist? _imported;

  final List<Map<String, String>> _quickPresets = [
    {'title': '官方热歌榜', 'id': '3778678'},
    {'title': '飙升巅峰榜', 'id': '19723756'},
    {'title': '新歌推荐榜', 'id': '3779629'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _doImport() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await OnlineMusicService.importNeteasePlaylist(text);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res != null) {
        _imported = res;
      } else {
        _errorMsg = '解析失败，请检查歌单ID或网络连接';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SoftCard(
        width: 520,
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
                        color: theme.accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.queue_music_rounded, color: theme.accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '一键导入外部歌单',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          '支持网易云音乐公开歌单 ID 或分享链接一键解析',
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 输入框
            RecessedWell(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              borderRadius: MellowRadii.borderR16,
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: theme.accentColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: theme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '输入歌单ID (如 3778678) 或粘贴分享链接...',
                        hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _doImport(),
                    ),
                  ),
                  if (_isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor),
                    )
                  else
                    SoftButton(
                      label: '解析',
                      isActive: true,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      onTap: _doImport,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 快速填充预设
            Row(
              children: [
                Text('快速体验: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                const SizedBox(width: 6),
                for (final item in _quickPresets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        _controller.text = item['id']!;
                        _doImport();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          border: Border.all(color: theme.borderColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['title']!,
                          style: TextStyle(fontSize: 11, color: theme.accentColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],

            if (_imported != null) ...[
              const SizedBox(height: 20),
              SoftCard(
                padding: const EdgeInsets.all(14),
                borderRadius: MellowRadii.borderR16,
                color: theme.accentColor.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    MellowImage(
                      url: _imported!.coverUrl,
                      width: 60,
                      height: 60,
                      borderRadius: MellowRadii.borderR12,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _imported!.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共解析成功 ${_imported!.trackCount} 首高保真曲目',
                            style: TextStyle(fontSize: 12, color: theme.accentColor),
                          ),
                          Text(
                            _imported!.description,
                            style: TextStyle(fontSize: 11, color: theme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftButton(
                    label: '存入资料库',
                    icon: Icons.bookmark_add_rounded,
                    onTap: () {
                      player.addImportedPlaylist(_imported!);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已将《${_imported!.title}》保存至我的资料库！')),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  SoftButton(
                    label: '一键全部播放',
                    icon: Icons.play_arrow_rounded,
                    isActive: true,
                    onTap: () {
                      player.addImportedPlaylist(_imported!);
                      player.playPlaylist(_imported!.tracks);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
