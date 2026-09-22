import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tokens.dart';
import 'theme_provider.dart';

/// 具有物理触感按压下潜反馈的 Modern Soft 质感按钮
class SoftButton extends StatefulWidget {
  final Widget? child;
  final String? label;
  final IconData? icon;
  final double iconSize;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isCircle;
  final bool isPill;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? activeColor;
  final String? tooltip;

  const SoftButton({
    super.key,
    this.child,
    this.label,
    this.icon,
    this.iconSize = 20,
    this.onTap,
    this.isActive = false,
    this.isCircle = false,
    this.isPill = false,
    this.padding,
    this.width,
    this.height,
    this.activeColor,
    this.tooltip,
  });

  @override
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final accent = widget.activeColor ?? theme.accentColor;

    // 圆角判定
    BorderRadius borderRadius;
    if (widget.isCircle) {
      borderRadius = MellowRadii.borderPill;
    } else if (widget.isPill) {
      borderRadius = MellowRadii.borderPill;
    } else {
      borderRadius = MellowRadii.borderR16;
    }

    // 颜色判定
    Color bgColor;
    Color fgColor;

    if (widget.isActive) {
      bgColor = accent;
      fgColor = Colors.white;
    } else if (_isHovered) {
      bgColor = isDark ? MellowColors.cardMuted(true) : Colors.white;
      fgColor = theme.textPrimary;
    } else {
      bgColor = isDark ? MellowColors.card(true) : MellowColors.cardMuted(false);
      fgColor = theme.textSecondary;
    }

    // 阴影
    List<BoxShadow> shadows;
    if (_isPressed) {
      shadows = MellowShadows.recessed(isDark);
    } else if (widget.isActive) {
      shadows = [
        BoxShadow(
          color: accent.withOpacity(0.35),
          offset: const Offset(0, 4),
          blurRadius: 12,
        ),
      ];
    } else if (_isHovered) {
      shadows = isDark ? MellowShadows.cardDark : MellowShadows.cardLight;
    } else {
      shadows = [
        BoxShadow(
          color: isDark ? Colors.black26 : const Color(0x0A0F172A),
          offset: const Offset(0, 2),
          blurRadius: 6,
        ),
      ];
    }

    Widget contentWidget;
    if (widget.child != null) {
      contentWidget = widget.child!;
    } else {
      final List<Widget> items = [];
      if (widget.icon != null) {
        items.add(Icon(widget.icon, size: widget.iconSize, color: fgColor));
      }
      if (widget.icon != null && widget.label != null) {
        items.add(const SizedBox(width: 8));
      }
      if (widget.label != null) {
        items.add(
          Text(
            widget.label!,
            style: TextStyle(
              color: fgColor,
              fontSize: 13.5,
              fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        );
      }
      contentWidget = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: items,
      );
    }

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.03 : 1.0),
          duration: MellowDurations.fast,
          curve: MellowDurations.press,
          child: AnimatedContainer(
            duration: MellowDurations.normal,
            curve: MellowDurations.standard,
            width: widget.width,
            height: widget.height,
            padding: widget.padding ??
                (widget.isCircle
                    ? const EdgeInsets.all(10)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
              boxShadow: shadows,
              border: Border.all(
                color: widget.isActive
                    ? accent
                    : (isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.white.withOpacity(0.85)),
                width: 1,
              ),
            ),
            child: contentWidget,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}
