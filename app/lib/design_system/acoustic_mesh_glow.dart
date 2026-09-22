import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

/// 动态声学流体高斯弥散光晕背景
class AcousticMeshGlow extends StatefulWidget {
  final Widget? child;
  final List<Color>? colors;
  final double? customIntensity;
  final bool enableAnimation;

  const AcousticMeshGlow({
    super.key,
    this.child,
    this.colors,
    this.customIntensity,
    this.enableAnimation = true,
  });

  @override
  State<AcousticMeshGlow> createState() => _AcousticMeshGlowState();
}

class _AcousticMeshGlowState extends State<AcousticMeshGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.enableAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final intensity = widget.customIntensity ?? theme.glowIntensity;
    final accent = theme.accentColor;

    // 默认提取 3 处声学色
    final baseColors = widget.colors ??
        [
          accent.withValues(alpha: 0.45 * intensity),
          const Color(0xFF8B5CF6).withValues(alpha: 0.35 * intensity),
          const Color(0xFFEC4899).withValues(alpha: 0.30 * intensity),
        ];

    return Stack(
      children: [
        // 动态光晕层
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return CustomPaint(
                painter: _MeshGlowPainter(
                  colors: baseColors,
                  progress: t,
                  intensity: intensity,
                ),
              );
            },
          ),
        ),

        // 高斯模糊层
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: const SizedBox.expand(),
          ),
        ),

        // 内容
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _MeshGlowPainter extends CustomPainter {
  final List<Color> colors;
  final double progress;
  final double intensity;

  _MeshGlowPainter({
    required this.colors,
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;

    final paint1 = Paint()
      ..color = colors[0]
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final paint2 = Paint()
      ..color = colors.length > 1 ? colors[1] : colors[0]
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);

    final paint3 = Paint()
      ..color = colors.length > 2 ? colors[2] : colors[0]
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // 缓慢漂移轨迹
    final dx1 = size.width * (0.25 + 0.1 * progress);
    final dy1 = size.height * (0.2 + 0.08 * (1.0 - progress));
    canvas.drawCircle(Offset(dx1, dy1), size.width * 0.32, paint1);

    final dx2 = size.width * (0.75 - 0.12 * progress);
    final dy2 = size.height * (0.35 + 0.1 * progress);
    canvas.drawCircle(Offset(dx2, dy2), size.width * 0.28, paint2);

    final dx3 = size.width * (0.5 + 0.15 * (progress - 0.5));
    final dy3 = size.height * (0.8 - 0.1 * progress);
    canvas.drawCircle(Offset(dx3, dy3), size.width * 0.35, paint3);
  }

  @override
  bool shouldRepaint(covariant _MeshGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.colors != colors;
  }
}
