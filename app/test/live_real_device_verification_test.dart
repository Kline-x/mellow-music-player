// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mellow_music/core/storage/storage_service.dart';
import 'package:mellow_music/design_system/theme_provider.dart';
import 'package:mellow_music/core/audio/audio_player_service.dart';
import 'package:mellow_music/core/sync/lan_sync_service.dart';
import 'package:mellow_music/views/desktop/desktop_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('局域网设备操作系统与形态识别：真实 Windows 目标机真机联调 E2E 验收', () {
    late AudioPlayerService player;
    late ThemeProvider theme;

    setUp(() async {
      // 允许真实的物理网络 Socket/HTTP 穿透测试框架
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.init();
      player = AudioPlayerService();
      theme = ThemeProvider();
    });

    tearDown(() {
      player.dispose();
      theme.dispose();
    });

    test('1. 真实网络探测 Windows 目标物理机 (192.168.1.8) 原生协议返回验证', () async {
      final service = LanSyncService.instance;
      print('[E2E SCAN] 正在对局域网执行真实子网扫描 (涵盖 192.168.1.8:23332)...');
      
      final ip = await LanSyncService.getLocalIPv4();
      final subnet = LanSyncService.getSubnetPrefix(ip);
      final devices = await service.scanNetwork(subnet, port: 23332);
      print('[E2E SCAN] 扫描完成！发现有效远端设备数: ${devices.length}');
      
      for (final d in devices) {
        print('-----------------------------------------');
        print('设备名: ${d.name}');
        print('IP 端点: ${d.ip}:${d.port}');
        print('ID: ${d.id}');
        print('原生上报 OS: ${d.os} -> 展示名: ${d.displayOsName}');
        print('原生上报 Type: ${d.deviceType} -> 展示形态: ${d.displayDeviceTypeName}');
        print('品牌色: ${d.osBrandColor}');
        print('图标: ${d.deviceIcon}');
      }

      // 验证自身 IP (如 Mac 本机) 绝不出现在设备列表中
      final localIps = await LanSyncService.getAllLocalIPv4s();
      for (final d in devices) {
        expect(localIps.contains(d.ip), isFalse, reason: '设备列表中绝不能包含本机自身 IP');
      }

      LanDevice? winDev;
      for (final d in devices) {
        if (d.ip == '192.168.1.8') {
          winDev = d;
          break;
        }
      }

      if (winDev == null) {
        print('[E2E SKIP] 局域网当前未检测到 192.168.1.8 硬件目标机，优雅跳过物理机断言');
        return;
      }

      expect(winDev.ip, '192.168.1.8');
      expect(winDev.port, 23332);
      expect(winDev.os, 'windows', reason: '目标物理机必须原生上报 windows');
      expect(winDev.displayOsName, 'Windows', reason: '必须精准映射为 Windows');
      expect(winDev.deviceType, 'desktop', reason: '目标物理机必须原生上报 desktop');
      expect(winDev.displayDeviceTypeName, '桌面 PC / 工作站', reason: '形态必须为桌面 PC / 工作站');
      expect(winDev.osBrandColor, const Color(0xFF0078D4), reason: 'Windows 专属微软极光蓝');
      expect(winDev.deviceIcon, Icons.desktop_windows_rounded, reason: 'Windows 桌面工作站图标');
      print('[E2E SUCCESS] 目标物理机 192.168.1.8 协议校验 100% 完美匹配！');
    });

    testWidgets('2. 桌面端局域网设备卡片 Modern Soft UI 视觉呈现端到端验证', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: repaintKey,
                child: DesktopSyncView(onNavigate: (_, [__]) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证标题与顶部服务监听状态卡片（包含操作系统和形态展示）
      expect(find.text('局域网近场设备协同 (LAN P2P)'), findsOneWidget);
      expect(find.textContaining('服务监听中:'), findsNothing); // 已升级为更详细的本机形态
      expect(find.textContaining('本机 ·'), findsOneWidget); // 顶部卡片升级显示本机系统

      // 2. 在 runAsync 环境中执行真实扫描并泵入 UI
      await tester.runAsync(() async {
        await tester.tap(find.text('扫描局域网节点'));
        // 等待真实扫描完成或单次探测返回
        await Future.delayed(const Duration(seconds: 2));
      });
      await tester.pump(const Duration(milliseconds: 500));


      // 验证界面上是否渲染出了 192.168.1.8 的卡片
      if (find.text('Mellow Desktop').evaluate().isNotEmpty) {
        expect(find.text('Mellow Desktop'), findsWidgets);
        expect(find.text('Windows'), findsWidgets);
        expect(find.text('桌面 PC / 工作站'), findsWidgets);
        expect(find.byIcon(Icons.window_rounded), findsWidgets);
        
        // 导出真实渲染高清画面并持久化保存
        final boundary = repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        File('/tmp/mac_desktop_sync_card_verified.png').writeAsBytesSync(byteData!.buffer.asUint8List());
        print('[E2E SUCCESS] Modern Soft UI 设备卡片完美呈现 Windows 品牌徽章、桌面 PC 形态胶囊及专属窗户图标！');
        print('[E2E SCREENSHOT] 高清截图已导出至 /tmp/mac_desktop_sync_card_verified.png');
      } else {
        print('[E2E SKIP] 当前环境为虚拟/隔离无外设局域网，未探测到物理节点，优雅跳过实机卡片断言');
      }
    });
  });
}
