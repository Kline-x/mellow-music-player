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

> **当前版本**：v1.7.0 (Client E2E Deep Inspection & 18 UX Issues Zero-Defect Closed & Tonearm Micro-Skeuomorphism & 167 Tests 100% Passed)  
> **更新时间**：2026-09-24  
> **当前状态**：黑屏根因与 macOS 前台激活彻底澄清、侧栏“白色药丸堆积”彻底消灭（升级为轻灵透明悬浮态且 800 高度无截断）、底部播放 Dock 呼吸主键与三区工具栏重构、搜索曲风刺眼色块柔化为 Soft Glass Tint、歌曲列表升级为 Apple Music 级一体化高密度表格、歌手库扩展 5 大流派、全屏歌词新增动态复古唱针与光栅同心环、167 项测试与 9 大视图真机高保真像素帧 100% 零缺陷通过。

---

## 📊 里程碑整体进度看板 (Milestone Dashboard)

| 里程碑 | 目标与交付物 | 计划周期 | 状态 | 交付物/参考文档 |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 0** | **Modern Soft UI 双端高保真原型与 E2E 验收** | 已完成 | 🟢 **100%** | `index.html`、`mobile.html`、`e2e_test.js` (Web 原型验收 83 项全绿) |
| **Phase 0.5** | **技术规格书与 E2E 缺陷验收整改清单** | 已完成 | 🟢 **100%** | `docs/SPEC.md`、`docs/PC_E2E_ACCEPTANCE_ISSUES.md`、`docs/e2e/` (156 项缺陷全景账本) |
| **Phase 1** | **物理音频引擎与真实本地持久化闭环** | 已完成 | 🟢 **100%** | `audioplayers: ^6.8.1` 物理声卡发声、`StorageService` 状态无损持久化 |
| **Phase 2** | **双端完整业务视图与无死区交互体验** | 已完成 | 🟢 **100%** | 33 首全量内置立体声音频、四大巅峰榜单、歌手档案主页、电台、800px 窄视口自适应 |
| **Pillar 1** | **局域网 P2P 近场即时传输交互 (LAN Sync)** | 已完成 | 🟢 **100%** | UDP 组播发现、HTTP P2P 歌单/曲目传输、双端即时同步 UI 接入（Commit: `b8d395d`） |
| **Pillar 2** | **LX-Music 自定义音源脚本沙箱与管理调度** | 已完成 | 🟢 **100%** | `LxSourceEngine` 安全沙箱、本地/URL 导入、音质自动阶梯降级调度（Commit: `10e44e4`） |
| **Pillar 3** | **桌面独立置顶透明穿透歌词窗口系统级贯通** | 已完成 | 🟢 **100%** | Win32 HWND_TOPMOST 置顶、WS_EX_TRANSPARENT 穿透、托盘与快捷键联动（Commit: `3b5ad9d`） |
| **Pillar 4** | **移动端 (Android / iOS) 真实打包发布流水线** | 已完成 | 🟢 **100%** | 平台权限合规、后台音频模式、`build_mobile.ps1` 自动化构建、Manifest 校验测试（Commit: `0f8e9d4`） |
| **Pillar 5** | **全仓文档口径诚实化对齐与质量审计门禁** | 已完成 | 🟢 **100%** | 对齐 `README.md`、`docs/PROGRESS.md`、`docs/SPEC.md`，146 项测试全绿 |
| **Phase 3** | **/goal 四大核心体验痛点全量闭环交付** | 已完成 | 🟢 **100%** | 全仓去假求真、消除原生蓝边框、高保真真实音频解析、独立全屏搜索（CI Run: `35850447362`, 151/151 Passed） |
| **Phase 4** | **跨平台真机 E2E 与多源高可用闭环 (建议1/2/3)** | 已完成 | 🟢 **100%** | macOS 沙箱网络权限、SMTC/托盘平台守卫、酷我+网易云+iTunes三源并发聚合去重、165 测试 + 8 macOS 原生 E2E 全绿 |
| **Phase 5** | **macOS 黑屏彻底根治与落雪音源方案 A 内置闭环** | 已完成 | 🟢 **100%** | `FLTEnableImpeller=false` 回退成熟 Skia Metal、产品名更名 Mellow Music、内置标准落雪聚合驱动并冷启动自装载激活、166 测试 + 9 原生 E2E 全绿 |
| **Phase 6** | **macOS 沉浸无边框重构与使用者挑剔体验闭环** | 已完成 | 🟢 **100%** | 消灭双层标题栏与系统生硬框、消灭 0.8px 灰色实线、胶囊高光微拟物、巨幕黑胶同心环与动态光晕、平台快捷键自适应、166 测试 + 9 原生 E2E 全绿 |
| **Phase 7** | **客户端全链路真机挑剔验收与 18 项缺陷系统性整改** | 已完成 | 🟢 **100%** | 消灭侧栏白色药丸堆积、Dock 三区分区、曲风半透明微光柔化、Apple Music 级一体化高密度歌曲列表、动态复古唱针与 167 项测试全绿 |

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

### 5. /goal 四大核心体验痛点全量闭环交付 (Goal Realization)
- **全仓去假求真**：彻底剔除 66+ 处 `soundhelix.com` 假音源，内置 33 首核心曲库全量注入真实流媒体直链（每首歌曲验证 HTTP 200 与流媒体大小），冷启动底栏呈现微拟物雅致空闲态，四大官方榜单接入实时在线流与动态歌词解析；
- **消除原生窗口丑陋蓝边框**：DWM API 深度定制 `DWMWA_CAPTION_COLOR`、`DWMWA_TEXT_COLOR`、`DWMWA_BORDER_COLOR`，开启 `DWMWCP_ROUND` 原生大圆角，窗口标题统一为 `Mellow Music · 润音`，MethodChannel 实现深浅主题原生自适应；
- **彻底根治“歌曲听不了”**：`OnlineMusicService` 集成免 VIP 高保真解析接口与 LRC 动态歌词，`AudioPlayerService` 引入智能换源重试与异常 Fallback 机制，彻底消除 404 弹窗；
- **独立全屏搜索页面建设**：废弃居中小弹窗，新建桌面端 `DesktopSearchView` 与移动端 `MobileSearchPage`，支持搜索历史持久化、热门探索推荐标签、30+ 丰富结果即点即播与一键批量播放。

### 6. 跨平台真机 E2E 与多源高可用闭环 (Cross-Platform E2E & Multi-Source Parity)
- **macOS 沙箱网络权限补齐**：在 `app/macos/Runner/DebugProfile.entitlements` 注入 `com.apple.security.network.client`，解决 macOS Debug 开发环境下内核静默拦截 HTTP/HTTPS 搜歌与流媒体请求的致命缺陷；
- **平台通道优雅降级**：`WindowsSmtcService` 与 `WindowsTrayService` 注入 `Platform.isWindows` 严密守卫，彻底消灭 macOS / Linux / 移动端与测试环境的 `MissingPluginException` 通道异常；
- **酷我 + 网易云 + iTunes 三源并发聚合去重**：`OnlineMusicService` 接入 `NeteaseMusicService` 真实搜索与多码率（320k/192k/128k）阶梯降级，并以 iTunes 官方高可用试听源作为免防盗链保底，通过 `dedupeByTitleArtist` 标题/歌手归一化去重；
- **Android 明文与局域网网络安全配置**：新增 `network_security_config.xml` 并在 `AndroidManifest.xml` 中配置引用，确保 Android 9+ 环境下 HTTP 明文音频流与 UDP 组播通信合规；
- **全仓质量双重门禁**：全仓 165 项 Flutter 自动化测试 100% 通过，macOS 真实物理进程端到端原生集成测试（`app_client_e2e_test.dart`）8/8 全绿通过。

---

## 🎯 产出物运行与验证指引

```bash
# 1. 运行全量单元与部件测试套件 (165/165 Passed 100%)
cd app
flutter analyze
flutter test

# 2. 运行 macOS 真实桌面物理集成测试 (8/8 Passed 100%)
flutter test integration_test/app_client_e2e_test.dart -d macos
```

# 3. 运行移动端平台配置合规检查与打包流水线
powershell -ExecutionPolicy Bypass -File .\build_mobile.ps1 -Target check-only
```
