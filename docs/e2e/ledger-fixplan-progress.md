# E2E 验收缺陷账本 · 修复方案阶段 0~7 与 44 条缺陷落地核对

> **修复进度汇总请见 [`docs/e2e/STATUS.md`](STATUS.md)**（2026-09-23 校准：哪些已修、哪些未修、证据是什么）。


> **负责人**：子 Agent D ｜ **取证时间**：本轮对当前工作区逐文件真实读取（非凭记忆）
> **核对对象**：`docs/PC_E2E_FIX_PLAN.md`（阶段 0~7 + 附录 A）与 `docs/PC_E2E_ACCEPTANCE_ISSUES.md`（44 条：P0-01~12 / P1-01~20 / P2-01~12）
> **判定口径**：功能可用 = 真实数据进入 + 真实副作用（落盘 / HTTP / 音频）+ 失败时有诚实反馈；能渲染 ≠ 能用。
> **本机环境（本轮实测）**：Flutter 3.47.4 stable / Dart 3.13.3 / macOS；`flutter analyze` → `No issues found!`；`flutter test` → 90/90 通过（首轮曾 89/90，见 PLAN-069）。
> **本轮未修改任何 `app/lib` 生产代码与既有测试**，仅写入本账本。

## 状态分布

| 状态 | 数量 | 条目 |
| :--- | :---: | :--- |
| 已修复 | 8 | P0-02 / P0-03 / P0-04 / P0-05 / P0-06 / P0-12 / P1-12 / P2-06 |
| 部分修复 | 17 | P0-01 / P0-07 / P0-08 / P0-09 / P0-10 / P0-11 / P1-01 / P1-02 / P1-03 / P1-04 / P1-06 / P1-08 / P1-11 / P1-14 / P1-17 / P1-19 / P1-20 |
| 未修复 | 19 | P1-05 / P1-07 / P1-09 / P1-10 / P1-13 / P1-15 / P1-16 / P1-18 / P2-01 / P2-02 / P2-03 / P2-04 / P2-05 / P2-07 / P2-08 / P2-09 / P2-10 / P2-11 / P2-12 |
| 已不适用 | 0 | — |
| **合计** | **44** | |

---

## 0. 44 条缺陷状态总表

| ID | 标题 | 状态 | 当前证据（本轮真实读取） | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| P0-01 | 完全没有音频播放能力：点播放永远无声 | 部分修复 | `app/lib/core/audio/player_backend.dart:22-71` RealAudioPlayerBackend 基于 audioplayers；`audio_player_service.dart:282-298` _executeRealPlay 用 track.audioUrl/localPath 真播放；`track_model.dart:120/142/162/184/204/222` 6 首示例曲均带 soundhelix mp3 直链 | 真播放与真实进度流达成；系统媒体控制/音频焦点/wakelock 全无（`wakelock\|audio_session\|audio_service` 在 app/lib 命中 0）；未采用方案建议的 media_kit |
| P0-02 | 零持久化：重启后收藏/历史/主题/强调色/EQ 全部归零 | 已修复 | `core/storage/storage_service.dart:20-183` 全量 KV 落盘；`audio_player_service.dart:113-161 _loadFromStorage()`；`theme_provider.dart:24-49/55-78` | 主题/强调色/光晕/音量/播放模式/收藏/历史/导入歌单均冷启动恢复；用 shared_preferences 替代 drift（阶段 2.1 的 drift 曲库未做） |
| P0-03 | 云端同步/备份伪造成功：900ms 定时器冒充 WebDAV | 已修复 | `desktop_views.dart:1558-1570` _triggerUpload/_triggerRestore 仅弹「尚未完整接入，请勿依赖」；:1554-1556 端点/账号改「未配置」；`Future.delayed(900ms)` 在 app/lib 命中 0 | 假成功弹窗、假账号、假「服务就绪」绿标全部删除；但 :1592 仍宣称「实时双向热备/毫秒级 P2P」（见 PLAN-010） |
| P0-04 | 局域网 P2P 假设备 + 端口不符：绿点写死、服务从未启动 | 已修复 | `desktop_views.dart:1783-1840` 假 iPhone 15 Pro / HomePod 卡片已删，改为「当前未发现局域网配对设备」；`18585` 在 app/lib 命中 0 | 设备编造与端口矛盾已消除；但 LanSyncService 仍未接线（阶段 4 未决策，见 PLAN-049） |
| P0-05 | Android release 缺 INTERNET 权限 | 已修复 | `app/android/app/src/main/AndroidManifest.xml:2-6` INTERNET / ACCESS_NETWORK_STATE / WAKE_LOCK / FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK | 静态核对通过；未产出 APK 实机验证（无 Android 构建链） |
| P0-06 | macOS release 缺 network.client entitlement | 已修复 | `app/macos/Runner/Release.entitlements:7-10` network.client + network.server 均为 true | 静态核对通过；本轮未做 release 签名产物验证 |
| P0-07 | LX 音源管理 (QuickJS) 是空壳，1836 行音源代码生产不可达 | 部分修复 | `desktop_views.dart:1498-1538` 假开关/v2.1.0 已删，改为「功能接入中」；`lx_script_sandbox.dart:727` LxSourceEngine 在 app/lib 仍 0 生产调用（仅自引用 + 测试） | 诚实话术已落地；阶段 4.2「接线或删除」未执行，1227+648 行死代码仍在 |
| P0-08 | 本地扫描/拖拽导入完全不可用，假本地曲目与假文件大小 | 部分修复 | `desktop_views.dart:1251-1285` 假列表/假 42.8MB/死按钮已删，改为诚实空态与「接入中」提示；`file_picker\|file_selector\|DragTarget` 在 app/lib 命中 0 | 阶段 0.2「删假」达成；阶段 2.4「真实现」完全未做，导入功能仍不存在 |
| P0-09 | 键盘交互全缺：Ctrl+K / ESC 等文案全部为假 | 部分修复 | `desktop_scaffold.dart:87-125` CallbackShortcuts 已实现 Space/Ctrl+K/Cmd+K/←/→/↑/↓/M/L/Q/ESC；:127 CallbackShortcuts | 桌面端已真实绑定；无 `shortcuts_test.dart`、未运行时验证；移动壳无快捷键 |
| P0-10 | 界面能力文案与实现矛盾（libmpv / firequalizer / 24bit / 服务就绪 / v2.1.0） | 部分修复 | UI 文案清除：`24bit/192kHz\|24bit/96kHz\|已缓存 6 首\|服务就绪\|18585\|已同步红心收藏\|v2.1.0` 在 app/lib 命中 0；残留 `equalizer_manager.dart:81/84` libmpv firequalizer | 代码层技术名词未清干净；同步中心 :1592、导入页 :1054（称支持 QQ 音乐）仍超额宣称 |
| P0-11 | 移动壳内置假 iOS 状态栏与 Mobile 调试角标 | 部分修复 | `mobile_scaffold.dart:93-160` 假 10:09/信号/WiFi/电池已删，灵动岛改真实曲目标题；`mobile_tabs.dart:82-89` 仍渲染常量 Text('Mobile') | 假状态栏数据已消除；Mobile 角标未删；灵动岛仍在 SafeArea 内（:58） |
| P0-12 | server.js 可被单条请求打死 + 目录穿越 + 0.0.0.0 + CORS 通配 + npm start 崩溃 | 已修复 | `server.cjs:35-59` safeResolve；:84-89 decodeURIComponent 兜底；:145-148 Range 校验；:167 uncaughtException；:169 默认 127.0.0.1；`package.json:6/8` main/start=server.cjs | 本轮实测：6 条畸形/Range payload 后进程存活；穿越请求全 403；POST→405；无 ACAO 通配 |
| P1-01 | 四榜单曲目池相同 + 静态更新文案 | 部分修复 | `track_model.dart:525/579/604/657` 四份独立列表；:728 toplistTracksMap；`desktop_views.dart:493` 按 chartTitle 取表 | 四榜曲目池已区分；但 :418/426/434/442 仍硬编码「每日09:00更新 · 100首」等静态更新承诺 |
| P1-02 | 歌手数据编造 / 头像张冠李戴 / 详情页共用代表作 / 默认已关注 | 部分修复 | `track_model.dart:473-506` 4 位歌手独立头像/bio/曲目；:509 getArtistProfileByName；`desktop_views.dart:739-845` 详情页用 artist 档案 | 头像与代表作已差异化；粉丝数仍编造、:733 `_isFollowing = true` 默认已关注且仅内存态、:705/:781 认证蓝勾无条件 |
| P1-03 | 歌单广场实为单曲 + 播放量编造 + 图片复用 | 部分修复 | `track_model.dart:866-966` SquarePlaylist 含 tracks + getPlaylistsByTag；`desktop_views.dart:293/324-398` 按标签过滤、卡片含完整曲目 | 「实为单曲」已修；播放量仍编造（:894/903/912/921/930/939/951）、封面大量复用、无歌单详情页 |
| P1-04 | 播放历史冷启动自插 1 条且无移除/清空 | 部分修复 | `audio_player_service.dart:107-111` 构造函数已不再自插；:389-393 clearPlayHistory；`desktop_views.dart:1184-1196` 清空按钮 | 冷启动伪造与一键清空已修；单条历史移除仍不存在（:1216-1236 仅 onTap 播放） |
| P1-05 | 收藏硬编码预置 4 首 | 未修复 | `audio_player_service.dart:29` `_favoriteIds = {'track-1','track-3','track-5','track-6'}`；`track_model.dart:121/163/205/223` 4 处 isFavorite: true | 首次安装仍显示 4 首收藏；UI 文案 :954 已改为「本地安全持久化存储」 |
| P1-06 | 设置中心仅 3 项，缺音质/缓存等 | 部分修复 | `desktop_views.dart:1289-1447` 现有 4 张卡片：外观/强调色/光晕/快捷键指南；`package_info_plus` 命中 0 | 快捷键卡补齐；仍缺音质首选项、离线缓存清理、关于（版本）三项 |
| P1-07 | 搜索面板初始结果 = 本地 mock、按 ESC 退出无效、网络失败静默 | 未修复 | `modals.dart:511` initState `_results = mockPresetTracks`；:528 回落 mock；:552 `if (onlineSongs.isNotEmpty)` 无 else；:598 hint 仍写按 ESC 退出；:670 无法区分网络异常 | 三项均未改；`online_music_service.dart:80/157/182` 仍 `catch (_)` 静默 |
| P1-08 | 声音电台卡片点击播放无关歌曲、无单集概念 | 部分修复 | `track_model.dart:769-863` 每电台绑定专属 Track（标题/时长/audioUrl）；`desktop_views.dart:882` 点击播 r.track | 点播内容与卡片已对应；仍无单集/主播模型，listeners 为编造数字 |
| P1-09 | EQ 第 5 个预设被裁切不可见、EQ 无 DSP 链路 | 未修复 | `equalizer_manager.dart:82-92` toLibmpvFilterString 在 app/lib 无生产调用；`modals.dart:233-249` 预设行仍横向 SingleChildScrollView（未改 Wrap）；:236 仅 6 个预设 | EQ 对声音零影响；裁切改法未实施；SPEC:451「9 款」/README:90「5 大」/实际 6 三处口径仍不一致 |
| P1-10 | 窗口无最小尺寸约束、<1024px 退化为移动壳、极小尺寸布局崩坏 | 未修复 | `app/lib` 与 `app/windows` 内 `window_manager\|WM_GETMINMAXINFO\|setMinimumSize\|minimumSize` 全仓 0 命中；`adaptive_scaffold.dart:14` 断点 1024；`main.cpp:29 Size(1280,720)` | 窗口最小尺寸约束未加 |
| P1-11 | 原生标题栏与全平台产物名为模板默认值 app | 部分修复 | 已改：`AndroidManifest.xml:9` label=Mellow Music；未改：`windows/CMakeLists.txt:4 project(app)`、`:9 BINARY_NAME app`、`runner/main.cpp:30 Create(L"app")`、`Runner.rc:93/95/97/98`、`AppInfo.xcconfig:8 PRODUCT_NAME = app`、`web/manifest.json:2-3/8`、`ios/Runner/Info.plist:10 App / :18 app`、`linux/runner/my_application.cc:52 mellow_music` | 仅 Android 完成品牌化；五端仍为 app/mellow_music/模板 |
| P1-12 | release.yml macOS 打包名不匹配导致发版流水线跑不通 | 已修复 | `.github/workflows/release.yml:80-84` 改为 `find ... -name "*.app"` 动态查找 + test -n 断言 | 打包步骤已修；:56 job 名仍为「Build macOS Universal」而 :78 无 universal 参数 |
| P1-13 | CI 未固定 Flutter 版本、flutter_e2e_verify.mjs 零断言、CI 不跑 83 项原型 E2E | 未修复 | `ci.yml:20/60` 与 `release.yml:26/65/110/154/188` 仍 channel: stable；`ci.yml:29` 无 --fatal-infos；`ci.yml:48` 跑 flutter_e2e_verify.mjs；全 workflow 无 e2e_test.js；无 .fvmrc/.tool-versions | `flutter_e2e_verify.mjs:126/181` 仍 `catch (_) {}`、:137-187 无条件 ✅ PASS、:201 打印 100% 通过、:141/149/157 硬编码坐标、desktopErrors/mobileErrors 从未断言 |
| P1-14 | 测试断言 mock 自身 / 条件断言 / 两测试文件重复 / 声称 47 实际 77 | 部分修复 | 重复仍在：`test/client_e2e_user_journey_test.dart` 与 `integration_test/app_client_e2e_test.dart` 均 285 行、MD5 均 9c6ce41ed07d4ed42f754a2b4a909698；`if (find` 在测试中命中 0；`lx_source_engine_test.dart` 25 用例仍以 mock 为判据 | 条件断言已清零、重复文件未删；用例数现为 98（test 52 + testWidgets 46，14 文件）与 README:33/127 的 90 口径不符 |
| P1-15 | pubspec 8/11 依赖未使用 + 缺关键依赖 + PingFang SC 在 Windows 无效 | 未修复 | `pubspec.yaml:36-47` 12 依赖；app/lib 引用：google_fonts 0 / go_router 0 / intl 0 / dio 0 / path_provider 0 / package:path 0 / cupertino_icons 0 / crypto 1（死代码）；`pubspec.yaml:66-102` 无 fonts: 段；`main.dart:44/54 fontFamily: 'PingFang SC'` | 僵尸依赖仍在；字体问题未改；`media_kit\|drift\|flutter_js` 在 app/lib 命中 0 |
| P1-16 | 50ms ticker 驱动 20Hz 全树 rebuild + 常驻模糊 | 未修复 | `audio_player_service.dart:164-167` position 回调直接 notifyListeners()；`desktop_scaffold.dart:79` 顶层 context.watch<AudioPlayerService>() | 进度流已真实，但每帧全树重建；无 positionNotifier/ValueListenableBuilder |
| P1-17 | 无 go_router / 无路由栈 / 无 PageStorageKey，前进按钮空实现 | 部分修复 | `desktop_scaffold.dart:33-74` 自建 _history 栈 + _goBack/_goForward 真实实现；:127 CallbackShortcuts | 前进/后退已真实；`GoRouter\|GoRoute\|PageStorageKey` 在 app/lib 仍 0 命中 |
| P1-18 | 可访问性缺失（0 Semantics） | 未修复 | `Semantics\|semanticLabel\|ExcludeSemantics` 在 app/lib 命中 0 | 完全未做 |
| P1-19 | 硬编码第三方私有接口 + 明文账号 | 部分修复 | `desktop_views.dart:1556` 明文账号已删；仍存：`online_music_service.dart:35` music.163.com 私有 API、:37-40/104-107/170-173 伪造 UA/Referer、:63/132 音频直链；:80/157/182 catch(_) | 明文凭据已清；私有接口与失效直链未治理；`desktop_views.dart:1054` 仍称支持 QQ 音乐导入 |
| P1-20 | 工程卫生：超大文件 / 死代码 / 版本号四处不一致 / 鸿蒙仅 README / 无错误上报 | 部分修复 | 版本单一来源已建立：`README.md:3`、`PROGRESS.md:3`、`SPEC.md:20`；未修：`desktop_views.dart` 1845 行、死代码仍在、`find app/harmonyos -type f` 仅 README.md、`FlutterError\|runZonedGuarded\|Crashlytics\|Sentry\|developer.log` 命中 0 | 多项工程红线仍失守；仅版本口径统一达成 |
| P2-01 | ListView(children:) 一次性构建 | 未修复 | `ListView(` 在 app/lib 共 21 处（desktop_views 13 / mobile_pages 3 / mobile_tabs 4 / desktop_scaffold 1）；Grid 多为 shrinkWrap: true + NeverScrollableScrollPhysics | 未改 builder/CustomScrollView |
| P2-02 | 歌词翻译不渲染、SPEC 称 9 款预设实际 6 款 | 未修复 | `translation` 在 `app/lib/views` 命中 0；`equalizer_manager.dart:4-14` 6 个预设 | 翻译字段仍无消费方；预设口径 9/5/6 三处仍矛盾 |
| P2-03 | 自绘标题栏无无边框配置 → 双标题栏 | 未修复 | `app/windows/runner/win32_window.cpp` 仍 WS_OVERLAPPEDWINDOW；无 window_manager/TitleBarStyle | 双标题栏未消除，自绘栏无最小化/最大化/关闭 |
| P2-04 | 播放状态机边界问题 | 未修复 | `audio_player_service.dart:300-314 next()` 无 singleLoop 短路且无条件 _recordHistory；:316-334 previous() 同样；:423-431 removeTrackAt 不重置 _position；:433-438 clearQueue 经 pause() 二次 notify | 三处边界均未修；正面：seek 有夹取、播完单曲循环分支正确 |
| P2-05 | design_tokens.css 与 tokens.dart 不一致 | 未修复 | CSS `design_tokens.css:20 --soft-bg-recessed: #E8EEF5` vs `tokens.dart:26 recessedLight = 0xFFEBF0F8`；CSS:24 #1E293B vs tokens.dart:29 #0F172A；圆角值域不重合（css :151-156 vs tokens.dart:58-65） | 无单一事实源；`convex`/`pressed` 在 tokens.dart 无对应 |
| P2-06 | README 引用 2 张不存在截图、npm start 命令失败 | 已修复 | 两张坏图已不再被 README 引用；README:48/52 改引已存在的 `public/e2e_flutter_desktop_verified.png`、`public/showcase_mobile_eq.png`；`node server.cjs` 实测启动成功，`npm start` 指向它 | 截图坏图与启动命令已修；README:33/127 的 90/90 与 :35 的 83/83 仍为静态文本（属 P1-13/P1-14） |
| P2-07 | Web 原型播放为振荡器合成音、mp3 零引用 | 未修复 | `index.html:1780/1807`、`mobile.html:1468/1494` createOscillator；`public/audio/track1-4.mp3`（34MB）全仓零引用；Hi-Res 文案仍在 `index.html:658/893/1285` | 振荡器发声未替换为真实 audio；大体积死文件仍在版本库 |
| P2-08 | 双端数据/文案不一致（含 e2e 断言互斥数据同时通过） | 未修复 | 无共享 data.js；index.html 与 mobile.html 各自维护常量；`e2e_test.js` 仍为自断言脚本 | 单一事实源未建立 |
| P2-09 | 移动端缺 1 个二级页、5 抽屉只有 2 | 未修复 | `mobile_scaffold.dart:396-410` 仅 8 个二级 case（无 playlist_detail）；`mobile_sheets.dart` 仅 MobilePlayerBottomSheet(:15)/MobileQueueBottomSheet(:338) | MobileEqBottomSheet / MobileSleepTimerBottomSheet / MobileVolumeModal / MobilePlaylistDetailPage 均不存在 |
| P2-10 | MellowImage 无 loading/磁盘缓存 + isInTest hack | 未修复 | `mellow_image.dart:7 static bool isInTest = false;`、:26 usePlaceholder = isInTest \|\| runtimeType 含 Test；无 loadingBuilder/磁盘缓存 | 生产代码测试开关仍在；无加载态与磁盘缓存 |
| P2-11 | 导入歌单仅预览前 5 首、封面加载失败 | 未修复 | `desktop_views.dart:1134 for (final t in pl.tracks.take(5))`，无「查看全部」；封面失败走占位 | 导入真实 200 首仍只显示 5 首 |
| P2-12 | 无音频焦点/后台播放/wakelock、无日志与错误上报 | 未修复 | `wakelock\|audio_session\|audio_service\|MediaSession\|SMTC` 在 app/lib 命中 0；`FlutterError\|runZonedGuarded\|Crashlytics\|Sentry\|developer.log` 命中 0；debugPrint 3 处 | 未做；与 P0-05/P0-06 的静默失败形成「问题不可见」闭环 |

---

## 1. 逐条详细记录（PLAN-001 ~ PLAN-044，顺序对应 P0-01~P2-12）

### [PLAN-001] [P0-01] 点播放永远无声：真播放已达成，系统媒体控制/EQ 接线未达成

- **编号**：PLAN-001
- **严重度**：P0
- **类别**：功能缺失 / 数据真实性
- **用户可见现象**：历史上点播放按钮变暂停、进度走动但扬声器无声、系统音量合成器看不到该应用。当前：点示例曲目应能真实出声（进度来自物理驱动流）。
- **复现步骤**：1. 启动客户端；2. 播放任意示例曲；3. 观察扬声器与进度；4. app/lib 检索 audioplayers/media_kit。
- **代码证据**：`app/lib/core/audio/player_backend.dart:22-71`（RealAudioPlayerBackend，:26 onPositionChanged 真流）；`audio_player_service.dart:282-298` _executeRealPlay 按 audioUrl→localPath→resume 分支真播；`track_model.dart:120/142/162/184/204/222` 六首带 soundhelix mp3。反证：`wakelock|audio_session|audio_service|MediaSession|SMTC` 在 app/lib 命中 0。
- **数据真实性**：内置 33 首全部指向 soundhelix.com 的 16 个演示 mp3（真实 HTTP 音频，但曲名/歌手为编造）；网易云在线曲 audioUrl=music.163.com/song/media/outer/url 实测 302→404（`online_music_service.dart:63/132`），该分支播放会失败并触发 :295 的诚实提示。
- **原型/文档依据**：`docs/SPEC.md:7` 已诚实标注「media_kit 未采用，实际用 audioplayers（真播放达成，系统媒体控制未达成）」；修复方案 1.1/1.2 要求 media_kit+audio_service、系统媒体控制、音频焦点、wakelock，均未落地。
- **建议修复**：补 audio_service/audio_session/wakelock_plus（或改用 media_kit），在 main 初始化系统媒体通道；在线曲目改用可播放直链或明确置灰。
- **可验收标准**：播放示例曲时系统媒体面板出现曲目并可控制；`app/lib` 内 audio_service|wakelock 命中 ≥1；`Timer.periodic` 仅剩睡眠定时器（`audio_player_service.dart:447`）。
- **状态**：部分修复（真播放与真实进度流已达成并代码级取证；系统媒体控制/音频焦点/wakelock 未实现）

### [PLAN-002] [P0-02] 零持久化：已由 shared_preferences 真实落盘

- **编号**：PLAN-002
- **严重度**：P0
- **类别**：工程卫生 / 数据真实性
- **用户可见现象**：历史上重启后主题/强调色/收藏/进度全部归零。当前应冷启动恢复。
- **复现步骤**：1. 改深色+强调色+红心 2 首+音量；2. 杀进程重启；3. 观察三项是否保持。
- **代码证据**：`core/storage/storage_service.dart:20-22 init()`、:32-40 键常量、:44-111 主题/音量/模式/收藏/历史读写、:139-148 导入歌单读写；`theme_provider.dart:24-49 _loadFromStorage`、:55-78 写入；`audio_player_service.dart:113-161 _loadFromStorage`。
- **数据真实性**：真实落盘：shared_preferences 键值写入；`main.dart:12 await StorageService.instance.init()` 在任何 Provider 构造前完成，无首帧闪烁。
- **原型/文档依据**：修复方案 2.1 要求 shared_preferences 起步 → drift 承接曲库；drift 部分未做（`drift` 在 app/lib 命中 0），但验收标准 1/2（设置与收藏重启保持）已满足。
- **建议修复**：若曲库规模增长，按 SPEC 第 8 章补 drift/SQLite。
- **可验收标准**：杀进程重启后主题/强调色/光晕/音量/播放模式/收藏/历史/导入歌单全部保持。
- **状态**：已修复（代码级取证；未做真机重启实验截图）

### [PLAN-003] [P0-03] 云端同步伪造成功：假成功链路已删除

- **编号**：PLAN-003
- **严重度**：P0
- **类别**：文案不诚实 / 数据造假
- **用户可见现象**：历史上点「从云端恢复」0.9s 后弹「已成功从 WebDAV 云端合并」但无任何网络请求。当前仅提示尚未接入。
- **复现步骤**：1. 进入多端协同与云端同步中心；2. 点立即云端备份 / 从云端恢复；3. 观察提示语。
- **代码证据**：`desktop_views.dart:1558-1570` 两个 trigger 仅 showSnackBar「尚未完整接入，请勿依赖此页面备份数据」/「云端恢复功能尚未完整接入」；:1554-1556 端点/账号=未配置；`Future.delayed` 在 app/lib 仅剩 lx_script_sandbox（死代码）4 处，无 900ms。
- **数据真实性**：无网络请求，且 UI 现在如实说明——不再是伪造成功。
- **原型/文档依据**：修复方案 0.2 要求删除 _triggerUpload/_triggerRestore 假实现并改文案：达成；但 `desktop_views.dart:1592` 仍写「支持 WebDAV 私有云盘实时双向热备，与局域网近场毫秒级 P2P 跨端流转」，属残留超额宣称。
- **建议修复**：删除或降级 :1592 的副标题；或将 WebDavSyncService 真正接线（阶段 4.1 A1）。
- **可验收标准**：app/lib 内 `Future.delayed(...900)` 命中 0（已满足）；同步中心文案不存在未落地能力的技术名词（:1592 未满足）。
- **状态**：已修复（假成功已消除）

### [PLAN-004] [P0-04] 局域网假设备与假端口：编造内容已删除，服务仍未接线

- **编号**：PLAN-004
- **严重度**：P0
- **类别**：数据造假 / 交互缺陷
- **用户可见现象**：历史上列出恒为在线的 iPhone 15 Pro / HomePod 与「本机端口 18585 监听中」。当前为空态。
- **复现步骤**：1. 进入同步中心；2. 观察局域网在线设备区。
- **代码证据**：`desktop_views.dart:1820-1838` 空态卡片「当前未发现局域网配对设备」；`18585` 在 app/lib 命中 0；`lan_sync_service.dart:411 class LanSyncService` 仅自引用，app/lib 无导入方。
- **数据真实性**：不再编造设备；但也没有任何真实设备发现逻辑（LanSyncService 未启动）。
- **原型/文档依据**：修复方案 0.2 要求删除两个假设备卡片与两个假成功按钮：已达成；阶段 4.1 要求接线或整页删除：未执行。
- **建议修复**：按阶段 4.1 二选一；同时修正 :1592 的 P2P 宣称。
- **可验收标准**：app/lib 内 `iPhone 15 Pro / HomePod / 18585` 命中 0（已满足）。
- **状态**：已修复（阶段 0「删假」目标达成）

### [PLAN-005] [P0-05] Android release INTERNET 权限：已补齐 5 项权限

- **编号**：PLAN-005
- **严重度**：P0
- **类别**：工程卫生
- **用户可见现象**：历史上 release APK 无 INTERNET，线上网络功能静默失效。
- **复现步骤**：1. 读 main/AndroidManifest.xml；2. 核对权限；3. （需 SDK）aapt dump permissions。
- **代码证据**：`app/android/app/src/main/AndroidManifest.xml:2-6` INTERNET / ACCESS_NETWORK_STATE / WAKE_LOCK / FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK。
- **数据真实性**：N/A（权限声明）。
- **原型/文档依据**：修复方案 0.3 动作 A 要求至少前两条，实际补齐 5 条（为阶段 1 后台播放预留）：达成。
- **建议修复**：无。若要防回归，可在 release.yml 增加 aapt 断言（未做）。
- **可验收标准**：`aapt dump permissions app-release.apk` 含 android.permission.INTERNET。
- **状态**：已修复（静态核对；未产出 APK）

### [PLAN-006] [P0-06] macOS network.client entitlement：已补齐并额外加 server

- **编号**：PLAN-006
- **严重度**：P0
- **类别**：工程卫生
- **用户可见现象**：历史上 release 版沙箱拒绝所有出网请求。
- **复现步骤**：1. 读 Release.entitlements；2. （需 macOS release）codesign -d --entitlements -。
- **代码证据**：`app/macos/Runner/Release.entitlements:5-10` app-sandbox + network.client + network.server 均 true；文件由 8 行增至 12 行。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 0.3 动作 B：达成。
- **建议修复**：无。
- **可验收标准**：codesign 输出含 com.apple.security.network.client。
- **状态**：已修复（静态核对；未做 release 签名核对）

### [PLAN-007] [P0-07] LX 音源空壳：UI 已诚实化，1836 行引擎仍生产不可达

- **编号**：PLAN-007
- **严重度**：P0
- **类别**：功能缺失 / 数据造假
- **用户可见现象**：历史上标题「自定义音源管理 (QuickJS)」+ 恒开且点不动的开关 + 无响应导入按钮 + 「v2.1.0 运行中」。当前页面只列内置网易云音源并标注「功能接入中」。
- **复现步骤**：1. 进入 LX 音源管理；2. 点在线导入音源；3. 观察仅 SnackBar 提示。
- **代码证据**：`desktop_views.dart:1498-1511`（标题改为「自定义音源管理」、按钮 onTap 弹「自定义音源在线导入功能接入中...」）、:1516-1538 仅一张内置音源卡；`QuickJS|v2.1.0` 在 app/lib 命中 0；`lx_script_sandbox.dart:727 class LxSourceEngine` 仅自引用（:735）无生产调用。
- **数据真实性**：无 JS 运行时（pubspec 无 flutter_js、app/lib 无 flutter_js）；沙箱内 `_mockDatabase`/`simulateFailure` 仍在。
- **原型/文档依据**：SPEC:8 已标注「flutter_js 未采用，core/sources 为纯 Dart 模拟且无生产调用」；修复方案 4.2 要求 B1 真跑或 B2 删除：均未执行。
- **建议修复**：执行阶段 4.2 二选一（推荐删除 core/sources 与相关测试，或标注未实现）。
- **可验收标准**：app/lib 内 LxSourceEngine 生产调用方为 0（当前是死代码）或 ≥1（真接线）；不允许悬空。
- **状态**：部分修复（阶段 0 UI 诚实化达成；阶段 4 决策未执行）

### [PLAN-008] [P0-08] 本地导入：假数据已删，真实现仍为零

- **编号**：PLAN-008
- **严重度**：P0
- **类别**：功能缺失
- **用户可见现象**：历史上点「选择本地文件夹扫描」无反应，列表 6 行全显示同一「FLAC 24bit/96kHz · 42.8 MB」。当前为诚实空态。
- **复现步骤**：1. 进入本地与下载；2. 点「本地扫描接入中」；3. 观察仅提示接入中。
- **代码证据**：`desktop_views.dart:1256-1280` RecessedWell 空态 + 按钮弹「本地文件与目录扫描功能正在接入中...」；:1282「本地曲库暂无内容」；42.8MB 文案在 app/lib 命中 0；`file_picker|file_selector|DragTarget|FilePicker` 在 app/lib 命中 0。
- **数据真实性**：无任何本地文件系统能力；无 dart:io 遍历（除死代码 lan_sync_service:3）。
- **原型/文档依据**：修复方案 0.2「删假」达成；2.4「真实现」要求 file_picker + desktop_drop + 元数据 + 入库：全部未做。
- **建议修复**：阶段 2.4：引入 file_picker/desktop_drop，扫描音频扩展名并读元数据入库。
- **可验收标准**：选含 3 mp3+1 flac 的目录后列表出现 4 条且格式/大小与磁盘一致。
- **状态**：部分修复（删假达成；真实现未做）

### [PLAN-009] [P0-09] 键盘交互：桌面端已真实绑定，缺验收测试

- **编号**：PLAN-009
- **严重度**：P0
- **类别**：交互缺陷
- **用户可见现象**：历史上 ESC/Ctrl+K 无反应。当前桌面端已绑定全局快捷键。
- **复现步骤**：1. 桌面窗口前台按 Ctrl+K 应弹搜索；2. 按 L 切全屏歌词、Q 开队列、ESC 退出；3. 空格播放/暂停。
- **代码证据**：`desktop_scaffold.dart:87-125` CallbackShortcuts 定义 Space(:89)、Ctrl+K(:91)、Cmd+K(:94)、←(:98)、→(:101)、↑(:105)、↓(:106)、M(:108)、L(:110)、Q(:114)、ESC(:118)；:127 CallbackShortcuts 包 Focus(autofocus: true)。
- **数据真实性**：N/A（交互）。
- **原型/文档依据**：修复方案 5.2 要求 8 组键位并新增 `app/test/shortcuts_test.dart`：键位已实现，测试文件不存在（`ls test | grep shortcut` 为空）；移动壳无快捷键。
- **建议修复**：补 `app/test/shortcuts_test.dart` 用 tester.sendKeyEvent 逐键断言；验证搜索框聚焦时空格不触发播放。
- **可验收标准**：`tester.sendKeyEvent` 断言各键状态变化；搜索框内输入空格不触发 togglePlay。
- **状态**：部分修复（代码级实现；无自动化测试与运行时验证）

### [PLAN-010] [P0-10] 能力文案与实现矛盾：UI 大头已清，代码层与副标题仍残留

- **编号**：PLAN-010
- **严重度**：P0
- **类别**：文案不诚实 / 与文档不符
- **用户可见现象**：历史上界面密集出现 libmpv/firequalizer/24bit 无损/服务就绪/18585/v2.1.0。当前这些 UI 文案已消失。
- **复现步骤**：1. app/lib 全文检索技术名词；2. 打开同步中心与导入页看副标题。
- **代码证据**：命中 0：`24bit/192kHz|24bit/96kHz|已缓存 6 首|服务就绪|18585|已同步红心收藏|v2.1.0`；命中仍在：`equalizer_manager.dart:81/84`（注释+代码 libmpv firequalizer）、`desktop_views.dart:1592`（实时双向热备/毫秒级 P2P）、:1054（支持网易云、QQ音乐分享链接）。
- **数据真实性**：EQ 滤镜字符串无生产消费方；QQ 音乐无任何代码分支。
- **原型/文档依据**：修复方案阶段 0 验收标准 1 要求 `app/lib` 内 libmpv/firequalizer 命中 0（未达标）；原则 2「未落地能力禁止出现技术名词」仍被 :1592/:1054 违反。
- **建议修复**：删除 equalizer_manager 的 libmpv 命名（改名或标注未接线）；改写 :1592 与 :1054。
- **可验收标准**：app/lib 内 `libmpv|firequalizer|QuickJS` 命中 0；页面文案逐条能对应到一行真实代码。
- **状态**：部分修复

### [PLAN-011] [P0-11] 移动壳假状态栏：假时钟已删，Mobile 角标仍在

- **编号**：PLAN-011
- **严重度**：P0
- **类别**：视觉缺陷 / 交付边界失守
- **用户可见现象**：历史上窗口 <1024px 出现恒为 10:09 的假 iOS 状态栏与「Mobile」调试角标。当前灵动岛改为显示真实曲目标题与播放态。
- **复现步骤**：1. 把窗口缩到 <1024px；2. 观察顶部胶囊内容；3. 看「发现音乐」标题旁角标。
- **代码证据**：`mobile_scaffold.dart:93-160` 灵动岛显示 track.title(:136) 与 player.isPlaying 图标(:149)；`10:09|Wifi|battery` 在该文件命中 0；残留：`mobile_tabs.dart:82-89 const Text('Mobile', ...)`；灵动岛仍在 SafeArea 内（:58）。
- **数据真实性**：不再有编造时间/电量；标题来自 player.currentTrack（真实状态）。
- **原型/文档依据**：修复方案 0.2 要求删除假时钟/假图标、把灵动岛移出 SafeArea 并改名「迷你播放胶囊」、删除 `mobile_prototype_1to1_test.dart` 的 10:09 断言。前两项部分达成，改名与移出未做。
- **建议修复**：删除 Mobile 角标；灵动岛移出 SafeArea 并改名。
- **可验收标准**：app/lib 内 `'Mobile'` 常量角标命中 0；移动端测试不再断言假状态栏。
- **状态**：部分修复

### [PLAN-012] [P0-12] server.cjs 安全加固：本轮实测全部通过

- **编号**：PLAN-012
- **严重度**：P0
- **类别**：工程卫生（安全）
- **用户可见现象**：历史上 `node server.js` 直接崩溃；单条畸形请求可打死服务；可读取工程根目录外文件；监听 0.0.0.0 且 CORS 通配。
- **复现步骤**：1. node server.cjs；2. 发 6 条畸形/Range payload；3. 请求 /../package.json、/.git/config；4. 检查进程存活与响应头。
- **代码证据**：`server.cjs:35-59 safeResolve`（空字节/..%2e/反斜杠拒绝、PUBLIC_DIR 前缀校验、DENY 黑名单）；:84-89 decodeURIComponent 异常→400；:145-148 Range 非法→416；:167 uncaughtException 兜底；:169 默认 127.0.0.1；`package.json:6 main=server.cjs`、:8 start=node server.cjs。本轮实测：`/%ZZ`→400、`/%00.html|/..%5c…|/%2e%2e/…|/.git/config|/node_modules/…|/../package.json|/docs/SPEC.md|/app/pubspec.yaml`→全 403、Range `bytes=abc-`→200、`bytes=-500`→206、`bytes=100-50|bytes=99999999-`→416、`bytes=0-9,20-29`→200、POST→405、无 access-control-allow-origin、payload 后 GET /index.html→200 且进程存活。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 0.1 验收标准 1-4 全部满足；标准 5（README 快速启动）npm start 已指向可运行的 server.cjs。残留：`.gitignore` 未加入 `public/audio/` 与 `.qa/`（见 PLAN-062）。
- **建议修复**：补 .gitignore 两项。
- **可验收标准**：上述 payload 序列后进程仍存活且穿越请求返回 403。
- **状态**：已修复（本轮实测证据）

### [PLAN-013] [P1-01] 四榜单同源：曲目池已独立，静态更新承诺仍在

- **编号**：PLAN-013
- **严重度**：P1
- **类别**：数据造假
- **用户可见现象**：历史上四榜 Top5 几乎相同且都写「每日09:00更新·100首」。
- **复现步骤**：1. 进入巅峰榜单；2. 对比四榜曲目与更新文案。
- **代码证据**：`track_model.dart:525 toplistSurgeTracks / :579 toplistHotTracks / :604 toplistNewTracks / :657 toplistOriginTracks`（各 5 首，ID 集合不同）；:728 toplistTracksMap；:736 getAllToplistTracks 去重；`desktop_views.dart:493` 按 chartTitle 取独立列表。
- **数据真实性**：四榜仍为内置示例曲（含编造曲目如 chart-surge-3 乌梅子酱），但集合已互不相同；`desktop_views.dart:418/426/434/442` 的 update 文案仍是静态字符串，全仓无任何定时任务。
- **原型/文档依据**：修复方案 3.1 要求删除静态更新文案或改为「更新时间未知」：未做；要求四榜 trackId 集合互不相同：已满足。
- **建议修复**：删除/改写 update 文案；接入真实榜单或改空态。
- **可验收标准**：四榜 trackId 集合互不相同（已满足）；文案中的数字来自返回体或不存在（未满足）。
- **状态**：部分修复

### [PLAN-014] [P1-02] 歌手数据：头像/代表作已差异化，粉丝数与默认关注仍假

- **编号**：PLAN-014
- **严重度**：P1
- **类别**：数据造假
- **用户可见现象**：历史上 4 位歌手共用一张头像、详情页简介与代表作完全相同、默认已关注。
- **复现步骤**：1. 进入热门歌手；2. 依次点进 4 位；3. 对比头像/简介/代表作；4. 看关注按钮初始态。
- **代码证据**：`track_model.dart:473-506` 4 位歌手各自 avatarUrl、fans、bio、tracks；:509-521 getArtistProfileByName；`desktop_views.dart:739-845` 详情页读 artist 档案与 artist.tracks。残留：:733 `bool _isFollowing = true;`、:705 与 :781 无条件 verified 蓝勾、fans 数字全为编造。
- **数据真实性**：头像来自 Unsplash 随机人像，与艺人无对应关系；tracks 为内置示例曲。
- **原型/文档依据**：修复方案 3.2 要求默认 false + 持久化、移除无条件蓝勾、真实头像否则占位：均未做。
- **建议修复**：默认未关注并接持久化；删除无条件认证勾；无真实头像用首字占位。
- **可验收标准**：首次安装关注按钮为「关注」态且重启保持；3 位歌手详情曲目列表互不相同（已满足）。
- **状态**：部分修复

### [PLAN-015] [P1-03] 歌单广场：已从单曲改为真歌单，播放量与封面复用仍在

- **编号**：PLAN-015
- **严重度**：P1
- **类别**：数据造假 / 视觉缺陷
- **用户可见现象**：历史上卡片展示的是单曲、播放量编造、同一张 Unsplash 图跨 10 处复用、分类标签不过滤。
- **复现步骤**：1. 进入歌单广场；2. 切换分类标签观察列表变化；3. 看播放量；4. 跨页比对封面。
- **代码证据**：`track_model.dart:866-884 class SquarePlaylist`（含 tracks）；:887-958 七个歌单；:961-966 getPlaylistsByTag；`desktop_views.dart:293 playlists = getPlaylistsByTag(_activeTag)`、:309-320 标签真实过滤、:324-398 卡片渲染 pl.coverUrl/pl.playCount/pl.tracks。
- **数据真实性**：歌单实体与曲目列表已真实（内置示例），播放量仍硬编码（:894/903/912/921/930/939/951）；封面 Unsplash URL 仍在多处复用（photo-1518709268805 同时用于 discover hero :116、sq-pl-3 :911、radio-1 :774、chart-orig-5 :714）。
- **原型/文档依据**：修复方案 3.3 要求删除手写播放量、封面去重、点击进入歌单详情：均未做；「实为单曲」已修。
- **建议修复**：删除或接入真实 playCount；建封面映射表 + 缺图占位；增加歌单详情页。
- **可验收标准**：任一点开的歌单能看到完整曲目（已满足）；同一 Unsplash URL 出现次数 ≤ 2（未满足）。
- **状态**：部分修复

### [PLAN-016] [P1-04] 播放历史：冷启动假数据已删、清空已有，单条移除仍缺

- **编号**：PLAN-016
- **严重度**：P1
- **类别**：功能缺失 / 数据造假
- **用户可见现象**：历史上冷启动即显示「最近 1 首云水禅心」且无移除/清空。
- **复现步骤**：1. 冷启动进入播放足迹；2. 看是否为空；3. 找清空与单条移除入口。
- **代码证据**：`audio_player_service.dart:107-111` 构造函数仅 _loadFromStorage + _initAudioListeners，无 _recordHistory；:389-393 clearPlayHistory；`desktop_views.dart:1184-1196` 「清空足迹」按钮；:1200-1214 空态；:1216-1236 列表项无删除按钮。
- **数据真实性**：历史来自真实播放记录并落盘（`_recordHistory` :468-475 → savePlayHistory）。
- **原型/文档依据**：SPEC:127 声称「支持单曲移除与一键清空」：一键清空已修，单条移除缺失。修复方案 2.2 第 5 点要求 removeHistoryItem：未做。
- **建议修复**：在历史列表项加滑动删除/✕，并在 service 加 removeHistoryItem。
- **可验收标准**：历史页可删除单条、可一键清空，重启后状态保持。
- **状态**：部分修复

### [PLAN-017] [P1-05] 预置收藏 4 首：仍硬编码，首次安装即虚高

- **编号**：PLAN-017
- **严重度**：P1
- **类别**：数据造假
- **用户可见现象**：用户从未收藏，首次进入「我喜欢的音乐」即显示 4 首。
- **复现步骤**：1. 全新用户目录冷启动；2. 进入我喜欢的音乐。
- **代码证据**：`audio_player_service.dart:29 final Set<String> _favoriteIds = {'track-1','track-3','track-5','track-6'};`；`track_model.dart:121/163/205/223 isFavorite: true`。注意 :136-140 仅在存在已保存值时覆盖，首次安装保留硬编码 4 首。
- **数据真实性**：伪造用户个人数据；`desktop_views.dart:954` 文案已由「实时云端同步」改为「本地安全持久化存储」。
- **原型/文档依据**：修复方案 2.2 第 1/3 点明确要求改为空集合并删除模型层 isFavorite: true：均未做。
- **建议修复**：`_favoriteIds` 初始化为空；删除模型层 4 处 isFavorite: true。
- **可验收标准**：首次安装收藏 0 首、历史为空，重启后仍为 0。
- **状态**：未修复

### [PLAN-018] [P1-06] 设置中心：3→4 张卡片，仍缺音质/缓存/关于

- **编号**：PLAN-018
- **严重度**：P1
- **类别**：功能缺失
- **用户可见现象**：历史上设置页只有外观/强调色/光晕 3 项。
- **复现步骤**：1. 进入个性化与系统设置；2. 清点卡片；3. 找音质与缓存清理入口。
- **代码证据**：`desktop_views.dart:1305-1335` 外观、:1339-1379 强调色、:1383-1404 光晕、:1408-1444 桌面快捷键指南（新增）。`package_info_plus` 在 app/lib 命中 0。
- **数据真实性**：N/A。
- **原型/文档依据**：SPEC:129/143 要求音源管理与音质首选项、离线缓存清理：均缺。修复方案 2.5 要求卡片数 ≥6：当前 4。
- **建议修复**：补音质首选项、缓存目录与清理、关于（版本）。
- **可验收标准**：设置页卡片数 ≥6；「清理缓存」显示占用与磁盘实际一致（±1MB）。
- **状态**：部分修复

### [PLAN-019] [P1-07] 搜索面板：初始 mock、ESC 文案、失败静默三项全未修

- **编号**：PLAN-019
- **严重度**：P1
- **类别**：交互缺陷 / 数据造假
- **用户可见现象**：未输入关键词即列出 6 首本地曲目；hint 写「按 ESC 退出」；断网搜索无失败提示。
- **复现步骤**：1. 点顶栏搜索；2. 观察初始列表；3. 断网输入关键词，观察提示。
- **代码证据**：`modals.dart:511 _results = mockPresetTracks;`、:528 清空后同样回落 mock；:547-564 350ms 防抖真联网，:552 `if (onlineSongs.isNotEmpty)` 无 else；:598 hintText 仍含「按 ESC 退出」；:670「无匹配结果，支持任意关键词搜索全网」无法区分网络异常；`online_music_service.dart:80 catch (_) {}`、:157、:182 静默。
- **数据真实性**：搜索本身真实联网（网易云私有接口）；初始结果是本地 mock；失败时不造假但也不提示。
- **原型/文档依据**：修复方案 3.4 要求初始改空态、hint 改「点击关闭」、新增 AppFailure 区分错误、AppLogger、runZonedGuarded：`app/lib/core/error/` 不存在、`runZonedGuarded` 命中 0，全部未做。
- **建议修复**：初始空态；:552 补 else 显示网络异常；hint 改文案。
- **可验收标准**：断网搜索显示「网络异常」而非「无匹配结果」；app/lib 内 `catch (_)` 命中 0。
- **状态**：未修复

### [PLAN-020] [P1-08] 声音电台：每台已绑定专属曲目，仍无单集模型

- **编号**：PLAN-020
- **严重度**：P1
- **类别**：数据造假 / 功能缺失
- **用户可见现象**：历史上点「助眠白噪音与雨声」会播放无关的 mock 歌曲。
- **复现步骤**：1. 进入声音电台；2. 点任一卡片；3. 看播放队列曲名。
- **代码证据**：`track_model.dart:750-766 class RadioStation{… Track track}`；:769-863 四个电台各带专属 track；`desktop_views.dart:882 player.playTrack(r.track)`。
- **数据真实性**：每台曲目标题与卡片主题一致，audioUrl 指向 soundhelix 演示 mp3（非真实播客音源）；listeners（:775/:799/:822/:845）为编造。
- **原型/文档依据**：修复方案 3.5 要求引入 PodcastEpisode 模型：未做，仍是单曲绑定。
- **建议修复**：引入单集模型与单集列表；无数据源时整页空态。
- **可验收标准**：点击任意电台单集，播放队列标题/时长与卡片一致（部分满足）。
- **状态**：部分修复

### [PLAN-021] [P1-09] EQ：无 DSP 链路、预设行仍横向滚动、预设数三处口径

- **编号**：PLAN-021
- **严重度**：P1
- **类别**：功能缺失 / 与文档不符
- **用户可见现象**：拖动 EQ 滑块听感无变化；1440px 下第 5 个预设需横向滚动。
- **复现步骤**：1. 打开 EQ 弹窗；2. 观察预设行右端；3. 拖动滑块听是否有变化。
- **代码证据**：`equalizer_manager.dart:82-92 toLibmpvFilterString()` 在 app/lib 无生产调用；`modals.dart:233-249` 预设行仍是 SingleChildScrollView(scrollDirection: horizontal)，未改 Wrap；:236 遍历 6 个 EqualizerPreset。
- **数据真实性**：EQ 参数只写内存 List<double>（:32），无任何音频副作用。
- **原型/文档依据**：SPEC:451 要求 9 款预设 + libmpv firequalizer 实时生效；README:90 称「5 大滤波预设」；实际 6（`equalizer_manager.dart:4-14`）：三处口径不一致。修复方案 1.3 二选一未执行。
- **建议修复**：选 A 接真实滤镜或选 B 明确标注不影响声音；预设行改 Wrap；统一预设数口径。
- **可验收标准**：toLibmpvFilterString 生产调用方 ≥1 或 UI 明确标注无效；1440×900 下 6 个预设全部可见。
- **状态**：未修复

### [PLAN-022] [P1-10] 窗口最小尺寸：未做

- **编号**：PLAN-022
- **严重度**：P1
- **类别**：交互缺陷
- **用户可见现象**：窗口可拖到任意小，<1024px 退化为移动壳，极小尺寸布局重叠。
- **复现步骤**：1. 拖动窗口到 430×860 / 220×200；2. 观察布局。
- **代码证据**：`window_manager|WM_GETMINMAXINFO|setMinimumSize|minimumSize` 在 `app/lib` 与 `app/windows` 全仓 0 命中；`app/windows/runner/main.cpp:29 Win32Window::Size size(1280, 720)`；`adaptive_scaffold.dart:14` 断点 1024。
- **数据真实性**：N/A。
- **原型/文档依据**：SPEC:115 断点 1024 与 SPEC:454 的 800 自相矛盾；修复方案 5.3 未执行。
- **建议修复**：引入 window_manager 设 minimumSize(1024,640)；同步 main.cpp 默认尺寸 1440×900。
- **可验收标准**：窗口拖到最小停在 1024×640 且布局不破。
- **状态**：未修复

### [PLAN-023] [P1-11] 品牌化：仅 Android 完成，其余五端仍 app/mellow_music

- **编号**：PLAN-023
- **严重度**：P1
- **类别**：与文档不符 / 视觉缺陷
- **用户可见现象**：Windows 原生标题栏为「app」，产物 app.exe；macOS 产物 app.app；Web manifest 仍是 Flutter 模板。
- **复现步骤**：1. 读各平台配置文件；2. 构建后看产物名与窗口标题。
- **代码证据**：已改：`AndroidManifest.xml:9 android:label="Mellow Music"`。未改：`app/windows/CMakeLists.txt:4 project(app)`、`:9 set(BINARY_NAME "app")`、`app/windows/runner/main.cpp:30 window.Create(L"app", ...)`、`app/windows/runner/Runner.rc:93/95/97/98` 全为 app、:96 Copyright (C) 2026；`app/macos/Runner/Configs/AppInfo.xcconfig:8 PRODUCT_NAME = app`、:14 Copyright © 2026；`app/web/manifest.json:2-3 mellow_music`、:6-7 #0175C2、:8 A new Flutter project.；`app/ios/Runner/Info.plist:10 App`、:18 app；`app/linux/runner/my_application.cc:52 mellow_music`。
- **数据真实性**：N/A。
- **原型/文档依据**：SPEC:467/439 称产物 mellow_music.exe。修复方案 7.1 表格 14 项仅 1 项达成。
- **建议修复**：按 7.1 表逐项替换；注意 BINARY_NAME 变更会改产物路径。
- **可验收标准**：Windows 属性面板显示 mellow_music.exe、窗口标题 Mellow Music；六端图标非默认蓝。
- **状态**：部分修复

### [PLAN-024] [P1-12] release.yml macOS 打包：已改动态查找

- **编号**：PLAN-024
- **严重度**：P1
- **类别**：工程卫生
- **用户可见现象**：历史上 ditto 打包不存在的 mellow_music.app，发版流水线必失败。
- **复现步骤**：1. 读 release.yml 打包步骤；2. 核对真实 .app 名。
- **代码证据**：`.github/workflows/release.yml:80-84` `APP_PATH=$(find app/build/macos/Build/Products/Release -maxdepth 1 -name "*.app" | head -n1)` + `test -n "$APP_PATH" || exit 1` + ditto；job 名 :56 仍「Build macOS Universal」，:57 macos-14，:78 flutter build macos --release（无 universal）。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 0.4 推荐修法：已按推荐落地。残留：Universal 命名未改。
- **建议修复**：把 job 改名 Build macOS (arm64) 或补 universal 参数。
- **可验收标准**：推测试 tag 后 6 job 全绿、Release 页 5 附件齐全（未在 CI 实跑）。
- **状态**：已修复（打包步骤代码级；CI 未实跑）

### [PLAN-025] [P1-13] 质量门禁：Flutter 版本未固定、E2E 零断言、83 项不入 CI

- **编号**：PLAN-025
- **严重度**：P1
- **类别**：工程卫生 / 文案不诚实
- **用户可见现象**：CI 绿灯不反映功能正确性；README 83/83 徽章无门禁保护。
- **复现步骤**：1. 读 ci.yml/release.yml；2. 读 flutter_e2e_verify.mjs；3. 全 workflow 检索 e2e_test.js。
- **代码证据**：`ci.yml:20` 与 `:60`、`release.yml:26/65/110/154/188` 均 `channel: 'stable'` 无 flutter-version；无 .fvmrc/.tool-versions；`ci.yml:29 run: flutter analyze`（无 --fatal-infos）；:33 flutter test（无 integration_test）；:48 node flutter_e2e_verify.mjs；全 workflow `e2e_test.js` 命中 0。`flutter_e2e_verify.mjs:126/181 catch (_) {}`、:137/145/153/161/187 无条件 `console.log('✅ [PASS] …')`、:141/149/157 硬编码坐标、:199-204 仅在抛异常时 exit 1、:201 打印「100% 通过」；:114/170 的 desktopErrors/mobileErrors 收集后从未断言。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 6.1/6.2 全部要求未落地；README:35 仍以 83/83 静态徽章为质量证据。
- **建议修复**：重写 flutter_e2e_verify.mjs 为真断言；固定 flutter-version；CI 纳入 integration_test 与 e2e_test.js。
- **可验收标准**：不 build web 直接跑脚本退出码 1；改坏侧边栏文案对应断言变红。
- **状态**：未修复

### [PLAN-026] [P1-14] 测试卫生：条件断言已清，重复文件与 mock 断言仍在，计数口径不符

- **编号**：PLAN-026
- **严重度**：P1
- **类别**：工程卫生 / 与文档不符
- **用户可见现象**：两个测试文件逐行相同；文档 47/90 与实际 98 不符。
- **复现步骤**：1. 对测试文件做 MD5 去重；2. 统计 test(/testWidgets(；3. grep 条件断言。
- **代码证据**：`app/test/client_e2e_user_journey_test.dart` 与 `app/integration_test/app_client_e2e_test.dart` 各 285 行、MD5 均 9c6ce41ed07d4ed42f754a2b4a909698（仍重复）。`if (find` 在 app/test 与 app/integration_test 命中 0（已清理）。全量：`test(` 52 + `testWidgets(` 46 = 98，共 14 个 `*_test.dart`（含 integration 8）。`lx_source_engine_test.dart` 25 用例仍以 mock 为判据。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 6.3 要求删除重复文件、修正命名误导、更新 PROGRESS 数字：重复文件未删。README:33/127 与 PROGRESS.md:15/91 称 90/90（= 98-8 integration），口径与 98 不一致且未声明范围。
- **建议修复**：删除 test/ 下重复副本；把 mock 断言改为对注入 http.Client 的请求/响应断言；文档写清执行范围。
- **可验收标准**：仓库内无内容相同的两个测试文件；`if (find` 命中 0（已满足）；文档数字与实际执行数一致。
- **状态**：部分修复

### [PLAN-027] [P1-15] 依赖与字体：7 个僵尸依赖仍在，fonts 配置仍缺

- **编号**：PLAN-027
- **严重度**：P1
- **类别**：工程卫生
- **用户可见现象**：11→12 个依赖中多数不参与业务；字体 PingFang SC 在 Windows 不存在。
- **复现步骤**：1. 逐个依赖在 app/lib 检索；2. 读 main.dart fontFamily 与 pubspec fonts。
- **代码证据**：`pubspec.yaml:36-47`：cupertino_icons/google_fonts/provider/go_router/intl/shared_preferences/http/dio/crypto/path_provider/path/audioplayers。app/lib 引用计数：google_fonts 0、go_router 0、intl 0、dio 0、path_provider 0、package:path 0、cupertino_icons 0、crypto 1（死代码）、http 3、shared_preferences 1、audioplayers 1。`pubspec.yaml:66-102` 无 fonts: 段（全注释）；`main.dart:44/54 fontFamily: 'PingFang SC'`。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 6.4 要求删除未用依赖并配置随包字体：未做。
- **建议修复**：删除 7 个僵尸依赖；引入 NotoSansSC 或改系统字体；main.dart 同步。
- **可验收标准**：pubspec dependencies 每项都能在 app/lib 找到 import；Windows 产物中文字体与设计稿一致。
- **状态**：未修复

### [PLAN-028] [P1-16] 20Hz 全树 rebuild：进度仍驱动全局 notifyListeners

- **编号**：PLAN-028
- **严重度**：P1
- **类别**：手感(性能)
- **用户可见现象**：播放期间界面高频重绘。
- **复现步骤**：1. 播放并观察 GPU/CPU；2. 读 position 回调与 scaffold watch。
- **代码证据**：`audio_player_service.dart:164-167` `_positionSub = _backend.onPositionChanged.listen((p) { _position = p; notifyListeners(); });`；`desktop_scaffold.dart:79 final player = context.watch<AudioPlayerService>();`（build 顶层）。无 positionNotifier/ValueListenableBuilder。
- **数据真实性**：进度来自真实流（audioplayers onPositionChanged），但通知粒度仍是整树。
- **原型/文档依据**：SPEC:183 声称「直接订阅 player.stream.position」只驱动叶子；修复方案 1.4 未执行。
- **建议修复**：新增 ValueNotifier<Duration> positionNotifier 并节流 4Hz；进度条/歌词改 ValueListenableBuilder；scaffold 改 context.read。
- **可验收标准**：DevTools 录制 10s，_DesktopScaffoldState.build 调用 ≤5 次、帧率 ≥55fps。
- **状态**：未修复

### [PLAN-029] [P1-17] 路由：前进/后退已真实，go_router 与 PageStorageKey 仍缺

- **编号**：PLAN-029
- **严重度**：P1
- **类别**：交互缺陷 / 与文档不符
- **用户可见现象**：历史上后退永远跳 discover、前进是死按钮。当前前进/后退按浏览顺序工作。
- **复现步骤**：1. 发现→榜单→歌手详情→后退；2. 前进；3. 列表滚动后切页再返回看滚动位置。
- **代码证据**：`desktop_scaffold.dart:33-36 _history` 栈、:38-52 _navigateTo、:54-63 _goBack、:65-74 _goForward。`GoRouter|GoRoute|PageStorageKey|context.go(|context.push(` 在 app/lib 命中 0。
- **数据真实性**：N/A。
- **原型/文档依据**：SPEC:115 声称强类型 go_router + PageStorageKey；修复方案 5.1 要求 go_router StatefulShellRoute：未做（用自建栈替代）。
- **建议修复**：迁移 go_router（可保留 onNavigate 适配层）；列表加 PageStorageKey。
- **可验收标准**：发现→榜单→歌手详情→后退回到榜单；榜单滚到中部切页返回位置保持。
- **状态**：部分修复

### [PLAN-030] [P1-18] 可访问性：0 Semantics

- **编号**：PLAN-030
- **严重度**：P1
- **类别**：视觉缺陷 / 工程卫生
- **用户可见现象**：讲述人/NVDA 读不出任何控件。
- **复现步骤**：1. 启动讲述人；2. Tab/方向键浏览。
- **代码证据**：`Semantics|semanticLabel|ExcludeSemantics` 在 app/lib 命中 0；`desktop_scaffold.dart:225-240` 强调色圆点与 :162-193 搜索条等仍是裸 GestureDetector。
- **数据真实性**：N/A。
- **原型/文档依据**：SPEC/README 未提及可访问性；修复方案 5.6 未执行。
- **建议修复**：为 IconButton/GestureDetector 加 tooltip 或 Semantics；裸 GestureDetector 换 InkWell/IconButton。
- **可验收标准**：widget 测试通过 labeledTapTargetGuideline 与 textContrastGuideline。
- **状态**：未修复

### [PLAN-031] [P1-19] 第三方私有接口：明文账号已删，私有接口与失效直链未治理

- **编号**：PLAN-031
- **严重度**：P1
- **类别**：工程卫生 / 数据真实性
- **用户可见现象**：在线能力依赖未鉴权私有接口并伪造 UA/Referer；音频直链 302→404；页面称支持 QQ 音乐但无分支。
- **复现步骤**：1. 读 online_music_service.dart；2. 裸测音频直链；3. 看导入页副标题。
- **代码证据**：`online_music_service.dart:35 music.163.com/api/search/get/web`、:103 /api/playlist/detail、:168 /api/song/lyric；:37-40/104-107/170-173 伪造 UA/Referer；:63/132 audioUrl=music.163.com/song/media/outer/url；:80/157/182 catch(_)。明文账号已删（`desktop_views.dart:1556 _username = '未绑定账号'`）；:1054 仍称支持 QQ 音乐。
- **数据真实性**：搜索/歌单/歌词三条链路真实联网，但使用非公开接口；播放直链失效（基线实测 302→404）。
- **原型/文档依据**：修复方案 3.6 要求可插拔 Provider 与直链治理：未做。
- **建议修复**：可插拔 Provider 抽象；直链改为可播放源或明确标注；修正「支持 QQ」文案。
- **可验收标准**：app/lib 无明文邮箱/密码；切换 Provider 不需改 views/；Web 构建下搜索明确提示不支持。
- **状态**：部分修复

### [PLAN-032] [P1-20] 工程卫生：版本已单一来源，死代码/超大文件/鸿蒙/错误上报未修

- **编号**：PLAN-032
- **严重度**：P1
- **类别**：工程卫生
- **用户可见现象**：desktop_views.dart 1845 行含 14 视图；core/sync 与 core/sources 死代码；鸿蒙仅 README；无错误上报。
- **复现步骤**：1. 统计文件行数与 import；2. 列 harmonyos；3. 检索 FlutterError/runZonedGuarded。
- **代码证据**：`desktop_views.dart` 1845 行；死代码：lx_script_sandbox 1227 + lx_source_model 648 + sync_data_model 587 + lan_sync_service 513 + webdav_sync_service 410；`find app/harmonyos -type f` → 仅 README.md；`FlutterError|runZonedGuarded|ErrorWidget|Crashlytics|Sentry|developer.log` 命中 0（仅 debugPrint 3 处：player_backend:166、audio_player_service:294、webdav_sync_service:391）。版本单一来源已建立：`README.md:3`、`PROGRESS.md:3`、`SPEC.md:20` 均指向 pubspec version。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 6.5 要求 package_info_plus 读版本（命中 0）、Sentry/Crashlytics（未做）、开 strict（`analysis_options.yaml:12-20` 仍 exclude 6 平台且 :33-35 rules 全注释）。
- **建议修复**：拆分 desktop_views；删除或接线死代码；补错误上报；开 strict-casts。
- **可验收标准**：`flutter analyze --fatal-infos` 0 issue；未捕获异常能在上报后台看到。
- **状态**：部分修复（仅版本口径统一达成）

### [PLAN-033] [P2-01] 列表一次性构建：21 处 ListView( 未改 builder

- **编号**：PLAN-033
- **严重度**：P2
- **类别**：手感(性能)
- **用户可见现象**：长列表首帧随长度线性增长。
- **复现步骤**：1. app/lib grep ListView(；2. 观察 Grid 是否 shrinkWrap。
- **代码证据**：`ListView(` 共 21 处：desktop_views.dart:23/295/449/675/741/862/924/1043/1170/1251/1298/1489/1581；mobile_pages.dart:36/523/630；mobile_tabs.dart:24/785/859/950；desktop_scaffold.dart:417。Grid 多为 `shrinkWrap: true` + `NeverScrollableScrollPhysics`（如 desktop_views.dart:146-147/326-327/480-481/681-682）。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 5.5 要求 CustomScrollView+SliverList/SliverGrid：未做。
- **建议修复**：主列表改 ListView.builder / Sliver 化。
- **可验收标准**：导入 3000 首后滚动帧率 ≥50fps、内存不随滚动持续增长。
- **状态**：未修复

### [PLAN-034] [P2-02] 歌词翻译不渲染、EQ 预设数口径不一

- **编号**：PLAN-034
- **严重度**：P2
- **类别**：功能缺失 / 与文档不符
- **用户可见现象**：双语歌词只显示原文。
- **复现步骤**：1. 播放带翻译歌词的曲目；2. 观察歌词区。
- **代码证据**：`translation` 在 `app/lib/views` 命中 0；`fullscreen_lyrics_view.dart` 无 .translation 读取；`equalizer_manager.dart:4-14` 6 个预设。
- **数据真实性**：`track_model.dart` 保留 translation 字段但无消费方。
- **原型/文档依据**：SPEC:451 称 9 款预设、README:90 称 5 大、实际 6：矛盾。
- **建议修复**：歌词行 Column 中渲染 translation；统一预设数口径。
- **可验收标准**：双语歌词显示两行；预设数与文档一致。
- **状态**：未修复

### [PLAN-035] [P2-03] 双标题栏：无无边框配置

- **编号**：PLAN-035
- **严重度**：P2
- **类别**：视觉缺陷 / 交互缺陷
- **用户可见现象**：窗口顶部同时有系统标题栏（app）与自绘标题栏，自绘栏无最小化/最大化/关闭。
- **复现步骤**：1. 启动 Windows 产物；2. 观察两层标题栏与按钮。
- **代码证据**：`app/windows/runner/win32_window.cpp` 仍 WS_OVERLAPPEDWINDOW（无 WM_NCCALCSIZE）；`window_manager|setAsFrameless|TitleBarStyle` 在 app/lib 与 windows 命中 0；自绘标题栏 `desktop_scaffold.dart:143 _buildTitleBar`。
- **数据真实性**：N/A。
- **原型/文档依据**：README:54 与 SPEC:447 声称无边框拟物标题栏。修复方案 5.4 未执行。
- **建议修复**：window_manager.setAsFrameless + DragToMoveArea + 三窗口按钮。
- **可验收标准**：Windows 上只有一个标题栏，拖动空白区可移动窗口。
- **状态**：未修复

### [PLAN-036] [P2-04] 播放状态机边界：三处均未修

- **编号**：PLAN-036
- **严重度**：P2
- **类别**：交互缺陷
- **用户可见现象**：删除正在播放曲目后进度不归零；暂停下点下一首仍写历史。
- **复现步骤**：1. 播放至 0:11 删当前曲；2. 暂停后点下一首看历史。
- **代码证据**：`audio_player_service.dart:300-314 next()` 无 singleLoop 短路，:309 无条件 _recordHistory；:316-334 previous() 同样 :329；:423-431 removeTrackAt 仅夹取 _currentIndex，不重置 _position；:433-438 clearQueue 内部调用 pause()（:260-264 会 notifyListeners）造成二次通知。正面：:336-347 seek 有 [0,duration] 夹取；:188-200 播完单曲循环分支正确。
- **数据真实性**：历史被未播放曲目污染。
- **原型/文档依据**：修复方案 1.5 要求 singleLoop 短路、环形随机队列、_setPausedWithoutNotify：均未做。
- **建议修复**：next() 首行加 singleLoop 短路；removeTrackAt 重置进度；clearQueue 用无通知内部方法。
- **可验收标准**：单曲循环下按下一首进度归零且曲目不变；clearQueue 后单帧 notifyListeners 计数=1。
- **状态**：未修复

### [PLAN-037] [P2-05] 设计 Token 双端不一致

- **编号**：PLAN-037
- **严重度**：P2
- **类别**：与文档不符 / 视觉缺陷
- **用户可见现象**：同名 token 双端取值不同；Flutter 端无内白高光。
- **复现步骤**：1. 对照 design_tokens.css 与 tokens.dart 同名值。
- **代码证据**：`design_tokens.css:20 --soft-bg-recessed: #E8EEF5` vs `tokens.dart:26 recessedLight = Color(0xFFEBF0F8)`；`design_tokens.css:24 --soft-text-main: #1E293B` vs `tokens.dart:29 textPrimaryLight = Color(0xFF0F172A)`；圆角：css :151-156（pill/window28/card-lg24/card-md18/card-sm12/btn14）vs `tokens.dart:58-65`（8/12/16/20/24/28/32/pill）不重合；`convex|pressed|inset` 在 tokens.dart 命中 0。
- **数据真实性**：N/A。
- **原型/文档依据**：README:70 与 SPEC:71 将 token 作为设计规范。修复方案 3.7 要求单一事实源 + CI 校验：未做。
- **建议修复**：以 tokens.json 或 css 为源生成 tokens.dart，CI 加一致性校验。
- **可验收标准**：校验脚本能检测出人工注入的一处色值差异。
- **状态**：未修复

### [PLAN-038] [P2-06] README 坏图与 npm start：已修

- **编号**：PLAN-038
- **严重度**：P2
- **类别**：工程卫生 / 与文档不符
- **用户可见现象**：历史上 README 引用 2 张不存在的截图，npm start 第一步崩溃。
- **复现步骤**：1. 检查 README 引用的图片是否存在；2. node server.cjs 启动。
- **代码证据**：`public/showcase_desktop_dark.png` 与 `public/showcase_desktop_lyrics.png` 不存在，但已不再被 README 引用；`README.md:48` 引 `public/e2e_flutter_desktop_verified.png`（存在）、:52 引 `public/showcase_mobile_eq.png`（存在）；`package.json:8 start=node server.cjs`，本轮实测 `node server.cjs` 输出 Server running at http://127.0.0.1:8088/ 且 GET /index.html→200。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 0.2 P2-06 达成；残留 README:33/127 的 90/90 徽章、:35 的 83/83 徽章仍为静态文本（属 P1-13/P1-14 范畴）。
- **建议修复**：徽章改 workflow status badge（阶段 6）。
- **可验收标准**：README 引用的每张截图都存在（已满足）；干净环境 npm start 可复现（已满足）。
- **状态**：已修复

### [PLAN-039] [P2-07] Web 原型仍是振荡器合成音，mp3 零引用

- **编号**：PLAN-039
- **严重度**：P2
- **类别**：数据造假 / 与文档不符
- **用户可见现象**：Web 原型「播放」是循环和弦音，不是歌曲；34MB 真实 mp3 从未被引用。
- **复现步骤**：1. 打开 index.html 点播放听感；2. 全仓检索 track1/audio/track；3. 检索 createOscillator。
- **代码证据**：`index.html:1690 new AudioContext()`、:1780/1807 createOscillator；`mobile.html:1383`/:1468/:1494 同构；`public/audio/` 有 track1-4.mp3（34MB）且全仓检索零引用；Hi-Res 文案仍在 `index.html:658`（192kHz/24bit 母带）、:893、:1285。
- **数据真实性**：Web 原型发声为合成音（非歌曲）；mp3 为死文件。
- **原型/文档依据**：README:115 已如实说明「通过 Web Audio API 实时生成 440Hz 纯净旋律」；SPEC 的「高保真/无损」叙事与之冲突。修复方案 3.7 要求接真实 audio 或移除 Hi-Res 文案：未做。
- **建议修复**：接真实 <audio> + track1-4.mp3，或移除 Hi-Res 文案并删死文件。
- **可验收标准**：index.html 内 createOscillator 命中 0 或明确标注为演示合成音；mp3 被引用或删除。
- **状态**：未修复

### [PLAN-040] [P2-08] 双端数据/文案不一致，无共享数据源

- **编号**：PLAN-040
- **严重度**：P2
- **类别**：数据造假 / 工程卫生
- **用户可见现象**：同一歌手两端粉丝数不同；同一次 E2E 同时通过互斥数据。
- **复现步骤**：1. 比对 index.html 与 mobile.html 的歌手/曲目/歌词常量；2. 读 e2e_test.js 断言值。
- **代码证据**：无 `data.js`；`index.html` 与 `mobile.html` 各自维护常量；`e2e_test.js` 为自断言脚本（全 workflow 未引用）。
- **数据真实性**：双端各一份编造数据。
- **原型/文档依据**：ROADMAP 与 SPEC 宣称零遗漏对齐矩阵。修复方案 3.7 要求抽共享 data.js：未做。
- **建议修复**：抽 data.js 单一事实源；E2E 断言改为跨端一致性校验。
- **可验收标准**：双端同名字段取自同一源；不一致时 E2E 变红。
- **状态**：未修复

### [PLAN-041] [P2-09] 移动端缺歌单详情页与 3 个底部抽屉

- **编号**：PLAN-041
- **严重度**：P2
- **类别**：功能缺失
- **用户可见现象**：移动壳无法进入歌单详情；EQ/定时器复用桌面 showDialog；音量弹层无实现。
- **复现步骤**：1. 移动壳点歌单；2. 找 EQ/定时器/音量抽屉。
- **代码证据**：`mobile_scaffold.dart:396-410` 仅 8 个 case（recommend/fm/playlists/toplist/radio/artists/artist_detail/local），无 playlist_detail；`mobile_sheets.dart` 仅 `MobilePlayerBottomSheet`(:15) 与 `MobileQueueBottomSheet`(:338)；`MobileEqBottomSheet|MobileSleepTimerBottomSheet|MobileVolumeModal|MobilePlaylistDetailPage` 全仓 0 命中。
- **数据真实性**：N/A。
- **原型/文档依据**：SPEC:144-157 列 9 二级页 + 5 抽屉；PROGRESS 历史写 8 页：文档互相打架。修复方案 3.7 要求补齐或删文档条目：未做。
- **建议修复**：二选一：补 MobilePlaylistDetailPage 与 3 抽屉，或改 SPEC。
- **可验收标准**：移动端 9 二级页与 5 抽屉齐备（或文档同步为 8/2）。
- **状态**：未修复

### [PLAN-042] [P2-10] MellowImage 无 loading/缓存 + isInTest 生产开关

- **编号**：PLAN-042
- **严重度**：P2
- **类别**：视觉缺陷 / 工程卫生
- **用户可见现象**：图片加载空白闪烁、不落盘；测试环境下直接占位掩盖真实问题。
- **复现步骤**：1. 弱网加载封面；2. 反复进出看是否重新请求；3. 读 mellow_image.dart。
- **代码证据**：`mellow_image.dart:7 static bool isInTest = false;`、:26-27 `usePlaceholder = isInTest || WidgetsBinding.instance.runtimeType.toString().contains('Test')`；无 loadingBuilder/frameBuilder/cacheWidth/磁盘缓存（`imageCache|precacheImage|CachedNetworkImage|loadingBuilder` 在 app/lib 命中 0）。
- **数据真实性**：封面来自网络（Unsplash/网易云）；无缓存。
- **原型/文档依据**：SPEC:57 声称 LRU 流式切片缓存。修复方案 3.7 要求 cached_network_image + loadingBuilder + 删除 isInTest：未做。
- **建议修复**：引入 cached_network_image；删除 isInTest；补 loadingBuilder。
- **可验收标准**：首次加载显示进度态；二次进入 0 网络请求。
- **状态**：未修复

### [PLAN-043] [P2-11] 导入歌单仅预览前 5 首、封面失败

- **编号**：PLAN-043
- **严重度**：P2
- **类别**：功能缺失
- **用户可见现象**：导入 200 首真实歌单后列表只显示 5 首且无查看全部；封面为音符占位。
- **复现步骤**：1. 导入与自建歌单→导入新歌单→官方热歌榜解析；2. 数列表条数。
- **代码证据**：`desktop_views.dart:1134 for (final t in pl.tracks.take(5))`（无「查看全部」入口）；:1106 MellowImage(url: pl.coverUrl) 失败走占位。导入链路本身真实：`modals.dart:796 OnlineMusicService.importNeteasePlaylist`、:804 失败时诚实提示「解析失败，请检查歌单ID或网络连接」。
- **数据真实性**：导入的曲目列表为真实网易云数据；封面 URL 可能加载失败。
- **原型/文档依据**：修复方案 5.7 要求懒加载全量列表 + 封面兜底。
- **建议修复**：改为全量列表 + 懒加载；封面缺图用渐变色块占位。
- **可验收标准**：导入 200 首歌单能滚到第 200 首。
- **状态**：未修复

### [PLAN-044] [P2-12] 无音频焦点/后台播放/wakelock、无日志与错误上报

- **编号**：PLAN-044
- **严重度**：P2
- **类别**：功能缺失 / 工程卫生
- **用户可见现象**：播放时设备会正常息屏；无后台播放与系统控制；异常无提示无上报。
- **复现步骤**：1. 播放中让屏幕息屏；2. 切后台看媒体控制；3. 断网看提示与日志。
- **代码证据**：`wakelock|Wakelock|audio_session|AudioSession|audio_service|MediaSession|SMTC` 在 app/lib 命中 0；`FlutterError|runZonedGuarded|ErrorWidget|Crashlytics|Sentry|developer.log` 命中 0；debugPrint 3 处（`player_backend.dart:166`、`audio_player_service.dart:294`、`webdav_sync_service.dart:391`）。
- **数据真实性**：异常部分已有诚实反馈（`audio_player_service.dart:295 _playbackNotice`，并在 `desktop_scaffold.dart:180-200` 渲染横幅），但无日志/上报。
- **原型/文档依据**：SPEC:48/176-180 与 README:62 声称锁屏封面流控与后台播放。修复方案 1.5/6.5 未执行。
- **建议修复**：接 wakelock_plus + audio_session + audio_service；接日志与错误上报。
- **可验收标准**：播放中不息屏；锁屏/媒体面板可控；未捕获异常可上报。
- **状态**：未修复

---

## 2. 修复方案阶段 0~7 落地核对（PLAN-045 ~ PLAN-052）

### [PLAN-045] 阶段 0（止血）落地核对：安全/权限/产物名/README 达成，删假与文档诚实化有残留

- **编号**：PLAN-045
- **严重度**：P0
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：N/A（阶段核对）。
- **复现步骤**：逐条打开阶段 0 的 0.1~0.5 动作项，在当前工作区核对文件。
- **代码证据**：0.1 server.cjs 加固与重命名 → 全部落地（PLAN-012，实测通过）；0.2 删假 → onTap: () {} / onChanged: (_) {} 命中 0、Future.delayed(900) 命中 0、假设备/假端口/假状态栏已删（PLAN-003/004/008/011），残留 equalizer_manager:81/84 libmpv、desktop_views:1592/1054 超额文案、mobile_tabs:83 Mobile 角标；0.3 权限 → Android :2-6 五项 + macOS :7-10 两项均达成；0.4 release.yml 动态查找达成；0.5 文档诚实化 → README:3/PROGRESS:3/SPEC:1-20 已建立版本单一来源并加免责声明。
- **数据真实性**：N/A。
- **原型/文档依据**：阶段 0 出口标准 7 条中，第 2 条（app/lib 内 libmpv/QuickJS 命中 0）与第 3 条（移动壳假状态栏）未完全达标，其余 5 条达标。
- **建议修复**：清掉 equalizer_manager 的 libmpv 命名与 mobile_tabs:83 角标；改写 desktop_views:1592/1054。
- **可验收标准**：app/lib 内 libmpv|firequalizer|QuickJS 命中 0；六条 payload 后 server 存活。
- **状态**：部分完成

### [PLAN-046] 阶段 1（播放底座）落地核对：真播放达成，media_kit/audio_service/EQ 接线/细分通知未达成

- **编号**：PLAN-046
- **严重度**：P0
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：能听到声音（示例曲），但锁屏/系统媒体面板无控制，EQ 调节无听感变化，播放期间界面高频重绘。
- **复现步骤**：1. 播放示例曲听声；2. 查系统媒体面板；3. 拖 EQ 滑块；4. 读 position 回调。
- **代码证据**：1.1 真播放 → 用 audioplayers 替代 media_kit（`player_backend.dart:22-71`；media_kit 在 app/lib 命中 0），50ms ticker 已删（仅剩睡眠定时器 `audio_player_service.dart:447`）达成；1.2 系统媒体控制/音频焦点/wakelock → audio_service|audio_session|wakelock 命中 0 未达成；1.3 EQ → `equalizer_manager.dart:82` 无生产调用 未达成；1.4 细分通知 → `audio_player_service.dart:164-167` 仍 notifyListeners 未达成；1.5 状态机边界 → 未改（PLAN-036）。
- **数据真实性**：真播放为真实 HTTP 音频（soundhelix 演示 mp3），非真实曲目内容。
- **原型/文档依据**：SPEC:7 已诚实标注 audioplayers 替代 media_kit 的取舍；「真播放 + 系统媒体控制 + EQ 接线」三项验收只满足第一项。
- **建议修复**：补 audio_service/audio_session/wakelock；EQ 二选一；position 改 ValueNotifier 节流。
- **可验收标准**：app/lib 内 audio_service 命中 ≥1 且系统媒体面板可控；EQ 生产调用方 ≥1 或明确标注；10s 内 scaffold build ≤5 次。
- **状态**：部分完成（audioplayers 替代满足「真播放」，不满足系统媒体控制与 EQ 接线）

### [PLAN-047] 阶段 2（持久化与数据层）落地核对：shared_preferences 达成，drift/Repository/本地导入/设置补齐未达成

- **编号**：PLAN-047
- **严重度**：P0
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：收藏/历史/主题重启保持；但首次即 4 首收藏、无法导入本地音乐、设置项仍少。
- **复现步骤**：1. 冷启动看收藏数；2. 尝试导入本地音乐；3. 清点设置卡片。
- **代码证据**：2.1 用 shared_preferences 替代 drift → `storage_service.dart` 全量 KV 落盘达成（drift 在 app/lib 命中 0，曲库未落 drift）；2.2 删除预置收藏与假历史 → 假历史已删（`audio_player_service.dart:107-111`），预置收藏 4 首未删（:29）、单条移除未做；2.3 Repository 抽象 → `app/lib/data/` 不存在，mockPresetTracks 仍被 views 直接引用（desktop_views.dart:97/154/161/168/175/193-197 等）未达成；strict 未开（analysis_options.yaml:12-20）；2.4 本地导入 → file_picker|desktop_drop 命中 0 未达成；2.5 设置补齐 → 4 卡片（PLAN-018）部分。
- **数据真实性**：持久化为真实；曲库仍为内置示例。
- **原型/文档依据**：修复方案 2.1 验收标准 3 要求 drift 命中 ≥1：未满足；MVP 验收④（红心 2 首、播放 3 首重启保持）在 shared_preferences 下可满足。
- **建议修复**：清空 _favoriteIds 默认值；引入 file_picker/desktop_drop；建 TrackRepository 收敛 mockPresetTracks。
- **可验收标准**：首次安装收藏 0 历史空；导入目录后列表条数与磁盘一致；views/ 与 navigation/ 内 mockPresetTracks 命中 0。
- **状态**：部分完成

### [PLAN-048] 阶段 3（真实数据接入）落地核对：仅内置示例重组，无真实数据源

- **编号**：PLAN-048
- **严重度**：P1
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：榜单/歌手/歌单/电台仍为编造内容，但对齐了内部一致性（歌手详情与列表一致、四榜池不同）。
- **复现步骤**：1. 逐页核对数据来源；2. app/lib 检索 Repository；3. 检查错误反馈。
- **代码证据**：3.1 四榜池 → 已独立（track_model.dart:525/579/604/657），静态更新文案未删（desktop_views.dart:418/426/434/442）；3.2 歌手 → 已差异化（:473-506）但粉丝数编造、默认已关注；3.3 歌单 → 真歌单模型（:887-958）但播放量编造；3.4 错误反馈 → app/lib/core/error/ 不存在、catch (_) 仍在 online_music_service.dart:80/157/182；3.5 电台 → 专属曲目（:769-863）但无单集模型；3.6 Provider/私有接口 → 未做；3.7 一致性 → tokens 不一致、Web 振荡器、移动端缺页。
- **数据真实性**：全部为 track_model.dart 内置常量（33 首示例 + 编造元数据），仅在线搜索/歌单导入/歌词三条链路真实联网。
- **原型/文档依据**：SPEC:1-20 顶部已声明第 4~7 章为目标设计；PROGRESS.md:35 自评「阶段 3 基本未完成」，与本轮一致。
- **建议修复**：按 3.4 先做错误反馈；无数据源页面改空态；删除编造播放量与静态更新承诺。
- **可验收标准**：断网搜索显示「网络异常」；同一实体跨页数字一致或不显示；无数据源页面为空态。
- **状态**：基本未完成

### [PLAN-049] 阶段 4（同步与 LX 音源决策）落地核对：未执行，两者仍为死代码

- **编号**：PLAN-049
- **严重度**：P1
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：同步中心与音源管理页均标注「接入中」，但代码既未接线也未删除。
- **复现步骤**：1. main.dart 看 Provider 注册；2. app/lib 检索三个类的引用。
- **代码证据**：`main.dart:14-19` 仅注册 ThemeProvider/AudioPlayerService/EqualizerManager；`webdav_sync_service.dart:160`、`lan_sync_service.dart:411`、`lx_script_sandbox.dart:727` 三个类的生产引用数均为 0（grep 仅命中定义处与自引用）；`desktop_views.dart:1558-1570` 与 :1498-1511 仅诚实提示。
- **数据真实性**：LWW 算法与 WebDAV/LAN 实现本身是真实 HTTP 代码（sync_services_test.dart 15 用例覆盖），但无生产调用方，用户不可达。
- **原型/文档依据**：修复方案 4.1/4.2 明确「阶段 4 结束时必须二选一，不允许继续悬空」：未执行。PROGRESS.md:36 自评「未执行」，一致。
- **建议修复**：MVP 建议整页删除（A2+B2），或按 A1/B1 真接线并加错误反馈。
- **可验收标准**：app/lib 内 WebDavSyncService/LanSyncService 命中 0（删除分支）或 ≥1 生产调用（接线分支）。
- **状态**：未执行（悬空状态持续）

### [PLAN-050] 阶段 5（桌面体验与性能）落地核对：仅快捷键与自建导航栈

- **编号**：PLAN-050
- **严重度**：P1
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：键盘快捷键可用、前进/后退可用；但窗口可缩到极小、列表一次性构建、无屏幕阅读器语义。
- **复现步骤**：1. 按快捷键；2. 缩窗口；3. 用讲述人浏览。
- **代码证据**：5.1 go_router → 命中 0，用自建 _history（desktop_scaffold.dart:33-74）替代；5.2 快捷键 → 已实现（:87-125），验收要求的 app/test/shortcuts_test.dart 不存在；5.3 窗口最小尺寸 → 未做（PLAN-022）；5.4 无边框 → 未做（PLAN-035）；5.5 列表虚拟化 → 未做（PLAN-033）；5.6 可访问性 → 未做（PLAN-030）；5.7 take(5) → 未改（desktop_views.dart:1134）。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 5 章 6 个子项中仅 5.2 部分落地。
- **建议修复**：补快捷键测试；引入 window_manager；列表 Sliver 化。
- **可验收标准**：快捷键 tester 断言通过；窗口最小 1024×640；3000 首滚动帧率 ≥50fps。
- **状态**：部分完成

### [PLAN-051] 阶段 6（质量门禁）落地核对：条件断言清理与版本单一来源达成，其余未做

- **编号**：PLAN-051
- **严重度**：P1
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：CI 绿灯不可信；README 数字与实际不一致。
- **复现步骤**：1. 读 ci.yml；2. 读 flutter_e2e_verify.mjs；3. 统计测试数与重复文件。
- **代码证据**：6.1 → flutter_e2e_verify.mjs:126/181 catch (_) {}、:137-187 无条件 PASS、:201 打印 100% 通过，零 assert 未做；6.2 → ci.yml:20/60 channel stable、无 flutter-version、无 e2e_test.js、无 integration_test、analyze 无 --fatal-infos 未做；6.3 → if (find 命中 0 已做，但重复文件仍在（两文件 285 行 MD5 相同）、lx_source_engine_test.dart 25 用例仍断言 mock 部分；6.4 → 7 个僵尸依赖 + 无 fonts 配置 未做；6.5 → 版本单一来源已在 README/PROGRESS/SPEC 建立 已做，package_info_plus 与 strict、错误上报未做。
- **数据真实性**：本轮实测 flutter analyze 0 issue、flutter test 90/90（复跑）；首轮 89/90（见 PLAN-069）。
- **原型/文档依据**：修复方案 6 章 5 子项中 6.3 部分、6.5 部分落地。
- **建议修复**：重写 E2E 为真断言；固定版本；删重复文件；清僵尸依赖。
- **可验收标准**：不 build web 跑脚本退出码 1；flutter-version 固定为 3.47.x；仓库无内容相同的两个测试文件。
- **状态**：部分完成

### [PLAN-052] 阶段 7（平台与发布）落地核对：仅 macOS 打包步骤修正

- **编号**：PLAN-052
- **严重度**：P2
- **类别**：与文档不符 / 功能缺失
- **用户可见现象**：产物名仍 app；Web manifest 仍是 Flutter 模板；鸿蒙无工程文件。
- **复现步骤**：1. 读各平台配置文件；2. 列 harmonyos；3. 读 release.yml 是否有 ios/hap job。
- **代码证据**：7.1 → 仅 Android label 改（其余见 PLAN-023）；7.2 macOS 打包 → 已改动态查找（PLAN-024）；7.3 鸿蒙 → find app/harmonyos -type f 仅 README.md，README 仍宣称「支持 HarmonyOS NEXT 与 OpenHarmony 4.0+」「API 10+」，但 AppScope/app.json5、entry/、module.json5、EntryAbility.ets 全不存在；release.yml 无 build-hap；7.4 iOS → release.yml 无 build-ios job，ios/Runner/Info.plist 无 UIBackgroundModes。
- **数据真实性**：N/A。
- **原型/文档依据**：SPEC:5 与 ROADMAP:160 仍宣称鸿蒙支持；修复方案 7.3 要求「补齐或移除，不允许保留现状」：未执行。
- **建议修复**：执行 7.1 表；鸿蒙二选一；iOS 二选一。
- **可验收标准**：六端产物名/图标/版权一致；harmonyos 有真实工程或文档移除。
- **状态**：基本未完成

---

## 3. 附录 A 关键数字复验（PLAN-053 ~ PLAN-062）

### [PLAN-053] 附录 A 关键数字复验

- **编号**：PLAN-053
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：现为 98 个（test( 52 + testWidgets( 46），分布于 14 个 *_test.dart（含 integration_test 8 个）。命令：grep -rhoE '^\s*(test|testWidgets)\(' app/test app/integration_test | sort | uniq -c；flutter test 只执行 test/ 下 90 个（integration_test 默认不跑）。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#1 Dart 测试用例 77（44 test + 33 testWidgets）」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：已过期

### [PLAN-054] 附录 A 关键数字复验

- **编号**：PLAN-054
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：app/test/client_e2e_user_journey_test.dart 与 app/integration_test/app_client_e2e_test.dart 各 285 行、MD5 均为 9c6ce41ed07d4ed42f754a2b4a909698（md5 -r）。结论：重复问题至今未修，数字由 279 变为 285。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#2 两测试文件完全相同（均 279 行，MD5 9C6CE41ED0）」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：仍成立且行数已变

### [PLAN-055] 附录 A 关键数字复验

- **编号**：PLAN-055
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：app/pubspec.lock:702 flutter: ">=3.47.0"（原标注 :622）。全部 workflow 仍用 channel: 'stable' 且未固定版本（见 PLAN-025）。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#3 pubspec.lock 解析出 flutter >=3.47.0」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：仍成立（行号已移）

### [PLAN-056] 附录 A 关键数字复验

- **编号**：PLAN-056
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：app/android/app/src/main/AndroidManifest.xml 现 51 行，:2-6 含 5 项 uses-permission（INTERNET/ACCESS_NETWORK_STATE/WAKE_LOCK/FOREGROUND_SERVICE/FOREGROUND_SERVICE_MEDIA_PLAYBACK）。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#4 AndroidManifest 45 行、无任何 uses-permission」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：已过期（已修）

### [PLAN-057] 附录 A 关键数字复验

- **编号**：PLAN-057
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：app/macos/Runner/Release.entitlements 现 12 行，:5-10 含 app-sandbox + network.client + network.server。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#5 Release.entitlements 8 行、仅 app-sandbox」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：已过期（已修）

### [PLAN-058] 附录 A 关键数字复验

- **编号**：PLAN-058
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：find app/harmonyos -type f → 仅 app/harmonyos/README.md；README 仍宣称拥有 app.json5 / module.json5 / EntryAbility.ets（均不存在）。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#6 harmonyos 仅 README.md」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：仍成立

### [PLAN-059] 附录 A 关键数字复验

- **编号**：PLAN-059
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：app/windows/CMakeLists.txt:4 project(app LANGUAGES CXX)、:9 set(BINARY_NAME "app")、app/windows/runner/main.cpp:30 window.Create(L"app", ...)、:29 Size(1280,720)。release_windows/ 被 .gitignore（:13）且当前不存在，无法复验 90624 字节（标注未验证）。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#7 windows project(app)/BINARY_NAME app/main.cpp Create(L"app")、release_windows/app.exe 90624 字节」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：源码仍成立（产物不可复验）

### [PLAN-060] 附录 A 关键数字复验

- **编号**：PLAN-060
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：app/web/manifest.json:2-3 name/short_name=mellow_music、:6-7 background_color/theme_color=#0175C2、:8 description=A new Flutter project.、:9 orientation=portrait-primary。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#8 web/manifest.json 仍为模板」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：仍成立

### [PLAN-061] 附录 A 关键数字复验

- **编号**：PLAN-061
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：app/pubspec.yaml:66-102 flutter 段仅 uses-material-design（fonts 全为注释）；app/lib/main.dart:44 与 :54 fontFamily: 'PingFang SC'。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#9 pubspec 无 fonts 配置而 main.dart 用 PingFang SC」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：仍成立

### [PLAN-062] 附录 A 关键数字复验

- **编号**：PLAN-062
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（核对项）。
- **复现步骤**：按附录 A 命令逐条执行。
- **代码证据**：public/audio/ 仍有 track1-4.mp3，du -sh = 34M（精确 35,233,596 B ≈ 33.6 MiB）；.gitignore 已含 release_windows/（:13）与 verify_windows_app.ps1，但 grep -n 'public/audio|\.qa' .gitignore 无命中：两项仍未加入。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md 附录 A 声称「附录 A#10 public/audio 4 mp3 约 33.6MB、.gitignore 未含 public/audio 与 .qa」。
- **建议修复**：更新附录 A 或按对应 PLAN 条目修复。
- **可验收标准**：附录 A 的数字与当前工作区实测一致。
- **状态**：部分仍成立

---

## 4. 修复方案中已失效 / 自相矛盾的断言（PLAN-063 ~ PLAN-069）

### [PLAN-063] 修复方案「本机未安装 Flutter/Dart 工具链」断言已失效

- **编号**：PLAN-063
- **严重度**：P1
- **类别**：与文档不符
- **用户可见现象**：N/A。
- **复现步骤**：flutter --version；cd app && flutter analyze；cd app && flutter test。
- **代码证据**：本轮实测 flutter --version → Flutter 3.47.4 stable / Dart 3.13.3；flutter analyze → No issues found!（exit 0）；flutter test → +90: All tests passed!（复跑；首轮 89/90，见 PLAN-069）。
- **数据真实性**：N/A。
- **原型/文档依据**：docs/PC_E2E_FIX_PLAN.md:7 与 :940 声称「本机未安装 Flutter/Dart 工具链，所有 flutter analyze/test/build 标注为需在装好工具链的机器上执行」。该前提已过期（PROGRESS.md:22 也已指出）。
- **建议修复**：把阶段 0~7 中标「需装工具链」的验收标准改为可执行并实际执行。
- **可验收标准**：附录 A 第 4 条改写为已执行结果。
- **状态**：断言失效（已确认）

### [PLAN-064] 修复方案称 docs/PC_E2E_ACCEPTANCE_ISSUES.md 不存在：断言错误且自相矛盾

- **编号**：PLAN-064
- **严重度**：P1
- **类别**：与文档不符
- **用户可见现象**：N/A。
- **复现步骤**：wc -l docs/PC_E2E_ACCEPTANCE_ISSUES.md；read docs/PC_E2E_FIX_PLAN.md:5。
- **代码证据**：docs/PC_E2E_ACCEPTANCE_ISSUES.md 实际存在且 1231 行（本轮 read 成功，含 44 条缺陷全文）；而 docs/PC_E2E_FIX_PLAN.md:5 写「docs/PC_E2E_ACCEPTANCE_ISSUES.md 在本仓库中不存在」；:928 再次如此声称。修复方案自身第 3 行又依据 docs/audit/ 四份报告（存在，合计 1865 行）。
- **数据真实性**：N/A。
- **原型/文档依据**：同证据；PROGRESS.md:31 亦已点出该断言错误。
- **建议修复**：修正修复方案 :5/:928。
- **可验收标准**：修复方案不再声称该文件不存在。
- **状态**：自相矛盾（已确认）

### [PLAN-065] 阶段 0 验收标准「app/lib 内 libmpv/firequalizer 命中 0」未达成

- **编号**：PLAN-065
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A。
- **复现步骤**：grep -rn 'libmpv|firequalizer' app/lib。
- **代码证据**：app/lib/core/audio/equalizer_manager.dart:81（注释「生成 libmpv firequalizer 滤镜参数字符串」）与 :84（StringBuffer('firequalizer=gain=\'')）仍命中；QuickJS 命中 0。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 0.2 验收标准 1 明列 libmpv、firequalizer 应命中 0；该条未达成。
- **建议修复**：重命名方法并删除 libmpv 文案，或真实接线。
- **可验收标准**：grep -rn 'libmpv|firequalizer' app/lib 无输出。
- **状态**：未达成（方案要求与现状冲突）

### [PLAN-066] 阶段 1 验收标准「media_kit 命中 ≥1」与实际技术选型冲突

- **编号**：PLAN-066
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A。
- **复现步骤**：grep -rn 'media_kit' app/lib；读 app/pubspec.yaml:30-47；读 docs/SPEC.md:7。
- **代码证据**：media_kit 在 app/lib 与 pubspec 均命中 0；实际依赖 audioplayers: ^6.8.1（pubspec.yaml:47）；docs/SPEC.md:7 已承认该替代。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 1.1 验收标准 4 写「app/lib 内 media_kit 命中 ≥1，pubspec.lock 含 media_kit」——在选定 audioplayers 后该标准已失效且无法通过，方案未同步修订。
- **建议修复**：把验收标准改为「存在真实物理播放后端且进度来自真实流」，并注明允许 audioplayers。
- **可验收标准**：方案不再要求 media_kit 字样。
- **状态**：断言失效

### [PLAN-067] 阶段 2 验收标准「drift 命中 ≥1」与最终选型冲突

- **编号**：PLAN-067
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A。
- **复现步骤**：grep -rn 'drift|sqlite|sqflite' app/lib；读 docs/SPEC.md:9。
- **代码证据**：drift|sqlite|sqflite 在 app/lib 命中 0；持久化由 storage_service.dart（shared_preferences）完成；SPEC:9 已承认用 shared_preferences KV。
- **数据真实性**：N/A。
- **原型/文档依据**：修复方案 2.1 验收标准 3 要求 drift 命中 ≥1 与 pubspec.lock 含 drift/sqlite3_flutter_libs：无法通过，且方案仍列为验收标准。
- **建议修复**：重写为「杀进程重启后设置/收藏/历史保持」。
- **可验收标准**：方案验收标准与实际数据层一致。
- **状态**：断言失效

### [PLAN-068] 阶段 3 的两条验收口径互斥（差异化内置榜单 vs 禁止保留内置榜单）

- **编号**：PLAN-068
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A。
- **复现步骤**：读 track_model.dart:525/579/604/657/728；读修复方案 3.1 第③点与验收标准。
- **代码证据**：四榜列表 ID 集合互不相同（已满足方案验收标准）；但 3.1 第③点又写「若无法接入真实榜单服务，整页改为空态或移除导航项——禁止保留取模伪装的 4 个榜单」。当前保留了 4 个内置榜单（非取模伪装，但仍是编造内容）。两条要求在「保留内置差异化榜单」这一实现下无共同判定。
- **数据真实性**：四榜均为内置示例数据。
- **原型/文档依据**：修复方案 3.1。
- **建议修复**：明确单一判定：要么真数据接入，要么整页空态。
- **可验收标准**：二选一并写入方案。
- **状态**：口径互斥（已确认）

### [PLAN-069] 测试稳定性：全量 flutter test 首轮 89/90（偶发失败），复跑 90/90

- **编号**：PLAN-069
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：N/A（CI 质量门禁稳定性）。
- **复现步骤**：连续两次执行 cd app && flutter test，对比结果。
- **代码证据**：首轮输出 +89 -1: Some tests failed.，失败用例为 app/test/sync_services_test.dart 的「3. WebDAV 云端备份与还原状态机测试 (WebDavSyncService) 自动定时同步开关与触发机制测试」；单独执行 flutter test test/sync_services_test.dart → +15: All tests passed!；复跑全量 → +90: All tests passed!。
- **数据真实性**：N/A。
- **原型/文档依据**：FORMAT.md:47 与 README.md:33/127、PROGRESS.md:15/91 均声称「90/90 通过」，未提示存在偶发不稳定。
- **建议修复**：排查该自动定时同步用例的定时器/端口竞态，修成确定性用例。
- **可验收标准**：连续 3 次 flutter test 均 90/90。
- **状态**：未修复（偶发不稳定）

---

## 5. 本轮实测命令与原始结果（可复现）

| 命令 | 结果 |
| :--- | :--- |
| `flutter --version` | Flutter 3.47.4 stable / Dart 3.13.3 |
| `cd app && flutter analyze` | `No issues found!`（exit 0） |
| `cd app && flutter test`（首轮） | `+89 -1`，失败 `sync_services_test.dart` 自动定时同步用例 |
| `cd app && flutter test`（复跑） | `+90: All tests passed!` |
| `cd app && flutter test test/sync_services_test.dart` | `+15: All tests passed!` |
| `node server.cjs` + 6 payload | 进程存活；`/%ZZ`→400；Range `abc-`→200、`-500`→206、`100-50`→416、`99999999-`→416、多段→200；POST→405 |
| 目录穿越 9 条 | `/..%5c`、`/%2e%2e/`、`/.git/config`、`/node_modules/...`、`/../package.json`、`/docs/SPEC.md`、`/app/pubspec.yaml` 全 403 |
| `md5 -r app/test app/integration_test` | 两文件同 MD5 `9c6ce41ed07d4ed42f754a2b4a909698`，各 285 行 |
| 测试用例统计 | `test(` 52 + `testWidgets(` 46 = 98，14 文件 |
| `du -sh public/audio` | 34M（4 个 mp3） |

## 6. 不确定 / 未验证事项（不编造结论）

1. **Windows 产物**：`release_windows/` 被 gitignore 且当前不存在，无法复验 44 条验收报告所基于的 `app.exe`（90624 B / MD5 4839AFE...）与 `app.so` 字节数；所有 Windows 侧结论均为当前源码静态核对，未经产物实机复验。
2. **Android/macOS release 产物**：P0-05/P0-06 仅静态核对配置文件，未产出 release APK / 签名 .app 验证 `aapt dump permissions` / `codesign -d --entitlements`。
3. **真实播放听感**：P0-01 的真播放为本轮代码级取证（audioplayers + soundhelix 直链 + 真实进度流），未在扬声器上实测出声。
4. **快捷键运行时行为**：P0-09 为代码级取证；未运行时验证 ESC 在搜索浮层/弹窗内的行为，也未验证搜索框聚焦时空格是否被 TextField 正确吞掉。
5. **macOS release 构建**：本轮未执行 `flutter build macos --release`（仅依据 FORMAT.md 基线的 `--debug` 成功）；P1-12 的 CI 6 job 全绿未实跑。
6. **网易云在线链路当前可用性**：基线标注音频直链 302→404，本轮未重新裸测 `music.163.com` 各接口现状；`online_music_service.dart` 的静态证据充分。
7. **鸿蒙/iOS 工程**：仅确认工程文件缺失与文档声称不符，未评估补齐工作量。
8. **44 条验收报告原始截图**：`docs/evidence/pc-e2e/` 未逐一打开比对像素，本轮结论基于当前源码与代码级运行证据。

