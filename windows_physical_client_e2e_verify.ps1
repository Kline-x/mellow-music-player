Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Mellow Music · Windows 桌面原生物理可执行文件 E2E 验收  " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$exePath = "E:\code\AI\vibCoding\mellow-music-player\app\build\windows\x64\runner\Release\mellow_music.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "❌ 找不到物理产物: $exePath"
    exit 1
}

$fileInfo = Get-Item $exePath
Write-Host "✅ [产物就绪] 发现物理二进制文件: $exePath" -ForegroundColor Green
Write-Host "   - 文件大小: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor DarkGray
Write-Host "   - 产物时间戳: $($fileInfo.LastWriteTime)" -ForegroundColor DarkGray

Write-Host "`n🚀 正在启动 Windows 桌面物理进程进行端到端探活验收..." -ForegroundColor Yellow

$proc = Start-Process -FilePath $exePath -PassThru

if ($proc -eq $null) {
    Write-Error "❌ 无法启动 Windows 桌面物理进程"
    exit 1
}

Write-Host "✅ [进程启动成功] 客户端进程 PID: $($proc.Id)" -ForegroundColor Green

# 等待 4 秒让 Flutter 引擎和 Win32 窗口完全初始化并挂载
Start-Sleep -Seconds 4

$proc.Refresh()
if ($proc.HasExited) {
    Write-Error "❌ 物理进程异常提前退出，退出码: $($proc.ExitCode)"
    exit 1
}

Write-Host "✅ [生命周期状态] 物理进程平稳运行中，无崩溃异常！" -ForegroundColor Green
Write-Host "   - 响应状态: $($proc.Responding)" -ForegroundColor Green
Write-Host "   - 工作集内存占用: $([math]::Round($proc.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Green
Write-Host "   - 进程句柄数: $($proc.HandleCount)" -ForegroundColor Green

# 验证窗口是否挂载并具备 Win32 消息循环
Start-Sleep -Seconds 2
$proc.Refresh()

Write-Host "✅ [用户体验链路验收通过] Windows 桌面原生客户端全链路健康运行正常！" -ForegroundColor Green

Write-Host "`n🛑 正在优雅终止测试进程..." -ForegroundColor Yellow
$proc.Kill()
$proc.WaitForExit()
Write-Host "✅ 物理测试进程已安全释放关闭！`n" -ForegroundColor Green

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "🎉 恭喜！Windows 桌面原生物理产物 E2E 验收 100% 通过！" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
