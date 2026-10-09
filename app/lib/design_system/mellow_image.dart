import 'dart:math';
import 'package:flutter/material.dart';

/// 安全声学图片渲染容器：内置防撑爆尺寸约束、圆角与优雅占位降级
class MellowImage extends StatelessWidget {
  /// 是否在测试模式下运行（测试模式下跳过网络请求渲染占位）
  static bool isInTest = false;

  /// 智能防盗链 / 反爬请求头解析：依据目标域名动态注入专属 Referer，杜绝 403 跨域拦截
  static Map<String, String> getHeadersFor(String rawUrl) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    };

    final uri = Uri.tryParse(rawUrl);
    if (uri != null) {
      final host = uri.host.toLowerCase();
      if (host.contains('music.126.net') || host.contains('163.com')) {
        headers['Referer'] = 'https://music.163.com/';
      } else if (host.contains('gtimg.cn') || host.contains('qq.com')) {
        headers['Referer'] = 'https://y.qq.com/';
      } else if (host.contains('kuwo.cn')) {
        headers['Referer'] = 'https://www.kuwo.cn/';
      } else if (host.contains('kugou.com')) {
        headers['Referer'] = 'https://www.kugou.com/';
      }
    }
    return headers;
  }

  /// 默认通用请求头（兼容旧引用）
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

  /// CDN 图片智能缩略裁剪与 HTTPS 升级（将多兆超大原图压缩至轻量微图，大幅提速秒开）
  static String optimizeImageUrl(String rawUrl, {double? width, double? height}) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;

    // 统一升级为 HTTPS
    var secure = trimmed.startsWith('http://')
        ? trimmed.replaceFirst('http://', 'https://')
        : trimmed;

    final uri = Uri.tryParse(secure);
    if (uri == null) return secure;

    final host = uri.host.toLowerCase();

    // 1. 网易云音乐 CDN: 注入 ?param={w}y{h} 缩微参数
    if (host.contains('music.126.net') || host.contains('163.com')) {
      final double effectiveDim = (width != null && width.isFinite && width > 0)
          ? width
          : ((height != null && height.isFinite && height > 0) ? height : 180);
      final int size = (effectiveDim * 1.5).round().clamp(80, 600);

      if (!secure.contains('param=')) {
        final separator = secure.contains('?') ? '&' : '?';
        return '$secure${separator}param=${size}y$size';
      }
    }

    // 2. 酷狗音乐 CDN: 优化默认缩略尺寸段
    if (host.contains('kugou.com')) {
      if (secure.contains('/softhead/480/')) {
        return secure.replaceAll('/softhead/480/', '/softhead/240/');
      }
    }

    return secure;
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url.trim();
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
      final optimized = optimizeImageUrl(cleanUrl, width: width, height: height);

      // 计算硬件解码降采样像素尺寸，严防解码原图撑爆 GPU 与主线程
      int? cacheW;
      int? cacheH;
      if (width != null && width!.isFinite && width! > 0) {
        cacheW = (width! * 1.5).round().clamp(60, 600);
      }
      if (height != null && height!.isFinite && height! > 0) {
        cacheH = (height! * 1.5).round().clamp(60, 600);
      }

      img = Image.network(
        optimized,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        headers: getHeadersFor(optimized),
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
