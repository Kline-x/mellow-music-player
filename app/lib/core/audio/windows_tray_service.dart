import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'track_model.dart';
import '../storage/storage_service.dart';

/// 跨桌面平台（Windows / macOS / Linux）系统托盘与常驻后台管理服务
class DesktopTrayService {
  static const String trayChannelName = 'com.kline.mellow_music/tray';
  static const String channelName = trayChannelName;
  static const String windowChannelName = 'com.kline.mellow_music/window';

  static final DesktopTrayService instance = DesktopTrayService._internal();

  DesktopTrayService._internal();

  MethodChannel _trayChannel = const MethodChannel(trayChannelName);
  MethodChannel _windowChannel = const MethodChannel(windowChannelName);

  bool _initialized = false;
  bool _isSupportedPlatform = false;
  bool _minimizeToTray = true;
  String? _lastTooltip;

  bool get isInitialized => _initialized;
  bool get minimizeToTray => _minimizeToTray;
  String? get lastTooltip => _lastTooltip;
  bool get isSupported => _isSupportedPlatform;

  @visibleForTesting
  void setMockMethodChannel(MethodChannel channel) {
    _trayChannel = channel;
    _windowChannel = channel;
    _isSupportedPlatform = true;
  }

  @visibleForTesting
  void setMockChannels({MethodChannel? trayChannel, MethodChannel? windowChannel, bool supported = true}) {
    if (trayChannel != null) _trayChannel = trayChannel;
    if (windowChannel != null) _windowChannel = windowChannel;
    _isSupportedPlatform = supported;
  }

  /// 初始化托盘通道与读取偏好
  Future<void> init() async {
    _isSupportedPlatform = _isSupportedPlatform || (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.linux));

    _minimizeToTray = StorageService.instance.getMinimizeToTray();
    _trayChannel.setMethodCallHandler(_handleNativeCall);

    if (_isSupportedPlatform) {
      try {
        await _trayChannel.invokeMethod('init', {
          'minimizeToTray': _minimizeToTray,
          'defaultTooltip': 'Mellow Music · 润音',
        });
        _initialized = true;
      } catch (e) {
        debugPrint('[DesktopTrayService] 原生托盘初始化降级: $e');
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
        debugPrint('[DesktopTrayService] 接收托盘动作: $action');
        return true;
      default:
        return null;
    }
  }

  /// 更新托盘悬浮提示词
  Future<void> updateTooltip(Track track) async {
    final tip = '${track.title} - ${track.artist} · Mellow Music';
    _lastTooltip = tip;

    if (!_isSupportedPlatform) return;

    try {
      await _trayChannel.invokeMethod('updateTrayTooltip', {
        'tooltip': tip,
      });
    } catch (e) {
      debugPrint('[DesktopTrayService] updateTrayTooltip 异常: $e');
    }
  }

  /// 设置关闭窗口时是否最小化到托盘
  Future<void> setMinimizeToTray(bool enabled) async {
    _minimizeToTray = enabled;
    await StorageService.instance.saveMinimizeToTray(enabled);

    if (!_isSupportedPlatform) return;

    try {
      await _trayChannel.invokeMethod('setMinimizeToTray', {
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('[DesktopTrayService] setMinimizeToTray 异常: $e');
    }
  }

  /// 唤醒并置顶主窗口
  Future<void> showWindow() async {
    if (!_isSupportedPlatform) return;
    try {
      await _trayChannel.invokeMethod('showWindow');
    } catch (_) {}
  }

  /// 最小化隐藏到托盘
  Future<void> hideWindow() async {
    if (!_isSupportedPlatform) return;
    try {
      await _trayChannel.invokeMethod('hideWindow');
    } catch (_) {}
  }

  /// 最小化窗口 (到系统任务栏 / Dock)
  Future<void> minimizeWindow() async {
    if (!_isSupportedPlatform) return;
    try {
      await _windowChannel.invokeMethod('minimize');
    } catch (_) {
      try {
        await _trayChannel.invokeMethod('minimizeWindow');
      } catch (_) {}
    }
  }

  void dispose() {
    _trayChannel.setMethodCallHandler(null);
    _initialized = false;
  }
}

/// 兼容历史命名
typedef WindowsTrayService = DesktopTrayService;
