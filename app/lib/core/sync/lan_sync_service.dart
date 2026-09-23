import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'sync_data_model.dart';

/// 局域网在线设备信息
class LanDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String version;
  final DateTime lastSeen;

  const LanDevice({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 23332,
    this.version = '1.0.0',
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'version': version,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory LanDevice.fromJson(Map<String, dynamic> json, {String? fallbackIp}) =>
      LanDevice(
        id: json['deviceId'] as String? ?? json['id'] as String? ?? 'unknown',
        name: json['deviceName'] as String? ?? json['name'] as String? ?? '未知设备',
        ip: json['ip'] as String? ?? fallbackIp ?? '127.0.0.1',
        port: (json['port'] as num?)?.toInt() ?? 23332,
        version: json['version'] as String? ?? '1.0.0',
        lastSeen: DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => id.hashCode ^ ip.hashCode ^ port.hashCode;
}

/// 局域网配对协议信息 (兼容 SPEC 7.2 lxsync:// 协议)
class LanPairingInfo {
  final String ip;
  final int port;
  final String authKey;
  final String? deviceName;

  const LanPairingInfo({
    required this.ip,
    this.port = 23332,
    required this.authKey,
    this.deviceName,
  });

  /// 解析二维码或直连字符串：lxsync://192.168.x.x:23332?key=AUTH_KEY&name=...
  static LanPairingInfo? fromUri(String uriString) {
    try {
      final uri = Uri.parse(uriString.trim());
      if (uri.scheme != 'lxsync') return null;

      final ip = uri.host;
      if (ip.isEmpty) return null;

      final port = uri.port != 0 ? uri.port : 23332;
      final key = uri.queryParameters['key'] ?? '';
      final name = uri.queryParameters['name'] ?? uri.queryParameters['deviceName'];

      return LanPairingInfo(
        ip: ip,
        port: port,
        authKey: key,
        deviceName: name,
      );
    } catch (_) {
      return null;
    }
  }

  /// 转换为标准配对 URI
  String toUri() {
    final queryParams = <String, String>{'key': authKey};
    if (deviceName != null && deviceName!.isNotEmpty) {
      queryParams['name'] = deviceName!;
    }
    final query = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'lxsync://$ip:$port?$query';
  }
}

/// 局域网直连同步服务端 (监听 23332 端口并处理握手、配对与快照投送)
class LanSyncServer {
  HttpServer? _server;
  int _port = 23332;
  String _authKey = '';
  String _deviceName = 'Mellow Desktop';
  String _deviceId = 'mellow-server';

  final StreamController<SyncSnapshot> _incomingSnapshotController =
      StreamController<SyncSnapshot>.broadcast();

  Stream<SyncSnapshot> get onSnapshotReceived =>
      _incomingSnapshotController.stream;

  bool get isRunning => _server != null;
  int get port => _port;
  String get authKey => _authKey;

  /// 启动内置 HTTP 同步服务端
  Future<int> start({
    dynamic address,
    int port = 23332,
    String? authKey,
    String? deviceName,
    String? deviceId,
  }) async {
    await stop();
    _port = port;
    _authKey = authKey ?? _generateRandomKey();
    if (deviceName != null) _deviceName = deviceName;
    if (deviceId != null) _deviceId = deviceId;

    final bindAddress = address ?? InternetAddress.anyIPv4;
    _server = await HttpServer.bind(bindAddress, _port);
    _port = _server!.port;
    _server!.listen(_handleRequest);
    return _port;
  }

  /// 请求分发处理
  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method.toUpperCase();

    // 跨域 CORS 支持
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept, X-Auth-Key',
    );
    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      if (path == '/sync/hello' && method == 'GET') {
        // 1. SPEC 7.2 握手探针
        final payload = {
          'status': 'ok',
          'action': 'hello',
          'version': '1.0.0',
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'port': _port,
        };
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(payload));
      } else if (path == '/sync/pair' && method == 'POST') {
        // 2. 配对校验
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final reqKey = data['key'] as String? ?? '';
        if (reqKey == _authKey) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'status': 'paired',
            'deviceId': _deviceId,
            'deviceName': _deviceName,
          }));
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': '密钥错误'}));
        }
      } else if (path == '/sync/push' && method == 'POST') {
        // 3. 接收快照数据投送 (支持标准快照与 SPEC 7.2 LX-Sync 报文)
        final reqKey = request.headers.value('x-auth-key') ??
            request.uri.queryParameters['key'];
        if (_authKey.isNotEmpty && reqKey != _authKey) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': '未授权的投送请求'}));
          await request.response.close();
          return;
        }

        final body = await utf8.decodeStream(request);
        final map = jsonDecode(body) as Map<String, dynamic>;

        SyncSnapshot snapshot;
        if (map['action'] == 'sync_list') {
          // LX-Sync 格式自动兼容导入
          snapshot = SyncSnapshot.fromLxSyncPayload(
            map,
            deviceId: 'lx-peer',
            deviceName: 'LX-Client',
          );
        } else {
          // Mellow 原生数据快照
          snapshot = SyncSnapshot.fromJson(map);
        }

        _incomingSnapshotController.add(snapshot);

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'received'}));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': e.toString()}));
    } finally {
      await request.response.close();
    }
  }

  /// 停止服务端
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  String _generateRandomKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().millisecondsSinceEpoch;
    var result = '';
    var seed = now;
    for (int i = 0; i < 6; i++) {
      result += chars[seed % chars.length];
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    }
    return result;
  }

  void dispose() {
    stop();
    _incomingSnapshotController.close();
  }
}

/// 局域网直连同步客户端 (支持握手探测、扫码直连、快照投送)
class LanSyncClient {
  final http.Client _client;
  final bool _isCustomClient;

  LanSyncClient({http.Client? client})
      : _client = client ?? http.Client(),
        _isCustomClient = client != null;

  /// 向对端发送握手探针 (/sync/hello)
  Future<LanDevice?> pingDevice(String host, {int port = 23332}) async {
    try {
      final uri = Uri.parse('http://$host:$port/sync/hello');
      final res = await _client.get(uri).timeout(
            const Duration(milliseconds: 1500),
          );
      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return LanDevice.fromJson(json, fallbackIp: host);
      }
    } catch (_) {}
    return null;
  }

  /// 设备配对验证
  Future<bool> pair(
    String host, {
    int port = 23332,
    required String authKey,
  }) async {
    try {
      final uri = Uri.parse('http://$host:$port/sync/pair');
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'key': authKey}),
          )
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 投送数据快照至目标对端 (/sync/push)
  Future<bool> pushSnapshot(
    String host,
    SyncSnapshot snapshot, {
    int port = 23332,
    String? authKey,
  }) async {
    try {
      final uri = Uri.parse('http://$host:$port/sync/push');
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      };
      if (authKey != null && authKey.isNotEmpty) {
        headers['x-auth-key'] = authKey;
      }

      final res = await _client
          .post(
            uri,
            headers: headers,
            body: utf8.encode(snapshot.toRawJson()),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 投送 LX-Sync 格式报文至目标对端 (与现有 LX-Music 客户端双向互通)
  Future<bool> pushLxSyncPayload(
    String host,
    Map<String, dynamic> lxPayload, {
    int port = 23332,
    String? authKey,
  }) async {
    try {
      final uri = Uri.parse('http://$host:$port/sync/push');
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      };
      if (authKey != null && authKey.isNotEmpty) {
        headers['x-auth-key'] = authKey;
      }

      final res = await _client
          .post(
            uri,
            headers: headers,
            body: utf8.encode(jsonEncode(lxPayload)),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 快速扫描指定网段内开启同步服务的设备
  Future<List<LanDevice>> scanSubnet(
    String subnetPrefix, {
    int port = 23332,
    int start = 1,
    int end = 254,
    Duration timeout = const Duration(milliseconds: 400),
  }) async {
    final List<LanDevice> discovered = [];
    final futures = <Future>[];

    for (int i = start; i <= end; i++) {
      final ip = '$subnetPrefix.$i';
      futures.add(
        pingDevice(ip, port: port).then((dev) {
          if (dev != null) {
            discovered.add(dev);
          }
        }),
      );
    }

    await Future.wait(futures);
    return discovered;
  }

  void dispose() {
    if (!_isCustomClient) {
      _client.close();
    }
  }
}

/// 局域网协同服务门面 (Facade: 服务端、客户端与配对管理统一中心)
class LanSyncService extends ChangeNotifier {
  static final LanSyncService instance = LanSyncService();

  final LanSyncServer server;
  final LanSyncClient client;

  final List<LanDevice> _discoveredDevices = [];
  bool _isScanning = false;
  String? _currentLocalIp;

  LanSyncService({
    LanSyncServer? server,
    LanSyncClient? client,
  })  : server = server ?? LanSyncServer(),
        client = client ?? LanSyncClient();

  List<LanDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  bool get isScanning => _isScanning;
  bool get isServerRunning => server.isRunning;
  String get serverAuthKey => server.authKey;
  int get serverPort => server.port;
  String get currentLocalIp => _currentLocalIp ?? '127.0.0.1';
  Stream<SyncSnapshot> get onSnapshotReceived => server.onSnapshotReceived;

  /// 获取本机主物理局域网 IPv4 地址
  static Future<String> getLocalIPv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (!addr.isLoopback &&
              (ip.startsWith('192.168.') ||
                  ip.startsWith('10.') ||
                  ip.startsWith('172.'))) {
            return ip;
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// 提取子网前缀 (例如 192.168.1.10 -> 192.168.1)
  static String getSubnetPrefix(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return '192.168.1';
  }

  /// 确保本机局域网接收服务已启动
  Future<int> ensureServerRunning() async {
    _currentLocalIp = await getLocalIPv4();
    if (server.isRunning) {
      return server.port;
    }
    try {
      final p = await startServer(port: 23332);
      return p;
    } catch (_) {
      // 端口冲突时自动寻找系统可用端口
      final p = await startServer(port: 0);
      return p;
    }
  }

  /// 启动本机服务
  Future<int> startServer({
    dynamic address,
    int port = 23332,
    String? authKey,
    String? deviceName,
    String? deviceId,
  }) async {
    final assignedPort = await server.start(
      address: address,
      port: port,
      authKey: authKey,
      deviceName: deviceName,
      deviceId: deviceId,
    );
    notifyListeners();
    return assignedPort;
  }

  /// 停止本机服务
  Future<void> stopServer() async {
    await server.stop();
    notifyListeners();
  }

  /// 生成供扫码的配对 URI
  String generatePairingUri(String localIp) {
    final info = LanPairingInfo(
      ip: localIp,
      port: server.port,
      authKey: server.authKey,
      deviceName: 'Mellow Music Desktop',
    );
    return info.toUri();
  }

  /// 发现与扫描设备
  Future<List<LanDevice>> scanNetwork(
    String subnetPrefix, {
    int port = 23332,
    int start = 1,
    int end = 254,
  }) async {
    _isScanning = true;
    notifyListeners();
    try {
      final devices = await client.scanSubnet(
        subnetPrefix,
        port: port,
        start: start,
        end: end,
      );
      _discoveredDevices.clear();
      _discoveredDevices.addAll(devices);
      return _discoveredDevices;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// 向目标设备投送快照
  Future<bool> pushToDevice(
    LanDevice device,
    SyncSnapshot snapshot, {
    String? authKey,
  }) async {
    return client.pushSnapshot(
      device.ip,
      snapshot,
      port: device.port,
      authKey: authKey,
    );
  }

  /// 向指定 IP/端口直接投送快照 (支持手动直连模式)
  Future<bool> pushToTarget(
    String host,
    SyncSnapshot snapshot, {
    int port = 23332,
    String? authKey,
  }) async {
    return client.pushSnapshot(
      host,
      snapshot,
      port: port,
      authKey: authKey,
    );
  }

  @override
  void dispose() {
    server.dispose();
    client.dispose();
    super.dispose();
  }
}
