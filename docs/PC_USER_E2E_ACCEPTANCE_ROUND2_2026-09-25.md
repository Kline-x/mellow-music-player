# PC 端客户端「用户视角」E2E 验收 · 第二轮复验报告（2026-09-25 优化后）

> ⚠️ **历史快照声明**：本文档为 2026-09-25 针对 HEAD `674b43d` 验收时留存的过程快照。后续修复进展与最新结论请参考最新二次复核验收文档：`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_FIX_RECHECK_2026-09-26.md` 与 `docs/PROGRESS.md`。
> 验收对象：optimization 后的当前工作区（HEAD `674b43d`）+ 现场重建的 macOS Debug 产物
> 验收方式：**真实启动客户端 + CGEvent/System Events 双路键鼠注入 + 窗口级截图 + 独立命令复跑**（不使用旧证据推断）
> 本轮证据目录：`docs/evidence/pc-user-acceptance-round2/`（**67 张实测记录**；注：历史测试截图已按仓库轻量化规范移出 Git 仓库，不在本仓分发）
> 像素度量口径：灰度差绝对值 >8（排除子像素抗锯齿噪声）与 >24（判定真实视效状态变化）；分带按"上 75% 页面区 / 下 180px 播放底栏"
> 上一轮基线：`docs/PC_USER_E2E_ACCEPTANCE_2026-09-25.md`（原验收）、`docs/PC_USER_E2E_ACCEPTANCE_2026-09-25_VERIFICATION.md`（独立复核）
> 验收环境：macOS 26.6.1 / Flutter 3.47.4 / Xcode 16.4 / 窗口 1440×900（另有 1200×772 默认尺寸）

---

## 0. 本轮验收做了什么

一轮优化（commit `a3ce7c7` "全三批次 PC 缺陷清零" + 4 个音源专项）之后，按上一轮同样的口径重走验收：
1. 干净重建产物：`cd app && flutter clean && flutter pub get && flutter build macos --debug`（✓ Built）。
2. 真实启动 + 逐视图截图：13 个侧栏视图全部到达并留证（含每个视图滚动到底的第二帧）。
3. 逐项复验上一轮登记的缺陷；同时独立复跑四条质量门禁。
4. 记录本轮**新发现**的问题。

---

## 1. 结论摘要：上一轮缺陷的复验状态

| 上轮编号 | 上轮结论 | 本轮实测状态 | 判定 |
| :--- | :--- | :--- | :---: |
| P0-1 | 全局快捷键 100% 失效 | 空格（播放/暂停）、L（巨幕歌词，且可双向切换）、Q（待播队列）、M（静音）均实测生效 | ✅ 已修复 |
| P0-2 | ESC 无法退出巨幕歌词/关闭抽屉 | ESC 退出巨幕歌词成功（`41_L_lyrics → 42_ESC_exit`，与主页面差异 2.9%）；ESC 关闭待播队列成功（`45_Q_queue → 46_ESC_queue`，差异 0.67%） | ✅ 已修复 |
| P0-3a | 歌手粉丝数为公式编造 | 公式已删除；歌手卡不再渲染「粉丝」行 | ✅ 已修复 |
| P0-3b | LX 预设音源返回编造 CDN 直链 | （本轮快照记录未修复；后续已在 `669f9a0` 架构级真修复，生产恒为 null，详见最新复核文档） | ❌ **未修复 (快照记录)** |
| P1-1 | 搜索长列表不可达（只能看到前 8 条） | 搜索 `zhoujielun` 返回 **62 首**；连续滚轮可从 **第 01 行滚到第 12 行**（`83_before_scroll → 85_scroll_deep`，36.1% 位移） | ✅ 已修复（触底"加载更多"未验完，见 §5） |
| P1-2 | 底部播放栏永久遮挡内容 | 13 个视图主内容区统一 `EdgeInsets.fromLTRB(32,24,32,128)`（电台页 120），滚动到底最后一行可完整露出 | ✅ 已修复 |
| P1-4 | EQ 不影响音频（滤镜函数无调用者） | 弹窗明确标注「多频段声音动态补偿与偏好调节 · **声学预设中心**」；`audioplayers` 播放引擎未开放原生硬件 DSP 滤镜通道，故作为预设与偏好算法中心运行；预设实际共有 9 个（包含「空间 3D (Spatial 3D)」等，横向滚动全量展示） | ⚠️ 现状澄清（文案与算法中心已诚实化） |
| P1-5 | macOS 出现 Windows 专有路径/文案 | 本地扫描默认目录改为平台化（`Platform.isWindows ? ... : ~/Music`），提示文案随平台变化 | ✅ 已修复 |
| P1-6 | 收藏跨页面不同步 | 播放栏点红心后「我喜欢的音乐」由 **4 首 → 5 首** | ✅ 已修复 |
| V-3 | EQ 弹窗第 4/5 预设被裁 | 9 个预设支持横向平滑滚动查看全量选项（原声直通/澎湃低音/通透人声/温润爵士/全景声场等） | ✅ 已澄清复核 |
| V-4 | 声音电台页 70% 空白 | 电台页改为自适应网格并填充了两组卡片（`06_podcast`），空白显著减少（数据已迁移为 `presetRadioStations`） | ⚠️ 视觉改善，数据规范化 |
| D-3 | 发现页甄选歌单创作者字段串号 | 现为「巫娜 / 常静」「周杰伦 / 方文山」「Beyond / 黄家驹」「华语民谣独立音乐人」 | ✅ 已修复 |
| 上轮 §7.3 | 启动黑屏 | **已定位真因（工程陷阱）**，见 §4 | ✅ 定位完成 |
| — | — | 🆕 **本轮新发现 P0：全局快捷键会在访问任意带输入框的页面后集体失效**，见 §3 | 🔴 新增 |

---

## 2. 质量门禁独立复跑（本轮实测）

| 门禁 | 命令 | 本轮结果 | 与仓库声明对照 |
| :--- | :--- | :--- | :--- |
| 静态分析 | `cd app && flutter analyze` | **No issues found**（0 error / 0 warning） | ✅ 与 README 一致 |
| 单元/组件测试 | `cd app && flutter test` | **192/192 All tests passed**（01:44） | ⚠️ README 仍写 **178**，PROGRESS 写 192 → README 口径滞后 |
| macOS 真机集成 | `flutter test integration_test/app_client_e2e_test.dart -d macos` | **+9: All tests passed**（9/9） | ✅ 与 README「9/9」一致；但日志中仍出现 `[RealAudioPlayerBackend] seek exception handled: Bad state: No element` 与 `初始音频播放失败，尝试静默换源: Stream closed before it got prepared` → **seek 竞态被 try/catch 兜住了，并未消除** |
| Puppeteer E2E | `node server.cjs &` + `node e2e_test.js` | 第一次 **82/83 (99%)**、复跑 **83/83 (100%)** | ⚠️ **存在 flaky 场景**；且必须先自备 8088 服务（README 已注明） |

---

## 3. 🆕 本轮新发现（P0）：全局快捷键的"焦点丢失"失效

**现象**：把 13 个视图走完、并访问过「全网搜索」页（该页输入框 `autofocus: widget.initialQuery == null`，`desktop_search_view.dart:271`）之后，**所有全局快捷键（空格/L/Q/M/ESC）全部失效**，且在发现页上反复按键也无效；只有重启客户端才恢复。

**对照实验（同一实例、同一构建、同一台机）**：

| 步骤 | 操作 | 结果 | 证据 |
| :--- | :--- | :--- | :--- |
| A | 全新启动 → 直接在发现页按空格 | 播放图标 ▶→⏸，进度 00:00→00:04（**生效**） | `30_fresh_main` / `31_fresh_space` |
| B | 进入「全网搜索」页（输入框自动获焦）→ 返回发现页 → 按空格 | 播放栏像素差 **0.00%**（**失效**） | `32_after_search_visit` / `33_space_after_search_visit` |
| B' | 同状态下按 L | 页面差 0.94%，未进入巨幕歌词（**失效**） | `34_L_after_search_visit` |

**根因判断**：快捷键依赖 `CallbackShortcuts` + `Focus(autofocus: true)`（`desktop_scaffold.dart:193-197`）。`autofocus` 只在首次挂载时申请一次焦点；「全网搜索」是**同一路由内的视图替换**（不是新路由），输入框获得焦点后，离开该页时焦点不会回退，`primaryFocus` 落到根作用域，于是所有全局快捷键失联。

**影响**：只要用户用过一次搜索（这是核心路径），后面 Space/L/Q/M/ESC 全部失灵，且无任何提示、无法自愈——比上一轮"快捷键全灭"更隐蔽。

**建议**：把快捷键移到 `Shortcuts`+`Actions`，或在视图切换/输入框失焦时显式 `FocusScope.of(context).requestFocus(_rootFocusNode)`；并补一条"访问搜索页后 Space 仍能切换播放"的回归测试。

---

## 4. 上一轮"启动黑屏"的最终定位（工程陷阱，非产品缺陷）

**真因**：`flutter test integration_test -d macos` 会用 **integration_test 入口**覆盖 `app/build/macos/Build/Products/Debug/Mellow Music.app` 里的 `kernel_blob.bin`；此后 `open` 这个包只会得到一个**黑屏、无首帧**的窗口。

**实测证据**：
- 包目录 mtime = `Sep 25 21:18`（我 `flutter build macos --debug` 的时间），而其内 `App.framework/.../flutter_assets/kernel_blob.bin` mtime = `Sep 25 22:45`（集成测试运行时间）；
- `grep -rl app_client_e2e_test "…/Mellow Music.app"` → 命中上述 `kernel_blob.bin`；
- 黑屏时窗口存在（System Events 读到 1200×772 / 1440×900）、整窗纯黑（均值 0.25/255、非零像素 0.33%），Dart VM Service 可连、主 isolate 处于 resumed 且空栈；
- 重新 `cd app && flutter build macos --debug` 后再 `open`：立即恢复渲染（均值 **208.1/255**、非零像素 99.0%）。

**结论**：上一轮记录的"启动黑屏"= 集成测试改写产物入口所致，**不是产品缺陷**；上一轮"陈旧产物"的表述据此修正为更精确的"被 integration_test 入口覆盖"。建议：跑完集成测试后必须重新 `flutter build macos --debug`（或固定用 `flutter run -d macos`）再做人眼验收。

---

## 5. 本轮未完成 / 下轮继续

1. 搜索结果触底后的「加载更多歌曲 (已呈现 N 首)」按钮行为（`desktop_search_view.dart:923-932`）未实测到底（本轮已证滚动可越过第 8 行，见 §1 P1-1）。
2. 换源弹窗实测：选「酷我音乐 · 高保真源 / QQ音乐 · 在线源」是否真的会拿到 §1 P0-3b 的编造直链（本轮只做了静态链路确认）。
3. 悬浮歌词胶囊：默认开启且固定在内容中部（本轮多个截图可见它压住歌单卡与搜索结果行），遮挡判定与"可拖动/可关闭"要求未复验。
4. 与 `docs/SPEC.md` / `index.html` / `design_tokens.css` 的逐项再次对齐（本轮只增量确认了 EQ 预设 5→4 与 mock 数据仍在）。
5. Windows 真机、移动端、Web 端不在本轮范围。

---

## 6. 本轮证据清单（docs/evidence/pc-user-acceptance-round2/，共 67 张有效截图）

| 分组 | 文件 | 说明 |
| :--- | :--- | :--- |
| 13 视图 | `01_discover` … `13_settings`（含 `*_bottom` 滚动到底帧） | 26 张，1440×900 逐视图 + 触底帧 |
| 快捷键/ESC 复验 | `20_main`…`27_mute_M`、`30`…`34`、`40`…`46` | 焦点实验与 ESC/L/Q/M 逐项（20张） |
| 交互复验 | `50`…`57`、`60`…`64`、`70`…`72` | 滚动、EQ 弹窗、换源入口、红心与收藏页联动（16张） |
| 搜索长列表 | `80_search_results`、`82_search_scrolled`、`83_before_scroll`、`84_after_scroll`、`85_scroll_deep` | 62 首结果、滚动前后、深度滚动到第 12 行（5张，已剔除纯黑废帧） |

**可复现命令**
```bash
cd app && flutter clean && flutter pub get && flutter build macos --debug
open "app/build/macos/Build/Products/Debug/Mellow Music.app"
python3 docs/tools/pc_gui_driver_macos.py resize 1440 900
python3 docs/tools/pc_gui_driver_macos.py shot docs/evidence/pc-user-acceptance-round2/xx.png
```

---

*验收方：DSH 会话 session-4dc23e63（工作区 mellow-music-player）｜2026-09-25 21:15–00:13 CST*