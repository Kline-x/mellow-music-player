import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'track_model.dart';

/// SMTC 按钮事件枚举
enum SmtcButtonAction {
  play,
  pause,
  togglePlay,
  next,
  previous,
  stop,
}

/// Windows 原生系统级媒体控制 (SMTC) 服务
/// 负责与 Windows 10/11 的 SystemMediaTransportControls 以及任务栏媒体浮层进行通信
class WindowsSmtcService {
  static const String channelName = 'com.kline.mellow_music/smtc';
  static final WindowsSmtcService instance = WindowsSmtcService._internal();

  WindowsSmtcService._internal();

  MethodChannel _channel = const MethodChannel(channelName);
  bool _initialized = false;
  bool _isSupportedPlatform = false;

  void Function(SmtcButtonAction action)? _onActionCallback;
  void Function(Duration position)? _onSeekCallback;

  // 上报状态快照 (用于测试断言与状态恢复)
  Track? _lastTrack;
  bool? _lastIsPlaying;
  Duration? _lastPosition;
  Duration? _lastDuration;

  Track? get lastTrack => _lastTrack;
  bool? get lastIsPlaying => _lastIsPlaying;
  Duration? get lastPosition => _lastPosition;
  Duration? get lastDuration => _lastDuration;
  bool get isInitialized => _initialized;

  /// 测试专用的 MethodChannel 注入器
  @visibleForTesting
  void setMockMethodChannel(MethodChannel channel) {
    _channel = channel;
    _isSupportedPlatform = true;
  }

  /// 初始化 SMTC 监听
  Future<void> init({
    required void Function(SmtcButtonAction action) onAction,
    void Function(Duration position)? onSeek,
  }) async {
    _onActionCallback = onAction;
    _onSeekCallback = onSeek;

    // 平台检测：非 Web 且运行于 Windows
    _isSupportedPlatform = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    _channel.setMethodCallHandler(_handleNativeMethodCall);

    if (_isSupportedPlatform) {
      try {
        await _channel.invokeMethod('init');
        _initialized = true;
      } catch (e) {
        debugPrint('[WindowsSmtcService] SMTC 原生通道初始化降级或受限: $e');
        _initialized = false;
      }
    } else {
      _initialized = true; // 在测试/非 Win 平台保持就绪状态以供测试模拟
    }
  }

  /// 处理来自 Windows 原生层的 SMTC 与硬件按键事件
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onButtonPressed':
        final String? button = call.arguments is Map ? call.arguments['button'] : call.arguments?.toString();
        if (button != null) {
          switch (button.toLowerCase()) {
            case 'play':
              _onActionCallback?.call(SmtcButtonAction.play);
              break;
            case 'pause':
              _onActionCallback?.call(SmtcButtonAction.pause);
              break;
            case 'toggleplay':
              _onActionCallback?.call(SmtcButtonAction.togglePlay);
              break;
            case 'next':
              _onActionCallback?.call(SmtcButtonAction.next);
              break;
            case 'previous':
              _onActionCallback?.call(SmtcButtonAction.previous);
              break;
            case 'stop':
              _onActionCallback?.call(SmtcButtonAction.stop);
              break;
          }
        }
        return true;

      case 'onSeekRequested':
        final int? positionMs = call.arguments is Map ? call.arguments['positionMs'] : call.arguments as int?;
        if (positionMs != null && _onSeekCallback != null) {
          _onSeekCallback!(Duration(milliseconds: positionMs));
        }
        return true;

      default:
        return null;
    }
  }

  /// 向 Windows SMTC 推送歌曲元数据（曲名、歌手、专辑、封面图）
  Future<void> updateMetadata(Track track) async {
    _lastTrack = track;
    if (!_isSupportedPlatform && !kDebugMode) return;

    try {
      await _channel.invokeMethod('updateMetadata', {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'durationMs': track.duration.inMilliseconds,
        'coverUrl': track.coverUrl,
      });
    } catch (e) {
      debugPrint('[WindowsSmtcService] updateMetadata 失败或受限: $e');
    }
  }

  /// 向 Windows SMTC 同步播放状态（Playing / Paused）
  Future<void> updatePlaybackState(bool isPlaying) async {
    _lastIsPlaying = isPlaying;
    if (!_isSupportedPlatform && !kDebugMode) return;

    try {
      await _channel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
      });
    } catch (e) {
      debugPrint('[WindowsSmtcService] updatePlaybackState 失败或受限: $e');
    }
  }

  /// 向 Windows SMTC 同步进度时间轴
  Future<void> updateTimeline(Duration position, Duration duration) async {
    _lastPosition = position;
    _lastDuration = duration;
    if (!_isSupportedPlatform && !kDebugMode) return;

    try {
      await _channel.invokeMethod('updateTimeline', {
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
      });
    } catch (e) {
      debugPrint('[WindowsSmtcService] updateTimeline 失败或受限: $e');
    }
  }

  /// 清除当前 SMTC 状态
  Future<void> clear() async {
    _lastTrack = null;
    _lastIsPlaying = false;
    _lastPosition = Duration.zero;
    _lastDuration = Duration.zero;

    if (!_isSupportedPlatform && !kDebugMode) return;

    try {
      await _channel.invokeMethod('clear');
    } catch (e) {
      debugPrint('[WindowsSmtcService] clear 失败或受限: $e');
    }
  }

  /// 释放服务资源
  void dispose() {
    _channel.setMethodCallHandler(null);
    _onActionCallback = null;
    _onSeekCallback = null;
    _initialized = false;
  }
}
