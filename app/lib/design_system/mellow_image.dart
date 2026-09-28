import 'dart:math';
import 'package:flutter/material.dart';

/// 安全声学图片渲染容器：内置防撑爆尺寸约束、圆角与优雅占位降级
class MellowImage extends StatelessWidget {
  /// 是否在测试模式下运行（测试模式下跳过网络请求渲染占位）
  static bool isInTest = false;

  /// 标准浏览器防盗链 / 反爬请求头（网易云、酷我、主流 CDN 必备，杜绝 Dart User-Agent 导致的 403 Forbidden）
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': 'https://music.163.com/',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  };

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const MellowImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  /// 声学双色艺术调色板：当图片加载失败或离线时，呈现质感优异的专辑渐变封套
  static const List<List<Color>> _acousticGradients = [
    [Color(0xFF4F46E5), Color(0xFF7C3AED)], // 暮色紫藤
    [Color(0xFF0284C7), Color(0xFF0D9488)], // 碧海清波
    [Color(0xFFE11D48), Color(0xFFEA580C)], // 晨曦珊瑚
    [Color(0xFF059669), Color(0xFF10B981)], // 极光森屿
    [Color(0xFF8B5CF6), Color(0xFFEC4899)], // 霓虹极光
    [Color(0xFFD97706), Color(0xFFF59E0B)], // 琥珀暖阳
    [Color(0xFF4338CA), Color(0xFF3B82F6)], // 深海流光
    [Color(0xFFBE185D), Color(0xFF9333EA)], // 迷雾落霞
  ];

  static List<Color> _gradientFor(String seed) {
    if (seed.isEmpty) return _acousticGradients[0];
    final hash = seed.hashCode.abs();
    return _acousticGradients[hash % _acousticGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url.trim().replaceFirst(RegExp(r'^http://'), 'https://');
    final bool usePlaceholder = isInTest ||
        cleanUrl.isEmpty ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    // 安全计算图标大小，严防 double.infinity 传入 Icon.size
    double iconSize = 24.0;
    if (width != null && height != null && width!.isFinite && height!.isFinite) {
      iconSize = max(14.0, min(width!, height!) * 0.38);
    }

    final gradientColors = _gradientFor(cleanUrl);

    Widget acousticPlaceholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradientColors[0].withValues(alpha: 0.85),
            gradientColors[1].withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 微拟物半透明声学唱片同心圆饰纹
          Positioned(
            right: -iconSize * 0.4,
            bottom: -iconSize * 0.4,
            child: Container(
              width: iconSize * 2.2,
              height: iconSize * 2.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 2,
                ),
              ),
            ),
          ),
          Icon(
            Icons.music_note_rounded,
            size: iconSize,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ],
      ),
    );

    Widget img;
    if (usePlaceholder) {
      img = acousticPlaceholder;
    } else {
      img = Image.network(
        cleanUrl,
        width: width,
        height: height,
        fit: fit,
        headers: defaultHeaders,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return acousticPlaceholder;
        },
        errorBuilder: (context, error, stackTrace) => acousticPlaceholder,
      );
    }

    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }

    if (width != null && height != null) {
      if (width!.isFinite && height!.isFinite) {
        return SizedBox(width: width, height: height, child: img);
      } else {
        return SizedBox.expand(child: img);
      }
    }
    return img;
  }
}

/// 安全声学圆形头像组件：杜绝 NetworkImage 在测试或离线状态下的抛错
class MellowAvatar extends StatelessWidget {
  final String url;
  final double radius;

  const MellowAvatar({
    super.key,
    required this.url,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return MellowImage(
      url: url,
      width: radius * 2,
      height: radius * 2,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
