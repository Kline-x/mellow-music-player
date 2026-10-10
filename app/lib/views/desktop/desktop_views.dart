import 'dart:async';
import 'dart:io' show Platform, Directory;
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
import '../../core/audio/windows_tray_service.dart';
import '../../core/audio/equalizer_manager.dart';
import '../../core/sources/daily_recommend_service.dart';
import '../../core/sources/online_music_service.dart';
import '../../core/sources/lx_source_model.dart';
import '../../core/sources/lx_script_sandbox.dart';
import '../../core/sync/webdav_sync_service.dart';
import '../../core/sync/sync_data_model.dart';
import '../../core/sync/lan_sync_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/window/desktop_floating_lyric_service.dart';
import '../common/modals.dart';
import '../../core/services/version_check_service.dart';
import '../common/update_dialog.dart';

/// 1. 发现音乐主页 (DiscoverView - Bento Grid 仪表盘)
class DesktopDiscoverView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopDiscoverView({super.key, required this.onNavigate});

  @override
  State<DesktopDiscoverView> createState() => _DesktopDiscoverViewState();
}

class _DesktopDiscoverViewState extends State<DesktopDiscoverView> {
  List<ImportedPlaylist> _curatedPlaylists = AudioPlayerService.isRunningInTest
      ? [
          ImportedPlaylist(
            id: 'test_curated_wuna',
            title: '东方禅境 · 幽篁古筝琴韵精选',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/69/49/61/694961f3-1414-355e-66e4-9649ba13ec55/23UM1IM57770.rgb.jpg/600x600bb.jpg',
            description: '甄选推荐歌单 · 4首单曲',
            trackCount: mockWuNaTracks.length,
            tracks: mockWuNaTracks,
          ),
        ]
      : [];
  List<ArtistProfile> _popularArtists = AudioPlayerService.isRunningInTest
      ? List.from(mockArtistsProfiles)
      : [];
  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    _loadRealDiscoverData();
  }

  void _loadRealDiscoverData() async {
    if (AudioPlayerService.isRunningInTest) return;
    setState(() => _isLoadingContent = true);
    try {
      final playlistsFuture = OnlineMusicService.searchOnlinePlaylists('精选', limit: 4);
      final artistsFuture = OnlineMusicService.fetchArtistList(limit: 8);

      final res = await Future.wait([playlistsFuture, artistsFuture]);
      if (mounted) {
        setState(() {
          _curatedPlaylists = res[0] as List<ImportedPlaylist>;
          final rawArtists = res[1] as List<Map<String, dynamic>>;
          _popularArtists = rawArtists.map((a) {
            final id = a['id']?.toString() ?? '';
            final name = a['name']?.toString() ?? '华语音乐人';
            final pic = a['img1v1Url']?.toString() ?? a['picUrl']?.toString() ?? '';
            final musicSize = (a['musicSize'] as num?)?.toInt() ?? 0;
            return ArtistProfile(
              id: id,
              name: name,
              role: '热门华语歌手 · $musicSize首单曲',
              fans: '华语热榜',
              bio: '热门入驻音乐人',
              avatarUrl: pic.isNotEmpty ? pic : NeteaseMusicService.fallbackCoverFor(name, '歌手'),
              musicSize: musicSize,
              albumSize: 0,
            );
          }).toList();
          _isLoadingContent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        // Bento Hero 席位 - 今日私享雷达
        SoftCard(
          padding: const EdgeInsets.all(28),
          borderRadius: MellowRadii.borderR28,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.15),
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radar_rounded, size: 14, color: theme.accentColor),
                              const SizedBox(width: 4),
                              Text(
                                '今日私享雷达',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '根据您常听的古风与经典流行智能漫游',
                            style: TextStyle(fontSize: 12, color: theme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '在静谧中邂逅共鸣 · 听见内心的温润回响',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '精选推荐曲目，沉浸式 Modern Soft UI 交互体验',
                      style: TextStyle(fontSize: 13.5, color: theme.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SoftButton(
                          label: '开启漫游播放',
                          icon: Icons.play_arrow_rounded,
                          isActive: true,
                          isPill: true,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          onTap: () {
                            final dailyTracks = DailyRecommendService.instance.getDailyRecommendTracks(limit: 30);
                            if (dailyTracks.isNotEmpty) {
                              player.playPlaylist(dailyTracks, startIndex: 0);
                            } else if (player.playlist.isNotEmpty) {
                              player.playTrack(player.playlist[0]);
                            } else {
                              final pool = getAllKnownTracks();
                              if (pool.isNotEmpty) {
                                player.playPlaylist(pool, startIndex: 0);
                              }
                            }
                          },
                        ),
                        SoftButton(
                          label: '查看完整推荐',
                          icon: Icons.explore_outlined,
                          isPill: true,
                          onTap: () => widget.onNavigate('playlists'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // 封面微浮雕
              MellowImage(
                url: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/58/8d/6d/588d6d61-fbac-148a-86bd-0030ce076ac1/23UM1IM57281.rgb.jpg/600x600bb.jpg',
                width: 150,
                height: 150,
                borderRadius: MellowRadii.borderR20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 每日专属推荐 Bento 卡片 (拟物日历便签头，点击下钻专属日推详情页)
        SoftCard(
          padding: const EdgeInsets.all(22),
          borderRadius: MellowRadii.borderR24,
          onTap: () => widget.onNavigate('daily_recommend'),
          child: Row(
            children: [
              // 拟物日历便签头
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFFFF655B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: MellowRadii.borderR20,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3366).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DailyRecommendService.instance.getFormattedWeekday(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DailyRecommendService.instance.getFormattedDay(),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.14),
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: Text(
                            '专属日推 · 每日06:00更新',
                            style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '共 ${DailyRecommendService.instance.getDailyRecommendTracks().length} 首精选单曲',
                          style: TextStyle(color: theme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DailyRecommendService.instance.getGreeting(),
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: theme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '根据您的真实听歌品味深度算法定制，点击查看今日完整推荐曲目',
                      style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SoftButton(
                label: '播放全部',
                icon: Icons.play_arrow_rounded,
                isActive: true,
                isPill: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onTap: () {
                  final tracks = DailyRecommendService.instance.getDailyRecommendTracks();
                  if (tracks.isNotEmpty) {
                    player.playPlaylist(tracks, startIndex: 0);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 推荐歌单网格
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '甄选歌单推荐',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: theme.textPrimary),
            ),
            TextButton(
              onPressed: () => widget.onNavigate('playlists'),
              child: Text('查看全部 >', style: TextStyle(color: theme.accentColor)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 推荐歌单网格 (自适应多分辨率列数，宽屏优雅延展)
        if (_isLoadingContent && _curatedPlaylists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 220).floor().clamp(2, 4);
              final displayPlaylists = _curatedPlaylists.isNotEmpty
                  ? _curatedPlaylists.take(4).toList()
                  : player.importedPlaylists.take(4).toList();

              if (displayPlaylists.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('暂无推荐歌单，可前往歌单广场发现音乐', style: TextStyle(color: theme.textMuted)),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.82,
                ),
                itemCount: displayPlaylists.length,
                itemBuilder: (context, idx) {
                  final pl = displayPlaylists[idx];
                  return _buildPlaylistCard(
                    context,
                    pl.title,
                    pl.description.isNotEmpty ? pl.description : '甄选推荐歌单 · ${pl.trackCount}首单曲',
                    pl.coverUrl,
                    () async {
                      if (pl.tracks.isNotEmpty) {
                        player.playPlaylist(pl.tracks, startIndex: 0);
                      } else {
                        final detail = await OnlineMusicService.importNeteasePlaylist(pl.id);
                        if (detail != null && detail.tracks.isNotEmpty) {
                          player.playPlaylist(detail.tracks, startIndex: 0);
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        const SizedBox(height: 32),

        // 热门歌手推荐环 (100% 真实全网歌手列表)
        Text(
          '热门入驻与关注歌手',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: theme.textPrimary),
        ),
        const SizedBox(height: 16),
        if (_popularArtists.isNotEmpty)
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: _popularArtists.map((a) {
              return _buildArtistAvatar(
                context,
                a.name,
                a.role.split('·').first.trim(),
                a.avatarUrl,
                () => widget.onNavigate('artist_detail', '${a.id}:::${a.name}:::${a.avatarUrl}'),
              );
            }).toList(),
          )
        else if (_isLoadingContent)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaylistCard(BuildContext context, String title, String sub, String img, VoidCallback onPlay) {
    final theme = context.watch<ThemeProvider>();
    return SoftCard(
      padding: const EdgeInsets.all(10),
      onTap: onPlay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                MellowImage(url: img, width: double.infinity, height: double.infinity, borderRadius: MellowRadii.borderR16),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: theme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistAvatar(BuildContext context, String name, String tag, String img, VoidCallback onTap) {
    final theme = context.watch<ThemeProvider>();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.accentColor.withValues(alpha: 0.4), width: 2),
            ),
            child: MellowAvatar(
              radius: 40,
              url: img,
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 13.5)),
          Text(tag, style: TextStyle(color: theme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 2. 歌单广场 (PlaylistSquareView)
class DesktopPlaylistSquareView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopPlaylistSquareView({super.key, required this.onNavigate});

  @override
  State<DesktopPlaylistSquareView> createState() => _DesktopPlaylistSquareViewState();
}

class _DesktopPlaylistSquareViewState extends State<DesktopPlaylistSquareView> {
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
  bool _isLoading = false;
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
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

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('歌单广场', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 2),
                Text('发现属于你的音乐磁场', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            SoftButton(
              label: '刷新广场',
              icon: Icons.refresh_rounded,
              isPill: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onTap: () => _loadPlaylists(reset: true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _tags.map((tag) {
              final isSel = _activeTag == tag;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SoftButton(
                  label: tag,
                  isActive: isSel,
                  isPill: true,
                  onTap: () => _switchTag(tag),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        if (_activeTag == '精选推荐') ...[
          SoftCard(
            padding: const EdgeInsets.all(18),
            borderRadius: MellowRadii.borderR20,
            onTap: () => widget.onNavigate('daily_recommend'),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
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
                        DailyRecommendService.instance.getFormattedWeekday(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DailyRecommendService.instance.getFormattedDay(),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3366).withValues(alpha: 0.12),
                              borderRadius: MellowRadii.borderPill,
                            ),
                            child: const Text('官方精选置顶', style: TextStyle(color: Color(0xFFFF3366), fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('每日 06:00 更新', style: TextStyle(color: theme.textMuted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final count = DailyRecommendService.instance.getDailyRecommendTracks().length;
                        return Text('专属声学每日推荐 · $count 首高保真单曲', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary));
                      }),
                      Text(DailyRecommendService.instance.getGreeting(), style: TextStyle(fontSize: 12, color: theme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                SoftButton(
                  label: '进入日推歌单',
                  icon: Icons.arrow_forward_rounded,
                  isActive: true,
                  isPill: true,
                  onTap: () => widget.onNavigate('daily_recommend'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            padding: const EdgeInsets.all(18),
            borderRadius: MellowRadii.borderR20,
            onTap: () => widget.onNavigate('scenarios'),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: MellowRadii.borderR16,
                  ),
                  child: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              borderRadius: MellowRadii.borderPill,
                            ),
                            child: const Text('全新场景推荐', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('结婚 · 国庆 · 新年 · 助眠 · 运动 · 露营', style: TextStyle(color: theme.textMuted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('场景歌单推荐与自由搜索 · 随心定制专属氛围', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      Text('搜结婚出婚礼歌单，搜国庆出欢庆赞歌，搜新年迎新春年味，随心自由检索', style: TextStyle(fontSize: 12, color: theme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                SoftButton(
                  label: '探索场景歌单',
                  icon: Icons.arrow_forward_rounded,
                  isActive: true,
                  isPill: true,
                  onTap: () => widget.onNavigate('scenarios'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 真实热门歌单展示区域
        if (_isLoading && _playlists.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.accentColor),
                  ),
                  const SizedBox(height: 16),
                  Text('正在加载全网精选热门歌单...', style: TextStyle(fontSize: 13, color: theme.textMuted)),
                ],
              ),
            ),
          )
        else if (_playlists.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music_rounded, size: 48, color: theme.textMuted),
                  const SizedBox(height: 12),
                  Text('暂未获取到歌单，点击上方刷新重试', style: TextStyle(fontSize: 14, color: theme.textMuted)),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.80,
            ),
            itemCount: _playlists.length,
            itemBuilder: (context, idx) {
              final pl = _playlists[idx];
              final countDisplay = pl.trackCount > 0 ? '${pl.trackCount}首' : (pl.tracks.isNotEmpty ? '${pl.tracks.length}首' : '');
              final descSuffix = countDisplay.isNotEmpty ? ' · 共$countDisplay' : '';

              return SoftCard(
                padding: const EdgeInsets.all(12),
                onTap: () {
                  widget.onNavigate(
                    'playlist_detail',
                    'playlist:::${pl.id}:::${pl.title}:::${pl.coverUrl}:::${pl.desc}:::playlists',
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          MellowImage(
                            url: pl.coverUrl,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: MellowRadii.borderR16,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: MellowRadii.borderPill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    pl.playCount,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pl.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${pl.desc}$descSuffix',
                      style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),

        if (_isLoadingMore)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor),
                  ),
                  const SizedBox(width: 10),
                  Text('正在加载下一批热门歌单...', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 官方四大核心权威榜单配置
final desktopCoreCharts = [
  {
    'title': '飙升榜',
    'desc': '近24小时全网播放量暴涨',
    'update': '每日09:00更新 · 100首',
    'badge': 'HOT',
    'gradient': const [Color(0xFFFF3366), Color(0xFFFF655B)],
    'icon': Icons.trending_up_rounded,
  },
  {
    'title': '热歌榜',
    'desc': '全平台亿级收听总榜单',
    'update': '每周四更新 · 200首',
    'badge': 'TOP',
    'gradient': const [Color(0xFFFF7A00), Color(0xFFFFB800)],
    'icon': Icons.local_fire_department_rounded,
  },
  {
    'title': '新歌榜',
    'desc': '全球华语精选新锐单曲首发',
    'update': '每日更新 · 100首',
    'badge': 'NEW',
    'gradient': const [Color(0xFF00C6FF), Color(0xFF0072FF)],
    'icon': Icons.auto_awesome_rounded,
  },
  {
    'title': '原创榜',
    'desc': '独立音乐人先锋代表作',
    'update': '每周五更新 · 50首',
    'badge': 'ORIGIN',
    'gradient': const [Color(0xFF8A2387), Color(0xFFE94057)],
    'icon': Icons.album_rounded,
  },
];

/// 3. 官方巅峰榜 (ToplistView - 接入全网实时动态榜单)
class DesktopToplistView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopToplistView({super.key, required this.onNavigate});

  @override
  State<DesktopToplistView> createState() => _DesktopToplistViewState();
}

class _DesktopToplistViewState extends State<DesktopToplistView> {
  final Map<String, List<Track>> _liveToplists = {};
  List<Map<String, dynamic>> _allToplists = [];
  String _selectedCategory = '全部榜单';
  bool _isLoadingAllToplists = false;
  String? _loadingChartName;

  final List<String> _categories = [
    '全部榜单',
    '官方权威榜',
    '精选特色榜',
    '全球潮流榜',
  ];

  @override
  void initState() {
    super.initState();
    _loadLiveToplists();
    _loadAllToplists();
  }

  void _loadLiveToplists() {
    if (AudioPlayerService.isRunningInTest) {
      for (final chart in ['飙升榜', '热歌榜', '新歌榜', '原创榜']) {
        if (toplistTracksMap.containsKey(chart)) {
          _liveToplists[chart] = List.from(toplistTracksMap[chart]!);
        }
      }
      return;
    }
    for (final chart in ['飙升榜', '热歌榜', '新歌榜', '原创榜']) {
      OnlineMusicService.fetchToplistTracks(chart, limit: 20).then((tracks) {
        if (mounted && tracks.isNotEmpty) {
          setState(() {
            _liveToplists[chart] = tracks;
          });
        }
      });
    }
  }

  void _loadAllToplists() async {
    if (AudioPlayerService.isRunningInTest) return;
    setState(() => _isLoadingAllToplists = true);
    final list = await OnlineMusicService.fetchAllToplists();
    if (mounted) {
      setState(() {
        _allToplists = list;
        _isLoadingAllToplists = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredToplists {
    if (_selectedCategory == '全部榜单') return _allToplists;
    if (_selectedCategory == '官方权威榜') {
      return _allToplists.where((c) {
        final n = c['name']?.toString() ?? '';
        return n.contains('飙升') ||
            n.contains('新歌') ||
            n.contains('热歌') ||
            n.contains('原创') ||
            n.contains('黑胶') ||
            n.contains('风向') ||
            n.contains('合伙人') ||
            n.contains('分享') ||
            n.contains('热度');
      }).toList();
    }
    if (_selectedCategory == '精选特色榜') {
      return _allToplists.where((c) {
        final n = c['name']?.toString() ?? '';
        return n.contains('电音') ||
            n.contains('说唱') ||
            n.contains('摇滚') ||
            n.contains('国风') ||
            n.contains('民谣') ||
            n.contains('ACG') ||
            n.contains('古典') ||
            n.contains('KTV') ||
            n.contains('DJ') ||
            n.contains('识曲');
      }).toList();
    }
    if (_selectedCategory == '全球潮流榜') {
      return _allToplists.where((c) {
        final n = c['name']?.toString() ?? '';
        return n.contains('Billboard') ||
            n.contains('UK') ||
            n.contains('Oricon') ||
            n.contains('欧美') ||
            n.contains('日本') ||
            n.contains('韩语') ||
            n.contains('日语') ||
            n.contains('法国') ||
            n.contains('俄语') ||
            n.contains('泰语') ||
            n.contains('Beatport');
      }).toList();
    }
    return _allToplists;
  }

  void _playChart(Map<String, dynamic> c) async {
    final chartId = c['id']?.toString() ?? '';
    final chartName = c['name']?.toString() ?? '排行榜';
    final player = context.read<AudioPlayerService>();

    if (_liveToplists.containsKey(chartName) && _liveToplists[chartName]!.isNotEmpty) {
      player.playPlaylist(_liveToplists[chartName]!, startIndex: 0);
      return;
    }

    setState(() => _loadingChartName = chartName);
    final tracks = await OnlineMusicService.fetchToplistTracks(chartId.isNotEmpty ? chartId : chartName);
    if (mounted) {
      setState(() => _loadingChartName = null);
      if (tracks.isNotEmpty) {
        setState(() {
          _liveToplists[chartName] = tracks;
        });
        player.playPlaylist(tracks, startIndex: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final coreCharts = desktopCoreCharts;

    final filteredList = _filteredToplists;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('官方巅峰排行榜', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('汇聚全网多源权威数据，实时追踪流行脉搏', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            SoftButton(
              label: '播放全部榜单',
              icon: Icons.play_arrow_rounded,
              isActive: true,
              isPill: true,
              onTap: () {
                final allTracks = <Track>[];
                final ids = <String>{};
                for (final c in ['飙升榜', '热歌榜', '新歌榜', '原创榜']) {
                  final list = _liveToplists[c] ?? toplistTracksMap[c] ?? [];
                  for (final t in list) {
                    if (ids.add(t.id)) allTracks.add(t);
                  }
                }
                if (allTracks.isNotEmpty) {
                  player.playPlaylist(allTracks);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 1. 四大核心官方权威榜单 (现代 1:1 正方形封套 + 固定质感高度，彻底根除拉伸变形)
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 1400
                ? 4
                : (constraints.maxWidth >= 760 ? 2 : 1);
            const cardHeight = 180.0;
            const coverSize = 156.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: cardHeight,
              ),
              itemCount: coreCharts.length,
              itemBuilder: (context, idx) {
            final c = coreCharts[idx];
            final gradientColors = c['gradient'] as List<Color>;
            final iconData = c['icon'] as IconData;
            final chartTitle = c['title'] as String;
            final chartTracks = _liveToplists[chartTitle] ??
                (AudioPlayerService.isRunningInTest ? (toplistTracksMap[chartTitle] ?? const <Track>[]) : const <Track>[]);

            return SoftCard(
              padding: const EdgeInsets.all(12),
              borderRadius: MellowRadii.borderR20,
              onTap: () {
                widget.onNavigate('toplist_detail', chartTitle);
              },
              child: Row(
                children: [
                  // 1:1 正方形 Squircle 榜单精美封套 (尺寸 156x156，永不变形)
                  Container(
                    width: coverSize,
                    height: coverSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: MellowRadii.borderR16,
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -8,
                          bottom: -8,
                          child: Icon(iconData, size: 76, color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: MellowRadii.borderPill,
                                ),
                                child: Text(
                                  c['badge'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c['update'] as String,
                                    style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.85)),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: GestureDetector(
                                  onTap: () {
                                    if (chartTracks.isNotEmpty) {
                                      player.playPlaylist(chartTracks, startIndex: 0);
                                    }
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.play_arrow_rounded, color: gradientColors[0], size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(chartTracks.length.clamp(0, 5), (i) {
                        final t = chartTracks[i];
                        final rank = i + 1;
                        final Color rankColor = rank == 1
                            ? const Color(0xFFFFB800)
                            : rank == 2
                                ? const Color(0xFF94A3B8)
                                : rank == 3
                                    ? const Color(0xFFCD7F32)
                                    : theme.textMuted;

                        return InkWell(
                          onTap: () => player.playPlaylist(chartTracks, startIndex: i),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: rank <= 3 ? FontWeight.w900 : FontWeight.bold,
                                      color: rankColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  flex: 6,
                                  child: Text(
                                    t.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: rank <= 3 ? FontWeight.w600 : FontWeight.normal,
                                      color: theme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  flex: 4,
                                  child: Text(
                                    t.artist,
                                    style: TextStyle(fontSize: 11, color: theme.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 15,
                                  color: theme.accentColor.withValues(alpha: 0.65),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),

        const SizedBox(height: 36),

        // 2. 全量 60+ 权威与特色榜单分区
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全网官方权威与特色榜单 (${filteredList.length})',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text('点击任意榜单立即加载并直接播放', style: TextStyle(fontSize: 12, color: theme.textMuted)),
              ],
            ),
            // 分类筛选 Tab 栏
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SoftButton(
                      label: cat,
                      isActive: isSel,
                      isPill: true,
                      onTap: () => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_isLoadingAllToplists && filteredList.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemCount: filteredList.length,
            itemBuilder: (context, idx) {
              final c = filteredList[idx];
              final name = c['name']?.toString() ?? '官方榜单';
              final cover = c['coverImgUrl']?.toString() ?? '';
              final freq = c['updateFrequency']?.toString() ?? '每日更新';
              final isCurrentLoading = _loadingChartName == name;

              return SoftCard(
                padding: const EdgeInsets.all(10),
                borderRadius: MellowRadii.borderR16,
                onTap: () {
                  final id = c['id']?.toString() ?? '';
                  widget.onNavigate('toplist_detail', '$id:::$name:::$cover:::$freq');
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: MellowRadii.borderR12,
                              child: MellowImage(
                                url: cover,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                freq,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => _playChart(c),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.accentColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: isCurrentLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: theme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      freq,
                      style: TextStyle(fontSize: 11, color: theme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 3.5. 巅峰排行榜详情页 (DesktopToplistDetailView - 呈现该榜单下 100~200 首全量歌曲)
class DesktopToplistDetailView extends StatefulWidget {
  final String chartName;
  final Function(String viewId, [String? extra]) onNavigate;

  const DesktopToplistDetailView({
    super.key,
    required this.chartName,
    required this.onNavigate,
  });

  @override
  State<DesktopToplistDetailView> createState() => _DesktopToplistDetailViewState();
}

class _DesktopToplistDetailViewState extends State<DesktopToplistDetailView> {
  String _chartId = '';
  String _chartTitle = '官方榜单';
  String _coverUrl = '';
  String _updateFreq = '每日更新';
  String _playlistDesc = '';
  String _backView = 'toplist';
  bool _isPlaylist = false;
  List<Color>? _gradient;
  IconData? _iconData;
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMoreTracks();
    }
  }

  void _checkAndAutoFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_allTrackIds.isEmpty || _tracks.length >= _allTrackIds.length) return;
      if (_isLoading || _isLoadingMore) return;
      // 若当前内容未填满视口（无法滚动，maxScrollExtent <= 100）或距底部非常近，主动连续拉取下一批，直到充满屏幕
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

  @override
  void didUpdateWidget(DesktopToplistDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartName != widget.chartName) {
      _parseParamsAndLoad();
    }
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
      _backView = parts.length > 5 ? parts[5] : 'playlists';
      _updateFreq = '高保真精选';
      _gradient = const [Color(0xFF6366F1), Color(0xFFA855F7)];
      _iconData = Icons.queue_music_rounded;
      _loadPlaylistTracks();
      return;
    }

    _isPlaylist = false;
    _backView = 'toplist';
    if (raw.contains(':::')) {
      final parts = raw.split(':::');
      _chartId = parts[0];
      _chartTitle = parts.length > 1 ? parts[1] : '官方榜单';
      _coverUrl = parts.length > 2 ? parts[2] : '';
      _updateFreq = parts.length > 3 ? parts[3] : '每日更新';
    } else {
      _chartTitle = raw;
      _chartId = '';
    }

    final match = desktopCoreCharts.firstWhere(
      (c) => c['title'] == _chartTitle,
      orElse: () => <String, Object>{},
    );
    if (match.isNotEmpty) {
      _gradient = match['gradient'] as List<Color>?;
      _iconData = match['icon'] as IconData?;
      _updateFreq = match['update'] as String? ?? _updateFreq;
    } else {
      _gradient = const [Color(0xFF6366F1), Color(0xFF4F46E5)];
      _iconData = Icons.leaderboard_rounded;
    }

    final initial = toplistTracksMap[_chartTitle];
    if (initial != null && initial.isNotEmpty) {
      _tracks = List.from(initial);
      _totalCount = _tracks.length;
    } else {
      _tracks = [];
      _totalCount = 0;
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

  Future<void> _loadTracks() async {
    setState(() => _isLoading = _tracks.isEmpty);
    try {
      final targetKey = _chartId.isNotEmpty ? _chartId : _chartTitle;
      final pl = await OnlineMusicService.fetchToplistPlaylist(targetKey);
      if (pl != null && mounted) {
        setState(() {
          _tracks = List.from(pl.tracks);
          _allTrackIds = List.from(pl.allTrackIds);
          _totalCount = pl.trackCount > 0
              ? pl.trackCount
              : (_allTrackIds.isNotEmpty ? _allTrackIds.length : _tracks.length);
          if (pl.coverUrl.isNotEmpty) _coverUrl = pl.coverUrl;
          if (pl.description.isNotEmpty) _playlistDesc = pl.description;
          _isLoading = false;
        });
        _checkAndAutoFillViewport();
        return;
      }
      final fetched = await OnlineMusicService.fetchToplistTracks(targetKey);
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
    final player = context.read<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    final displayTracks = _searchFilter.trim().isEmpty
        ? _tracks
        : _tracks.where((t) {
            final q = _searchFilter.trim().toLowerCase();
            return t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q) || t.album.toLowerCase().contains(q);
          }).toList();

    String backLabel = '返回巅峰榜单';
    if (_isPlaylist) {
      if (_backView == 'scenarios') {
        backLabel = '返回场景歌单';
      } else if (_backView == 'search') {
        backLabel = '返回搜索';
      } else {
        backLabel = '返回歌单广场';
      }
    }

    final totalDisplay = _totalCount > 0 ? _totalCount : _tracks.length;

    return Material(
      color: Colors.transparent,
      child: ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 128),
      children: [
        // 顶部返回按钮与层级导航
        InkWell(
          onTap: () => widget.onNavigate(_backView),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoftButton(
                  icon: Icons.arrow_back_rounded,
                  isCircle: true,
                  onTap: () => widget.onNavigate(_backView),
                ),
                const SizedBox(width: 12),
                Text(backLabel, style: TextStyle(color: theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 榜单/歌单 Header Banner
        SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1:1 Squircle 封面封套
              Container(
                width: 156,
                height: 156,
                decoration: BoxDecoration(
                  gradient: _coverUrl.isEmpty && _gradient != null
                      ? LinearGradient(
                          colors: _gradient!,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: MellowRadii.borderR20,
                  boxShadow: [
                    BoxShadow(
                      color: (_gradient != null ? _gradient![0] : theme.accentColor).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: MellowRadii.borderR20,
                  child: _coverUrl.isNotEmpty
                      ? MellowImage(
                          url: _coverUrl,
                          width: 156,
                          height: 156,
                          fit: BoxFit.cover,
                        )
                      : Stack(
                          children: [
                            Positioned(
                              right: -10,
                              bottom: -10,
                              child: Icon(_iconData ?? Icons.leaderboard_rounded, size: 84, color: Colors.white.withValues(alpha: 0.18)),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_iconData ?? Icons.leaderboard_rounded, size: 40, color: Colors.white),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      _chartTitle,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 24),

              // 详情信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.14),
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: Text(
                            _isPlaylist ? '场景精选歌单' : '官方权威排行榜',
                            style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _updateFreq,
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _chartTitle,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: theme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _playlistDesc.isNotEmpty
                          ? _playlistDesc
                          : '权威大数据实时聚合，收录全量 $totalDisplay 首精选好歌 · 每日同步刷新',
                      style: TextStyle(fontSize: 13, color: theme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SoftButton(
                          label: '播放全部 ($totalDisplay首)',
                          icon: Icons.play_arrow_rounded,
                          isActive: true,
                          isPill: true,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          onTap: () {
                            if (_tracks.isNotEmpty) {
                              player.playPlaylist(_tracks, startIndex: 0);
                              if (_allTrackIds.isNotEmpty && _tracks.length < _allTrackIds.length) {
                                _loadAllRemainingTracksToPlayer(player);
                              }
                            }
                          },
                        ),
                        SoftButton(
                          label: '添加到播放列表',
                          icon: Icons.playlist_add_rounded,
                          isPill: true,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          onTap: () {
                            if (_tracks.isNotEmpty) {
                              player.appendPlaylist(_tracks);
                              if (_allTrackIds.isNotEmpty && _tracks.length < _allTrackIds.length) {
                                _loadAllRemainingTracksToPlayer(player);
                              }
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text('已添加 ${_tracks.length} 首歌曲到播放列表'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 歌曲列表区域与即时搜索筛选
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _searchFilter.isEmpty
                  ? (_isPlaylist ? '歌曲列表 (已呈现 ${_tracks.length} 首 · 共 $totalDisplay 首)' : '榜单歌曲列表 (${displayTracks.length})')
                  : '筛选结果 (${displayTracks.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
            ),
            SizedBox(
              width: 240,
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchFilter = val),
                style: TextStyle(fontSize: 12, color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: _isPlaylist ? '在列表中筛选歌曲/歌手...' : '在榜单内筛选歌曲/歌手...',
                  hintStyle: TextStyle(fontSize: 12, color: theme.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: theme.textMuted),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, size: 14, color: theme.textMuted),
                          tooltip: '清空筛选',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  border: OutlineInputBorder(
                    borderRadius: MellowRadii.borderPill,
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: MellowRadii.borderPill,
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: MellowRadii.borderPill,
                    borderSide: BorderSide(color: theme.accentColor, width: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 现代歌曲表格列表
        DesktopSongTableView(
          tracks: displayTracks,
          isToplistRank: !_isPlaylist,
          onIndexTap: (idx) {
            player.playPlaylist(displayTracks, startIndex: idx);
          },
          emptyMessage: _isLoading
              ? (_isPlaylist ? '正在加载曲目...' : '正在加载榜单全量歌曲...')
              : (_isPlaylist ? '未找到相关歌曲' : '未找到相关榜单曲目'),
        ),

        // 触底懒加载指示器与已加载完全部提示
        if (_isLoadingMore) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '正在懒加载更多曲目... (已呈现 ${_tracks.length} / $totalDisplay 首)',
                    style: TextStyle(fontSize: 12, color: theme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ] else if (!_isLoadingMore && _tracks.isNotEmpty && _tracks.length < totalDisplay) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '已加载 ${_tracks.length} 首 · 剩余 ${totalDisplay - _tracks.length} 首未呈现',
                    style: TextStyle(fontSize: 12, color: theme.textMuted),
                  ),
                  const SizedBox(width: 14),
                  SoftButton(
                    label: '立即加载全部',
                    icon: Icons.download_rounded,
                    isPill: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    onTap: _loadAllRemainingTracks,
                  ),
                ],
              ),
            ),
          ),
        ] else if (_tracks.isNotEmpty && _tracks.length >= totalDisplay) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                '已加载全部 $totalDisplay 首曲目',
                style: TextStyle(fontSize: 12, color: theme.textMuted),
              ),
            ),
          ),
        ],
      ],
    ),
    );
  }
}

/// 3.6. 每日推荐歌单详情页 (DesktopDailyRecommendView - 专属声学日推全量 30 首真实高保真曲库)
class DesktopDailyRecommendView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;

  const DesktopDailyRecommendView({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DesktopDailyRecommendView> createState() => _DesktopDailyRecommendViewState();
}

class _DesktopDailyRecommendViewState extends State<DesktopDailyRecommendView> {
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyTracks();
  }

  void _loadDailyTracks() async {
    final cached = DailyRecommendService.instance.getDailyRecommendTracks();
    if (cached.isNotEmpty) {
      if (mounted) setState(() { _tracks = cached; _isLoading = false; });
    }
    final fresh = await DailyRecommendService.instance.getDailyRecommendTracksAsync();
    if (mounted) {
      setState(() {
        _tracks = fresh;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    final service = DailyRecommendService.instance;
    final tracks = _tracks.isNotEmpty ? _tracks : service.getDailyRecommendTracks();
    final greeting = service.getGreeting();
    final dayStr = service.getFormattedDay();
    final weekdayStr = service.getFormattedWeekday();
    final monthYearStr = service.getFormattedMonthYear();

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 128),
      children: [
        // 顶部返回按钮与层级导航
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onNavigate('discover'),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SoftButton(
                    icon: Icons.arrow_back_rounded,
                    isCircle: true,
                    onTap: () => widget.onNavigate('discover'),
                  ),
                  const SizedBox(width: 12),
                  Text('发现音乐', style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 16, color: theme.textMuted),
                  const SizedBox(width: 8),
                  Text('每日推荐', style: TextStyle(color: theme.accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 拟物日历便签头大卡片 Banner
        SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 拟物日历撕页卡片
              Container(
                width: 156,
                height: 156,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2028) : Colors.white,
                  borderRadius: MellowRadii.borderR20,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3366).withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  children: [
                    // 日历头部
                    Container(
                      height: 40,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF3366), Color(0xFFFF655B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(19),
                          topRight: Radius.circular(19),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$monthYearStr · $weekdayStr',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayStr,
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3366).withValues(alpha: 0.12),
                              borderRadius: MellowRadii.borderPill,
                            ),
                            child: const Text(
                              '每日06:00更新',
                              style: TextStyle(fontSize: 10, color: Color(0xFFFF3366), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // 详细文案与操作区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3366), Color(0xFFFF655B)],
                            ),
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: const Text(
                            '每日推荐',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3366).withValues(alpha: 0.14),
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: const Text(
                            '专属声学算法推荐',
                            style: TextStyle(color: Color(0xFFFF3366), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '契合度 99.8%',
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '根据你的近期听歌偏好与时光节律，为你精选 ${tracks.length} 首高保真温润纯音',
                      style: TextStyle(fontSize: 13, color: theme.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SoftButton(
                          label: '播放全部 (${tracks.length}首)',
                          icon: Icons.play_arrow_rounded,
                          isActive: true,
                          isPill: true,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          onTap: () {
                            if (tracks.isNotEmpty) {
                              player.playPlaylist(tracks, startIndex: 0);
                            }
                          },
                        ),
                        SoftButton(
                          label: '添加到播放列表',
                          icon: Icons.playlist_add_rounded,
                          isPill: true,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          onTap: () {
                            if (tracks.isNotEmpty) {
                              player.appendPlaylist(tracks);
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text('已添加 ${tracks.length} 首每日推荐歌曲到播放列表'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
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
        const SizedBox(height: 24),

        // 歌曲列表区
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '今日专属曲目列表 (${tracks.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
            ),
            Text('每日 06:00 自动刷新', style: TextStyle(fontSize: 12, color: theme.textMuted)),
          ],
        ),
        const SizedBox(height: 14),

        DesktopSongTableView(
          tracks: tracks,
          emptyMessage: _isLoading ? '正在拉取今日专属日推曲目...' : '今日暂无推荐曲目',
          onIndexTap: (idx) {
            player.playPlaylist(tracks, startIndex: idx);
          },
        ),
      ],
    );
  }
}

/// 4. 热门歌手库 (DesktopArtistsView - 网易云真实官方入驻全量歌手库)
class DesktopArtistsView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopArtistsView({super.key, required this.onNavigate});

  @override
  State<DesktopArtistsView> createState() => _DesktopArtistsViewState();
}

class _DesktopArtistsViewState extends State<DesktopArtistsView> {
  int _selectedArea = -1;
  int _selectedType = -1;
  String _selectedCategoryName = '全部热门';
  List<ArtistProfile> _artists = AudioPlayerService.isRunningInTest
      ? List.from(mockArtistsProfiles)
      : [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _artistCategories = [
    {'name': '全部热门', 'area': -1, 'type': -1},
    {'name': '华语男歌手', 'area': 7, 'type': 1},
    {'name': '华语女歌手', 'area': 7, 'type': 2},
    {'name': '华语乐队/组合', 'area': 7, 'type': 3},
    {'name': '欧美男歌手', 'area': 96, 'type': 1},
    {'name': '欧美女歌手', 'area': 96, 'type': 2},
    {'name': '欧美乐队/组合', 'area': 96, 'type': 3},
    {'name': '日本歌手', 'area': 8, 'type': -1},
    {'name': '韩国歌手', 'area': 16, 'type': -1},
  ];

  @override
  void initState() {
    super.initState();
    _loadArtists(area: _selectedArea, type: _selectedType);
  }

  void _loadArtists({required int area, required int type}) async {
    if (AudioPlayerService.isRunningInTest) return;
    setState(() => _isLoading = true);
    final rawList = await OnlineMusicService.fetchArtistList(area: area, type: type, limit: 60);
    if (!mounted) return;
    if (rawList.isNotEmpty) {
      final list = rawList.map((item) {
        final id = item['id']?.toString() ?? '';
        final name = item['name']?.toString() ?? '';
        var picUrl = item['img1v1Url']?.toString() ?? item['picUrl']?.toString() ?? '';
        if (picUrl.isNotEmpty && !picUrl.contains('?param=')) {
          picUrl = '$picUrl?param=300y300';
        }
        final musicSize = (item['musicSize'] as num?)?.toInt() ?? 0;
        final albumSize = (item['albumSize'] as num?)?.toInt() ?? 0;
        return ArtistProfile(
          id: id,
          name: name,
          avatarUrl: picUrl,
          role: '代表作 $musicSize 首 · 专辑 $albumSize 张',
          // 真实粉丝数接口未接入：不再用公式编造（见 docs/PC_USER_E2E_ACCEPTANCE_2026-09-25.md D-1）
          // 留空由卡片侧隐藏该行，避免展示与「代表作数」线性相关的伪值。
          fans: '',
          bio: '官方认证知名音乐人',
          musicSize: musicSize,
          albumSize: albumSize,
          tracks: const [],
        );
      }).toList();
      setState(() {
        _artists = list;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('热门歌手库', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('汇聚华语乐坛殿堂名宿与全球先锋音乐人 · 官方全量真实数据', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // 分类标签 Tab 栏
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _artistCategories.map((c) {
              final name = c['name'] as String;
              final isSel = _selectedCategoryName == name;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SoftButton(
                  label: name,
                  isActive: isSel,
                  isPill: true,
                  onTap: () {
                    setState(() {
                      _selectedCategoryName = name;
                      _selectedArea = c['area'] as int;
                      _selectedType = c['type'] as int;
                    });
                    _loadArtists(area: _selectedArea, type: _selectedType);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 225,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _artists.length,
          itemBuilder: (context, idx) {
            final a = _artists[idx];
            return SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              onTap: () => widget.onNavigate('artist_detail', '${a.id}:::${a.name}:::${a.avatarUrl}'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MellowAvatar(radius: 44, url: a.avatarUrl),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          a.name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 15, color: theme.accentColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.role,
                    style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (a.fans.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('粉丝 ${a.fans}', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 5. 歌手详情页 (DesktopArtistDetailView - 动态获取真实代表作50首与直链播放)
class DesktopArtistDetailView extends StatefulWidget {
  final String artistName;
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopArtistDetailView({super.key, required this.artistName, required this.onNavigate});

  @override
  State<DesktopArtistDetailView> createState() => _DesktopArtistDetailViewState();
}

class _DesktopArtistDetailViewState extends State<DesktopArtistDetailView> {
  bool _isFollowing = false;
  bool _isLoadingTracks = false;
  int _selectedTab = 0; // 0: 热门代表作 (Top 50), 1: 全部作品 (全量曲库)
  List<Track> _topTracks = [];
  List<Track> _allTracks = [];
  int _totalSongCount = 0;
  int _albumCount = 0;
  bool _isLoadingMore = false;
  bool _hasMoreAllSongs = true;
  bool _hasMoreTopSongs = true;
  int _allSongsOffset = 0;
  String _artistBio = '';
  String _artistId = '';
  String _artistName = '';
  String _artistAvatar = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _parseParamsAndLoad();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (_selectedTab == 1 && _hasMoreAllSongs) {
        _loadMoreAllSongs();
      } else if (_selectedTab == 0 && _hasMoreTopSongs) {
        _loadMoreTopSongs();
      }
    }
  }

  @override
  void didUpdateWidget(DesktopArtistDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _parseParamsAndLoad();
    }
  }

  void _parseParamsAndLoad() {
    final raw = widget.artistName;
    if (raw.contains(':::')) {
      final parts = raw.split(':::');
      _artistId = parts[0];
      _artistName = parts.length > 1 ? parts[1] : '';
      _artistAvatar = parts.length > 2 ? parts[2] : '';
    } else {
      _artistName = raw;
      final profile = getArtistProfileByName(raw);
      _artistId = profile.id;
      _artistAvatar = profile.avatarUrl;
    }

    _isFollowing = StorageService.instance.isArtistFollowed(_artistName);

    if (_artistAvatar.isEmpty) {
      final profile = getArtistProfileByName(_artistName);
      if (profile.avatarUrl.isNotEmpty) _artistAvatar = profile.avatarUrl;
    }

    final profile = getArtistProfileByName(_artistName);
    _artistBio = profile.bio;
    _totalSongCount = profile.musicSize;
    _albumCount = profile.albumSize;
    if (profile.tracks.isNotEmpty) {
      _topTracks = List.from(profile.tracks);
    } else {
      _topTracks = [];
    }
    _allTracks = [];
    _allSongsOffset = 0;
    _hasMoreAllSongs = true;
    _hasMoreTopSongs = true;
    _selectedTab = 0;
    _isLoadingTracks = _topTracks.isEmpty;

    _loadSongs();
  }

  void _loadSongs() async {
    final profile = getArtistProfileByName(_artistName);

    // 1. 尝试从 NetEase 官方接口拉取完整艺人资料（最新高清头像、总作品数、专辑数、官方传记）
    OnlineMusicService.fetchArtistDetail(_artistId, artistName: _artistName).then((detail) {
      if (detail != null && mounted) {
        setState(() {
          if (detail['avatarUrl'] != null && (detail['avatarUrl'] as String).isNotEmpty) {
            _artistAvatar = detail['avatarUrl'] as String;
          }
          final mSize = (detail['musicSize'] as num?)?.toInt() ?? 0;
          if (mSize > 0) _totalSongCount = mSize;
          final aSize = (detail['albumSize'] as num?)?.toInt() ?? 0;
          if (aSize > 0) _albumCount = aSize;
          final bio = detail['briefDesc']?.toString() ?? '';
          if (bio.isNotEmpty) _artistBio = bio;
        });
      }
    });

    // 2. 加载热门代表作 (Top 50)
    try {
      final songs = await OnlineMusicService.fetchArtistTopSongs(_artistId, artistName: _artistName);
      if (mounted) {
        setState(() {
          if (songs.isNotEmpty) {
            _topTracks = songs;
          } else if (_topTracks.isEmpty) {
            _topTracks = profile.tracks;
          }
          if (_totalSongCount == 0) _totalSongCount = _topTracks.length;
          _isLoadingTracks = false;
          _hasMoreTopSongs = _totalSongCount > _topTracks.length;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_topTracks.isEmpty) {
            _topTracks = profile.tracks;
          }
          _isLoadingTracks = false;
        });
      }
    }
  }

  void _loadMoreTopSongs() async {
    if (_isLoadingMore || !_hasMoreTopSongs) return;
    setState(() => _isLoadingMore = true);

    try {
      final res = await OnlineMusicService.fetchArtistAllSongs(
        _artistId,
        offset: _topTracks.length,
        limit: 50,
      );
      if (mounted) {
        final newTracks = res['tracks'] as List<Track>? ?? [];
        final total = (res['total'] as num?)?.toInt() ?? 0;
        final more = res['more'] == true;
        final existingIds = _topTracks.map((t) => t.id).toSet();
        final uniqueNew = newTracks.where((t) => !existingIds.contains(t.id)).toList();

        setState(() {
          _topTracks.addAll(uniqueNew);
          if (total > 0) _totalSongCount = total;
          _hasMoreTopSongs = more && uniqueNew.isNotEmpty;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _loadMoreAllSongs() async {
    if (_isLoadingMore || !_hasMoreAllSongs) return;
    setState(() => _isLoadingMore = true);

    try {
      final res = await OnlineMusicService.fetchArtistAllSongs(
        _artistId,
        offset: _allSongsOffset,
        limit: 50,
      );
      if (mounted) {
        final newTracks = res['tracks'] as List<Track>? ?? [];
        final total = (res['total'] as num?)?.toInt() ?? 0;
        final more = res['more'] == true;
        final existingIds = _allTracks.map((t) => t.id).toSet();
        final uniqueNew = newTracks.where((t) => !existingIds.contains(t.id)).toList();

        setState(() {
          _allTracks.addAll(uniqueNew);
          if (total > 0) _totalSongCount = total;
          _hasMoreAllSongs = more && uniqueNew.isNotEmpty;
          _allSongsOffset = _allTracks.length;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _switchTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    if (index == 1 && _allTracks.isEmpty) {
      _loadMoreAllSongs();
    }
  }

  Widget _buildTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.accentColor : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [BoxShadow(color: theme.accentColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : theme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final artistProfile = getArtistProfileByName(_artistName);
    final avatarToUse = _artistAvatar.isNotEmpty ? _artistAvatar : artistProfile.avatarUrl;
    final currentTracks = _selectedTab == 0 ? _topTracks : _allTracks;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        InkWell(
          onTap: () => widget.onNavigate('artists'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoftButton(
                  icon: Icons.arrow_back_rounded,
                  isCircle: true,
                  onTap: () => widget.onNavigate('artists'),
                ),
                const SizedBox(width: 12),
                Text('返回歌手列表', style: TextStyle(color: theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SoftCard(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              MellowAvatar(
                radius: 60,
                url: avatarToUse,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_artistName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        const SizedBox(width: 8),
                        Icon(Icons.verified_rounded, color: theme.accentColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _artistBio.isNotEmpty ? _artistBio : artistProfile.bio,
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // 真实作品规模元数据徽章
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '热门代表作 ${_topTracks.isNotEmpty ? _topTracks.length : 50} 首',
                            style: TextStyle(fontSize: 11.5, color: theme.accentColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            '全量收录 ${_totalSongCount > 0 ? _totalSongCount : "1000+"} 首',
                            style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                          ),
                        ),
                        if (_albumCount > 0 || artistProfile.albumSize > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '官方专辑 ${_albumCount > 0 ? _albumCount : artistProfile.albumSize} 张',
                              style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SoftButton(
                          label: _isFollowing ? '已关注' : '+ 关注歌手',
                          isActive: _isFollowing,
                          isPill: true,
                          onTap: () async {
                            await StorageService.instance.toggleArtistFollow(_artistName);
                            if (mounted) {
                              setState(() {
                                _isFollowing = StorageService.instance.isArtistFollowed(_artistName);
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        SoftButton(
                          label: '播放热门代表作',
                          icon: Icons.play_arrow_rounded,
                          isPill: true,
                          isActive: true,
                          onTap: () {
                            if (currentTracks.isNotEmpty) {
                              player.playPlaylist(currentTracks, startIndex: 0);
                            } else if (_topTracks.isNotEmpty) {
                              player.playPlaylist(_topTracks, startIndex: 0);
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
        const SizedBox(height: 24),
        // Tab 栏：热门代表作 (Top 50) 与 全量作品 (突破 50 首限制)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabButton(
                  title: '热门代表作 (${_topTracks.isNotEmpty ? _topTracks.length : 50})',
                  isActive: _selectedTab == 0,
                  onTap: () => _switchTab(0),
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _buildTabButton(
                  title: '全部作品 (${_totalSongCount > 0 ? _totalSongCount : "全量"})',
                  isActive: _selectedTab == 1,
                  onTap: () => _switchTab(1),
                  theme: theme,
                ),
              ],
            ),
            if (!_isLoadingTracks)
              Text(
                _selectedTab == 0
                    ? '网易云官方热度 Top 50 精选'
                    : '已加载 ${_allTracks.length} / 共 ${_totalSongCount > 0 ? _totalSongCount : _allTracks.length} 首',
                style: TextStyle(fontSize: 12, color: theme.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingTracks && currentTracks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (currentTracks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                _selectedTab == 0 ? '暂未加载到该歌手热门代表作' : '正在抓取全量曲库...',
                style: TextStyle(color: theme.textMuted),
              ),
            ),
          )
        else
          ...List.generate(currentTracks.length, (idx) {
            final t = currentTracks[idx];
            return SoftCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => player.playPlaylist(currentTracks, startIndex: idx),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: idx < 3 ? FontWeight.bold : FontWeight.normal,
                        color: idx < 3 ? theme.accentColor : theme.textMuted,
                      ),
                    ),
                  ),
                  MellowImage(url: t.coverUrl, width: 42, height: 42, borderRadius: MellowRadii.borderR8),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.artist} · ${t.album}',
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(t.formattedDuration, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 16),
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

        // 底部引导或分页展示
        if (_selectedTab == 0) ...[
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('触底自动加载更多作品中...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_hasMoreTopSongs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SoftButton(
                  label: '向下滚动自动加载全量曲库 · 或切换全部作品 ($_totalSongCount 首) >',
                  icon: Icons.library_music_rounded,
                  isPill: true,
                  onTap: () => _switchTab(1),
                ),
              ),
            )
          else if (_topTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '已呈现全部 ${_topTracks.length} 首代表作与作品',
                  style: TextStyle(fontSize: 12, color: theme.textMuted),
                ),
              ),
            ),
        ],
        if (_selectedTab == 1) ...[
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('正在自动加载更多曲目...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_hasMoreAllSongs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SoftButton(
                  label: '向下滚动自动加载 · 或点击加载更多 (${_allTracks.length} / $_totalSongCount 首)',
                  icon: Icons.arrow_downward_rounded,
                  isPill: true,
                  onTap: _loadMoreAllSongs,
                ),
              ),
            )
          else if (_allTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '已全部加载完毕 · 共收录 ${_allTracks.length} 首真音源',
                  style: TextStyle(fontSize: 12, color: theme.textMuted),
                ),
              ),
            ),
        ],
      ],
    );
  }
}


/// 6. 声音电台 (PodcastView)
class DesktopPodcastView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopPodcastView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final radios = presetRadioStations;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
      children: [
        Text('声音电台专区', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisExtent: 96,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: radios.length,
              itemBuilder: (context, idx) {
                final r = radios[idx];
                return SoftCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () {
                    player.playTrack(r.track);
                  },
                  child: Row(
                    children: [
                      MellowImage(url: r.coverUrl, width: 72, height: 72, borderRadius: MellowRadii.borderR16),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              r.title,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.sub,
                              style: TextStyle(fontSize: 12, color: theme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r.listeners,
                              style: TextStyle(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.radio_rounded, color: theme.accentColor, size: 26),
                    ],
                  ),
                );
              },
            ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('自然声景与专注空间', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            Text('纯净声学采样 · 无缝沉浸循环', style: TextStyle(fontSize: 12, color: theme.textMuted)),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final soundscapes = [
              {
                'title': '森林夜雨 · 幽谷独行',
                'desc': '高保真立体声雨丝与树叶拍击声',
                'tag': '深度睡眠',
                'icon': Icons.water_drop_rounded,
                'color': const Color(0xFF0284C7),
              },
              {
                'title': '壁炉柴火 · 暖冬微光',
                'desc': '木柴劈啪声与轻微室内回响',
                'tag': '沉浸阅读',
                'icon': Icons.local_fire_department_rounded,
                'color': const Color(0xFFEA580C),
              },
              {
                'title': '深海蓝鲸 · 频率律动',
                'desc': '低频水下空灵声场与心流共振',
                'tag': '高效专注',
                'icon': Icons.waves_rounded,
                'color': const Color(0xFF4F46E5),
              },
            ];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (constraints.maxWidth / 300).floor().clamp(1, 3),
                mainAxisExtent: 110,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: soundscapes.length,
              itemBuilder: (context, idx) {
                final sc = soundscapes[idx];
                final col = sc['color'] as Color;
                return SoftCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () {
                    if (radios.isNotEmpty) {
                      player.playTrack(radios[idx % radios.length].track);
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderR16,
                        ),
                        child: Icon(sc['icon'] as IconData, color: col, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              sc['title'] as String,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sc['desc'] as String,
                              style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.12),
                                borderRadius: MellowRadii.borderPill,
                              ),
                              child: Text(
                                sc['tag'] as String,
                                style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// 7. 我喜欢的音乐 (FavoriteView - 一体化现代高密度曲目列表)
class DesktopFavoriteView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopFavoriteView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final favTracks = player.favoriteTracks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        SoftCard(
          padding: const EdgeInsets.all(28),
          borderRadius: MellowRadii.borderR24,
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF472B6)]),
                  borderRadius: MellowRadii.borderR20,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我喜欢的音乐', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                    const SizedBox(height: 6),
                    Text('共收藏 ${favTracks.length} 首心动单曲 · 本地安全持久化存储', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        SoftButton(
                          label: '一键播放全部',
                          icon: Icons.play_arrow_rounded,
                          isActive: true,
                          isPill: true,
                          onTap: () {
                            if (favTracks.isNotEmpty) player.playPlaylist(favTracks);
                          },
                        ),
                        SoftButton(
                          label: '导入更多',
                          icon: Icons.add_link_rounded,
                          isPill: true,
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => const ImportPlaylistModal(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        DesktopSongTableView(
          tracks: favTracks,
          emptyMessage: '暂无收藏曲目，在播放或搜索时点击红心即可收入心动歌单',
        ),
      ],
    );
  }
}

/// 现代桌面端一体化高密度歌曲列表组件
class DesktopSongTableView extends StatelessWidget {
  final List<Track> tracks;
  final Function(Track)? onTrackTap;
  final Function(int index)? onIndexTap;
  final String? emptyMessage;
  final bool isToplistRank;

  const DesktopSongTableView({
    super.key,
    required this.tracks,
    this.onTrackTap,
    this.onIndexTap,
    this.emptyMessage,
    this.isToplistRank = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final currentPlayingId = context.select<AudioPlayerService, String?>((p) => p.currentTrack?.id);
    final player = context.read<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    if (tracks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.music_off_rounded, size: 44, color: theme.textMuted),
              const SizedBox(height: 12),
              Text(emptyMessage ?? '暂无曲目', style: TextStyle(color: theme.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showAlbum = constraints.maxWidth >= 650;

        return SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          borderRadius: MellowRadii.borderR20,
          child: Column(
            children: [
              // 优雅表头
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: showAlbum ? 5 : 6,
                      child: Text('音乐标题', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textMuted)),
                    ),
                    Expanded(
                      flex: showAlbum ? 3 : 4,
                      child: Text('歌手', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textMuted)),
                    ),
                    if (showAlbum)
                      Expanded(
                        flex: 3,
                        child: Text('专辑', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textMuted)),
                      ),
                    Container(
                      width: 50,
                      alignment: Alignment.centerRight,
                      child: Text('时长', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textMuted)),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              ),
              // 数据行 (每个条目包裹 RepaintBoundary 彻底隔绝重绘)
              ...tracks.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final t = entry.value;
                final isPlaying = currentPlayingId == t.id;

                return RepaintBoundary(
                  key: ValueKey('song_row_${t.id}'),
                  child: _DesktopSongTableRow(
                    index: idx,
                    track: t,
                    isPlaying: isPlaying,
                    showAlbum: showAlbum,
                    isToplistRank: isToplistRank,
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 60), () {
                        if (onIndexTap != null) {
                          onIndexTap!(entry.key);
                        } else if (onTrackTap != null) {
                          onTrackTap!(t);
                        } else {
                          player.playTrack(t);
                        }
                      });
                    },
                    onFavoriteToggle: () => player.toggleFavorite(t.id, t),
                    isFavorite: player.isFavorite(t.id),
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

class _DesktopSongTableRow extends StatefulWidget {
  final int index;
  final Track track;
  final bool isPlaying;
  final bool showAlbum;
  final bool isToplistRank;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final bool isFavorite;

  const _DesktopSongTableRow({
    required this.index,
    required this.track,
    required this.isPlaying,
    this.showAlbum = true,
    this.isToplistRank = false,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.isFavorite,
  });

  @override
  State<_DesktopSongTableRow> createState() => _DesktopSongTableRowState();
}

class _DesktopSongTableRowState extends State<_DesktopSongTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    final bgColor = widget.isPlaying
        ? theme.accentColor.withValues(alpha: isDark ? 0.18 : 0.1)
        : (_isHovered
            ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
            : Colors.transparent);

    return ExcludeSemantics(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: MellowRadii.borderR12,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: widget.isPlaying
                    ? Icon(Icons.volume_up_rounded, size: 16, color: theme.accentColor)
                    : (_isHovered
                        ? Icon(Icons.play_arrow_rounded, size: 18, color: theme.accentColor)
                        : (widget.isToplistRank && widget.index <= 3
                            ? Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: widget.index == 1
                                        ? const Color(0xFFFFB800)
                                        : widget.index == 2
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFFCD7F32),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              )
                            : Text(
                                widget.index.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textMuted,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ))),
              ),
              const SizedBox(width: 8),
              MellowImage(
                url: widget.track.coverUrl,
                width: 38,
                height: 38,
                borderRadius: MellowRadii.borderR8,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: widget.showAlbum ? 5 : 6,
                child: Text(
                  widget.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.w500,
                    color: widget.isPlaying ? theme.accentColor : theme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: widget.showAlbum ? 3 : 4,
                child: Text(
                  widget.track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                ),
              ),
              if (widget.showAlbum) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.track.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.textMuted),
                  ),
                ),
              ],
              Container(
                width: 50,
                alignment: Alignment.centerRight,
                child: Text(
                  widget.track.formattedDuration,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: Icon(
                  widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 18,
                  color: widget.isFavorite ? const Color(0xFFEF4444) : theme.textMuted,
                ),
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                onPressed: widget.onFavoriteToggle,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// 7.5. 导入与自建歌单中心 (DesktopImportedPlaylistsView - 对标 AlgerMusicPlayer 歌单库)
class DesktopImportedPlaylistsView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopImportedPlaylistsView({super.key, required this.onNavigate});

  @override
  State<DesktopImportedPlaylistsView> createState() => _DesktopImportedPlaylistsViewState();
}

class _DesktopImportedPlaylistsViewState extends State<DesktopImportedPlaylistsView> {
  int _selectedFilter = 0; // 0: 全部, 1: 自建, 2: 外部导入

  void _showRenameDialog(BuildContext context, ImportedPlaylist pl) {
    final titleCtrl = TextEditingController(text: pl.title);
    final descCtrl = TextEditingController(text: pl.description);
    final player = context.read<AudioPlayerService>();
    final theme = context.read<ThemeProvider>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SoftCard(
            padding: const EdgeInsets.all(22),
            borderRadius: MellowRadii.borderR24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('编辑歌单信息', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 16),
                Text('歌单名称', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 6),
                RecessedWell(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: MellowRadii.borderR12,
                  child: TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  ),
                ),
                const SizedBox(height: 12),
                Text('歌单描述', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textSecondary)),
                const SizedBox(height: 6),
                RecessedWell(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: MellowRadii.borderR12,
                  child: TextField(
                    controller: descCtrl,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SoftButton(label: '取消', onTap: () => Navigator.of(ctx).pop()),
                    const SizedBox(width: 10),
                    SoftButton(
                      label: '保存修改',
                      isActive: true,
                      onTap: () {
                        player.renamePlaylist(pl.id, titleCtrl.text, descCtrl.text);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已更新歌单「${titleCtrl.text}」信息')),
                        );
                      },
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

  void _showDeleteConfirmDialog(BuildContext context, ImportedPlaylist pl) {
    final player = context.read<AudioPlayerService>();
    final theme = context.read<ThemeProvider>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SoftCard(
            padding: const EdgeInsets.all(22),
            borderRadius: MellowRadii.borderR24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('确认删除歌单？', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 10),
                Text('删除歌单「${pl.title}」不会影响歌曲原文件或收藏记录。', style: TextStyle(fontSize: 13, color: theme.textMuted)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SoftButton(label: '取消', onTap: () => Navigator.of(ctx).pop()),
                    const SizedBox(width: 10),
                    SoftButton(
                      label: '确认删除',
                      icon: Icons.delete_outline_rounded,
                      isActive: true,
                      onTap: () {
                        player.deletePlaylist(pl.id);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已删除歌单「${pl.title}」')),
                        );
                      },
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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final allPlaylists = player.importedPlaylists;

    final filteredPlaylists = allPlaylists.where((pl) {
      if (_selectedFilter == 1) return pl.isCustom;
      if (_selectedFilter == 2) return !pl.isCustom;
      return true;
    }).toList();

    final customCount = allPlaylists.where((p) => p.isCustom).length;
    final importedCount = allPlaylists.where((p) => !p.isCustom).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导入与自建歌单', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('管理自建精选集，或一键导入网易云音乐、QQ音乐分享链接与公开歌单', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                SoftButton(
                  label: '新建自建歌单',
                  icon: Icons.add_circle_outline_rounded,
                  isActive: true,
                  isPill: true,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const CreatePlaylistModal(),
                  ),
                ),
                SoftButton(
                  label: '心动导出',
                  icon: Icons.favorite_border_rounded,
                  tooltip: '将我喜欢的音乐批量导出为新歌单',
                  isPill: true,
                  onTap: () {
                    final pl = player.exportFavoritesToPlaylist('心动收藏精选 · ${DateTime.now().month}月');
                    if (pl != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已成功导出自建歌单「${pl.title}」（共 ${pl.trackCount} 首）！')),
                      );
                    }
                  },
                ),
                SoftButton(
                  label: '导入新歌单',
                  icon: Icons.add_link_rounded,
                  isPill: true,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const ImportPlaylistModal(),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 分类微胶囊过滤器
        Row(
          children: [
            _buildFilterChip('全部 (${allPlaylists.length})', 0, theme),
            const SizedBox(width: 10),
            _buildFilterChip('我的自建 ($customCount)', 1, theme),
            const SizedBox(width: 10),
            _buildFilterChip('外部导入 ($importedCount)', 2, theme),
          ],
        ),
        const SizedBox(height: 20),

        if (filteredPlaylists.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(40),
            borderRadius: MellowRadii.borderR24,
            child: Column(
              children: [
                Icon(Icons.queue_music_rounded, size: 56, color: theme.accentColor),
                const SizedBox(height: 16),
                Text(
                  _selectedFilter == 1
                      ? '暂无自建歌单'
                      : _selectedFilter == 2
                          ? '暂无外部导入歌单'
                          : '暂无歌单数据',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedFilter == 1
                      ? '点击右上角“新建自建歌单”，或在播放歌曲时随时点击“收录到歌单”建立您的专属音乐集！'
                      : '点击右上角“导入新歌单”，粘贴网易云公开歌单即可完整同步！',
                  style: TextStyle(fontSize: 13, color: theme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SoftButton(
                  label: _selectedFilter == 1 ? '创建第一个歌单' : '立即体验导入',
                  icon: _selectedFilter == 1 ? Icons.add_rounded : Icons.download_rounded,
                  isActive: true,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => _selectedFilter == 1 ? const CreatePlaylistModal() : const ImportPlaylistModal(),
                  ),
                ),
              ],
            ),
          )
        else
          for (final pl in filteredPlaylists)
            SoftCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              borderRadius: MellowRadii.borderR20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MellowImage(url: pl.coverUrl, width: 72, height: 72, borderRadius: MellowRadii.borderR12),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    pl.title,
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (pl.isCustom ? theme.accentColor : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                                    borderRadius: MellowRadii.borderPill,
                                  ),
                                  child: Text(
                                    pl.isCustom ? '自建' : '外部导入',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: pl.isCustom ? theme.accentColor : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '包含 ${pl.trackCount} 首完整音轨 · ${pl.description}',
                              style: TextStyle(fontSize: 12.5, color: theme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          SoftButton(
                            label: '播放全部',
                            icon: Icons.play_arrow_rounded,
                            isActive: true,
                            isPill: true,
                            onTap: () => player.playPlaylist(pl.tracks),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary, size: 20),
                            color: theme.cardColor,
                            shape: RoundedRectangleBorder(borderRadius: MellowRadii.borderR12),
                            onSelected: (action) {
                              if (action == 'rename') {
                                _showRenameDialog(context, pl);
                              } else if (action == 'delete') {
                                _showDeleteConfirmDialog(context, pl);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16, color: theme.textPrimary),
                                    const SizedBox(width: 8),
                                    Text('重命名与描述', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                    SizedBox(width: 8),
                                    Text('删除此歌单', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // 前 5 首曲目预览与单曲移除控制
                  for (final t in pl.tracks.take(5))
                    InkWell(
                      onTap: () => player.playTrack(t),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_outline_rounded, size: 18, color: theme.accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${t.title} - ${t.artist}', style: TextStyle(fontSize: 13, color: theme.textPrimary)),
                            ),
                            Text(t.formattedDuration, style: TextStyle(fontSize: 12, color: theme.textMuted)),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () {
                                player.removeTrackFromPlaylist(pl.id, t.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已从歌单中移除「${t.title}」')),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.remove_circle_outline_rounded, size: 16, color: theme.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (pl.tracks.length > 5) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '还有 ${pl.tracks.length - 5} 首曲目未显示，点击上方“播放全部”即可完整连播',
                        style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index, ThemeProvider theme) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor.withValues(alpha: 0.15) : theme.canvasColor,
          borderRadius: MellowRadii.borderPill,
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.borderColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.accentColor : theme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 8. 播放历史 (HistoryView)
class DesktopHistoryView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopHistoryView({super.key, required this.onNavigate});

  @override
  State<DesktopHistoryView> createState() => _DesktopHistoryViewState();
}

class _DesktopHistoryViewState extends State<DesktopHistoryView> {
  late List<Track> _frozenTracks;
  int _lastHistoryLength = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = context.read<AudioPlayerService>();
    if (_lastHistoryLength == -1 || player.playHistory.length != _lastHistoryLength) {
      _frozenTracks = List.of(player.playHistory);
      _lastHistoryLength = _frozenTracks.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    // 当且仅当总曲目数变化时（如清空或大批量导入）同步快照，普通切歌时维持视口稳定
    if (player.playHistory.length != _lastHistoryLength) {
      _frozenTracks = List.of(player.playHistory);
      _lastHistoryLength = _frozenTracks.length;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('播放足迹历史', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('已记录最近 ${_frozenTracks.length} 首曲目 · 真实本地存储', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            if (_frozenTracks.isNotEmpty)
              SoftButton(
                label: '清空足迹',
                icon: Icons.delete_sweep_rounded,
                isPill: true,
                onTap: () {
                  player.clearPlayHistory();
                  setState(() {
                    _frozenTracks = [];
                    _lastHistoryLength = 0;
                  });
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清空全部本地播放历史记录')),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        DesktopSongTableView(
          tracks: _frozenTracks,
          onTrackTap: (track) {
            Future.delayed(const Duration(milliseconds: 60), () {
              if (mounted) {
                player.playTrack(track);
              }
            });
          },
          emptyMessage: '暂无播放历史，在发现页、榜单或搜索播放音乐，足迹将自动安全记录在此',
        ),
      ],
    );
  }
}

/// 9. 本地与下载专区 (LocalMusicView)
class DesktopLocalMusicView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopLocalMusicView({super.key, required this.onNavigate});

  @override
  State<DesktopLocalMusicView> createState() => _DesktopLocalMusicViewState();
}

class _DesktopLocalMusicViewState extends State<DesktopLocalMusicView> {
  void _openScanDialog(BuildContext context, AudioPlayerService player, ThemeProvider theme) {
    final home = Platform.environment['HOME'] ?? '';
    final defaultMusicDir = Platform.isWindows
        ? 'C:\\Users\\Public\\Music'
        : (home.isNotEmpty ? '$home/Music' : '/Users/Shared');
    final textController = TextEditingController(text: defaultMusicDir);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: MellowRadii.borderR24),
        title: Text('扫描本地音频目录', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('支持扫描 FLAC、WAV、MP3、OGG、M4A 等常见音频格式：', style: TextStyle(fontSize: 12.5, color: theme.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: Platform.isWindows ? '输入文件夹绝对路径，如 C:\\Users\\Music' : '输入文件夹绝对路径，如 /Users/xxx/Music',
                hintStyle: TextStyle(color: theme.textMuted),
                filled: true,
                fillColor: theme.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: MellowRadii.borderR12, borderSide: BorderSide(color: theme.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: MellowRadii.borderR12, borderSide: BorderSide(color: theme.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: MellowRadii.borderR12, borderSide: BorderSide(color: theme.accentColor)),
                prefixIcon: const Icon(Icons.folder_open_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('默认音乐库', style: TextStyle(fontSize: 11)),
                  onPressed: () => textController.text = defaultMusicDir,
                ),
                ActionChip(
                  label: Text(Platform.isWindows ? '示例演示目录' : '下载目录', style: const TextStyle(fontSize: 11)),
                  onPressed: () => textController.text = Platform.isWindows
                      ? 'E:\\Music\\Lossless'
                      : (home.isNotEmpty ? '$home/Downloads' : '/tmp'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('取消', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              shape: RoundedRectangleBorder(borderRadius: MellowRadii.borderPill),
            ),
            onPressed: () async {
              final path = textController.text.trim();
              Navigator.of(dialogCtx).pop();
              if (path.isNotEmpty) {
                final dir = Directory(path);
                if (!dir.existsSync()) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('目录不存在或无法访问，请检查路径: $path')),
                    );
                  }
                  return;
                }
                final count = await player.scanLocalDirectory(path);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(count > 0 ? '扫描完成！成功载入 $count 首本地歌曲' : '扫描完成，未发现新支持的音频文件'),
                    ),
                  );
                }
              }
            },
            child: const Text('开始扫描', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;
    final localTracks = player.localTracks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        // 1. 顶部标题栏
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地与离线下载', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('支持 FLAC / WAV / MP3 / OGG 无损音频直接声卡解码回放', style: TextStyle(color: theme.textMuted, fontSize: 13)),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (localTracks.isNotEmpty) ...[
                  SoftButton(
                    label: '播放全部',
                    icon: Icons.play_arrow_rounded,
                    isPill: true,
                    onTap: () => player.playLocalMusic(),
                  ),
                  SoftButton(
                    label: '清空曲库',
                    icon: Icons.delete_sweep_rounded,
                    isPill: true,
                    onTap: () => player.clearLocalTracks(),
                  ),
                ],
                SoftButton(
                  label: '扫描目录',
                  icon: Icons.create_new_folder_rounded,
                  isPill: true,
                  onTap: () => _openScanDialog(context, player, theme),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. 本地曲库统计看板
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          borderRadius: MellowRadii.borderR20,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.audio_file_rounded, size: 28, color: theme.accentColor),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本地音乐库统计', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      '已收录 ${localTracks.length} 首离线曲目 · ${player.localDirectories.length} 个扫描目录',
                      style: TextStyle(color: theme.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  _buildFormatBadge('FLAC', Colors.purpleAccent, isDark),
                  _buildFormatBadge('WAV', Colors.tealAccent, isDark),
                  _buildFormatBadge('MP3', Colors.blueAccent, isDark),
                  _buildFormatBadge('Hi-Res', theme.accentColor, isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. 歌曲列表或空状态
        if (localTracks.isEmpty)
          RecessedWell(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            borderRadius: MellowRadii.borderR24,
            child: Column(
              children: [
                Icon(Icons.folder_open_rounded, size: 54, color: theme.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('本地曲库暂无内容', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 17)),
                const SizedBox(height: 6),
                Text('点击下方按钮选择或输入要扫描的本地音频文件夹，即可秒级载入您的本地无损曲库',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textMuted, fontSize: 13)),
                const SizedBox(height: 20),
                SoftButton(
                  label: '立即添加并扫描目录',
                  icon: Icons.add_circle_outline_rounded,
                  isPill: true,
                  onTap: () => _openScanDialog(context, player, theme),
                ),
              ],
            ),
          )
        else ...[
          Text('曲目清单 (${localTracks.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: localTracks.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final track = localTracks[index];
              final isCurrent = player.currentTrack?.id == track.id;

              return SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: MellowRadii.borderR12,
                child: Row(
                  children: [
                    // 序号/播放中指示
                    SizedBox(
                      width: 32,
                      child: isCurrent && player.isPlaying
                          ? Icon(Icons.volume_up_rounded, color: theme.accentColor, size: 18)
                          : Text(
                              '${index + 1}'.padLeft(2, '0'),
                              style: TextStyle(fontSize: 13, color: isCurrent ? theme.accentColor : theme.textMuted),
                            ),
                    ),
                    const SizedBox(width: 8),

                    // 封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: theme.accentColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.music_note_rounded, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 歌名与歌手
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isCurrent ? theme.accentColor : theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: theme.textMuted),
                          ),
                        ],
                      ),
                    ),

                    // 路径/专辑
                    Expanded(
                      flex: 2,
                      child: Text(
                        track.localPath ?? track.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                      ),
                    ),

                    // 操作栏
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isCurrent && player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: theme.accentColor,
                            size: 24,
                          ),
                          tooltip: isCurrent && player.isPlaying ? '暂停' : '播放',
                          onPressed: () {
                            if (isCurrent) {
                              player.togglePlay();
                            } else {
                              player.playTrack(track);
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: player.isFavorite(track.id) ? Colors.pink : theme.textMuted,
                            size: 18,
                          ),
                          tooltip: '红心收藏',
                          onPressed: () => player.toggleFavorite(track.id, track),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: theme.textMuted, size: 18),
                          tooltip: '从曲库移除',
                          onPressed: () => player.removeLocalTrack(track.id),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFormatBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

/// 10. 个性化设置中心 (SettingsView)
class DesktopSettingsView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopSettingsView({super.key, required this.onNavigate});

  @override
  State<DesktopSettingsView> createState() => _DesktopSettingsViewState();
}

class _DesktopSettingsViewState extends State<DesktopSettingsView> {
  late bool _minimizeToTray;
  bool _isCheckingUpdate = false;

  Future<void> _checkUpdate({bool forceMock = false}) async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = VersionCheckService();
      final newVersion = await service.checkLatestVersion(forceMock: forceMock);
      if (!mounted) return;
      if (newVersion != null) {
        await UpdateDialog.show(context, newVersion);
      } else {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('已是最新版本 (v${service.currentVersionName})'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('检查更新失败: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _minimizeToTray = WindowsTrayService.instance.minimizeToTray;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        Text('个性化与系统设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 20),

        // 1. 外观模式
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('外观与主题质感', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '跟随系统 (Auto)',
                      icon: Icons.brightness_auto_rounded,
                      isActive: theme.appThemeMode == AppThemeMode.system,
                      onTap: () => theme.setThemeMode(AppThemeMode.system),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftButton(
                      label: '温润白瓷 (Light)',
                      icon: Icons.light_mode_rounded,
                      isActive: theme.appThemeMode == AppThemeMode.light,
                      onTap: () => theme.setThemeMode(AppThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftButton(
                      label: '深石墨夜间 (Dark)',
                      icon: Icons.dark_mode_rounded,
                      isActive: theme.appThemeMode == AppThemeMode.dark,
                      onTap: () => theme.setThemeMode(AppThemeMode.dark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. 声学强调色
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('声学柔光强调色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: AccentColorType.values.map((type) {
                  final isSelected = theme.accentType == type;
                  return GestureDetector(
                    onTap: () => theme.setAccentType(type),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: type.getColor(isDark),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(color: type.getColor(isDark).withValues(alpha: 0.4), blurRadius: 10),
                            ],
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                        ),
                        const SizedBox(height: 6),
                        Text(type.label, style: TextStyle(fontSize: 11.5, color: theme.textSecondary)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. 弥散光晕浓度
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('动态声学弥散光晕浓度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  Text('${(theme.glowIntensity * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: theme.accentColor)),
                ],
              ),
              Slider(
                value: theme.glowIntensity,
                min: 0.0,
                max: 1.0,
                activeColor: theme.accentColor,
                onChanged: (v) => theme.setGlowIntensity(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. 系统托盘与常驻设置 (macOS & Windows 桌面特性)
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('系统托盘与常驻后台', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Text('桌面原生集成', style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('关闭主窗口时最小化至系统托盘', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('关闭主窗口时不退出程序，在系统状态栏/任务栏托盘保持后台静默播放与快捷播控菜单', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _minimizeToTray,
                    activeThumbColor: theme.accentColor,
                    onChanged: (val) async {
                      setState(() {
                        _minimizeToTray = val;
                      });
                      await WindowsTrayService.instance.setMinimizeToTray(val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. 桌面悬浮动效歌词与系统级穿透置顶
        ListenableBuilder(
          listenable: DesktopFloatingLyricService.instance,
          builder: (context, _) {
            final lyricService = DesktopFloatingLyricService.instance;
            return SoftCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('桌面悬浮歌词与置顶穿透', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderPill,
                        ),
                        child: Text(Platform.isWindows ? 'Win32 原生置顶 / 穿透' : '桌面动效视窗', style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('开启桌面悬浮动效歌词', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('在桌面上浮动显示现代柔光质感双行歌词，支持鼠标拖拽与微控手柄 (Ctrl+D)', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: lyricService.isEnabled,
                        activeThumbColor: theme.accentColor,
                        onChanged: (val) => lyricService.setEnabled(val),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('主窗口始终置顶 (Always on Top)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('固定播放器窗口于屏幕最上层显示，避免被其他程序遮挡${Platform.isWindows ? ' (Win32 HWND_TOPMOST)' : ''}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: lyricService.isAlwaysOnTop,
                        activeThumbColor: theme.accentColor,
                        onChanged: (val) => lyricService.setAlwaysOnTop(val),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('锁定歌词与鼠标点击穿透 (Click-Through)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('锁定后歌词小组件进入半透明状态，鼠标点击直接透传到底层游戏或网页 (Win32 WS_EX_TRANSPARENT)', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: lyricService.isLocked,
                        activeThumbColor: theme.accentColor,
                        onChanged: (val) => lyricService.setLocked(val),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('歌词字号档位', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                          const SizedBox(height: 4),
                          Text('缩放桌面悬浮歌词的字号大小', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          {'id': 'normal', 'label': '标准'},
                          {'id': 'large', 'label': '放大'},
                          {'id': 'xlarge', 'label': '超大'},
                        ].map((item) {
                          final isSelected = lyricService.fontSizeLevel == item['id'];
                          return GestureDetector(
                            onTap: () => lyricService.setFontSizeLevel(item['id']!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.accentColor
                                    : theme.accentColor.withValues(alpha: 0.08),
                                borderRadius: MellowRadii.borderPill,
                              ),
                              child: Text(
                                item['label']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : theme.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 6. 桌面全局键盘快捷键指南
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('桌面端全局键盘快捷键', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Text('全局就绪', style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _buildShortcutChip('空格 Space', '播放 / 暂停', theme),
                  _buildShortcutChip('⌘/Ctrl + K', '全网即时搜索', theme),
                  _buildShortcutChip('⌘/Ctrl + D', '桌面悬浮歌词', theme),
                  _buildShortcutChip('← / →', '快退 / 快进 5 秒', theme),
                  _buildShortcutChip('↑ / ↓', '音量微调 ±5%', theme),
                  _buildShortcutChip('M', '一键静音切换', theme),
                  _buildShortcutChip('L', '巨幕动效歌词', theme),
                  _buildShortcutChip('Q', '待播队列抽屉', theme),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 7. 软件版本与在线更新 (Online Update)
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('软件版本与在线更新', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Text('v1.1.4 稳定版', style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mellow Music (润音) - Modern Soft UI 音乐播放器', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('支持多镜像加速、SHA256 完整性校验与无损覆盖升级', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SoftButton(
                    label: _isCheckingUpdate ? '正在检查...' : '检查新版本',
                    icon: _isCheckingUpdate ? Icons.hourglass_top_rounded : Icons.system_update_rounded,
                    isPill: true,
                    onTap: _isCheckingUpdate ? null : () => _checkUpdate(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutChip(String keyStr, String label, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.canvasColor.withValues(alpha: 0.7),
        borderRadius: MellowRadii.borderR8,
        border: Border.all(
          color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Text(
              keyStr,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11.5, color: theme.textSecondary)),
        ],
      ),
    );
  }
}

/// 11. LX 音源管理专区 (SourceManagerView)
class DesktopSourceManagerView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopSourceManagerView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return ListenableBuilder(
      listenable: LxSourceEngine.instance,
      builder: (context, _) {
        final engine = LxSourceEngine.instance;
        final allSources = engine.sources.where((s) => s.id != 'mellow' && s.id != 'lx_official_builtin').toList();
        final builtinSources = allSources.where((s) => s.isBuiltIn).toList();
        final customSources = allSources.where((s) => !s.isBuiltIn).toList();
        final enabledCount = allSources.where((s) => s.isEnabled).length;
        final effectiveDriver = (engine.activeSourceId != 'mellow' && engine.activeSourceId != 'lx_official_builtin')
            ? engine.drivers[engine.activeSourceId]
            : engine.drivers['lx_sixyin'];
        final activeName = effectiveDriver?.metadata.name ?? '落雪推荐音源 (智能调度)';

        return ListView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
          children: [
            // --- 顶部标头栏 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '音源引擎与外部脚本管理',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '支持落雪官方聚合音源、多平台直连解析与 Alger 声明式音源脚本调度',
                        style: TextStyle(fontSize: 13, color: theme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SoftButton(
                  label: '导入自定义脚本',
                  icon: Icons.add_link_rounded,
                  isPill: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ImportScriptSourceModal(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Bento 调度控制台：全局音质偏好与引擎状态 ---
            SoftCard(
              padding: const EdgeInsets.all(22),
              borderRadius: MellowRadii.borderR24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧：音质阶梯控制
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.high_quality_rounded, size: 18, color: theme.accentColor),
                                const SizedBox(width: 8),
                                Text(
                                  '全局首选音质偏好',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: AudioQuality.values.map((quality) {
                                final isSelected = engine.preferredQuality == quality;
                                return GestureDetector(
                                  onTap: () => engine.setPreferredQuality(quality),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.accentColor
                                          : theme.accentColor.withValues(alpha: 0.08),
                                      borderRadius: MellowRadii.borderPill,
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.accentColor
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          '${quality.label} · ${quality.displayName.split(' ').last}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? Colors.white : theme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '播放或下载时优先请求该音质。若音源未提供，自动沿「24bit -> FLAC -> 320K -> 128K」顺位降级回退。',
                              style: TextStyle(fontSize: 12, color: theme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // 右侧：脚本安全与状态统计
                      Expanded(
                        flex: 4,
                        child: RecessedWell(
                          padding: const EdgeInsets.all(16),
                          borderRadius: MellowRadii.borderR16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.shield_rounded, size: 16, color: Colors.green),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '脚本静态安全校验已启用',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '支持落雪规范脚本与 Alger 声明式音源配置，自动解析 API 端点进行全网音频流调度。',
                                style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('当前主音源:', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                                  Flexible(
                                    child: Text(
                                      activeName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.accentColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('音源就绪状态:', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                                  Text(
                                    '$enabledCount / ${allSources.length} 就绪',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // --- 分区 1：外部扩展与自定义脚本音源 ---
            Row(
              children: [
                Icon(Icons.extension_rounded, size: 18, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(
                  '外部自定义扩展音源 (${customSources.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '落雪社区 API 协议驱动 · 原生沙箱安全调度',
                  style: TextStyle(fontSize: 12, color: theme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (customSources.isEmpty)
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.extension_off_rounded, size: 36, color: theme.accentColor),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '暂无外部第三方音源脚本',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '点击右上角「导入自定义脚本」可订阅远程 URL 或直接粘贴脚本代码，支持落雪与 Alger API 端点解析。',
                        style: TextStyle(fontSize: 12.5, color: theme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      SoftButton(
                        label: '立即导入第三方脚本',
                        icon: Icons.add_rounded,
                        isPill: true,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const ImportScriptSourceModal(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              ...customSources.map((meta) => _buildSourceCard(context, meta, engine, theme, isCustom: true)),

            const SizedBox(height: 32),

            // --- 分区 2：官方预设多平台音源 ---
            Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, size: 18, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(
                  '官方预设与多平台音源 (${builtinSources.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '多平台音源驱动与兜底调度机制',
                  style: TextStyle(fontSize: 12, color: theme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...builtinSources.map((meta) => _buildSourceCard(context, meta, engine, theme, isCustom: false)),
          ],
        );
      },
    );
  }

  Widget _buildSourceCard(
    BuildContext context,
    LxSourceMetadata meta,
    LxSourceEngine engine,
    ThemeProvider theme, {
    required bool isCustom,
  }) {
    final isActive = engine.activeSourceId == meta.id;
    final isEnabled = meta.isEnabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(18),
        borderRadius: MellowRadii.borderR20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧图标
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCustom
                    ? Colors.purple.withValues(alpha: 0.12)
                    : theme.accentColor.withValues(alpha: 0.12),
                borderRadius: MellowRadii.borderR16,
              ),
              child: Icon(
                isCustom ? Icons.javascript_rounded : _getPlatformIcon(meta.id),
                color: isCustom ? Colors.purple : theme.accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // 中间元信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isEnabled ? theme.textPrimary : theme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 版本号
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.textMuted.withValues(alpha: 0.1),
                          borderRadius: MellowRadii.borderPill,
                        ),
                        child: Text(
                          'v${meta.version}',
                          style: TextStyle(fontSize: 11, color: theme.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 主音源徽章
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.accentColor,
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 12, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                '当前主音源',
                                style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      if (isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: const Text(
                            '原生协议驱动',
                            style: TextStyle(fontSize: 10.5, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.12),
                            borderRadius: MellowRadii.borderPill,
                          ),
                          child: Text(
                            '聚合展示 · 需落雪调度',
                            style: TextStyle(fontSize: 10.5, color: theme.accentColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  // 音质支持标签与作者信息
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '作者: ${meta.author}',
                        style: TextStyle(fontSize: 11, color: theme.textMuted),
                      ),
                      const Text('·', style: TextStyle(color: Colors.grey)),
                      ...meta.supportedQualities.map((q) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              q.label,
                              style: TextStyle(fontSize: 10, color: theme.accentColor, fontWeight: FontWeight.w600),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // 右侧操作栏
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 连通性测速按钮
                SoftButton(
                  icon: Icons.network_ping_rounded,
                  label: '测速',
                  isPill: true,
                  onTap: () async {
                    final sw = Stopwatch()..start();
                    final ok = await engine.testSourceHealth(meta.id);
                    sw.stop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? '「${meta.name}」连通正常，响应耗时: ${sw.elapsedMilliseconds}ms'
                              : '「${meta.name}」检测超时或端点未就绪'),
                          backgroundColor: ok ? Colors.teal.shade700 : Colors.redAccent.shade400,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),

                // 设为主音源按钮
                if (!isActive)
                  SoftButton(
                    label: '设为主源',
                    icon: Icons.star_border_rounded,
                    isPill: true,
                    onTap: isEnabled
                        ? () {
                            try {
                              engine.setActiveSource(meta.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('主音源已切换为「${meta.name}」')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('切换失败: $e')),
                              );
                            }
                          }
                        : null,
                  ),
                const SizedBox(width: 8),

                // 查看详情与代码
                SoftButton(
                  icon: isCustom ? Icons.code_rounded : Icons.info_outline_rounded,
                  label: isCustom ? '源码' : '详情',
                  isPill: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => ViewScriptSourceModal(metadata: meta),
                    );
                  },
                ),

                // 若为自定义音源，提供删除卸载按钮
                if (isCustom) ...[
                  const SizedBox(width: 8),
                  SoftButton(
                    icon: Icons.delete_outline_rounded,
                    isPill: true,
                    onTap: () => _confirmDeleteSource(context, meta, engine),
                  ),
                ],

                const SizedBox(width: 10),
                // 启用 / 停用 Switch 开关
                Switch.adaptive(
                  value: isEnabled,
                  activeThumbColor: theme.accentColor,
                  onChanged: (val) {
                    engine.setSourceEnabled(meta.id, val);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlatformIcon(String id) {
    switch (id) {
      case LxPlatformId.kw:
        return Icons.album_rounded;
      case LxPlatformId.kg:
        return Icons.graphic_eq_rounded;
      case LxPlatformId.tx:
        return Icons.library_music_rounded;
      case LxPlatformId.wy:
        return Icons.music_note_rounded;
      case LxPlatformId.mg:
        return Icons.radio_rounded;
      case LxPlatformId.mellow:
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Future<void> _confirmDeleteSource(
    BuildContext context,
    LxSourceMetadata meta,
    LxSourceEngine engine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('卸载自定义音源'),
        content: Text('确定要卸载并移除外部音源脚本「${meta.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认卸载'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      engine.unregisterDriver(meta.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功卸载音源「${meta.name}」')),
        );
      }
    }
  }
}


/// 12. 多端协同与云端同步中心 (DesktopSyncView)
class DesktopSyncView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopSyncView({super.key, required this.onNavigate});

  @override
  State<DesktopSyncView> createState() => _DesktopSyncViewState();
}

class _DesktopSyncViewState extends State<DesktopSyncView> {
  WebDavConfig? _config;
  bool _isSyncing = false;
  String _statusMessage = '空闲就绪';

  // 局域网近场协同服务状态
  final LanSyncService _lanService = LanSyncService.instance;
  StreamSubscription<SyncSnapshot>? _lanSnapshotSub;
  bool _isScanningLan = false;
  String? _pushingDeviceId;
  String? _lanLocalIp;
  int _lanLocalPort = 23332;
  List<LanDevice> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _initLanSync();
  }

  @override
  void dispose() {
    _lanSnapshotSub?.cancel();
    super.dispose();
  }

  Future<void> _initLanSync() async {
    try {
      final port = await _lanService.ensureServerRunning();
      final ip = await LanSyncService.getLocalIPv4();
      if (mounted) {
        setState(() {
          _lanLocalIp = ip;
          _lanLocalPort = port;
        });
      }
    } catch (_) {}

    _lanSnapshotSub = _lanService.onSnapshotReceived.listen((incoming) async {
      if (!mounted) return;
      final player = context.read<AudioPlayerService>();
      final eq = EqualizerManager.instance;
      final local = SyncSnapshot.createFromAppState(player: player, eqManager: eq);
      final merged = local.merge(incoming);
      await SyncSnapshot.applyToAppState(merged, player: player, eqManager: eq);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('收到局域网设备无线快照！已智能合并 ${merged.favorites.length} 首红心、${merged.playlists.length} 个歌单'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
        setState(() {});
      }
    });
  }

  Future<void> _scanLanDevices() async {
    if (_isScanningLan) return;
    setState(() => _isScanningLan = true);
    try {
      final ip = _lanLocalIp ?? await LanSyncService.getLocalIPv4();
      final subnet = LanSyncService.getSubnetPrefix(ip);
      final list = await _lanService.scanNetwork(subnet, port: _lanLocalPort);
      if (mounted) {
        setState(() {
          _discoveredDevices = list;
          _isScanningLan = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(list.isEmpty
                ? '扫描完成，当前网段暂未发现其他 Mellow/LX 节点'
                : '扫描完成，发现 ${list.length} 台在线协同节点'),
            backgroundColor: list.isNotEmpty ? Colors.teal.shade700 : Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningLan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('局域网扫描出错: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _openLanPairingModal() {
    showDialog(
      context: context,
      builder: (ctx) => const LanPairingModal(),
    );
  }

  Future<void> _pushToLanDevice(LanDevice device) async {
    setState(() => _pushingDeviceId = device.id);
    try {
      final player = context.read<AudioPlayerService>();
      final eq = EqualizerManager.instance;
      final snap = SyncSnapshot.createFromAppState(player: player, eqManager: eq);
      final ok = await _lanService.pushToDevice(
        device,
        snap,
        authKey: device.authKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功向「${device.name}」(${device.ip}) 投送当前曲库快照！'),
              backgroundColor: Colors.teal.shade700,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('投送失败，请确认对端设备处于前台并保持在同一局域网'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _pushingDeviceId = null);
      }
    }
  }

  void _loadConfig() {
    setState(() {
      _config = StorageService.instance.getWebDavConfig();
    });
  }

  Future<void> _openWebDavConfig() async {
    await showDialog(
      context: context,
      builder: (ctx) => WebDavConfigModal(
        initialConfig: _config,
        onSave: (savedCfg) {
          setState(() {
            _config = savedCfg;
            _statusMessage = 'WebDAV 配置已保存';
          });
        },
      ),
    );
  }

  Future<void> _triggerUpload() async {
    if (_config == null || !_config!.isConfigured) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 WebDAV 私有云盘服务器参数')),
      );
      _openWebDavConfig();
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = '正在采集本地数据快照并上传云端...';
    });

    final player = context.read<AudioPlayerService>();
    final eq = EqualizerManager.instance;
    final snapshot = SyncSnapshot.createFromAppState(player: player, eqManager: eq);

    final result = await WebDavSyncService.uploadSnapshotDirect(_config!, snapshot);

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
    });

    if (result.isSuccess) {
      final now = DateTime.now();
      setState(() {
        _statusMessage = '云端备份完成 (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')})';
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('云端备份成功！已备份 ${snapshot.favorites.length} 首红心、${snapshot.playlists.length} 个歌单'),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    } else {
      setState(() {
        _statusMessage = '云端备份失败: ${result.error}';
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('备份失败: ${result.error}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _triggerRestore() async {
    if (_config == null || !_config!.isConfigured) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 WebDAV 私有云盘服务器参数')),
      );
      _openWebDavConfig();
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = '正在连接云端拉取备份数据...';
    });

    final result = await WebDavSyncService.downloadSnapshotDirect(_config!);

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isSyncing = false;
        _statusMessage = '云端拉取失败: ${result.error ?? '未在云盘找到备份快照'}';
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('拉取失败: ${result.error ?? '云端尚未存在备份快照'}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final remoteSnapshot = result.data!;
    final player = context.read<AudioPlayerService>();
    final eq = EqualizerManager.instance;
    final localSnapshot = SyncSnapshot.createFromAppState(player: player, eqManager: eq);

    // LWW (Last-Write-Wins) 智能冲突合并
    final mergedSnapshot = localSnapshot.merge(remoteSnapshot);
    await SyncSnapshot.applyToAppState(mergedSnapshot, player: player, eqManager: eq);

    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _statusMessage = '云端恢复并合并成功 (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})';
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('云端数据恢复完成！现保留 ${mergedSnapshot.favorites.length} 首红心收藏、${mergedSnapshot.playlists.length} 个歌单及 10 频段 EQ 设置'),
        backgroundColor: Colors.teal.shade700,
      ),
    );
  }

  void _openExportModal() {
    showDialog(
      context: context,
      builder: (ctx) => const ExportSnapshotModal(),
    );
  }

  void _openImportModal() {
    showDialog(
      context: context,
      builder: (ctx) => const ImportSnapshotModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final favCount = player.favoriteTracks.length;
    final playlistCount = player.importedPlaylists.length;
    final historyCount = player.playHistory.length;
    final isWebDavConfigured = _config?.isConfigured ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            final titleWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('多端协同与云端同步中心', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('支持 WebDAV 私有云盘实时双向热备，与免网络环境全量 JSON 快照流转', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            );
            final actionsWidget = Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SoftButton(
                  label: '离线快照迁移',
                  icon: Icons.swap_horiz_rounded,
                  onTap: _openExportModal,
                ),
                SoftButton(
                  label: _isSyncing ? '同步传输中...' : '立即云端备份',
                  icon: Icons.cloud_upload_rounded,
                  isActive: true,
                  isPill: true,
                  onTap: _isSyncing ? null : _triggerUpload,
                ),
              ],
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 14),
                  actionsWidget,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleWidget),
                const SizedBox(width: 16),
                actionsWidget,
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // 数据健康度指标卡
        Row(
          children: [
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(20),
                borderRadius: MellowRadii.borderR20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.pink.withValues(alpha: 0.15),
                        borderRadius: MellowRadii.borderR12,
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$favCount 首', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        Text('本地红心收藏', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(20),
                borderRadius: MellowRadii.borderR20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.15),
                        borderRadius: MellowRadii.borderR12,
                      ),
                      child: Icon(Icons.queue_music_rounded, color: theme.accentColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$playlistCount 个', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        Text('自建与导入歌单', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(20),
                borderRadius: MellowRadii.borderR20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: MellowRadii.borderR12,
                      ),
                      child: const Icon(Icons.history_rounded, color: Colors.amber, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$historyCount 条', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        Text('播放足迹历史', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 模块 1: WebDAV 云端备份与还原
        SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 840;
                  final leftWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderR12,
                        ),
                        child: Icon(Icons.cloud_sync_rounded, color: theme.accentColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WebDAV 私有云盘热备', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                            Text('兼容标准 WebDAV 协议（坚果云、Nextcloud、群晖 NAS、Alist 等）', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  );

                  final rightWidget = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWebDavConfigured ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isWebDavConfigured ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 14,
                              color: isWebDavConfigured ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isWebDavConfigured ? '已配置就绪' : '待配置',
                              style: TextStyle(
                                color: isWebDavConfigured ? Colors.green : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SoftButton(
                        label: '配置服务器',
                        icon: Icons.tune_rounded,
                        onTap: _openWebDavConfig,
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftWidget,
                        const SizedBox(height: 12),
                        rightWidget,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: leftWidget),
                      const SizedBox(width: 16),
                      rightWidget,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              RecessedWell(
                padding: const EdgeInsets.all(16),
                borderRadius: MellowRadii.borderR16,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('云端端点: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                              Flexible(
                                child: Text(
                                  isWebDavConfigured ? _config!.serverUrl : '未设置云端服务器端点',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('绑定账号: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                              Text(
                                isWebDavConfigured ? _config!.username : '未绑定',
                                style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Text('当前状态: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                              Text(
                                _statusMessage,
                                style: TextStyle(fontSize: 12.5, color: theme.accentColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SoftButton(
                      label: '从云端恢复',
                      icon: Icons.cloud_download_rounded,
                      isPill: true,
                      onTap: _isSyncing ? null : _triggerRestore,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 模块 2: 离线快照迁移与灾备（免网络环境）
        SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 840;
                  final leftWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderR12,
                        ),
                        child: const Icon(Icons.file_copy_rounded, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('离线快照迁移与灾备（无网络环境）', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                            Text('将收藏、自建歌单、历史足迹及 10 频段 EQ 导为 JSON 纯文本，秒级还原与合并', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  );

                  final rightWidget = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SoftButton(
                        label: '导出快照 JSON',
                        icon: Icons.file_upload_outlined,
                        onTap: _openExportModal,
                      ),
                      SoftButton(
                        label: '导入快照合并',
                        icon: Icons.file_download_outlined,
                        onTap: _openImportModal,
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftWidget,
                        const SizedBox(height: 12),
                        rightWidget,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: leftWidget),
                      const SizedBox(width: 16),
                      rightWidget,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 模块 3: 局域网近场协同流转 (LAN P2P)
        SoftCard(
          padding: const EdgeInsets.all(24),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 1020;
                  final titleWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderR12,
                        ),
                        child: const Icon(Icons.hub_rounded, color: Colors.indigoAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('局域网近场设备协同 (LAN P2P)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                            Text('同一 Wi-Fi 局域网下免公网服务器，自动发现与双向近场快传', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  );

                  final actionsWidget = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_tethering_rounded, size: 14, color: Colors.teal),
                            const SizedBox(width: 5),
                            Text(
                              '本机 · ${_lanService.localOsName} (${_lanService.localDeviceTypeName}) : ${_lanLocalIp ?? '127.0.0.1'}:$_lanLocalPort',
                              style: const TextStyle(color: Colors.teal, fontSize: 11.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SoftButton(
                        label: '配对码与手动直连',
                        icon: Icons.qr_code_rounded,
                        onTap: _openLanPairingModal,
                      ),
                      SoftButton(
                        label: _isScanningLan ? '正在雷达扫描...' : '扫描局域网节点',
                        icon: Icons.radar_rounded,
                        isActive: true,
                        isPill: true,
                        onTap: _isScanningLan ? null : _scanLanDevices,
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 14),
                        actionsWidget,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleWidget),
                      const SizedBox(width: 16),
                      actionsWidget,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '在线协同节点 (${_discoveredDevices.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary),
                  ),
                  if (_lanService.serverAuthKey.isNotEmpty)
                    Text(
                      '本机配对密钥: ${_lanService.serverAuthKey}',
                      style: TextStyle(fontSize: 11.5, color: theme.textMuted, fontFamily: 'monospace'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_discoveredDevices.isEmpty)
                RecessedWell(
                  padding: const EdgeInsets.all(20),
                  borderRadius: MellowRadii.borderR16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.12),
                          borderRadius: MellowRadii.borderR12,
                        ),
                        child: Icon(Icons.wifi_find_rounded, color: theme.accentColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '近场广播监听已启动，等待同网段设备连接',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '当前节点开放局域网 P2P 快照协议通道（${_lanLocalIp ?? '127.0.0.1'}:$_lanLocalPort）。点击右上角「扫描局域网节点」雷达探测，或使用「配对码与手动直连」扫码投送。',
                              style: TextStyle(fontSize: 12, color: theme.textMuted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (final dev in _discoveredDevices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SoftCard(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          borderRadius: MellowRadii.borderR16,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: dev.osBrandColor.withValues(alpha: 0.14),
                                  borderRadius: MellowRadii.borderR12,
                                ),
                                child: Icon(
                                  dev.deviceIcon,
                                  color: dev.osBrandColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          dev.name,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary),
                                        ),
                                        const SizedBox(width: 8),
                                        // 操作系统专属品牌徽章
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: dev.osBrandColor.withValues(alpha: 0.16),
                                            borderRadius: MellowRadii.borderPill,
                                            border: Border.all(
                                              color: dev.osBrandColor.withValues(alpha: 0.35),
                                              width: 0.6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                dev.displayOsName == 'Windows'
                                                    ? Icons.window_rounded
                                                    : (dev.displayOsName == 'macOS'
                                                        ? Icons.apple_rounded
                                                        : (dev.displayOsName == 'Android'
                                                            ? Icons.android_rounded
                                                            : Icons.devices_rounded)),
                                                size: 11,
                                                color: dev.osBrandColor,
                                              ),
                                              const SizedBox(width: 3.5),
                                              Text(
                                                dev.displayOsName,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: dev.osBrandColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // 设备形态微标签
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.canvasColor,
                                            borderRadius: MellowRadii.borderPill,
                                            border: Border.all(
                                              color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            dev.displayDeviceTypeName,
                                            style: TextStyle(fontSize: 10, color: theme.textMuted),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // 版本号
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.canvasColor,
                                            borderRadius: MellowRadii.borderPill,
                                          ),
                                          child: Text(
                                            'v${dev.version}',
                                            style: TextStyle(fontSize: 10, color: theme.textMuted.withValues(alpha: 0.8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '端点: ${dev.ip}:${dev.port} · 节点ID: ${dev.id}',
                                      style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              SoftButton(
                                label: _pushingDeviceId == dev.id ? '正在投送...' : '无线投送曲库',
                                icon: Icons.send_rounded,
                                isActive: true,
                                isPill: true,
                                onTap: _pushingDeviceId != null ? null : () => _pushToLanDevice(dev),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
