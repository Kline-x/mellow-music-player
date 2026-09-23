import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'track_model.dart';
import '../storage/storage_service.dart';

/// Windows 系统托盘与常驻后台管理服务
class WindowsTrayService {
  static const String channelName = 'com.kline.mellow_music/tray';
  static final WindowsTrayService instance = WindowsTrayService._internal();

  WindowsTrayService._internal();

  MethodChannel _channel = const MethodChannel(channelName);
  bool _initialized = false;
  bool _isSupportedPlatform = false;
  bool _minimizeToTray = true;
  String? _lastTooltip;

  bool get isInitialized => _initialized;
  bool get minimizeToTray => _minimizeToTray;
  String? get lastTooltip => _lastTooltip;

  @visibleForTesting
  void setMockMethodChannel(MethodChannel channel) {
    _channel = channel;
    _isSupportedPlatform = true;
  }

  /// 初始化托盘通道与读取偏好
  Future<void> init() async {
    _isSupportedPlatform = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    _minimizeToTray = StorageService.instance.getMinimizeToTray();

    _channel.setMethodCallHandler(_handleNativeCall);

    if (_isSupportedPlatform) {
      try {
        await _channel.invokeMethod('init', {
          'minimizeToTray': _minimizeToTray,
          'defaultTooltip': 'Mellow Music · 润音',
        });
        _initialized = true;
      } catch (e) {
        debugPrint('[WindowsTrayService] 原生托盘初始化降级: $e');
        _initialized = false;
      }
    } else {
      _initialized = true;
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTrayAction':
        final action = call.arguments?.toString();
        debugPrint('[WindowsTrayService] 接收托盘动作: $action');
        return true;
      default:
        return null;
    }
  }

  /// 更新托盘悬浮提示词
  Future<void> updateTooltip(Track track) async {
    final tip = '${track.title} - ${track.artist} · Mellow Music';
    _lastTooltip = tip;

    if (!_isSupportedPlatform && !kDebugMode) return;

    try {
      await _channel.invokeMethod('updateTrayTooltip', {
        'tooltip': tip,
      });
    } catch (e) {
      debugPrint('[WindowsTrayService] updateTrayTooltip 异常: $e');
    }
  }

  /// 设置关闭窗口时是否最小化到托盘
  Future<void> setMinimizeToTray(bool enabled) async {
    _minimizeToTray = enabled;
    await StorageService.instance.saveMinimizeToTray(enabled);

    if (!_isSupportedPlatform && !kDebugMode) return;

    try {
      await _channel.invokeMethod('setMinimizeToTray', {
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('[WindowsTrayService] setMinimizeToTray 异常: $e');
    }
  }

  /// 唤醒并置顶主窗口
  Future<void> showWindow() async {
    if (!_isSupportedPlatform && !kDebugMode) return;
    try {
      await _channel.invokeMethod('showWindow');
    } catch (_) {}
  }

  /// 最小化隐藏到托盘
  Future<void> hideWindow() async {
    if (!_isSupportedPlatform && !kDebugMode) return;
    try {
      await _channel.invokeMethod('hideWindow');
    } catch (_) {}
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _initialized = false;
  }
}
