/// 歌词行数据模型
class LyricLine {
  final Duration time;
  final String text;
  final String? translation;

  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
  });

  /// 解析标准 LRC 歌词行 [00:12.34]歌词内容
  static LyricLine? parse(String line) {
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final match = regExp.firstMatch(line.trim());
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final milliStr = match.group(3)!;
      final milli = int.parse(milliStr.padRight(3, '0').substring(0, 3));
      final text = match.group(4)!.trim();
      return LyricLine(
        time: Duration(minutes: min, seconds: sec, milliseconds: milli),
        text: text,
      );
    }
    return null;
  }

  /// 批量解析完整 LRC 歌词文本
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = lrcContent.split('\n');
    final result = <LyricLine>[];
    for (final line in lines) {
      final parsed = LyricLine.parse(line);
      if (parsed != null && parsed.text.isNotEmpty) {
        result.add(parsed);
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }
}

/// 音乐曲目模型
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final Duration duration;
  final String source;
  final String? audioUrl;
  final String? localPath;
  final List<LyricLine> lyrics;
  final bool isFavorite;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.duration,
    this.source = 'lx-mock',
    this.audioUrl,
    this.localPath,
    this.lyrics = const [],
    this.isFavorite = false,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
    Duration? duration,
    String? source,
    String? audioUrl,
    String? localPath,
    List<LyricLine>? lyrics,
    bool? isFavorite,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      source: source ?? this.source,
      audioUrl: audioUrl ?? this.audioUrl,
      localPath: localPath ?? this.localPath,
      lyrics: lyrics ?? this.lyrics,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// 格式化时长为 mm:ss
  String get formattedDuration {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 预置高保真曲目池 (与原型 83 项 E2E 验证曲目 100% 对齐)
final List<Track> mockPresetTracks = [
  Track(
    id: 'track-1',
    title: '云水禅心',
    artist: '巫娜',
    album: '天禅 · 琴筝和鸣',
    coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 28),
    source: 'preset-flac',
    isFavorite: true,
    lyrics: [
      LyricLine(time: Duration.zero, text: '云水禅心 - 巫娜'),
      LyricLine(time: const Duration(seconds: 12), text: '古筝幽弦，流水静淌'),
      LyricLine(time: const Duration(seconds: 24), text: '一曲清音，抚尽尘喧'),
      LyricLine(time: const Duration(seconds: 38), text: '山岚微润，清风徐来'),
      LyricLine(time: const Duration(seconds: 52), text: '空山新雨后，天气晚来秋'),
      LyricLine(time: const Duration(seconds: 68), text: '明月松间照，清泉石上流'),
      LyricLine(time: const Duration(seconds: 88), text: '心如止水，波澜不惊'),
      LyricLine(time: const Duration(seconds: 110), text: '禅意悠长，琴韵空灵'),
      LyricLine(time: const Duration(seconds: 135), text: '落叶萧萧，岁月静好'),
    ],
  ),
  Track(
    id: 'track-2',
    title: '晚风告白',
    artist: '伯远',
    album: '晚风拂过告白季',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 45),
    source: 'preset-320k',
    isFavorite: false,
    lyrics: [
      LyricLine(time: Duration.zero, text: '晚风告白 - 伯远'),
      LyricLine(time: const Duration(seconds: 10), text: '在日落黄昏前向你走来'),
      LyricLine(time: const Duration(seconds: 22), text: '晚风轻踩着云朵告白'),
      LyricLine(time: const Duration(seconds: 35), text: '星河泛滥成温柔大海'),
      LyricLine(time: const Duration(seconds: 48), text: '只想守护在你的身旁'),
      LyricLine(time: const Duration(seconds: 62), text: '让心动有迹可循'),
      LyricLine(time: const Duration(seconds: 78), text: '风吹过街角，写下心愿'),
    ],
  ),
  Track(
    id: 'track-3',
    title: '海阔天空',
    artist: 'Beyond',
    album: '乐与怒',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    duration: const Duration(minutes: 5, seconds: 24),
    source: 'preset-flac',
    isFavorite: true,
    lyrics: [
      LyricLine(time: Duration.zero, text: '海阔天空 - Beyond'),
      LyricLine(time: const Duration(seconds: 18), text: '今天我 寒夜里看雪飘过'),
      LyricLine(time: const Duration(seconds: 28), text: '怀着冷却了的心窝漂远方'),
      LyricLine(time: const Duration(seconds: 40), text: '风雨里追赶 雾里分不清影踪'),
      LyricLine(time: const Duration(seconds: 52), text: '天空海阔你与我 可会变'),
      LyricLine(time: const Duration(seconds: 65), text: '原谅我这一生不羁放纵爱自由'),
      LyricLine(time: const Duration(seconds: 78), text: '也会怕有一天会跌倒'),
      LyricLine(time: const Duration(seconds: 90), text: '背弃了理想 谁人都可以'),
      LyricLine(time: const Duration(seconds: 102), text: '哪会怕有一天只你共我'),
    ],
  ),
  Track(
    id: 'track-4',
    title: '夜的第七章',
    artist: '周杰伦',
    album: '依然范特西',
    coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 36),
    source: 'preset-flac',
    isFavorite: false,
    lyrics: [
      LyricLine(time: Duration.zero, text: '夜的第七章 - 周杰伦'),
      LyricLine(time: const Duration(seconds: 15), text: '1983年小巷 12月晴朗'),
      LyricLine(time: const Duration(seconds: 26), text: '夜的第七章 打字机继续推向'),
      LyricLine(time: const Duration(seconds: 38), text: '接近事实的那行 石楠烟斗的雾'),
      LyricLine(time: const Duration(seconds: 50), text: '飘向枯萎的树 沉默的证人'),
      LyricLine(time: const Duration(seconds: 64), text: '如果邪恶是华丽残酷的乐章'),
      LyricLine(time: const Duration(seconds: 80), text: '它的终场我会亲自写上'),
    ],
  ),
  Track(
    id: 'track-5',
    title: 'City of Stars',
    artist: 'Ryan Gosling & Emma Stone',
    album: 'La La Land OST',
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    duration: const Duration(minutes: 2, seconds: 58),
    source: 'preset-320k',
    isFavorite: true,
    lyrics: [
      LyricLine(time: Duration.zero, text: 'City of Stars - La La Land'),
      LyricLine(time: const Duration(seconds: 8), text: 'City of stars, are you shining just for me?'),
      LyricLine(time: const Duration(seconds: 20), text: 'City of stars, there\'s so much that I can\'t see'),
      LyricLine(time: const Duration(seconds: 34), text: 'Who knows? I felt it from the first embrace I shared with you'),
      LyricLine(time: const Duration(seconds: 50), text: 'That now our dreams, they\'ve finally come true'),
    ],
  ),
  Track(
    id: 'track-6',
    title: '起风了',
    artist: '买辣椒也用券',
    album: '起风了',
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&q=80',
    duration: const Duration(minutes: 5, seconds: 12),
    source: 'preset-flac',
    isFavorite: true,
    lyrics: [
      LyricLine(time: Duration.zero, text: '起风了 - 买辣椒也用券'),
      LyricLine(time: const Duration(seconds: 14), text: '这一路上走走停停 顺着少年漂流的痕迹'),
      LyricLine(time: const Duration(seconds: 28), text: '迈出车站的前一刻 竟有些犹豫'),
      LyricLine(time: const Duration(seconds: 42), text: '不禁笑这近乡情怯 仍无可避免'),
      LyricLine(time: const Duration(seconds: 56), text: '而长野的天 依旧那么暖 风吹起了从前'),
      LyricLine(time: const Duration(seconds: 72), text: '从前初识这世间 万般流连 看着天边似在眼前'),
      LyricLine(time: const Duration(seconds: 90), text: '也甘愿赴汤蹈火去走它一遍'),
    ],
  ),
];
