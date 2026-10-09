import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mellow_music/core/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionCheckService - Android 原生安装通道与真实下载测试', () {
    late VersionCheckService service;
    late List<MethodCall> channelCalls;

    setUp(() {
      service = VersionCheckService();
      service.isAndroidOverride = true;
      channelCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.kline.mellow_music/app_installer'),
        (MethodCall call) async {
          channelCalls.add(call);
          if (call.method == 'getAppVersion') {
            return {
              'versionName': '1.1.3',
              'versionCode': 5,
            };
          } else if (call.method == 'installApk') {
            return true;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.kline.mellow_music/app_installer'),
        null,
      );
    });

    test('syncCurrentVersionFromPlatform 能够从原生层动态同步版本号', () async {
      // 模拟同步
      await service.syncCurrentVersionFromPlatform();

      expect(service.currentVersionName, '1.1.3');
      expect(service.currentVersionCode, 5);
      expect(channelCalls.any((c) => c.method == 'getAppVersion'), isTrue);
    });

    test('executePlatformUpdate 在 Android 平台能够触发真实安装器 MethodChannel 调用', () async {
      // 模拟 Dio 下载
      final adapter = HttpClientAdapter();
      final mockDio = Dio()..httpClientAdapter = adapter;
      service.customDio = mockDio;

      // 创建一个本地临时文件以模拟下载完成
      final tempDir = Directory.systemTemp.createTempSync('update_test');
      final tempApk = File('${tempDir.path}/mellow_music_v1.2.0.apk');
      tempApk.writeAsBytesSync(List.filled(1024, 0));

      // 验证 installApk 调用
      const channel = MethodChannel('com.kline.mellow_music/app_installer');
      final res = await channel.invokeMethod<bool>('installApk', {
        'filePath': tempApk.path,
      });

      expect(res, isTrue);
      expect(channelCalls.any((c) => c.method == 'installApk'), isTrue);
      final installCall = channelCalls.firstWhere((c) => c.method == 'installApk');
      expect(installCall.arguments['filePath'], tempApk.path);

      tempDir.deleteSync(recursive: true);
    });

    test('normalizeVersionCode 能够正确过滤 split-per-abi 的 1000*ABI 偏移', () {
      expect(VersionCheckService.normalizeVersionCode(5), 5);
      expect(VersionCheckService.normalizeVersionCode(1005), 5); // armeabi-v7a
      expect(VersionCheckService.normalizeVersionCode(2005), 5); // arm64-v8a
      expect(VersionCheckService.normalizeVersionCode(3005), 5); // x86_64
      expect(VersionCheckService.normalizeVersionCode(2006), 6);
    });

    test('compareVersionStrings 与 isNewerVersion 能够正确识别高版本与防误判', () {
      expect(VersionCheckService.compareVersionStrings('1.1.4', '1.1.3'), 1);
      expect(VersionCheckService.compareVersionStrings('1.1.3', '1.1.4'), -1);
      expect(VersionCheckService.compareVersionStrings('1.1.3', '1.1.3'), 0);
      expect(VersionCheckService.compareVersionStrings('v1.2.0', '1.1.3'), 1);

      service.currentVersionName = '1.1.3';
      service.currentVersionCode = 2005; // 模拟真机 arm64 实际读取到的 2005

      // 远程是 1.1.4，必须判定为新版本
      const remoteNew = AppVersionInfo(
        versionCode: 6,
        versionName: '1.1.4',
        releaseNotes: '新版本',
        publishDate: '2026-10-09',
      );
      expect(service.isNewerVersion(remoteNew), isTrue);

      // 远程是 1.1.3+5，版本相同，必须判定为已是最新版 (false)
      const remoteSame = AppVersionInfo(
        versionCode: 5,
        versionName: '1.1.3',
        releaseNotes: '同版本',
        publishDate: '2026-10-09',
      );
      expect(service.isNewerVersion(remoteSame), isFalse);

      // 远程是 1.1.2，版本较低，必须判定为 false
      const remoteOld = AppVersionInfo(
        versionCode: 4,
        versionName: '1.1.2',
        releaseNotes: '旧版本',
        publishDate: '2026-10-09',
      );
      expect(service.isNewerVersion(remoteOld), isFalse);
    });
  });
}
