import 'package:flutter/material.dart';

/// 5 大声学柔光强调色枚举
enum AccentColorType {
  blue('浩瀚蔚蓝', Color(0xFF3B82F6), Color(0xFF60A5FA)),
  purple('星河微紫', Color(0xFF8B5CF6), Color(0xFFA78BFA)),
  pink('晨樱柔粉', Color(0xFFEC4899), Color(0xFFF472B6)),
  amber('琥珀金晖', Color(0xFFF59E0B), Color(0xFFFBBF24)),
  emerald('碧波翡翠', Color(0xFF10B981), Color(0xFF34D399));

  final String label;
  final Color lightColor;
  final Color darkColor;

  const AccentColorType(this.label, this.lightColor, this.darkColor);

  Color getColor(bool isDark) => isDark ? darkColor : lightColor;
}

/// Modern Soft UI 色彩规范 (映射 design_tokens.css)
class MellowColors {
  // 浅色模式 - 温润白瓷 (Porcelain)
  static const Color canvasLight = Color(0xFFF5F7FB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardMutedLight = Color(0xFFF8FAFD);
  static const Color recessedLight = Color(0xFFEBF0F8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtleLight = Color(0xFFEDF2F7);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // 深色模式 - 深石墨夜间 (Graphite)
  static const Color canvasDark = Color(0xFF0D1117);
  static const Color cardDark = Color(0xFF161B22);
  static const Color cardMutedDark = Color(0xFF1C2128);
  static const Color recessedDark = Color(0xFF0B0E14);
  static const Color borderDark = Color(0xFF30363D);
  static const Color borderSubtleDark = Color(0xFF21262D);
  static const Color textPrimaryDark = Color(0xFFF0F6FC);
  static const Color textSecondaryDark = Color(0xFF8B949E);
  static const Color textMutedDark = Color(0xFF6E7681);

  // 快捷获取当前主题色彩
  static Color canvas(bool isDark) => isDark ? canvasDark : canvasLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color cardMuted(bool isDark) => isDark ? cardMutedDark : cardMutedLight;
  static Color recessed(bool isDark) => isDark ? recessedDark : recessedLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color borderSubtle(bool isDark) => isDark ? borderSubtleDark : borderSubtleLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
}

/// 连续曲率圆角与几何半径 (Squircle & Radii)
class MellowRadii {
  static const Radius r8 = Radius.circular(8);
  static const Radius r12 = Radius.circular(12);
  static const Radius r16 = Radius.circular(16);
  static const Radius r20 = Radius.circular(20);
  static const Radius r24 = Radius.circular(24);
  static const Radius r28 = Radius.circular(28);
  static const Radius r32 = Radius.circular(32);
  static const Radius pill = Radius.circular(9999);

  static const BorderRadius borderR8 = BorderRadius.all(r8);
  static const BorderRadius borderR12 = BorderRadius.all(r12);
  static const BorderRadius borderR16 = BorderRadius.all(r16);
  static const BorderRadius borderR20 = BorderRadius.all(r20);
  static const BorderRadius borderR24 = BorderRadius.all(r24);
  static const BorderRadius borderR28 = BorderRadius.all(r28);
  static const BorderRadius borderR32 = BorderRadius.all(r32);
  static const BorderRadius borderPill = BorderRadius.all(pill);
}

/// 三层漫散射景深阴影系统 (Layered Soft Depth Shadows)
class MellowShadows {
  // 浅色 - 微浮卡片阴影 (Elevation 1)
  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x0D0F172A), // 5% alpha
      offset: Offset(0, 4),
      blurRadius: 20,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x080F172A), // 3% alpha
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  // 深色 - 微浮卡片阴影
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x33000000), // 20% alpha
      offset: Offset(0, 4),
      blurRadius: 20,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x1F000000), // 12% alpha
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  // 浅色 - 悬浮胶囊/播放底栏阴影 (Elevation 2)
  static const List<BoxShadow> floatingPillLight = [
    BoxShadow(
      color: Color(0x1F0F172A), // 12% alpha
      offset: Offset(0, 20),
      blurRadius: 40,
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Color(0x0F0F172A), // 6% alpha
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  // 深色 - 悬浮胶囊/播放底栏阴影
  static const List<BoxShadow> floatingPillDark = [
    BoxShadow(
      color: Color(0x66000000), // 40% alpha
      offset: Offset(0, 20),
      blurRadius: 40,
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Color(0x33000000), // 20% alpha
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  // 内凹沉槽微内阴影 (Recessed Well) 模拟
  static List<BoxShadow> recessed(bool isDark) {
    if (isDark) {
      return const [
        BoxShadow(
          color: Color(0x4D000000),
          offset: Offset(0, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];
    } else {
      return const [
        BoxShadow(
          color: Color(0x0F0F172A),
          offset: Offset(0, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];
    }
  }
}

/// 动效曲线与微时间戳
class MellowDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration lyricScroll = Duration(milliseconds: 320);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve press = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Curve smooth = Cubic(0.25, 0.1, 0.25, 1.0);
}
