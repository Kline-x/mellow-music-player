import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mellow_music/core/audio/track_model.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';

/// 统一构造 UTF-8 的假响应，避免中文在 MockClient 中按 latin1 编码。
http.Response _json(String body) => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 构造网易云 /api/song/enhance/player/url 的真实响应体。
String _enhanceBody({
  String? url,
  int br = 0,
  int code = 200,
  int fee = 0,
}) {
  return jsonEncode({
    'data': [
      {
        'id': 1330348068,
        'url': url,
        'br': br,
        'size': 0,
        'md5': null,
        'code': code,
        'fee': fee,
        'type': url == null ? null : 'mp3',
        'level': null,
      },
    ],
    'code': 200,
  });
}

/// 构造网易云 /api/search/get/web 的真实响应体。
String _searchBody() => jsonEncode({
      'result': {
        'songs': [
          {
            'id': 5257138,
            'name': '屋顶',
            'duration': 319039,
            'fee': 8,
            'artists': [
              {'name': '周杰伦'},
              {'name': '温岚'},
            ],
            'album': {'name': '男女情歌对唱冠军全记录', 'picId': 1},
          },
        ],
      },
    });

/// 构造 iTunes 搜索响应体（与网易云同一首歌，用于聚合去重）。
String _itunesBody() => jsonEncode({
      'results': [
        {
          'trackId': 123456,
          'trackName': '屋顶',
          'artistName': '周杰伦、温岚',
          'collectionName': '男女情歌对唱冠军全记录',
          'trackTimeMillis': 30000,
          'previewUrl': 'https://audio-ssl.itunes.apple.com/preview.m4a',
          'artworkUrl100': 'https://is1.mzstatic.com/a/100x100bb.jpg',
        },
      ],
    });

void main() {
  group('NeteaseMusicService.resolveStreamUrl（真实取流解析）', () {
    test('(a) 正常返回 url：解析真实直链、实际码率与请求参数', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _json(_enhanceBody(url: 'http://m801.music.126.net/real-song.mp3', br: 320000));
      });
      final service = NeteaseMusicService(client: client);

      final result = await service.resolveStreamUrl('netease_1330348068');

      expect(captured.url.path, '/api/song/enhance/player/url');
      expect(captured.url.queryParameters['id'], '1330348068');
      expect(captured.url.queryParameters['ids'], '[1330348068]');
      expect(captured.url.queryParameters['br'], '320000');
      expect(captured.headers['Referer'], 'https://music.163.com/');
      expect(captured.headers['User-Agent'], isNotEmpty);

      expect(result.isPlayable, isTrue);
      expect(result.url, 'http://m801.music.126.net/real-song.mp3');
      expect(result.bitrate, 320000);
      expect(result.quality, NeteaseQuality.br320k);
      expect(result.reason, isNull);
    });

    test('(b) url:null + code:-110：返回不可播放与可读原因，不伪造直链', () async {
      final client = MockClient(
        (request) async => _json(_enhanceBody(url: null, code: -110, fee: 1)),
      );
      final service = NeteaseMusicService(client: client);

      final result = await service.resolveStreamUrl('347230');

      expect(result.isPlayable, isFalse);
      expect(result.url, isNull);
      expect(result.bitrate, 0);
      expect(result.quality, isNull);
      expect(result.reason, isNotNull);
      expect(result.reason, contains('无版权'));
    });

    test('(c) 320k/192k 失败后按序降级到 128k，回传实际码率', () async {
      final requested = <int>[];
      final client = MockClient((request) async {
        final br = int.parse(request.url.queryParameters['br']!);
        requested.add(br);
        if (br == 128000) {
          return _json(_enhanceBody(url: 'http://m701.music.126.net/128.mp3', br: 128000));
        }
        return _json(_enhanceBody(url: null, code: -110, fee: 1));
      });
      final service = NeteaseMusicService(client: client);

      final result = await service.resolveStreamUrl('1330348068');

      expect(requested, [320000, 192000, 128000]);
      expect(result.isPlayable, isTrue);
      expect(result.url, 'http://m701.music.126.net/128.mp3');
      expect(result.bitrate, 128000);
      expect(result.quality, NeteaseQuality.br128k);
    });

    test('(c2) 首个档位成功即返回，不再继续降级', () async {
      final requested = <int>[];
      final client = MockClient((request) async {
        requested.add(int.parse(request.url.queryParameters['br']!));
        return _json(_enhanceBody(url: 'http://m801.music.126.net/320.mp3', br: 320000));
      });
      final service = NeteaseMusicService(client: client);

      final result = await service.resolveStreamUrl('1330348068');

      expect(requested, [320000]);
      expect(result.bitrate, 320000);
    });

    test('指定 128k 起步时只请求 128k 档位', () async {
      final requested = <int>[];
      final client = MockClient((request) async {
        requested.add(int.parse(request.url.queryParameters['br']!));
        return _json(_enhanceBody(url: null, code: -110, fee: 1));
      });
      final service = NeteaseMusicService(client: client);

      await service.resolveStreamUrl('1330348068', quality: NeteaseQuality.br128k);

      expect(requested, [128000]);
    });

    test('未知曲目 ID 返回可读原因且不发请求', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _json(_enhanceBody());
      });
      final service = NeteaseMusicService(client: client);

      final result = await service.resolveStreamUrl('not-a-song-id');

      expect(calls, 0);
      expect(result.isPlayable, isFalse);
      expect(result.reason, contains('无法识别'));
    });
  });

  group('NeteaseMusicService 真实接口解析', () {
    test('search 标注 netease-online、直链留空待惰性取流、封面由 detail 真实补齐', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/song/detail') {
          return _json(jsonEncode({
            'songs': [
              {
                'id': 5257138,
                'album': {'picUrl': 'https://p1.music.126.net/cover.jpg'},
              },
            ],
          }));
        }
        return _json(_searchBody());
      });
      final service = NeteaseMusicService(client: client);

      final tracks = await service.search('屋顶');

      expect(tracks, hasLength(1));
      expect(tracks.single.id, 'netease_5257138');
      expect(tracks.single.title, '屋顶');
      expect(tracks.single.artist, '周杰伦 / 温岚');
      expect(tracks.single.source, 'netease-online');
      expect(tracks.single.audioUrl, isNull);
      expect(tracks.single.coverUrl, 'https://p1.music.126.net/cover.jpg');
    });

    test('fetchLyric 解析真实 LRC 文本', () async {
      final client = MockClient(
        (request) async => _json(
          jsonEncode({
            'lrc': {'lyric': '[00:01.000]第一句\n[00:05.500]第二句'},
          }),
        ),
      );
      final service = NeteaseMusicService(client: client);

      final lyrics = await service.fetchLyric('netease_5257138');

      expect(lyrics, hasLength(2));
      expect(lyrics.first.text, '第一句');
      expect(lyrics.last.text, '第二句');
    });
  });

  group('ItunesMusicService（真实 previewUrl 过滤）', () {
    test('无 previewUrl 的条目被丢弃，封面替换为 600x600', () async {
      final client = MockClient(
        (request) async => _json(jsonEncode({
          'results': [
            {
              'trackId': 1,
              'trackName': '有试听',
              'artistName': 'A',
              'previewUrl': 'https://x/1.m4a',
              'trackTimeMillis': 30000,
              'artworkUrl100': 'https://x/100x100bb.jpg',
            },
            {'trackId': 2, 'trackName': '无试听', 'artistName': 'B'},
          ],
        })),
      );
      final service = ItunesMusicService(client: client);

      final tracks = await service.search('test');

      expect(tracks, hasLength(1));
      expect(tracks.single.source, 'itunes-preview');
      expect(tracks.single.audioUrl, 'https://x/1.m4a');
      expect(tracks.single.coverUrl, 'https://x/600x600bb.jpg');
    });
  });

  group('OnlineMusicService 聚合与去重', () {
    late NeteaseMusicService prevNetease;
    late ItunesMusicService prevItunes;

    setUp(() {
      prevNetease = OnlineMusicService.neteaseService;
      prevItunes = OnlineMusicService.itunesService;
      OnlineMusicService.enableKuwoSearch = false;
    });

    tearDown(() {
      OnlineMusicService.neteaseService = prevNetease;
      OnlineMusicService.itunesService = prevItunes;
      OnlineMusicService.enableKuwoSearch = true;
    });

    test('(d) 归一化 title+artist 去重，保留先出现的真实来源', () {
      const netease = Track(
        id: 'netease_5257138',
        title: '屋顶',
        artist: '周杰伦 / 温岚',
        album: '男女情歌对唱冠军全记录',
        coverUrl: '',
        duration: Duration(seconds: 319),
        source: 'netease-online',
      );
      const itunes = Track(
        id: 'itunes_123456',
        title: '屋顶 ',
        artist: '周杰伦、温岚',
        album: '男女情歌对唱冠军全记录',
        coverUrl: '',
        duration: Duration(seconds: 30),
        source: 'itunes-preview',
        audioUrl: 'https://audio-ssl.itunes.apple.com/preview.m4a',
      );

      final deduped = OnlineMusicService.dedupeByTitleArtist([netease, itunes]);

      expect(deduped, hasLength(1));
      expect(deduped.single.source, 'netease-online');
      expect(deduped.single.id, 'netease_5257138');
    });

    test('title 或 artist 不同则不去重', () {
      const a = Track(
        id: 'n1',
        title: '屋顶',
        artist: '周杰伦',
        album: '',
        coverUrl: '',
        duration: Duration(seconds: 200),
        source: 'netease-online',
      );
      const b = Track(
        id: 'n2',
        title: '屋顶',
        artist: '温岚',
        album: '',
        coverUrl: '',
        duration: Duration(seconds: 200),
        source: 'netease-online',
      );
      const c = Track(
        id: 'n3',
        title: '晴天',
        artist: '周杰伦',
        album: '',
        coverUrl: '',
        duration: Duration(seconds: 200),
        source: 'netease-online',
      );

      expect(OnlineMusicService.dedupeByTitleArtist([a, b, c]), hasLength(3));
    });

    test('并发聚合两源：结果带真实来源且同曲去重（网易云优先）', () async {
      OnlineMusicService.neteaseService = NeteaseMusicService(
        client: MockClient((request) async {
          if (request.url.path == '/api/song/detail') {
            return _json(jsonEncode({'songs': []}));
          }
          return _json(_searchBody());
        }),
      );
      OnlineMusicService.itunesService = ItunesMusicService(
        client: MockClient((request) async => _json(_itunesBody())),
      );

      final tracks = await OnlineMusicService.searchOnlineTracks('屋顶');

      expect(tracks, hasLength(1));
      expect(tracks.single.source, 'netease-online');
      expect(tracks.single.id, 'netease_5257138');
    });

    test('两源全部网络异常时抛出真实异常', () async {
      OnlineMusicService.neteaseService = NeteaseMusicService(
        client: MockClient((request) async => throw Exception('网易云网络不可达')),
      );
      OnlineMusicService.itunesService = ItunesMusicService(
        client: MockClient((request) async => throw Exception('iTunes 网络不可达')),
      );

      await expectLater(
        OnlineMusicService.searchOnlineTracks('屋顶'),
        throwsA(isA<Exception>()),
      );
    });

    test('单源成功时返回该源真实结果，不因另一源异常而全盘失败', () async {
      OnlineMusicService.neteaseService = NeteaseMusicService(
        client: MockClient((request) async => throw Exception('网易云网络不可达')),
      );
      OnlineMusicService.itunesService = ItunesMusicService(
        client: MockClient((request) async => _json(_itunesBody())),
      );

      final tracks = await OnlineMusicService.searchOnlineTracks('屋顶');

      expect(tracks, hasLength(1));
      expect(tracks.single.source, 'itunes-preview');
    });
  });
}
