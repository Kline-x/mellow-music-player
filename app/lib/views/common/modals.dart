import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/storage/storage_service.dart';
import '../../core/sync/sync_data_model.dart';
import '../../core/sync/webdav_sync_service.dart';
import '../../core/sync/lan_sync_service.dart';
import '../../core/sources/lx_source_model.dart';
import '../../core/sources/lx_script_sandbox.dart';

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SoftCard(
          padding: const EdgeInsets.all(22),
          borderRadius: MellowRadii.borderR24,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '声学 10 频段均衡器 (EQ)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '多频段声音动态补偿与声学校准',
                                  style: TextStyle(fontSize: 12, color: theme.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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

                // 10 频段滑块流 (支持自适应与小屏平滑水平滚动)
                RecessedWell(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  borderRadius: MellowRadii.borderR20,
                  child: SizedBox(
                    height: 200,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: constraints.maxWidth < 520
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                              maxWidth: constraints.maxWidth < 520 ? 520 : constraints.maxWidth,
                            ),
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
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 底部重置与直通 (Wrap 弹性流排版，防止窄屏右侧溢出)
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
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

/// 6. 新建自建歌单对话框 (CreatePlaylistModal)
class CreatePlaylistModal extends StatefulWidget {
  final Track? initialTrack;
  final Function(ImportedPlaylist pl)? onCreated;

  const CreatePlaylistModal({
    super.key,
    this.initialTrack,
    this.onCreated,
  });

  @override
  State<CreatePlaylistModal> createState() => _CreatePlaylistModalState();
}

class _CreatePlaylistModalState extends State<CreatePlaylistModal> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入歌单名称')),
      );
      return;
    }

    final player = context.read<AudioPlayerService>();
    final pl = player.createCustomPlaylist(
      title,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      coverUrl: widget.initialTrack?.coverUrl,
      initialTracks: widget.initialTrack != null ? [widget.initialTrack!] : null,
    );

    widget.onCreated?.call(pl);
    Navigator.of(context).pop(pl);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已创建自建歌单「$title」${widget.initialTrack != null ? '，并收录单曲' : ''}！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SoftCard(
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
                        child: Icon(Icons.playlist_add_rounded, color: theme.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '新建自建歌单',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (widget.initialTrack != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: MellowRadii.borderR12,
                  ),
                  child: Row(
                    children: [
                      MellowImage(url: widget.initialTrack!.coverUrl, width: 40, height: 40, borderRadius: MellowRadii.borderR8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.initialTrack!.title,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.initialTrack!.artist,
                              style: TextStyle(fontSize: 11, color: theme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderPill,
                        ),
                        child: Text('收录首曲', style: TextStyle(fontSize: 10.5, color: theme.accentColor, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Text('歌单名称', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textSecondary)),
              const SizedBox(height: 6),
              RecessedWell(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                borderRadius: MellowRadii.borderR12,
                child: TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '如：深夜疗愈电台 / 节奏运动精选',
                    hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 14),

              Text('歌单描述 (选填)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textSecondary)),
              const SizedBox(height: 6),
              RecessedWell(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                borderRadius: MellowRadii.borderR12,
                child: TextField(
                  controller: _descController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '写一段简短的话记录这份歌单的心情...',
                    hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftButton(
                    label: '取消',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  SoftButton(
                    label: '立即创建',
                    icon: Icons.check_rounded,
                    isActive: true,
                    onTap: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 7. 歌曲收录到歌单对话框 (AddToPlaylistModal)
class AddToPlaylistModal extends StatefulWidget {
  final Track track;

  const AddToPlaylistModal({super.key, required this.track});

  @override
  State<AddToPlaylistModal> createState() => _AddToPlaylistModalState();
}

class _AddToPlaylistModalState extends State<AddToPlaylistModal> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;
    final playlists = player.importedPlaylists;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
        child: SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部头部
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
                        child: Icon(Icons.bookmark_add_rounded, color: theme.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('收录到歌单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          Text('将单曲归类至您的专属资料库', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 目标单曲信息预览卡片
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: MellowRadii.borderR12,
                  border: Border.all(color: theme.borderColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    MellowImage(url: widget.track.coverUrl, width: 44, height: 44, borderRadius: MellowRadii.borderR8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.track.title,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.track.artist} · ${widget.track.album}',
                            style: TextStyle(fontSize: 12, color: theme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.track.formattedDuration,
                      style: TextStyle(fontSize: 12, color: theme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 快速新建自建歌单入口条目
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => CreatePlaylistModal(
                      initialTrack: widget.track,
                      onCreated: (_) => setState(() {}),
                    ),
                  );
                },
                borderRadius: MellowRadii.borderR12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.08),
                    borderRadius: MellowRadii.borderR12,
                    border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: theme.accentColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '新建自建歌单并收录此曲',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.accentColor),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13, color: theme.accentColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text('选择要添加的目标歌单', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
              const SizedBox(height: 8),

              // 现有歌单列表
              Expanded(
                child: playlists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.queue_music_rounded, size: 40, color: theme.textMuted),
                            const SizedBox(height: 10),
                            Text('暂无自建或导入歌单', style: TextStyle(color: theme.textMuted, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('点击上方按钮即可创建第一个自建歌单', style: TextStyle(color: theme.textMuted, fontSize: 11)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: playlists.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final pl = playlists[index];
                          final isContained = player.isTrackInPlaylist(pl.id, widget.track.id);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: MellowRadii.borderR12,
                              border: Border.all(
                                color: isContained ? theme.accentColor.withValues(alpha: 0.4) : theme.borderColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                MellowImage(url: pl.coverUrl, width: 42, height: 42, borderRadius: MellowRadii.borderR8),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              pl.title,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                                color: theme.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: (pl.isCustom ? theme.accentColor : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                                              borderRadius: MellowRadii.borderPill,
                                            ),
                                            child: Text(
                                              pl.isCustom ? '自建' : '导入',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: pl.isCustom ? theme.accentColor : const Color(0xFF3B82F6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '共 ${pl.trackCount} 首音轨',
                                        style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isContained)
                                  InkWell(
                                    onTap: () {
                                      player.removeTrackFromPlaylist(pl.id, widget.track.id);
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('已从歌单「${pl.title}」中移除')),
                                      );
                                    },
                                    borderRadius: MellowRadii.borderPill,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: MellowRadii.borderPill,
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14),
                                          SizedBox(width: 4),
                                          Text('已收录', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  SoftButton(
                                    label: '收录',
                                    icon: Icons.add_rounded,
                                    isPill: true,
                                    isActive: true,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    onTap: () {
                                      final ok = player.addTrackToPlaylist(pl.id, widget.track);
                                      if (ok) {
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('已成功收录到歌单「${pl.title}」！')),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 8. WebDAV 云端服务器配置对话框 (WebDavConfigModal)
class WebDavConfigModal extends StatefulWidget {
  final Function(WebDavConfig savedConfig)? onSave;
  final VoidCallback? onSaved;
  final WebDavConfig? initialConfig;
  const WebDavConfigModal({
    super.key,
    this.onSave,
    this.onSaved,
    this.initialConfig,
  });

  @override
  State<WebDavConfigModal> createState() => _WebDavConfigModalState();
}

class _WebDavConfigModalState extends State<WebDavConfigModal> {
  late TextEditingController _serverCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _dirCtrl;
  bool _isTesting = false;
  String? _testMessage;
  bool? _testSuccess;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final saved = widget.initialConfig ?? StorageService.instance.getWebDavConfig();
    _serverCtrl = TextEditingController(text: saved?.serverUrl ?? 'https://dav.jianguoyun.com/dav/');
    _userCtrl = TextEditingController(text: saved?.username ?? '');
    _passCtrl = TextEditingController(text: saved?.password ?? '');
    _dirCtrl = TextEditingController(text: saved?.remoteDirectory ?? '/mellow_music/');
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  WebDavConfig _buildConfig() {
    return WebDavConfig(
      serverUrl: _serverCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      remoteDirectory: _dirCtrl.text.trim().isEmpty ? '/mellow_music/' : _dirCtrl.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    final config = _buildConfig();
    if (config.serverUrl.isEmpty || config.username.isEmpty || config.password.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = '请完整填写服务器地址、账号和密码/授权码';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = '正在测试连接与鉴权...';
      _testSuccess = null;
    });

    final service = WebDavSyncService(config: config);
    final ok = await service.testConnection();

    setState(() {
      _isTesting = false;
      _testSuccess = ok;
      _testMessage = ok ? 'WebDAV 服务器连接成功，授权有效！' : (service.errorMessage ?? '连接失败，请检查地址或密码');
    });
  }

  Future<void> _saveConfig() async {
    final config = _buildConfig();
    await StorageService.instance.saveWebDavConfig(config);
    widget.onSave?.call(config);
    widget.onSaved?.call();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WebDAV 云端服务器配置已保存！')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: SingleChildScrollView(
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
                          child: Icon(Icons.cloud_sync_rounded, color: theme.accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('配置 WebDAV 私有云盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                            Text('跨设备热备与多端同步', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 快捷填充芯片
                Row(
                  children: [
                    Text('推荐服务商: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _serverCtrl.text = 'https://dav.jianguoyun.com/dav/';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.12),
                          borderRadius: MellowRadii.borderPill,
                        ),
                        child: Text('坚果云 WebDAV', style: TextStyle(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _serverCtrl.text = 'https://your-nextcloud.com/remote.php/dav/files/user/';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: MellowRadii.borderPill,
                        ),
                        child: Text('Nextcloud / 自建', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text('服务器端点 URL', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 6),
                RecessedWell(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: MellowRadii.borderR12,
                  child: TextField(
                    controller: _serverCtrl,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'https://dav.jianguoyun.com/dav/'),
                  ),
                ),
                const SizedBox(height: 12),

                Text('账号 / 邮箱', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 6),
                RecessedWell(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: MellowRadii.borderR12,
                  child: TextField(
                    controller: _userCtrl,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'username@example.com'),
                  ),
                ),
                const SizedBox(height: 12),

                Text('应用密码 / Token', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 6),
                RecessedWell(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: MellowRadii.borderR12,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passCtrl,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: theme.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '第三方应用授权密码'),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: theme.textMuted),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Text('备份子目录 (选填)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 6),
                RecessedWell(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: MellowRadii.borderR12,
                  child: TextField(
                    controller: _dirCtrl,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '/mellow_music/'),
                  ),
                ),
                const SizedBox(height: 16),

                // 测试状态反馈
                if (_testMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_testSuccess == true
                              ? const Color(0xFF10B981)
                              : (_testSuccess == false ? const Color(0xFFEF4444) : theme.accentColor))
                          .withValues(alpha: 0.12),
                      borderRadius: MellowRadii.borderR8,
                    ),
                    child: Row(
                      children: [
                        if (_isTesting)
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor))
                        else
                          Icon(
                            _testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 16,
                            color: _testSuccess == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _testSuccess == true
                                  ? const Color(0xFF10B981)
                                  : (_testSuccess == false ? const Color(0xFFEF4444) : theme.accentColor),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SoftButton(
                      label: _isTesting ? '正在测试...' : '测试连接',
                      icon: Icons.network_check_rounded,
                      onTap: _isTesting ? null : _testConnection,
                    ),
                    Row(
                      children: [
                        SoftButton(
                          label: '取消',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                        SoftButton(
                          label: '保存配置',
                          icon: Icons.save_rounded,
                          isActive: true,
                          onTap: _saveConfig,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 9. 离线快照导出对话框 (ExportSnapshotModal)
class ExportSnapshotModal extends StatelessWidget {
  const ExportSnapshotModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final eq = context.watch<EqualizerManager>();

    final snapshot = SyncSnapshot.createFromAppState(player: player, eqManager: eq);
    final jsonStr = JsonEncoder.withIndent('  ').convert(snapshot.toJson());

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
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
                        child: Icon(Icons.file_upload_outlined, color: theme.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('导出离线曲库快照', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          Text('跨设备冷备份与零网络迁移', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 数据摘要胶囊
              Row(
                children: [
                  _buildSummaryBadge('收藏 ${snapshot.favorites.length} 首', theme),
                  const SizedBox(width: 8),
                  _buildSummaryBadge('歌单 ${snapshot.playlists.length} 个', theme),
                  const SizedBox(width: 8),
                  _buildSummaryBadge('足迹 ${snapshot.history.length} 条', theme),
                  const SizedBox(width: 8),
                  _buildSummaryBadge('EQ ${snapshot.equalizer.presetName}', theme),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: RecessedWell(
                  padding: const EdgeInsets.all(12),
                  borderRadius: MellowRadii.borderR12,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonStr,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: theme.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftButton(
                    label: '关闭',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  SoftButton(
                    label: '一键复制快照 JSON',
                    icon: Icons.copy_rounded,
                    isActive: true,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: jsonStr));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('曲库快照 JSON 已复制到剪贴板！可发送至新设备直接导入。')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(String label, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.12),
        borderRadius: MellowRadii.borderPill,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.bold)),
    );
  }
}

/// 10. 离线快照导入对话框 (ImportSnapshotModal)
class ImportSnapshotModal extends StatefulWidget {
  final VoidCallback? onImported;
  const ImportSnapshotModal({super.key, this.onImported});

  @override
  State<ImportSnapshotModal> createState() => _ImportSnapshotModalState();
}

class _ImportSnapshotModalState extends State<ImportSnapshotModal> {
  final _ctrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请粘贴有效的快照 JSON 内容');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = SyncSnapshot.fromRawJson(text);
      final player = context.read<AudioPlayerService>();
      final eq = context.read<EqualizerManager>();

      // 生成本地快照并执行 LWW 智能合并
      final localSnapshot = SyncSnapshot.createFromAppState(player: player, eqManager: eq);
      final merged = localSnapshot.merge(snapshot);

      // 回灌进应用
      await SyncSnapshot.applyToAppState(merged, player: player, eqManager: eq);

      widget.onImported?.call();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功合并导入 ${snapshot.favorites.length} 首收藏、${snapshot.playlists.length} 个歌单！'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '快照解析失败，请确保格式正确: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
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
                        child: Icon(Icons.file_download_outlined, color: theme.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('导入离线曲库快照', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          Text('智能时间戳冲突合并 (LWW)', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text('请在下方粘贴导出的快照 JSON 数据：', style: TextStyle(fontSize: 12.5, color: theme.textSecondary)),
              const SizedBox(height: 8),

              Expanded(
                child: RecessedWell(
                  padding: const EdgeInsets.all(12),
                  borderRadius: MellowRadii.borderR12,
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: theme.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '{\n  "version": "1.0.0",\n  "favorites": [...]\n}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SoftButton(
                    label: '从剪贴板粘贴',
                    icon: Icons.paste_rounded,
                    onTap: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        setState(() => _ctrl.text = data!.text!);
                      }
                    },
                  ),
                  Row(
                    children: [
                      SoftButton(
                        label: '取消',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      SoftButton(
                        label: _isLoading ? '解析中...' : '解析并合并',
                        icon: Icons.merge_type_rounded,
                        isActive: true,
                        onTap: _isLoading ? null : _handleImport,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 11. 局域网近场直连配对与投送对话框 (LanPairingModal)
class LanPairingModal extends StatefulWidget {
  const LanPairingModal({super.key});

  @override
  State<LanPairingModal> createState() => _LanPairingModalState();
}

class _LanPairingModalState extends State<LanPairingModal> {
  final LanSyncService _lanService = LanSyncService.instance;
  late TextEditingController _targetIpCtrl;
  late TextEditingController _targetPortCtrl;
  late TextEditingController _targetKeyCtrl;
  bool _isPushing = false;
  String? _statusMessage;
  bool? _pushSuccess;

  @override
  void initState() {
    super.initState();
    _targetIpCtrl = TextEditingController();
    _targetPortCtrl = TextEditingController(text: '23332');
    _targetKeyCtrl = TextEditingController();
    _initLan();
  }

  Future<void> _initLan() async {
    await _lanService.ensureServerRunning();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _targetIpCtrl.dispose();
    _targetPortCtrl.dispose();
    _targetKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePush() async {
    final ip = _targetIpCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _statusMessage = '请输入对端设备的局域网 IP 地址';
        _pushSuccess = false;
      });
      return;
    }
    final port = int.tryParse(_targetPortCtrl.text.trim()) ?? 23332;
    final key = _targetKeyCtrl.text.trim();

    setState(() {
      _isPushing = true;
      _statusMessage = '正在向 $ip:$port 发送曲库数据快照...';
      _pushSuccess = null;
    });

    final player = context.read<AudioPlayerService>();
    final eq = EqualizerManager.instance;
    final snapshot = SyncSnapshot.createFromAppState(player: player, eqManager: eq);

    final ok = await _lanService.pushToTarget(
      ip,
      snapshot,
      port: port,
      authKey: key.isNotEmpty ? key : null,
    );

    if (!mounted) return;
    setState(() {
      _isPushing = false;
      _pushSuccess = ok;
      _statusMessage = ok
          ? '成功将曲库快照推送到 $ip:$port！'
          : '投送失败，请检查对端 IP 是否正确且已打开 Mellow Music 同步服务';
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功向 $ip:$port 投送 ${snapshot.favorites.length} 首红心、${snapshot.playlists.length} 个歌单！'),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final localIp = _lanService.currentLocalIp;
    final port = _lanService.serverPort;
    final authKey = _lanService.serverAuthKey;
    final pairingUri = _lanService.generatePairingUri(localIp);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: SingleChildScrollView(
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
                            color: Colors.indigoAccent.withValues(alpha: 0.15),
                            borderRadius: MellowRadii.borderR12,
                          ),
                          child: const Icon(Icons.hub_rounded, color: Colors.indigoAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('局域网近场直连配对', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                            Text('同 Wi-Fi 局域网下秒级 P2P 快照投送与歌单漫游', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.textMuted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 本机服务卡片
                Text('本机节点信息', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 8),
                RecessedWell(
                  padding: const EdgeInsets.all(14),
                  borderRadius: MellowRadii.borderR16,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('本机地址: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                              SelectableText('$localIp:$port', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: '$localIp:$port'));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制本机地址')));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.copy_rounded, size: 15, color: theme.accentColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('配对密钥: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.accentColor.withValues(alpha: 0.15),
                                  borderRadius: MellowRadii.borderPill,
                                ),
                                child: Text(authKey.isNotEmpty ? authKey : '免密', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.accentColor)),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: pairingUri));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制 lxsync:// 完整配对协议链接')));
                            },
                            child: Row(
                              children: [
                                Icon(Icons.link_rounded, size: 15, color: theme.accentColor),
                                const SizedBox(width: 4),
                                Text('复制配对 URI', style: TextStyle(fontSize: 11.5, color: theme.accentColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 手动直连投送目标
                Text('向目标设备直连发送曲库快照', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: RecessedWell(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: MellowRadii.borderR12,
                        child: TextField(
                          controller: _targetIpCtrl,
                          style: TextStyle(color: theme.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '目标设备 IP (如 192.168.1.100)'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: RecessedWell(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        borderRadius: MellowRadii.borderR12,
                        child: TextField(
                          controller: _targetPortCtrl,
                          style: TextStyle(color: theme.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '23332'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RecessedWell(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: MellowRadii.borderR12,
                  child: TextField(
                    controller: _targetKeyCtrl,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '目标配对密钥 (选填)'),
                  ),
                ),
                const SizedBox(height: 14),

                if (_statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _pushSuccess == true
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : (_pushSuccess == false
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : theme.accentColor.withValues(alpha: 0.12)),
                      borderRadius: MellowRadii.borderR12,
                    ),
                    child: Row(
                      children: [
                        if (_isPushing)
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor))
                        else
                          Icon(
                            _pushSuccess == true ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 16,
                            color: _pushSuccess == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _pushSuccess == true ? const Color(0xFF10B981) : (_pushSuccess == false ? const Color(0xFFEF4444) : theme.accentColor),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SoftButton(
                      label: '关闭',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    SoftButton(
                      label: _isPushing ? '正在投送...' : '立即无线投送',
                      icon: Icons.send_rounded,
                      isActive: true,
                      onTap: _isPushing ? null : _handlePush,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 14. 自定义音源脚本导入模态框 (ImportScriptSourceModal)
class ImportScriptSourceModal extends StatefulWidget {
  final VoidCallback? onImportSuccess;
  const ImportScriptSourceModal({super.key, this.onImportSuccess});

  @override
  State<ImportScriptSourceModal> createState() => _ImportScriptSourceModalState();
}

class _ImportScriptSourceModalState extends State<ImportScriptSourceModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _scriptController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  LxSourceMetadata? _parsedMeta;

  static const String _sampleTemplate = '''/*!
 * @name 六维高清云解析
 * @description 支持全网六维音乐高品质无损音源解析与智能降级
 * @version 1.0.0
 * @author AudioGeek
 * @homepage https://github.com/mellow-music/custom-sources
 */

const { EVENT_NAMES, on } = globalThis.lx;

on(EVENT_NAMES.request, async ({ source, action, info }) => {
  switch (action) {
    case 'musicUrl':
      return { url: 'https://cdn.example.com/audio/' + info.musicInfo.songmid + '.mp3' };
    case 'lyric':
      return { lyric: '[00:00.00]自定义音源歌词' };
  }
});
''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scriptController.text = _sampleTemplate;
    _updateParsedMetadata(_sampleTemplate);
    _scriptController.addListener(() {
      _updateParsedMetadata(_scriptController.text);
    });
  }

  void _updateParsedMetadata(String text) {
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _parsedMeta = null);
      return;
    }
    try {
      final meta = LxSourceMetadata.fromScriptHeader(text);
      if (mounted) {
        setState(() {
          _parsedMeta = meta;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _parsedMeta = null);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _handleImportFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = '请输入有效的音源脚本网络 URL 地址');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final meta = await LxSourceEngine.instance.importScriptFromUrl(url);
      if (mounted) {
        widget.onImportSuccess?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入并挂载音源: ${meta.name} (v${meta.version})'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '导入失败: $e';
        });
      }
    }
  }

  Future<void> _handleImportFromScript() async {
    final script = _scriptController.text.trim();
    if (script.isEmpty) {
      setState(() => _errorMessage = '脚本内容不可为空');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final meta = LxSourceEngine.instance.importScript(script);
      if (mounted) {
        widget.onImportSuccess?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入并挂载自定义脚本: ${meta.name} (v${meta.version})'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '脚本校验或挂载失败: $e';
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _scriptController.text = data.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderR12,
                        ),
                        child: Icon(Icons.extension_rounded, color: theme.accentColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('导入外部自定义音源脚本',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          Text('支持遵循 LX-Music 开放音源标准规范的 JavaScript 扩展脚本',
                              style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TabBar(
                controller: _tabController,
                indicatorColor: theme.accentColor,
                labelColor: theme.accentColor,
                unselectedLabelColor: theme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: '网络订阅导入 (URL)'),
                  Tab(text: '直接粘贴/编辑脚本 (JS)'),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: URL 导入
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('脚本订阅或直接下载链接 (HTTP / HTTPS):',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _urlController,
                          style: TextStyle(fontSize: 13, color: theme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'https://example.com/sources/lx-custom-source.js',
                            hintStyle: TextStyle(fontSize: 12, color: theme.textMuted),
                            filled: true,
                            fillColor: theme.canvasColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: MellowRadii.borderR12,
                              borderSide: BorderSide(color: theme.borderColor.withValues(alpha: 0.6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: MellowRadii.borderR12,
                              borderSide: BorderSide(color: theme.borderColor.withValues(alpha: 0.6)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: MellowRadii.borderR12,
                              borderSide: BorderSide(color: theme.accentColor, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        RecessedWell(
                          padding: const EdgeInsets.all(16),
                          borderRadius: MellowRadii.borderR16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.shield_outlined, size: 20, color: theme.accentColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '安全沙箱承诺：所有外部脚本均在内存严格沙箱环境中解析，剥离 process、child_process 等敏感危险 API，确保客户端与系统环境 100% 安全。',
                                  style: TextStyle(fontSize: 12, color: theme.textSecondary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: 直接粘贴脚本
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('JavaScript 音源脚本内容:',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                            InkWell(
                              onTap: _pasteFromClipboard,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.content_paste_rounded, size: 14, color: theme.accentColor),
                                    const SizedBox(width: 4),
                                    Text('从剪贴板粘贴', style: TextStyle(fontSize: 12, color: theme.accentColor)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: _scriptController,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: '粘贴符合规范的音源 JS 源码...',
                              hintStyle: TextStyle(fontSize: 12, color: theme.textMuted),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: MellowRadii.borderR12,
                                borderSide: BorderSide(color: theme.borderColor.withValues(alpha: 0.6)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: MellowRadii.borderR12,
                                borderSide: BorderSide(color: theme.borderColor.withValues(alpha: 0.6)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: MellowRadii.borderR12,
                                borderSide: BorderSide(color: theme.accentColor, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 实时解析元数据小卡片
              if (_parsedMeta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.08),
                    borderRadius: MellowRadii.borderR12,
                    border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 18, color: theme.accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '已识别元数据: ${_parsedMeta!.name} · v${_parsedMeta!.version} · 作者: ${_parsedMeta!.author}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.accentColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftButton(
                    label: '取消',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  SoftButton(
                    label: _isLoading ? '正在校验导入...' : '确认导入并挂载',
                    icon: Icons.check_circle_rounded,
                    isActive: true,
                    isPill: true,
                    onTap: _isLoading
                        ? null
                        : () {
                            if (_tabController.index == 0) {
                              _handleImportFromUrl();
                            } else {
                              _handleImportFromScript();
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 15. 查看音源详情与脚本内容模态框 (ViewScriptSourceModal)
class ViewScriptSourceModal extends StatelessWidget {
  final LxSourceMetadata metadata;
  const ViewScriptSourceModal({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderR12,
                        ),
                        child: Icon(Icons.code_rounded, color: theme.accentColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metadata.name,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          Text('版本: v${metadata.version} · 作者: ${metadata.author}',
                              style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (metadata.description.isNotEmpty) ...[
                Text(metadata.description, style: TextStyle(fontSize: 13, color: theme.textSecondary)),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Text('支持音质: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                  for (final q in metadata.supportedQualities)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.12),
                        borderRadius: MellowRadii.borderPill,
                      ),
                      child: Text(q.label, style: TextStyle(fontSize: 10.5, color: theme.accentColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              Text('脚本源代码预览:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                    borderRadius: MellowRadii.borderR12,
                    border: Border.all(color: theme.borderColor.withValues(alpha: 0.5)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      metadata.scriptContent ?? '// 内置音源，代码编译于原生二进制驱动中。',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (metadata.scriptContent != null && metadata.scriptContent!.isNotEmpty)
                    SoftButton(
                      label: '复制代码',
                      icon: Icons.copy_rounded,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: metadata.scriptContent!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('脚本源码已复制到剪贴板')),
                        );
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  SoftButton(
                    label: '关闭',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 8. 真实音源主动切换与调度弹窗 (SourceSwitcherModal)
class SourceSwitcherModal extends StatefulWidget {
  final Track track;
  const SourceSwitcherModal({super.key, required this.track});

  @override
  State<SourceSwitcherModal> createState() => _SourceSwitcherModalState();
}

class _SourceSwitcherModalState extends State<SourceSwitcherModal> {
  bool _isSwitching = false;
  String? _switchingTarget;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;
    final currentSource = widget.track.source;

    final sources = [
      {
        'id': 'kuwo-sq',
        'name': '酷我音乐 · 高保真源',
        'badge': '推荐 · SQ无损',
        'desc': '主打高保真音质，收录海量流行歌曲原声，高清晰度流媒体',
        'icon': Icons.album_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'id': 'netease-online',
        'name': '网易云音乐 · 在线源',
        'badge': '官方流',
        'desc': '主流开放曲库，支持原生高品质 MP3 流与声学专辑匹配',
        'icon': Icons.cloud_queue_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'id': 'itunes-preview',
        'name': 'iTunes · 官方保底源',
        'badge': '全球高可用',
        'desc': '苹果官方 CDN 高可用试听流，网络受限时稳定兜底播放',
        'icon': Icons.apple_rounded,
        'color': const Color(0xFF6366F1),
      },
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: MellowColors.card(isDark),
            borderRadius: MellowRadii.borderR24,
            boxShadow: isDark ? MellowShadows.floatingPillDark : MellowShadows.floatingPillLight,
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部标题与曲目信息
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.swap_calls_rounded, color: theme.accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主动切换播放音源',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '正在播放：「${widget.track.title}」 - ${widget.track.artist}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: theme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Text(
                '选择目标音频源（切换后将保持当前进度平滑重播）：',
                style: TextStyle(fontSize: 12.5, color: theme.textMuted),
              ),
              const SizedBox(height: 12),

              // 音源卡片列表
              ...sources.map((s) {
                final id = s['id'] as String;
                final name = s['name'] as String;
                final badge = s['badge'] as String;
                final desc = s['desc'] as String;
                final icon = s['icon'] as IconData;
                final color = s['color'] as Color;
                final isCurrent = currentSource.contains(id.replaceAll('-sq', '').replaceAll('-online', '').replaceAll('-preview', ''));
                final isTarget = _switchingTarget == id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    borderRadius: MellowRadii.borderR16,
                    onTap: (_isSwitching || isCurrent)
                        ? null
                        : () async {
                            setState(() {
                              _isSwitching = true;
                              _switchingTarget = id;
                            });
                            final ok = await player.switchSource(widget.track, id);
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? '已成功切换至【${AudioPlayerService.formatSourceDisplayName(id)}】'
                                      : '切换失败，该源未匹配到「${widget.track.title}」有效音频'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                desc,
                                style: TextStyle(fontSize: 11, color: theme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isTarget && _isSwitching)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor),
                          )
                        else if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.15),
                              borderRadius: MellowRadii.borderPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded, size: 12, color: theme.accentColor),
                                const SizedBox(width: 3),
                                Text(
                                  '生效中',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: theme.accentColor),
                                ),
                              ],
                            ),
                          )
                        else
                          Icon(Icons.chevron_right_rounded, size: 18, color: theme.textMuted),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}



