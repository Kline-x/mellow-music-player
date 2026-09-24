import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'design_system/tokens.dart';
import 'design_system/theme_provider.dart';
import 'core/audio/audio_player_service.dart';
import 'core/audio/equalizer_manager.dart';
import 'core/storage/storage_service.dart';
import 'core/sources/lx_script_sandbox.dart';
import 'core/window/desktop_floating_lyric_service.dart';
import 'navigation/adaptive_scaffold.dart';

/// 全局 HTTP 覆盖器：强制所有底层连接（含 Image.network）附带桌面浏览器 User-Agent，
/// 根治各大国内音乐 CDN（网易云、酷我等）针对 Dart 默认 UA 的 403 Forbidden 屏蔽。
class MellowHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
    return client;
  }
}

void main() async {
  // ignore: avoid_print
  print('>>> [STEP 1] main started');
  HttpOverrides.global = MellowHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: avoid_print
  print('>>> [STEP 2] WidgetsFlutterBinding ensured');
  await StorageService.instance.init();
  // ignore: avoid_print
  print('>>> [STEP 3] StorageService initialized');
  await LxSourceEngine.instance.initFromStorage();
  // ignore: avoid_print
  print('>>> [STEP 4] LxSourceEngine initialized');
  await DesktopFloatingLyricService.instance.init();
  // ignore: avoid_print
  print('>>> [STEP 5] DesktopFloatingLyricService initialized, calling runApp');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerService()),
        ChangeNotifierProvider(create: (_) => EqualizerManager()),
      ],
      child: const MellowMusicApp(),
    ),
  );
  // ignore: avoid_print
  print('>>> [STEP 6] runApp called successfully');
}

class MellowMusicApp extends StatelessWidget {
  const MellowMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print('>>> [STEP 7] MellowMusicApp build executed');
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return MaterialApp(
      title: 'Mellow Music · 润音',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: MellowColors.canvasLight,
        colorScheme: ColorScheme.light(
          primary: theme.accentColor,
          surface: MellowColors.cardLight,
        ),
        fontFamily: 'PingFang SC',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MellowColors.canvasDark,
        colorScheme: ColorScheme.dark(
          primary: theme.accentColor,
          surface: MellowColors.cardDark,
        ),
        fontFamily: 'PingFang SC',
        useMaterial3: true,
      ),
      home: const AdaptiveScaffold(),
    );
  }
}
