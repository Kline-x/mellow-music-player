import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tokens.dart';
import 'theme_provider.dart';

/// Modern Soft UI 微浮卡片组件
class SoftCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final bool isRecessed;
  final bool isFloatingPill;
  final Border? border;
  final double? width;
  final double? height;

  const SoftCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.onTap,
    this.isRecessed = false,
    this.isFloatingPill = false,
    this.border,
    this.width,
    this.height,
  });

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final r = widget.borderRadius ?? MellowRadii.borderR24;

    // 阴影计算
    List<BoxShadow> shadows;
    if (widget.isRecessed) {
      shadows = MellowShadows.recessed(isDark);
    } else if (widget.isFloatingPill) {
      shadows = isDark ? MellowShadows.floatingPillDark : MellowShadows.floatingPillLight;
    } else {
      shadows = isDark ? MellowShadows.cardDark : MellowShadows.cardLight;
    }

    // 背景色计算
    Color bgColor;
    if (widget.color != null) {
      bgColor = widget.color!;
    } else if (widget.isRecessed) {
      bgColor = MellowColors.recessed(isDark);
    } else {
      bgColor = MellowColors.card(isDark);
    }

    // 默认高光微描边
    final border = widget.border ??
        Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.85),
          width: 1.0,
        );

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: r,
        boxShadow: _isPressed ? MellowShadows.recessed(isDark) : shadows,
        border: border,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : (_isHovered ? 1.01 : 1.0),
            duration: MellowDurations.fast,
            curve: MellowDurations.press,
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}
