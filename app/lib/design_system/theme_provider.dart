import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';
import '../core/storage/storage_service.dart';

/// 主题模式枚举：跟随系统、浅色、深色
enum AppThemeMode {
  system('跟随系统', Icons.brightness_auto_rounded),
  light('温润白瓷', Icons.light_mode_rounded),
  dark('深石墨夜间', Icons.dark_mode_rounded);

  final String label;
  final IconData icon;
  const AppThemeMode(this.label, this.icon);
}

/// 全局主题与个性化状态管理 (支持 SharedPreferences 真实本地持久化与系统模式响应)
class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _systemIsDark = false;
  AccentColorType _accentType = AccentColorType.blue;
  double _glowIntensity = 0.65;

  AppThemeMode get appThemeMode => _themeMode;
  ThemeMode get themeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// 当前实际生效的明暗状态 (跟随系统时实时基于系统当前亮度，手动时直接取设定值)
  bool get isDarkMode {
    if (_themeMode == AppThemeMode.system) {
      return _systemIsDark;
    }
    return _themeMode == AppThemeMode.dark;
  }

  AccentColorType get accentType => _accentType;
  double get glowIntensity => _glowIntensity;

  Color get accentColor => _accentType.getColor(isDarkMode);
  Color get canvasColor => MellowColors.canvas(isDarkMode);
  Color get cardColor => MellowColors.card(isDarkMode);
  Color get recessedColor => MellowColors.recessed(isDarkMode);
  Color get borderColor => MellowColors.border(isDarkMode);
  Color get textPrimary => MellowColors.textPrimary(isDarkMode);
  Color get textSecondary => MellowColors.textSecondary(isDarkMode);
  Color get textMuted => MellowColors.textMuted(isDarkMode);

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _readSystemBrightness();
    _loadFromStorage();
  }

  void _readSystemBrightness() {
    try {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _systemIsDark = brightness == Brightness.dark;
    } catch (_) {
      _systemIsDark = false;
    }
  }

  @override
  void didChangePlatformBrightness() {
    final prev = _systemIsDark;
    _readSystemBrightness();
    if (_themeMode == AppThemeMode.system && prev != _systemIsDark) {
      _syncWindowTheme();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadFromStorage() {
    final storage = StorageService.instance;

    // 1. 恢复主题模式
    final savedMode = storage.getThemeModeSetting();
    if (savedMode != null) {
      for (final mode in AppThemeMode.values) {
        if (mode.name == savedMode) {
          _themeMode = mode;
          break;
        }
      }
    } else {
      // 兼容历史老版本仅存 isDarkMode 的情况
      final legacyDark = storage.getIsDarkMode();
      if (legacyDark != null) {
        _themeMode = legacyDark ? AppThemeMode.dark : AppThemeMode.light;
      } else {
        _themeMode = AppThemeMode.system;
      }
    }

    final savedAccent = storage.getAccentType();
    if (savedAccent != null) {
      for (final type in AccentColorType.values) {
        if (type.name == savedAccent) {
          _accentType = type;
          break;
        }
      }
    }

    final savedGlow = storage.getGlowIntensity();
    if (savedGlow != null) {
      _glowIntensity = savedGlow.clamp(0.0, 1.0);
    }
    _syncWindowTheme();
  }

  void _syncWindowTheme() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        const MethodChannel('com.kline.mellow_music/window')
            .invokeMethod('setTheme', {'isDark': isDarkMode});
      } catch (_) {}
    }
  }

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      StorageService.instance.saveThemeModeSetting(mode.name);
      StorageService.instance.saveIsDarkMode(isDarkMode);
      _syncWindowTheme();
      notifyListeners();
    }
  }

  void toggleTheme() {
    if (isDarkMode) {
      setThemeMode(AppThemeMode.light);
    } else {
      setThemeMode(AppThemeMode.dark);
    }
  }

  void setDarkMode(bool value) {
    setThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);
  }

  void setAccentType(AccentColorType type) {
    if (_accentType != type) {
      _accentType = type;
      StorageService.instance.saveAccentType(type.name);
      notifyListeners();
    }
  }

  void setGlowIntensity(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_glowIntensity != clamped) {
      _glowIntensity = clamped;
      StorageService.instance.saveGlowIntensity(clamped);
      notifyListeners();
    }
  }
}
