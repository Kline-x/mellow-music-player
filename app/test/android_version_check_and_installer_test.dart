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
  });
}
