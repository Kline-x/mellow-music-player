import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens.dart';
import '../../design_system/theme_provider.dart';
import '../../design_system/soft_button.dart';
import '../../core/services/version_check_service.dart';

/// Modern Soft UI 极具科技感与温度的跨端新版本更新弹窗
class UpdateDialog extends StatefulWidget {
  final AppVersionInfo info;

  const UpdateDialog({
    super.key,
    required this.info,
  });

  /// 便捷呼出更新弹窗
  static Future<void> show(BuildContext context, AppVersionInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final VersionCheckService _versionService = VersionCheckService();

  CancelToken? _cancelToken;
  bool _isProcessing = false;
  bool _isFinished = false;
  double _progress = 0.0;
  String _statusText = '准备就绪';
  bool _hasError = false;
  bool _movedToBackground = false;

  @override
  void initState() {
    super.initState();
    final running = _versionService.activeDownload.value;
    if (running != null && running.info.versionCode == widget.info.versionCode) {
      _movedToBackground = true;
      _cancelToken = running.cancelToken;
      _isProcessing = true;
      _progress = running.progress;
      _statusText = _formatProgressText(running.progress, running.speedText);
      _versionService.activeDownload.addListener(_onBackgroundProgress);
    }
  }

  String _formatProgressText(double progress, String? speedText) {
    final pct = (progress * 100).toStringAsFixed(1);
    final speed = (speedText != null && speedText.isNotEmpty) ? ' · $speedText' : '';
    return '正在高速下载升级包... $pct%$speed';
  }

  void _onBackgroundProgress() {
    if (!mounted) return;
    final running = _versionService.activeDownload.value;
    setState(() {
      if (running == null) {
        _progress = 1.0;
        _isFinished = true;
        _statusText = '下载完成，已唤起安装程序';
      } else {
        _progress = running.progress;
        _statusText = _formatProgressText(running.progress, running.speedText);
      }
    });
  }

  @override
  void dispose() {
    _versionService.activeDownload.removeListener(_onBackgroundProgress);
    if (_isProcessing && !_movedToBackground) {
      _cancelToken?.cancel('用户关闭弹窗');
    }
    super.dispose();
  }

  void _moveToBackground() {
    _movedToBackground = true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('已转入后台下载，完成后会自动唤起安装'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startUpdate() async {
    _cancelToken = CancelToken();
    setState(() {
      _isProcessing = true;
      _hasError = false;
      _isFinished = false;
      _progress = 0.0;
      _statusText = '正在建立多节点高速连接...';
    });

    try {
      await _versionService.executePlatformUpdate(
        widget.info,
        cancelToken: _cancelToken,
        onProgress: (progress, [speedText]) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            if (progress >= 1.0) {
              _statusText = '下载完成，已唤起系统安装器';
              _isFinished = true;
            } else {
              _statusText = _formatProgressText(progress, speedText);
            }
          });
        },
      );

      if (mounted && _progress >= 1.0) {
        setState(() {
          _isFinished = true;
          _statusText = '安装器已启动，请按指引完成升级';
        });
      }
    } catch (e) {
      if (_cancelToken?.isCancelled == true) return;
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusText = '下载遇到问题，请检查网络后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return PopScope(
      canPop: !widget.info.isForceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: MellowColors.card(isDark),
            borderRadius: MellowRadii.borderR24,
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏与版本徽章
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: MellowRadii.borderR12,
                    ),
                    child: Icon(Icons.rocket_launch_rounded, color: theme.accentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '发现全新版本',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: MellowColors.textPrimary(isDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'v${widget.info.versionName}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '发布时间: ${widget.info.publishDate}',
                          style: TextStyle(
                            fontSize: 12,
                            color: MellowColors.textMuted(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 更新日志列表容器
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MellowColors.recessed(isDark),
                  borderRadius: MellowRadii.borderR16,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.releaseNotes.isNotEmpty
                        ? widget.info.releaseNotes
                        : '常规稳定性与性能优化提升',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: MellowColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 下载进度与状态条
              if (_isProcessing || _isFinished || _hasError) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasError ? Colors.redAccent : theme.accentColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isProcessing && !_isFinished && !_hasError)
                          Text(
                            '${(_progress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.accentColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _isProcessing && _progress > 0 ? _progress : (_isFinished ? 1.0 : null),
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _hasError ? Colors.redAccent : theme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // 底部操作按钮流
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isProcessing && !_isFinished && !_hasError)
                    SoftButton(
                      label: '后台下载',
                      icon: Icons.downloading_rounded,
                      isPill: true,
                      onTap: _moveToBackground,
                    )
                  else if (!widget.info.isForceUpdate)
                    SoftButton(
                      label: _isFinished ? '完成' : '稍后提醒',
                      isPill: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  const SizedBox(width: 12),
                  if (!_isFinished)
                    SoftButton(
                      label: _hasError ? '重试更新' : (_isProcessing ? '高速下载中...' : '立即更新'),
                      icon: _hasError ? Icons.refresh_rounded : Icons.cloud_download_rounded,
                      isPill: true,
                      onTap: _isProcessing && !_hasError ? null : _startUpdate,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
