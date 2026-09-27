import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/soft_button.dart';
import '../../design_system/recessed_well.dart';
import '../../design_system/mellow_image.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track_model.dart';
import '../../core/sources/online_music_service.dart';
import '../../core/sources/daily_recommend_service.dart';
import '../../core/storage/storage_service.dart';

/// 1. 每日推荐二级页面 (拟物日历便签头 + 28 首高保真精选日推曲目)
class MobileDailyRecommendPage extends StatelessWidget {
  final VoidCallback onBack;
  const MobileDailyRecommendPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final service = DailyRecommendService.instance;
    final tracks = service.getDailyRecommendTracks();
    final greeting = service.getGreeting();
    final dayStr = service.getFormattedDay();
    final weekdayStr = service.getFormattedWeekday();
    final monthYearStr = service.getFormattedMonthYear();

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text('每日推荐', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // 拟物日历便签头
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3366), Color(0xFFFF655B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: MellowRadii.borderR16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$monthYearStr · $weekdayStr',
                        style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(dayStr, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3366).withValues(alpha: 0.12),
                                borderRadius: MellowRadii.borderPill,
                              ),
                              child: const Text(
                                '专属声学日推 · 每日 06:00 更新',
                                style: TextStyle(color: Color(0xFFFF3366), fontSize: 10, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        greeting,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SoftButton(
                label: '播放全部 (${tracks.length}首)',
                icon: Icons.play_arrow_rounded,
                isActive: true,
                isPill: true,
                onTap: () {
                  if (tracks.isNotEmpty) {
                    player.playPlaylist(tracks, startIndex: 0);
                  }
                },
              ),
              Text('今日契合度 99.8%', style: TextStyle(fontSize: 12, color: theme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(tracks.length, (idx) {
            final t = tracks[idx];
            final isPlaying = player.currentTrack?.id == t.id;
            return SoftCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => player.playPlaylist(tracks, startIndex: idx),
              child: Row(
                children: [
                  MellowImage(url: t.coverUrl, width: 44, height: 44, borderRadius: MellowRadii.borderR8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isPlaying ? theme.accentColor : theme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.artist} · ${t.album}',
                          style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: Colors.pink,
                      size: 20,
                    ),
                    onPressed: () => player.toggleFavorite(t.id, t),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 2. 私人漫游 FM 二级页面 (全屏黑胶旋转大碟、Next漫游切歌、喜欢/丢弃)
class MobilePersonalFMPage extends StatefulWidget {
  final VoidCallback onBack;
  const MobilePersonalFMPage({super.key, required this.onBack});

  @override
  State<MobilePersonalFMPage> createState() => _MobilePersonalFMPageState();
}

class _MobilePersonalFMPageState extends State<MobilePersonalFMPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final track = player.currentTrack ?? mockPresetTracks[0];

    if (player.isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      if (_rotationController.isAnimating) _rotationController.stop();
    }

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text('私人漫游 FM', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 大黑胶大碟
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * pi,
                  child: child,
                );
              },
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF151515),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 10)),
                  ],
                  border: Border.all(color: const Color(0xFF282828), width: 5),
                ),
                child: Center(
                  child: MellowImage(url: track.coverUrl, width: 100, height: 100, borderRadius: MellowRadii.borderPill),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(track.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            const SizedBox(height: 6),
            Text('${track.artist} · ${track.album}', style: TextStyle(fontSize: 14, color: theme.textSecondary)),
            const SizedBox(height: 40),

            // FM 核心三大控制：丢弃垃圾桶 / 喜欢收藏 / Next 漫游
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SoftButton(
                  icon: Icons.delete_outline_rounded,
                  iconSize: 24,
                  isCircle: true,
                  padding: const EdgeInsets.all(16),
                  onTap: () => player.next(),
                ),
                const SizedBox(width: 24),
                SoftButton(
                  icon: player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  iconSize: 26,
                  isCircle: true,
                  padding: const EdgeInsets.all(16),
                  activeColor: Colors.pink,
                  isActive: player.isFavorite(track.id),
                  onTap: () => player.toggleFavorite(track.id),
                ),
                const SizedBox(width: 24),
                SoftButton(
                  icon: Icons.skip_next_rounded,
                  iconSize: 28,
                  isCircle: true,
                  isActive: true,
                  padding: const EdgeInsets.all(16),
                  onTap: () => player.next(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. 歌单广场二级页 (MobilePlaylistSquarePage)
class MobilePlaylistSquarePage extends StatelessWidget {
  final VoidCallback onBack;
  const MobilePlaylistSquarePage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text('歌单广场', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemCount: mockPresetTracks.length,
        itemBuilder: (context, idx) {
          final t = mockPresetTracks[idx];
          return SoftCard(
            padding: const EdgeInsets.all(10),
            onTap: () => player.playTrack(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MellowImage(url: t.coverUrl, width: double.infinity, height: double.infinity, borderRadius: MellowRadii.borderR12),
                ),
                const SizedBox(height: 8),
                Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary)),
                Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 11, color: theme.textMuted)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 4. 巅峰排行榜二级页 (MobileToplistPage)
class MobileToplistPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String chartName)? onSelectToplist;

  const MobileToplistPage({super.key, required this.onBack, this.onSelectToplist});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final charts = ['飙升榜', '热歌榜', '新歌榜', '原创榜'];

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text('官方巅峰排行榜', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: charts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final chartName = charts[idx];
          final chartTracks = toplistTracksMap[chartName] ?? mockPresetTracks;
          return SoftCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              if (onSelectToplist != null) {
                onSelectToplist!(chartName);
              } else if (chartTracks.isNotEmpty) {
                player.playPlaylist(chartTracks, startIndex: 0);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(chartName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                    GestureDetector(
                      onTap: () {
                        if (chartTracks.isNotEmpty) player.playPlaylist(chartTracks, startIndex: 0);
                      },
                      child: Icon(Icons.play_circle_fill_rounded, color: theme.accentColor, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...List.generate(chartTracks.length.clamp(0, 3), (i) {
                  final t = chartTracks[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${i + 1}. ${t.title} - ${t.artist}',
                      style: TextStyle(fontSize: 12.5, color: i == 0 ? theme.accentColor : theme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('查看完整榜单 (${chartTracks.length}首) >', style: TextStyle(fontSize: 11.5, color: theme.accentColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 4.5. 移动端榜单详情页 (MobileToplistDetailPage - 完整展示榜单所有歌曲)
class MobileToplistDetailPage extends StatefulWidget {
  final String chartName;
  final VoidCallback onBack;

  const MobileToplistDetailPage({
    super.key,
    required this.chartName,
    required this.onBack,
  });

  @override
  State<MobileToplistDetailPage> createState() => _MobileToplistDetailPageState();
}

class _MobileToplistDetailPageState extends State<MobileToplistDetailPage> {
  String _chartTitle = '官方榜单';
  List<Track> _tracks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  void _loadTracks() async {
    _chartTitle = widget.chartName;
    final initial = toplistTracksMap[_chartTitle];
    if (initial != null && initial.isNotEmpty) {
      _tracks = List.from(initial);
    }
    setState(() => _isLoading = _tracks.isEmpty);

    try {
      final fetched = await OnlineMusicService.fetchToplistTracks(_chartTitle, limit: 100);
      if (mounted) {
        setState(() {
          if (fetched.isNotEmpty) {
            _tracks = fetched;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(_chartTitle, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: MellowRadii.borderR16,
                  ),
                  child: const Center(
                    child: Icon(Icons.leaderboard_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.12),
                              borderRadius: MellowRadii.borderPill,
                            ),
                            child: Text('官方巅峰榜单', style: TextStyle(color: theme.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Text('每日更新', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_chartTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textPrimary)),
                      Text('全量收录 ${_tracks.length} 首精选歌曲', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SoftButton(
                label: '播放全部 (${_tracks.length}首)',
                icon: Icons.play_arrow_rounded,
                isActive: true,
                isPill: true,
                onTap: () {
                  if (_tracks.isNotEmpty) {
                    player.playPlaylist(_tracks, startIndex: 0);
                  }
                },
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_tracks.length, (idx) {
            final t = _tracks[idx];
            final rank = idx + 1;
            final isPlaying = player.currentTrack?.id == t.id;
            final Color rankColor = rank == 1
                ? const Color(0xFFFFB800)
                : rank == 2
                    ? const Color(0xFF94A3B8)
                    : rank == 3
                        ? const Color(0xFFCD7F32)
                        : theme.textMuted;

            return SoftCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => player.playPlaylist(_tracks, startIndex: idx),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: rank <= 3 ? FontWeight.w900 : FontWeight.bold,
                        color: rankColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MellowImage(url: t.coverUrl, width: 44, height: 44, borderRadius: MellowRadii.borderR8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isPlaying ? theme.accentColor : theme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.artist} · ${t.album}',
                          style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: Colors.pink,
                      size: 20,
                    ),
                    onPressed: () => player.toggleFavorite(t.id, t),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 5. 声音电台二级页 (MobileRadioPage)
class MobileRadioPage extends StatelessWidget {
  final VoidCallback onBack;
  const MobileRadioPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final radios = presetRadioStations;

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text('声音电台', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: radios.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final r = radios[idx];
          return SoftCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              player.playTrack(r.track);
            },
            child: Row(
              children: [
                MellowImage(url: r.coverUrl, width: 48, height: 48, borderRadius: MellowRadii.borderR12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(r.sub, style: TextStyle(fontSize: 12, color: theme.textMuted)),
                      const SizedBox(height: 4),
                      Text(r.listeners, style: TextStyle(fontSize: 11, color: theme.accentColor)),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: theme.accentColor, size: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 6. 热门歌手列表二级页 (MobileArtistsPage)
class MobileArtistsPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String artistName) onSelectArtist;
  const MobileArtistsPage({super.key, required this.onBack, required this.onSelectArtist});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final artists = mockArtistsProfiles;

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text('热门入驻歌手', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final a = artists[idx];
          return SoftCard(
            padding: const EdgeInsets.all(12),
            onTap: () => onSelectArtist(a.name),
            child: Row(
              children: [
                MellowAvatar(radius: 26, url: a.avatarUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(a.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 14, color: theme.accentColor),
                        ],
                      ),
                      Text('粉丝 ${a.fans}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.textMuted),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 7. 歌手详情二级页 (MobileArtistDetailPage)
class MobileArtistDetailPage extends StatefulWidget {
  final String artistName;
  final VoidCallback onBack;
  const MobileArtistDetailPage({super.key, required this.artistName, required this.onBack});

  @override
  State<MobileArtistDetailPage> createState() => _MobileArtistDetailPageState();
}

class _MobileArtistDetailPageState extends State<MobileArtistDetailPage> {
  bool _isFollowing = true;
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  void _loadTracks() async {
    final artist = getArtistProfileByName(widget.artistName);
    final songs = await OnlineMusicService.fetchArtistTopSongs(artist.id, artistName: artist.name);
    if (mounted) {
      setState(() {
        _tracks = songs.isNotEmpty ? songs : artist.tracks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final artist = getArtistProfileByName(widget.artistName);

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(widget.artistName, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                MellowAvatar(
                  radius: 36,
                  url: artist.avatarUrl,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(artist.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 14, color: theme.accentColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tracks.isNotEmpty ? '热门代表作 ${_tracks.length} 首 · 官方实时榜' : artist.bio,
                        style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SoftButton(
                            label: _isFollowing ? '已关注' : '+ 关注',
                            isActive: _isFollowing,
                            isPill: true,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            onTap: () => setState(() => _isFollowing = !_isFollowing),
                          ),
                          const SizedBox(width: 10),
                          SoftButton(
                            label: '播放热门',
                            icon: Icons.play_arrow_rounded,
                            isPill: true,
                            isActive: true,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            onTap: () {
                              if (_tracks.isNotEmpty) {
                                player.playPlaylist(_tracks, startIndex: 0);
                              }
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('代表作清单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              if (!_isLoading)
                Text('共 ${_tracks.length} 首', style: TextStyle(fontSize: 12, color: theme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ...List.generate(_tracks.length, (idx) {
              final t = _tracks[idx];
              return SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => player.playPlaylist(_tracks, startIndex: idx),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: idx < 3 ? FontWeight.bold : FontWeight.normal,
                          color: idx < 3 ? theme.accentColor : theme.textMuted,
                        ),
                      ),
                    ),
                    MellowImage(url: t.coverUrl, width: 40, height: 40, borderRadius: MellowRadii.borderR8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 11, color: theme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.pink, size: 20),
                      onPressed: () => player.toggleFavorite(t.id),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// 8. 本地与下载二级页 (MobileLocalMusicPage)
class MobileLocalMusicPage extends StatelessWidget {
  final VoidCallback onBack;
  const MobileLocalMusicPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final localTracks = player.localTracks;

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text('本地与离线曲库', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
        actions: [
          if (localTracks.isNotEmpty)
            TextButton.icon(
              icon: Icon(Icons.play_circle_fill_rounded, size: 18, color: theme.accentColor),
              label: Text('播放全部', style: TextStyle(color: theme.accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: () => player.playLocalMusic(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          RecessedWell(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.audio_file_rounded, size: 24, color: theme.accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('设备离线音频库', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text('已收录 ${localTracks.length} 首曲目 · 物理声卡直出回放', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (localTracks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.music_off_rounded, size: 48, color: theme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('暂无本地音乐', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('可在桌面端扫描或将音频放入设备音乐目录', style: TextStyle(color: theme.textMuted, fontSize: 12)),
                ],
              ),
            )
          else
            ...localTracks.map((t) => SoftCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => player.playTrack(t),
              child: Row(
                children: [
                  const Icon(Icons.audio_file_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                      ],
                    ),
                  ),
                  Icon(
                    player.currentTrack?.id == t.id && player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_arrow_rounded,
                    color: theme.accentColor,
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

/// 9. 移动端独立全屏搜索页面 (MobileSearchPage)
class MobileSearchPage extends StatefulWidget {
  final VoidCallback onBack;
  const MobileSearchPage({super.key, required this.onBack});

  @override
  State<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends State<MobileSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _currentQuery = '';
  bool _isLoading = false;
  List<Track> _searchResults = [];
  List<String> _history = [];
  int _searchToken = 0;

  // 移动端实时搜索联想状态
  List<Track> _suggestedTracks = [];
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  final List<String> _hotSearches = [
    '周杰伦', '告五人', '布拉格广场', '陈奕迅', '林俊杰', '晴天', '海阔天空', '邓紫棋', '粤语经典'
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadHistory() {
    setState(() {
      _history = StorageService.instance.getSearchHistory();
    });
  }

  Future<void> _executeSearch(String query) async {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) return;

    final token = ++_searchToken;

    setState(() {
      _showSuggestions = false;
      _isLoading = true;
      _currentQuery = clean;
    });

    await StorageService.instance.addSearchHistory(clean);
    if (!mounted || token != _searchToken) return;
    _loadHistory();

    final results = await OnlineMusicService.searchOnlineTracks(clean, limit: 30);
    if (mounted && token == _searchToken) {
      setState(() {
        _isLoading = false;
        _searchResults = results;
      });
    }
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchToken++;
    _searchController.clear();
    setState(() {
      _currentQuery = '';
      _searchResults.clear();
      _suggestedTracks.clear();
      _showSuggestions = false;
      _isLoadingSuggestions = false;
      _isLoading = false;
    });
  }

  void _onQueryChanged(String text) {
    _debounceTimer?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestedTracks = [];
        _isLoadingSuggestions = false;
        _showSuggestions = false;
      });
      return;
    }

    final lower = query.toLowerCase();
    final localMatches = getAllKnownTracks().where((t) {
      return t.title.toLowerCase().contains(lower) ||
          t.artist.toLowerCase().contains(lower) ||
          t.album.toLowerCase().contains(lower);
    }).take(6).toList();

    setState(() {
      _showSuggestions = true;
      _isLoadingSuggestions = true;
      if (localMatches.isNotEmpty) {
        _suggestedTracks = localMatches;
      }
    });

    final token = ++_searchToken;
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final onlineResults = await OnlineMusicService.searchOnlineTracks(query, limit: 6);
        if (!mounted || token != _searchToken) return;

        final merged = <Track>[];
        final seen = <String>{};
        for (final t in [...onlineResults, ...localMatches]) {
          final key = '${t.title.trim().toLowerCase()}_${t.artist.trim().toLowerCase()}';
          if (seen.add(key)) {
            merged.add(t);
            if (merged.length >= 6) break;
          }
        }

        setState(() {
          _suggestedTracks = merged;
          _isLoadingSuggestions = false;
        });
      } catch (_) {
        if (mounted && token == _searchToken) {
          setState(() {
            _isLoadingSuggestions = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: widget.onBack,
        ),
        title: RecessedWell(
          height: 40,
          borderRadius: MellowRadii.borderPill,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: theme.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: TextStyle(fontSize: 14, color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: '搜索歌曲、歌手 (如布拉格广场)...',
                    hintStyle: TextStyle(fontSize: 12.5, color: theme.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: _onQueryChanged,
                  onSubmitted: _executeSearch,
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(Icons.close_rounded, size: 16, color: theme.textMuted),
                ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => _executeSearch(_searchController.text),
              child: Text('搜索', style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor)),
                  const SizedBox(height: 16),
                  Text('正在检索全网高保真音频...', style: TextStyle(fontSize: 13, color: theme.textMuted)),
                ],
              ),
            )
          : _showSuggestions && (_suggestedTracks.isNotEmpty || _isLoadingSuggestions)
              ? _buildMobileSuggestions(theme, player)
              : _currentQuery.isNotEmpty && _searchResults.isNotEmpty
                  ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('共找到 ${_searchResults.length} 首单曲', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        GestureDetector(
                          onTap: () => player.playPlaylist(_searchResults, startIndex: 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.12),
                              borderRadius: MellowRadii.borderPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, size: 16, color: theme.accentColor),
                                const SizedBox(width: 4),
                                Text('播放全部', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.accentColor)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._searchResults.map((t) {
                      final isCurrent = player.currentTrack?.id == t.id && player.isPlaying;
                      return SoftCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        onTap: () => player.playTrack(t),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: MellowImage(url: t.coverUrl, width: 44, height: 44),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isCurrent ? theme.accentColor : theme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${t.artist} · ${t.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: theme.textMuted)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => player.toggleFavorite(t.id, t),
                              child: Icon(
                                player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: player.isFavorite(t.id) ? const Color(0xFFEF4444) : theme.textMuted,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (_history.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('历史搜索', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          GestureDetector(
                            onTap: () async {
                              await StorageService.instance.clearSearchHistory();
                              _loadHistory();
                            },
                            child: Text('清空', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _history.map((h) => SoftCard(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          borderRadius: MellowRadii.borderPill,
                          onTap: () {
                            _searchController.text = h;
                            _executeSearch(h);
                          },
                          child: Text(h, style: TextStyle(fontSize: 12, color: theme.textPrimary)),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text('全网热门搜索', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _hotSearches.map((h) => SoftCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        borderRadius: MellowRadii.borderPill,
                        onTap: () {
                          _searchController.text = h;
                          _executeSearch(h);
                        },
                        child: Text(h, style: TextStyle(fontSize: 12, color: theme.textPrimary)),
                      )).toList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMobileSuggestions(ThemeProvider theme, AudioPlayerService player) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: theme.accentColor),
            const SizedBox(width: 8),
            Text(
              '为你联想相关歌曲 (即点即播)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.accentColor,
              ),
            ),
            if (_isLoadingSuggestions) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _showSuggestions = false),
              child: Icon(Icons.close_rounded, size: 16, color: theme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._suggestedTracks.map((track) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              padding: const EdgeInsets.all(10),
              borderRadius: MellowRadii.borderR16,
              onTap: () {
                player.playPlaylist([track, ..._suggestedTracks]);
              },
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MellowImage(
                      url: track.coverUrl,
                      width: 42,
                      height: 42,
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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.accentColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.play_arrow_rounded, size: 20, color: theme.accentColor),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

