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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
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
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.82,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildPlaylistCard(
              context,
              '东方禅境 · 幽篁古筝琴韵精选',
              '48.6万播放 · 巫娜 / 常静',
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
              () => player.playPlaylist(mockWuNaTracks, startIndex: 0),
            ),
            _buildPlaylistCard(
              context,
              '夜幕降临时的华语流行浪漫',
              '129.4万播放 · 周杰伦 / 伯远',
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
              () => player.playPlaylist(mockJayChouTracks, startIndex: 0),
            ),
            _buildPlaylistCard(
              context,
              '岁月如歌 · 粤语传世经典不朽巡礼',
              '98.2万播放 · Beyond / 传奇殿堂',
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
              () => player.playPlaylist(mockBeyondTracks, startIndex: 0),
            ),
            _buildPlaylistCard(
              context,
              '原创独立先锋 · 诗意民谣声线',
              '45.1万播放 · 独立音乐人代表作',
              'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
              () => player.playPlaylist(toplistOriginTracks, startIndex: 0),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // 热门歌手推荐环 (统一从 mockArtistsProfiles 单点源读取)
        Text(
          '热门入驻与关注歌手',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: theme.textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: mockArtistsProfiles.map((a) {
            return _buildArtistAvatar(
              context,
              a.name,
              a.role.split('/')[0].trim(),
              a.avatarUrl,
              () => onNavigate('artist_detail', a.name),
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.82,
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

/// 3. 官方巅峰榜 (ToplistView)
class DesktopToplistView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopToplistView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final charts = [
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                final allTracks = getAllToplistTracks();
                if (allTracks.isNotEmpty) {
                  player.playPlaylist(allTracks);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 2.25,
          ),
          itemCount: charts.length,
          itemBuilder: (context, idx) {
            final c = charts[idx];
            final gradientColors = c['gradient'] as List<Color>;
            final iconData = c['icon'] as IconData;
            final chartTitle = c['title'] as String;
            final chartTracks = toplistTracksMap[chartTitle] ?? mockPresetTracks;

            return SoftCard(
              padding: const EdgeInsets.all(14),
              borderRadius: MellowRadii.borderR20,
              onTap: () {
                if (chartTracks.isNotEmpty) {
                  player.playPlaylist(chartTracks, startIndex: 0);
                }
              },
              child: Row(
                children: [
                  // 左侧艺术声学渐变封面
                  Container(
                    width: 146,
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
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
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
                                  width: 32,
                                  height: 32,
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
                                  child: Icon(Icons.play_arrow_rounded, color: gradientColors[0], size: 22),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 右侧 Top 5 精选歌曲紧凑排行榜
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
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: rank <= 3 ? FontWeight.w900 : FontWeight.bold,
                                      color: rankColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    t.title,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: rank <= 3 ? FontWeight.w600 : FontWeight.normal,
                                      color: theme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.artist,
                                  style: TextStyle(fontSize: 11, color: theme.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 16,
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
        ),
      ],
    );
  }
}

/// 4. 热门歌手库与歌手详情 (Artists & ArtistDetail)
class DesktopArtistsView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopArtistsView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final artists = mockArtistsProfiles;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Text('热门歌手库', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: artists.length,
          itemBuilder: (context, idx) {
            final a = artists[idx];
            return SoftCard(
              padding: const EdgeInsets.all(16),
              onTap: () => onNavigate('artist_detail', a.name),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MellowAvatar(radius: 46, url: a.avatarUrl),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 16, color: theme.accentColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a.role, style: TextStyle(fontSize: 11.5, color: theme.textMuted), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
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

/// 5. 歌手详情页 (DesktopArtistDetailView)
class DesktopArtistDetailView extends StatefulWidget {
  final String artistName;
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopArtistDetailView({super.key, required this.artistName, required this.onNavigate});

  @override
  State<DesktopArtistDetailView> createState() => _DesktopArtistDetailViewState();
}

class _DesktopArtistDetailViewState extends State<DesktopArtistDetailView> {
  bool _isFollowing = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final artist = getArtistProfileByName(widget.artistName);

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
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
                url: artist.avatarUrl,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(artist.name, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        const SizedBox(width: 8),
                        Icon(Icons.verified_rounded, color: theme.accentColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(artist.bio, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
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
                          onTap: () {
                            if (artist.tracks.isNotEmpty) {
                              player.playPlaylist(artist.tracks, startIndex: 0);
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
        Text('代表作列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 12),
        ...List.generate(artist.tracks.length, (idx) {
          final t = artist.tracks[idx];
          return SoftCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: () => player.playPlaylist(artist.tracks, startIndex: idx),
            child: Row(
              children: [
                MellowImage(url: t.coverUrl, width: 40, height: 40, borderRadius: MellowRadii.borderR8),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    ],
                  ),
                ),
                Text(t.formattedDuration, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.pink, size: 20),
                  onPressed: () => player.toggleFavorite(t.id),
                ),
              ],
            ),
          );
        }),
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Text('声音电台专区', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
          ),
          itemCount: radios.length,
          itemBuilder: (context, idx) {
            final r = radios[idx];
            return SoftCard(
              padding: const EdgeInsets.all(16),
              onTap: () {
                player.playTrack(r.track);
              },
              child: Row(
                children: [
                  MellowImage(url: r.coverUrl, width: 90, height: 90, borderRadius: MellowRadii.borderR16),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(r.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(r.sub, style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        const SizedBox(height: 6),
                        Text(r.listeners, style: TextStyle(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Icon(Icons.radio_rounded, color: theme.accentColor, size: 28),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 7. 我喜欢的音乐 (FavoriteView)
class DesktopFavoriteView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopFavoriteView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final favTracks = player.favoriteTracks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        SoftCard(
          padding: const EdgeInsets.all(28),
          borderRadius: MellowRadii.borderR24,
          child: Row(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF472B6)]),
                  borderRadius: MellowRadii.borderR24,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我喜欢的音乐', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  const SizedBox(height: 6),
                  Text('共收藏 ${favTracks.length} 首心动单曲 · 本地安全持久化存储', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 14),
                  Row(
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
                      const SizedBox(width: 10),
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
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (favTracks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.favorite_border_rounded, size: 48, color: theme.textMuted),
                  const SizedBox(height: 12),
                  Text('暂无收藏曲目，在播放或搜索时点击红心即可收入心动歌单', style: TextStyle(color: theme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          for (final t in favTracks)
            SoftCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => player.playTrack(t),
              child: Row(
                children: [
                  MellowImage(url: t.coverUrl, width: 42, height: 42, borderRadius: MellowRadii.borderR8),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                      ],
                    ),
                  ),
                  Text(t.formattedDuration, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 20),
                    tooltip: '取消收藏',
                    onPressed: () => player.toggleFavorite(t.id, t),
                  ),
                ],
              ),
            ),
      ],
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导入与自建歌单', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('管理自建精选集，或一键导入网易云音乐、QQ音乐分享链接与公开歌单', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            Row(
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
                const SizedBox(width: 10),
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
                const SizedBox(width: 10),
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
                            Text('包含 ${pl.trackCount} 首完整音轨 · ${pl.description}', style: TextStyle(fontSize: 12.5, color: theme.textMuted)),
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        if (player.playHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history_rounded, size: 56, color: theme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('暂无播放历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  const SizedBox(height: 6),
                  Text('在发现页、榜单或搜索播放音乐，足迹将自动安全记录在此', style: TextStyle(fontSize: 13, color: theme.textMuted)),
                ],
              ),
            ),
          )
        else
          ...player.playHistory.map((t) => SoftCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: () => player.playTrack(t),
            child: Row(
              children: [
                MellowImage(url: t.coverUrl, width: 40, height: 40, borderRadius: MellowRadii.borderR8),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    ],
                  ),
                ),
                Text(t.formattedDuration, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
              ],
            ),
          )),
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
        backgroundColor: theme.surfaceColor,
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
                border: OutlineInputBorder(borderRadius: MellowRadii.borderM, borderSide: BorderSide(color: theme.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: MellowRadii.borderM, borderSide: BorderSide(color: theme.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: MellowRadii.borderM, borderSide: BorderSide(color: theme.accentColor)),
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        // 1. 顶部标题栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地与离线下载', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('支持 FLAC / WAV / MP3 / OGG 无损音频直接声卡解码回放', style: TextStyle(color: theme.textMuted, fontSize: 13)),
              ],
            ),
            Row(
              children: [
                if (localTracks.isNotEmpty) ...[
                  SoftButton(
                    label: '播放全部',
                    icon: Icons.play_arrow_rounded,
                    isPill: true,
                    onTap: () => player.playLocalMusic(),
                  ),
                  const SizedBox(width: 10),
                  SoftButton(
                    label: '清空曲库',
                    icon: Icons.delete_sweep_rounded,
                    isPill: true,
                    onTap: () => player.clearLocalTracks(),
                  ),
                  const SizedBox(width: 10),
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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final track = localTracks[index];
              final isCurrent = player.currentTrack?.id == track.id;

              return SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: MellowRadii.borderM,
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
                            color: player.isFavorite(track.id) ? Colors.rose : theme.textMuted,
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
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
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
                    activeColor: theme.accentColor,
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

        // 5. 桌面全局键盘快捷键指南
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
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.borderColor),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('自定义音源管理', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                Text('支持扩展音源解析脚本（功能接入中）', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            SoftButton(
              label: '在线导入音源',
              icon: Icons.add_link_rounded,
              isPill: true,
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('自定义音源在线导入功能接入中...')),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.accentColor.withValues(alpha: 0.15), borderRadius: MellowRadii.borderR16),
                child: Icon(Icons.source_rounded, color: theme.accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('网易云在线开放音源 (Built-in)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('支持在线搜索与公开歌单导入解析', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
  final String _syncStatusText = '未配置';
  final String _serverUrl = '未配置端点 (例如 https://dav.jianguoyun.com/dav/)';
  final String _username = '未绑定账号';

  void _triggerUpload() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('云端同步功能尚未完整接入，请勿依赖此页面备份数据')),
    );
  }

  void _triggerRestore() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('云端恢复功能尚未完整接入')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    final favCount = player.favoriteTracks.length;
    final playlistCount = player.importedPlaylists.length;
    final historyCount = player.playHistory.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('多端协同与云端同步中心', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('支持 WebDAV 私有云盘实时双向热备，与局域网近场毫秒级 P2P 跨端流转', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            SoftButton(
              label: '立即云端备份',
              icon: Icons.cloud_upload_rounded,
              isActive: true,
              isPill: true,
              onTap: _triggerUpload,
            ),
          ],
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
                        child: Icon(Icons.cloud_sync_rounded, color: theme.accentColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WebDAV 私有云盘同步', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          Text('支持标准 WebDAV 协议（功能接入中）', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('待配置', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
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
                              Text(_serverUrl, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('绑定账号: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                              Text(_username, style: TextStyle(fontSize: 12.5, color: theme.textSecondary)),
                              const SizedBox(width: 16),
                              Text('状态: ', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                              Text(_syncStatusText, style: TextStyle(fontSize: 12.5, color: theme.accentColor, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SoftButton(
                      label: '从云端恢复',
                      icon: Icons.cloud_download_rounded,
                      isPill: true,
                      onTap: _triggerRestore,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 模块 2: 局域网近场协同流转 (LAN P2P)
        SoftCard(
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
                          color: Colors.indigoAccent.withValues(alpha: 0.15),
                          borderRadius: MellowRadii.borderR12,
                        ),
                        child: const Icon(Icons.hub_rounded, color: Colors.indigoAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('局域网近场设备协同 (LAN P2P)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          Text('同一 Wi-Fi 下设备近场流转与歌单互传（功能接入中）', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('局域网在线设备', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              const SizedBox(height: 10),

              // 设备列表空状态卡片
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.devices_other_rounded, color: theme.textMuted, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('当前未发现局域网配对设备', style: TextStyle(fontWeight: FontWeight.w600, color: theme.textPrimary)),
                          const SizedBox(height: 2),
                          Text('局域网近场 P2P 互联功能接入中，支持设备自动发现与歌曲互传', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
