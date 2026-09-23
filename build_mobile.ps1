param (
    [string]$Mode = "debug",
    [string]$Target = "apk"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$appDir = Join-Path $root "app"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Mellow Music Mobile Build & Verification Pipeline" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Flutter SDK Detection
$flutterBin = "C:\Users\gaore\.puro\envs\stable\flutter\bin\flutter.bat"
if (-not (Test-Path $flutterBin)) {
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        $flutterBin = $flutterCmd.Source
    } else {
        Write-Error "Flutter SDK not found!"
    }
}
Write-Host "[1/4] Flutter SDK: $flutterBin" -ForegroundColor Green

# 2. Android Manifest Validation
Write-Host "[2/4] Validating Android platform configuration..." -ForegroundColor Yellow
$manifestPath = Join-Path $appDir "android\app\src\main\AndroidManifest.xml"
if (-not (Test-Path $manifestPath)) {
    Write-Error "AndroidManifest.xml not found at: $manifestPath"
}
$manifestContent = Get-Content -Raw $manifestPath
$requiredAndroidPermissions = @(
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.WAKE_LOCK",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.CHANGE_WIFI_MULTICAST_STATE",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.MODIFY_AUDIO_SETTINGS"
)
foreach ($perm in $requiredAndroidPermissions) {
    if ($manifestContent.IndexOf($perm) -lt 0) {
        Write-Error "AndroidManifest.xml missing permission: $perm"
    }
}
if ($manifestContent.IndexOf('android:usesCleartextTraffic="true"') -lt 0) {
    Write-Error "AndroidManifest.xml missing android:usesCleartextTraffic=true"
}
Write-Host "  [OK] AndroidManifest.xml passed (Background Audio, Multicast, Notifications, Cleartext Traffic)" -ForegroundColor Green

# 3. iOS Info.plist Validation
Write-Host "[3/4] Validating iOS platform configuration..." -ForegroundColor Yellow
$plistPath = Join-Path $appDir "ios\Runner\Info.plist"
if (-not (Test-Path $plistPath)) {
    Write-Error "iOS Info.plist not found at: $plistPath"
}
$plistContent = Get-Content -Raw $plistPath
if ($plistContent.IndexOf("<string>audio</string>") -lt 0) {
    Write-Error "iOS Info.plist missing UIBackgroundModes: audio"
}
if ($plistContent.IndexOf("NSLocalNetworkUsageDescription") -lt 0) {
    Write-Error "iOS Info.plist missing NSLocalNetworkUsageDescription"
}
if ($plistContent.IndexOf("NSAppTransportSecurity") -lt 0) {
    Write-Error "iOS Info.plist missing NSAppTransportSecurity"
}
if ($plistContent.IndexOf("<string>Mellow Music</string>") -lt 0) {
    Write-Error "iOS Info.plist missing CFBundleDisplayName: Mellow Music"
}
Write-Host "  [OK] iOS Info.plist passed (Background Audio, Local Network, ATS)" -ForegroundColor Green

# 4. Build or Check-only
if ($Target -eq "check-only") {
    Write-Host "[4/4] Validation completed successfully (check-only mode)." -ForegroundColor Cyan
    exit 0
}

Write-Host "[4/4] Starting Android build ($Target, $Mode)..." -ForegroundColor Yellow

Push-Location $appDir
try {
    if ($Target -eq "apk") {
        if ($Mode -eq "release") {
            & $flutterBin build apk --release
        } else {
            & $flutterBin build apk --debug
        }
        
        $outputApkDir = Join-Path $appDir "build\app\outputs\flutter-apk"
        $apkFile = Get-ChildItem -Path $outputApkDir -Filter "*.apk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($apkFile) {
            $fileSizeMB = [math]::Round($apkFile.Length / 1MB, 2)
            $hash = (Get-FileHash -Path $apkFile.FullName -Algorithm SHA256).Hash
            Write-Host "==========================================================" -ForegroundColor Green
            Write-Host "  Android APK Build SUCCESS!" -ForegroundColor Green
            Write-Host "  Artifact: $($apkFile.FullName)" -ForegroundColor Cyan
            Write-Host "  Size: $fileSizeMB MB" -ForegroundColor Cyan
            Write-Host "  SHA256: $hash" -ForegroundColor DarkGray
            Write-Host "==========================================================" -ForegroundColor Green
        } else {
            Write-Error "No output APK found!"
        }
    } elseif ($Target -eq "bundle") {
        if ($Mode -eq "release") {
            & $flutterBin build appbundle --release
        } else {
            & $flutterBin build appbundle --debug
        }
        Write-Host "  Android AppBundle Build SUCCESS!" -ForegroundColor Green
    } else {
        Write-Error "Unknown build target: $Target"
    }
} finally {
    Pop-Location
}
