import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/sources/daily_recommend_service.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('DailyRecommendService 单元测试', () {
    test('确定性生成 28 首每日推荐曲库', () {
      final service = DailyRecommendService.instance;
      final tracks = service.getDailyRecommendTracks(limit: 28);
      expect(tracks.length, equals(28));

      // 验证曲目信息完整性
      for (final t in tracks) {
        expect(t.id, isNotEmpty);
        expect(t.title, isNotEmpty);
        expect(t.artist, isNotEmpty);
      }

      // 同一天调用两次，返回结果必须确定性完全一致
      final tracksAgain = service.getDailyRecommendTracks(limit: 28);
      expect(tracks.map((e) => e.id).toList(), equals(tracksAgain.map((e) => e.id).toList()));
    });

    test('动态问候语与格式化日期测试', () {
      final service = DailyRecommendService.instance;
      final greeting = service.getGreeting();
      expect(greeting, isNotEmpty);

      final day = service.getFormattedDay();
      expect(day.length, equals(2));

      final weekday = service.getFormattedWeekday();
      expect(weekday, startsWith('星期'));

      final monthYear = service.getFormattedMonthYear();
      expect(monthYear, contains('年'));
      expect(monthYear, contains('月'));
    });
  });

  group('DesktopToplistDetailView 榜单详情组件测试', () {
    testWidgets('桌面端榜单详情页能正确展示榜单所有曲目与前三金银铜徽标', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopToplistDetailView(
                chartName: '飙升榜',
                onNavigate: (_, [__]) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证标题和徽标渲染
      expect(find.text('飙升榜'), findsWidgets);
      expect(find.text('官方权威排行榜'), findsOneWidget);
      expect(find.textContaining('播放全部'), findsOneWidget);

      // 验证歌曲列表展示（榜单前三名有金银铜标识 01、02、03）
      expect(find.text('01'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);

      // 验证榜内搜索过滤输入框
      expect(find.byType(TextField), findsOneWidget);
      final searchSong = toplistSurgeTracks.first.title;
      await tester.enterText(find.byType(TextField), searchSong);
      await tester.pumpAndSettle();
      expect(find.text(searchSong), findsWidgets);
    });
  });

  group('DesktopDailyRecommendView 每日推荐详情组件测试', () {
    testWidgets('桌面端每日推荐详情页能正确渲染日历便签头与28首推荐曲目', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopDailyRecommendView(
                onNavigate: (_, [__]) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证日历撕页便签头
      expect(find.text('每日06:00更新'), findsOneWidget);
      expect(find.text('专属声学算法推荐'), findsOneWidget);
      expect(find.textContaining('播放全部'), findsOneWidget);

      // 点击播放全部
      await tester.tap(find.textContaining('播放全部'));
      await tester.pumpAndSettle();
      expect(audioService.playlist.length, greaterThanOrEqualTo(28));
    });
  });

  group('Mobile 移动端榜单详情与每日推荐测试', () {
    testWidgets('移动端每日推荐二级页渲染28首推荐曲目并能一键播放全部', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: MaterialApp(
            home: MobileDailyRecommendPage(onBack: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('每日推荐'), findsOneWidget);
      expect(find.textContaining('专属声学日推'), findsOneWidget);
      expect(find.text('播放全部 (28首)'), findsOneWidget);

      await tester.tap(find.text('播放全部 (28首)'));
      await tester.pumpAndSettle();
      expect(audioService.playlist.length, equals(28));
    });

    testWidgets('移动端榜单详情二级页渲染榜单曲目与金银铜名次', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: MaterialApp(
            home: MobileToplistDetailPage(chartName: '热歌榜', onBack: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('热歌榜'), findsWidgets);
      expect(find.text('官方巅峰榜单'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
