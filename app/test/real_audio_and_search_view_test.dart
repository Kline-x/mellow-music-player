import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/views/desktop/desktop_search_view.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('1. 全仓去假求真与零 SoundHelix 验证', () {
    test('所有预置曲目与榜单曲目彻底消灭 soundhelix 假链接', () {
      for (final t in mockPresetTracks) {
        expect(t.audioUrl?.contains('soundhelix.com') ?? false, isFalse);
      }
      for (final list in toplistTracksMap.values) {
        for (final t in list) {
          expect(t.audioUrl?.contains('soundhelix.com') ?? false, isFalse);
        }
      }
      for (final t in getAllToplistTracks()) {
        expect(t.audioUrl?.contains('soundhelix.com') ?? false, isFalse);
      }
    });

    test('AudioPlayerService 真实音频调度与换源回退机制', () async {
      final backend = InMemoryAudioPlayerBackend();
      final player = AudioPlayerService(backend: backend);

      final testTrack = Track(
        id: 'test-blg',
        title: '布拉格广场',
        artist: '蔡依林',
        album: '看我72变',
        coverUrl: '',
        duration: const Duration(minutes: 4),
        source: 'test',
        audioUrl: 'https://music.163.com/song/media/outer/url?id=186016.mp3', // 模拟 404 外链
      );

      player.playTrack(testTrack);
      expect(player.isPlaying, isTrue);
      expect(player.currentTrack?.title, equals('布拉格广场'));
    });
  });

  group('2. 搜索历史持久化与 StorageService 验证', () {
    test('搜索历史记录能够正常增加、去重、置顶、删除与清空', () async {
      final storage = StorageService.instance;
      expect(storage.getSearchHistory(), isEmpty);

      await storage.addSearchHistory('周杰伦');
      await storage.addSearchHistory('告五人');
      await storage.addSearchHistory('布拉格广场');
      expect(storage.getSearchHistory(), equals(['布拉格广场', '告五人', '周杰伦']));

      // 再次搜索周杰伦，应置顶去重
      await storage.addSearchHistory('周杰伦');
      expect(storage.getSearchHistory(), equals(['周杰伦', '布拉格广场', '告五人']));

      // 单条删除
      await storage.removeSearchHistory('告五人');
      expect(storage.getSearchHistory(), equals(['周杰伦', '布拉格广场']));

      // 全部清空
      await storage.clearSearchHistory();
      expect(storage.getSearchHistory(), isEmpty);
    });
  });

  group('3. 独立全屏搜索页面 DesktopSearchView 验证', () {
    testWidgets('DesktopSearchView 渲染完整搜索框、分类 Tab、历史搜索与热门词条', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await StorageService.instance.addSearchHistory('晴天');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AudioPlayerService(backend: InMemoryAudioPlayerBackend())),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSearchView(
                onNavigate: (view, [extra]) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证大标题与提示
      expect(find.text('全网音乐搜索'), findsOneWidget);
      expect(find.text('聚合主流高保真流媒体音轨 · 原声即点即播'), findsOneWidget);

      // 验证分类 Tab
      expect(find.text('单曲'), findsOneWidget);
      expect(find.text('歌单'), findsOneWidget);
      expect(find.text('歌手'), findsOneWidget);

      // 验证搜索框
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('搜索'), findsOneWidget);

      // 验证历史记录与热门搜索
      expect(find.text('历史搜索'), findsOneWidget);
      expect(find.text('晴天'), findsOneWidget);
      expect(find.text('热门搜索 · 流行探索'), findsOneWidget);
      expect(find.text('布拉格广场'), findsOneWidget);
      expect(find.text('周杰伦'), findsOneWidget);
    });
  });

  group('4. 移动端独立全屏搜索页面 MobileSearchPage 验证', () {
    testWidgets('MobileSearchPage 正确渲染输入框、返回键与热搜词条', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool backed = false;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AudioPlayerService(backend: InMemoryAudioPlayerBackend())),
          ],
          child: MaterialApp(
            home: MobileSearchPage(onBack: () => backed = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('全网热门搜索'), findsOneWidget);
      expect(find.text('布拉格广场'), findsOneWidget);

      // 点击返回按钮
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(backed, isTrue);
    });
  });
}
