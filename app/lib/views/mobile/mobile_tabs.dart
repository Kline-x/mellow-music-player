import 'package:flutter/material.dart';
import '../../design_system/mellow_image.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/soft_button.dart';
import '../../design_system/recessed_well.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track_model.dart';
import 'mobile_pages.dart';
import 'mobile_sheets.dart';
import '../common/modals.dart';

/// 1. 移动端 Tab 1: 发现音乐 (MobileDiscoverTab)
class MobileDiscoverTab extends StatelessWidget {
  final Function(String pageId, [String? extra]) onNavigatePage;
  final VoidCallback onOpenSearch;

  const MobileDiscoverTab({
    super.key,
    required this.onNavigatePage,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // 顶部搜索胶囊
        GestureDetector(
          onTap: onOpenSearch,
          child: RecessedWell(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderRadius: MellowRadii.borderPill,
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(
                  '搜索歌曲、歌手、专辑...',
                  style: TextStyle(color: theme.textMuted, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 5 大金刚区快捷入口
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildKingKongItem(
              context,
              '每日推荐',
              Icons.calendar_today_rounded,
              const Color(0xFF3B82F6),
              () => onNavigatePage('recommend'),
            ),
            _buildKingKongItem(
              context,
              '歌单广场',
              Icons.queue_music_rounded,
              const Color(0xFF8B5CF6),
              () => onNavigatePage('playlists'),
            ),
            _buildKingKongItem(
              context,
              '巅峰榜',
              Icons.leaderboard_rounded,
              const Color(0xFFF59E0B),
              () => onNavigatePage('toplist'),
            ),
            _buildKingKongItem(
              context,
              '声音电台',
              Icons.radio_rounded,
              const Color(0xFF10B981),
              () => onNavigatePage('radio'),
            ),
            _buildKingKongItem(
              context,
              '私人漫游',
              Icons.explore_rounded,
              const Color(0xFFEC4899),
              () => onNavigatePage('fm'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 专属雷达 Hero 卡片
        SoftCard(
          padding: const EdgeInsets.all(18),
          borderRadius: MellowRadii.borderR24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar_rounded, color: theme.accentColor, size: 18),
                      const SizedBox(width: 6),
                      Text('今日私享雷达', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textPrimary)),
                    ],
                  ),
                  SoftButton(
                    label: '播放全部',
                    icon: Icons.play_arrow_rounded,
                    isPill: true,
                    isActive: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    onTap: () {
                      if (player.playlist.isNotEmpty) player.playTrack(player.playlist[0]);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('根据常听曲风，为您定制今日心动旋律', style: TextStyle(fontSize: 12.5, color: theme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 新歌推荐列表
        Text('新歌速递推荐', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 12),
        ...mockPresetTracks.take(4).map((t) => SoftCard(
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
                    Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                    Text('${t.artist} · ${t.album}', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill_rounded, color: theme.accentColor, size: 28),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildKingKongItem(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final theme = context.watch<ThemeProvider>();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.25), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: theme.textPrimary)),
        ],
      ),
    );
  }
}

/// 2. 移动端 Tab 2: 探索全库 (MobileExploreTab)
class MobileExploreTab extends StatefulWidget {
  final Function(String pageId, [String? extra]) onNavigatePage;
  const MobileExploreTab({super.key, required this.onNavigatePage});

  @override
  State<MobileExploreTab> createState() => _MobileExploreTabState();
}

class _MobileExploreTabState extends State<MobileExploreTab> {
  String _currentTag = '全部';
  final List<String> _tags = ['全部', '华语', '流行', '摇滚', '民谣', '电子', '古典'];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('探索音乐全库', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _tags.map((tag) {
              final isSel = _currentTag == tag;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SoftButton(
                  label: tag,
                  isActive: isSel,
                  isPill: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  onTap: () => setState(() => _currentTag = tag),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
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
                    child: MellowImage(
                      url: t.coverUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: MellowRadii.borderR12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textPrimary)),
                  Text(t.artist, style: TextStyle(fontSize: 11, color: theme.textMuted)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 3. 移动端 Tab 3: 我的资料库 (MobileLibraryTab)
class MobileLibraryTab extends StatelessWidget {
  final Function(String pageId, [String? extra]) onNavigatePage;
  const MobileLibraryTab({super.key, required this.onNavigatePage});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final favCount = player.playlist.where((t) => player.isFavorite(t.id)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('我的音乐资料库', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 16),

        // 核心分类入口行
        Row(
          children: [
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                onTap: () => onNavigatePage('local'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.folder_special_rounded, color: theme.accentColor, size: 28),
                    const SizedBox(height: 10),
                    Text('本地与下载', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                    Text('离线音乐管理', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                onTap: () => onNavigatePage('artists'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Color(0xFF8B5CF6), size: 28),
                    const SizedBox(height: 10),
                    Text('关注歌手', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary)),
                    Text('4 位入驻音乐人', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 我喜欢的音乐卡片
        SoftCard(
          padding: const EdgeInsets.all(16),
          onTap: () {
            final favs = player.playlist.where((t) => player.isFavorite(t.id)).toList();
            if (favs.isNotEmpty) player.playTrack(favs[0]);
          },
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF472B6)]),
                  borderRadius: MellowRadii.borderR16,
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我喜欢的音乐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('已收藏 $favCount 首心动单曲', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: theme.accentColor, size: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// 4. 移动端 Tab 4: 个人与设置中心 (MobileProfileTab)
class MobileProfileTab extends StatelessWidget {
  const MobileProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // 用户卡片
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const MellowAvatar(
                radius: 28,
                url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Mellow 音乐探索家', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textPrimary)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.accentColor,
                            borderRadius: MellowRadii.borderR8,
                          ),
                          child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('享受温润微质感 · 声学生态已连接', style: TextStyle(fontSize: 12, color: theme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 主题切换卡片
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('界面主题与质感', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: theme.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '温润白瓷',
                      icon: Icons.light_mode_rounded,
                      isActive: !isDark,
                      onTap: () => theme.setDarkMode(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftButton(
                      label: '深石墨夜间',
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

        // 强调色选择
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('声学柔光主色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: theme.textPrimary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: AccentColorType.values.map((type) {
                  final isSelected = theme.accentType == type;
                  return GestureDetector(
                    onTap: () => theme.setAccentType(type),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: type.getColor(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: type.getColor(isDark).withOpacity(0.35), blurRadius: 8),
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
