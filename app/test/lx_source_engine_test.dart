import 'package:flutter_test/flutter_test.dart';
import 'package:mellow_music/core/sources/lx_source_model.dart';
import 'package:mellow_music/core/sources/lx_script_sandbox.dart';

void main() {
  group('1. AudioQuality 音质档位与降级链模型测试', () {
    test('音质枚举基础属性与比特率断言', () {
      expect(AudioQuality.k128k.value, equals('128k'));
      expect(AudioQuality.k128k.bitrate, equals(128));

      expect(AudioQuality.k320k.value, equals('320k'));
      expect(AudioQuality.k320k.bitrate, equals(320));

      expect(AudioQuality.flac.value, equals('flac'));
      expect(AudioQuality.flac.bitrate, equals(960));

      expect(AudioQuality.flac24bit.value, equals('flac24bit'));
      expect(AudioQuality.flac24bit.bitrate, equals(1920));
    });

    test('音质回退降级链 (Fallback Chain) 严格有序性断言', () {
      // 24bit 母带降级链: flac -> 320k -> 128k
      expect(
        AudioQuality.flac24bit.fallbackChain,
        equals([AudioQuality.flac, AudioQuality.k320k, AudioQuality.k128k]),
      );

      // FLAC 无损降级链: 320k -> 128k
      expect(
        AudioQuality.flac.fallbackChain,
        equals([AudioQuality.k320k, AudioQuality.k128k]),
      );

      // 320K 降级链: 128k
      expect(
        AudioQuality.k320k.fallbackChain,
        equals([AudioQuality.k128k]),
      );

      // 128K 最低档位降级链为空
      expect(AudioQuality.k128k.fallbackChain, isEmpty);
    });

    test('字符串兼容解析 AudioQuality.fromString 断言', () {
      expect(AudioQuality.fromString('128k'), equals(AudioQuality.k128k));
      expect(AudioQuality.fromString('320K'), equals(AudioQuality.k320k));
      expect(AudioQuality.fromString('flac'), equals(AudioQuality.flac));
      expect(AudioQuality.fromString('lossless'), equals(AudioQuality.flac));
      expect(AudioQuality.fromString('flac24bit'), equals(AudioQuality.flac24bit));
      expect(AudioQuality.fromString('Hi-Res'), equals(AudioQuality.flac24bit));
      expect(AudioQuality.fromString('unknown_val'), equals(AudioQuality.k128k));
    });
  });

  group('2. 音源元数据与曲目模型双向互通测试', () {
    test('从 JS 注释头自动解析元数据 LxSourceMetadata.fromScriptHeader', () {
      const script = '''
/*!
 * @name 洛雪六音终极解析脚本
 * @description 跨平台六维无损高保真解析
 * @version 2.5.0
 * @author SixSoundGroup
 * @homepage https://github.com/lyswhut/lx-music-desktop
 */
console.log('Script loaded');
''';
      final meta = LxSourceMetadata.fromScriptHeader(script);
      expect(meta.name, equals('洛雪六音终极解析脚本'));
      expect(meta.description, equals('跨平台六维无损高保真解析'));
      expect(meta.version, equals('2.5.0'));
      expect(meta.author, equals('SixSoundGroup'));
      expect(meta.homepage, equals('https://github.com/lyswhut/lx-music-desktop'));
      expect(meta.isEnabled, isTrue);
      expect(meta.isBuiltIn, isFalse);
    });

    test('LxSongInfo 与 Track 核心模型双向无损互转', () {
      const songInfo = LxSongInfo(
        id: 'kw_1001',
        songMid: '1001',
        title: '云水禅心',
        artist: '古筝佛音',
        album: '禅茶一味',
        source: 'kw',
        duration: Duration(minutes: 4, seconds: 28),
        coverUrl: 'https://example.com/cover.jpg',
      );

      // 转为播放底座 Track
      final track = songInfo.toTrack(audioUrl: 'https://example.com/stream.flac');
      expect(track.id, equals('kw_1001'));
      expect(track.title, equals('云水禅心'));
      expect(track.artist, equals('古筝佛音'));
      expect(track.album, equals('禅茶一味'));
      expect(track.source, equals('kw'));
      expect(track.audioUrl, equals('https://example.com/stream.flac'));

      // 从 Track 转回 LxSongInfo
      final reversed = LxSongInfo.fromTrack(track);
      expect(reversed.id, equals(songInfo.id));
      expect(reversed.title, equals(songInfo.title));
      expect(reversed.artist, equals(songInfo.artist));
      expect(reversed.source, equals(songInfo.source));
    });

    test('LxLyricResult 歌词解析与翻译对齐测试', () {
      const lrc = '''
[00:00.00]云水禅心
[00:02.00]清风拂过绿水
[00:06.50]指尖拨弄琴弦
''';
      const tlyric = '''
[00:02.00]Gentle breeze ripples green water
[00:06.50]Fingers pluck the strings
''';
      const result = LxLyricResult(
        songId: 'kw_1001',
        lyric: lrc,
        tlyric: tlyric,
      );

      final lines = result.toLyricLines();
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('云水禅心'));
      expect(lines[0].translation, isNull);

      expect(lines[1].text, equals('清风拂过绿水'));
      expect(lines[1].translation, equals('Gentle breeze ripples green water'));

      expect(lines[2].text, equals('指尖拨弄琴弦'));
      expect(lines[2].translation, equals('Fingers pluck the strings'));
    });
  });

  group('3. 六维官方预设音源驱动体系测试', () {
    late LxSourceEngine engine;

    setUp(() {
      engine = LxSourceEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('六大音源默认全部初始化并注册', () {
      final sources = engine.registeredSources;
      expect(sources.length, equals(6));

      final ids = sources.map((s) => s.id).toSet();
      expect(ids, containsAll(['mellow', 'kw', 'kg', 'tx', 'wy', 'mg']));

      // 默认主音源为 mellow
      expect(engine.activeSourceId, equals('mellow'));
    });

    test('维度 1: 歌曲搜索能力 (精确与模糊匹配)', () async {
      final res = await engine.search('云水禅心', sourceId: 'mellow');
      expect(res.total, greaterThanOrEqualTo(1));
      expect(res.list.first.title, equals('云水禅心'));
      expect(res.list.first.artist, equals('古筝佛音'));
      expect(res.source, equals('mellow'));
    });

    test('维度 2: 多音质音乐 URL 解析', () async {
      final searchRes = await engine.search('云水禅心', sourceId: 'mellow');
      final song = searchRes.list.first;

      final url128 = await engine.activeDriver.getMusicUrl(song, AudioQuality.k128k);
      expect(url128, isNotNull);
      expect(url128, contains('128k'));

      final urlFlac24 = await engine.activeDriver.getMusicUrl(song, AudioQuality.flac24bit);
      expect(urlFlac24, isNotNull);
      expect(urlFlac24, contains('flac24bit'));
    });

    test('维度 3: 动态歌词拉取', () async {
      final searchRes = await engine.search('云水禅心', sourceId: 'mellow');
      final song = searchRes.list.first;

      final lyric = await engine.getLyricWithFallback(song);
      expect(lyric.lyric, contains('清风拂过绿水'));
      expect(lyric.tlyric, isNotNull);
      expect(lyric.lxlyric, isNotNull);
    });

    test('维度 4: 专辑封面拉取', () async {
      final searchRes = await engine.search('云水禅心', sourceId: 'mellow');
      final song = searchRes.list.first;

      final pic = await engine.getPicWithFallback(song);
      expect(pic, isNotNull);
      expect(pic, startsWith('http'));
    });

    test('维度 5: 排行榜单列表与榜单曲目抓取', () async {
      final boards = await engine.getLeaderboards(sourceId: 'mellow');
      expect(boards.length, equals(4));
      expect(boards.map((b) => b.id), contains('mellow_top_rise'));

      final detail = await engine.getLeaderboardDetail('mellow_top_rise', sourceId: 'mellow');
      expect(detail.board.name, contains('飙升'));
      expect(detail.songs, isNotEmpty);
      expect(detail.songs.first.title, equals('云水禅心'));
    });

    test('维度 6: 歌单广场抓取与歌单详情', () async {
      final playlists = await engine.getPlaylists(sourceId: 'mellow');
      expect(playlists, isNotEmpty);
      expect(playlists.first.tags, contains('国风'));

      final detail = await engine.getPlaylistDetail(playlists.first.id, sourceId: 'mellow');
      expect(detail.playlist.title, equals(playlists.first.title));
      expect(detail.songs, isNotEmpty);
    });
  });

  group('4. 第三方自定义脚本沙箱与导入测试', () {
    late LxSourceEngine engine;

    setUp(() {
      engine = LxSourceEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('导入有效第三方 JS 脚本并成功调用六维能力', () async {
      const validScript = '''
/*!
 * @name 六音自定义聚合源
 * @description 第三方开源音源脚本
 * @version 1.0.0
 * @author Community
 */
console.log('Custom script initialized');
''';

      final meta = engine.importScript(validScript, customId: 'six_custom_01');
      expect(meta.id, equals('six_custom_01'));
      expect(meta.name, equals('六音自定义聚合源'));
      expect(engine.registeredSources.map((s) => s.id), contains('six_custom_01'));

      // 调用自定义脚本的搜索
      final searchRes = await engine.search('青花瓷', sourceId: 'six_custom_01');
      expect(searchRes.total, equals(1));
      expect(searchRes.list.first.title, equals('青花瓷'));
      expect(searchRes.list.first.source, equals('six_custom_01'));

      // 解析 URL
      final url = await engine.resolveMusicUrlWithFallback(
        searchRes.list.first,
        quality: AudioQuality.k320k,
      );
      expect(url.url, contains('custom-cdn.six_custom_01.com'));
      expect(url.quality, equals(AudioQuality.k320k));
    });

    test('导入空内容脚本抛出 LxSourceException 容错拦截', () {
      expect(
        () => engine.importScript('   '),
        throwsA(isA<LxSourceException>()),
      );
    });
  });

  group('5. 全网多平台聚合搜索 (searchAggregated) 测试', () {
    late LxSourceEngine engine;

    setUp(() {
      engine = LxSourceEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('并发向 6 大音源搜索并进行去重聚合', () async {
      final aggRes = await engine.searchAggregated('云水禅心');
      expect(aggRes.source, equals('aggregated'));
      expect(aggRes.total, greaterThanOrEqualTo(1));

      // 验证去重逻辑：聚合结果中不应存在标题与歌手完全相同的重复项
      final titles = aggRes.list.map((s) => '${s.title}_${s.artist}').toList();
      final uniqueTitles = titles.toSet().toList();
      expect(titles.length, equals(uniqueTitles.length));
    });

    test('单个音源网络故障时，聚合搜索具备容错隔离', () async {
      // 注册一个总是失败的音源
      final faultyDriver = PlatformPresetSourceDriver(
        platformId: 'faulty_src',
        platformName: '故障模拟音源',
        qualities: [AudioQuality.k128k],
        mockSongs: [],
        simulateFailure: true,
      );
      engine.registerDriver(faultyDriver);

      // 聚合搜索不应抛出异常，其他正常源仍正常返回
      final res = await engine.searchAggregated('云水禅心');
      expect(res.total, greaterThanOrEqualTo(1));
    });
  });

  group('6. 六维音源动态切换与双重容错降级核心机制测试', () {
    late LxSourceEngine engine;

    setUp(() {
      engine = LxSourceEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('场景 A: 音质平滑降级 (Quality Fallback)', () async {
      // 场景：歌曲《星空下的低语》仅支持 [128k, 320k, flac]，不支持 flac24bit
      final searchRes = await engine.search('星空下的低语', sourceId: 'mellow');
      final song = searchRes.list.first;

      // 用户强制请求 flac24bit
      final result = await engine.resolveMusicUrlWithFallback(
        song,
        quality: AudioQuality.flac24bit,
        sourceId: 'mellow',
        enableSourceFallback: false, // 暂不跨源，测试纯音质降级
      );

      // 断言发生音质降级并成功命中最高可用音质 FLAC
      expect(result.isQualityFallback, isTrue);
      expect(result.quality, equals(AudioQuality.flac));
      expect(result.requestedQuality, equals(AudioQuality.flac24bit));
      expect(result.source, equals('mellow'));
      expect(result.isSourceFallback, isFalse);
      expect(result.fallbackChain, contains('mellow@flac24bit'));
      expect(result.fallbackChain, contains('mellow@flac'));
    });

    test('场景 B: 跨源智能热切与轮询换源 (Source Hot-Switch Fallback)', () async {
      // 注册一个模拟网络超时的故障音源
      final brokenDriver = PlatformPresetSourceDriver(
        platformId: 'broken_source',
        platformName: '断流故障源',
        qualities: [AudioQuality.flac],
        mockSongs: [],
        simulateFailure: true,
      );
      engine.registerDriver(brokenDriver);

      const song = LxSongInfo(
        id: 'broken_001',
        songMid: 'sample_01',
        title: '云水禅心',
        artist: '古筝佛音',
        album: '禅茶一味',
        source: 'broken_source',
        duration: Duration(minutes: 4),
      );

      // 请求故障源，开启跨源降级
      final result = await engine.resolveMusicUrlWithFallback(
        song,
        quality: AudioQuality.flac,
        sourceId: 'broken_source',
        enableSourceFallback: true,
      );

      // 断言发生跨源热切换源
      expect(result.isSourceFallback, isTrue);
      expect(result.requestedSource, equals('broken_source'));
      // 成功热切至其他可用源 (如 kw 或 mellow)
      expect(result.source, isNot(equals('broken_source')));
      expect(result.url, isNotEmpty);
      expect(result.fallbackChain, contains('broken_source@flac[ERROR:LxSourceException]'));
    });

    test('场景 C: 极端情况双重降级 (同时发生音质降级与跨源热切)', () async {
      // 故障源首发失败，备用源仅支持 128k
      final limitedDriver = PlatformPresetSourceDriver(
        platformId: 'limited_source',
        platformName: '仅限标准音质源',
        qualities: [AudioQuality.k128k],
        mockSongs: [
          const LxSongInfo(
            id: 'lim_01',
            songMid: 'lim_01',
            title: '特别歌曲',
            artist: '特别歌手',
            album: '单曲',
            source: 'limited_source',
            duration: Duration(minutes: 3),
            availableQualities: [AudioQuality.k128k],
          ),
        ],
      );
      final failingDriver = PlatformPresetSourceDriver(
        platformId: 'failing_source',
        platformName: '直接报错源',
        qualities: [AudioQuality.flac24bit],
        mockSongs: [],
        simulateFailure: true,
      );

      final cleanEngine = LxSourceEngine();
      // 清理其他源，只留下这两个做精确控制
      for (final s in cleanEngine.registeredSources) {
        cleanEngine.unregisterDriver(s.id);
      }
      cleanEngine.registerDriver(failingDriver);
      cleanEngine.registerDriver(limitedDriver);

      const testSong = LxSongInfo(
        id: 'test_song',
        songMid: 'lim_01',
        title: '特别歌曲',
        artist: '特别歌手',
        album: '单曲',
        source: 'failing_source',
        duration: Duration(minutes: 3),
      );

      final result = await cleanEngine.resolveMusicUrlWithFallback(
        testSong,
        quality: AudioQuality.flac24bit,
        sourceId: 'failing_source',
      );

      expect(result.isSourceFallback, isTrue);
      expect(result.isQualityFallback, isTrue);
      expect(result.source, equals('limited_source'));
      expect(result.quality, equals(AudioQuality.k128k));

      cleanEngine.dispose();
    });

    test('场景 D: 所有源均不可用时抛出明确包含尝试链路的 LxSourceException', () async {
      const nonExistentSong = LxSongInfo(
        id: 'no_such_song',
        songMid: '999999',
        title: '完全不存在的绝版未知歌曲',
        artist: '神秘人',
        album: '无',
        source: 'kw',
        duration: Duration(seconds: 10),
      );

      // 创建一个只含有故障源的 engine
      final emptyEngine = LxSourceEngine();
      for (final s in emptyEngine.registeredSources) {
        emptyEngine.unregisterDriver(s.id);
      }
      emptyEngine.registerDriver(PlatformPresetSourceDriver(
        platformId: 'kw',
        platformName: '酷我',
        qualities: [AudioQuality.k128k],
        mockSongs: [],
      ));

      expect(
        () async => await emptyEngine.resolveMusicUrlWithFallback(nonExistentSong),
        throwsA(isA<LxSourceException>().having(
          (e) => e.message,
          'message',
          contains('无法解析曲目直链'),
        )),
      );

      emptyEngine.dispose();
    });
  });

  group('7. 音源动态切换、启停控制与健康检测测试', () {
    late LxSourceEngine engine;

    setUp(() {
      engine = LxSourceEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('切换当前主音源与音质偏好', () {
      expect(engine.activeSourceId, equals('mellow'));

      engine.setActiveSource('tx');
      expect(engine.activeSourceId, equals('tx'));
      expect(engine.activeDriver.metadata.name, equals('QQ音乐'));

      engine.preferredQuality = AudioQuality.flac24bit;
      expect(engine.preferredQuality, equals(AudioQuality.flac24bit));
    });

    test('音源停用 (setSourceEnabled) 与主源自动回退保护', () {
      engine.setActiveSource('kw');
      expect(engine.activeSourceId, equals('kw'));

      // 停用当前主音源 kw
      engine.setSourceEnabled('kw', false);
      expect(engine.getDriver('kw')!.metadata.isEnabled, isFalse);

      // 主音源自动安全回退至 mellow 官方源
      expect(engine.activeSourceId, equals('mellow'));

      // 尝试将已停用的源设为主源应抛出异常
      expect(
        () => engine.setActiveSource('kw'),
        throwsA(isA<LxSourceException>()),
      );
    });

    test('音源健康探活检测 testSourceHealth', () async {
      final isHealthy = await engine.testSourceHealth('mellow');
      expect(isHealthy, isTrue);

      final brokenDriver = PlatformPresetSourceDriver(
        platformId: 'dead_source',
        platformName: '离线源',
        qualities: [AudioQuality.k128k],
        mockSongs: [],
        simulateFailure: true,
      );
      engine.registerDriver(brokenDriver);

      final isBrokenHealthy = await engine.testSourceHealth('dead_source');
      expect(isBrokenHealthy, isFalse);
    });

    test('事件流广播监听 onEvent', () async {
      final events = <String>[];
      final sub = engine.onEvent.listen(events.add);

      engine.setActiveSource('tx');
      engine.preferredQuality = AudioQuality.k320k;

      await Future.delayed(const Duration(milliseconds: 50));
      expect(events, contains(contains('主音源已切换至: QQ音乐')));
      expect(events, contains(contains('音质首选项已切换为: 320K 高品质')));

      await sub.cancel();
    });
  });
}
