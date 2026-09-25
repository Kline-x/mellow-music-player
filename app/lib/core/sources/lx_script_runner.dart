import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'lx_source_model.dart';

/// 落雪脚本请求上下文参数
class LxRequestContext {
  final String source; // kw, kg, tx, wy, mg 等
  final String action; // musicUrl, lyric, pic
  final LxSongInfo song;
  final AudioQuality quality;

  const LxRequestContext({
    required this.source,
    required this.action,
    required this.song,
    required this.quality,
  });
}

/// 落雪脚本解析与运行时引擎 (LX Script Engine & Custom API Runner)
///
/// 遵循落雪音乐 (LX-Music) 自定义音源规范 (User Script Specification) 与
/// AlgerMusicPlayer (AlgerMusic) 自定义 API JSON 配置规范。
///
/// 支持两类音源：
/// 1. 标准落雪自定义 JavaScript 音源脚本（基于 globalThis.lx 通信协议规范）；
/// 2. AlgerMusicPlayer 风格的声明式 JSON API 配置文件（声明 apiUrl, params, responseUrlPath）。
class LxScriptRunner {
  final http.Client _client;

  LxScriptRunner({http.Client? client}) : _client = client ?? http.Client();

  /// 释放网络资源
  void dispose() {
    _client.close();
  }

  // ===========================================================================
  // 1. AlgerMusicPlayer 风格声明式 API 解析与执行 (Custom API JSON Provider)
  // ===========================================================================

  /// 判断文本是否为 AlgerMusicPlayer 风格的 JSON 配置
  static bool isAlgerJsonConfig(String content) {
    try {
      final trimmed = content.trim();
      if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return false;
      final map = jsonDecode(trimmed);
      return map is Map && map.containsKey('apiUrl') && map.containsKey('name');
    } catch (_) {
      return false;
    }
  }

  /// 执行 AlgerMusicPlayer 声明式 API 请求以获取音频直链
  Future<String?> resolveAlgerJsonUrl({
    required Map<String, dynamic> config,
    required String songId,
    required String songMid,
    required AudioQuality quality,
    String? source,
  }) async {
    final apiUrl = config['apiUrl']?.toString() ?? '';
    if (apiUrl.isEmpty) return null;

    final method = (config['method']?.toString() ?? 'GET').toUpperCase();
    final qualityMapping = config['qualityMapping'] as Map<String, dynamic>?;
    final mappedQuality = qualityMapping?[quality.value]?.toString() ?? quality.value;
    final responseUrlPath = config['responseUrlPath']?.toString() ?? 'url';

    // 参数模板替换: {songId}, {songMid}, {quality}, {source}
    final rawParams = config['params'] as Map<String, dynamic>? ?? {};
    final resolvedParams = <String, String>{};
    rawParams.forEach((key, val) {
      var sVal = val.toString();
      sVal = sVal.replaceAll('{songId}', songId);
      sVal = sVal.replaceAll('{songMid}', songMid.isNotEmpty ? songMid : songId);
      sVal = sVal.replaceAll('{quality}', mappedQuality);
      sVal = sVal.replaceAll('{source}', source ?? 'kw');
      resolvedParams[key] = sVal;
    });

    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
    if (config['headers'] is Map) {
      (config['headers'] as Map).forEach((k, v) => headers[k.toString()] = v.toString());
    }

    http.Response response;
    final timeoutDuration = Duration(milliseconds: (config['timeout'] as num?)?.toInt() ?? 8000);

    if (method == 'POST') {
      final isJsonBody = headers['Content-Type']?.contains('application/json') ?? true;
      response = await _client
          .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: isJsonBody ? jsonEncode(resolvedParams) : resolvedParams,
          )
          .timeout(timeoutDuration);
    } else {
      final uri = Uri.parse(apiUrl).replace(
        queryParameters: {
          ...Uri.parse(apiUrl).queryParameters,
          ...resolvedParams,
        },
      );
      response = await _client.get(uri, headers: headers).timeout(timeoutDuration);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = utf8.decode(response.bodyBytes);
      return extractUrlByPath(body, responseUrlPath);
    }
    return null;
  }

  /// 依据路径 (例如 "data.url" 或 "data[0].url") 从 JSON 中提取目标字段
  static String? extractUrlByPath(String jsonStr, String path) {
    try {
      dynamic current = jsonDecode(jsonStr);
      final segments = path.replaceAll('[', '.').replaceAll(']', '').split('.');
      for (final seg in segments) {
        if (seg.trim().isEmpty) continue;
        if (current is Map) {
          current = current[seg];
        } else if (current is List) {
          final idx = int.tryParse(seg);
          if (idx != null && idx >= 0 && idx < current.length) {
            current = current[idx];
          } else {
            return null;
          }
        } else {
          return null;
        }
      }
      if (current != null) {
        final res = current.toString().trim();
        if (res.startsWith('http://') || res.startsWith('https://')) {
          return res;
        }
      }
    } catch (_) {}
    return null;
  }

  // ===========================================================================
  // 2. 落雪音乐标准自定义 JS 音源解析 (LX User Script Parser)
  // ===========================================================================

  /// 从落雪自定义源脚本中提取其声明的 API 请求端点与参数模板
  ///
  /// 市面上绝大多数主流落雪源（包括六音、小秋、第三方聚合源）均采用 API 转发模式：
  /// 在 request 回调中向固定格式的 API Server 发起请求，如：
  /// - `http://domain.com/url/{source}/{songmid}/{quality}`
  /// - `https://api.xxx.com/api/music/url?source={source}&id={id}&type={quality}`
  /// - 或内部声明了 `API_URL` 常量
  static LxScriptEndpoint? extractScriptEndpoint(String scriptContent) {
    if (scriptContent.trim().isEmpty) return null;

    // 1. 尝试匹配显式声明的 baseUrl / API_URL / host / server 常量
    final urlRegexes = [
      RegExp(r'''(?:const|let|var)\s+(?:API_URL|baseUrl|HOST|SERVER_URL|API_HOST|url)\s*=\s*['"](https?://[^'"]+)['"]''', caseSensitive: false),
      RegExp(r'''['"](https?://[a-zA-Z0-9\.\-_:\/]+(?:/url|/api/|/link)[^'"]*)['"]''', caseSensitive: false),
      RegExp(r'''lx\.request\s*\(\s*[`'"](https?://[^`'"]+)[`'"]''', caseSensitive: false),
    ];

    String? foundUrl;
    for (final reg in urlRegexes) {
      final m = reg.firstMatch(scriptContent);
      if (m != null && m.groupCount >= 1) {
        foundUrl = m.group(1);
        break;
      }
    }

    if (foundUrl == null) {
      // 备选方案：查找任何公网 http 路径
      final generalHttp = RegExp(r'''['"](https?://[a-zA-Z0-9\.\-_:]+)(?:/|['"])''').firstMatch(scriptContent);
      if (generalHttp != null) {
        foundUrl = generalHttp.group(1);
      }
    }

    if (foundUrl == null) return null;

    // 2. 检查支持的音质声明
    final supportedQualities = <AudioQuality>[];
    if (scriptContent.contains('128k')) supportedQualities.add(AudioQuality.k128k);
    if (scriptContent.contains('320k')) supportedQualities.add(AudioQuality.k320k);
    if (scriptContent.contains('flac24bit')) {
      supportedQualities.add(AudioQuality.flac24bit);
    }
    if (scriptContent.contains('flac') && !supportedQualities.contains(AudioQuality.flac)) {
      supportedQualities.add(AudioQuality.flac);
    }
    if (supportedQualities.isEmpty) {
      supportedQualities.addAll(AudioQuality.values);
    }

    // 3. 检查支持的音源平台声明
    final supportedSources = <String>[];
    for (final s in ['kw', 'wy', 'tx', 'kg', 'mg']) {
      if (scriptContent.contains("'$s'") || scriptContent.contains('"$s"')) {
        supportedSources.add(s);
      }
    }
    if (supportedSources.isEmpty) {
      supportedSources.addAll(['kw', 'wy', 'tx']);
    }

    // 4. 提取自定义请求头 (例如 X-Request-Key 等)
    final customHeaders = <String, String>{};
    final headerMatch = RegExp(r'''['"](X-[a-zA-Z\-]+)['"]\s*:\s*['"]([^'"]+)['"]''').firstMatch(scriptContent);
    if (headerMatch != null) {
      customHeaders[headerMatch.group(1)!] = headerMatch.group(2)!;
    }

    return LxScriptEndpoint(
      baseUrl: foundUrl,
      supportedSources: supportedSources,
      supportedQualities: supportedQualities,
      customHeaders: customHeaders,
    );
  }

  /// 执行落雪音源真实取流解析
  Future<String?> resolveLxScriptUrl({
    required LxScriptEndpoint endpoint,
    required String source,
    required String songId,
    required String songMid,
    required AudioQuality quality,
    String? title,
    String? artist,
  }) async {
    final cleanMid = songMid.isNotEmpty ? songMid : songId;
    final qualitiesToTry = [quality, ...quality.fallbackChain];

    final headers = <String, String>{
      'User-Agent': 'lx-music-request/2.5.0',
      'Accept': 'application/json, text/plain, */*',
      ...endpoint.customHeaders,
    };

    final base = endpoint.baseUrl.replaceAll(RegExp(r'/$'), '');

    for (final q in qualitiesToTry) {
      final qualityStr = q.value;
      // 构造请求候选 URL 格式列表 (涵盖落雪常见 API 路由规范)
      final candidates = <String>[];

      if (base.contains('{source}') || base.contains('{songmid}')) {
        var custom = base;
        custom = custom.replaceAll('{source}', source);
        custom = custom.replaceAll('{songmid}', cleanMid);
        custom = custom.replaceAll('{id}', cleanMid);
        custom = custom.replaceAll('{quality}', qualityStr);
        candidates.add(custom);
      } else {
        // 常见 API Server 路由:
        // 1. /url/{source}/{songmid}/{quality}
        candidates.add('$base/url/$source/$cleanMid/$qualityStr');
        // 2. /api/music/url?source={source}&id={id}&type={quality}
        candidates.add('$base/api/music/url?source=$source&id=$cleanMid&type=$qualityStr');
        // 3. /music/url?source={source}&mid={mid}&quality={quality}
        candidates.add('$base/music/url?source=$source&mid=$cleanMid&quality=$qualityStr');
        // 4. 若原 baseUrl 已包含完整路径则直接添加
        if (base.contains('/url')) {
          candidates.insert(0, '$base/$source/$cleanMid/$qualityStr');
        }
      }

      for (final url in candidates) {
        try {
          final resp = await _client
              .get(Uri.parse(url), headers: headers)
              .timeout(const Duration(seconds: 6));

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            final body = utf8.decode(resp.bodyBytes);
            // 尝试以 JSON 解析
            if (body.trim().startsWith('{')) {
              // 常见路径：data.url, url, data, result
              final extracted = extractUrlByPath(body, 'data.url') ??
                  extractUrlByPath(body, 'url') ??
                  extractUrlByPath(body, 'data') ??
                  extractUrlByPath(body, 'result');
              if (extracted != null && extracted.isNotEmpty) {
                return extracted;
              }
            } else if (body.trim().startsWith('http://') || body.trim().startsWith('https://')) {
              return body.trim();
            }
          }
        } catch (e) {
          debugPrint('[LxScriptRunner] 尝试请求落雪端点 [$url] 异常: $e');
        }
      }
    }

    return null;
  }
}

/// 解析提取出的落雪端点信息
class LxScriptEndpoint {
  final String baseUrl;
  final List<String> supportedSources;
  final List<AudioQuality> supportedQualities;
  final Map<String, String> customHeaders;

  const LxScriptEndpoint({
    required this.baseUrl,
    required this.supportedSources,
    required this.supportedQualities,
    this.customHeaders = const {},
  });
}
