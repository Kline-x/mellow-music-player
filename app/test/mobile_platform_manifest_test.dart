import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('移动端平台合规与发布配置测试 (Mobile Platform Manifest & Configuration)', () {
    test('Android AndroidManifest.xml 包含后台音频、通知、明文局域网与 P2P 发现权限', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml 必须存在');

      final content = manifestFile.readAsStringSync();

      // 网络与后台唤醒
      expect(content.contains('android.permission.INTERNET'), isTrue);
      expect(content.contains('android.permission.ACCESS_NETWORK_STATE'), isTrue);
      expect(content.contains('android.permission.WAKE_LOCK'), isTrue);

      // 后台音频与服务
      expect(content.contains('android.permission.FOREGROUND_SERVICE'), isTrue);
      expect(content.contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'), isTrue);

      // 局域网近场同步与组播发现
      expect(content.contains('android.permission.ACCESS_WIFI_STATE'), isTrue);
      expect(content.contains('android.permission.CHANGE_WIFI_MULTICAST_STATE'), isTrue);

      // 通知与音频设置
      expect(content.contains('android.permission.POST_NOTIFICATIONS'), isTrue);
      expect(content.contains('android.permission.MODIFY_AUDIO_SETTINGS'), isTrue);

      // 支持局域网明文传输与音源加载
      expect(content.contains('android:usesCleartextTraffic="true"'), isTrue);
    });

    test('Android build.gradle.kts 配置包含正确的 namespace 与 application ID', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content.contains('namespace = "com.mellow.music.app"'), isTrue);
      expect(content.contains('applicationId = "com.mellow.music.app"'), isTrue);
    });

    test('iOS Runner/Info.plist 包含后台音频模式、局域网权限声明与 ATS 明文支持', () {
      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue, reason: 'iOS Info.plist 必须存在');

      final content = plistFile.readAsStringSync();

      // 显示名称
      expect(content.contains('<string>Mellow Music</string>'), isTrue);

      // 后台音频播放模式
      expect(content.contains('<key>UIBackgroundModes</key>'), isTrue);
      expect(content.contains('<string>audio</string>'), isTrue);

      // 局域网权限声明
      expect(content.contains('<key>NSLocalNetworkUsageDescription</key>'), isTrue);
      expect(content.contains('_mellowsync._tcp'), isTrue);

      // ATS 网络安全配置
      expect(content.contains('<key>NSAppTransportSecurity</key>'), isTrue);
      expect(content.contains('<key>NSAllowsArbitraryLoads</key>'), isTrue);
    });
  });
}
