# E2E 缺陷修复进度汇总（STATUS）

> 本文件是五份账本（desktop 24 / mobile 32 / data 19 / fixplan 69 / desktop-visual 12，共 **156** 条）**统一修复进度的汇总视图**。
> 明细与证据请看各账本本身；本文件只回答「哪些已修、哪些没修、证据是什么」。
> 最后校准：2026-09-23（Round 5 终版验收；逐项实测数字见 §6）。

## 0. 质量基线（可复现）

| 检查 | 命令 | 结果 |
| :--- | :--- | :--- |
| 静态分析 | `cd app && flutter analyze` | ✅ No issues found!（本轮实测） |
| 测试 | `cd app && flutter test` | ✅ **188/188 全绿**（本轮实测，基线 188） |
| macOS 构建 | `cd app && flutter build macos --debug` | ✅ 成功（含 flutter_js） |
| 桌面端集成 E2E | `cd app && flutter test integration_test/desktop_real_user_e2e_test.dart -d macos` | ✅ **9/9 全绿**（真实网络 + 真实音频 + 真实落盘） |
| Android 构建 | `cd app && flutter build apk --debug` | ✅ 成功：本轮产出 `app-debug.apk`（2026-09-23 06:23:34，230,760,763 字节），并 `adb install -r` 到 Redmi / Android 15 真机复验 |
| 假数据扫描 | `grep -rn "mellowmusic.io\|_mockDatabase\|simulateFailure\|清风拂过绿水" app/lib` | ✅ 0 命中 |

> 终版验收基线的逐项实测证据见文末「§6 终版验收基线（Round 5 实测）」。

## 1. 已修复（本轮，含证据）

| 主题 | 修复内容 | 证据 |
| :--- | :--- | :--- |
| P0 播放无声/伪播放 | 接入 `audioplayers` 物理音频驱动；无真实音源时**不再伪造播放**，改为诚实提示（含移动端 SnackBar） | `core/audio/player_backend.dart`、`audio_player_service.dart:_executeRealPlay`、`main.dart:PlaybackNoticeListener` |
| P0 零持久化 | 主题/音量/播放模式/收藏/历史/导入歌单/本地曲库/关注歌手 全量落盘，冷启动恢复 | `core/storage/storage_service.dart`、`audio_player_service.dart:_loadFromStorage` |
| P0 假云端备份 | 假成功弹窗删除；同步中心改为**真实接线** WebDAV 与局域网 | `core/sync/sync_controller.dart`、`desktop_views.dart:DesktopSyncView` |
| P0 服务端可被单请求打死 | `server.cjs` 加固：目录穿越、`decodeURIComponent` 异常、Range 越界、异常兜底、默认只听 127.0.0.1 | `server.cjs` |
| P0 macOS Debug 无网络权限 | 补 `com.apple.security.network.client`（此前所有联网在 OS 层被拒） | `macos/Runner/DebugProfile.entitlements` |
| 数据造假：内置假曲库 | 删除 33 首 SoundHelix 假曲目 + 编造曲名/歌手/封面 + 4 位编造歌手与粉丝数 | `core/audio/track_model.dart`（1003 → 约 244 行，本轮复核） |
| 数据造假：四榜单/电台/歌单/雷达/日推 | 全部改为真实曲库驱动；无数据时诚实空状态；删除编造统计与更新时间 | `desktop_views.dart`、`mobile_tabs.dart`、`mobile_pages.dart` |
| 数据造假：Unsplash 假封面/头像 | 不再用于冒充歌手/专辑/用户；首页头像改真实曲目封面 | `track_model.dart`、`mobile_tabs.dart` |
| 假收藏 | 删除预置 4 首假收藏，收藏只来自用户真实操作 | `audio_player_service.dart` |
| 音源偏离计划 | 恢复并补齐**网易云真实音源**（真实取流 + 音质降级 + 无版权诚实提示）+ **LX 真实引擎**（flutter_js + 真实网络桥） | `netease_music_service.dart`、`lx_script_engine.dart` |
| 本地导入缺失 | 真实系统文件选择器导入 + 落盘 + 真实时长回填 | `core/sources/local_music_service.dart`、`localTracks` |
| 时长/进度造假 | 播放器进度上限改用**真实解码时长**（移动端 + 桌面底栏 + 全屏歌词） | `mobile_sheets.dart`、`desktop_scaffold.dart`、`fullscreen_lyrics_view.dart` |
| 移动端无音量入口 | 新增真实音量滑杆 + 静音/恢复 | `mobile_sheets.dart` |
| EQ 死开关 | 明确标注「当前引擎不支持实时音效」，不再暗示声音被调节 | `equalizer_manager.dart`、`modals.dart`、`desktop_scaffold.dart` |
| 空夹具下标崩溃 | 10 处 `currentTrack ?? mockPresetTracks[0]` 全部改为空态渲染 | 各播放器 UI |
| 版本/文档不一致 | 确立 `pubspec.yaml` 为版本单一来源；README/PROGRESS/SPEC/ROADMAP 校准为真实口径 | `README.md`、`docs/*` |
| 平台品牌化 | web manifest / iOS 显示名 / Windows 可执行名与窗口标题 | `app/web/manifest.json`、`ios/Runner/Info.plist`、`windows/*` |
| 测试锁死假数据 | 全部改为保护真实行为（显式夹具注入），并删除已失效的假源测试 | `app/test/*` |
| 偶发失败测试 | WebDAV 自动同步测试加真实重入保护并改为轮询等待 | `webdav_sync_service.dart`、`sync_services_test.dart` |

## 2. 未修复 / 如实声明的限制

| 项 | 现状 | 说明 |
| :--- | :--- | :--- |
| 网易云多数曲目不可播放 | 版权限制（接口返回 `url:null`） | UI 如实提示；非实现缺陷 |
| LX `rsaEncrypt` 未实现 | 缺 RSA 依赖 | 需要 RSA 的脚本诚实报错 |
| QuickJS 仅 macOS 实测 | Android/Windows/Linux 未真机验证 | 待真机/CI 验证 |
| EQ 不改变声音 | `audioplayers` 无实时音效能力 | 需换 DSP 引擎才能真实生效 |
| 同步未跨端互测 | 需第二台设备 | 单端接线与单测已完成 |
| ~~外部歌单 QQ/酷狗~~ | ✅ 已接入（Round 4） | `online_music_service.dart` 公开歌单端点 curl 实测 HTTP 200 + 真实 JSON；不支持的输入抛真实可读错误，不返回假歌单 |
| ~~桌面端 ESC/快捷键在全屏歌词内失效~~ | ✅ 已修复（DESK-001） | 与主工作台共用同一套 `CallbackShortcuts`，ESC/L 等在全屏歌词内恢复生效 |
| 列表虚拟化 / go_router 真实 34 路由 | 未做（DESK-015 等 P2） | 性能与架构优化项 |
| Windows 产物复验 | 未做 | 需 Windows 环境 |
| Android 真机 E2E | ✅ 已完成（第二轮复验） | Redmi / Android 15 真机 6 项新修全部通过、本轮无新缺陷；见 `ledger-mobile.md` §8 |

## 3. 下一步

1. ~~安卓真机 E2E 取证结果回收~~ → 已完成（第二轮无新缺陷）；后续按账本剩余 9 条移动端待修项继续。
2. 修桌面端剩余条目：DESK-014（可访问性）、DESK-020（窗口约束）与 DESK-015 / DESK-019 部分项，以及 P2（虚拟化等）。
3. 用真实 LX/六音脚本做一次线上导入验证。
4. 回填各账本条目『状态』字段（当前仍有 69 条待修/其他未回填）；终版验收报告已产出：`docs/e2e/FINAL-ACCEPTANCE.md`。
## 4. 本轮（Round 4）新增进展

| 项 | 状态 | 说明 |
| :--- | :--- | :--- |
| 音质偏好真实生效 | ✅ 已落地 | `StorageService.getPreferredQuality/savePreferredQuality`（默认 320K）+ 播放器读取偏好 + 取流按偏好真实请求并回传实际码率 |
| QQ / 酷狗 歌单导入 | ✅ 已接入 | `online_music_service.dart` 增加两个平台的公开歌单端点（curl 实测 HTTP 200 + 真实 JSON）；不支持的输入抛真实可读错误，不返回假歌单 |
| Android 构建阻塞 | ✅ 已修 | flutter_js 插件 JVM target 冲突：`android/gradle.properties` 降级校验 + `android/build.gradle.kts` 统一 Kotlin JVM_17；现已产出 `app-debug.apk` |
| 全屏歌词快捷键 | ✅ 已修（DESK-001） | 移除提前 return，改为与主工作台共用同一套 `CallbackShortcuts`，ESC/L 等在全屏歌词内恢复生效 |
| 测试基线 | ✅ 提升 | 144 → **188 项全部通过**（Round 5 实测） |

## 5. 子 Agent 并行分工与失败重拉

本轮共拉起 15 个子 Agent（并行取证 4 个 → 测试对齐 3 个 → 音源补齐 2 个 → 移动端清理 1 个 → 同步接线 1 个 → 桌面/音质补齐 2 个 → 真机 E2E 1 个 → 失败重拉 3 个）。
其中 3 个中途失败（桌面剩余缺陷、音质偏好与外部歌单、安卓真机 E2E）；**失败前的部分改动已落盘且通过全量测试**，本轮已重新拉起并继续。

## 6. 终版验收基线（Round 5 实测）

### 6.1 本轮实测数字（全部在本机 macOS 实测，命令见 §0）

| 项 | 命令 | 实测结果 |
| :--- | :--- | :--- |
| 静态分析 | `cd app && flutter analyze` | **No issues found!**（无 warning / 无 info） |
| 单元 + 组件测试 | `cd app && flutter test` | **188/188 全绿**（基线 188，无回归） |
| macOS 构建 | `cd app && flutter build macos --debug` | **成功**：产出 `build/macos/Build/Products/Debug/Mellow Music.app` |
| 桌面端集成 E2E | `cd app && flutter test integration_test/desktop_real_user_e2e_test.dart -d macos` | **9/9 全绿**（E2E-01 ~ E2E-09） |

集成 E2E 的关键真实证据（来自本轮运行日志，非合成）：

- 真实网络：聚合搜索返回 35 条（网易云 20 / iTunes 15），每条带真实来源标识；网易云条目 `audioUrl` 仍恒为 `null`（DESK-U-001 口径未满足，未弱化）。
- 真实音频：点击 iTunes 试听结果后 `player.position` 真实推进（实测起播约 0.016~0.073s，`duration` 来自真实解码 ≈00:29.976）。
- 真实取流诚实性：无版权曲目 347230 不返回直链并给出可读原因；可播曲目 5257138 返回 `music.126.net` 真实直连。
- 真实落盘：收藏 id / 本地曲库（含真实文件路径）/ 音量 / 播放模式均写入真实存储并可在新实例恢复。

### 6.2 本轮已修条目统计

**产品/账本条目：1 条闭环（DESK-V-006 的集成测试同步）**

- `app/integration_test/desktop_real_user_e2e_test.dart` 的 `tapSidebar` 由旧文案文本定位改为稳定 key `desktop-nav-<id>`（id 来自 `desktopNavEntries`）。
- E2E-01 / E2E-06 / E2E-09 中全部旧导航文案（巅峰榜单 / 热门歌手 / 本地与下载 / 播放历史 / 多端同步中心 / LX 音源管理 / 个性化设置）替换为新文案对应的 id。
- E2E-06 的页面 marker 改为「视图内 H1 限定查找」，H1 取自 `desktopViewTitles` 唯一映射；旧 marker「声音电台专区」等废弃字符串不再引用。
- 效果：侧栏/H1 文案以后只改 `app/lib/views/desktop/desktop_views.dart` 一处，集成测试不会再因改名而断。

**集成测试自身写法/卫生问题（非产品缺陷，已改测试）：3 条用例、共 5 处问题**

| 用例 | 原问题（测试侧） | 处理 |
| :--- | :--- | :--- |
| E2E-02 | 搜索结果是懒加载 `ListView`，首屏只构建可见项；iTunes 结果排在网易云结果之后时首屏看不到 → 误判为「搜索无结果」 | 改为真实滚动结果列表直到「iTunes 试听」出现 |
| E2E-02 | `下一首/上一首` 依赖 `playTrack` 插入顺序，队列里混有上一步点过的网易云曲目，落点不确定 | 改为显式构造两首真实可播曲目的确定队列再验证 next/prev |
| E2E-02 | 测试体结束时真实音频仍播放，`audioplayers` 帧回调在 widget 树销毁后触发 `An animation is still running…` | 测试体内先 `player.pause()` 并 pump，再结束用例 |
| E2E-03 / E2E-07 | 诚实提示 `SnackBar`（悬浮层）弹出后约 4s 会遮挡底栏按钮，导致点击落空 | 先等待提示自行消失再操作底栏；收藏按钮改用稳定 key `dock-favorite-toggle` |

> 结论：上述 3 条用例共 5 处失败，**均判定为测试写法过时/测试卫生问题**，产品行为（真实搜索、真实播放、诚实提示、收藏落盘、全屏歌词 ESC）经修复后的集成测试全部通过；本轮**未改** `app/lib/` 生产代码。

### 6.3 账本条目状态统计（逐条字段复核；移动端取 §8.4 覆盖后分布）

| 账本 | 条目总数 | 已修复 | 部分修复 / 部分完成 | 待修复 / 其他 |
| :--- | ---: | ---: | ---: | ---: |
| `docs/e2e/ledger-desktop.md` | 24 | 20 | 2 | 2 |
| `docs/e2e/ledger-mobile.md`（按 §8.4 状态变更表） | 32 | 19 | 3 | 9 + 1（不修） |
| `docs/e2e/ledger-data.md` | 19 | 0 | 0 | 19 |
| `docs/e2e/ledger-fixplan-progress.md` | 69 | 8 | 23 | 38 |
| `docs/e2e/ledger-desktop-visual.md` | 12 | 12 | 0 | 0 |
| **合计** | **156** | **59** | **28** | **69**（68 待修/其他 + 1 已确认不修） |

> 统计口径：逐条读取正文 `- **状态**：...` 字段并按条目 ID 归并；**移动端采用该账本 §8.4「状态变更表（覆盖正文）」的第二轮真机最新分布**（正文 6 已修 / 1「修复中」已过时）。`ledger-data.md` 19 条字段状态仍全部为「待修复」（其多数问题已在后续修复处理，但账本未回填状态，故不计入「已修复」）。`ledger-fixplan-progress.md` 为定点核对，含「已过期 / 断言失效 / 仍成立」等历史状态，统一归入「待修/其他」。较上一轮口径（46 / 24 / 86）的差异全部来自移动端复验回填。明细与逐条 ID 见 [`FINAL-ACCEPTANCE.md`](FINAL-ACCEPTANCE.md) §4。

### 6.4 无法在本机验证的项（如实声明，不代填，不含推测结论）

| 项 | 为什么本机无法验证 | 需要什么条件 |
| :--- | :--- | :--- |
| Windows 产物 | 本机为 macOS，无 Windows 工具链 | 在 Windows 机器执行 `flutter build windows` 并实机启动 |
| 真机听感 | 自动化只能验证「音频流真实推进 / 有真实解码时长」，无法验证经真实扬声器或耳机的听感 | 人工在真机用耳机试听并记录 |
| 跨端同步互测 | 需要第二台设备与可访问的真实 WebDAV / 局域网对端 | 两台设备 + 真实 WebDAV 服务，做真实双向同步 |
| 系统媒体控制 | 未接入系统级媒体控制（macOS Now Playing / Windows SMTC / Linux MPRIS 等），本机无对应实现可验证 | 明确需求后接平台通道，再在 macOS / Windows 实机验证 |


### 6.5 本轮结论

- 本机可验证的验收项（analyze / 188 单测 / macOS 构建 / 9 条桌面集成 E2E）**全部通过**；桌面视觉 DESK-V-001~012 **12/12 已修**；Android 真机第二轮复验 6 项新修通过、无新缺陷。
- §6.4 列出的项**未在本机验证**，不得视为已通过（Android 真机 E2E 已由真机复验补齐，不再列入）；完整放行建议见 [`FINAL-ACCEPTANCE.md`](FINAL-ACCEPTANCE.md) §6。
