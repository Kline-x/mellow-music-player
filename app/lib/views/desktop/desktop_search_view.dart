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
import '../../core/storage/storage_service.dart';
import '../common/modals.dart';

/// 桌面端独立全屏搜索主视图 (DesktopSearchView - 替代局促小弹窗)
class DesktopSearchView extends StatefulWidget {
  final Function(String viewId, [String? extra]) onNavigate;
  final String? initialQuery;

  const DesktopSearchView({
    super.key,
    required this.onNavigate,
    this.initialQuery,
  });

  @override
  State<DesktopSearchView> createState() => _DesktopSearchViewState();
}

class _DesktopSearchViewState extends State<DesktopSearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _currentQuery = '';
  bool _isLoading = false;
  List<Track> _searchResults = [];
  List<ImportedPlaylist> _playlistResults = [];
  List<ArtistProfile> _artistResults = [];
  bool _isLoadingPlaylists = false;
  bool _isLoadingArtists = false;
  int _songPage = 1;
  bool _isLoadingMoreSongs = false;
  bool _hasMoreSongs = true;
  String _activeCategory = 'songs'; // 'songs', 'playlists', 'artists'
  List<String> _history = [];

  final List<Map<String, String>> _hotSearches = [
    {'title': '周杰伦', 'badge': 'HOT 1'},
    {'title': '告五人', 'badge': 'HOT 2'},
    {'title': '布拉格广场', 'badge': 'HOT 3'},
    {'title': '陈奕迅', 'badge': '4'},
    {'title': '林俊杰', 'badge': '5'},
    {'title': '晴天', 'badge': '6'},
    {'title': '海阔天空', 'badge': '7'},
    {'title': '邓紫棋', 'badge': '8'},
    {'title': '粤语经典', 'badge': '9'},
    {'title': '纯音白噪', 'badge': '10'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _scrollController.addListener(_onScroll);
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _executeSearch(widget.initialQuery!.trim());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 280) {
      if (!_isLoadingMoreSongs && _hasMoreSongs && _activeCategory == 'songs' && !_isLoading) {
        _loadMoreSongs();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.unfocus();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadHistory() {
    setState(() {
      _history = StorageService.instance.getSearchHistory();
    });
  }

  Future<void> _executeSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentQuery = cleanQuery;
      _songPage = 1;
      _hasMoreSongs = true;
      _playlistResults = [];
      _artistResults = [];
    });

    await StorageService.instance.addSearchHistory(cleanQuery);
    _loadHistory();

    final tracksFuture = OnlineMusicService.searchOnlineTracks(cleanQuery, page: 1, limit: 35);
    final playlistsFuture = OnlineMusicService.searchOnlinePlaylists(cleanQuery, limit: 20);
    final artistsFuture = OnlineMusicService.searchOnlineArtists(cleanQuery, limit: 20);

    final res = await Future.wait([tracksFuture, playlistsFuture, artistsFuture]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _searchResults = res[0] as List<Track>;
        _playlistResults = res[1] as List<ImportedPlaylist>;
        _artistResults = res[2] as List<ArtistProfile>;
      });
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMoreSongs || !_hasMoreSongs || _currentQuery.isEmpty) return;
    setState(() => _isLoadingMoreSongs = true);

    try {
      final nextPage = _songPage + 1;
      final more = await OnlineMusicService.searchOnlineTracks(_currentQuery, page: nextPage, limit: 30);
      if (mounted) {
        setState(() {
          _isLoadingMoreSongs = false;
          _songPage = nextPage;
          if (more.isEmpty) {
            _hasMoreSongs = false;
          } else {
            _searchResults = OnlineMusicService.dedupeByTitleArtist([..._searchResults, ...more]);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMoreSongs = false);
    }
  }

  Future<void> _fetchPlaylistsOnly(String query) async {
    setState(() => _isLoadingPlaylists = true);
    try {
      final res = await OnlineMusicService.searchOnlinePlaylists(query, limit: 20);
      if (mounted) {
        setState(() {
          _isLoadingPlaylists = false;
          _playlistResults = res;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlaylists = false);
    }
  }

  Future<void> _fetchArtistsOnly(String query) async {
    setState(() => _isLoadingArtists = true);
    try {
      final res = await OnlineMusicService.searchOnlineArtists(query, limit: 20);
      if (mounted) {
        setState(() {
          _isLoadingArtists = false;
          _artistResults = res;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingArtists = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
      _searchResults.clear();
      _playlistResults.clear();
      _artistResults.clear();
      _isLoading = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<AudioPlayerService>();
    final isDark = theme.isDarkMode;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: false,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 128),
      children: [
        // 1. 顶部大标题与副标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全网音乐搜索',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '聚合主流高保真流媒体音轨 · 原声即点即播',
                  style: TextStyle(fontSize: 13, color: theme.textMuted),
                ),
              ],
            ),
            // 分类筛选 Tab 胶囊
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                borderRadius: MellowRadii.borderPill,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCategoryTab('songs', '单曲', Icons.music_note_rounded),
                  _buildCategoryTab('playlists', '歌单', Icons.queue_music_rounded),
                  _buildCategoryTab('artists', '歌手', Icons.person_rounded),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. 核心大输入框 (Neumorphic Soft Well)
        RecessedWell(
          borderRadius: MellowRadii.borderR24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 22, color: theme.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  autofocus: widget.initialQuery == null,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入歌曲名、歌手、专辑 (例如：布拉格广场、周杰伦、海阔天空)...',
                    hintStyle: TextStyle(fontSize: 14, color: theme.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: _executeSearch,
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18, color: theme.textMuted),
                  splashRadius: 18,
                  onPressed: _clearSearch,
                ),
              const SizedBox(width: 8),
              SoftButton(
                label: '搜索',
                icon: Icons.arrow_forward_rounded,
                isActive: true,
                isPill: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                onTap: () => _executeSearch(_searchController.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 3. 搜索内容区
        if (_isLoading)
          _buildLoadingState(theme)
        else if (_currentQuery.isNotEmpty && (_searchResults.isNotEmpty || _playlistResults.isNotEmpty || _artistResults.isNotEmpty))
          _buildResultsView(theme, player)
        else if (_currentQuery.isNotEmpty)
          _buildEmptyResultsView(theme)
        else
          _buildPreSearchView(theme),
      ],
      ),
    );
  }

  Widget _buildCategoryTab(String id, String label, IconData icon) {
    final theme = context.watch<ThemeProvider>();
    final isSelected = _activeCategory == id;

    return GestureDetector(
      onTap: () {
        setState(() => _activeCategory = id);
        if (_currentQuery.isNotEmpty) {
          if (id == 'playlists' && _playlistResults.isEmpty && !_isLoadingPlaylists) {
            _fetchPlaylistsOnly(_currentQuery);
          } else if (id == 'artists' && _artistResults.isEmpty && !_isLoadingArtists) {
            _fetchArtistsOnly(_currentQuery);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor : Colors.transparent,
          borderRadius: MellowRadii.borderPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : theme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      alignment: Alignment.center,
      child: Column(
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
          ),
          const SizedBox(height: 18),
          Text(
            '正在全网跨音源检索「$_currentQuery」高保真音轨...',
            style: TextStyle(fontSize: 14, color: theme.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            '支持自动换源、原声流媒体解析与 LRC 动态歌词联动',
            style: TextStyle(fontSize: 12, color: theme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResultsView(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: theme.textMuted.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            '未找到与「$_currentQuery」相关的曲目',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '请检查输入拼写，或尝试使用更简短的关键词、歌手名重新检索',
            style: TextStyle(fontSize: 13, color: theme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPreSearchView(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 搜索历史
        if (_history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    '历史搜索',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  await StorageService.instance.clearSearchHistory();
                  _loadHistory();
                },
                child: Text(
                  '清空历史',
                  style: TextStyle(fontSize: 12, color: theme.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _history.map((keyword) {
              return SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                borderRadius: MellowRadii.borderPill,
                onTap: () {
                  _searchController.text = keyword;
                  _executeSearch(keyword);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      keyword,
                      style: TextStyle(fontSize: 12.5, color: theme.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        await StorageService.instance.removeSearchHistory(keyword);
                        _loadHistory();
                      },
                      child: Icon(Icons.close_rounded, size: 14, color: theme.textMuted),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],

        // 2. 热门搜索词条
        Row(
          children: [
            Icon(Icons.local_fire_department_rounded, size: 18, color: const Color(0xFFFF5252)),
            const SizedBox(width: 8),
            Text(
              '热门搜索 · 流行探索',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _hotSearches.map((item) {
            final title = item['title']!;
            final badge = item['badge']!;
            final isTop = badge.startsWith('HOT');

            return SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              borderRadius: MellowRadii.borderPill,
              onTap: () {
                _searchController.text = title;
                _executeSearch(title);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isTop ? const Color(0xFFFF5252).withValues(alpha: 0.15) : theme.borderColor.withValues(alpha: 0.3),
                      borderRadius: MellowRadii.borderPill,
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isTop ? const Color(0xFFFF5252) : theme.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: isTop ? FontWeight.w600 : FontWeight.normal, color: theme.textPrimary),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 36),

        // 3. 探索专区风格卡片
        Text(
          '推荐分类专区',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildGenreCard(theme, '华语流行', '周杰伦、陈奕迅、孙燕姿', const [Color(0xFF6366F1), Color(0xFF8B5CF6)])),
            const SizedBox(width: 14),
            Expanded(child: _buildGenreCard(theme, '摇滚现场', 'Beyond、新裤子、草东', const [Color(0xFFEF4444), Color(0xFFF97316)])),
            const SizedBox(width: 14),
            Expanded(child: _buildGenreCard(theme, '唯美古风', '巫娜、琴筝合奏、山水静心', const [Color(0xFF10B981), Color(0xFF059669)])),
            const SizedBox(width: 14),
            Expanded(child: _buildGenreCard(theme, '治愈民谣', '告五人、房东的猫、赵雷', const [Color(0xFF0EA5E9), Color(0xFF3B82F6)])),
          ],
        ),
      ],
    );
  }

  Widget _buildGenreCard(ThemeProvider theme, String title, String sub, List<Color> colors) {
    final isDark = theme.isDarkMode;
    final primaryColor = colors.first;
    return GestureDetector(
      onTap: () {
        _searchController.text = title;
        _executeSearch(title);
      },
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? primaryColor.withValues(alpha: 0.16) : primaryColor.withValues(alpha: 0.08),
          borderRadius: MellowRadii.borderR16,
          border: Border.all(
            color: isDark ? primaryColor.withValues(alpha: 0.28) : primaryColor.withValues(alpha: 0.2),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(ThemeProvider theme, AudioPlayerService player) {
    if (_activeCategory == 'playlists') {
      return _buildPlaylistsResultsView(theme, player);
    } else if (_activeCategory == 'artists') {
      return _buildArtistsResultsView(theme, player);
    }
    return _buildSongsResultsView(theme, player);
  }

  Widget _buildSongsResultsView(ThemeProvider theme, AudioPlayerService player) {
    final isDark = theme.isDarkMode;

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.music_off_rounded, size: 48, color: theme.textMuted),
              const SizedBox(height: 12),
              Text('未找到相关单曲，请尝试其它关键词', style: TextStyle(color: theme.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showAlbum = constraints.maxWidth >= 720;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部操作栏
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '搜索「$_currentQuery」',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.15),
                        borderRadius: MellowRadii.borderPill,
                      ),
                      child: Text(
                        '${_searchResults.length} 首高保真单曲',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    SoftButton(
                      label: '播放全部',
                      icon: Icons.play_arrow_rounded,
                      isActive: true,
                      isPill: true,
                      onTap: () {
                        if (_searchResults.isNotEmpty) {
                          player.playPlaylist(_searchResults, startIndex: 0);
                        }
                      },
                    ),
                    SoftButton(
                      label: '加入待播队列',
                      icon: Icons.queue_music_rounded,
                      isPill: true,
                      onTap: () {
                        for (final track in _searchResults) {
                          if (!player.playlist.any((t) => t.id == track.id)) {
                            player.playPlaylist([...player.playlist, track], startIndex: player.currentIndex);
                          }
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已将 ${_searchResults.length} 首歌曲加入播放队列'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 结果列表表头
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textMuted)),
                  ),
                  const SizedBox(width: 56), // 封面占位
                  Expanded(
                    flex: showAlbum ? 4 : 6,
                    child: Text('歌曲标题', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textMuted)),
                  ),
                  Expanded(
                    flex: showAlbum ? 3 : 4,
                    child: Text('歌手', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textMuted)),
                  ),
                  if (showAlbum)
                    Expanded(
                      flex: 3,
                      child: Text('专辑', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textMuted)),
                    ),
                  SizedBox(
                    width: 60,
                    child: Text('时长', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textMuted)),
                  ),
                  const SizedBox(width: 80), // 操作区占位
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
            const SizedBox(height: 8),

            // 歌曲列表
            ...List.generate(_searchResults.length, (index) {
              final track = _searchResults[index];
              final isPlayingCurrent = player.currentTrack?.id == track.id && player.isPlaying;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  borderRadius: MellowRadii.borderR12,
                  onTap: () => player.playTrack(track),
                  child: Row(
                    children: [
                      // 序号
                      SizedBox(
                        width: 36,
                        child: isPlayingCurrent
                            ? Icon(Icons.volume_up_rounded, size: 16, color: theme.accentColor)
                            : Text(
                                (index + 1).toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      // 封面大图 (带悬浮圆角)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MellowImage(
                          url: track.coverUrl,
                          width: 44,
                          height: 44,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // 标题与音质角标 + 音源标签
                      Expanded(
                        flex: showAlbum ? 4 : 6,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isPlayingCurrent ? theme.accentColor : theme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.accentColor.withValues(alpha: 0.5), width: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SQ',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.accentColor),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AudioPlayerService.formatSourceDisplayName(track.source),
                                style: TextStyle(fontSize: 8.5, color: theme.accentColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 歌手
                      Expanded(
                        flex: showAlbum ? 3 : 4,
                        child: Text(
                          track.artist,
                          style: TextStyle(fontSize: 13, color: theme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 专辑
                      if (showAlbum)
                        Expanded(
                          flex: 3,
                          child: Text(
                            track.album,
                            style: TextStyle(fontSize: 12.5, color: theme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // 时长
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${track.duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${track.duration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: theme.textMuted),
                        ),
                      ),
                  // 操作按钮群
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 红心收藏
                      GestureDetector(
                        onTap: () => player.toggleFavorite(track.id, track),
                        child: Icon(
                          player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: player.isFavorite(track.id) ? const Color(0xFFEF4444) : theme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // 添加到自建歌单
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AddToPlaylistModal(track: track),
                          );
                        },
                        child: Icon(Icons.playlist_add_rounded, size: 20, color: theme.textMuted),
                      ),
                      const SizedBox(width: 12),
                      // 即刻播放
                      GestureDetector(
                        onTap: () => player.playTrack(track),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlayingCurrent ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 16,
                            color: theme.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),

        // 底部“加载更多”控制条
        if (_hasMoreSongs && _searchResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          Center(
            child: SoftButton(
              label: _isLoadingMoreSongs ? '正在拉取更多高品质单曲...' : '加载更多歌曲 (已呈现 ${_searchResults.length} 首)',
              icon: _isLoadingMoreSongs ? Icons.hourglass_top_rounded : Icons.expand_more_rounded,
              isPill: true,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              onTap: _isLoadingMoreSongs ? null : _loadMoreSongs,
            ),
          ),
          const SizedBox(height: 20),
        ] else if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              '已为您呈现全部 ${_searchResults.length} 首相关高保真单曲',
              style: TextStyle(fontSize: 12, color: theme.textMuted),
            ),
          ),
        ],
      ],
    );
  },
);
  }

  Widget _buildPlaylistsResultsView(ThemeProvider theme, AudioPlayerService player) {
    if (_isLoadingPlaylists) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(theme.accentColor)),
        ),
      );
    }

    if (_playlistResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.queue_music_rounded, size: 48, color: theme.textMuted),
              const SizedBox(height: 12),
              Text('未找到相关公开歌单', style: TextStyle(color: theme.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '相关歌单',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.15),
                borderRadius: MellowRadii.borderPill,
              ),
              child: Text(
                '${_playlistResults.length} 个公开歌单',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _playlistResults.map((pl) {
            return SizedBox(
              width: 190,
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                borderRadius: MellowRadii.borderR16,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(content: Text('正在解析导入歌单「${pl.title}」...'), duration: const Duration(seconds: 1)),
                  );
                  final imported = await OnlineMusicService.importNeteasePlaylist(pl.id.replaceAll('netease_', ''));
                  if (!mounted) return;
                  if (imported != null && imported.tracks.isNotEmpty) {
                    player.addImportedPlaylist(imported);
                    player.playPlaylist(imported.tracks, startIndex: 0);
                    messenger.showSnackBar(
                      SnackBar(content: Text('已导入并开始播放歌单「${pl.title}」（共 ${imported.tracks.length} 首）')),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: MellowImage(
                        url: pl.coverUrl,
                        width: 166,
                        height: 166,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pl.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pl.trackCount} 首歌曲 · ${pl.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildArtistsResultsView(ThemeProvider theme, AudioPlayerService player) {
    if (_isLoadingArtists) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(theme.accentColor)),
        ),
      );
    }

    if (_artistResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.person_off_rounded, size: 48, color: theme.textMuted),
              const SizedBox(height: 12),
              Text('未找到相关歌手档案', style: TextStyle(color: theme.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '相关歌手',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.15),
                borderRadius: MellowRadii.borderPill,
              ),
              child: Text(
                '${_artistResults.length} 位歌手',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _artistResults.map((a) {
            return SizedBox(
              width: 175,
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                borderRadius: MellowRadii.borderR16,
                onTap: () => widget.onNavigate('artist_detail', a.name),
                child: Column(
                  children: [
                    ClipOval(
                      child: MellowImage(
                        url: a.avatarUrl,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${a.musicSize} 首单曲 · ${a.albumSize} 专辑',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                    ),
                    const SizedBox(height: 10),
                    SoftButton(
                      label: '进入歌手页',
                      icon: Icons.arrow_forward_rounded,
                      isPill: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      onTap: () => widget.onNavigate('artist_detail', a.name),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
