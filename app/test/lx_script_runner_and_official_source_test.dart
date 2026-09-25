import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/sources/lx_source_model.dart';
import 'package:mellow_music/core/sources/lx_script_runner.dart';
import 'package:mellow_music/core/sources/lx_official_driver.dart';
import 'package:mellow_music/core/sources/lx_script_sandbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. LxScriptRunner 脚本与配置解析器测试 (Alger & LX-Music)', () {
    test('isAlgerJsonConfig 识别 Alger 声明式 JSON 配置', () {
      const validAlgerJson = '''
      {
        "name": "Alger自定义音源",
        "author": "Alger",
        "version": "1.0.0",
        "apiUrl": "https://api.example.com/music",
        "responseUrlPath": "data.url"
      }
      ''';
      expect(LxScriptRunner.isAlgerJsonConfig(validAlgerJson), isTrue);

      const invalidJson = 'function() { return "hello"; }';
      expect(LxScriptRunner.isAlgerJsonConfig(invalidJson), isFalse);

      const noApiJson = '{"name": "test"}';
      expect(LxScriptRunner.isAlgerJsonConfig(noApiJson), isFalse);
    });

    test('extractUrlByPath 嵌套 JSON 字段安全提取', () {
      final jsonStr = jsonEncode({
        'code': 200,
        'data': {
          'music': {
            'playUrl': 'https://music.source.com/song_320k.mp3'
          }
        }
      });
      final url = LxScriptRunner.extractUrlByPath(jsonStr, 'data.music.playUrl');
      expect(url, equals('https://music.source.com/song_320k.mp3'));

      final fallback = LxScriptRunner.extractUrlByPath(jsonStr, 'data.nonexistent.url');
      expect(fallback, isNull);
    });

    test('resolveAlgerJsonUrl 占位符替换与网络取流解析', () async {
      final algerConfig = {
        'name': 'Alger测试源',
        'apiUrl': 'https://api.test.com/get',
        'params': {
          'songId': '{songId}',
          'quality': '{quality}',
          'source': '{source}',
        },
        'responseUrlPath': 'data.url',
      };

      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['songId'], equals('123456'));
        expect(request.url.queryParameters['quality'], equals('320k'));
        expect(request.url.queryParameters['source'], equals('wy'));

        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {'url': 'https://res.test.com/123456_320.mp3'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final runner = LxScriptRunner(client: mockClient);
      final url = await runner.resolveAlgerJsonUrl(
        config: algerConfig,
        songId: '123456',
        songMid: '123456',
        quality: AudioQuality.k320k,
        source: 'wy',
      );

      expect(url, equals('https://res.test.com/123456_320.mp3'));
    });

    test('extractScriptEndpoint 从落雪 JS 脚本中提取有效 API 端点', () {
      const lxScript = '''
      /*!
       * @name 六音落雪源
       * @version 1.0.0
       */
      const API_URL = "https://lx.sixyin.com/api";
      function getMusicUrl() {}
      ''';

      final endpoint = LxScriptRunner.extractScriptEndpoint(lxScript);
      expect(endpoint?.baseUrl, equals('https://lx.sixyin.com/api'));

      const fallbackScript = 'function test() {}';
      expect(LxScriptRunner.extractScriptEndpoint(fallbackScript), isNull);
    });

    test('resolveLxScriptUrl 从落雪端点请求真实直链并遵循降级', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('flac')) {
          // 模拟无损暂无，返回 404 触发降级
          return http.Response('{"code": 404, "msg": "no flac"}', 404);
        }
        if (request.url.path.contains('320k')) {
          return http.Response(
            jsonEncode({'code': 0, 'data': {'url': 'https://stream.lx.com/320k_play.mp3'}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      const song = LxSongInfo(
        id: 'kw_998877',
        songMid: '998877',
        title: '晴天',
        artist: '周杰伦',
        album: '叶惠美',
        source: 'kw',
        duration: Duration(minutes: 4, seconds: 29),
      );

      final runner = LxScriptRunner(client: mockClient);
      const endpoint = LxScriptEndpoint(
        baseUrl: 'https://lx.endpoint.com',
        supportedSources: ['kw', 'wy'],
        supportedQualities: [AudioQuality.flac, AudioQuality.k320k, AudioQuality.k128k],
      );
      final url = await runner.resolveLxScriptUrl(
        endpoint: endpoint,
        source: song.source,
        songId: song.id,
        songMid: song.songMid,
        quality: AudioQuality.flac,
        title: song.title,
        artist: song.artist,
      );

      expect(url, equals('https://stream.lx.com/320k_play.mp3'));
    });
  });

  group('2. LxOfficialSourceDriver 官方内置音源驱动测试', () {
    test('驱动元数据与支持音质验证', () {
      final driver = LxOfficialSourceDriver();
      expect(driver.metadata.id, equals('lx_official_builtin'));
      expect(driver.metadata.name, contains('落雪官方'));
      expect(driver.metadata.isBuiltIn, isTrue);

      expect(driver.metadata.supportedQualities.contains(AudioQuality.k128k), isTrue);
      expect(driver.metadata.supportedQualities.contains(AudioQuality.k320k), isTrue);
      expect(driver.metadata.supportedQualities.contains(AudioQuality.flac), isTrue);
      expect(driver.metadata.supportedQualities.contains(AudioQuality.flac24bit), isTrue);
    });

    test('getMusicUrl 真实调度网易云与酷我 API', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('music.163.com')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': [
                {
                  'id': 1001,
                  'url': 'https://m701.music.126.net/real_audio.mp3',
                  'br': 320000,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final driver = LxOfficialSourceDriver(client: mockClient);
      const song = LxSongInfo(
        id: 'netease_1001',
        songMid: '1001',
        title: '海阔天空',
        artist: 'Beyond',
        album: '海阔天空',
        source: 'wy',
        duration: Duration(minutes: 5, seconds: 24),
      );

      final playUrl = await driver.getMusicUrl(song, AudioQuality.k320k);
      expect(playUrl, isNotNull);
      expect(playUrl, equals('https://m701.music.126.net/real_audio.mp3'));
    });

    test('getPic 与 getLeaderboards 正确返回', () async {
      final driver = LxOfficialSourceDriver();
      const songWithPic = LxSongInfo(
        id: '1',
        songMid: '1',
        title: '光辉岁月',
        artist: 'Beyond',
        album: '命运派对',
        source: 'wy',
        duration: Duration(minutes: 5),
        coverUrl: 'https://images.example.com/cover.jpg',
      );

      final pic = await driver.getPic(songWithPic);
      expect(pic, equals('https://images.example.com/cover.jpg'));

      final boards = await driver.getLeaderboards();
      expect(boards.length, greaterThanOrEqualTo(4));
      expect(boards.any((b) => b.name.contains('热歌榜')), isTrue);
      expect(boards.any((b) => b.name.contains('新歌榜')), isTrue);
    });

    test('健康探测 healthCheck 正常连通', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"code": 200}', 200);
      });
      final driver = LxOfficialSourceDriver(client: mockClient);
      final healthy = await driver.healthCheck();
      expect(healthy, isTrue);
    });
  });

  group('3. LxSourceEngine 注册与官方驱动激活验证', () {
    test('registerDriver 挂载官方驱动并激活', () {
      final engine = LxSourceEngine.instance;
      final driver = LxOfficialSourceDriver();
      engine.registerDriver(driver);
      engine.setActiveSource('lx_official_builtin');
      expect(engine.activeSourceId, equals('lx_official_builtin'));
      expect(engine.activeDriver.metadata.id, equals('lx_official_builtin'));
      expect(engine.activeDriver, isA<LxOfficialSourceDriver>());

      final sources = engine.sources;
      expect(sources.any((s) => s.id == 'lx_official_builtin'), isTrue);
    });

    test('importScript 正确挂载并支持落雪 User Script', () {
      final engine = LxSourceEngine.instance;
      const script = '''
      /*!
       * @name 测试落雪外置源
       * @author Tester
       * @version 1.2.0
       * @description 专用单元测试音源
       */
      const API_URL = "https://test.source.com/api";
      function getUrl() {}
      ''';

      final meta = engine.importScript(script);
      expect(meta.name, equals('测试落雪外置源'));
      expect(meta.version, equals('1.2.0'));
      expect(engine.drivers.containsKey(meta.id), isTrue);

      final customDriver = engine.drivers[meta.id];
      expect(customDriver, isA<LxCustomScriptDriver>());

      // 激活自定义音源并测试卸载回退
      engine.setActiveSource(meta.id);
      expect(engine.activeSourceId, equals(meta.id));

      // 清理卸载
      engine.unregisterDriver(meta.id);
      expect(engine.drivers.containsKey(meta.id), isFalse);
      // 卸载后平滑回退至官方源
      expect(engine.activeSourceId, equals(LxPlatformId.mellow));
    });

    test('importScript 正确支持 AlgerMusic 声明式 JSON 配置', () {
      final engine = LxSourceEngine.instance;
      const algerJson = '''
      {
        "name": "Alger播放器特供源",
        "author": "AlgerDev",
        "version": "2.0.0",
        "description": "专为 Alger 格式设计的 API 驱动",
        "apiUrl": "https://api.alger.test/get",
        "responseUrlPath": "data.url"
      }
      ''';

      final meta = engine.importScript(algerJson);
      expect(meta.name, equals('Alger播放器特供源'));
      expect(meta.author, equals('AlgerDev'));
      expect(meta.version, equals('2.0.0'));
      expect(engine.drivers.containsKey(meta.id), isTrue);

      // 激活自定义音源并测试卸载回退
      engine.setActiveSource(meta.id);
      expect(engine.activeSourceId, equals(meta.id));

      // 清理卸载
      engine.unregisterDriver(meta.id);
      expect(engine.activeSourceId, equals(LxPlatformId.mellow));
    });

    test('预装六音高保真无损解析源 (kSixYinAggregateScript)', () {
      final engine = LxSourceEngine.instance;
      final sixyin = LxCustomScriptDriver.fromScript(kSixYinAggregateScript, customId: 'lx_sixyin');
      engine.registerDriver(sixyin);
      expect(engine.drivers.containsKey('lx_sixyin'), isTrue);
      expect(engine.drivers['lx_sixyin']!.metadata.name, equals('六音无损聚合源'));
      expect(engine.drivers['lx_sixyin']!.metadata.author, contains('六音'));
    });
  });

  group('4. AudioPlayerService 音源名称格式化测试', () {
    test('formatSourceDisplayName 准确映射落雪官方源、六音无损源与 Alger 官方源', () {
      expect(AudioPlayerService.formatSourceDisplayName('lx_sixyin'), equals('六音无损源'));
      expect(AudioPlayerService.formatSourceDisplayName('lx_official_builtin'), equals('落雪官方源'));
      expect(AudioPlayerService.formatSourceDisplayName('lx_official'), equals('落雪官方源'));
      expect(AudioPlayerService.formatSourceDisplayName('alger_custom'), equals('Alger官方源'));
      expect(AudioPlayerService.formatSourceDisplayName('kuwo_vip'), equals('酷我高保真'));
      expect(AudioPlayerService.formatSourceDisplayName('netease_cloud'), equals('网易云音乐'));
      expect(AudioPlayerService.formatSourceDisplayName('local_file'), equals('本地音频'));
    });
  });
}
