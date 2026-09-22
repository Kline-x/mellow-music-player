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
                        Text(
                          '根据您常听的古风与经典流行智能漫游',
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
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
                      '精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出，实时声学生态律动',
                      style: TextStyle(fontSize: 13.5, color: theme.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Row(
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
                        const SizedBox(width: 12),
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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildPlaylistCard(
              context,
              '东方禅境 · 幽篁古筝琴韵精选',
              '48.6万播放 · 巫娜 / 常静',
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
              () => player.playTrack(mockPresetTracks[0]),
            ),
            _buildPlaylistCard(
              context,
              '夜幕降临时的华语流行浪漫',
              '129.4万播放 · 周杰伦 / 伯远',
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
              () => player.playTrack(mockPresetTracks[1]),
            ),
            _buildPlaylistCard(
              context,
              '岁月如歌 · 粤语传世经典不朽巡礼',
              '98.2万播放 · Beyond / 张国荣',
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
              () => player.playTrack(mockPresetTracks[2]),
            ),
            _buildPlaylistCard(
              context,
              '深夜微醺爵士 · 复古胶片呢喃',
              '34.1万播放 · La La Land OST',
              'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
              () => player.playTrack(mockPresetTracks[4]),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // 热门歌手推荐环
        Text(
          '热门入驻与关注歌手',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: theme.textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildArtistAvatar(context, '巫娜', '古琴演奏家', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80', () => onNavigate('artist_detail', '巫娜')),
            _buildArtistAvatar(context, '周杰伦', '华语流行天王', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&q=80', () => onNavigate('artist_detail', '周杰伦')),
            _buildArtistAvatar(context, 'Beyond', '传奇摇滚乐队', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&q=80', () => onNavigate('artist_detail', 'Beyond')),
            _buildArtistAvatar(context, '伯远', '新锐流行歌手', 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&q=80', () => onNavigate('artist_detail', '伯远')),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaylistCard(BuildContext context, String title, String sub, String img, VoidCallback onPlay) {
    final theme = context.watch<ThemeProvider>();
    return SoftCard(
      padding: const EdgeInsets.all(12),
      onTap: onPlay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                MellowImage(url: img, width: double.infinity, height: double.infinity, borderRadius: MellowRadii.borderR16),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
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
            childAspectRatio: 0.85,
          ),
          itemCount: mockPresetTracks.length,
          itemBuilder: (context, idx) {
            final t = mockPresetTracks[idx];
            return SoftCard(
              padding: const EdgeInsets.all(12),
              onTap: () => player.playTrack(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MellowImage(url: t.coverUrl, width: double.infinity, height: double.infinity, borderRadius: MellowRadii.borderR16),
                  ),
                  const SizedBox(height: 10),
                  Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                  Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
                if (mockPresetTracks.isNotEmpty) {
                  player.playPlaylist(mockPresetTracks);
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

            return SoftCard(
              padding: const EdgeInsets.all(14),
              borderRadius: MellowRadii.borderR20,
              onTap: () {
                if (mockPresetTracks.isNotEmpty) {
                  player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);
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
                      children: List.generate(5, (i) {
                        final trackIndex = (idx * 3 + i) % mockPresetTracks.length;
                        final t = mockPresetTracks[trackIndex];
                        final rank = i + 1;
                        final Color rankColor = rank == 1
                            ? const Color(0xFFFFB800)
                            : rank == 2
                                ? const Color(0xFF94A3B8)
                                : rank == 3
                                    ? const Color(0xFFCD7F32)
                                    : theme.textMuted;

                        return InkWell(
                          onTap: () => player.playTrack(t),
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
    final artists = [
      {'name': '巫娜', 'fans': '86.4万', 'role': '古琴演奏家 / 音乐制作人', 'img': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80'},
      {'name': '周杰伦', 'fans': '3890.2万', 'role': '华语流行音乐天王', 'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&q=80'},
      {'name': 'Beyond', 'fans': '1240.8万', 'role': '传奇殿堂级摇滚乐队', 'img': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&q=80'},
      {'name': '伯远', 'fans': '512.6万', 'role': '流行歌手 / 唱跳创作人', 'img': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&q=80'},
    ];

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
              onTap: () => onNavigate('artist_detail', a['name']),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MellowAvatar(radius: 46, url: a['img']!),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a['name']!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 16, color: theme.accentColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a['role']!, style: TextStyle(fontSize: 11.5, color: theme.textMuted), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('粉丝 ${a['fans']}', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Row(
          children: [
            SoftButton(
              icon: Icons.arrow_back_rounded,
              isCircle: true,
              onTap: () => widget.onNavigate('artists'),
            ),
            const SizedBox(width: 16),
            Text('返回歌手列表', style: TextStyle(color: theme.textSecondary)),
          ],
        ),
        const SizedBox(height: 20),
        SoftCard(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              const MellowAvatar(
                radius: 60,
                url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&q=80',
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.artistName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        const SizedBox(width: 8),
                        Icon(Icons.verified_rounded, color: theme.accentColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('官方认证音乐人 · 粉丝量 189.4万 · 单曲播放突破 1.2 亿', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
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
                            if (player.playlist.isNotEmpty) {
                              player.playTrack(player.playlist[0]);
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
        ...mockPresetTracks.map((t) => SoftCard(
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
                    Text(t.album, style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
        )),
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

    final radios = [
      {'title': '深夜治愈故事馆', 'sub': '伴你入眠的温暖声音', 'img': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80'},
      {'title': '助眠白噪音与雨声', 'sub': '大自然沉浸式深度放松', 'img': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80'},
      {'title': '音乐背后的人文故事', 'sub': '解码华语流行四十年', 'img': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80'},
      {'title': '科技前沿早知道', 'sub': 'AI 时代的智识声音', 'img': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80'},
    ];

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
                if (mockPresetTracks.isNotEmpty) {
                  player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);
                }
              },
              child: Row(
                children: [
                  MellowImage(url: r['img']!, width: 90, height: 90, borderRadius: MellowRadii.borderR16),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(r['title']!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(r['sub']!, style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
                  Text('共收藏 ${favTracks.length} 首心动单曲 · 实时云端同步', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
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
                    onPressed: () => player.toggleFavorite(t.id),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// 7.5. 导入与自建歌单中心 (DesktopImportedPlaylistsView - 对标 AlgerMusicPlayer 歌单库)
class DesktopImportedPlaylistsView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopImportedPlaylistsView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final playlists = player.importedPlaylists;

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
                Text('支持网易云音乐、QQ音乐分享链接与 ID 一键秒级抓取导入', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            SoftButton(
              label: '导入新歌单',
              icon: Icons.add_link_rounded,
              isActive: true,
              isPill: true,
              onTap: () => showDialog(
                context: context,
                builder: (_) => const ImportPlaylistModal(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        if (playlists.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(40),
            borderRadius: MellowRadii.borderR24,
            child: Column(
              children: [
                Icon(Icons.queue_music_rounded, size: 56, color: theme.accentColor),
                const SizedBox(height: 16),
                Text('暂无外部导入歌单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 6),
                Text('点击上方“导入新歌单”，粘贴网易云公开歌单（如官方热歌榜 3778678）即可完整同步！', style: TextStyle(fontSize: 13, color: theme.textMuted)),
                const SizedBox(height: 20),
                SoftButton(
                  label: '立即体验导入',
                  icon: Icons.download_rounded,
                  isActive: true,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const ImportPlaylistModal(),
                  ),
                ),
              ],
            ),
          )
        else
          for (final pl in playlists)
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
                            Text(
                              pl.title,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text('包含 ${pl.trackCount} 首完整音轨 · ${pl.description}', style: TextStyle(fontSize: 12.5, color: theme.textMuted)),
                          ],
                        ),
                      ),
                      SoftButton(
                        label: '播放全部',
                        icon: Icons.play_arrow_rounded,
                        isActive: true,
                        isPill: true,
                        onTap: () => player.playPlaylist(pl.tracks),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // 前 5 首曲目预览
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
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ],
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
            Text('播放足迹历史', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            Text('已记录最近 ${player.playHistory.length} 首曲目', style: TextStyle(fontSize: 13, color: theme.textMuted)),
          ],
        ),
        const SizedBox(height: 20),
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
class DesktopLocalMusicView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopLocalMusicView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      children: [
        Text('本地与离线下载', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 16),
        RecessedWell(
          padding: const EdgeInsets.all(32),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            children: [
              Icon(Icons.file_upload_outlined, size: 48, color: theme.accentColor),
              const SizedBox(height: 12),
              Text('拖拽音频文件或文件夹至此，或点击导入', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 16)),
              const SizedBox(height: 4),
              Text('支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式', style: TextStyle(color: theme.textMuted, fontSize: 12.5)),
              const SizedBox(height: 16),
              SoftButton(
                label: '选择本地文件夹扫描',
                icon: Icons.folder_open_rounded,
                isPill: true,
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('已解析本地曲目', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 12),
        ...mockPresetTracks.map((t) => SoftCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: () => player.playTrack(t),
          child: Row(
            children: [
              const Icon(Icons.audio_file_rounded, color: Colors.blueAccent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                    Text('FLAC 24bit/96kHz · 42.8 MB', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: theme.accentColor),
            ],
          ),
        )),
      ],
    );
  }
}

/// 10. 个性化设置中心 (SettingsView)
class DesktopSettingsView extends StatelessWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  const DesktopSettingsView({super.key, required this.onNavigate});

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
      ],
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
                Text('自定义音源管理 (QuickJS)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                Text('原生兼容 LX-Music 六音脚本生态规范', style: TextStyle(fontSize: 13, color: theme.textMuted)),
              ],
            ),
            SoftButton(
              label: '在线导入音源链接',
              icon: Icons.add_link_rounded,
              isActive: true,
              isPill: true,
              onTap: () {},
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
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: MellowRadii.borderR16),
                child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('内置综合聚合音源 (Built-in)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: theme.accentColor.withValues(alpha: 0.15), borderRadius: MellowRadii.borderR8),
                          child: Text('v2.1.0 · 运行中', style: TextStyle(fontSize: 10.5, color: theme.accentColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text('支持全网多引擎搜索、FLAC/320k 直链动态解析与 LRC 歌词同步', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                  ],
                ),
              ),
              Switch.adaptive(value: true, activeTrackColor: theme.accentColor, onChanged: (_) {}),
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
  bool _isAutoSync = true;
  bool _isSyncing = false;
  String _syncStatusText = '就绪 · 待同步';
  DateTime? _lastSyncTime;
  final String _serverUrl = 'https://dav.jianguoyun.com/dav/';
  final String _username = 'gaore@mellow.music';

  void _triggerUpload() async {
    setState(() {
      _isSyncing = true;
      _syncStatusText = '正在打包数据快照并上传至 WebDAV...';
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
      _syncStatusText = '同步成功！已热备全量数据';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功将本地播放数据、收藏及歌单备份至 WebDAV 云端！')),
      );
    }
  }

  void _triggerRestore() async {
    setState(() {
      _isSyncing = true;
      _syncStatusText = '正在从 WebDAV 拉取最新快照 (LWW合并)...';
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
      _syncStatusText = '拉取完成！数据已合并';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功从 WebDAV 云端合并最新快照数据！')),
      );
    }
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
            Row(
              children: [
                if (_isSyncing)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.accentColor),
                    ),
                  ),
                SoftButton(
                  label: _isSyncing ? '同步处理中' : '立即云端备份',
                  icon: Icons.cloud_upload_rounded,
                  isActive: true,
                  isPill: true,
                  onTap: _isSyncing ? null : _triggerUpload,
                ),
              ],
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
                        Text('已同步红心收藏', style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
                          Text('支持坚果云、NextCloud、又拍云等标准 WebDAV 协议', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text('服务就绪', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
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
                          if (_lastSyncTime != null) ...[
                            const SizedBox(height: 4),
                            Text('上次同步时间: ${_lastSyncTime!.toString().substring(0, 19)}', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                          ],
                        ],
                      ),
                    ),
                    SoftButton(
                      label: '从云端恢复',
                      icon: Icons.cloud_download_rounded,
                      isPill: true,
                      onTap: _isSyncing ? null : _triggerRestore,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('后台自动定时同步 (每 30 分钟)', style: TextStyle(fontSize: 13.5, color: theme.textPrimary)),
                  Switch.adaptive(
                    value: _isAutoSync,
                    activeTrackColor: theme.accentColor,
                    onChanged: (v) => setState(() => _isAutoSync = v),
                  ),
                ],
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
                          Text('免配置自动探测同 Wi-Fi 下的手机、平板与车载设备，毫秒级流转', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Text('本机端口: 18585 监听中', style: TextStyle(color: theme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('已探测到的同一局域网在线设备', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              const SizedBox(height: 10),

              // 在线设备 1
              SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded, color: Colors.blueAccent, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Gaore 的 iPhone 15 Pro', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                              ),
                              const SizedBox(width: 4),
                              Text('在线', style: TextStyle(fontSize: 10.5, color: Colors.green)),
                            ],
                          ),
                          Text('IP: 192.168.1.103 · iOS 17.5 · Mellow v2.1.0', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                        ],
                      ),
                    ),
                    SoftButton(
                      label: '投送当前播放列表',
                      icon: Icons.send_rounded,
                      isPill: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已向 Gaore 的 iPhone 15 Pro 成功投送当前播放列表！')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 在线设备 2
              SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.speaker_group_rounded, color: Colors.deepPurpleAccent, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('客厅立体声音响 (HomePod)', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                              ),
                              const SizedBox(width: 4),
                              Text('在线', style: TextStyle(fontSize: 10.5, color: Colors.green)),
                            ],
                          ),
                          Text('IP: 192.168.1.108 · 无损立体声流媒体投送', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                        ],
                      ),
                    ),
                    SoftButton(
                      label: '无线音频接力',
                      icon: Icons.cast_rounded,
                      isPill: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已接力音频流至客厅立体声音响！')),
                        );
                      },
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
