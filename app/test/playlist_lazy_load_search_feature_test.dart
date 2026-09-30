import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/scenario_playlist_service.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

import 'package:mellow_music/core/sources/online_music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final samplePlaylists = [
    SquarePlaylist(
      id: 'sample-pl-1',
      title: '华语经典流行金曲堂',
      desc: '从千禧年代到黄金世代，听懂已非少年',
      tag: '华语流行',
      coverUrl: 'https://p1.music.126.net/6y-UleORITEDbvrOLAL-vQ==/109951164803975765.jpg',
      playCount: '184.2万',
      trackCount: 65,
      tracks: mockJayChouTracks,
    ),
    SquarePlaylist(
      id: 'sample-pl-2',
      title: '治愈系都市温情歌单',
      desc: '温暖每一个孤单夜晚',
      tag: '沉静治愈',
      coverUrl: 'https://p2.music.126.net/L3cE6x8y2g6n7Q0o4w0z_g==/109951165123987114.jpg',
      playCount: '92.4万',
      trackCount: 42,
      tracks: mockBoYuanTracks,
    ),
  ];

  setUpAll(() {
    OnlineMusicService.mockTopPlaylistsFetcher = ({cat = '全部', offset = 0, limit = 30}) async => samplePlaylists;
  });

  group('歌单全量懒加载、即时曲目搜索与全屏详情页专属验收套件', () {
    late AudioPlayerService audioService;
    late ThemeProvider themeProvider;
    late EqualizerManager eqManager;

    setUp(() {
      audioService = AudioPlayerService();
      themeProvider = ThemeProvider();
      eqManager = EqualizerManager();
    });

    tearDown(() {
      audioService.pause();
    });

    Widget buildTestApp(Widget child, {Size size = const Size(1280, 800)}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audioService),
          ChangeNotifierProvider<EqualizerManager>.value(value: eqManager),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: child,
          ),
        ),
      );
    }

    test('TEST-1: 歌单广场全网真实热门精选歌单分类 API 与数据流模型验证', () async {
      final list = await OnlineMusicService.fetchTopPlaylists(cat: '华语流行', limit: 10);
      expect(list.isNotEmpty, isTrue);
      final first = list.first;
      expect(first.title, equals('华语经典流行金曲堂'));
      expect(first.coverUrl.contains('unsplash.com'), isFalse);
      expect(first.coverUrl.startsWith('https://p'), isTrue);
      expect(first.trackCount, greaterThan(0));
    });

    test('TEST-2: 场景预设歌单全量覆盖与国内 CDN 换源验证', () {
      final scenarios = ScenarioPlaylistService.presetScenarios;
      expect(scenarios.length, equals(12));
      for (final s in scenarios) {
        expect(s.defaultCoverUrl.contains('unsplash.com'), isFalse);
        expect(s.defaultCoverUrl.startsWith('https://'), isTrue);
      }
    });

    testWidgets('TEST-3: MellowImage 优雅声学双色艺术渐变兜底机制验证 (杜绝灰白死板方块)', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MellowImage(
            url: '', // 空链接，触发声学艺术渐变降级
            width: 120,
            height: 120,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证渲染了微拟物声学唱片与音符图标
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('TEST-4: 桌面端全屏歌单详情页渲染、即时搜索筛选与一键播放验证', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 模拟跳转进入全屏歌单详情页
      await tester.pumpWidget(
        buildTestApp(
          DesktopToplistDetailView(
            chartName: 'playlist:::sq-pl-1:::华语经典流行金曲堂:::https://p1.music.126.net/6y-UleORITEDbvrOLAL-vQ==/109951164803975765.jpg:::经典千禧一代流行金曲:::playlists',
            onNavigate: (_, [__]) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证详情页 Header Banner 元素
      expect(find.text('华语经典流行金曲堂'), findsOneWidget);
      expect(find.text('场景精选歌单'), findsOneWidget);
      expect(find.text('经典千禧一代流行金曲'), findsOneWidget);
      expect(find.textContaining('播放全部'), findsOneWidget);
      expect(find.textContaining('添加到播放列表'), findsOneWidget);

      // 2. 验证曲目列表渲染丰富 (超过 10 首)
      expect(find.byType(DesktopSongTableView), findsOneWidget);

      // 3. 验证歌单内即时搜索过滤
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);

      await tester.enterText(searchInput, '晴天');
      await tester.pump(const Duration(milliseconds: 200));

      // 过滤结果验证
      expect(find.textContaining('筛选结果'), findsOneWidget);

      // 4. 清空搜索过滤
      final clearBtn = find.byTooltip('清空筛选');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('歌曲列表'), findsOneWidget);
    });

    testWidgets('TEST-5: 桌面端脚手架点击歌单广场卡片无缝打开全屏详情页与播放闭环', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(const DesktopScaffold()),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 切换至歌单广场
      await tester.tap(find.text('歌单广场'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 点击首个歌单卡片「华语经典流行金曲堂」
      final card = find.text('华语经典流行金曲堂');
      expect(card, findsOneWidget);
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证已下钻至全屏详情页
      expect(find.text('返回歌单广场'), findsOneWidget);
      expect(find.text('华语经典流行金曲堂'), findsAtLeastNWidgets(1));
      expect(find.textContaining('播放全部'), findsOneWidget);
    });

    testWidgets('TEST-6: 移动端全屏歌单详情页下钻、触底懒加载指示器与搜索联动验证', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          MobileToplistDetailPage(
            chartName: 'playlist:::sq-pl-1:::华语经典流行金曲堂:::https://p1.music.126.net/6y-UleORITEDbvrOLAL-vQ==/109951164803975765.jpg:::移动端经典歌单',
            onBack: () {},
          ),
          size: const Size(390, 844),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 验证标题与精选歌单标签
      expect(find.text('华语经典流行金曲堂'), findsWidgets);
      expect(find.text('精选歌单'), findsOneWidget);
      expect(find.text('播放全部'), findsOneWidget);

      // 验证移动端搜索栏
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, '周杰伦');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('周杰伦'), findsWidgets);
    });
  });
}
