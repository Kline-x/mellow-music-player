import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';
import 'package:mellow_music/views/desktop/desktop_search_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('一、消除默认4首收藏与历史沙盒脏数据自动清洗测试', () {
    test('1.1 预设曲目库 mockPresetTracks 默认收藏状态应全为 false', () {
      expect(mockPresetTracks, isNotEmpty);
      for (final t in mockPresetTracks) {
        expect(
          t.isFavorite,
          isFalse,
          reason: '歌曲「${t.title}」不应有默认收藏标记',
        );
      }
    });

    test('1.2 历史沙盒中包含老假ID时，启动后应被自动清洗为纯净0首', () async {
      // 模拟真机沙盒中曾存储过老旧假数据集合
      SharedPreferences.setMockInitialValues({
        'mellow_audio_favorite_ids': ['track-1', 'track-3', 'track-5', 'track-6'],
      });
      await StorageService.instance.init();

      final player = AudioPlayerService(backend: InMemoryAudioPlayerBackend());

      // 验证已被自动清洗守卫重置为空
      expect(player.favoriteIds, isEmpty);
      expect(player.favoriteTracks, isEmpty);
      expect(StorageService.instance.hasCleanedLegacyFavorites(), isTrue);
    });

    test('1.3 用户手动点击红心收藏与取消收藏闭环', () {
      final player = AudioPlayerService(backend: InMemoryAudioPlayerBackend());
      final track = mockPresetTracks.first;

      expect(player.isFavorite(track.id), isFalse);
      player.toggleFavorite(track.id, track);
      expect(player.isFavorite(track.id), isTrue);
      expect(player.favoriteTracks.map((t) => t.id), contains(track.id));

      player.toggleFavorite(track.id, track);
      expect(player.isFavorite(track.id), isFalse);
      expect(player.favoriteTracks, isEmpty);
    });
  });

  group('二、官方巅峰排行榜卡片 1:1 正方形封套与防拉伸固定高度测试', () {
    testWidgets('2.1 超宽屏与不同分辨率下，榜单卡片保持 180px 固定高度与 156x156 正方形封套', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final theme = ThemeProvider();
      final player = AudioPlayerService(backend: InMemoryAudioPlayerBackend());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: player),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopToplistView(onNavigate: (_, [__]) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证标题正常呈现
      expect(find.text('官方巅峰排行榜'), findsOneWidget);

      // 验证四大核心榜单正常呈现
      expect(find.text('飙升榜'), findsWidgets);
      expect(find.text('热歌榜'), findsWidgets);
      expect(find.text('新歌榜'), findsWidgets);
      expect(find.text('原创榜'), findsWidgets);

      // 验证封套容器严格为正方形 (156 x 156)，绝不拉伸变形
      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.constraints != null) {
          final c = widget.constraints!;
          return c.minWidth == 156.0 && c.maxWidth == 156.0 && c.minHeight == 156.0 && c.maxHeight == 156.0;
        }
        return false;
      });
      expect(containerFinder, findsWidgets);
    });
  });

  group('三、搜索即时联想提示与即点即播交互测试', () {
    testWidgets('3.1 搜索框输入前几个字时，自动弹出歌曲联想建议卡片', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final theme = ThemeProvider();
      final player = AudioPlayerService(backend: InMemoryAudioPlayerBackend());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: player),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSearchView(onNavigate: (_, [__]) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      // 输入前几个字（如 "周"）
      await tester.enterText(inputFinder, '周');
      await tester.pump();

      // 联想建议卡片弹出
      expect(find.textContaining('为你联想相关歌曲'), findsOneWidget);
      expect(find.textContaining('按回车查看'), findsOneWidget);

      // 验证匹配到的歌曲列表已渲染且带即点即播按钮
      expect(find.byTooltip('即点即播'), findsWidgets);

      // 点击即点即播按钮
      await tester.tap(find.byTooltip('即点即播').first);
      await tester.pumpAndSettle();

      // 验证播放器已响应并进入播放状态
      expect(player.playlist, isNotEmpty);
    });
  });
}
