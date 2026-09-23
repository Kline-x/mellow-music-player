import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'design_system/tokens.dart';
import 'design_system/theme_provider.dart';
import 'core/audio/audio_player_service.dart';
import 'core/audio/equalizer_manager.dart';
import 'core/storage/storage_service.dart';
import 'core/sources/lx_script_sandbox.dart';
import 'navigation/adaptive_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  await LxSourceEngine.instance.initFromStorage();
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
}

class MellowMusicApp extends StatelessWidget {
  const MellowMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
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
