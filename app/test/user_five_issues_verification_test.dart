import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/audio/player_backend.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';
import 'package:mellow_music/core/sources/scenario_playlist_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/navigation/desktop_scaffold.dart';

void main() {
  group('用户五大核心诉求与体验问题专项验收测试', () {
    test('诉求 1: 各端原生配置文件中的应用显示名称统一为中文名“润音”', () {
      // 1. Android Manifest
      final androidManifest = File('android/app/src/main/AndroidManifest.xml');
      expect(androidManifest.existsSync(), isTrue);
      expect(androidManifest.readAsStringSync().contains('android:label="润音"'), isTrue);

      // 2. iOS Info.plist
      final iosPlist = File('ios/Runner/Info.plist');
      expect(iosPlist.existsSync(), isTrue);
      expect(iosPlist.readAsStringSync().contains('<string>润音</string>'), isTrue);

      // 3. macOS AppInfo.xcconfig
      final macAppInfo = File('macos/Runner/Configs/AppInfo.xcconfig');
      expect(macAppInfo.existsSync(), isTrue);
      expect(macAppInfo.readAsStringSync().contains('PRODUCT_NAME = 润音'), isTrue);

      // 4. Windows Runner.rc
      final winRc = File('windows/runner/Runner.rc');
      expect(winRc.existsSync(), isTrue);
      expect(winRc.readAsStringSync().contains('"润音"'), isTrue);
    });

    testWidgets('诉求 3: PC 桌面端顶栏已精简，彻底移除日夜切换、设置、最小化到托盘 3 个重复按钮', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeProvider = ThemeProvider();
      final audioService = AudioPlayerService(backend: InMemoryAudioPlayerBackend());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: audioService),
          ],
          child: const MaterialApp(
            home: DesktopScaffold(),
          ),
        ),
      );
      await tester.pump();

      // 确保顶栏右上角不再有这三个冗余重复按钮
      expect(find.byTooltip('最小化到托盘'), findsNothing);
      expect(find.byTooltip('切换浅色/深色主题'), findsNothing);
      expect(find.byTooltip('设置'), findsNothing);

      audioService.dispose();
    });

    test('诉求 4: 场景歌单与榜单解除歌曲数量限制 (不人为截断取 10 首或 50 首)', () async {
      final detail = await ScenarioPlaylistService.instance.getScenarioPlaylistDetail('netease_123');
      expect(detail, isNotNull);
      // 验证曲目数量不再被 take(10) 硬编码截断，包含完整的全部曲目
      expect(detail!.tracks.length, greaterThan(10));
    });

    test('诉求 5: 歌词解析引擎宽容度测试 (支持单双位分钟、冒号毫秒、多时间戳展开与标签过滤)', () {
      // 包含多种非常规格式的复杂 LRC 字符串
      const lrcContent = '''
[ti:晴天]
[ar:周杰伦]
[al:叶惠美]
[by:LyricEngine]
[0:15.50]故事的小黄花
[00:20:80]从出生那年就飘着
[00:25.123]童年的荡秋千
[00:30.00][01:00.00]随记忆一直晃到现在
[01:05]刮风这天我试过握着你手
''';

      final lines = LyricLine.parseLrc(lrcContent);
      expect(lines.isNotEmpty, isTrue);

      // 验证元数据标签被正确剔除
      expect(lines.any((l) => l.text.contains('[ti:晴天]')), isFalse);
      expect(lines.any((l) => l.text.contains('[ar:周杰伦]')), isFalse);

      // 验证单数分钟 [0:15.50] 解析成功
      final line1 = lines.firstWhere((l) => l.text == '故事的小黄花');
      expect(line1.time, const Duration(seconds: 15, milliseconds: 500));

      // 验证冒号毫秒 [00:20:80] 解析成功
      final line2 = lines.firstWhere((l) => l.text == '从出生那年就飘着');
      expect(line2.time, const Duration(seconds: 20, milliseconds: 800));

      // 验证三位毫秒 [00:25.123] 解析成功
      final line3 = lines.firstWhere((l) => l.text == '童年的荡秋千');
      expect(line3.time, const Duration(seconds: 25, milliseconds: 123));

      // 验证多时间戳展开：随记忆一直晃到现在 应在两个不同时间点出现
      final repeatedLines = lines.where((l) => l.text == '随记忆一直晃到现在').toList();
      expect(repeatedLines.length, 2);
      expect(repeatedLines[0].time, const Duration(seconds: 30));
      expect(repeatedLines[1].time, const Duration(minutes: 1));

      // 验证单数字整秒 [01:05]
      final line5 = lines.firstWhere((l) => l.text == '刮风这天我试过握着你手');
      expect(line5.time, const Duration(minutes: 1, seconds: 5));

      // 验证按时间线性升序排序
      for (int i = 0; i < lines.length - 1; i++) {
        expect(lines[i].time <= lines[i + 1].time, isTrue);
      }
    });

    test('诉求 5: 智能歌名降噪清洗测试 cleanSongTitle', () {
      expect(OnlineMusicService.cleanSongTitle('晴天 (Live)'), '晴天');
      expect(OnlineMusicService.cleanSongTitle('起风了（电视剧《加油，你是最棒的》主题曲）'), '起风了');
      expect(OnlineMusicService.cleanSongTitle('七里香 [伴奏]'), '七里香');
      expect(OnlineMusicService.cleanSongTitle('孤勇者 - 动画《英雄联盟：双城之战》中文主题曲'), '孤勇者');
      expect(OnlineMusicService.cleanSongTitle('夜曲 (Instrumental)'), '夜曲');
    });
  });
}
