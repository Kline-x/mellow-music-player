import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/tokens.dart';
import '../design_system/theme_provider.dart';
import 'desktop_scaffold.dart';
import 'mobile_scaffold.dart';

/// 响应式双壳自适应架构 (AdaptiveScaffold)
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopWidth = constraints.maxWidth >= 1024;

        // 如果在桌面宽屏下，但用户点击了“移动端预览”
        if (isDesktopWidth && theme.isMobilePreview) {
          return Scaffold(
            backgroundColor: theme.isDarkMode ? Colors.black : const Color(0xFFE2E8F0),
            body: Center(
              child: Container(
                width: 390,
                height: 844,
                decoration: BoxDecoration(
                  borderRadius: MellowRadii.borderR32,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                  border: Border.all(color: Colors.black, width: 8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const MobileScaffold(),
                ),
              ),
            ),
          );
        }

        // 正常断点切换
        if (isDesktopWidth) {
          return const DesktopScaffold();
        } else {
          return const MobileScaffold();
        }
      },
    );
  }
}
