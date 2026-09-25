import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/sources/lx_source_model.dart';
import 'package:mellow_music/core/sources/lx_script_sandbox.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    await LxSourceEngine.instance.initFromStorage();
  });

  tearDown(() {
    // 恢复默认音源引擎状态
    LxSourceEngine.instance.setActiveSource(LxPlatformId.mellow);
    LxSourceEngine.instance.setPreferredQuality(AudioQuality.flac);
  });

  group('1. LX 自定义音源脚本沙箱导入与安全隔离测试', () {
    const validScript = '''
/*!
 * @name 测试社区高保真音源
 * @author MellowDev
 * @version 1.0.8
 * @description 专为测试环境定制的沙箱音源脚本
 * @homepage https://github.com/mellow-music
 */
const supportedQualities = ['128k', '320k', 'flac'];
console.log('Script initialized in sandbox');
''';

    test('解析合法自定义脚本注释头并成功挂载到引擎', () {
      final engine = LxSourceEngine.instance;
      final meta = engine.importScript(validScript, customId: 'test_custom_001');

      expect(meta.id, equals('test_custom_001'));
      expect(meta.name, equals('测试社区高保真音源'));
      expect(meta.author, equals('MellowDev'));
      expect(meta.version, equals('1.0.8'));
      expect(meta.isBuiltIn, isFalse);
      expect(meta.isEnabled, isTrue);

      // 验证已注册到引擎驱动映射表中
      expect(engine.drivers.containsKey('test_custom_001'), isTrue);
      final driver = engine.getDriver('test_custom_001');
      expect(driver, isNotNull);
      expect(driver!.metadata.name, equals('测试社区高保真音源'));

      // 卸载清理
      engine.unregisterDriver('test_custom_001');
      expect(engine.drivers.containsKey('test_custom_001'), isFalse);
    });

    test('沙箱防注入检测：拒绝空脚本与非法格式', () {
      final engine = LxSourceEngine.instance;

      expect(
        () => engine.importScript('   \n  '),
        throwsA(isA<LxSourceException>().having((e) => e.type, 'type', LxSourceErrorType.scriptError)),
      );
    });

    test('沙箱防恶意代码检测：阻断包含 eval / child_process 的危险脚本', () {
      final engine = LxSourceEngine.instance;

      const dangerousEvalScript = '''
/*!
 * @name 恶意探测音源
 * @version 1.0.0
 */
eval("stealData()");
''';

      expect(
        () => engine.importScript(dangerousEvalScript),
        throwsA(isA<LxSourceException>().having((e) => e.type, 'type', LxSourceErrorType.scriptError)),
      );

      const dangerousProcessScript = '''
/*!
 * @name 恶意系统注入脚本
 * @version 1.0.0
 */
const proc = require('child_process');
proc.exec('calc.exe');
''';

      expect(
        () => engine.importScript(dangerousProcessScript),
        throwsA(isA<LxSourceException>().having((e) => e.type, 'type', LxSourceErrorType.scriptError)),
      );
    });
  });

  group('2. 音源生命周期、切换与智能降级测试', () {
    test('主音源动态切换与设为主源约束', () {
      final engine = LxSourceEngine.instance;

      // 切换至酷狗 kg
      engine.setActiveSource('kg');
      expect(engine.activeSourceId, equals('kg'));
      expect(StorageService.instance.getActiveSourceId(), equals('kg'));

      // 尝试切换至不存在的源抛出异常
      expect(
        () => engine.setActiveSource('non_existent_source'),
        throwsA(isA<LxSourceException>().having((e) => e.type, 'type', LxSourceErrorType.notFound)),
      );

      // 停用 kg 后，尝试设为主源应抛出异常
      engine.setSourceEnabled('kg', false);
      expect(
        () => engine.setActiveSource('kg'),
        throwsA(isA<LxSourceException>().having((e) => e.type, 'type', LxSourceErrorType.sourceDisabled)),
      );

      // 恢复启用
      engine.setSourceEnabled('kg', true);
      engine.setActiveSource('mellow');
    });

    test('卸载当前激活的主音源时自动平滑回退至官方 mellow 音源', () {
      final engine = LxSourceEngine.instance;

      const tempScript = '''
/*!
 * @name 临时主音源
 * @version 0.9.1
 * @author TempTester
 */
''';
      final meta = engine.importScript(tempScript, customId: 'temp_active_01');
      engine.setActiveSource(meta.id);
      expect(engine.activeSourceId, equals('temp_active_01'));

      // 卸载该激活音源
      engine.unregisterDriver('temp_active_01');
      // 验证主音源已安全自动回退至官方 mellow
      expect(engine.activeSourceId, equals('mellow'));
      expect(StorageService.instance.getActiveSourceId(), equals('mellow'));
    });

    test('全局首选音质变更与降级阶梯持久化', () {
      final engine = LxSourceEngine.instance;

      engine.setPreferredQuality(AudioQuality.flac24bit);
      expect(engine.preferredQuality, equals(AudioQuality.flac24bit));
      expect(StorageService.instance.getPreferredQuality(), equals('flac24bit'));

      engine.setPreferredQuality(AudioQuality.k320k);
      expect(engine.preferredQuality, equals(AudioQuality.k320k));
      expect(StorageService.instance.getPreferredQuality(), equals('320k'));
    });

    test('智能音质阶梯降级链解析 resolveMusicUrlWithFallback', () async {
      final engine = LxSourceEngine.instance;

      // 寻找官方曲目
      final searchResult = await engine.searchAggregated('云水禅心');
      expect(searchResult.list, isNotEmpty);
      final song = searchResult.list.first;

      // 1. 请求官方源原生支持的 flac24bit 母带
      final res24bit = await engine.resolveMusicUrlWithFallback(
        song,
        quality: AudioQuality.flac24bit,
      );
      expect(res24bit.quality, equals(AudioQuality.flac24bit));
      expect(res24bit.url, isNotEmpty);

      // 2. 挂载一个仅支持 128k 的音源驱动并设为主音源
      const lowSong = LxSongInfo(
        id: 'low_1',
        songMid: 'low_1',
        title: '稻香',
        artist: '周杰伦',
        album: '魔杰座',
        duration: Duration(seconds: 223),
        source: 'low_q_source',
        availableQualities: [AudioQuality.k128k],
      );

      final lowQualityDriver = PlatformPresetSourceDriver(
        platformId: 'low_q_source',
        platformName: '低音质测试源',
        qualities: [AudioQuality.k128k],
        mockSongs: [lowSong],
      );
      engine.registerDriver(lowQualityDriver);
      engine.setActiveSource('low_q_source');

      // 即使请求 flac24bit，也能平滑阶梯降级至 low_q_source 的 128k
      final degradedRes = await engine.resolveMusicUrlWithFallback(
        lowSong,
        quality: AudioQuality.flac24bit,
      );
      expect(degradedRes.quality, equals(AudioQuality.k128k));
      expect(degradedRes.url, isNotEmpty);

      // 清理
      engine.setActiveSource('mellow');
      engine.unregisterDriver('low_q_source');
    });
  });

  group('3. 持久化存储与冷启动恢复 (Cold Start Recovery) 测试', () {
    test('重启/重新初始化后自动恢复自定义音源与配置', () async {
      final engine = LxSourceEngine.instance;

      const persistentScript = '''
/*!
 * @id persist_src_01
 * @name 持久化保存音源
 * @author AutoPersist
 * @version 3.3.3
 */
''';
      final meta = engine.importScript(persistentScript, customId: 'persist_src_01');
      engine.setActiveSource(meta.id);
      engine.setPreferredQuality(AudioQuality.k320k);

      // 验证 SharedPreferences 中已有数据
      final savedScripts = StorageService.instance.getCustomScripts();
      expect(savedScripts, isNotNull);
      expect(savedScripts!.any((s) => s.contains('持久化保存音源')), isTrue);

      // 模拟应用冷启动：重新创建并初始化引擎
      final newEngine = LxSourceEngine();
      await newEngine.initFromStorage();

      // 验证状态完全恢复
      expect(newEngine.activeSourceId, equals('persist_src_01'));
      expect(newEngine.preferredQuality, equals(AudioQuality.k320k));
      expect(newEngine.drivers.containsKey('persist_src_01'), isTrue);
      expect(newEngine.getDriver('persist_src_01')!.metadata.name, equals('持久化保存音源'));

      // 清理
      engine.setActiveSource('mellow');
      engine.unregisterDriver('persist_src_01');
    });
  });

  group('4. DesktopSourceManagerView UI 交互与音质切换组件测试', () {
    testWidgets('桌面端音源管理页完整渲染与音质切换响应', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSourceManagerView(onNavigate: (page, [extra]) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证标题与组件渲染
      expect(find.text('音源引擎与外部脚本管理'), findsOneWidget);
      expect(find.text('全局首选音质偏好'), findsOneWidget);
      expect(find.text('脚本静态安全校验已启用'), findsOneWidget);
      expect(find.text('导入自定义脚本'), findsOneWidget);

      // 验证官方六维音源卡片与方案 A 默认落雪聚合音源卡片渲染
      expect(find.textContaining('官方预设与多平台音源'), findsOneWidget);
      expect(find.text('润音内置基准源'), findsNothing);
      expect(find.text('酷我音乐'), findsOneWidget);
      expect(find.text('QQ音乐'), findsOneWidget);
      expect(find.text('网易云音乐'), findsOneWidget);
      expect(find.text('默认落雪聚合音源'), findsNWidgets(2)); // 当前主音源指示器与扩展音源卡片
      // 诚实化标注：脚本仅解析元数据，不执行 JS
      expect(find.text('仅解析注释头元数据 · 不执行 JS 代码'), findsOneWidget);

      // 点击切换全局音质偏好至 320K
      final chip320 = find.text('320K · 高品质');
      expect(chip320, findsOneWidget);
      await tester.tap(chip320);
      await tester.pumpAndSettle();

      expect(LxSourceEngine.instance.preferredQuality, equals(AudioQuality.k320k));

      // 点击切换全局音质偏好至 Hi-Res
      final chipHiRes = find.text('Hi-Res · 母带');
      expect(chipHiRes, findsOneWidget);
      await tester.tap(chipHiRes);
      await tester.pumpAndSettle();

      expect(LxSourceEngine.instance.preferredQuality, equals(AudioQuality.flac24bit));
    });
  });

  group('5. 落雪音源方案 A（开箱即用内置默认源）专项验证', () {
    test('未导入任何脚本时冷启动自动挂载默认落雪音源且默认激活', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.init();
      final engine = LxSourceEngine.instance;
      await engine.initFromStorage();

      // 验证已自动装载默认落雪音源
      expect(engine.drivers.containsKey('lx_default_aggregate'), isTrue);
      final defaultDriver = engine.getDriver('lx_default_aggregate');
      expect(defaultDriver, isNotNull);
      expect(defaultDriver!.metadata.name, equals('默认落雪聚合音源'));
      expect(defaultDriver.metadata.version, equals('2.0.0'));
      expect(defaultDriver.metadata.author, equals('MellowLxCommunity'));
      expect(defaultDriver.metadata.isEnabled, isTrue);
      expect(defaultDriver.metadata.isBuiltIn, isFalse);

      // 验证主音源自动设为落雪默认聚合源
      expect(engine.activeSourceId, equals('lx_default_aggregate'));

      // 验证支持的音质覆盖全档位
      expect(
        defaultDriver.metadata.supportedQualities,
        containsAll([AudioQuality.k128k, AudioQuality.k320k, AudioQuality.flac, AudioQuality.flac24bit]),
      );
    });
  });
}
