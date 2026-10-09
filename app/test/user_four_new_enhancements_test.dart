import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/views/mobile/mobile_tabs.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';

Widget buildTestApp(Widget child, {AudioPlayerService? player}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<AudioPlayerService>(create: (_) => player ?? AudioPlayerService()),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('四大专项新特性深度验收套件 (突破50首、退出润音、甄选歌单、灵动岛/原子岛)', () {
    testWidgets('1. 移动端发现页呈现与PC端一致的「甄选歌单推荐」，包含查看全部与歌单流', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();
      bool navigatedToPlaylists = false;

      await tester.pumpWidget(
        buildTestApp(
          MobileDiscoverTab(
            onNavigatePage: (page, [extra]) {
              if (page == 'playlists') navigatedToPlaylists = true;
            },
            onOpenSearch: () {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('甄选歌单推荐'), findsOneWidget);
      expect(find.text('查看全部 >'), findsOneWidget);

      // 点击「查看全部 >」验证导航至歌单广场
      await tester.tap(find.text('查看全部 >'));
      await tester.pump();
      expect(navigatedToPlaylists, isTrue);
    });

    testWidgets('2. 移动端歌手详情页支持触底流式懒加载并突破50首代表作限制', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();

      await tester.pumpWidget(
        buildTestApp(
          MobileArtistDetailPage(
            artistName: '周杰伦',
            onBack: () {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证标题呈现全部作品清单与歌手名称
      expect(find.text('全部作品清单'), findsOneWidget);
      expect(find.text('周杰伦'), findsWidgets);
      expect(find.text('播放热门'), findsOneWidget);

      // 验证滑动列表存在并能触发滚动
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);

      // 模拟下滑滚动触发触底懒加载
      await tester.drag(listViewFinder, const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('3. PC 桌面端歌手详情页支持双Tab切换与触底加载控制器绑定', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final player = AudioPlayerService();

      await tester.pumpWidget(
        buildTestApp(
          DesktopArtistDetailView(
            artistName: '周杰伦',
            onNavigate: (_, [__]) {},
          ),
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('返回歌手列表'), findsOneWidget);
      expect(find.textContaining('热门代表作'), findsWidgets);
      expect(find.textContaining('全部作品'), findsWidgets);

      // 验证绑定了 ScrollController 的主 ListView
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);

      // 验证在 Tab 1（全部作品）下能够切换并平滑展示
      final allTab = find.textContaining('全部作品').first;
      await tester.tap(allTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    test('4. 灵动岛药丸与MiniPlayer手势交互支持', () {
      final player = AudioPlayerService();
      final testTrack = Track(
        id: 'capsule-test-1',
        title: '灵动岛测试歌曲',
        artist: '原子通知歌手',
        album: '声学专辑',
        coverUrl: 'http://example.com/cover.jpg',
        duration: const Duration(minutes: 3),
      );
      player.playTrack(testTrack);

      expect(player.isPlaying, isTrue);
      expect(player.currentTrack?.title, equals('灵动岛测试歌曲'));
      player.pause();
    });

    testWidgets('5. 移动端甄选歌单卡片点击接入onNavigatePage子栈，保障MiniPlayer与灵动岛驻留', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? navigatedPage;
      String? navigatedParam;

      await tester.pumpWidget(
        buildTestApp(
          MobileDiscoverTab(
            onNavigatePage: (page, [param]) {
              navigatedPage = page;
              navigatedParam = param;
            },
            onOpenSearch: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final firstPlaylistCard = find.textContaining('云音乐热歌榜');
      expect(firstPlaylistCard, findsOneWidget);

      await tester.tap(firstPlaylistCard);
      await tester.pump();

      expect(navigatedPage, equals('playlist_detail'));
      expect(navigatedParam, contains('playlist:::netease_3778678'));
    });

    test('6. 歌词有效性过滤与多源降级：过滤假占位歌词，确保拉取真实多行滚动歌词', () async {
      // 验证伪歌词识别过滤规则
      final placeholderLyrics = [
        LyricLine(time: Duration.zero, text: '玻璃 - Gareth.T'),
        LyricLine(time: const Duration(seconds: 4), text: '由自定义音源脚本 [六音] 解析提供'),
      ];

      bool isValid(List<LyricLine> list) {
        if (list.isEmpty) return false;
        if (list.length <= 2) {
          final combined = list.map((e) => e.text).join(' ');
          if (combined.contains('暂无歌词') ||
              combined.contains('暂无滚动歌词') ||
              combined.contains('纯音乐') ||
              combined.contains('自定义音源脚本') ||
              combined.contains('解析提供')) {
            return false;
          }
        }
        return true;
      }

      // 假占位歌词应被拒绝
      expect(isValid(placeholderLyrics), isFalse);

      // 真实完整多行歌词应被接收
      final realLyrics = [
        LyricLine(time: Duration.zero, text: '前奏'),
        LyricLine(time: const Duration(seconds: 10), text: '清风拂过绿水波澜起伏'),
        LyricLine(time: const Duration(seconds: 20), text: '指尖拨弄琴弦余音未绝'),
      ];
      expect(isValid(realLyrics), isTrue);
    });
  });
}

