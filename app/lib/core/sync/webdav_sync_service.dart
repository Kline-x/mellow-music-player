import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'sync_data_model.dart';

/// WebDAV 同步状态枚举
enum WebDavSyncStatus {
  idle('空闲'),
  connecting('连接服务器中...'),
  downloading('正在拉取云端快照...'),
  merging('正在合并冲突数据 (LWW)...'),
  uploading('正在上传合并快照...'),
  success('同步完成'),
  failed('同步失败');

  final String label;
  const WebDavSyncStatus(this.label);
}

/// WebDAV 配置参数
class WebDavConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remoteDirectory;
  final String backupFileName;
  final Duration autoSyncInterval;
  final bool isAutoSyncEnabled;

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remoteDirectory = '/mellow_music/',
    this.backupFileName = 'mellow_sync_snapshot.json',
    this.autoSyncInterval = const Duration(minutes: 30),
    this.isAutoSyncEnabled = false,
  });

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remoteDirectory,
    String? backupFileName,
    Duration? autoSyncInterval,
    bool? isAutoSyncEnabled,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDirectory: remoteDirectory ?? this.remoteDirectory,
      backupFileName: backupFileName ?? this.backupFileName,
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'remoteDirectory': remoteDirectory,
        'backupFileName': backupFileName,
        'autoSyncIntervalMinutes': autoSyncInterval.inMinutes,
        'isAutoSyncEnabled': isAutoSyncEnabled,
      };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
        serverUrl: json['serverUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        remoteDirectory: json['remoteDirectory'] as String? ?? '/mellow_music/',
        backupFileName:
            json['backupFileName'] as String? ?? 'mellow_sync_snapshot.json',
        autoSyncInterval: Duration(
          minutes: (json['autoSyncIntervalMinutes'] as num?)?.toInt() ?? 30,
        ),
        isAutoSyncEnabled: json['isAutoSyncEnabled'] as bool? ?? false,
      );

  /// 是否已配置基本端点与账号
  bool get isConfigured =>
      serverUrl.trim().isNotEmpty && username.trim().isNotEmpty;

  /// 组合生成完整的目标备份文件 URL
  Uri get fullBackupUri {
    var base = serverUrl.trim();
    if (!base.endsWith('/')) {
      base += '/';
    }
    var dir = remoteDirectory.trim();
    if (dir.startsWith('/')) {
      dir = dir.substring(1);
    }
    if (!dir.endsWith('/') && dir.isNotEmpty) {
      dir += '/';
    }
    return Uri.parse('$base$dir$backupFileName');
  }

  /// 远程目录 URI（用于 MKCOL 创建目录）
  Uri get remoteDirectoryUri {
    var base = serverUrl.trim();
    if (!base.endsWith('/')) {
      base += '/';
    }
    var dir = remoteDirectory.trim();
    if (dir.startsWith('/')) {
      dir = dir.substring(1);
    }
    if (!dir.endsWith('/') && dir.isNotEmpty) {
      dir += '/';
    }
    return Uri.parse('$base$dir');
  }

  /// HTTP Basic Auth 认证头
  Map<String, String> get authHeaders {
    final credentials = '$username:$password';
    final token = base64Encode(utf8.encode(credentials));
    return {
      'Authorization': 'Basic $token',
    };
  }
}

/// WebDAV 同步操作结果
class WebDavSyncResult {
  final bool isSuccess;
  final String message;
  final SyncSnapshot? snapshot;
  final DateTime? syncedAt;
  final int? statusCode;

  SyncSnapshot? get data => snapshot;
  String? get error => isSuccess ? null : message;

  const WebDavSyncResult({
    required this.isSuccess,
    required this.message,
    this.snapshot,
    this.syncedAt,
    this.statusCode,
  });

  factory WebDavSyncResult.success(SyncSnapshot snapshot, {String? msg}) =>
      WebDavSyncResult(
        isSuccess: true,
        message: msg ?? '同步成功',
        snapshot: snapshot,
        syncedAt: DateTime.now(),
        statusCode: 200,
      );

  factory WebDavSyncResult.failed(String message, {int? statusCode}) =>
      WebDavSyncResult(
        isSuccess: false,
        message: message,
        statusCode: statusCode,
      );
}

/// WebDAV 云端备份与双向同步服务
class WebDavSyncService extends ChangeNotifier {
  /// 便捷静态上传快照方法
  static Future<WebDavSyncResult> uploadSnapshotDirect(
    WebDavConfig config,
    SyncSnapshot snapshot, {
    http.Client? client,
  }) async {
    final service = WebDavSyncService(config: config, client: client);
    try {
      return await service.uploadSnapshot(snapshot);
    } finally {
      if (client == null) {
        service.dispose();
      }
    }
  }

  /// 便捷静态拉取快照方法
  static Future<WebDavSyncResult> downloadSnapshotDirect(
    WebDavConfig config, {
    http.Client? client,
  }) async {
    final service = WebDavSyncService(config: config, client: client);
    try {
      final snapshot = await service.downloadSnapshot();
      if (snapshot != null) {
        return WebDavSyncResult.success(snapshot);
      } else if (service.errorMessage != null) {
        return WebDavSyncResult.failed(service.errorMessage!);
      } else {
        return WebDavSyncResult.failed('云端暂无备份快照或已被清理');
      }
    } finally {
      if (client == null) {
        service.dispose();
      }
    }
  }

  final http.Client _client;
  final bool _isCustomClient;

  WebDavConfig config;
  WebDavSyncStatus _status = WebDavSyncStatus.idle;
  String? _errorMessage;
  DateTime? _lastSyncTime;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  WebDavSyncService({
    required this.config,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _isCustomClient = client != null;

  WebDavSyncStatus get status => _status;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;

  void updateConfig(WebDavConfig newConfig) {
    config = newConfig;
    notifyListeners();
  }

  void _setStatus(WebDavSyncStatus newStatus, {String? error}) {
    _status = newStatus;
    _errorMessage = error;
    notifyListeners();
  }

  /// 测试 WebDAV 连接与鉴权可用性
  Future<bool> testConnection() async {
    _setStatus(WebDavSyncStatus.connecting);
    try {
      final uri = config.remoteDirectoryUri;
      // 优先尝试 PROPFIND 获取目录属性，若不支持则降级为 HEAD / GET
      final request = http.Request('PROPFIND', uri)
        ..headers.addAll({
          ...config.authHeaders,
          'Depth': '0',
        });

      http.StreamedResponse response;
      try {
        response = await _client.send(request).timeout(
              const Duration(seconds: 10),
            );
      } catch (_) {
        // 部分 WebDAV 服务器不支持根 PROPFIND，使用 HEAD 重试
        final headRes = await _client
            .head(uri, headers: config.authHeaders)
            .timeout(const Duration(seconds: 10));
        if (headRes.statusCode >= 200 && headRes.statusCode < 400) {
          _setStatus(WebDavSyncStatus.idle);
          return true;
        }
        _setStatus(WebDavSyncStatus.failed, error: '连接测试失败: HTTP ${headRes.statusCode}');
        return false;
      }

      if (response.statusCode >= 200 && response.statusCode < 400) {
        _setStatus(WebDavSyncStatus.idle);
        return true;
      } else if (response.statusCode == 404) {
        // 目录尚不存在，但服务器连接与认证成功
        _setStatus(WebDavSyncStatus.idle);
        return true;
      } else if (response.statusCode == 401) {
        _setStatus(WebDavSyncStatus.failed, error: 'WebDAV 账号或应用密码错误 (401)');
        return false;
      } else {
        _setStatus(
          WebDavSyncStatus.failed,
          error: '服务器返回异常状态码: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      _setStatus(WebDavSyncStatus.failed, error: '无法连接到 WebDAV 服务器: $e');
      return false;
    }
  }

  /// 确保远程目录存在（若不存在则尝试创建 MKCOL）
  Future<bool> _ensureRemoteDirectory() async {
    try {
      final dirUri = config.remoteDirectoryUri;
      final request = http.Request('MKCOL', dirUri)
        ..headers.addAll(config.authHeaders);
      final response = await _client.send(request).timeout(
            const Duration(seconds: 10),
          );
      // 201 Created 代表创建成功，405 Method Not Allowed 代表目录已存在
      return response.statusCode == 201 ||
          response.statusCode == 405 ||
          (response.statusCode >= 200 && response.statusCode < 300);
    } catch (_) {
      return false;
    }
  }

  /// 上传数据快照到 WebDAV
  Future<WebDavSyncResult> uploadSnapshot(SyncSnapshot snapshot) async {
    _setStatus(WebDavSyncStatus.uploading);
    try {
      await _ensureRemoteDirectory();
      final targetUri = config.fullBackupUri;
      final rawData = snapshot.toRawJson();

      final res = await _client
          .put(
            targetUri,
            headers: {
              ...config.authHeaders,
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: utf8.encode(rawData),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _lastSyncTime = DateTime.now();
        _setStatus(WebDavSyncStatus.success);
        return WebDavSyncResult.success(snapshot, msg: '快照成功上传至云端');
      } else {
        final errMsg = '上传快照失败: HTTP ${res.statusCode} ${res.body}';
        _setStatus(WebDavSyncStatus.failed, error: errMsg);
        return WebDavSyncResult.failed(errMsg, statusCode: res.statusCode);
      }
    } catch (e) {
      final errMsg = '上传快照网络异常: $e';
      _setStatus(WebDavSyncStatus.failed, error: errMsg);
      return WebDavSyncResult.failed(errMsg);
    }
  }

  /// 从 WebDAV 拉取最新快照
  Future<SyncSnapshot?> downloadSnapshot() async {
    _setStatus(WebDavSyncStatus.downloading);
    try {
      final targetUri = config.fullBackupUri;
      final res = await _client
          .get(
            targetUri,
            headers: config.authHeaders,
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final bodyStr = utf8.decode(res.bodyBytes);
        final snapshot = SyncSnapshot.fromRawJson(bodyStr);
        _setStatus(WebDavSyncStatus.idle);
        return snapshot;
      } else if (res.statusCode == 404) {
        // 云端尚无快照备份
        _setStatus(WebDavSyncStatus.idle);
        return null;
      } else {
        _setStatus(
          WebDavSyncStatus.failed,
          error: '拉取快照失败: HTTP ${res.statusCode}',
        );
        return null;
      }
    } catch (e) {
      _setStatus(WebDavSyncStatus.failed, error: '拉取快照网络异常: $e');
      return null;
    }
  }

  /// 核心双向同步（拉取 -> Last-Write-Wins 冲突合并 -> 回传最新快照）
  Future<WebDavSyncResult> sync(SyncSnapshot localSnapshot) async {
    if (_isSyncing) {
      return WebDavSyncResult.failed('当前已有同步任务正在进行');
    }
    _isSyncing = true;
    try {
      // 1. 尝试下载云端快照
      final remoteSnapshot = await downloadSnapshot();

      SyncSnapshot mergedSnapshot;
      if (remoteSnapshot == null) {
        // 云端没有快照，直接将本地数据作为基准上传
        mergedSnapshot = localSnapshot;
      } else {
        // 2. 执行 Last-Write-Wins 冲突解决与合并
        _setStatus(WebDavSyncStatus.merging);
        mergedSnapshot = localSnapshot.merge(remoteSnapshot);
      }

      // 3. 上传合并后的全量数据快照
      final uploadRes = await uploadSnapshot(mergedSnapshot);
      if (uploadRes.isSuccess) {
        _lastSyncTime = DateTime.now();
        _setStatus(WebDavSyncStatus.success);
        return WebDavSyncResult.success(
          mergedSnapshot,
          msg: remoteSnapshot == null ? '首次备份成功' : '云端与本地双向同步合并成功',
        );
      } else {
        return uploadRes;
      }
    } catch (e) {
      final msg = '双向同步异常: $e';
      _setStatus(WebDavSyncStatus.failed, error: msg);
      return WebDavSyncResult.failed(msg);
    } finally {
      _isSyncing = false;
    }
  }

  /// 启动自动定时同步
  void startAutoSync({
    required Future<SyncSnapshot> Function() localSnapshotProvider,
    required Future<void> Function(SyncSnapshot merged) onMerged,
  }) {
    stopAutoSync();
    if (!config.isAutoSyncEnabled) return;

    _autoSyncTimer = Timer.periodic(config.autoSyncInterval, (timer) async {
      if (_isSyncing) return;
      try {
        final local = await localSnapshotProvider();
        final result = await sync(local);
        if (result.isSuccess && result.snapshot != null) {
          await onMerged(result.snapshot!);
        }
      } catch (e) {
        debugPrint('[WebDAV AutoSync Error]: $e');
      }
    });
  }

  /// 停止自动定时同步
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  @override
  void dispose() {
    stopAutoSync();
    if (!_isCustomClient) {
      _client.close();
    }
    super.dispose();
  }
}
