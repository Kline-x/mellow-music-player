import 'package:flutter/material.dart';
import 'tokens.dart';

/// 全局主题与个性化状态管理
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

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      notifyListeners();
    }
  }

  void setAccentType(AccentColorType type) {
    if (_accentType != type) {
      _accentType = type;
      notifyListeners();
    }
  }

  void setGlowIntensity(double value) {
    _glowIntensity = value.clamp(0.0, 1.0);
    notifyListeners();
  }
}
