# Mellow Music · 润音 — 文档声称 vs 代码实现 差距审计报告

> **审计对象仓库**：`E:\code\AI\vibCoding\mellow-music-player`
> **被审文档**：`README.md`、`docs/SPEC.md`(v1.1.0)、`docs/ROADMAP.md`、`docs/PROGRESS.md`
> **核对代码**：`app/pubspec.yaml`、`app/lib/**`(26 个 dart 文件, 约 9.6k 行)、`app/test/**`(8 文件)、`app/integration_test/**`(1 文件)、`.github/workflows/{ci,release}.yml`、`app/windows/`、`app/harmonyos/`、`app/linux/`、根目录 `index.html` / `mobile.html` / `server.js` / `e2e_test.js` / `flutter_e2e_verify.mjs`
> **审计方法**：逐条抽取文档声称 → 在代码中检索依赖声明/类名/方法/平台配置 → 判定结论。所有"代码证据"均给出 `文件:行号`。
> **环境限制**：本机未安装 `flutter`/`dart` CLI（`Get-Command flutter,dart` 无输出），因此 `flutter analyze` / `flutter test` **未能实机复现**，测试数量由源码静态计数得出（`^\s*test(` / `^\s*testWidgets(`）。其余结论均基于可复核的静态证据。

---

## 0. 一句话结论

客户端 `app/` 是一个**能编译、能跑、能看**的 Flutter 交互原型：14 个桌面视图 + 4 个移动 Tab 全部由**内存 Mock 数据**驱动，**无音频解码器、无数据库、无路由、无键盘快捷键、无系统媒体集成、无多窗口歌词**；`media_kit`/`audio_service`/`flutter_js`/`drift`/`desktop_multi_window` 等 SPEC 依赖**一个都没有进入 `pubspec.yaml`**。音源引擎与 WebDAV/LAN 同步虽然写了较完整的 Dart 逻辑，但**从未被 UI 引用（死代码）**。文档中"Phase 1~6 全部 100% 完成""47/47 测试通过""零遗漏对齐"等表述与实际严重不符。

---

## 1. 主表（逐条差距清单）

### 1.1 播放底座（声称 media_kit + audio_service 双流 / SMTC / 无损解码）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 1.1 | SPEC.md:47 / SPEC.md:382 / ROADMAP.md:28 | 音频底座 `media_kit`（libmpv，FLAC/APE/DSD/Hi-Res 解码） | `app/pubspec.yaml:30-46` 仅有 cupertino_icons / google_fonts / provider / go_router / intl / shared_preferences / http / dio / crypto / path_provider / path；`app/pubspec.lock` 全文无 `media_kit`；`app/lib` 内 `media_kit` 仅出现在注释与文案（`equalizer_manager.dart:81`、`modals.dart:207`） | **未实现** | 无解码器 → 无任何真实发声；"FLAC/APE/DSD/Hi-Res" 仅剩枚举字符串（`lx_source_model.dart:4` AudioQuality） |
| 1.2 | SPEC.md:48 / SPEC.md:176-180 / ROADMAP.md:29 | `audio_service` 系统通道（Windows SMTC / Android MediaSession / iOS Control Center） | 全仓库 `audio_service` 零匹配（pubspec、lock、lib、android、ios 均无） | **未实现** | 锁屏/通知栏/媒体键全部不可用 |
| 1.3 | SPEC.md:183 / ROADMAP.md:126 | "60Hz 表现层高刷流，直接订阅 `player.stream.position`" | `audio_player_service.dart:304-329`：`Timer.periodic(Duration(milliseconds: 50))` 每次把 `_position` 加 50ms 纯自增；类中无任何 player 实例 | **未实现（内存模拟）** | 所谓"60Hz 高刷"实为 20Hz 定时器自走时钟，与音频播放无关联 |
| 1.4 | SPEC.md:184-188 / ROADMAP.md:127 | 1s 节流系统广播（playing / seek / 切歌 / 每 1000ms） | 无 audio_service、无 PlatformChannel 上报代码 | **未实现** | — |
| 1.5 | SPEC.md:439 / SPEC.md:467 | Windows 产物为 `mellow_music.exe` | `app/windows/CMakeLists.txt:7` `set(BINARY_NAME "app")`；`release_windows/app.exe` 为实际产物 | **与文档不一致** | 文档给出的路径与文件名均错；`windows_physical_client_e2e_verify.ps1` 已做 app.exe / mellow_music.exe 双候选兜底 |
| 1.6 | README.md:62 / ROADMAP.md:156-165 | Android/iOS 系统媒体集成（MediaSession、锁屏封面流控、锁屏歌词） | `app/android/app/src/main/AndroidManifest.xml` 无 `FOREGROUND_SERVICE` / 播放 Service 声明；`MainActivity.kt` 为 3 行 stock 实现；`app/ios/Runner/Info.plist` 无 `UIBackgroundModes: audio` | **未实现** | 移动端后台播放 / 锁屏控制完全缺失 |

### 1.2 音源引擎（声称 flutter_js QuickJS 沙箱 + Dart Polyfill + 六大平台聚合 + 双重降级）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 2.1 | SPEC.md:49 / SPEC.md:207 / ROADMAP.md:30 | `flutter_js` 构建 QuickJS 独立实例 | pubspec / lock 无 `flutter_js`；lib 内唯一匹配是 UI 文案 `desktop_views.dart:1348` "自定义音源管理 (QuickJS)" | **未实现（仅 UI 文案）** | 无 JS 运行时，第三方脚本物理上无法执行 |
| 2.2 | SPEC.md:229-238 / ROADMAP.md:116 | Dart 注入 `globalThis.lx`，含 `lx.request` / `lx.utils.buffer` / `lx.utils.crypto`(md5/aes/rsa) | lib 内无 `globalThis.lx` 注入代码；仅 `lx_script_sandbox.dart:601-604` 有一个 Dart 侧 `md5Hash()` 工具方法；无 AES/RSA（`pointycastle` 未引入） | **未实现** | 六音脚本即使能跑也缺 `lx` 全局对象 |
| 2.3 | SPEC.md:243-247 / ROADMAP.md:118-121 | 脚本须响应 `search` / `getMusicUrl` / `getLyric` / `getPic` 四类 action | `lx_script_sandbox.dart:7-49` 的 `LxSourceDriver` 抽象接口确有这 4 个方法名；但 `LxCustomScriptDriver`(555-724) **不解析也不执行 JS**：`initialize()` 只做字符串包含检查(580-586)，`search()` 直接返回 1 首硬编码 mock(616-636)，`getMusicUrl()` 返回假 URL `https://custom-cdn.<id>.com/stream/...`(646)，`getLyric()` 返回两行编造歌词(651-654) | **未实现（接口空壳 + 硬编码 Mock）** | 导入任何脚本都"能启用"是假象：永远返回 1 首假歌 |
| 2.4 | PROGRESS.md:43 / ROADMAP.md:118 | 全网多平台聚合搜索 wy/kw/tx/kg/mg | `_initializeDefaultDrivers()`(847-964) 注册 6 个 driver（mellow/kw/kg/tx/wy/mg）；`searchAggregated()`(986-1035) 的并发与去重逻辑真实；但每个 driver 的曲库都是同一份 5 首 `sampleSongs` 本地常量(852-913)，无一个真实 HTTP 请求 | **部分实现（聚合框架真、数据源全假）** | "聚合搜索"结果永远是这 5 首 mock 歌的改名副本；`PlatformPresetSourceDriver.getMusicUrl` 返回 `https://cdn.<platform>.music.net/...`(452) 死链 |
| 2.5 | PROGRESS.md:43 / SPEC.md:449 | 双重容错降级（音质平滑降级 + 跨源热切换） | `resolveMusicUrlWithFallback()`(1040-1119)：外层遍历候选源、内层遍历 `qualityChain`，逐级 try/catch 并记录 `fallbackChain` | **已实现（仅算法层）** | 算法真实且可测，但被 mock 数据源包围，且**从未被播放链路调用**（工程内不存在播放链路） |
| 2.6 | PROGRESS.md:16 / ROADMAP.md:102 | 引擎已交付并集成 | `LxSourceEngine` / `LxSourceDriver` 的全部引用只出现在 `lx_script_sandbox.dart` 自身与 `test/lx_source_engine_test.dart`；`main.dart:12-20` 只注入 ThemeProvider / AudioPlayerService / EqualizerManager，**未注入 LxSourceEngine** | **未接线（死代码）** | 音源引擎对最终用户 100% 不可见 |
| 2.7 | ROADMAP.md:103 / `modals.dart:731` | 外部歌单链接导入（网易云/QQ/酷狗） | `online_music_service.dart:87-161` 仅解析网易云 `id=` 与纯数字并请求 `music.163.com/api/playlist/detail`；QQ/酷狗链接无任何分支处理 | **部分实现** | 文档称支持三类链接，代码仅支持网易云一种 |

### 1.3 数据库（声称 Drift + SQLite3 + FTS5 + 5 张表）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 3.1 | SPEC.md:56 / SPEC.md:384 / ROADMAP.md:36,142-149 | `Drift (SQLite3 FTS5)` 响应式数据库 | pubspec / lock 无 `drift` / `drift_dev` / `sqlite3_flutter_libs`；`app/lib` 下**无 `core/database/` 目录**（SPEC.md:384 声称该目录存在） | **未实现** | SPEC 第 8 章目录结构中的 `core/database/` 是虚构目录 |
| 3.2 | SPEC.md:278-335 | 5 张表：SongsTable / PlaylistsTable / PlaylistSongsTable / HistoryTable / SourcesTable | 全仓库（含测试）检索 `SongsTable` / `PlaylistsTable` / `PlaylistSongsTable` / `HistoryTable` / `SourcesTable` / `FTS5` / `GeneratedDatabase` → **0 匹配** | **未实现** | SPEC 中"引用实现"级别的 dart 代码块在工程里不存在 |
| 3.3 | SPEC.md:149 / ROADMAP.md:149 | 本地数十万曲库毫秒级 FTS5 联想检索 | 无数据库；"搜索"为内存 `List.where`（`lx_script_sandbox.dart:402-407`）与在线 API 转发 | **未实现** | — |
| 3.4 | SPEC.md:115（`PageStorageKey` 保证状态不丢）/ 全文隐含持久化 | 播放状态 / 收藏 / 主题持久化 | `theme_provider.dart` 全文无持久化；`shared_preferences` 虽在 `pubspec.yaml:41` 声明，但 **lib 内 0 次引用**；收藏与历史仅存内存（`audio_player_service.dart:19-22`） | **未实现** | 应用重启后收藏、历史、主题、EQ 全部归零；反而是 Web 原型用了 localStorage（`index.html:1848-1881`） |

### 1.4 路由（声称 go_router 强类型 34 路由）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 4.1 | SPEC.md:115 / SPEC.md:387 | 全量强类型路由表 `navigation/app_router.dart`（go_router） | `app/pubspec.yaml:39` 有 `go_router: ^18.0.1`，但 `app/lib` 内 `GoRouter` / `GoRoute` / `context.go(` / `context.push(` **0 匹配**；`navigation/` 下只有 adaptive / desktop / mobile_scaffold 三个文件，**无 app_router.dart** | **未实现** | 依赖被声明却完全未使用（pubspec 中 7 个依赖同属此类，见 §2 D-7） |
| 4.2 | SPEC.md:118-157 / ROADMAP.md:52-94 | 34 个路由路径（`/desktop/discover`、`/mobile/tabs/discover` …） | 全仓库无任何 `/desktop/`、`/mobile/` 路由字符串；`main.dart:55` `home: const AdaptiveScaffold()` | **未实现** | 34 个"路由"实际是同一 Scaffold 内的字符串枚举 |
| 4.3 | README.md:148 / ROADMAP.md:100-105 | 导航应为路由跳转 | `desktop_scaffold.dart:25` `String _activeView = 'discover';` + `_navigateTo()`(30-37) + `switch`(334-358)；`mobile_scaffold.dart` `switch`(423-438) + `_currentTab` | **与文档不一致（字符串 switch 复用单壳）** | 无深链接 / 无返回栈 / Web 端无法直达任意页 |
| 4.4 | SPEC.md:120-131（桌面 12 视图） | 12 个桌面视图类名 | 逐类 grep：DesktopDiscoverView(desktop_views.dart:14)、DesktopPlaylistSquareView(264)、DesktopToplistView(345)、DesktopArtistsView(604)、DesktopArtistDetailView(666)、DesktopPodcastView(783)、DesktopFavoriteView(850)、DesktopHistoryView(1098)、DesktopLocalMusicView(1145)、DesktopSettingsView(1209)、DesktopFullscreenLyricsView(fullscreen_lyrics_view.dart:13)、DesktopSourceManagerView(1331) → **12/12 存在** | **已实现（组件层）** | 但不经路由访问，且数据全 Mock |
| 4.5 | SPEC.md:132-135（桌面 4 弹窗抽屉） | PlaybackQueueDrawer / EqualizerModal / SleepTimerModal / QuickSearchOverlay | EqualizerModal(modals.dart:161)、SleepTimerModal(330)、QuickSearchOverlay(462) 存在；**`PlaybackQueueDrawer` 不存在**，实际类名为 `PlaybackQueueView`(modals.dart:16)，以 `Positioned` 面板内嵌（desktop_scaffold.dart:87-95），非 Drawer 组件 | **部分实现（1 个类名不符、实现形态不同）** | 文档声称 `Drawer`，实为自绘浮层 |
| 4.6 | PROGRESS.md:38 | "移动端 4 主 Tab + 8 二级页面 + 5 大弹窗/抽屉"（与 SPEC 的 9 页自相矛盾） | 实际 switch 仅 8 个二级页 case | **与文档不一致（文档内部互相打架）** | SPEC 说 9 页、PROGRESS 说 8 页、README 说 9 个二级页 |
| 4.7 | （SPEC / ROADMAP 未记载） | — | 实际存在 2 个未入册视图：`DesktopImportedPlaylistsView`(desktop_views.dart:970, case 'imported' 349)、`DesktopSyncView`(1401, case 'sync' 359) | **文档漏写** | 桌面实际 14 个主视图，多于文档的 12 |

**路由统计**：文档 34 个路由槽位 → **可用 go_router 路由 0/34**；作为 UI 组件存在 **30/34**（桌面 16/16、移动 14/18）；完全缺失 **4 个**（见 1.10）。

### 1.5 动效歌词（声称 LRC/QRC 毫秒解析 + 贝塞尔 + 多窗口穿透）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 5.1 | SPEC.md:50 / SPEC.md:255-260 | LRC/QRC 毫秒级解析器 | `track_model.dart:13-35` `LyricLine.parseLrc()`，正则 `\[(\d{2}):(\d{2})\.(\d{2,3})\]`，精确到毫秒（`milliseconds: milli`） | **已实现（仅 LRC）** | QRC / KRC 逐字歌词无任何解析代码 |
| 5.2 | SPEC.md:258 / ROADMAP.md:31,134 | 逐字高帧率贝塞尔曲线插值（Cubic(0.25, 0.1, 0.25, 1.0)）平滑滚动 | lib 内 `Curves.` **0 匹配**；唯一的 `AnimationController` 是黑胶旋转（`fullscreen_lyrics_view.dart:124-131`）；歌词为普通滚动列表 + 高亮 | **未实现** | 无插值、无逐字、无 60fps 驱动（进度本身是 50ms 定时器） |
| 5.3 | SPEC.md:262-269 / ROADMAP.md:136-140 | `desktop_multi_window` 独立穿透歌词窗口 | pubspec 无 `desktop_multi_window`；lib 无子窗口创建代码；`main.dart` 单 `runApp` | **未实现** | 桌面歌词窗口完全不存在 |
| 5.4 | SPEC.md:265 / ROADMAP.md:138 | Win32 `WS_EX_TRANSPARENT` / `WS_EX_LAYERED` / `WS_EX_TOPMOST` 鼠标穿透 | `app/windows/runner/win32_window.cpp` 全文无 `WS_EX_TRANSPARENT` / `WS_EX_LAYERED`；窗口创建为 stock `WS_OVERLAPPEDWINDOW`(win32_window.cpp:137-138) | **未实现** | — |
| 5.5 | ROADMAP.md:140 | Android `SYSTEM_ALERT_WINDOW` 系统级浮窗歌词 | AndroidManifest.xml 无该权限；android 目录无浮窗 Service | **未实现** | — |
| 5.6 | SPEC.md:254-256 / README.md:46 | 提取封面 3 处主色 + `BackdropFilter(blur 90)` 流体光晕 | `acoustic_mesh_glow.dart:26-33`：取 `theme.accentColor` + 两个硬编码色 `0xFF8B5CF6` / `0xFFEC4899`，**与当前曲目封面无关**；无 BackdropFilter | **部分实现（有光晕、无取色）** | 浓度滑块有效（设置页），但"随封面自适应取色"不成立 |

### 1.6 均衡器 EQ（声称 10 频段 libmpv firequalizer + 5 大预设）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 6.1 | SPEC.md:190-195 | 10 组中心频率 31Hz~16kHz，范围 -12 ~ +12 dB | `equalizer_manager.dart:18-29` `frequencyBands` 恰为 10 个；`setBandGain` 带 `clamp(-12,12)`(45-51) | **已实现（数据层）** | — |
| 6.2 | SPEC.md:191-193 / ROADMAP.md:128-129 | 向 libmpv 动态挂载 `firequalizer` 滤镜 | `equalizer_manager.dart:81-93` 只**拼接字符串** `toLibmpvFilterString()`；该方法在 lib 内 **0 调用**，仅 3 个测试文件调用（`mellow_music_comprehensive_test.dart:130`、`client_e2e_user_journey_test.dart:156`、`app_client_e2e_test.dart:156`）；无 media_kit / libmpv 可挂载 | **未实现（生成了字符串但无处应用）** | 调 EQ 对声音零影响（本来也没有声音） |
| 6.3 | README.md:60 / SPEC.md:196-200 / SPEC.md:451 | 5 大预设 | `equalizer_manager.dart:4-14` 枚举 **6 项**：flat / bassBoost / clearVocal / warmJazz / spatial3d / custom；UI 全量渲染 6 个预设按钮（`modals.dart` 内 `EqualizerPreset.values.map`） | **与文档不一致** | README 说 5 大预设，SPEC §E2E-05 又说"9 款声学预设"，同一文档三处口径不一 |
| 6.4 | PROGRESS.md:39 | "实现声学 10 频段 EQ 管理器" | `_bandGains` 为内存 `List<double>`，仅靠 `notifyListeners()` 驱动 UI 重绘 | **仅 UI 数值（无逻辑落地）** | — |

### 1.7 多端同步（声称 WebDAV 加密双向同步 + LX-Sync 100% 兼容）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 7.1 | SPEC.md:452 / ROADMAP.md:104,152 | WebDAV 增量双向加密同步（坚果云 / Nextcloud / 群晖） | `webdav_sync_service.dart` 实现了 `testConnection` PROPFIND(194-245)、`_ensureRemoteDirectory` MKCOL(247-263)、`uploadSnapshot`(265)、`downloadSnapshot`(300)、`sync` + LWW(334-405)、Basic Auth(118)；**但**全 lib 无 `encrypt` / `AES` / 加密实现（仅有一个 `password` 字段），且该类**未被任何 UI 引用** | **部分实现（服务层真、加密为零、未接线）** | "加密同步"不成立 |
| 7.2 | SPEC.md:446 / desktop_views.dart:1401-1455 | 同步中心 UI 执行上传 / 恢复 | `_triggerUpload()`(1417-1435) 与 `_triggerRestore()`(1437-1455) 均为 `await Future.delayed(900ms)` 后弹 SnackBar「已成功…备份至 WebDAV 云端」；硬编码服务器 `https://dav.jianguoyun.com/dav/` 与账号 `gaore@mellow.music`(1414-1415)，无任何输入框 | **只做了 UI 没逻辑（假成功）** | 用户会看到"同步成功"的假提示，属误导性 UI |
| 7.3 | SPEC.md:339 / ROADMAP.md:154 | 局域网监听 `0.0.0.0:23332` | `lan_sync_service.dart:112` `_port = 23332`；`start()`(128-146) `HttpServer.bind(InternetAddress.anyIPv4, 23332)` | **已实现** | 端口与文档一致 |
| 7.4 | SPEC.md:341 | `WS /sync` WebSocket 长连接 + RSA/AES 握手密钥交换 | 无 WebSocket（`dart:io` 仅用 `HttpServer`）；无 RSA/AES 代码，配对仅明文比对 `reqKey == _authKey`(lan_sync_service.dart:188-201)，`/sync/push` 用明文 `X-Auth-Key` 头(204-212) | **未实现** | 鉴权强度 = 6 位随机码明文比对，无签名、无加密 |
| 7.5 | ROADMAP.md:155 | gzip 压缩传输、公私钥签名、与原生 LX-Music 双向互同步 | lib 内 `gzip` **0 匹配**、`rsa` / `signature` **0 匹配**；实际端点为自造的 `/sync/hello`(171)、`/sync/pair`(184)、`/sync/push`(202) | **未实现** | "100% 兼容原生 LX-Sync 报文"无依据；`fromLxSyncPayload`(220) 只是本地格式猜测 |
| 7.6 | SPEC.md:354 / ROADMAP.md:104,154 | `lxsync://ip:port?key=...` 配对二维码 | `lan_sync_service.dart:96-106` 确实拼出 `lxsync://$ip:$port?key=…` 字符串；但无 `qr_flutter` / `qr` 依赖、无二维码渲染；UI 只有静态文案 `'IP: 192.168.1.103 · iOS 17.5 · Mellow v2.1.0'`(desktop_views.dart:1766) | **部分实现（生成 URI、无二维码、无扫码）** | 无二维码即无"扫码配对"体验 |
| 7.7 | PROGRESS.md:49 | "实现了基于端口 23332 的局域网直连同步…100% 兼容" | `LanSyncService` 同样**未被任何 UI 引用**（仅自身 + 测试） | **未接线（死代码）** | — |

### 1.8 桌面交互（无边框标题栏 / 交通灯 / 全局快捷键 / Ctrl+K / 托盘 / 最小尺寸）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 8.1 | README.md:54 / SPEC.md:447 | 无边框拟物标题栏（可拖拽、最大化 / 最小化 / 关闭） | Flutter 内自绘了 56px 标题栏(`desktop_scaffold.dart:102-250`)，但窗口样式仍是 stock 有边框窗口（`win32_window.cpp:137-138` `WS_OVERLAPPEDWINDOW`，无 `WM_NCCALCSIZE` 处理）；标题栏内**没有**最小化 / 最大化 / 关闭按钮 | **只做了 UI（假无边框）** | 系统标题栏与应用内标题栏并存，视觉上双标题栏 |
| 8.2 | README.md:54 | Mac 交通灯（红黄绿） | lib 内 `traffic` 0 匹配；git 提交 `4b8bb71` 明确 "remove fake mac traffic lights & mobile preview"（原型 `index.html:508-510` 有） | **未实现（且已被主动移除）** | 文档描述的正是代码里被删掉的假控件 |
| 8.3 | README.md:62 / SPEC.md:135 | 全局快捷键 Space(播放) / M(静音) / L(歌词) / Q(队列) / Escape(退出) / Arrow(调音快进) | `app/lib` 内 `Shortcuts` / `RawKeyboard` / `HardwareKeyboard` / `KeyboardListener` / `LogicalKeyboardKey` **全部 0 匹配**；唯一含 "ESC" 的是搜索框 hint 文案(`modals.dart:567`)与退出全屏 tooltip(`fullscreen_lyrics_view.dart:104`)。原型侧 `index.html:3191-3240` 有完整实现 | **未实现（客户端）** | Flutter 客户端按任何键都无反应 |
| 8.4 | SPEC.md:135 / README.md:54 | `Ctrl/Cmd + K` 呼出全局搜索 | 标题栏仅渲染了一个写着 "Ctrl K" 的徽标(`desktop_scaffold.dart:186`)，点击可开 `QuickSearchOverlay`(163)，但无键盘监听 | **部分实现（仅 UI 入口）** | 按 Ctrl+K 无效，与徽标承诺不符 |
| 8.5 | ROADMAP.md:163 | 桌面端配置系统级托盘 (System Tray) | pubspec 无 `tray_manager` / `system_tray`；lib 与 windows 目录无托盘代码 | **未实现** | — |
| 8.6 | SPEC.md:447（E2E-01） | 最小窗口尺寸约束 / 无边框贴靠 | `win32_window.cpp` 无 `WM_GETMINMAXINFO` / `kMinSize`（0 匹配）；窗口初始 1280x720(`main.cpp:27-28`) | **未实现** | 窗口可被拖到极小尺寸；响应式断点为 1024px(`adaptive_scaffold.dart:14`，与 SPEC.md:115 一致，但与 SPEC.md:454 的 800px 阈值矛盾） |

### 1.9 设置中心

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 9.1 | SPEC.md:129 | 设置中心含：深浅色切换、5 大强调色圆盘、弥散光晕浓度、**音源管理与音质首选项** | `DesktopSettingsView`(desktop_views.dart:1209-1328) 全量内容 = 3 张卡片：①外观(1225-1255) ②强调色(1259-1299) ③光晕浓度 `Slider`(1303-1324) | **部分实现（4 项声称中 3 项落地）** | 音源管理与音质首选项不在设置页 |
| 9.2 | SPEC.md:129 | 音质首选项 | 无 UI 入口；`LxSourceEngine.preferredQuality`(lx_script_sandbox.dart:746-750) 存在但引擎未接入 | **未实现** | — |
| 9.3 | SPEC.md:143 | 离线缓存清理 | 全仓库无缓存目录与清理逻辑（`path_provider` 已声明但 0 引用） | **未实现** | — |
| 9.4 | ROADMAP.md:65 / PROGRESS.md:16 | 音源管理（脚本导入 / 启用 / 测试 / 热重载） | `DesktopSourceManagerView`(1331-1398) 只有 1 张静态卡片："内置综合聚合音源" + 硬编码 `'v2.1.0 · 运行中'`(1383)；**"在线导入音源链接"按钮 `onTap: () {}` 空实现(1352-1358)**；**开关 `Switch.adaptive(... onChanged: (_) {})` 空实现(1391)** | **只做了 UI 没逻辑** | 开关永远不变；导入按钮点了没反应 |
| 9.5 | SPEC.md:75-80 | 5 大强调色 | `tokens.dart:4-9` 恰为 5 项，配色与 SPEC 逐色一致 | **已实现** | — |

### 1.10 移动端（4 Tab + 9 二级页 + 5 底部抽屉）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 10.1 | SPEC.md:140-143 | 4 主 Tab | `MobileDiscoverTab`(mobile_tabs.dart:12)、`MobileExploreTab`(768)、`MobileLibraryTab`(849)、`MobileProfileTab`(942) → **4/4** | **已实现** | — |
| 10.2 | SPEC.md:144-152 | 9 个二级页 | 存在 8 个：MobileDailyRecommendPage(mobile_pages.dart:14)、MobilePlaylistSquarePage(241)、MobileToplistPage(295)、MobileRadioPage(360)、MobilePersonalFMPage(121)、MobileArtistsPage(423)、MobileArtistDetailPage(489)、MobileLocalMusicPage(579)；**`MobilePlaylistDetailPage` 类不存在**，`mobile_scaffold.dart:423-438` 只有 8 个 case（无 `playlist_detail`，无 `/mobile/playlist/:id`） | **缺失 1 个（8/9）** | 移动端无法进入歌单详情 |
| 10.3 | SPEC.md:153-157 | 5 个底部抽屉：MobilePlayerBottomSheet / MobileQueueBottomSheet / MobileEqBottomSheet / MobileSleepTimerBottomSheet / MobileVolumeModal | 存在 2 个：`MobilePlayerBottomSheet`(mobile_sheets.dart:15)、`MobileQueueBottomSheet`(295)；**MobileEqBottomSheet / MobileSleepTimerBottomSheet / MobileVolumeModal 三个类均不存在**——移动端 EQ 与定时器直接复用桌面 `showDialog(EqualizerModal / SleepTimerModal)`(`mobile_sheets.dart:269,277`)，音量弹层无任何实现 | **缺失 3 个（2/5）** | 文档承诺的"移动端 10 频段触控 EQ / 定时器弹层 / 触觉音量条"均无对应页面 |
| 10.4 | SPEC.md:140 | 顶部灵动岛沉浸条、金刚区 5 大入口 | 实际有金刚区与浮动胶囊 Mini 播放器（`mobile_scaffold.dart:240-352`） | **已实现（原型级）** | — |

**移动端统计**：文档 18 槽位 → 存在 **14/18**，缺失 **4**。

### 1.11 测试与质量门禁

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 11.1 | README.md:5,95,109-113 | "Total Scenarios Tested: 83；Passed 83/83 (100%)" | `e2e_test.js` 全文**无字面量 83**；`recordResult(` 调用点实际 **84 处**（第 15 行是函数定义）；运行时 `total = testResults.length`(829) | **与文档不一致（数字对不上）** | 徽章与报告正文是手写常量，非运行输出 |
| 11.2 | README.md:97 / PROGRESS.md:13 | 83 项 E2E 覆盖"桌面端与移动端核心用户路径" | `e2e_test.js:34-36` SUITE 1 = Desktop(`index.html`，1440x900)；`:331-333` SUITE 2 = Mobile(`mobile.html`，390x844) | **测试对象是 Web 原型，非 Flutter 客户端** | README 把它当作客户端交付证据属口径错位；`BASE_URL = 'http://localhost:8088'`(11) 还需另起 `npm start` |
| 11.3 | PROGRESS.md:5,60 | `flutter test` **47/47** 通过 | 静态计数：`app/test`(8 文件) + `app/integration_test`(1 文件) 共 `test(` **44** 个 + `testWidgets(` **33** 个 = **77** 个用例 | **与文档不一致** | 分文件：lx_source_engine 25、sync_services 15、client_e2e_journey 8、mobile_prototype 6、comprehensive 4+3、alger_features 3、modals_and_lyrics 3、toplist_and_sync 2、integration 8 |
| 11.4 | SPEC.md:484 | `flutter test` 须达 **55/55 Suites**（含客户端原生全链路 E2E） | 实际 77 个用例；且 `app/integration_test/app_client_e2e_test.dart`（8 个 `testWidgets`）位于 `integration_test/`，`flutter test` **默认不执行**该目录 | **与文档不一致 + 门禁假覆盖** | PROGRESS.md:54 声称 CI"包含客户端原生全链路 E2E 旅程测试"，实际 CI 从未运行 |
| 11.5 | PROGRESS.md:59 | `flutter analyze` → "No issues found! (0 错误 0 警告 0 提示)" | **未能实机复现**（本环境无 flutter / dart CLI）；`app/analysis_options.yaml` 通过 `analyzer.exclude` 排除了 android / ios / windows / macos / web / linux | **无法验证** | 静态分析范围被收窄到 lib + test，不构成"全工程 0 issue"的证据 |
| 11.6 | SPEC.md:415-435,464 | 硬性质量红线：未捕获异常必须为 0 | Flutter 侧无异常监控代码；`flutter_e2e_verify.mjs` 采集了 `pageerror` 却从不判定（见 12.3） | **未实现** | 红线无技术手段兜底 |

### 1.12 CI/CD

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 12.1 | SPEC.md:481 | ci.yml 在 push / PR 到 main 时触发 | `.github/workflows/ci.yml` 触发条件正确；2 个 job：`code-quality-and-client-e2e`(ubuntu-latest)、`build-windows-desktop-client`(windows-latest) | **已实现** | — |
| 12.2 | SPEC.md:483-486 | analyze 0 issue → flutter test → 编译 Windows Release → Web E2E 探针 | 步骤齐全（analyze / test / build web / npm ci / node flutter_e2e_verify.mjs / upload artifact） | **已实现（流程齐全）** | — |
| 12.3 | SPEC.md:486 / PROGRESS.md:57 | "真实浏览器端到端渲染挂载验收""零未捕获异常" | `flutter_e2e_verify.mjs` 只做 `goto` + 等待 canvas + `screenshot` + 打印 `[PASS]`；`desktopErrors` / `mobileErrors` 被收集后**从未断言**；`allPassed` 仅在导航抛异常时置 false；点击侧边栏用硬编码坐标 `mouse.click(100,200)` / `(75,630)` | **门禁失效（零断言，永远 PASS）** | 最严重的"假绿灯"：Web E2E 步骤实质是截图脚本 |
| 12.4 | SPEC.md:489-498 | release.yml：tag `v*` 触发，5 平台矩阵 + 聚合发布 | 触发 `tags: v*` + `workflow_dispatch` ✅；5 个 build job(win / mac / linux / android / web) + `publish-release`(needs 5) + `softprops/action-gh-release` ✅ | **已实现** | — |
| 12.5 | README.md:145 / SPEC.md:5 | 平台覆盖含 **iOS** | release.yml **无 iOS job**（`flutter build ios` 0 匹配）；`needs` 列表也没有 | **未实现** | iOS 从未被 CI 构建 |
| 12.6 | release.yml:56 `name: Build macOS Universal` | macOS Universal（Intel + ARM）产物 | 构建机为 `macos-14`(arm64)，无 universal 参数，产物必然单架构 | **与文档不一致** | 命名误导，Intel Mac 用户可能无法运行 |
| 12.7 | SPEC.md:490-495 | 矩阵构建应含 Android SDK / JDK17 配置 | `build-android` 有 JDK17 但**未配置 Android SDK**（依赖 runner 预装，脆弱）；`build-android` 与 `build-web` **未跑 `flutter test`**（其余 3 个 job 跑了），门禁不一致 | **部分实现（存在明显缺陷）** | Android 构建可能因 SDK 版本波动失败；测试覆盖不均 |
| 12.8 | README.md:99-102 | `npm run test:e2e` 是项目质量手段 | `test:e2e` **完全不在任何 workflow 中**；且 `e2e_test.js:5-8` 硬编码 Windows Chrome / Edge 路径 | **未纳入门禁（且不可移植）** | Linux / macOS runner 上该脚本必然找不到浏览器 |
| 12.9 | PROGRESS.md:52-57 | "鸿蒙脚手架 + 全端支持" | release.yml 无 HarmonyOS job；`flutter build hap` 仅出现在 `app/harmonyos/README.md` 的文本里 | **未实现** | — |

### 1.13 平台矩阵（Windows / macOS / Linux / Android / iOS / HarmonyOS）

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 13.1 | PROGRESS.md:52 / ROADMAP.md:160 | "补齐 Linux 原生 CMake & GTK3 构建脚手架与 HarmonyOS NEXT / OpenHarmony 架构对接" | `app/linux/` 存在但是 `flutter create` stock 脚手架（`my_application.cc` 无任何定制，GTK 标题为 "mellow_music"，行 48/52） | **已实现（仅脚手架，无定制）** | 无托盘 / 无全局快捷键 / 无媒体集成 |
| 13.2 | SPEC.md:5 / ROADMAP.md:160 | HarmonyOS NEXT (OpenHarmony Stage / ArkUI) 支持 | `app/harmonyos/` **只有一个 `README.md`**：无 `AppScope/app.json5`、无 `entry/`、无 `module.json5`、无 `EntryAbility.ets`、无 `hvigor` / `oh-package.json5` / `build-profile.json5` | **未实现（纯文档）** | README 中列出的 3 个"核心配置文件"路径全部不存在 |
| 13.3 | ROADMAP.md:159-165 | 各端原生管道适配（Win SMTC / Android MediaSession / 鸿蒙 backgroundTaskManager / 桌面托盘） | windows / android / ios / macos 平台目录均为 stock；跨这些目录检索 `SMTC` / `MediaSession` / `backgroundTask` / `tray` → 0 匹配 | **未实现** | 六端平台定制为零 |
| 13.4 | SPEC.md:424 | E2E 产物覆盖 Windows(.exe) / macOS(.app) / Linux / Android(.apk) / Web(PWA) | 本地仅有 `release_windows/`（app.exe + flutter_windows.dll + data/），其余平台无本地产物 | **部分实现** | — |

### 1.14 版本号与身份一致性

| # | 声称（文档:位置） | 声称内容 | 代码证据 | 结论 | 差距/风险 |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 14.1 | `app/pubspec.yaml:19` | `version: 1.0.0+1` | `Runner.rc:63-72` 从中派生 `VERSION_AS_NUMBER` / `VERSION_AS_STRING`，缺省回退 `1,0,0,0` / `"1.0.0"` | **基准一致** | — |
| 14.2 | desktop_views.dart:1383,1766 | UI 显示 `v2.1.0 · 运行中` / `Mellow v2.1.0` | 与 pubspec 的 1.0.0 **不一致** | **与文档不一致（UI 与清单差 1 个大版本）** | 用户看到的版本与安装包元数据不符 |
| 14.3 | SPEC.md:3 / PROGRESS.md:3 / README 全文 | 规格书 `v1.1.0`、看板 `v1.0.0`、README 叙述 v1.0.0 | 三处口径不一 | **与文档不一致** | 无单一版本事实源 |
| 14.4 | SPEC.md:467 / SPEC.md:439 | 产物名 `mellow_music.exe` | 实际为 `app.exe`（`windows/CMakeLists.txt:3,7` project(app) / BINARY_NAME "app"；`release_windows/app.exe`） | **与文档不一致** | — |
| 14.5 | SPEC.md:467 / PROGRESS.md:31 | 应为品牌化应用 "Mellow Music · 润音" | 六端应用名均未品牌化：Windows 窗口标题 `"app"`(`main.cpp:29`)、`Runner.rc:93-99` ProductName/FileDescription/OriginalFilename = "app"/"app.exe"、Android `android:label="app"`、iOS `CFBundleDisplayName = App`、macOS `PRODUCT_NAME = app`、Linux GTK 标题 `"mellow_music"`、Web `<title>mellow_music</title>` + `description "A new Flutter project."` | **未实现（品牌身份未落地）** | 安装后系统显示 "app"，与"品牌重塑已完成"矛盾 |

---

## 2. 分组汇总

### A. 完全没做（文档有明确技术方案，代码零实现）

1. **media_kit / libmpv 播放底座**（SPEC:47、ROADMAP:28）— 无依赖、无解码；`AudioPlayerService` 是 50ms 定时器假时钟（`audio_player_service.dart:305-329`）
2. **audio_service 系统通道**（SPEC:48,176-180）— 全仓零匹配；SMTC / MediaSession / 锁屏控制全无
3. **flutter_js QuickJS 沙箱**（SPEC:49,207、ROADMAP:30）— 无依赖，脚本从不执行
4. **Dart Polyfill 注入**（`globalThis.lx`、buffer、crypto 的 AES/RSA）（SPEC:229-238）
5. **Drift + SQLite3 + FTS5 + 5 张表**（SPEC:56,278-335）— 表名标识符全仓 0 匹配，`core/database/` 目录不存在
6. **go_router 路由表**（SPEC:115,387）— 依赖已声明但 0 引用，`app_router.dart` 不存在
7. **desktop_multi_window 透明穿透歌词窗口 + Win32 `WS_EX_TRANSPARENT`**（SPEC:262-269）
8. **Android `SYSTEM_ALERT_WINDOW` 浮窗歌词**（ROADMAP:140）
9. **贝塞尔插值 / 逐字歌词 / QRC-KRC 解析**（SPEC:255-260）— lib 内 `Curves.` 0 匹配
10. **libmpv `firequalizer` 实际挂载**（SPEC:190-193）— 只生成字符串，lib 内 0 调用
11. **WebDAV 加密**（SPEC:452 声称"加密同步"）— 无任何加解密代码
12. **LX-Sync 的 WebSocket / RSA-AES 握手 / gzip / 公私钥签名 / 二维码**（SPEC:341,354、ROADMAP:155）
13. **Flutter 全局键盘快捷键系统**（Space / M / L / Q / Esc / Arrow、Ctrl+K）（README:62、SPEC:135）— 0 处键盘监听
14. **桌面系统托盘 / 最小窗口尺寸约束 / 真无边框窗口**（ROADMAP:163、SPEC:447）
15. **离线缓存清理、音质首选项 UI**（SPEC:129,143）
16. **HarmonyOS 工程**（SPEC:5、ROADMAP:160）— 只有一份 README，README 描述的配置文件全不存在
17. **iOS 的 CI 构建与后台音频**（README:145）
18. **任何本地持久化**（收藏 / 历史 / 主题 / EQ）— `shared_preferences` 声明未用

### B. 只做了 UI 没逻辑（界面在、点击无效果或假成功）

1. **同步中心**（`desktop_views.dart:1417-1455`）：`Future.delayed(900ms)` + SnackBar「已成功备份至 WebDAV 云端」，无任何网络请求；账号密码硬编码
2. **音源管理**（`desktop_views.dart:1331-1398`）：只有一个假状态卡片，「在线导入音源链接」`onTap: () {}`，启用开关 `onChanged: (_) {}`
3. **Ctrl+K 徽标**（`desktop_scaffold.dart:186`）：显示快捷键但无按键监听
4. **EQ 面板**（`modals.dart:161` 起）：10 个滑块只改内存 `List<double>`，对声音零影响
5. **桌面自绘标题栏**（`desktop_scaffold.dart:102-250`）：无最小化 / 最大化 / 关闭能力，窗口本身仍是系统边框
6. **声学弥散光晕**（`acoustic_mesh_glow.dart:26-33`）：用主题色 + 2 个硬编码色，不随封面取色
7. **外链歌单导入**（`online_music_service.dart:87-161`）：仅支持网易云，QQ / 酷狗链接静默失败
8. **多处"成功"提示与实际行为不符**（同步中心、音源开关等），属误导性 UI

### C. 做了但和文档不一致

1. **导航实现**：文档 = go_router 34 路由；实际 = `_activeView` / `_currentTab` 字符串 switch（`desktop_scaffold.dart:25,334-358`；`mobile_scaffold.dart:423-438`）
2. **队列抽屉**：文档 `PlaybackQueueDrawer`(Drawer)；实际 `PlaybackQueueView` 自绘浮层（`modals.dart:16`）
3. **移动端二级页**：SPEC 说 9 个、PROGRESS 说 8 个；实际 8 个，缺 `MobilePlaylistDetailPage`
4. **移动端底部抽屉**：文档 5 个独立类；实际 2 个，EQ 与定时器复用桌面 `showDialog`
5. **EQ 预设数**：README 说 5 大、SPEC §E2E-05 说"9 款"；实际枚举 6 项（含 custom），UI 渲染 6 个
6. **音源数量与命名**：SPEC:448 说"聚合 6 大音源"、ROADMAP:30 说"六音"；实际 6 个 driver 全部 mock（`lx_script_sandbox.dart:847-964`）
7. **响应式断点**：SPEC:115 说 1024px（代码 `adaptive_scaffold.dart:14` 一致），SPEC:454 E2E-08 又说 800px 阈值
8. **E2E 数字**：README 83 vs 脚本 84 个断言点；PROGRESS 47 vs 实际 77 用例；SPEC 55 vs 实际 77
9. **质量门禁**：文档称 E2E 是"不可逾越的硬性红线"，实际 `flutter_e2e_verify.mjs` 无断言、永远 PASS
10. **版本号**：pubspec 1.0.0 / UI v2.1.0 / SPEC v1.1.0 / PROGRESS v1.0.0，四处不一
11. **产物名与品牌**：文档写 `mellow_music.exe`，实际 `app.exe`；六端应用名均为 "app" / "mellow_music"
12. **macOS Universal**：实际单架构 arm64
13. **音源引擎与同步服务**：文档称"已集成、全绿"，实际是未被 UI 引用的死代码（仅测试可达）

### D. 文档漏写（代码有、文档无）

1. `DesktopImportedPlaylistsView`（`desktop_views.dart:970`，case `'imported'`）— 桌面实为 14 视图
2. `DesktopSyncView`（`desktop_views.dart:1401`，case `'sync'`）— SPEC 第三章无此模块，但第 9 章 E2E-06 又要求 WebDAV
3. `ImportPlaylistModal`（`modals.dart:731`）— 桌面第 5 个弹窗，SPEC 只列 4 个
4. `online_music_service.dart` 的网易云直连能力 — 工程内**唯一**真实的在线数据通路
5. `app/linux/`、`app/macos/`、`app/ios/`、`app/android/` 平台目录的存在及其 stock 性质，未在任何"已完成"条目中如实说明
6. `e2e_test.js` 的 SUITE 划分（桌面 1440x900 / 移动 390x844）与依赖 `npm start` 前置未在 README 说明
7. 7 个已声明但零引用的依赖（`go_router` / `google_fonts` / `intl` / `shared_preferences` / `dio` / `path_provider` / `path`）未在文档中说明用途

---

## 3. 大项统计数字

| 大项 | 文档声称量 | 代码实际 | 命中率 |
| :--- | :--- | :--- | :--- |
| 1. 播放底座 | 5 项依赖 / 通道（media_kit、audio_service、60Hz 流、1s 广播、无损解码） | **0 项**（进度用 50ms Timer 伪造） | **0/5** |
| 2. 音源引擎 | JS 沙箱 + Polyfill + 4 action + 多平台 + 双重降级 + UI 接入 | 接口与降级**算法**已写；JS 运行时 / Polyfill **0**；数据源 6/6 为 mock；UI 接入 **0**（死代码） | **2/6（数据全假）** |
| 3. 数据库 | 1 套 Drift(SQLite3+FTS5) + 5 张表 | 依赖 0、表 0、FTS5 0、本地持久化 0 | **0/6** |
| 4. 路由 | 34 个 go_router 路由（桌面 12+4 / 移动 4+9+5） | 真实路由 **0/34**；UI 组件 **30/34**（桌面 16/16、移动 14/18）；实现方式 = 字符串 switch | **0/34（路由）**、**30/34（组件）** |
| 5. 动效歌词 | 7 项（LRC/QRC 解析、贝塞尔、多窗口、WS_EX_TRANSPARENT、Android 浮窗、封面取色光晕） | 1 项完整（LRC 毫秒解析）、1 项部分（光晕无取色）、**5 项缺失** | **1.5/7** |
| 6. EQ | 10 频段 + firequalizer 注入 + 5 预设 | 10 频段数据层 ✅、UI ✅、**注入 0**、预设 6（文档 5 与 9 自相矛盾） | **1/3** |
| 7. 同步 | WebDAV 加密同步 + LX-Sync 端口 / WS / 签名 / gzip / 二维码 | 端口 23332 ✅；WebDAV 服务层已实现但**无加密且未接线**；WS / RSA / gzip / 二维码 **全 0** | **1.5/6** |
| 8. 桌面交互 | 6 项（无边框栏、交通灯、快捷键、Ctrl+K、托盘、最小尺寸） | **0 项完整**，2 项部分（自绘栏、搜索入口 UI），4 项缺失 | **0/6** |
| 9. 设置中心 | 4 项（深色、5 色、浓度、音源与音质）+ 缓存清理 | 3 项 ✅（深色 / 5 色 / 浓度）；音源管理与音质 0；缓存清理 0 | **3/5** |
| 10. 移动端 | 4 Tab + 9 二级页 + 5 抽屉 = 18 | Tab 4/4 ✅、页 **8/9**、抽屉 **2/5** | **14/18** |
| 11. 测试 | README 83/83、PROGRESS 47/47、SPEC 55/55 | `e2e_test.js` **84** 个断言点（Web 原型）；Flutter `test(` 44 + `testWidgets(` **33 = 77** 用例；`integration_test` **8** 用例默认不执行；analyze 无法复现 | **三处数字全部不符** |
| 12. CI/CD | 2 workflow / 6 job / 5 平台矩阵 + iOS + 鸿蒙 | 2 workflow、**6 job**（无 iOS、无鸿蒙）；**E2E 门禁零断言**；83 项 E2E 不在 CI；`test:e2e` 硬编码 Windows 浏览器路径 | **流程 ✅ / 有效性 ✗** |
| 13. 平台矩阵 | 6 端（Win / macOS / Linux / Android / iOS / HarmonyOS） | 5 端有 stock 脚手架（**0 平台定制**）；**HarmonyOS 仅 1 个 README**、0 工程文件 | **5/6（脚手架）、0/6（定制）** |
| 14. 版本一致性 | 1 个版本号、1 个品牌名 | 版本 4 处不一致（1.0.0+1 / v2.1.0 / v1.1.0 / 1.0.0）；应用名 6 端均未品牌化 | **0/2** |

**汇总（按主表 80 条断言计）**：**已实现 13 条**（2.5、4.4、5.1、6.1、7.3、9.5、10.1、10.4、12.1、12.2、12.4、13.1、14.1）、**部分实现或仅 UI 14 条**（2.4、2.7、4.5、5.6、6.4、7.1、7.2、7.6、8.1、8.4、9.1、9.4、12.7、13.4）、**与文档不一致 12 条**（1.5、4.3、4.6、6.3、11.1、11.2、11.3、11.4、12.6、14.2、14.3、14.4）、**文档漏写 1 条**（4.7）、**完全未实现 39 条**、**无法验证 1 条**（11.5，本环境无 flutter/dart CLI）。另发现**文档内部自相矛盾 8 处**、**代码有而文档无 7 处**。

---

## 4. 风险等级建议（供验收会议使用）

| 等级 | 事项 | 影响 |
| :--- | :--- | :--- |
| **P0** | 无任何音频解码 / 输出（media_kit 缺失），"音乐播放器"不具备播放能力 | 产品核心价值不成立 |
| **P0** | `flutter_e2e_verify.mjs` 零断言却充当 CI 硬门禁，且 README / PROGRESS 以"83/83、47/47、0 issue"作为交付证据 | 质量结论不可信，属虚假验收材料 |
| **P0** | 同步中心 / 音源管理给出"成功"假反馈（无网络请求） | 用户数据丢失且被误导 |
| **P1** | 无本地持久化（收藏 / 历史 / 主题 / EQ 重启即失） | 数据可靠性为零 |
| **P1** | 音源引擎与 WebDAV / LAN 同步服务是死代码，文档却声称已交付 | 交付物与验收清单不符 |
| **P1** | HarmonyOS 声称支持但零工程文件；iOS 无 CI 构建 | 平台矩阵承诺无法兑现 |
| **P2** | 34 个 go_router 路由一个都没实现，导航为字符串 switch | Web 端无深链接；架构文档失真 |
| **P2** | 版本号 4 处不一致、六端应用名仍为 "app" | 发布 / 合规风险（商店审核名不符） |
| **P3** | 桌面未真无边框、EQ 预设数口径不一、光晕不随封面取色 | 体验与文档承诺有落差 |

---

## 5. 复核指引（如何自行验证本报告）

```powershell
cd E:\code\AI\vibCoding\mellow-music-player

# 1. 关键依赖是否存在（预期：无输出）
Select-String -Path app\pubspec.yaml,app\pubspec.lock -Pattern 'media_kit|audio_service|flutter_js|drift|sqlite3|desktop_multi_window|window_manager|tray_manager|qr_flutter'

# 2. 路由 / DTO 类名是否存在（预期：无输出）
Get-ChildItem app\lib -Recurse -Filter *.dart | Select-String -Pattern 'GoRouter|SongsTable|MobilePlaylistDetailPage|MobileEqBottomSheet|MobileVolumeModal|PlaybackQueueDrawer'

# 3. 键盘监听是否存在（预期：无输出）
Get-ChildItem app\lib -Recurse -Filter *.dart | Select-String -Pattern 'Shortcuts|RawKeyboard|HardwareKeyboard|KeyboardListener'

# 4. 测试用例真实数量（预期：test=44, testWidgets=33）
Get-ChildItem app\test,app\integration_test -Recurse -Filter *.dart | ForEach-Object { $c = Get-Content $_.FullName -Raw; "{0}: test={1} testWidgets={2}" -f $_.Name, ([regex]::Matches($c,'(?m)^\s*test\(')).Count, ([regex]::Matches($c,'(?m)^\s*testWidgets\(')).Count }

# 5. E2E 断言点数量（预期：84）
(Select-String -Path e2e_test.js -Pattern "recordResult\('").Count

# 6. 鸿蒙工程文件（预期：仅 README.md 一个文件）
Get-ChildItem app\harmonyos -Recurse -Force
```

---

*报告生成：基于静态代码审计（未执行 `flutter analyze` / `flutter test`，本机无 flutter / dart CLI）。所有结论均可通过上节命令复核；未使用推测性描述。*




