import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../storage/storage_service.dart';
import '../audio/track_model.dart';

/// 桌面悬浮歌词与系统级窗口置顶/穿透管理服务
class DesktopFloatingLyricService extends ChangeNotifier {
  static const String channelName = 'com.kline.mellow_music/floating_lyric';
  static final DesktopFloatingLyricService instance = DesktopFloatingLyricService._internal();

  DesktopFloatingLyricService._internal();

  MethodChannel _channel = const MethodChannel(channelName);
  bool _isInitialized = false;

  bool _isEnabled = false;
  bool _isLocked = false;
  bool _isAlwaysOnTop = false;
  String _fontSizeLevel = 'normal'; // 'normal', 'large', 'xlarge'
  Offset? _position;

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  bool get isLocked => _isLocked;
  bool get isAlwaysOnTop => _isAlwaysOnTop;
  String get fontSizeLevel => _fontSizeLevel;
  Offset? get position => _position;

  bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @visibleForTesting
  void setMockMethodChannel(MethodChannel channel) {
    _channel = channel;
  }

  /// 初始化服务并恢复本地持久化配置
  Future<void> init() async {
    final storage = StorageService.instance;
    _isEnabled = storage.getFloatingLyricEnabled() ?? false;
    _isLocked = storage.getFloatingLyricLocked() ?? false;
    _isAlwaysOnTop = storage.getFloatingLyricAlwaysOnTop() ?? false;
    _fontSizeLevel = storage.getFloatingLyricFontSize() ?? 'normal';

    final posX = storage.getFloatingLyricPosX();
    final posY = storage.getFloatingLyricPosY();
    if (posX != null && posY != null) {
      _position = Offset(posX, posY);
    }

    _channel.setMethodCallHandler(_handleNativeCall);
    _isInitialized = true;

    // 若运行在 Windows 平台，同步初始置顶与穿透状态至原生窗口
    if (isWindows) {
      if (_isAlwaysOnTop) {
        await _invokeNativeAlwaysOnTop(_isAlwaysOnTop);
      }
      if (_isLocked && _isEnabled) {
        await _invokeNativeClickThrough(_isLocked);
      }
    }

    notifyListeners();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'toggleFloatingLyric':
        await toggleEnabled();
        break;
      case 'onAlwaysOnTopChanged':
        if (call.arguments is Map) {
          final args = call.arguments as Map;
          final onTop = args['alwaysOnTop'] as bool? ?? false;
          _isAlwaysOnTop = onTop;
          await StorageService.instance.saveFloatingLyricAlwaysOnTop(onTop);
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  /// 开启 / 关闭桌面悬浮歌词
  Future<void> setEnabled(bool value) async {
    if (_isEnabled == value) return;
    _isEnabled = value;
    await StorageService.instance.saveFloatingLyricEnabled(value);

    if (isWindows && _isLocked) {
      await _invokeNativeClickThrough(value ? _isLocked : false);
    }

    notifyListeners();
  }

  Future<void> toggleEnabled() async {
    await setEnabled(!_isEnabled);
  }

  /// 切换锁定状态 (锁定后鼠标事件穿透)
  Future<void> setLocked(bool value) async {
    if (_isLocked == value) return;
    _isLocked = value;
    await StorageService.instance.saveFloatingLyricLocked(value);

    if (isWindows && _isEnabled) {
      await _invokeNativeClickThrough(value);
    }

    notifyListeners();
  }

  Future<void> toggleLocked() async {
    await setLocked(!_isLocked);
  }

  /// 切换窗口系统级置顶 (Win32 HWND_TOPMOST)
  Future<void> setAlwaysOnTop(bool value) async {
    if (_isAlwaysOnTop == value) return;
    _isAlwaysOnTop = value;
    await StorageService.instance.saveFloatingLyricAlwaysOnTop(value);

    if (isWindows) {
      await _invokeNativeAlwaysOnTop(value);
    }

    notifyListeners();
  }

  Future<void> toggleAlwaysOnTop() async {
    await setAlwaysOnTop(!_isAlwaysOnTop);
  }

  /// 切换字号档位
  Future<void> setFontSizeLevel(String level) async {
    _fontSizeLevel = level;
    await StorageService.instance.saveFloatingLyricFontSize(level);
    notifyListeners();
  }

  Future<void> cycleFontSize() async {
    switch (_fontSizeLevel) {
      case 'normal':
        await setFontSizeLevel('large');
        break;
      case 'large':
        await setFontSizeLevel('xlarge');
        break;
      case 'xlarge':
      default:
        await setFontSizeLevel('normal');
        break;
    }
  }

  /// 保存桌面歌词拖拽定位坐标
  Future<void> savePosition(Offset pos) async {
    _position = pos;
    await StorageService.instance.saveFloatingLyricPosition(pos.dx, pos.dy);
    notifyListeners();
  }

  /// 向上报送当前播放歌词数据至原生层
  Future<void> updateLyric({
    required String currentLine,
    required String nextLine,
    Track? track,
  }) async {
    if (!isWindows) return;
    try {
      await _channel.invokeMethod('updateLyric', {
        'currentLine': currentLine,
        'nextLine': nextLine,
        'title': track?.title ?? '',
        'artist': track?.artist ?? '',
      });
    } catch (_) {}
  }

  Future<void> _invokeNativeAlwaysOnTop(bool onTop) async {
    try {
      await _channel.invokeMethod('setAlwaysOnTop', {'alwaysOnTop': onTop});
    } catch (_) {}
  }

  Future<void> _invokeNativeClickThrough(bool clickThrough) async {
    try {
      await _channel.invokeMethod('setClickThrough', {'clickThrough': clickThrough});
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
