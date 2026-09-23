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

void main() async {
  // ignore: avoid_print
  print('>>> [STEP 1] main started');
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
