import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/sources/online_music_service.dart';
import '../../core/sources/scenario_playlist_service.dart';
import '../../core/storage/storage_service.dart';
import '../../design_system/mellow_image.dart';
import '../../design_system/soft_button.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/tokens.dart';

/// 桌面端场景歌单推荐与自由搜索主视图 (DesktopScenarioPlaylistView)
class DesktopScenarioPlaylistView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;

  const DesktopScenarioPlaylistView({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DesktopScenarioPlaylistView> createState() => _DesktopScenarioPlaylistViewState();
}

class _DesktopScenarioPlaylistViewState extends State<DesktopScenarioPlaylistView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _activeKeyword = '结婚';
  String? _selectedScenarioId = 'wedding';
  bool _isLoading = false;
  List<ImportedPlaylist> _playlists = [];
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadScenarioPlaylists(_activeKeyword);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadHistory() {
    setState(() {
      _searchHistory = StorageService.instance.getScenarioSearchHistory();
    });
  }

  Future<void> _loadScenarioPlaylists(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _activeKeyword = clean;
    });

    final res = await ScenarioPlaylistService.instance.searchScenarioPlaylists(clean, limit: 30);

    if (mounted) {
      setState(() {
        _playlists = res;
        _isLoading = false;
      });
      _loadHistory();
    }
  }

  void _onSelectScenario(ScenarioItem item) {
    setState(() {
      _selectedScenarioId = item.id;
      _searchController.text = item.primaryKeyword;
    });
    _loadScenarioPlaylists(item.primaryKeyword);
  }

  void _onExecuteSearch(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // 匹配是否有预置场景
    final matchedScenario = ScenarioPlaylistService.presetScenarios.where(
      (s) => s.keywords.any((k) => k.contains(clean) || clean.contains(k)) || s.title.contains(clean),
    ).firstOrNull;

    setState(() {
      _selectedScenarioId = matchedScenario?.id;
    });

    _loadScenarioPlaylists(clean);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        // 1. 顶部 Header 标题与场景自由搜索输入框
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '场景歌单推荐',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.12),
                        borderRadius: MellowRadii.borderPill,
                      ),
                      child: Text(
                        '生活与节日',
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '自由探索婚礼、国庆、新春贺岁、晚安助眠等多元场景，用音乐点亮当下时刻',
                  style: TextStyle(fontSize: 13, color: theme.textMuted),
                ),
              ],
            ),

            // 自由场景搜索框
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, minWidth: 260),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2028) : const Color(0xFFF1F5F9),
                  borderRadius: MellowRadii.borderPill,
                  border: Border.all(
                    color: theme.borderColor.withValues(alpha: 0.8),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, size: 20, color: theme.accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('scenario_search_input'),
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '搜索场景：结婚、国庆、新年、自驾...',
                          hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: _onExecuteSearch,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: theme.textMuted,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      key: const Key('scenario_search_button'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      color: theme.accentColor,
                      tooltip: '立即搜索此场景',
                      onPressed: () => _onExecuteSearch(_searchController.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 2. 场景搜索历史 (如果有)
        if (_searchHistory.isNotEmpty) ...[
          Row(
            children: [
              Text(
                '最近搜索的场景',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await StorageService.instance.clearScenarioSearchHistory();
                  _loadHistory();
                },
                child: Text('清空历史', style: TextStyle(fontSize: 11, color: theme.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _searchHistory.map((historyWord) {
                final isCurrent = _activeKeyword == historyWord;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SoftButton(
                    label: historyWord,
                    icon: Icons.history_rounded,
                    isActive: isCurrent,
                    isPill: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    onTap: () {
                      _searchController.text = historyWord;
                      _onExecuteSearch(historyWord);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
        ],

        // 3. 高频精选场景大卡片水平流
        Text(
          '精选生活与节庆场景',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ScenarioPlaylistService.presetScenarios.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final scenario = ScenarioPlaylistService.presetScenarios[index];
              final isSelected = _selectedScenarioId == scenario.id;

              return GestureDetector(
                key: Key('scenario_card_${scenario.id}'),
                onTap: () => _onSelectScenario(scenario),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 210,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scenario.gradient[0].withValues(alpha: isSelected ? 0.95 : 0.75),
                        scenario.gradient[1].withValues(alpha: isSelected ? 0.95 : 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: MellowRadii.borderR20,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                      width: isSelected ? 2.0 : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scenario.gradient[0].withValues(alpha: isSelected ? 0.4 : 0.15),
                        blurRadius: isSelected ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(scenario.icon, color: Colors.white, size: 20),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '当前场景',
                                style: TextStyle(
                                  color: scenario.gradient[0],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scenario.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scenario.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 26),

        // 4. 场景歌单标题与统计指示
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '「$_activeKeyword」精选公开歌单',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.12),
                    borderRadius: MellowRadii.borderPill,
                  ),
                  child: Text(
                    '${_playlists.length} 个场景歌单',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor),
                  ),
                ),
              ],
            ),
            SoftButton(
              label: '刷新推荐',
              icon: Icons.refresh_rounded,
              isPill: true,
              onTap: () => _loadScenarioPlaylists(_activeKeyword),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 5. 歌单响应式卡片网格
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          )
        else if (_playlists.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(40),
            borderRadius: MellowRadii.borderR24,
            child: Column(
              children: [
                Icon(Icons.queue_music_rounded, size: 54, color: theme.textMuted),
                const SizedBox(height: 14),
                Text(
                  '未找到「$_activeKeyword」相关场景歌单',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  '可以尝试搜索：结婚、国庆、新年、咖啡、助眠、自驾、聚会等热门场景词。',
                  style: TextStyle(fontSize: 12.5, color: theme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SoftButton(
                      label: '婚礼庆典',
                      icon: Icons.favorite_rounded,
                      onTap: () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[0]),
                    ),
                    SoftButton(
                      label: '国庆华诞',
                      icon: Icons.flag_rounded,
                      onTap: () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[1]),
                    ),
                    SoftButton(
                      label: '新春贺岁',
                      icon: Icons.celebration_rounded,
                      onTap: () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[2]),
                    ),
                    SoftButton(
                      label: '午后咖啡',
                      icon: Icons.local_cafe_rounded,
                      onTap: () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[3]),
                    ),
                    SoftButton(
                      label: '晚安助眠',
                      icon: Icons.bedtime_rounded,
                      onTap: () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[4]),
                    ),
                    SoftButton(
                      label: '公路自驾',
                      icon: Icons.directions_car_rounded,
                      onTap: () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[7]),
                    ),
                  ],
                ),
              ],
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
              childAspectRatio: 0.78,
            ),
            itemCount: _playlists.length,
            itemBuilder: (context, index) {
              final pl = _playlists[index];

              return SoftCard(
                key: Key('scenario_playlist_card_$index'),
                padding: const EdgeInsets.all(12),
                borderRadius: MellowRadii.borderR16,
                onTap: () {
                  widget.onNavigate(
                    'playlist_detail',
                    'playlist:::${pl.id}:::${pl.title}:::${pl.coverUrl}:::${pl.description}:::scenarios',
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: MellowRadii.borderR16,
                              child: MellowImage(
                                url: pl.coverUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // 播放量/歌曲数微标签
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: MellowRadii.borderPill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.music_note_rounded, color: Colors.white, size: 11),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${pl.trackCount}首',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 悬浮快速播放按钮
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(
                                  SnackBar(content: Text('正在解析场景歌单「${pl.title}」...'), duration: const Duration(seconds: 1)),
                                );
                                final detail = await ScenarioPlaylistService.instance.getScenarioPlaylistDetail(pl.id);
                                if (detail != null && detail.tracks.isNotEmpty) {
                                  player.playPlaylist(detail.tracks, startIndex: 0);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('已开始播放场景歌单「${pl.title}」（共 ${detail.tracks.length} 首）')),
                                  );
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: theme.accentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.accentColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pl.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: theme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pl.description.isNotEmpty ? pl.description : '精选场景公开推荐歌单',
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
