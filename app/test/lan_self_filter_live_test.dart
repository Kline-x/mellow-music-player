import 'package:flutter_test/flutter_test.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';

void main() {
  test('局域网协同扫描真实网卡与 IP 集合剔除验证', () async {
    final ip = await LanSyncService.getLocalIPv4();
    final allLocalIps = await LanSyncService.getAllLocalIPv4s();
    expect(allLocalIps.contains('127.0.0.1'), isTrue);
    expect(allLocalIps.contains('localhost'), isTrue);
    expect(allLocalIps.contains(ip), isTrue);

    final service = LanSyncService.instance;
    expect(service.server.deviceId.startsWith('mellow-'), isTrue);

    // 模拟构造发现设备列表（含本机多个 IP 与远端机器）
    final mockDevices = [
      LanDevice(
        id: service.server.deviceId,
        name: '本机自身节点',
        ip: ip,
        port: 23332,
        lastSeen: DateTime.now(),
      ),
      LanDevice(
        id: 'self-loopback',
        name: '本机回环',
        ip: '127.0.0.1',
        port: 23332,
        lastSeen: DateTime.now(),
      ),
      LanDevice(
        id: 'win-11-remote',
        name: 'Windows 远端设备',
        ip: '192.168.1.8',
        port: 23332,
        lastSeen: DateTime.now(),
      ),
    ];

    // 执行过滤逻辑
    final filtered = mockDevices.where((dev) {
      final isLocalIpAndPort = allLocalIps.contains(dev.ip) && dev.port == service.serverPort;
      final isSelfDeviceId = dev.id == service.server.deviceId;
      return !isLocalIpAndPort && !isSelfDeviceId;
    }).toList();

    expect(filtered.length, 1);
    expect(filtered.first.id, 'win-11-remote');
    expect(filtered.first.ip, '192.168.1.8');
    expect(filtered.any((d) => d.ip == ip), isFalse);
    expect(filtered.any((d) => d.ip == '127.0.0.1'), isFalse);
  });
}
