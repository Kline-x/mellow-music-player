import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 安全声学图片渲染容器：内置防撑爆尺寸约束、圆角与优雅占位降级
class MellowImage extends StatelessWidget {
  /// 是否在测试模式下运行（测试模式下跳过网络请求渲染占位）
  static bool isInTest = false;

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

  @override
  Widget build(BuildContext context) {
    final bool usePlaceholder = isInTest ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    // 安全计算图标大小，严防 double.infinity 传入 Icon.size
    double iconSize = 24.0;
    if (width != null && height != null && width!.isFinite && height!.isFinite) {
      iconSize = max(12.0, min(width!, height!) * 0.4);
    }

    Widget placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey.withOpacity(0.15),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: iconSize,
        color: Colors.grey.shade400,
      ),
    );

    Widget img;
    if (usePlaceholder) {
      img = placeholder;
    } else {
      img = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder,
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
