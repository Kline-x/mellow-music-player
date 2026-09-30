import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/sources/online_music_service.dart';
import '../../core/sources/scenario_playlist_service.dart';
import '../../core/storage/storage_service.dart';
import '../../design_system/mellow_image.dart';
import '../../design_system/soft_card.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/tokens.dart';
import 'mobile_pages.dart';

/// 移动端场景歌单推荐与自由搜索专属页面 (MobileScenarioPlaylistPage)
class MobileScenarioPlaylistPage extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String pageId, [String? extra])? onNavigatePage;

  const MobileScenarioPlaylistPage({
    super.key,
    required this.onBack,
    this.onNavigatePage,
  });

  @override
  State<MobileScenarioPlaylistPage> createState() => _MobileScenarioPlaylistPageState();
}

class _MobileScenarioPlaylistPageState extends State<MobileScenarioPlaylistPage> {
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

    final matched = ScenarioPlaylistService.presetScenarios.where(
      (s) => s.keywords.any((k) => k.contains(clean) || clean.contains(k)) || s.title.contains(clean),
    ).firstOrNull;

    setState(() {
      _selectedScenarioId = matched?.id;
    });

    _loadScenarioPlaylists(clean);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(
          '场景歌单推荐',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textPrimary,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textSecondary, size: 20),
            onPressed: () => _loadScenarioPlaylists(_activeKeyword),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
        children: [
          // 1. 移动端全幅场景搜索药丸框
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2028) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.borderColor.withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 19, color: theme.accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('mobile_scenario_search_input'),
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '搜场景：结婚、国庆、新年、助眠...',
                      hintStyle: TextStyle(color: theme.textMuted, fontSize: 12.5),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _onExecuteSearch,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.clear_rounded, size: 18, color: theme.textMuted),
                    ),
                  ),
                GestureDetector(
                  key: const Key('mobile_scenario_search_btn'),
                  onTap: () => _onExecuteSearch(_searchController.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '搜索',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. 搜索历史快捷胶囊（如果存在）
          if (_searchHistory.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('历史:', style: TextStyle(fontSize: 11, color: theme.textMuted)),
                  ),
                  ..._searchHistory.take(6).map((historyWord) {
                    final isCurrent = _activeKeyword == historyWord;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          _searchController.text = historyWord;
                          _onExecuteSearch(historyWord);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? theme.accentColor.withValues(alpha: 0.15)
                                : theme.borderColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent ? theme.accentColor : theme.borderColor.withValues(alpha: 0.4),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            historyWord,
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrent ? theme.accentColor : theme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. 预置场景横向滑动标签流
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ScenarioPlaylistService.presetScenarios.map((scenario) {
                final isSelected = _selectedScenarioId == scenario.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: Key('mobile_scenario_tag_${scenario.id}'),
                    onTap: () => _onSelectScenario(scenario),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scenario.gradient[0]
                            : (isDark ? const Color(0xFF1E2028) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? scenario.gradient[1]
                              : theme.borderColor.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            scenario.icon,
                            size: 15,
                            color: isSelected ? Colors.white : theme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            scenario.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // 4. 当前场景信息指示栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '「$_activeKeyword」场景公开歌单',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: theme.textPrimary),
              ),
              Text(
                '共 ${_playlists.length} 个歌单',
                style: TextStyle(fontSize: 11, color: theme.textMuted),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 5. 歌单双列网格
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.queue_music_rounded, size: 48, color: theme.textMuted),
                    const SizedBox(height: 10),
                    Text('暂无「$_activeKeyword」相关场景歌单', style: TextStyle(color: theme.textSecondary, fontSize: 13.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('试试探索以下热门生活与节庆场景：', style: TextStyle(color: theme.textMuted, fontSize: 11.5)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildEmptyChip('婚礼庆典', Icons.favorite_rounded, () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[0])),
                        _buildEmptyChip('国庆华诞', Icons.flag_rounded, () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[1])),
                        _buildEmptyChip('新春贺岁', Icons.celebration_rounded, () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[2])),
                        _buildEmptyChip('晚安助眠', Icons.bedtime_rounded, () => _onSelectScenario(ScenarioPlaylistService.presetScenarios[4])),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final pl = _playlists[index];

                return SoftCard(
                  key: Key('mobile_scenario_card_$index'),
                  padding: const EdgeInsets.all(9),
                  borderRadius: MellowRadii.borderR16,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MobileToplistDetailPage(
                          chartName: 'playlist:::${pl.id}:::${pl.title}:::${pl.coverUrl}:::${pl.description}',
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: MellowImage(
                                  url: pl.coverUrl,
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.music_note_rounded, color: Colors.white, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${pl.trackCount}首',
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
                                onTap: () async {
                                  final detail = await ScenarioPlaylistService.instance.getScenarioPlaylistDetail(pl.id);
                                  if (detail != null && detail.tracks.isNotEmpty) {
                                    player.playPlaylist(detail.tracks, startIndex: 0);
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
                      const SizedBox(height: 6),
                      Text(
                        pl.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: theme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pl.description.isNotEmpty ? pl.description : '精选场景歌单',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: theme.textMuted),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyChip(String label, IconData icon, VoidCallback onTap) {
    final theme = context.read<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2028) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.borderColor.withValues(alpha: 0.8),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.accentColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
