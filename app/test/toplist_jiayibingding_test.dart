import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/core/sources/online_music_service.dart';

class _AllowAllHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  test('验证热歌榜中甲乙丙丁曲目正常收录且具备真实直链解析能力', () async {
    HttpOverrides.global = _AllowAllHttpOverrides();

    // 1. 抓取热歌榜真实曲库
    final hotTracks = await OnlineMusicService.fetchToplistTracks('热歌榜', limit: 50);
    expect(hotTracks.isNotEmpty, isTrue);

    // 2. 验证曲目池中包含甲乙丙丁
    final hasJiaYi = hotTracks.any((t) => t.title.contains('甲乙丙丁'));
    expect(hasJiaYi, isTrue, reason: '热歌榜中应正常包含《甲乙丙丁》歌曲');

    final jiaYiTrack = hotTracks.firstWhere((t) => t.title.contains('甲乙丙丁'));
    expect(jiaYiTrack.title.isNotEmpty, isTrue);

    // 3. 验证真实音频解析能力
    final url = await OnlineMusicService.resolvePlayableAudioUrl(
      jiaYiTrack.title,
      jiaYiTrack.artist,
      trackId: jiaYiTrack.id,
    );
    expect(url, isNotNull, reason: '《甲乙丙丁》应能通过多源智能聚合成功提取到物理可播放直链');
    expect(url!.startsWith('http'), isTrue);
  });
}
