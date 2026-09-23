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
        // ignore: avoid_print
        print('>>> [STEP 8.1] AdaptiveScaffold constraints: maxWidth=${constraints.maxWidth}, maxHeight=${constraints.maxHeight}');
        final isDesktopWidth = constraints.maxWidth >= 1024;
        if (isDesktopWidth) {
          // ignore: avoid_print
          print('>>> [STEP 8.2] Choosing DesktopScaffold');
          return const DesktopScaffold();
        } else {
          // ignore: avoid_print
          print('>>> [STEP 8.2] Choosing MobileScaffold');
          return const MobileScaffold();
        }
      },
    );
  }
}
