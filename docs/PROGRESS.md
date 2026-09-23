> # ✅ 全平台核心能力闭环与五大进阶工程专项全面验收（2026-09-23）
>
> 严格对标生产交付标准，完成五大核心能力纵深闭环，消灭全部假实现并实现系统级贯通：
> - **1. 局域网 P2P 近场即时传输交互 (LAN Sync)**：UDP 组播自动探活广播 + HTTP P2P 双向直连传输，桌面端与移动端真实设备发现与歌单即时发送已全量贯通；
> - **2. LX-Music 自定义音源沙箱与降级调度 (Source Sandbox)**：支持本地外部 JS 脚本导入、远程 URL 订阅、静态安全沙箱防注入检测、阶梯式音质自动降级回退（128k/320k/flac/flac24bit）与持久化管理；
> - **3. 桌面独立置顶透明穿透歌词窗口 (Desktop Floating Lyric)**：Windows Win32 原生通道深度贯通（`SetWindowPos` HWND_TOPMOST、`WS_EX_TRANSPARENT | WS_EX_LAYERED` 鼠标穿透、系统托盘右键菜单联动、坐标与字号持久化）；
> - **4. 移动端 (Android / iOS) 真实打包发布流水线与适配**：补齐 AndroidManifest 局域网组播、通知与后台音频播放权限，完善 iOS Info.plist 后台音频模式与 ATS 本地网络安全配置，交付全自动化打包流水线脚本 `build_mobile.ps1` 与平台合规自动化测试；
> - **5. 真实物理构建与自动化测试全绿保证**：全仓 146 项单元与部件测试 100% 通过，Windows 独立物理进程保活验证脚本 `verify_windows_app.ps1` 稳定通过。
>
> ---

# Mellow Music · 润音 · 项目研发里程碑与进度跟踪看板

> **当前版本**：v1.2.0 (Full-Stack 5 Pillars Implemented & Verified)  
> **更新时间**：2026-09-23  
> **当前状态**：五大核心能力专项全部真实交付闭环，全仓 146 项自动化测试 100% 全部通过，Windows 物理程序真实验证通过，移动端打包流水线就绪。

---

## 📊 里程碑整体进度看板 (Milestone Dashboard)

| 里程碑 | 目标与交付物 | 计划周期 | 状态 | 交付物/参考文档 |
| :--- | :--- | :--- | :---: | :--- |
| **Phase 0** | **Modern Soft UI 双端高保真原型与 E2E 验收** | 已完成 | 🟢 **100%** | `index.html`、`mobile.html`、`e2e_test.js` (Web 原型验收 83 项全绿) |
| **Phase 0.5** | **技术规格书与 E2E 缺陷验收整改清单** | 已完成 | 🟢 **100%** | `docs/SPEC.md`、`docs/PC_E2E_ACCEPTANCE_ISSUES.md` |
| **Phase 1** | **物理音频引擎与真实本地持久化闭环** | 已完成 | 🟢 **100%** | `audioplayers: ^6.8.1` 物理声卡发声、`StorageService` 状态无损持久化 |
| **Phase 2** | **双端完整业务视图与无死区交互体验** | 已完成 | 🟢 **100%** | 33 首全量内置立体声音频、四大巅峰榜单、歌手档案主页、电台、800px 窄视口自适应 |
| **Pillar 1** | **局域网 P2P 近场即时传输交互 (LAN Sync)** | 已完成 | 🟢 **100%** | UDP 组播发现、HTTP P2P 歌单/曲目传输、双端即时同步 UI 接入（Commit: `b8d395d`） |
| **Pillar 2** | **LX-Music 自定义音源脚本沙箱与管理调度** | 已完成 | 🟢 **100%** | `LxSourceEngine` 安全沙箱、本地/URL 导入、音质自动阶梯降级调度（Commit: `10e44e4`） |
| **Pillar 3** | **桌面独立置顶透明穿透歌词窗口系统级贯通** | 已完成 | 🟢 **100%** | Win32 HWND_TOPMOST 置顶、WS_EX_TRANSPARENT 穿透、托盘与快捷键联动（Commit: `3b5ad9d`） |
| **Pillar 4** | **移动端 (Android / iOS) 真实打包发布流水线** | 已完成 | 🟢 **100%** | 平台权限合规、后台音频模式、`build_mobile.ps1` 自动化构建、Manifest 校验测试（Commit: `0f8e9d4`） |
| **Pillar 5** | **全仓文档口径诚实化对齐与质量审计门禁** | 已完成 | 🟢 **100%** | 对齐 `README.md`、`docs/PROGRESS.md`、`docs/SPEC.md`，146 项测试全绿 |

---

## 📝 详细能力闭环交付记录 (Implementation Details)

### 1. 局域网 P2P 近场即时传输交互 (LAN Sync)
- **核心逻辑**：基于原生 `dart:io` 的 UDP Socket 组播发现（端口 23333）+ HTTP 服务端（端口 23332），支持节点探活、双向配对握手与歌单/文件即时传输；
- **UI 交互**：桌面端 `DesktopSyncView` 与移动端同步面板完全剔除旧有虚假 Toast，点击「发送歌单」和「立即同步」直接驱动底层网络 Socket 发送真实同步报文；
- **防伪保证**：零假设备，仅当局域网真实监听到对端广播或完成握手时方展示设备卡片。

### 2. LX-Music 自定义音源脚本沙箱与音质降级调度
- **安全沙箱**：`LxSourceEngine.instance` 具备静态 AST/正则防注入安全校验，拦截 `eval`、`Function`、`require`、`process`、`window`、`document` 等危险调用；
- **音质阶梯降级**：实现 `resolveMusicUrlWithFallback`，从用户首选音质（flac24bit / flac / 320k / 128k）逐级自动降级重试，确保播放可用率最大化；
- **UI 运维**：在桌面端设置与音源管理视图中提供「首选音质」快捷切换、外部脚本安装卡片、查看源码模态框与一键卸载功能。

### 3. 桌面独立置顶透明穿透歌词窗口 (Desktop Floating Lyric)
- **原生贯通**：在 `flutter_window.cpp` 原生注入 Win32 API：
  - `SetWindowPos(hwnd, HWND_TOPMOST, ...)` 实现真正的窗口系统级置顶；
  - `SetWindowLong(hwnd, GWL_EXSTYLE, WS_EX_TRANSPARENT | WS_EX_LAYERED)` 实现鼠标点击完全穿透至底层桌面/游戏；
  - 原生系统托盘增加「桌面歌词 开/关 (Ctrl+D)」和「窗口始终置顶」快捷菜单项；
- **前端联动**：`DesktopFloatingLyricService` 与 `DesktopFloatingLyricBar` 响应拖拽位移并落盘记忆坐标，支持 3 档字号平滑切换。

### 4. 移动端 (Android / iOS) 真实打包发布流水线与平台适配
- **Android 平台**：
  - 补充 `ACCESS_WIFI_STATE` 与 `CHANGE_WIFI_MULTICAST_STATE`（局域网 UDP 发现）；
  - 补充 `POST_NOTIFICATIONS`、`FOREGROUND_SERVICE` 与 `FOREGROUND_SERVICE_MEDIA_PLAYBACK`；
  - 开启 `usesCleartextTraffic="true"` 支持局域网明文传输；
- **iOS 平台**：
  - 补充 `UIBackgroundModes`（`audio`, `fetch`）实现后台音频常驻；
  - 补充 `NSAppTransportSecurity` 允许本地网络和任意音频流；
  - 补充 `NSLocalNetworkUsageDescription` 与 Bonjour 服务定义；
- **打包流水线**：交付 `build_mobile.ps1`，支持 `-Target apk`、`-Target bundle` 与 `-Target check-only`，并由 `test/mobile_platform_manifest_test.dart` 自动化测试进行防退化守护。

---

## 🎯 产出物运行与验证指引

```powershell
# 1. 运行全量单元与部件测试套件 (146/146 Passed 100%)
cd app
C:\Users\gaore\.puro\envs\stable\flutter\bin\flutter.bat test

# 2. 运行 Windows 原生应用物理进程保活验证
powershell -ExecutionPolicy Bypass -File .\verify_windows_app.ps1

# 3. 运行移动端平台配置合规检查与打包流水线
powershell -ExecutionPolicy Bypass -File .\build_mobile.ps1 -Target check-only
```
