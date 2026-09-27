import 'package:flutter/material.dart';

/// Mellow Music · 润音 品牌徽标组件
/// 支持全平台高清矢量/资源图呈现，外附微拟物声学微光容器
class MellowBrandLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showGlow;

  const MellowBrandLogo({
    super.key,
    this.size = 32,
    this.borderRadius = 8,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 优雅降级微徽标
            return Container(
              color: const Color(0xFF1E222D),
              alignment: Alignment.center,
              child: Icon(
                Icons.graphic_eq_rounded,
                color: const Color(0xFF8B5CF6),
                size: size * 0.65,
              ),
            );
          },
        ),
      ),
    );
  }
}
