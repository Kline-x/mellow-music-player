import 'package:flutter/material.dart';
import 'desktop_scaffold.dart';
import 'mobile_scaffold.dart';

/// 响应式双壳自适应架构 (AdaptiveScaffold)
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key});

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopWidth = constraints.maxWidth >= 1024;
        if (isDesktopWidth) {
          return const DesktopScaffold();
        } else {
          return const MobileScaffold();
        }
      },
    );
  }
}
