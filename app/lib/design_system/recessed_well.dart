import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tokens.dart';
import 'theme_provider.dart';

/// 内凹沉槽容器组件 (Recessed Well)
class RecessedWell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final Color? color;

  const RecessedWell({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final r = borderRadius ?? MellowRadii.borderR16;

    final bgColor = color ?? MellowColors.recessed(isDark);

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: r,
        boxShadow: MellowShadows.recessed(isDark),
        border: Border.all(
          color: isDark ? Colors.black45 : const Color(0xFFD1D5DB).withOpacity(0.6),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}
