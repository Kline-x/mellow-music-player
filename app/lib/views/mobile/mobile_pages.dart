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

    return ListenableBuilder(
      listenable: DailyRecommendService.instance,
      builder: (context, _) {
        final service = DailyRecommendService.instance;
        final tracks = service.getDailyRecommendTracks();
        final greeting = service.getGreeting();
        final dayStr = service.getFormattedDay();
        final weekdayStr = service.getFormattedWeekday();
        final monthYearStr = service.getFormattedMonthYear();
        final isLoading = service.isLoading;

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
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: theme.textPrimary, size: 20),
                tooltip: '刷新今日推荐',
                onPressed: () => service.getDailyRecommendTracksAsync(),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$monthYearStr · $weekdayStr',
                            style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
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
          if (tracks.isEmpty)
            SoftCard(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  if (isLoading)
                    CircularProgressIndicator(color: theme.accentColor, strokeWidth: 2.5)
                  else ...[
                    Icon(Icons.queue_music_rounded, size: 48, color: theme.textMuted),
                    const SizedBox(height: 12),
                    Text('今日推荐正在精心调配中...', style: TextStyle(color: theme.textSecondary, fontSize: 13.5)),
                    const SizedBox(height: 12),
                    SoftButton(
                      label: '立即抓取今日推荐',
                      icon: Icons.refresh_rounded,
                      isActive: true,
                      isPill: true,
                      onTap: () => service.getDailyRecommendTracksAsync(),
                    ),
                  ],
                ],
              ),
            ),
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
      },
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
    final track = player.currentTrack;
    if (track == null) {
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radio_rounded, size: 54, color: theme.textMuted),
              const SizedBox(height: 16),
              Text('漫游雷达待命中', style: TextStyle(color: theme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('轻触开启你的专属音乐旅程', style: TextStyle(color: theme.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              SoftButton(
                label: '开启漫游',
                icon: Icons.play_arrow_rounded,
                isPill: true,
                onTap: () async {
                  final list = await DailyRecommendService.instance.getDailyRecommendTracksAsync();
                  if (list.isNotEmpty) player.playPlaylist(list, startIndex: 0);
                },
              ),
            ],
          ),
        ),
      );
    }

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
class MobilePlaylistSquarePage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onOpenScenarios;

  const MobilePlaylistSquarePage({
    super.key,
    required this.onBack,
    this.onOpenScenarios,
  });

  @override
  State<MobilePlaylistSquarePage> createState() => _MobilePlaylistSquarePageState();
}

class _MobilePlaylistSquarePageState extends State<MobilePlaylistSquarePage> {
  String _activeTag = '精选推荐';
  final List<String> _tags = [
    '精选推荐',
    '华语流行',
    '沉静治愈',
    '古风雅乐',
    '经典粤语',
    '深夜爵士',
    '轻音乐',
    '摇滚',
    'ACG 动漫',
    '民谣',
  ];
  final ScrollController _scrollController = ScrollController();
  List<SquarePlaylist> _playlists = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 30;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPlaylists(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadPlaylists(reset: false);
    }
  }

  Future<void> _loadPlaylists({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
        _offset = 0;
        _playlists = [];
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    final currentToken = ++_requestToken;
    final currentOffset = reset ? 0 : _offset;

    try {
      final list = await OnlineMusicService.fetchTopPlaylists(
        cat: _activeTag,
        offset: currentOffset,
        limit: _limit,
      );

      if (!mounted || currentToken != _requestToken) return;

      setState(() {
        if (reset) {
          _playlists = list;
          _isLoading = false;
        } else {
          final existingIds = _playlists.map((p) => p.id).toSet();
          final uniqueNew = list.where((p) => !existingIds.contains(p.id)).toList();
          _playlists.addAll(uniqueNew);
          _isLoadingMore = false;
        }
        _offset = _playlists.length;
        _hasMore = list.length >= _limit;
      });
    } catch (_) {
      if (mounted && currentToken == _requestToken) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _switchTag(String tag) {
    if (_activeTag == tag) return;
    setState(() => _activeTag = tag);
    _loadPlaylists(reset: true);
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
        title: Text('歌单广场', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
        actions: [
          if (widget.onOpenScenarios != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: widget.onOpenScenarios,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_motion_rounded, size: 13, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      const Text(
                        '场景歌单',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _playlists.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16, 4, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                // 场景歌单推荐横幅
                if (widget.onOpenScenarios != null) ...[
                  GestureDetector(
                    onTap: widget.onOpenScenarios,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '场景歌单推荐 · 自由探索',
                                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '搜结婚、国庆、新年、助眠、自驾，定制专属氛围',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 热门分类切换横滑胶囊
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tags.map((tag) {
                      final isSel = _activeTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SoftButton(
                          label: tag,
                          isActive: isSel,
                          isPill: true,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          onTap: () => _switchTag(tag),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // 真实精选歌单双列网格
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.84,
                  ),
                  itemCount: _playlists.length,
                  itemBuilder: (context, idx) {
                    final pl = _playlists[idx];
                    final countDisplay = pl.trackCount > 0 ? '${pl.trackCount}首' : (pl.tracks.isNotEmpty ? '${pl.tracks.length}首' : '');

                    return SoftCard(
                      padding: const EdgeInsets.all(10),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MobileToplistDetailPage(
                              chartName: 'playlist:::${pl.id}:::${pl.title}:::${pl.coverUrl}:::${pl.desc}',
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: MellowImage(
                                    url: pl.coverUrl,
                                    width: double.infinity,
                                    height: double.infinity,
                                    borderRadius: MellowRadii.borderR12,
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 11),
                                        const SizedBox(width: 2),
                                        Text(
                                          pl.playCount,
                                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('正在播放歌单「${pl.title}」...'),
                                          duration: const Duration(milliseconds: 1200),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      if (pl.tracks.isNotEmpty) {
                                        player.playPlaylist(pl.tracks, startIndex: 0);
                                        return;
                                      }
                                      final detail = await OnlineMusicService.importNeteasePlaylist(pl.id);
                                      if (detail != null && detail.tracks.isNotEmpty) {
                                        player.playPlaylist(detail.tracks, startIndex: 0);
                                      } else {
                                        final fallback = getAllKnownTracks();
                                        if (fallback.isNotEmpty) player.playPlaylist(fallback, startIndex: 0);
                                      }
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: theme.accentColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pl.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary),
                          ),
                          Text(
                            pl.desc.isNotEmpty ? pl.desc : (countDisplay.isNotEmpty ? '共$countDisplay精选曲目' : '全网精选热门歌单'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: theme.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                if (_isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor),
                          ),
                          const SizedBox(width: 8),
                          Text('正在加载更多热门歌单...', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 4. 巅峰排行榜二级页 (MobileToplistPage)
class MobileToplistPage extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String chartName)? onSelectToplist;

  const MobileToplistPage({super.key, required this.onBack, this.onSelectToplist});

  @override
  State<MobileToplistPage> createState() => _MobileToplistPageState();
}

class _MobileToplistPageState extends State<MobileToplistPage> {
  final charts = ['飙升榜', '热歌榜', '新歌榜', '原创榜'];
  final Map<String, List<Track>> _liveToplists = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToplists();
  }

  void _loadToplists() async {
    for (final chart in charts) {
      try {
        final tracks = await OnlineMusicService.fetchToplistTracks(chart, limit: 10);
        if (mounted && tracks.isNotEmpty) {
          setState(() {
            _liveToplists[chart] = tracks;
          });
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoading = false);
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
        title: Text('官方巅峰排行榜', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
        itemCount: charts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final chartName = charts[idx];
          final chartTracks = _liveToplists[chartName] ?? const <Track>[];
          return SoftCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              if (widget.onSelectToplist != null) {
                widget.onSelectToplist!(chartName);
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
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (chartTracks.isNotEmpty) {
                          player.playPlaylist(chartTracks, startIndex: 0);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('正在拉取「$chartName」曲目，请稍候...'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Icon(Icons.play_circle_fill_rounded, color: theme.accentColor, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (chartTracks.isEmpty)
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 13,
                            width: 180,
                            decoration: BoxDecoration(
                              color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 13,
                            width: 220,
                            decoration: BoxDecoration(
                              color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 13,
                            width: 140,
                            decoration: BoxDecoration(
                              color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('暂无榜单数据', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    )
                else ...List.generate(chartTracks.length.clamp(0, 3), (i) {
                  final t = chartTracks[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2, right: 12),
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
                    Text(
                      chartTracks.isNotEmpty ? '查看完整榜单 (${chartTracks.length}首) >' : '查看完整榜单 >',
                      style: TextStyle(fontSize: 11.5, color: theme.accentColor, fontWeight: FontWeight.w600),
                    ),
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
  String _chartId = '';
  String _coverUrl = '';
  String _playlistDesc = '';
  bool _isPlaylist = false;
  List<Track> _tracks = [];
  List<String> _allTrackIds = [];
  int _totalCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _parseParamsAndLoad();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore) return;
    if (_allTrackIds.isEmpty || _tracks.length >= _allTrackIds.length) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      _loadMoreTracks();
    }
  }

  void _checkAndAutoFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_allTrackIds.isEmpty || _tracks.length >= _allTrackIds.length) return;
      if (_isLoading || _isLoadingMore) return;
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 100) {
        _loadMoreTracks();
      }
    });
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoadingMore) return;
    final start = _tracks.length;
    final end = (start + 50 < _allTrackIds.length) ? start + 50 : _allTrackIds.length;
    if (start >= end) return;
    setState(() => _isLoadingMore = true);
    try {
      final batchIds = _allTrackIds.sublist(start, end);
      final newTracks = await OnlineMusicService.fetchTracksByIds(batchIds, defaultCover: _coverUrl);
      if (mounted) {
        final existingIds = _tracks.map((t) => t.id).toSet();
        final uniqueNew = newTracks.where((t) => !existingIds.contains(t.id)).toList();
        setState(() {
          _tracks.addAll(uniqueNew);
          _isLoadingMore = false;
        });
        _checkAndAutoFillViewport();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadAllRemainingTracks() async {
    if (_isLoadingMore || _tracks.length >= _allTrackIds.length) return;
    setState(() => _isLoadingMore = true);
    try {
      while (_tracks.length < _allTrackIds.length && mounted) {
        final start = _tracks.length;
        final end = (start + 50 < _allTrackIds.length) ? start + 50 : _allTrackIds.length;
        if (start >= end) break;
        final batchIds = _allTrackIds.sublist(start, end);
        final newTracks = await OnlineMusicService.fetchTracksByIds(batchIds, defaultCover: _coverUrl);
        if (!mounted) break;
        final existingIds = _tracks.map((t) => t.id).toSet();
        final uniqueNew = newTracks.where((t) => !existingIds.contains(t.id)).toList();
        setState(() {
          _tracks.addAll(uniqueNew);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _loadAllRemainingTracksToPlayer(AudioPlayerService player) {
    Future.microtask(() async {
      try {
        var currentOffset = _tracks.length;
        while (currentOffset < _allTrackIds.length) {
          final end = (currentOffset + 50 < _allTrackIds.length) ? currentOffset + 50 : _allTrackIds.length;
          final batchIds = _allTrackIds.sublist(currentOffset, end);
          final newTracks = await OnlineMusicService.fetchTracksByIds(batchIds, defaultCover: _coverUrl);
          if (newTracks.isNotEmpty) {
            player.appendPlaylist(newTracks);
            currentOffset += newTracks.length;
            if (mounted) {
              final existingIds = _tracks.map((t) => t.id).toSet();
              final uniqueNew = newTracks.where((t) => !existingIds.contains(t.id)).toList();
              if (uniqueNew.isNotEmpty) {
                setState(() => _tracks.addAll(uniqueNew));
              }
            }
          } else {
            break;
          }
        }
      } catch (_) {}
    });
  }

  void _parseParamsAndLoad() {
    final raw = widget.chartName;
    if (raw.startsWith('playlist:::')) {
      final parts = raw.split(':::');
      _isPlaylist = true;
      _chartId = parts.length > 1 ? parts[1] : '';
      _chartTitle = parts.length > 2 ? parts[2] : '精选歌单';
      _coverUrl = parts.length > 3 ? parts[3] : '';
      _playlistDesc = parts.length > 4 ? parts[4] : '';
      _loadPlaylistTracks();
      return;
    }

    _isPlaylist = false;
    _chartTitle = raw;
    final initial = toplistTracksMap[_chartTitle];
    if (initial != null && initial.isNotEmpty) {
      _tracks = List.from(initial);
      _totalCount = _tracks.length;
    }
    _loadTracks();
  }

  Future<void> _loadPlaylistTracks() async {
    setState(() => _isLoading = true);
    final cleanId = _chartId.replaceAll('netease_', '');
    try {
      final imported = await OnlineMusicService.importNeteasePlaylist(cleanId);
      if (imported != null && mounted) {
        final seen = <String>{};
        final uniqueTracks = <Track>[];
        for (final t in imported.tracks) {
          if (seen.add(t.id)) uniqueTracks.add(t);
        }
        setState(() {
          if (imported.title.isNotEmpty) _chartTitle = imported.title;
          if (imported.coverUrl.isNotEmpty) _coverUrl = imported.coverUrl;
          if (imported.description.isNotEmpty) _playlistDesc = imported.description;
          _tracks = uniqueTracks;
          _allTrackIds = List.from(imported.allTrackIds);
          _totalCount = imported.trackCount > 0
              ? imported.trackCount
              : (_allTrackIds.isNotEmpty ? _allTrackIds.length : _tracks.length);
          _isLoading = false;
        });
        _checkAndAutoFillViewport();
      } else if (mounted) {
        final fallback = getAllKnownTracks().take(15).toList();
        setState(() {
          if (_tracks.isEmpty) {
            _tracks = fallback;
            _totalCount = fallback.length;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final fallback = getAllKnownTracks().take(15).toList();
        setState(() {
          if (_tracks.isEmpty) {
            _tracks = fallback;
            _totalCount = fallback.length;
          }
          _isLoading = false;
        });
      }
    }
  }

  void _loadTracks() async {
    setState(() => _isLoading = _tracks.isEmpty);
    try {
      final fetched = await OnlineMusicService.fetchToplistTracks(_chartTitle, limit: 100);
      if (mounted) {
        setState(() {
          if (fetched.isNotEmpty) {
            _tracks = fetched;
            _totalCount = fetched.length;
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
    final totalDisplay = _totalCount > 0 ? _totalCount : _tracks.length;

    final displayTracks = _searchFilter.trim().isEmpty
        ? _tracks
        : _tracks.where((t) {
            final q = _searchFilter.trim().toLowerCase();
            return t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q) || t.album.toLowerCase().contains(q);
          }).toList();

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
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: MellowRadii.borderR16,
                  ),
                  child: ClipRRect(
                    borderRadius: MellowRadii.borderR16,
                    child: _coverUrl.isNotEmpty
                        ? MellowImage(url: _coverUrl, width: 76, height: 76, fit: BoxFit.cover)
                        : const Center(
                            child: Icon(Icons.queue_music_rounded, color: Colors.white, size: 36),
                          ),
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
                            child: Text(
                              _isPlaylist ? '精选歌单' : '官方巅峰榜单',
                              style: TextStyle(color: theme.accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(_isPlaylist ? '高保真音质' : '每日更新', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _chartTitle,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _playlistDesc.isNotEmpty ? _playlistDesc : '全量收录 $totalDisplay 首精选歌曲',
                        style: TextStyle(fontSize: 12, color: theme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 搜索与播放栏
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchFilter = val),
                    style: TextStyle(fontSize: 12, color: theme.textPrimary),
                    decoration: InputDecoration(
                      hintText: '在列表中筛选歌曲/歌手...',
                      hintStyle: TextStyle(fontSize: 12, color: theme.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: theme.textMuted),
                      suffixIcon: _searchFilter.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, size: 14, color: theme.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(borderRadius: MellowRadii.borderPill, borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SoftButton(
                label: '播放全部',
                icon: Icons.play_arrow_rounded,
                isActive: true,
                isPill: true,
                onTap: () {
                  if (_tracks.isNotEmpty) {
                    player.playPlaylist(_tracks, startIndex: 0);
                    if (_allTrackIds.isNotEmpty && _tracks.length < _allTrackIds.length) {
                      _loadAllRemainingTracksToPlayer(player);
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (displayTracks.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('未找到相关歌曲', style: TextStyle(color: theme.textMuted, fontSize: 13)),
              ),
            ),

          ...List.generate(displayTracks.length, (idx) {
            final t = displayTracks[idx];
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
              onTap: () => player.playPlaylist(displayTracks, startIndex: idx),
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

          if (_isLoadingMore) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor)),
                    const SizedBox(width: 8),
                    Text('正在加载更多曲目 (${_tracks.length}/$totalDisplay)...', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                  ],
                ),
              ),
            ),
          ] else if (!_isLoadingMore && _tracks.isNotEmpty && _tracks.length < totalDisplay) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('已呈现 ${_tracks.length} 首 · 剩余 ${totalDisplay - _tracks.length} 首', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                    const SizedBox(width: 10),
                    SoftButton(
                      label: '加载全部',
                      icon: Icons.download_rounded,
                      isPill: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      onTap: _loadAllRemainingTracks,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_tracks.isNotEmpty && _tracks.length >= totalDisplay) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('已呈现全部 $totalDisplay 首曲目', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
              ),
            ),
          ],
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () {
                final allTracks = radios.map((e) => e.track).toList();
                if (allTracks.isNotEmpty) {
                  player.playPlaylist(allTracks, startIndex: 0);
                }
              },
              icon: Icon(Icons.play_arrow_rounded, color: theme.accentColor, size: 18),
              label: Text('播放全部', style: TextStyle(color: theme.accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
        itemCount: radios.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final r = radios[idx];
          final allTracks = radios.map((e) => e.track).toList();
          return SoftCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              player.playPlaylist(allTracks, startIndex: idx);
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    player.playPlaylist(allTracks, startIndex: idx);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: theme.accentColor, size: 22),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 6. 热门歌手列表二级页 (MobileArtistsPage)
class MobileArtistsPage extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String artistName) onSelectArtist;
  const MobileArtistsPage({super.key, required this.onBack, required this.onSelectArtist});

  @override
  State<MobileArtistsPage> createState() => _MobileArtistsPageState();
}

class _MobileArtistsPageState extends State<MobileArtistsPage> {
  List<ArtistProfile> _artists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  void _loadArtists() async {
    try {
      final rawList = await OnlineMusicService.fetchArtistList(limit: 50);
      if (mounted) {
        setState(() {
          _artists = rawList.map((item) {
            final id = item['id']?.toString() ?? '';
            final name = item['name']?.toString() ?? '歌手';
            var picUrl = item['img1v1Url']?.toString() ?? item['picUrl']?.toString() ?? '';
            final musicSize = (item['musicSize'] as num?)?.toInt() ?? 0;
            return ArtistProfile(
              id: id,
              name: name,
              role: '华语音乐人 · $musicSize首单曲',
              fans: '华语热度榜',
              bio: '热门入驻音乐人',
              avatarUrl: picUrl.isNotEmpty ? picUrl : NeteaseMusicService.fallbackCoverFor(name, '歌手'),
              musicSize: musicSize,
              albumSize: 0,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text('热门歌手', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
      ),
      body: _isLoading && _artists.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
              itemCount: _artists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final a = _artists[idx];
                return SoftCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => widget.onSelectArtist(a.name),
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
        padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
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
                              } else if (artist.tracks.isNotEmpty) {
                                player.playPlaylist(artist.tracks, startIndex: 0);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('正在拉取歌手代表作，请稍候...'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
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
class MobileLocalMusicPage extends StatefulWidget {
  final VoidCallback onBack;
  const MobileLocalMusicPage({super.key, required this.onBack});

  @override
  State<MobileLocalMusicPage> createState() => _MobileLocalMusicPageState();
}

class _MobileLocalMusicPageState extends State<MobileLocalMusicPage> {
  bool _isScanning = false;

  Future<void> _handleScan(BuildContext context, AudioPlayerService player) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    try {
      final added = await player.scanDeviceMusicDirectories();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added > 0 ? '扫描完毕，新增 $added 首本地音乐' : '扫描完成，暂未在通用媒体目录中发现新增音频',
            style: const TextStyle(fontSize: 13),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('扫描本地音频出错: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

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
          onPressed: widget.onBack,
        ),
        title: Text('本地与离线曲库', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isScanning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(theme.accentColor)),
                  )
                : Icon(Icons.refresh_rounded, color: theme.accentColor, size: 22),
            tooltip: '扫描设备音频',
            onPressed: _isScanning ? null : () => _handleScan(context, player),
          ),
          if (localTracks.isNotEmpty)
            TextButton.icon(
              icon: Icon(Icons.play_circle_fill_rounded, size: 18, color: theme.accentColor),
              label: Text('播放全部', style: TextStyle(color: theme.accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: () => player.playLocalMusic(),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
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
                  const SizedBox(height: 6),
                  Text('可将音频放入设备的 Music 目录，或点击下方按钮检索', style: TextStyle(color: theme.textMuted, fontSize: 12)),
                  const SizedBox(height: 20),
                  SoftButton(
                    label: _isScanning ? '正在扫描设备音频...' : '智能扫描设备本地曲库',
                    icon: Icons.radar_rounded,
                    isActive: true,
                    isPill: true,
                    onTap: _isScanning ? null : () => _handleScan(context, player),
                  ),
                ],
              ),
            ),
          if (localTracks.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('本地曲目 (${localTracks.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                SoftButton(
                  icon: Icons.play_arrow_rounded,
                  label: '播放全部',
                  isPill: true,
                  isActive: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  onTap: () => player.playPlaylist(localTracks, startIndex: 0),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(localTracks.length, (idx) {
              final t = localTracks[idx];
              return SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => player.playPlaylist(localTracks, startIndex: idx),
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
              );
            }),
          ],
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
    '周杰伦', '结婚', '国庆', '新年', '告五人', '布拉格广场', '陈奕迅', '林俊杰', '晴天', '海阔天空', '邓紫棋', '粤语经典'
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
    _focusNode.unfocus();
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
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
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
                    ...List.generate(_searchResults.length, (idx) {
                      final t = _searchResults[idx];
                      final isCurrent = player.currentTrack?.id == t.id && player.isPlaying;
                      return SoftCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        onTap: () => player.playPlaylist(_searchResults, startIndex: idx),
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
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
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
                _searchController.text = track.title;
                _searchController.selection = TextSelection.fromPosition(TextPosition(offset: track.title.length));
                _executeSearch(track.title);
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      player.playPlaylist([track, ..._suggestedTracks]);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.accentColor.withValues(alpha: 0.12),
                      ),
                      child: Icon(Icons.play_arrow_rounded, size: 20, color: theme.accentColor),
                    ),
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

/// 移动端专属：我喜欢的音乐二级页 (MobileFavoritesPage)
class MobileFavoritesPage extends StatelessWidget {
  final VoidCallback onBack;

  const MobileFavoritesPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final favorites = player.favoriteTracks;

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text(
          '我喜欢的音乐',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.favorite_rounded, size: 36, color: Color(0xFFEC4899)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无心动单曲',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '在发现、探索或搜索时点击红心即可珍藏',
                    style: TextStyle(fontSize: 13, color: theme.textMuted),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                // 顶部心动大卡片 Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEC4899).withValues(alpha: 0.85),
                        const Color(0xFFF43F5E).withValues(alpha: 0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: MellowRadii.borderR24,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '我喜欢的音乐',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '共 ${favorites.length} 首珍藏曲目 · 随时畅听',
                              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 播放全部操作栏
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (favorites.isNotEmpty) {
                            player.playPlaylist(favorites, startIndex: 0);
                          }
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.accentColor,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: theme.accentColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 6),
                              Text(
                                '播放全部',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 单曲列表
                ...List.generate(favorites.length, (index) {
                  final track = favorites[index];
                  final isCurrent = player.currentTrack?.id == track.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: MellowRadii.borderR16,
                      onTap: () {
                        player.playPlaylist(favorites, startIndex: index);
                      },
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: MellowImage(
                              url: track.coverUrl,
                              width: 46,
                              height: 46,
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
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? theme.accentColor : theme.textPrimary,
                                  ),
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
                          // 红心切换按钮
                          IconButton(
                            icon: const Icon(Icons.favorite_rounded, color: Color(0xFFEC4899), size: 22),
                            onPressed: () {
                              player.toggleFavorite(track.id, track);
                            },
                          ),
                          // 播放状态小图标
                          if (isCurrent)
                            Icon(
                              player.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                              color: theme.accentColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

/// 12. 播放历史二级页面 (MobileHistoryPage)
class MobileHistoryPage extends StatelessWidget {
  final VoidCallback onBack;
  const MobileHistoryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final history = player.playHistory;

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: onBack,
        ),
        title: Text('播放历史', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
        centerTitle: true,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: theme.textMuted, size: 20),
              tooltip: '清空播放历史',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空播放历史'),
                    content: const Text('确定要清空全部播放历史记录吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      TextButton(
                        onPressed: () {
                          player.clearHistory();
                          Navigator.pop(ctx);
                        },
                        child: const Text('确定清空', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: theme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('暂无播放历史记录', style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('快去发现你心动的音乐吧', style: TextStyle(color: theme.textMuted, fontSize: 12)),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 180 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('共 ${history.length} 首足迹歌曲', style: TextStyle(fontSize: 12.5, color: theme.textMuted)),
                    SoftButton(
                      label: '播放全部',
                      icon: Icons.play_arrow_rounded,
                      isActive: true,
                      isPill: true,
                      onTap: () => player.playPlaylist(history, startIndex: 0),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(history.length, (idx) {
                  final t = history[idx];
                  final isCurrent = player.currentTrack?.id == t.id;
                  final isFav = player.isFavorite(t.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: MellowRadii.borderR16,
                      border: isCurrent
                          ? Border.all(color: theme.accentColor.withValues(alpha: 0.6), width: 1.2)
                          : null,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: theme.accentColor.withValues(alpha: 0.15),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: SoftCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      onTap: () => player.playPlaylist(history, startIndex: idx),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              MellowImage(url: t.coverUrl, width: 44, height: 44, borderRadius: MellowRadii.borderR8),
                              if (isCurrent)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: MellowRadii.borderR8,
                                  ),
                                  child: Icon(
                                    player.isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                                    color: theme.accentColor,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: isCurrent ? theme.accentColor : theme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.accentColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          player.isPlaying ? '播放中' : '已暂停',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: theme.accentColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: Colors.pink,
                              size: 20,
                            ),
                            onPressed: () => player.toggleFavorite(t.id, t),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

