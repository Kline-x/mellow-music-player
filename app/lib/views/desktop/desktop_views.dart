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
import '../../core/audio/track_model.dart';
import '../../core/audio/windows_tray_service.dart';
import '../../core/audio/equalizer_manager.dart';
import '../../core/sources/online_music_service.dart';
import '../../core/sources/lx_source_model.dart';
import '../../core/sources/lx_script_sandbox.dart';
import '../../core/sync/webdav_sync_service.dart';
import '../../core/sync/sync_data_model.dart';
import '../../core/sync/lan_sync_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/window/desktop_floating_lyric_service.dart';
import '../common/modals.dart';

/// 1. 发现音乐主页 (DiscoverView - Bento Grid 仪表盘)
class DesktopDiscoverView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopDiscoverView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
                            if (player.playlist.isNotEmpty) {
                              player.playTrack(player.playlist[0]);
                            }
                          },
                        ),
                        SoftButton(
                          label: '查看完整推荐',
                          icon: Icons.explore_outlined,
                          isPill: true,
                          onTap: () => onNavigate('playlists'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // 封面微浮雕
              MellowImage(
                url: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
                width: 150,
                height: 150,
                borderRadius: MellowRadii.borderR20,
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
              onPressed: () => onNavigate('playlists'),
              child: Text('查看全部 >', style: TextStyle(color: theme.accentColor)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 推荐歌单网格 (自适应多分辨率列数，宽屏优雅延展)
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 220).floor().clamp(2, 4);
            final curatedPlaylists = [
              {
                'title': '东方禅境 · 幽篁古筝琴韵精选',
                'sub': '48.6万播放 · 巫娜 / 常静',
                'cover': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
                'tracks': mockWuNaTracks,
              },
              {
                'title': '夜幕降临时的华语流行浪漫',
                'sub': '129.4万播放 · 周杰伦 / 伯远',
                'cover': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
                'tracks': mockJayChouTracks,
              },
              {
                'title': '岁月如歌 · 粤语传世经典不朽巡礼',
                'sub': '98.2万播放 · Beyond / 传奇殿堂',
                'cover': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
                'tracks': mockBeyondTracks,
              },
              {
                'title': '原创独立先锋 · 诗意民谣声线',
                'sub': '45.1万播放 · 独立音乐人代表作',
                'cover': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
                'tracks': toplistOriginTracks,
              },
            ];
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.82,
              ),
              itemCount: curatedPlaylists.length,
              itemBuilder: (context, idx) {
                final pl = curatedPlaylists[idx];
                return _buildPlaylistCard(
                  context,
                  pl['title'] as String,
                  pl['sub'] as String,
                  pl['cover'] as String,
                  () => player.playPlaylist(pl['tracks'] as List<Track>, startIndex: 0),
                );
              },
            );
          },
        ),
        const SizedBox(height: 32),

        // 热门歌手推荐环 (统一从 mockArtistsProfiles 读取，Wrap 优雅聚拢避免宽屏过大空白)
        Text(
          '热门入驻与关注歌手',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: theme.textPrimary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: mockArtistsProfiles.map((a) {
            return _buildArtistAvatar(
              context,
              a.name,
              a.role.split('/')[0].trim(),
              a.avatarUrl,
              () => onNavigate('artist_detail', '${a.id}:::${a.name}:::${a.avatarUrl}'),
            );
          }).toList(),
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
  final List<String> _tags = ['精选推荐', '华语流行', '沉静治愈', '古风雅乐', '经典粤语', '深夜爵士', '纯音乐'];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final playlists = getPlaylistsByTag(_activeTag);

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('歌单广场', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            Text('发现属于你的音乐磁场', style: TextStyle(fontSize: 13, color: theme.textMuted)),
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
                  onTap: () => setState(() => _activeTag = tag),
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
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.80,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, idx) {
            final pl = playlists[idx];
            return SoftCard(
              padding: const EdgeInsets.all(12),
              onTap: () {
                if (pl.tracks.isNotEmpty) {
                  player.playPlaylist(pl.tracks, startIndex: 0);
                }
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
                    '${pl.desc} · 共${pl.tracks.length}首',
                    style: TextStyle(fontSize: 11.5, color: theme.textMuted),
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
    final tracks = await OnlineMusicService.fetchToplistTracks(chartId.isNotEmpty ? chartId : chartName, limit: 50);
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

    final coreCharts = [
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

    final filteredList = _filteredToplists;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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

        // 1. 四大核心官方权威榜单 (响应式自适应：超宽屏4列并行，常规屏2列，紧凑屏1列)
        LayoutBuilder(
          builder: (context, constraints) {
            final isUltraWide = constraints.maxWidth >= 1440;
            final isNarrow = constraints.maxWidth < 720;
            final crossAxisCount = isUltraWide ? 4 : (isNarrow ? 1 : 2);
            final childAspectRatio = isUltraWide ? 1.55 : (isNarrow ? 2.8 : 2.3);
            final bannerWidth = isUltraWide ? 118.0 : 138.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: coreCharts.length,
              itemBuilder: (context, idx) {
            final c = coreCharts[idx];
            final gradientColors = c['gradient'] as List<Color>;
            final iconData = c['icon'] as IconData;
            final chartTitle = c['title'] as String;
            final chartTracks = _liveToplists[chartTitle] ?? toplistTracksMap[chartTitle] ?? mockPresetTracks;

            return SoftCard(
              padding: const EdgeInsets.all(12),
              borderRadius: MellowRadii.borderR20,
              onTap: () {
                if (chartTracks.isNotEmpty) {
                  player.playPlaylist(chartTracks, startIndex: 0);
                }
              },
              child: Row(
                children: [
                  Container(
                    width: bannerWidth,
                    height: double.infinity,
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
                          right: -10,
                          bottom: -10,
                          child: Icon(iconData, size: isUltraWide ? 64 : 76, color: Colors.white.withValues(alpha: 0.16)),
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
                                    style: TextStyle(
                                      fontSize: isUltraWide ? 18 : 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c['update'] as String,
                                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.82)),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.92),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.play_arrow_rounded, color: gradientColors[0], size: 20),
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
                onTap: () => _playChart(c),
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
  List<ArtistProfile> _artists = [];
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
    _artists = mockArtistsProfiles;
    _loadArtists(area: _selectedArea, type: _selectedType);
  }

  void _loadArtists({required int area, required int type}) async {
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
          fans: '${(musicSize * 15.6 + 68).toInt()}万',
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
                  const SizedBox(height: 6),
                  Text('粉丝 ${a.fans}', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
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
  bool _isFollowing = true;
  bool _isLoadingTracks = false;
  int _selectedTab = 0; // 0: 热门代表作 (Top 50), 1: 全部作品 (全量曲库)
  List<Track> _topTracks = [];
  List<Track> _allTracks = [];
  int _totalSongCount = 0;
  int _albumCount = 0;
  bool _isLoadingMore = false;
  bool _hasMoreAllSongs = true;
  int _allSongsOffset = 0;
  String _artistBio = '';
  String _artistId = '';
  String _artistName = '';
  String _artistAvatar = '';

  @override
  void initState() {
    super.initState();
    _parseParamsAndLoad();
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
        setState(() {
          _allTracks.addAll(newTracks);
          if (total > 0) _totalSongCount = total;
          _hasMoreAllSongs = more && newTracks.isNotEmpty;
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
                          onTap: () => setState(() => _isFollowing = !_isFollowing),
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
                    onPressed: () => player.toggleFavorite(t.id),
                  ),
                ],
              ),
            );
          }),

        // 底部引导或分页按钮
        if (_selectedTab == 0 && _totalSongCount > _topTracks.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SoftButton(
                label: '查看该歌手全部 $_totalSongCount 首作品 >',
                icon: Icons.library_music_rounded,
                isPill: true,
                onTap: () => _switchTab(1),
              ),
            ),
          ),
        if (_selectedTab == 1 && _hasMoreAllSongs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SoftButton(
                label: _isLoadingMore ? '正在加载更多曲目...' : '加载更多作品 (已载入 ${_allTracks.length} / 共 $_totalSongCount 首)',
                icon: _isLoadingMore ? null : Icons.arrow_downward_rounded,
                isPill: true,
                onTap: _loadMoreAllSongs,
              ),
            ),
          )
        else if (_selectedTab == 1 && _allTracks.isNotEmpty)
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
    final radios = mockRadioStations;

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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
  final String? emptyMessage;

  const DesktopSongTableView({
    super.key,
    required this.tracks,
    this.onTrackTap,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
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
              // 数据行
              ...tracks.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final t = entry.value;
                final isPlaying = player.currentTrack?.id == t.id;

                return _DesktopSongTableRow(
                  index: idx,
                  track: t,
                  isPlaying: isPlaying,
                  showAlbum: showAlbum,
                  onTap: () => onTrackTap != null ? onTrackTap!(t) : player.playTrack(t),
                  onFavoriteToggle: () => player.toggleFavorite(t.id, t),
                  isFavorite: player.isFavorite(t.id),
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
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final bool isFavorite;

  const _DesktopSongTableRow({
    required this.index,
    required this.track,
    required this.isPlaying,
    this.showAlbum = true,
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
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
                        : Text(
                            widget.index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textMuted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          )),
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
class DesktopHistoryView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopHistoryView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
                Text('已记录最近 ${player.playHistory.length} 首曲目 · 真实本地存储', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            if (player.playHistory.isNotEmpty)
              SoftButton(
                label: '清空足迹',
                icon: Icons.delete_sweep_rounded,
                isPill: true,
                onTap: () {
                  player.clearPlayHistory();
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
          tracks: player.playHistory,
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
    final textController = TextEditingController(text: 'E:\\Music');
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
                hintText: '输入文件夹绝对路径，如 C:\\Users\\Music',
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
                  onPressed: () => textController.text = 'C:\\Users\\Public\\Music',
                ),
                ActionChip(
                  label: const Text('示例演示目录', style: TextStyle(fontSize: 11)),
                  onPressed: () => textController.text = 'E:\\Music\\Lossless',
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
                final count = await player.scanLocalDirectory(path);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(count > 0 ? '扫描完成！成功载入 $count 首本地歌曲' : '扫描完成，未发现新支持的音频文件或目录不存在'),
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
                      label: '温润白瓷 (Light)',
                      icon: Icons.light_mode_rounded,
                      isActive: !isDark,
                      onTap: () => theme.setDarkMode(false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SoftButton(
                      label: '深石墨夜间 (Dark)',
                      icon: Icons.dark_mode_rounded,
                      isActive: isDark,
                      onTap: () => theme.setDarkMode(true),
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

        // 4. 系统托盘与常驻设置 (Windows & Desktop 特性)
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
                    child: Text('Windows 原生集成', style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
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
                        Text('关闭主窗口时最小化至托盘', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('点击窗口右上角关闭按钮时不退出程序，在系统托盘保持后台静默播放与快捷菜单控制', style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
                        child: Text('Win32 原生置顶 / 穿透', style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
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
                            Text('固定播放器窗口于屏幕最上层显示，避免被其他程序遮挡 (Win32 HWND_TOPMOST)', style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
                  _buildShortcutChip('ESC', '退出全屏 / 关闭抽屉', theme),
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
        final allSources = engine.sources;
        final builtinSources = allSources.where((s) => s.isBuiltIn).toList();
        final customSources = allSources.where((s) => !s.isBuiltIn).toList();
        final enabledCount = allSources.where((s) => s.isEnabled).length;
        final activeDriver = engine.drivers[engine.activeSourceId];
        final activeName = activeDriver?.metadata.name ?? engine.activeSourceId;

        return ListView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
                        '平台直连音源解析与音质阶梯降级；外部脚本仅解析注释头元数据，脚本代码不会被执行',
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
                                '导入脚本仅做危险模式正则扫描与注释头解析，脚本代码不会被加载或执行。',
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
                  '仅解析注释头元数据 · 不执行 JS 代码',
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
                        '点击右上角「导入自定义脚本」可订阅 URL 或粘贴脚本：仅登记注释头元数据，脚本代码不会被执行',
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
                  '覆盖国内主流六大音乐平台高保真音源驱动',
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
                            '元数据挂载',
                            style: TextStyle(fontSize: 10.5, color: Colors.green, fontWeight: FontWeight.bold),
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
        authKey: _lanService.serverAuthKey,
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
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
                  final isCompact = constraints.maxWidth < 840;
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
                              '服务监听中: ${_lanLocalIp ?? '127.0.0.1'}:$_lanLocalPort',
                              style: const TextStyle(color: Colors.teal, fontSize: 11.5, fontWeight: FontWeight.bold),
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
                                  color: theme.accentColor.withValues(alpha: 0.12),
                                  borderRadius: MellowRadii.borderR12,
                                ),
                                child: Icon(
                                  dev.name.toLowerCase().contains('phone') || dev.name.toLowerCase().contains('android') || dev.name.toLowerCase().contains('ios')
                                      ? Icons.phone_android_rounded
                                      : Icons.laptop_chromebook_rounded,
                                  color: theme.accentColor,
                                  size: 24,
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.canvasColor,
                                            borderRadius: MellowRadii.borderPill,
                                            border: Border.all(
                                              color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            'v${dev.version}',
                                            style: TextStyle(fontSize: 10, color: theme.textMuted),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
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
