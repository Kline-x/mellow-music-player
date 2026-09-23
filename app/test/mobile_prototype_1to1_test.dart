import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/design_system/mellow_image.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/equalizer_manager.dart';
import 'package:mellow_music/navigation/mobile_scaffold.dart';
import 'package:mellow_music/views/mobile/mobile_sheets.dart';
import 'package:mellow_music/views/mobile/mobile_pages.dart';

void main() {
  setUpAll(() {
    MellowImage.isInTest = true;
  });

  group('Mellow Music · 移动端 1:1 原型图像素级复刻专项验收套件 (media_1789972521518.png)', () {
    late ThemeProvider themeProvider;
    late AudioPlayerService audioService;
    late EqualizerManager equalizerManager;

    setUp(() {
      themeProvider = ThemeProvider();
      audioService = AudioPlayerService();
      audioService.pause();
      equalizerManager = EqualizerManager();
    });

    tearDown(() {
      audioService.pause();
      audioService.dispose();
      equalizerManager.dispose();
    });

    Widget buildMobileApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audioService),
          ChangeNotifierProvider<EqualizerManager>.value(value: equalizerManager),
        ],
        child: MaterialApp(
          title: 'Mellow Music Mobile 1:1',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: themeProvider.canvasColor,
          ),
          home: const MobileScaffold(),
        ),
      );
    }

    testWidgets('MOB-01: 顶部灵动岛 (Dynamic Island) 黑色药丸状态栏与音频频谱交互', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp());
      await tester.pump(const Duration(milliseconds: 300));


      // 2. 验证灵动岛黑色药丸胶囊存在
      expect(find.byKey(const Key('dynamic_island_capsule')), findsOneWidget);
      final currentTrackTitle = audioService.currentTrack!.title;
      expect(find.text(currentTrackTitle), findsWidgets);

      // 3. 点击灵动岛，呼出全屏播放器底部抽屉
      await tester.tap(find.byKey(const Key('dynamic_island_capsule')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证底部全屏播放抽屉弹出
      expect(find.byType(MobilePlayerBottomSheet), findsOneWidget);

      // 关闭抽屉
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('MOB-02: 标题栏徽章、白瓷微拟物日夜切换按钮与全幅药丸搜索框', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证“发现音乐”大粗体与“Mobile”浅蓝胶囊徽章
      expect(find.text('发现音乐'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);

      // 2. 验证白瓷微拟物日夜模式切换按钮
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.wb_sunny_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(themeProvider.isDarkMode, isTrue);

      // 切回亮色模式
      await tester.tap(find.byIcon(Icons.light_mode_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(themeProvider.isDarkMode, isFalse);

      // 3. 验证全幅药丸搜索框与麦克风语音图标
      expect(find.text('搜索歌曲、歌手、专辑、播客...'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      // 4. 点击搜索框进入全屏搜索页面 MobileSearchPage
      await tester.tap(find.text('搜索歌曲、歌手、专辑、播客...'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MobileSearchPage), findsOneWidget);

      // 返回主界面
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MobileSearchPage), findsNothing);
    });

    testWidgets('MOB-03: 五大彩色渐变金刚区大圆角微矩形卡片与二级页下钻', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 验证五大金刚区卡片
      expect(find.text('每日推荐'), findsOneWidget);
      expect(find.text('歌单广场'), findsOneWidget);
      expect(find.text('排行榜'), findsOneWidget);
      expect(find.text('声音电台'), findsOneWidget);
      expect(find.text('私人漫游'), findsOneWidget);

      // 点击“歌单广场”下钻
      await tester.tap(find.text('歌单广场'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证进入歌单广场二级页面
      expect(find.text('歌单广场'), findsWidgets);

      // 返回主页
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('发现音乐'), findsOneWidget);
    });

    testWidgets('MOB-04: “专属雷达 · Daily Mixes” 1 + 4 不对称网格矩阵点播交互', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证标题栏
      expect(find.text('专属雷达 · Daily Mixes'), findsOneWidget);
      expect(find.text('更新于 06:00'), findsOneWidget);

      // 2. 验证左侧大卡片
      expect(find.text('落日微风 · 私人漫游'), findsOneWidget);
      expect(find.text('周杰伦 / 告五人 / M83'), findsOneWidget);

      // 3. 验证右侧 2x2 四张紧凑小卡片
      expect(find.text('午夜霓虹'), findsOneWidget);
      expect(find.text('慢冷治愈'), findsOneWidget);
      expect(find.text('Golden Hour'), findsOneWidget);
      expect(find.text('爱在西元前'), findsOneWidget);

      // 4. 点击小卡片切歌点播
      await tester.tap(find.text('Golden Hour'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证当前播放歌曲切换
      expect(audioService.currentIndex, equals(2));

      // 暂停防止定时器泄漏
      audioService.pause();
    });

    testWidgets('MOB-05: 悬浮毛玻璃胶囊播放条 (内嵌 2px 极细微实时进度条与红心收藏)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. 验证内嵌 2px 极细微进度条存在
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 2. 验证收藏心标交互
      final currentTrack = audioService.currentTrack!;
      final isInitialFav = audioService.isFavorite(currentTrack.id);

      // 点击收藏心标
      await tester.tap(find.byKey(const Key('mini_player_fav_button')));
      await tester.pump(const Duration(milliseconds: 300));

      // 断言收藏状态反转
      expect(audioService.isFavorite(currentTrack.id), equals(!isInitialFav));

      // 3. 点击实心主色播放按钮
      await tester.tap(find.byKey(const Key('mini_player_play_button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(audioService.isPlaying, isTrue);

      // 4. 点击下一首
      await tester.tap(find.byKey(const Key('mini_player_next_button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(audioService.currentIndex, isNot(equals(0)));

      // 暂停防止定时器泄漏
      audioService.pause();
    });

    testWidgets('MOB-06: 底部 4-Tab 毛玻璃原生导航栏切换', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 验证 4-Tab 存在
      expect(find.text('发现'), findsOneWidget);
      expect(find.text('探索'), findsOneWidget);
      expect(find.text('资料库'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);

      // 切换到“探索”
      await tester.tap(find.text('探索'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('探索音乐全库'), findsOneWidget);

      // 切换到“资料库”
      await tester.tap(find.text('资料库'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('我的音乐资料库'), findsOneWidget);

      // 切换到“我的”
      await tester.tap(find.text('我的'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mellow 音乐探索家'), findsOneWidget);
      expect(find.text('温润白瓷'), findsOneWidget);
    });
  });
}
