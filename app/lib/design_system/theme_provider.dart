import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';
import '../core/storage/storage_service.dart';

/// 全局主题与个性化状态管理 (支持 SharedPreferences 真实本地持久化)
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  AccentColorType _accentType = AccentColorType.blue;
  double _glowIntensity = 0.65;

  bool get isDarkMode => _isDarkMode;
  AccentColorType get accentType => _accentType;
  double get glowIntensity => _glowIntensity;

  Color get accentColor => _accentType.getColor(_isDarkMode);
  Color get canvasColor => MellowColors.canvas(_isDarkMode);
  Color get cardColor => MellowColors.card(_isDarkMode);
  Color get recessedColor => MellowColors.recessed(_isDarkMode);
  Color get borderColor => MellowColors.border(_isDarkMode);
  Color get textPrimary => MellowColors.textPrimary(_isDarkMode);
  Color get textSecondary => MellowColors.textSecondary(_isDarkMode);
  Color get textMuted => MellowColors.textMuted(_isDarkMode);

  ThemeProvider() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final storage = StorageService.instance;
    final savedDark = storage.getIsDarkMode();
    if (savedDark != null) {
      _isDarkMode = savedDark;
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
            .invokeMethod('setTheme', {'isDark': _isDarkMode});
      } catch (_) {}
    }
  }

  void toggleTheme() {
    setDarkMode(!_isDarkMode);
  }

  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      StorageService.instance.saveIsDarkMode(value);
      _syncWindowTheme();
      notifyListeners();
    }
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
