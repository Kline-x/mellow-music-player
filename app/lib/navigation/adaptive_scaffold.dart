import 'package:flutter/material.dart';
import 'desktop_scaffold.dart';
import 'mobile_scaffold.dart';

/// 响应式双壳自适应架构 (AdaptiveScaffold)
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key});

  @override
  Widget build(BuildContext context) {

    // ignore: avoid_print
    print('>>> [STEP 8] AdaptiveScaffold build called');
    return LayoutBuilder(
      builder: (context, constraints) {
        // 在桌面平台（Windows/macOS/Linux）或视口宽度 >= 720 时，保持现代桌面级工作台架构
        final isDesktopPlatform = Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.macOS ||
            Theme.of(context).platform == TargetPlatform.linux;
        final isDesktopWidth = constraints.maxWidth >= 720;
        if (isDesktopPlatform || isDesktopWidth) {
          return const DesktopScaffold();
        } else {
          return const MobileScaffold();
        }
      },
    );
  }
}
