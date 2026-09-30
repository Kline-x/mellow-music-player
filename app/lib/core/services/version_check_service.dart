import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 跨平台版本升级包详情
class PlatformUpdateInfo {
  final String? downloadUrl;
  final String? storeUrl;
  final String? backupUrl;
  final int? fileSize;
  final String? sha256;
  final int? versionCode;
  final String installMode; // in_app_download, browser, app_store

  const PlatformUpdateInfo({
    this.downloadUrl,
    this.storeUrl,
    this.backupUrl,
    this.fileSize,
    this.sha256,
    this.versionCode,
    this.installMode = 'in_app_download',
  });

  factory PlatformUpdateInfo.fromJson(Map<String, dynamic> json) =>
      PlatformUpdateInfo(
        downloadUrl: json['downloadUrl'] as String?,
        storeUrl: json['storeUrl'] as String?,
        backupUrl: json['backupUrl'] as String?,
        fileSize: json['fileSize'] as int?,
        sha256: json['sha256'] as String?,
        versionCode: json['versionCode'] as int?,
        installMode: json['installMode'] as String? ?? 'in_app_download',
      );

  Map<String, dynamic> toJson() => {
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
        if (storeUrl != null) 'storeUrl': storeUrl,
        if (backupUrl != null) 'backupUrl': backupUrl,
        if (fileSize != null) 'fileSize': fileSize,
        if (sha256 != null) 'sha256': sha256,
        if (versionCode != null) 'versionCode': versionCode,
        'installMode': installMode,
      };
}

/// 版本更新信息数据模型 (跨端自适应矩阵)
class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String releaseNotes;
  final String publishDate;
  final bool isForceUpdate;
  final Map<String, PlatformUpdateInfo> platforms;

  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.releaseNotes,
    required this.publishDate,
    this.isForceUpdate = false,
    this.platforms = const {},
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = json['platforms'] as Map<String, dynamic>? ?? {};
    final parsedPlatforms = <String, PlatformUpdateInfo>{};
    rawPlatforms.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedPlatforms[key] = PlatformUpdateInfo.fromJson(val);
      }
    });

    return AppVersionInfo(
      versionCode: json['versionCode'] as int? ?? 1,
      versionName: json['versionName'] as String? ?? '1.0.0',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      publishDate: json['publishDate'] as String? ?? '',
      isForceUpdate: json['isForceUpdate'] as bool? ?? false,
      platforms: parsedPlatforms,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    platforms.forEach((k, v) => map[k] = v.toJson());
    return {
      'versionCode': versionCode,
      'versionName': versionName,
      'releaseNotes': releaseNotes,
      'publishDate': publishDate,
      'isForceUpdate': isForceUpdate,
      'platforms': map,
    };
  }

  /// 获取当前宿主平台的专属升级配置
  PlatformUpdateInfo? get currentPlatformInfo {
    if (kIsWeb) return platforms['web'] ?? platforms['windows'];
    if (Platform.isWindows) return platforms['windows'];
    if (Platform.isMacOS) return platforms['macos'];
    if (Platform.isAndroid) return platforms['android'];
    if (Platform.isIOS) return platforms['ios'];
    if (Platform.isLinux) return platforms['linux'];
    return platforms['windows'];
  }

  String get downloadUrl {
    final info = currentPlatformInfo;
    return info?.downloadUrl ??
        info?.backupUrl ??
        'https://github.com/Kline-x/mellow-music-player/releases';
  }

  String get displayTag => 'v$versionName+$versionCode';
}

/// 正在执行的后台下载任务
class ActiveDownload {
  final AppVersionInfo info;
  final CancelToken cancelToken;
  final double progress;
  final String? speedText;

  const ActiveDownload({
    required this.info,
    required this.cancelToken,
    this.progress = 0.0,
    this.speedText,
  });

  ActiveDownload copyWith({double? progress, String? speedText}) =>
      ActiveDownload(
        info: info,
        cancelToken: cancelToken,
        progress: progress ?? this.progress,
        speedText: speedText ?? this.speedText,
      );
}

/// 远程版本检测与无损保留数据应用内升级服务 (VersionCheckService)
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  Dio? _customDio;
  Dio get _dio =>
      _customDio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 3000),
          receiveTimeout: const Duration(milliseconds: 4000),
        ),
      );

  @visibleForTesting
  set customDio(Dio dio) => _customDio = dio;

  /// 后台正在进行的下载
  final ValueNotifier<ActiveDownload?> activeDownload =
      ValueNotifier<ActiveDownload?>(null);

  bool get hasActiveDownload => activeDownload.value != null;

  /// 当前客户端基准版本号 (对应 pubspec.yaml: 1.1.1+3)
  int currentVersionCode = 3;
  String currentVersionName = '1.1.1';

  static const String appRepo = 'Kline-x/mellow-music-player';

  /// 国内多级高可用镜像源列表
  static const List<String> gitHubProxyMirrors = [
    'https://ghproxy.net/',
    'https://ghfast.top/',
    'https://gh-proxy.com/',
    'https://mirror.ghproxy.com/',
    'https://ghproxy.cc/',
  ];

  /// 生成国内高可用加速下载候选列表
  static List<String> buildAcceleratedDownloadUrls(String? originalUrl) {
    if (originalUrl == null || originalUrl.trim().isEmpty) return [];
    var cleanUrl = originalUrl.trim();
    for (final mirror in gitHubProxyMirrors) {
      if (cleanUrl.startsWith(mirror)) {
        cleanUrl = cleanUrl.substring(mirror.length);
        break;
      }
    }

    final result = <String>[];
    if (cleanUrl.contains('github.com') ||
        cleanUrl.contains('githubusercontent.com')) {
      for (final mirror in gitHubProxyMirrors) {
        result.add('$mirror$cleanUrl');
      }
    }
    result.add(cleanUrl);
    return result.toSet().toList();
  }

  /// 对候选下载节点并发轻量测速探测
  static Future<List<String>> raceCandidateUrls(
    List<String> urls, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    if (urls.length <= 1) return urls;
    final results = <String, int>{};
    final futures = <Future<void>>[];

    for (final url in urls) {
      futures.add(() async {
        final sw = Stopwatch()..start();
        try {
          final dio = Dio(BaseOptions(
            connectTimeout: timeout,
            receiveTimeout: timeout,
            headers: {'range': 'bytes=0-1024'},
          ));
          final res = await dio.head(url);
          if (res.statusCode == 200 || res.statusCode == 206) {
            results[url] = sw.elapsedMilliseconds;
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    if (results.isEmpty) return urls;

    final sorted = urls.toList()
      ..sort((a, b) {
        final tA = results[a] ?? 999999;
        final tB = results[b] ?? 999999;
        return tA.compareTo(tB);
      });
    return sorted;
  }

  /// 远程清单高可用探测地址
  static List<String> get manifestEndpoints => [
        'https://ghproxy.net/https://raw.githubusercontent.com/$appRepo/main/version_manifest.json',
        'https://cdn.jsdelivr.net/gh/$appRepo@main/version_manifest.json',
        'https://raw.githubusercontent.com/$appRepo/main/version_manifest.json',
      ];

  /// 检查是否有最新版本
  Future<AppVersionInfo?> checkLatestVersion({
    String? customEndpoint,
    bool forceMock = false,
  }) async {
    if (forceMock) {
      return defaultMockVersion;
    }

    final endpoints = customEndpoint != null
        ? [customEndpoint, ...manifestEndpoints]
        : manifestEndpoints;

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams['_t'] = DateTime.now().millisecondsSinceEpoch.toString();
        final requestUrl = uri.replace(queryParameters: queryParams).toString();

        final res = await _dio.get<dynamic>(
          requestUrl,
          options: Options(
            sendTimeout: const Duration(milliseconds: 3000),
            receiveTimeout: const Duration(milliseconds: 4000),
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            },
          ),
        );

        if (res.statusCode == 200 && res.data != null) {
          Map<String, dynamic>? jsonMap;
          if (res.data is Map<String, dynamic>) {
            jsonMap = res.data as Map<String, dynamic>;
          } else if (res.data is Map) {
            jsonMap = Map<String, dynamic>.from(res.data as Map);
          } else if (res.data is String) {
            final decoded = jsonDecode((res.data as String).trim());
            if (decoded is Map<String, dynamic>) {
              jsonMap = decoded;
            } else if (decoded is Map) {
              jsonMap = Map<String, dynamic>.from(decoded);
            }
          }

          if (jsonMap != null) {
            final info = AppVersionInfo.fromJson(jsonMap);
            if (info.versionCode > currentVersionCode) {
              return info;
            } else {
              return null; // 已经是最新版
            }
          }
        }
      } catch (e) {
        debugPrint('[VersionCheckService] 节点 $endpoint 探测未响应: $e');
      }
    }

    return null;
  }

  /// 跨平台执行下载与更新升级
  Future<void> executePlatformUpdate(
    AppVersionInfo info, {
    required void Function(double progress, [String? speedText]) onProgress,
    CancelToken? cancelToken,
  }) async {
    if (kIsWeb) {
      return;
    }

    // Windows 平台：流式下载 Setup.exe 并启动执行覆盖安装
    if (Platform.isWindows) {
      await _downloadAndExecuteWindowsInstaller(
        info,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return;
    }

    // macOS 平台：若有 DMG 镜像则流式下载，否则唤起下载链接
    if (Platform.isMacOS) {
      await _downloadAndOpenMacInstaller(
        info,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return;
    }

    // 默认兜底：打开外部链接
    onProgress(1.0, null);
  }

  Future<void> _downloadAndExecuteWindowsInstaller(
    AppVersionInfo info, {
    required void Function(double progress, [String? speedText]) onProgress,
    CancelToken? cancelToken,
  }) async {
    final running = activeDownload.value;
    if (running != null && running.info.versionCode == info.versionCode) {
      return;
    }

    final token = cancelToken ?? CancelToken();
    activeDownload.value = ActiveDownload(info: info, cancelToken: token);

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'mellow_music_setup_v${info.versionName}.exe';
      final saveFile = File('${tempDir.path}\\$fileName');

      final platformInfo = info.currentPlatformInfo;
      final rawCandidates = <String>{
        ...buildAcceleratedDownloadUrls(platformInfo?.backupUrl),
        ...buildAcceleratedDownloadUrls(platformInfo?.downloadUrl),
        ...buildAcceleratedDownloadUrls(info.downloadUrl),
      }.toList();

      final candidates = await raceCandidateUrls(rawCandidates);
      bool downloadSuccess = false;

      for (final url in candidates) {
        if (token.isCancelled) return;
        try {
          int lastReceived = 0;
          int lastTimestamp = DateTime.now().millisecondsSinceEpoch;
          double currentSpeedMB = 0.0;

          final response = await _dio.download(
            url,
            saveFile.path,
            cancelToken: token,
            options: Options(
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 20),
            ),
            onReceiveProgress: (received, total) {
              if (total > 0) {
                final now = DateTime.now().millisecondsSinceEpoch;
                final delta = now - lastTimestamp;
                if (delta >= 600) {
                  final bytesDelta = received - lastReceived;
                  currentSpeedMB = (bytesDelta / (delta / 1000.0)) / (1024 * 1024);
                  lastReceived = received;
                  lastTimestamp = now;
                }
                final progress = (received / total).clamp(0.0, 1.0);
                final speedStr = currentSpeedMB > 0.05
                    ? '${currentSpeedMB.toStringAsFixed(1)} MB/s'
                    : '';
                final speed = speedStr.isNotEmpty ? speedStr : null;
                activeDownload.value = activeDownload.value
                    ?.copyWith(progress: progress, speedText: speed);
                onProgress(progress, speed);
              }
            },
          );

          if (response.statusCode == 200 && await saveFile.exists()) {
            final reason = await _verifyFile(saveFile, platformInfo);
            if (reason != null) {
              debugPrint('[VersionCheckService] 文件校验未通过($reason)，尝试备选镜像');
              await saveFile.delete();
              continue;
            }
            downloadSuccess = true;
            break;
          }
        } catch (e) {
          if (token.isCancelled) return;
          debugPrint('[VersionCheckService] 节点 $url 下载失败: $e');
        }
      }

      if (!downloadSuccess) {
        throw Exception('所有下载节点均不可用，请检查网络或稍后重试');
      }

      onProgress(1.0, null);

      // 唤起 Windows 安装程序
      await Process.start(saveFile.path, [], runInShell: true);
    } finally {
      activeDownload.value = null;
    }
  }

  Future<void> _downloadAndOpenMacInstaller(
    AppVersionInfo info, {
    required void Function(double progress, [String? speedText]) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'mellow_music_v${info.versionName}.dmg';
    final saveFile = File('${tempDir.path}/$fileName');

    final platformInfo = info.currentPlatformInfo;
    final rawCandidates = <String>{
      ...buildAcceleratedDownloadUrls(platformInfo?.backupUrl),
      ...buildAcceleratedDownloadUrls(platformInfo?.downloadUrl),
      ...buildAcceleratedDownloadUrls(info.downloadUrl),
    }.toList();

    final candidates = await raceCandidateUrls(rawCandidates);
    bool downloadSuccess = false;

    for (final url in candidates) {
      if (cancelToken?.isCancelled == true) return;
      try {
        final response = await _dio.download(
          url,
          saveFile.path,
          cancelToken: cancelToken,
          options: Options(receiveTimeout: const Duration(seconds: 60)),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onProgress((received / total).clamp(0.0, 1.0));
            }
          },
        );
        if (response.statusCode == 200 && await saveFile.exists()) {
          downloadSuccess = true;
          break;
        }
      } catch (_) {}
    }

    if (downloadSuccess) {
      onProgress(1.0, null);
      await Process.run('open', [saveFile.path]);
    } else {
      throw Exception('macOS 安装包下载失败');
    }
  }

  Future<String?> _verifyFile(File file, PlatformUpdateInfo? info) async {
    if (!await file.exists()) return '文件不存在';
    final len = await file.length();
    if (len < 1024) return '文件过小($len B)';

    final expectedSize = info?.fileSize;
    if (expectedSize != null && expectedSize > 0 && len != expectedSize) {
      return '文件体积不符: 期望 $expectedSize, 实际 $len';
    }

    final expectedSha = info?.sha256?.trim().toLowerCase();
    if (expectedSha != null && expectedSha.isNotEmpty) {
      final bytes = await file.readAsBytes();
      final actualSha = sha256.convert(bytes).toString();
      if (actualSha != expectedSha) {
        return 'SHA256 不一致';
      }
    }
    return null;
  }

  /// 预置的 Mock 稳定新版本（供无网或离线单测验收）
  static const AppVersionInfo defaultMockVersion = AppVersionInfo(
    versionCode: 4,
    versionName: '1.2.0',
    publishDate: '2026-09-30',
    releaseNotes:
        '1. 【近场设备协同升级】：支持局域网免密极速直传与双端曲库无缝合流；\n2. 【全新在线更新体系】：对标专业级多镜像加速，支持全国 CDN 节点测速择优与 Windows/macOS 无损静默升级；\n3. 【Windows 播放稳定性加固】：彻底根治播放历史页切歌与音源切换闪退，高频交互稳如磐石；\n4. 【全景音质引擎】：优化六大音源解析与无损 FLAC 直链自适应播放。',
    isForceUpdate: false,
    platforms: {
      'windows': PlatformUpdateInfo(
        downloadUrl:
            'https://github.com/Kline-x/mellow-music-player/releases/download/v1.1.1/mellow-music-windows-setup.exe',
        backupUrl:
            'https://ghproxy.net/https://github.com/Kline-x/mellow-music-player/releases/download/v1.1.1/mellow-music-windows-setup.exe',
        fileSize: 42100000,
        installMode: 'in_app_download',
      ),
      'macos': PlatformUpdateInfo(
        downloadUrl:
            'https://github.com/Kline-x/mellow-music-player/releases/download/v1.1.1/mellow-music-macos.dmg',
        backupUrl:
            'https://ghproxy.net/https://github.com/Kline-x/mellow-music-player/releases/download/v1.1.1/mellow-music-macos.dmg',
        fileSize: 38200000,
        installMode: 'in_app_download',
      ),
    },
  );
}
