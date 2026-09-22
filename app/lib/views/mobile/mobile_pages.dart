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

/// 1. 每日推荐二级页面 (拟物日历便签头 + 6 首日推曲目)
class MobileDailyRecommendPage extends StatelessWidget {
  final VoidCallback onBack;
  const MobileDailyRecommendPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final now = DateTime.now();

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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.accentColor,
                    borderRadius: MellowRadii.borderR16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${now.month}月', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('${now.day}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.1)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('专属声学日推 · 每日 06:00 更新', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: theme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('今日契合度 99.4% · 已匹配 6 首温润曲目', style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
                label: '播放全部 (6首)',
                icon: Icons.play_arrow_rounded,
                isActive: true,
                isPill: true,
                onTap: () {
                  if (mockPresetTracks.isNotEmpty) player.playTrack(mockPresetTracks[0]);
                },
              ),
              Text('高品质无损回放', style: TextStyle(fontSize: 12, color: theme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          ...mockPresetTracks.map((t) => SoftCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => player.playTrack(t),
            child: Row(
              children: [
                MellowImage(url: t.coverUrl, width: 44, height: 44, borderRadius: MellowRadii.borderR8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary)),
                      Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.pink, size: 20),
                  onPressed: () => player.toggleFavorite(t.id),
                ),
              ],
            ),
          )),
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
    )..repeat();
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
                    BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 10)),
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
  const MobileToplistPage({super.key, required this.onBack});

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
          return SoftCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              if (mockPresetTracks.isNotEmpty) player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(chartName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                    Icon(Icons.play_circle_fill_rounded, color: theme.accentColor, size: 28),
                  ],
                ),
                const SizedBox(height: 10),
                ...List.generate(3, (i) {
                  final t = mockPresetTracks[(idx + i) % mockPresetTracks.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${i + 1}. ${t.title} - ${t.artist}',
                      style: TextStyle(fontSize: 12.5, color: i == 0 ? theme.accentColor : theme.textSecondary),
                    ),
                  );
                }),
              ],
            ),
          );
        },
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

    final radios = [
      {'title': '深夜治愈故事馆', 'sub': '温暖伴眠精选'},
      {'title': '大自然白噪音', 'sub': '雨声与流水'},
      {'title': '流行音乐传奇故事', 'sub': '经典背后的人文'},
      {'title': '科技先锋播客', 'sub': '智能未来的前沿之声'},
    ];

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
              if (mockPresetTracks.isNotEmpty) player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);
            },
            child: Row(
              children: [
                Icon(Icons.radio_rounded, size: 32, color: theme.accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['title']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                      Text(r['sub']!, style: TextStyle(fontSize: 12, color: theme.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: theme.textSecondary),
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
    final artists = [
      {'name': '巫娜', 'fans': '86.4万', 'img': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80'},
      {'name': '周杰伦', 'fans': '3890.2万', 'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&q=80'},
      {'name': 'Beyond', 'fans': '1240.8万', 'img': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&q=80'},
      {'name': '伯远', 'fans': '512.6万', 'img': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&q=80'},
    ];

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
            onTap: () => onSelectArtist(a['name']!),
            child: Row(
              children: [
                MellowAvatar(radius: 26, url: a['img']!),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(a['name']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 14, color: theme.accentColor),
                        ],
                      ),
                      Text('粉丝 ${a['fans']}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
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
                const MellowAvatar(
                  radius: 36,
                  url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.artistName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('官方认证音乐人 · 粉丝量 189.4万', style: TextStyle(fontSize: 11.5, color: theme.textMuted)),
                      const SizedBox(height: 10),
                      SoftButton(
                        label: _isFollowing ? '已关注' : '+ 关注',
                        isActive: _isFollowing,
                        isPill: true,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        onTap: () => setState(() => _isFollowing = !_isFollowing),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('代表作清单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
          const SizedBox(height: 10),
          ...mockPresetTracks.map((t) => SoftCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => player.playTrack(t),
            child: Row(
              children: [
                MellowImage(url: t.coverUrl, width: 40, height: 40, borderRadius: MellowRadii.borderR8),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textPrimary)),
                ),
                IconButton(
                  icon: Icon(player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.pink, size: 20),
                  onPressed: () => player.toggleFavorite(t.id),
                ),
              ],
            ),
          )),
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          RecessedWell(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.folder_zip_rounded, size: 36, color: theme.accentColor),
                const SizedBox(height: 8),
                Text('设备离线音频扫描', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text('已缓存 6 首无损音频 · 占用空间 182 MB', style: TextStyle(fontSize: 12, color: theme.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...mockPresetTracks.map((t) => SoftCard(
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
                      Text('FLAC 24bit · 42.8 MB', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: theme.accentColor),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
