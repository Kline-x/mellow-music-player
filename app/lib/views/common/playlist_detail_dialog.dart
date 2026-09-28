import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/sources/online_music_service.dart';
import '../../core/sources/scenario_playlist_service.dart';
import '../../design_system/mellow_image.dart';
import '../../design_system/soft_button.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/tokens.dart';

/// 通用歌单曲目明细弹窗与抽屉 (PlaylistDetailDialog)
class PlaylistDetailDialog extends StatefulWidget {
  final ImportedPlaylist playlist;
  final bool isBottomSheet;

  const PlaylistDetailDialog({
    super.key,
    required this.playlist,
    this.isBottomSheet = false,
  });

  /// 静态辅助方法：快速在桌面端以 Dialog 形式打开
  static Future<void> showDesktopDialog(BuildContext context, ImportedPlaylist playlist) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => PlaylistDetailDialog(playlist: playlist, isBottomSheet: false),
    );
  }

  /// 静态辅助方法：快速在移动端以 BottomSheet 形式打开
  static Future<void> showMobileSheet(BuildContext context, ImportedPlaylist playlist) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaylistDetailDialog(playlist: playlist, isBottomSheet: true),
    );
  }

  @override
  State<PlaylistDetailDialog> createState() => _PlaylistDetailDialogState();
}

class _PlaylistDetailDialogState extends State<PlaylistDetailDialog> {
  late ImportedPlaylist _currentPlaylist;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPlaylist = widget.playlist;
    if (_currentPlaylist.tracks.isEmpty) {
      _loadTracks();
    }
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await ScenarioPlaylistService.instance.getScenarioPlaylistDetail(_currentPlaylist.id);
      if (mounted) {
        if (detail != null && detail.tracks.isNotEmpty) {
          setState(() {
            _currentPlaylist = detail;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = '未获取到此歌单的有效曲目';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载曲目失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    final content = Container(
      decoration: BoxDecoration(
        color: MellowColors.card(isDark),
        borderRadius: widget.isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : MellowRadii.borderR24,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 移动端拖拽药丸指示把手
          if (widget.isBottomSheet)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: theme.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

          // 头部歌单信息区
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: MellowRadii.borderR16,
                  child: MellowImage(
                    url: _currentPlaylist.coverUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentPlaylist.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: theme.textMuted,
                            onPressed: () => Navigator.of(context).pop(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentPlaylist.description.isNotEmpty
                            ? _currentPlaylist.description
                            : '场景定制精选歌单 · 共 ${_currentPlaylist.tracks.length} 首高保真音频',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          SoftButton(
                            label: '播放全部',
                            icon: Icons.play_arrow_rounded,
                            isActive: true,
                            isPill: true,
                            onTap: _currentPlaylist.tracks.isEmpty
                                ? null
                                : () {
                                    player.playPlaylist(_currentPlaylist.tracks, startIndex: 0);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('正在播放歌单「${_currentPlaylist.title}」（共 ${_currentPlaylist.tracks.length} 首）'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                          ),
                          SoftButton(
                            label: '收藏到我的歌单',
                            icon: Icons.bookmark_add_rounded,
                            isPill: true,
                            onTap: () {
                              player.addImportedPlaylist(_currentPlaylist);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已将歌单「${_currentPlaylist.title}」收藏至资料库！'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
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

          const Divider(height: 1, thickness: 0.6),

          // 歌曲明细列表区
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 36, color: theme.textMuted),
                              const SizedBox(height: 10),
                              Text(_errorMessage!, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                              const SizedBox(height: 12),
                              SoftButton(label: '重新加载', onTap: _loadTracks),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _currentPlaylist.tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final track = _currentPlaylist.tracks[index];
                          final isPlayingThis = player.currentTrack?.id == track.id;

                          return SoftCard(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            borderRadius: MellowRadii.borderR12,
                            onTap: () {
                              player.playPlaylist(_currentPlaylist.tracks, startIndex: index);
                            },
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: isPlayingThis
                                      ? Icon(Icons.volume_up_rounded, color: theme.accentColor, size: 18)
                                      : Text(
                                          '${index + 1}'.padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.textMuted,
                                          ),
                                        ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: MellowImage(
                                    url: track.coverUrl,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w600,
                                          color: isPlayingThis ? theme.accentColor : theme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${track.artist} · ${track.album.isNotEmpty ? track.album : "精选专辑"}',
                                        style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  track.formattedDuration,
                                  style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: Icon(
                                    player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: player.isFavorite(track.id) ? const Color(0xFFFF3366) : theme.textMuted,
                                  ),
                                  onPressed: () => player.toggleFavorite(track.id, track),
                                  visualDensity: VisualDensity.compact,
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

    if (widget.isBottomSheet) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: content,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: content,
      ),
    );
  }
}
