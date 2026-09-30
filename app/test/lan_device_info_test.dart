import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';

void main() {
  group('局域网设备操作系统与设备形态类型解析专项测试', () {
    test('完整 JSON 携带 os 与 deviceType 时准确解析', () {
      final json = {
        'deviceId': 'test-win-pc',
        'deviceName': 'Kline-Windows-11',
        'ip': '192.168.1.8',
        'port': 23332,
        'version': '1.2.0',
        'os': 'windows',
        'deviceType': 'desktop',
      };

      final dev = LanDevice.fromJson(json);
      expect(dev.os, 'windows');
      expect(dev.deviceType, 'desktop');
      expect(dev.displayOsName, 'Windows');
      expect(dev.displayDeviceTypeName, '桌面 PC / 工作站');
      expect(dev.osBrandColor, const Color(0xFF0078D4));
      expect(dev.deviceIcon, Icons.desktop_windows_rounded);
    });

    test('macOS 设备与手机端准确解析', () {
      final jsonMac = {
        'deviceId': 'test-macbook',
        'deviceName': 'MacBook Pro M1',
        'ip': '192.168.1.10',
        'os': 'macos',
        'deviceType': 'desktop',
      };
      final devMac = LanDevice.fromJson(jsonMac);
      expect(devMac.displayOsName, 'macOS');
      expect(devMac.deviceIcon, Icons.laptop_mac_rounded);

      final jsonPhone = {
        'deviceId': 'test-android-phone',
        'deviceName': 'Xiaomi 14 Pro',
        'ip': '192.168.1.15',
        'os': 'android',
        'deviceType': 'mobile',
      };
      final devPhone = LanDevice.fromJson(jsonPhone);
      expect(devPhone.displayOsName, 'Android');
      expect(devPhone.displayDeviceTypeName, '智能手机');
      expect(devPhone.deviceIcon, Icons.phone_iphone_rounded);
    });

    test('旧版协议未携带 os 时，根据名称启发式智能推断兜底', () {
      final jsonLegacyWin = {
        'deviceId': 'legacy-desktop-id',
        'deviceName': 'Mellow Windows PC',
        'ip': '192.168.1.20',
      };
      final devLegacyWin = LanDevice.fromJson(jsonLegacyWin);
      expect(devLegacyWin.displayOsName, 'Windows');
      expect(devLegacyWin.displayDeviceTypeName, '桌面 PC / 工作站');

      final jsonLegacyPhone = {
        'deviceId': 'legacy-phone-id',
        'deviceName': 'My iPhone 15',
        'ip': '192.168.1.25',
      };
      final devLegacyPhone = LanDevice.fromJson(jsonLegacyPhone);
      expect(devLegacyPhone.displayOsName, 'iOS');
      expect(devLegacyPhone.displayDeviceTypeName, '智能手机');
    });
  });
}
