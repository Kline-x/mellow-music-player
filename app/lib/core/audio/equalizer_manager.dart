import 'package:flutter/foundation.dart';
import '../storage/storage_service.dart';

/// 均衡器预设风格
enum EqualizerPreset {
  flat('原声直通 (Flat)'),
  bassBoost('澎湃低音 (Bass Boost)'),
  clearVocal('通透人声 (Clear Vocal)'),
  warmJazz('温润爵士 (Warm Jazz)'),
  spatial3d('全景声场 (Spatial 3D)'),
  electronic('纯享电音 (Electronic)'),
  rock('现场摇滚 (Rock)'),
  classical('沉浸古典 (Classical)'),
  custom('自定义调校 (Custom)');

  final String label;
  const EqualizerPreset(this.label);
}

/// 声学 10 频段硬件均衡器管理服务
class EqualizerManager extends ChangeNotifier {
  static final EqualizerManager instance = EqualizerManager._internal();

  static const List<String> frequencyBands = [
    '31Hz',
    '62Hz',
    '125Hz',
    '250Hz',
    '500Hz',
    '1kHz',
    '2kHz',
    '4kHz',
    '8kHz',
    '16kHz',
  ];

  // 10 频段当前增益值 (-12.0 ~ +12.0 dB)
  List<double> _bandGains = List.filled(10, 0.0);
  EqualizerPreset _currentPreset = EqualizerPreset.flat;
  bool _isEnabled = true;

  EqualizerManager() {
    _restoreFromStorage();
  }

  EqualizerManager._internal() {
    _restoreFromStorage();
  }

  void _restoreFromStorage() {
    final storage = StorageService.instance;
    _isEnabled = storage.getEqualizerEnabled();

    final savedPresetStr = storage.getEqualizerPreset();
    if (savedPresetStr != null) {
      final matched = EqualizerPreset.values.where((p) => p.name == savedPresetStr).firstOrNull;
      if (matched != null) {
        _currentPreset = matched;
      }
    }

    final savedGains = storage.getEqualizerGains();
    if (savedGains != null && savedGains.length == 10) {
      _bandGains = List<double>.from(savedGains);
    } else if (_currentPreset != EqualizerPreset.flat && _currentPreset != EqualizerPreset.custom) {
      _applyPresetGains(_currentPreset);
    }
  }

  List<double> get bandGains => List.unmodifiable(_bandGains);
  EqualizerPreset get currentPreset => _currentPreset;
  bool get isEnabled => _isEnabled;

  void toggleEnabled() {
    _isEnabled = !_isEnabled;
    StorageService.instance.saveEqualizerEnabled(_isEnabled);
    notifyListeners();
  }

  void setBandGain(int index, double gain) {
    if (index >= 0 && index < 10) {
      _bandGains[index] = gain.clamp(-12.0, 12.0);
      _currentPreset = EqualizerPreset.custom;
      StorageService.instance.saveEqualizerGains(_bandGains);
      StorageService.instance.saveEqualizerPreset(_currentPreset.name);
      notifyListeners();
    }
  }

  void applyPreset(EqualizerPreset preset) {
    _currentPreset = preset;
    _applyPresetGains(preset);
    StorageService.instance.saveEqualizerPreset(_currentPreset.name);
    StorageService.instance.saveEqualizerGains(_bandGains);
    notifyListeners();
  }

  void _applyPresetGains(EqualizerPreset preset) {
    switch (preset) {
      case EqualizerPreset.flat:
        _bandGains = List.filled(10, 0.0);
        break;
      case EqualizerPreset.bassBoost:
        _bandGains = [7.0, 5.5, 3.0, 1.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.5];
        break;
      case EqualizerPreset.clearVocal:
        _bandGains = [-1.0, 0.0, 0.5, 1.5, 2.5, 3.0, 5.0, 3.5, 1.5, 0.0];
        break;
      case EqualizerPreset.warmJazz:
        _bandGains = [2.0, 2.5, 3.5, 4.0, 2.0, 1.0, 0.5, 0.0, -1.0, -1.5];
        break;
      case EqualizerPreset.spatial3d:
        _bandGains = [2.0, 1.0, 0.0, 0.0, 0.5, 1.5, 3.0, 5.0, 6.5, 7.0];
        break;
      case EqualizerPreset.electronic:
        _bandGains = [6.0, 5.0, 2.5, 0.5, -1.0, 0.0, 1.5, 3.5, 5.0, 6.0];
        break;
      case EqualizerPreset.rock:
        _bandGains = [4.5, 4.0, 3.0, 1.5, -0.5, 0.5, 2.5, 4.0, 4.5, 3.5];
        break;
      case EqualizerPreset.classical:
        _bandGains = [3.0, 2.5, 2.0, 1.0, -0.5, -0.5, 1.0, 2.5, 3.5, 4.0];
        break;
      case EqualizerPreset.custom:
        break;
    }
  }

  void reset() {
    applyPreset(EqualizerPreset.flat);
  }

  /// 生成 libmpv firequalizer 滤镜参数字符串
  String toLibmpvFilterString() {
    if (!_isEnabled) return '';
    final buffer = StringBuffer('firequalizer=gain=\'');
    final freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    for (int i = 0; i < freqs.length; i++) {
      buffer.write('gain_interpolate(${freqs[i]},${_bandGains[i].toStringAsFixed(1)})');
      if (i < freqs.length - 1) buffer.write('+');
    }
    buffer.write('\'');
    return buffer.toString();
  }
}
