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
    audioUrl: null,
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
    audioUrl: null,
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
    audioUrl: null,
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
    audioUrl: null,
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
    audioUrl: null,
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
    audioUrl: null,
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

/// 歌手结构化档案模型
class ArtistProfile {
  final String name;
  final String role;
  final String fans;
  final String bio;
  final String avatarUrl;
  final List<Track> tracks;

  const ArtistProfile({
    required this.name,
    required this.role,
    required this.fans,
    required this.bio,
    required this.avatarUrl,
    required this.tracks,
  });
}

/// 周杰伦专属曲库
final List<Track> mockJayChouTracks = [
  mockPresetTracks[3], // 夜的第七章
  Track(
    id: 'artist-jay-2',
    title: '晴天',
    artist: '周杰伦',
    album: '叶惠美',
    coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 29),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '晴天 - 周杰伦'),
      LyricLine(time: const Duration(seconds: 15), text: '故事的小黄花 从出生那年就飘着'),
      LyricLine(time: const Duration(seconds: 28), text: '童年的荡秋千 随记忆一直晃到现在'),
      LyricLine(time: const Duration(seconds: 44), text: '为你翘课的那一天 花落的那一天'),
      LyricLine(time: const Duration(seconds: 58), text: '刮风这天 我试过握着你手'),
      LyricLine(time: const Duration(seconds: 75), text: '但偏偏 雨渐渐 大到我看你不见'),
    ],
  ),
  Track(
    id: 'artist-jay-3',
    title: '花海',
    artist: '周杰伦',
    album: '魔杰座',
    coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 24),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '花海 - 周杰伦'),
      LyricLine(time: const Duration(seconds: 16), text: '静止了 所有的花开'),
      LyricLine(time: const Duration(seconds: 28), text: '遥远了 清晰了爱'),
      LyricLine(time: const Duration(seconds: 40), text: '天郁闷 爱却更喜欢'),
      LyricLine(time: const Duration(seconds: 56), text: '那时候 以为的挽留 原来是思念的借口'),
    ],
  ),
  Track(
    id: 'artist-jay-4',
    title: '爱在西元前',
    artist: '周杰伦',
    album: '范特西',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 54),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '爱在西元前 - 周杰伦'),
      LyricLine(time: const Duration(seconds: 12), text: '古巴比伦王颁布了汉谟拉比法典'),
      LyricLine(time: const Duration(seconds: 25), text: '刻在黑色的玄武岩 距今已经三千七百多年'),
      LyricLine(time: const Duration(seconds: 40), text: '你在橱窗前 凝视碑文的字眼'),
      LyricLine(time: const Duration(seconds: 55), text: '我却在旁静静欣赏你那张我爱的脸'),
    ],
  ),
];

/// Beyond 专属曲库
final List<Track> mockBeyondTracks = [
  mockPresetTracks[2], // 海阔天空
  Track(
    id: 'artist-beyond-2',
    title: '光辉岁月',
    artist: 'Beyond',
    album: '命运派对',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    duration: const Duration(minutes: 5, seconds: 3),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '光辉岁月 - Beyond'),
      LyricLine(time: const Duration(seconds: 15), text: '钟声响起归家的讯号 在他生命里'),
      LyricLine(time: const Duration(seconds: 28), text: '彷佛带点唏嘘 黑色肌肤给他的意义'),
      LyricLine(time: const Duration(seconds: 42), text: '是一生奉献 肤色斗争中'),
      LyricLine(time: const Duration(seconds: 58), text: '年月把拥有变做失去 疲倦的双眼带着期望'),
      LyricLine(time: const Duration(seconds: 74), text: '今天只有残留的躯壳 迎接光辉岁月'),
    ],
  ),
  Track(
    id: 'artist-beyond-3',
    title: '真的爱你',
    artist: 'Beyond',
    album: 'Beyond IV',
    coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 36),
    source: 'preset-320k',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '真的爱你 - Beyond'),
      LyricLine(time: const Duration(seconds: 12), text: '无法可修饰的一对手 带出温暖永远在背后'),
      LyricLine(time: const Duration(seconds: 24), text: '纵使啰唆始终关注 不懂得珍惜怎可拥有'),
      LyricLine(time: const Duration(seconds: 38), text: '常渴望见你 面容常微笑'),
      LyricLine(time: const Duration(seconds: 52), text: '是你多么温馨的目光 教我坚毅望着前路'),
    ],
  ),
  Track(
    id: 'artist-beyond-4',
    title: '喜欢你',
    artist: 'Beyond',
    album: '秘密警察',
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 34),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '喜欢你 - Beyond'),
      LyricLine(time: const Duration(seconds: 18), text: '细雨带风湿透黄昏的街道 抹去雨水双眼无故地仰望'),
      LyricLine(time: const Duration(seconds: 32), text: '望向孤单的晚灯 记忆中想起你'),
      LyricLine(time: const Duration(seconds: 48), text: '喜欢你 那双眼动人 笑声更迷人'),
      LyricLine(time: const Duration(seconds: 64), text: '愿再可 轻抚你 那可爱面容'),
    ],
  ),
];

/// 巫娜专属曲库
final List<Track> mockWuNaTracks = [
  mockPresetTracks[0], // 云水禅心
  Track(
    id: 'artist-wn-2',
    title: '七弦清音',
    artist: '巫娜',
    album: '琴意禅心',
    coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    duration: const Duration(minutes: 5, seconds: 8),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '七弦清音 - 巫娜'),
      LyricLine(time: const Duration(seconds: 16), text: '古琴七弦，空灵超尘'),
      LyricLine(time: const Duration(seconds: 36), text: '指尖轻抚，山水相逢'),
      LyricLine(time: const Duration(seconds: 58), text: '万籁俱寂，唯余清响'),
    ],
  ),
  Track(
    id: 'artist-wn-3',
    title: '流水行云',
    artist: '巫娜',
    album: '静水深流',
    coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 45),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '流水行云 - 巫娜'),
      LyricLine(time: const Duration(seconds: 14), text: '山泉汩汩，云卷云舒'),
      LyricLine(time: const Duration(seconds: 32), text: '心无挂碍，意随琴远'),
      LyricLine(time: const Duration(seconds: 52), text: '坐看云起，静听清泉'),
    ],
  ),
  Track(
    id: 'artist-wn-4',
    title: '秋江夜泊',
    artist: '巫娜',
    album: '秋水长天',
    coverUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
    duration: const Duration(minutes: 5, seconds: 32),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '秋江夜泊 - 巫娜'),
      LyricLine(time: const Duration(seconds: 20), text: '月落乌啼霜满天，江枫渔火对愁眠'),
      LyricLine(time: const Duration(seconds: 40), text: '姑苏城外寒山寺，夜半钟声到客船'),
    ],
  ),
];

/// 伯远专属曲库
final List<Track> mockBoYuanTracks = [
  mockPresetTracks[1], // 晚风告白
  Track(
    id: 'artist-by-2',
    title: '起跑线',
    artist: '伯远',
    album: '青春巡光',
    coverUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 38),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '起跑线 - 伯远'),
      LyricLine(time: const Duration(seconds: 12), text: '站在晨光里的起跑线'),
      LyricLine(time: const Duration(seconds: 24), text: '奔赴属于每一个明天的约定'),
      LyricLine(time: const Duration(seconds: 42), text: '汗水与勇气，织就最炽热的青春'),
    ],
  ),
  Track(
    id: 'artist-by-3',
    title: '冬日之光',
    artist: '伯远',
    album: '初光如昨',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 15),
    source: 'preset-320k',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '冬日之光 - 伯远'),
      LyricLine(time: const Duration(seconds: 15), text: '白雪落下的时候，想起你的微笑'),
      LyricLine(time: const Duration(seconds: 30), text: '温热的一杯咖啡，驱散寒冬风霜'),
    ],
  ),
  Track(
    id: 'artist-by-4',
    title: '巡光之旅',
    artist: '伯远',
    album: '巡光之旅',
    coverUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 50),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '巡光之旅 - 伯远'),
      LyricLine(time: const Duration(seconds: 14), text: '跟随心中的光芒不断前行'),
      LyricLine(time: const Duration(seconds: 32), text: '每一座城市都有特别的歌声与你同行'),
    ],
  ),
];

/// 结构化歌手档案列表
final List<ArtistProfile> mockArtistsProfiles = [
  ArtistProfile(
    name: '巫娜',
    role: '古琴演奏家 / 音乐制作人',
    fans: '86.4万',
    bio: '当代古琴领军名家 · 禅意东方声学开创者 · 累计播放量突破 3000 万',
    avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500&q=80',
    tracks: mockWuNaTracks,
  ),
  ArtistProfile(
    name: '周杰伦',
    role: '华语流行音乐天王',
    fans: '3890.2万',
    bio: '华语乐坛传奇巨星 · 累计播放量破 100 亿 · 金曲奖历史大满贯得主',
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&q=80',
    tracks: mockJayChouTracks,
  ),
  ArtistProfile(
    name: 'Beyond',
    role: '传奇殿堂级摇滚乐队',
    fans: '1240.8万',
    bio: '殿堂级华人摇滚丰碑 · 跨越时代的理想与信念 · 累计传唱逾三十载',
    avatarUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    tracks: mockBeyondTracks,
  ),
  ArtistProfile(
    name: '伯远',
    role: '流行歌手 / 唱跳创作人',
    fans: '512.6万',
    bio: '实力流行唱作人 · 舞台全能先锋 · 巡演热度榜 TOP 级',
    avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=500&q=80',
    tracks: mockBoYuanTracks,
  ),
];

/// 根据歌手名字检索歌手档案
ArtistProfile getArtistProfileByName(String name) {
  return mockArtistsProfiles.firstWhere(
    (a) => a.name.trim().toLowerCase() == name.trim().toLowerCase(),
    orElse: () => ArtistProfile(
      name: name,
      role: '官方认证音乐人',
      fans: '128.5万',
      bio: '官方认证音乐人 · 原创先锋作者 · 累计播放破亿',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&q=80',
      tracks: mockPresetTracks,
    ),
  );
}

/// 四大榜单真实独立曲库
/// 1. 飙升榜 (HOT - 5 首)
final List<Track> toplistSurgeTracks = [
  mockPresetTracks[5], // 起风了 - 买辣椒也用券
  mockPresetTracks[1], // 晚风告白 - 伯远
  Track(
    id: 'chart-surge-3',
    title: '乌梅子酱',
    artist: '李荣浩',
    album: '纵横四海',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 35),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '乌梅子酱 - 李荣浩'),
      LyricLine(time: const Duration(seconds: 14), text: '背对背默默许下心愿'),
      LyricLine(time: const Duration(seconds: 28), text: '看远方的星是否听的见'),
      LyricLine(time: const Duration(seconds: 46), text: '你浅浅的微笑就像 乌梅子酱'),
      LyricLine(time: const Duration(seconds: 62), text: '我尝了你嘴角唇膏 薄荷味道'),
    ],
  ),
  Track(
    id: 'chart-surge-4',
    title: '如果呢',
    artist: '郑润泽',
    album: '绚烂 枯萎 以后',
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 48),
    source: 'preset-320k',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '如果呢 - 郑润泽'),
      LyricLine(time: const Duration(seconds: 12), text: '如果那天的风没有吹向你'),
      LyricLine(time: const Duration(seconds: 26), text: '如果我们的相遇早一点清醒'),
      LyricLine(time: const Duration(seconds: 45), text: '会不会故事就会有不同结局'),
    ],
  ),
  Track(
    id: 'chart-surge-5',
    title: '想去海边',
    artist: '夏日入侵企画',
    album: '想去海边',
    coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 12),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '想去海边 - 夏日入侵企画'),
      LyricLine(time: const Duration(seconds: 16), text: '穿过长长隧道 奔向无垠蓝天'),
      LyricLine(time: const Duration(seconds: 34), text: '在浪花里追赶夏日的风'),
    ],
  ),
];

/// 2. 热歌榜 (TOP - 5 首)
final List<Track> toplistHotTracks = [
  mockPresetTracks[2], // 海阔天空 - Beyond
  mockPresetTracks[3], // 夜的第七章 - 周杰伦
  mockJayChouTracks[1], // 晴天 - 周杰伦
  mockBeyondTracks[1], // 光辉岁月 - Beyond
  Track(
    id: 'chart-hot-5',
    title: '十年',
    artist: '陈奕迅',
    album: '黑·白·灰',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 25),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '十年 - 陈奕迅'),
      LyricLine(time: const Duration(seconds: 12), text: '如果那两个字没有颤抖 我不会发现 我难受'),
      LyricLine(time: const Duration(seconds: 28), text: '怎么说出口 也不过是分手'),
      LyricLine(time: const Duration(seconds: 45), text: '十年之前 我不认识你 你不属于我'),
      LyricLine(time: const Duration(seconds: 64), text: '十年之后 我们是朋友 还可以问候'),
    ],
  ),
];

/// 3. 新歌榜 (NEW - 5 首)
final List<Track> toplistNewTracks = [
  Track(
    id: 'chart-new-1',
    title: '瞬',
    artist: '郑润泽',
    album: '瞬',
    coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 58),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '瞬 - 郑润泽'),
      LyricLine(time: const Duration(seconds: 15), text: '当光线穿过这片迷雾'),
      LyricLine(time: const Duration(seconds: 32), text: '短暂的停留也是永恒的印记'),
    ],
  ),
  Track(
    id: 'chart-new-2',
    title: '漠河舞厅',
    artist: '柳爽',
    album: '1st . 漠河舞厅',
    coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 28),
    source: 'preset-320k',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '漠河舞厅 - 柳爽'),
      LyricLine(time: const Duration(seconds: 16), text: '我从没有见过极光出现的村落'),
      LyricLine(time: const Duration(seconds: 30), text: '也没有见过有人 在深夜里跳舞'),
      LyricLine(time: const Duration(seconds: 48), text: '如果时间可以倒流，你愿意再跳一支舞吗'),
    ],
  ),
  mockJayChouTracks[3], // 爱在西元前 - 周杰伦
  mockJayChouTracks[2], // 花海 - 周杰伦
  Track(
    id: 'chart-new-5',
    title: '海底',
    artist: '一支榴莲',
    album: '独白',
    coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 16),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '海底 - 一支榴莲'),
      LyricLine(time: const Duration(seconds: 15), text: '散落的月光穿过了云'),
      LyricLine(time: const Duration(seconds: 30), text: '凝望深海里未完的心愿'),
      LyricLine(time: const Duration(seconds: 50), text: '来不及说出的告白 沉入静谧蔚蓝'),
    ],
  ),
];

/// 4. 原创榜 (ORIGIN - 5 首)
final List<Track> toplistOriginTracks = [
  mockPresetTracks[0], // 云水禅心 - 巫娜
  Track(
    id: 'chart-orig-2',
    title: '米店',
    artist: '张玮玮',
    album: '白银饭店',
    coverUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 35),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '米店 - 张玮玮'),
      LyricLine(time: const Duration(seconds: 18), text: '三月的烟雨 飘摇的南方'),
      LyricLine(time: const Duration(seconds: 36), text: '你坐在空旷的酒馆里'),
      LyricLine(time: const Duration(seconds: 54), text: '苹果成熟了 窗外阳光明亮'),
      LyricLine(time: const Duration(seconds: 72), text: '你一定要买一把吉他 走在三月的细雨里'),
    ],
  ),
  Track(
    id: 'chart-orig-3',
    title: '安和桥',
    artist: '宋冬野',
    album: '安和桥北',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    duration: const Duration(minutes: 4, seconds: 12),
    source: 'preset-320k',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '安和桥 - 宋冬野'),
      LyricLine(time: const Duration(seconds: 20), text: '让我再看你一眼 从南到北'),
      LyricLine(time: const Duration(seconds: 38), text: '像是被五月的风吹过的夏天'),
      LyricLine(time: const Duration(seconds: 56), text: '我知道 那些夏天 就像青春一样回不来'),
      LyricLine(time: const Duration(seconds: 78), text: '所以 你好 再见'),
    ],
  ),
  Track(
    id: 'chart-orig-4',
    title: '理想三旬',
    artist: '陈鸿宇',
    album: '浓烟下的诗歌电台',
    coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=500&q=80',
    duration: const Duration(minutes: 3, seconds: 46),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '理想三旬 - 陈鸿宇'),
      LyricLine(time: const Duration(seconds: 15), text: '雨后有车驶来 驶过暮色苍白'),
      LyricLine(time: const Duration(seconds: 30), text: '旧铁皮往南开 恋人已不在'),
      LyricLine(time: const Duration(seconds: 48), text: '时光苟延残喘无可奈何 抓不住的岁月'),
    ],
  ),
  Track(
    id: 'chart-orig-5',
    title: '南山南',
    artist: '马頔',
    album: '孤岛',
    coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    duration: const Duration(minutes: 5, seconds: 24),
    source: 'preset-flac',
    audioUrl: null,
    lyrics: [
      LyricLine(time: Duration.zero, text: '南山南 - 马頔'),
      LyricLine(time: const Duration(seconds: 22), text: '你在南方的艳阳里 大雪纷飞'),
      LyricLine(time: const Duration(seconds: 40), text: '我在北方的寒夜里 四季如春'),
      LyricLine(time: const Duration(seconds: 60), text: '如果天黑之前来得及 我要忘了你的眼睛'),
    ],
  ),
];

/// 四大榜单汇总聚合字典
final Map<String, List<Track>> toplistTracksMap = {
  '飙升榜': toplistSurgeTracks,
  '热歌榜': toplistHotTracks,
  '新歌榜': toplistNewTracks,
  '原创榜': toplistOriginTracks,
};

/// 获取全部榜单汇总曲库（排重）
List<Track> getAllToplistTracks() {
  final Set<String> ids = {};
  final List<Track> result = [];
  for (final list in toplistTracksMap.values) {
    for (final t in list) {
      if (ids.add(t.id)) {
        result.add(t);
      }
    }
  }
  return result;
}

/// 声音电台专区节目模型
class RadioStation {
  final String id;
  final String title;
  final String sub;
  final String coverUrl;
  final String listeners;
  final Track track;

  const RadioStation({
    required this.id,
    required this.title,
    required this.sub,
    required this.coverUrl,
    required this.listeners,
    required this.track,
  });
}

/// 声音电台 4 大专属节目曲库
final List<RadioStation> mockRadioStations = [
  RadioStation(
    id: 'radio-1',
    title: '深夜治愈故事馆',
    sub: '伴你入眠的温暖声音',
    coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    listeners: '24.8万在听',
    track: Track(
      id: 'radio-track-1',
      title: '伴月入眠 · 晚安夜读',
      artist: '深夜治愈故事馆',
      album: '月光下的人文陪伴',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
      duration: const Duration(minutes: 6, seconds: 12),
      source: 'podcast-station',
    audioUrl: null,
      lyrics: [
        LyricLine(time: Duration.zero, text: '伴月入眠 · 晚安夜读 - 深夜治愈故事馆'),
        LyricLine(time: const Duration(seconds: 10), text: '今晚无论你经历过什么，都请在这一刻卸下行囊'),
        LyricLine(time: const Duration(seconds: 24), text: '夜深了，城市的灯火正一盏盏熄灭'),
        LyricLine(time: const Duration(seconds: 40), text: '深呼吸，感受胸腔内安稳平缓的律动'),
        LyricLine(time: const Duration(seconds: 58), text: '明天又是全新的起点，愿你好梦'),
      ],
    ),
  ),
  RadioStation(
    id: 'radio-2',
    title: '助眠白噪音与雨声',
    sub: '大自然沉浸式深度放松',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    listeners: '58.2万在听',
    track: Track(
      id: 'radio-track-2',
      title: '松针夜雨 · 深林空溪',
      artist: '自然声学实验室',
      album: '大自然立体声场白噪音',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      duration: const Duration(minutes: 8, seconds: 20),
      source: 'podcast-station',
    audioUrl: null,
      lyrics: [
        LyricLine(time: Duration.zero, text: '松针夜雨 · 深林空溪 - 自然声学实验室'),
        LyricLine(time: const Duration(seconds: 15), text: '【环境声学】细雨穿过针叶林，微风拂动树影'),
        LyricLine(time: const Duration(seconds: 45), text: '【声学频率】粉红噪声动态平抑杂乱脑电波'),
        LyricLine(time: const Duration(seconds: 80), text: '【深度放松】潺潺溪流与青石碰撞的自然回响'),
      ],
    ),
  ),
  RadioStation(
    id: 'radio-3',
    title: '音乐背后的人文故事',
    sub: '解码华语流行四十年',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    listeners: '36.5万在听',
    track: Track(
      id: 'radio-track-3',
      title: '时代的回响 · 殿堂级摇滚溯源',
      artist: '乐话人文专栏',
      album: '解码华语流行四十年',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
      duration: const Duration(minutes: 7, seconds: 15),
      source: 'podcast-station',
    audioUrl: null,
      lyrics: [
        LyricLine(time: Duration.zero, text: '时代的回响 · 殿堂级摇滚溯源 - 乐话人文专栏'),
        LyricLine(time: const Duration(seconds: 14), text: '上世纪八十年代末，香港的霓虹灯火与地下录音棚'),
        LyricLine(time: const Duration(seconds: 30), text: '一把木吉他，写出了几代人共同铭记的理想'),
        LyricLine(time: const Duration(seconds: 52), text: '哪怕海阔天空，风雨里也始终追赶着不灭的光芒'),
      ],
    ),
  ),
  RadioStation(
    id: 'radio-4',
    title: '科技前沿早知道',
    sub: 'AI 时代的智识声音',
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    listeners: '19.4万在听',
    track: Track(
      id: 'radio-track-4',
      title: '先锋访谈 · 声学算法与智能重塑',
      artist: '未来声音播客',
      album: 'AI 时代的智识前沿',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
      duration: const Duration(minutes: 6, seconds: 45),
      source: 'podcast-station',
    audioUrl: null,
      lyrics: [
        LyricLine(time: Duration.zero, text: '先锋访谈 · 声学算法与智能重塑 - 未来声音播客'),
        LyricLine(time: const Duration(seconds: 12), text: '当神经渲染与物理声卡发生碰撞'),
        LyricLine(time: const Duration(seconds: 28), text: '空间音频算法如何还原真实现场的三维沉浸感？'),
        LyricLine(time: const Duration(seconds: 48), text: '今天我们邀请到前沿声学实验室的架构师共同探讨'),
      ],
    ),
  ),
];

/// 歌单广场结构化歌单模型
class SquarePlaylist {
  final String id;
  final String title;
  final String desc;
  final String tag;
  final String coverUrl;
  final String playCount;
  final List<Track> tracks;

  const SquarePlaylist({
    required this.id,
    required this.title,
    required this.desc,
    required this.tag,
    required this.coverUrl,
    required this.playCount,
    required this.tracks,
  });
}

/// 歌单广场多分类预设歌单库
final List<SquarePlaylist> mockSquarePlaylists = [
  SquarePlaylist(
    id: 'sq-pl-1',
    title: '华语经典流行金曲堂',
    desc: '从千禧年代到黄金世代，听懂已非少年',
    tag: '华语流行',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
    playCount: '184.2万',
    tracks: mockJayChouTracks,
  ),
  SquarePlaylist(
    id: 'sq-pl-2',
    title: '不朽摇滚 · 岁月沉思录',
    desc: '超越时光的呐喊与感动，致敬不朽传奇',
    tag: '经典粤语',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
    playCount: '92.6万',
    tracks: mockBeyondTracks,
  ),
  SquarePlaylist(
    id: 'sq-pl-3',
    title: '空山新雨 · 禅意清音集',
    desc: '古筝与古琴清越合鸣，洗涤世间纷扰',
    tag: '古风雅乐',
    coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    playCount: '63.8万',
    tracks: mockWuNaTracks,
  ),
  SquarePlaylist(
    id: 'sq-pl-4',
    title: '温润声线 · 晚风与少年',
    desc: '治愈系都市抒情曲，温暖每一个孤单夜晚',
    tag: '沉静治愈',
    coverUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=500&q=80',
    playCount: '78.5万',
    tracks: mockBoYuanTracks,
  ),
  SquarePlaylist(
    id: 'sq-pl-5',
    title: '原创独立音乐先锋榜',
    desc: '民谣诗意与独立声线，唱出真实灵魂',
    tag: '沉静治愈',
    coverUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
    playCount: '45.1万',
    tracks: toplistOriginTracks,
  ),
  SquarePlaylist(
    id: 'sq-pl-6',
    title: '爵士迷情 · 深夜微醺特调',
    desc: '萨克斯风与低音提琴，流淌午夜浪漫',
    tag: '深夜爵士',
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
    playCount: '31.2万',
    tracks: [
      mockPresetTracks[4], // City of Stars
      mockPresetTracks[3], // 夜的第七章
    ],
  ),
  SquarePlaylist(
    id: 'sq-pl-7',
    title: '纯音天籁 · 专注与深度思考',
    desc: '不被打扰的纯净旋律，伴你高效专注',
    tag: '纯音乐',
    coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
    playCount: '52.7万',
    tracks: [
      mockWuNaTracks[0],
      mockWuNaTracks[1],
      mockWuNaTracks[2],
    ],
  ),
];

/// 根据分类标签筛选歌单（“精选推荐”返回全部）
List<SquarePlaylist> getPlaylistsByTag(String tag) {
  if (tag == '精选推荐') {
    return mockSquarePlaylists;
  }
  return mockSquarePlaylists.where((p) => p.tag == tag).toList();
}



/// 获取全局所有已知曲目（去重）
List<Track> getAllKnownTracks() {
  final map = <String, Track>{};
  for (final t in mockPresetTracks) {
    map[t.id] = t;
  }
  for (final list in toplistTracksMap.values) {
    for (final t in list) {
      map[t.id] = t;
    }
  }
  for (final a in mockArtistsProfiles) {
    for (final t in a.tracks) {
      map[t.id] = t;
    }
  }
  for (final r in mockRadioStations) {
    map[r.track.id] = r.track;
  }
  for (final pl in mockSquarePlaylists) {
    for (final t in pl.tracks) {
      map[t.id] = t;
    }
  }
  return map.values.toList();
}

/// 全局已知曲库寻轨辅助函数 (解决收藏与历史跨列表检索)
Track? findKnownTrackById(String id) {
  for (final t in getAllKnownTracks()) {
    if (t.id == id) return t;
  }
  return null;
}
