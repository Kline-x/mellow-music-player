# E2E 验收缺陷账本 — 桌面端 (Desktop)

> 负责人：子 Agent A ｜ 覆盖范围：`app/lib/navigation/desktop_scaffold.dart`、`app/lib/views/desktop/*`、`app/lib/views/common/modals.dart`（桌面端弹窗）、`app/lib/core/audio/*`、`app/lib/design_system/*` 中影响桌面端体验的部分。
> 格式与取证规则：`docs/e2e/FORMAT.md`。

## 0. 取证环境、基线与复现方式（先读）

- **平台/工具链**：macOS（darwin，Apple Silicon），Flutter 3.47.4 stable（Dart 3.13.3），取证时间 **2026-09-23 00:05 ~ 00:16 CST**。
- **仓库基线**：`git rev-parse HEAD` = `21ecef88415458a4b1cd3dd3e2ad0e1960790cff`（`fix(experience): 真实使用者视角全链路走查与 14 项体验交互缺陷修复闭环`）+ **工作区未提交改动**。
- **并发修改声明（重要）**：取证期间主 Agent 正在并发修复 `app/lib`，我记录行号时所依据的文件哈希如下（任何后续改动都会使行号失效，请以哈希为准重新核对）：

| 文件 | 取证时 sha1 |
| :--- | :--- |
| `app/lib/navigation/desktop_scaffold.dart` | `492f8e723a91c827226bb8fd672c158c0ef2226d` |
| `app/lib/views/desktop/desktop_views.dart` | `b1aa4025f6c7a0acae6cd5c5553160600b87decb` |
| `app/lib/views/desktop/fullscreen_lyrics_view.dart` | `5ed8e6e8aad4c6c5b376f6d263432c75ab0f434f` |
| `app/lib/views/common/modals.dart` | `e291896af98ce3584406cdc91e8b672c644889c4` |
| `app/lib/core/audio/audio_player_service.dart` | `6b858e2b7fc63148a2bd988a15fc659e70e54415` |
| `app/lib/core/audio/equalizer_manager.dart` | `64d26722a09617c4a73ae28a17d18a3af178ae0d` |
| `app/lib/core/sources/online_music_service.dart` | `6bc82a90b9226cf30b750aedfa18db866c6b8808` |
| `app/lib/core/audio/track_model.dart` | `b2ba09ed1bb198bd2747cb3e41bd7d66d043e72e` |
| `app/lib/navigation/adaptive_scaffold.dart` | `3a1112941e4c47fed1239218cc15daefeb9e1463` |
| `app/lib/design_system/soft_button.dart` | `6345d1332af2fa0e6474db879e07851421fc1b12` |
| `app/lib/design_system/mellow_image.dart` | `929859999def8217cde24e8aa32d71aa9ca8642b` |
| `app/lib/design_system/acoustic_mesh_glow.dart` | `737933da4aee8e08b533e89434d379ce8ef11c2f` |

- **探针工程（临时，位于 `/tmp`，未污染仓库）**：`/tmp/desk_probe`（`pubspec.yaml` 以 path 依赖 `mellow_music`），含
  - `test/desk_probe_test.dart`：快捷键 / 播放栏 / 历史栈 / 歌词 / EQ / 导入 / 定时器 / 队列 / 溢出（摘要）
  - `test/desk_overflow_test.dart`：14 视图 + 5 弹窗 + 脚手架 × 1440×900 / 1024×640 / 800×600 / 600×800 / 360×640，捕获 `FlutterError` 并解析 `RenderFlex overflowed by N pixels` 与 `The relevant error-causing widget was … file:line`
  - `test/desk_esc_test.dart`：ESC 语义与输入框焦点隔离（长 pump 等待弹窗动画）
  - `test/desk_queue_test.dart`：队列抽屉与清空后底栏
  - 复现：`cd /tmp/desk_probe && flutter test test/desk_probe_test.dart test/desk_overflow_test.dart test/desk_esc_test.dart test/desk_queue_test.dart`
- **网络裸测（真实 curl）**：网易云 `/api/search/get/web` → HTTP 200（真实歌曲）；`/api/playlist/detail?id=3778678` → HTTP 200（200 首）；`/api/song/lyric` → HTTP 200（含 lrc + tlyric）；`song/media/outer/url?id=186016.mp3` → **302 → http://music.163.com/404**；iTunes `/search` → HTTP 200，`previewUrl` 实测 HTTP 200 `audio/x-m4p`（可播放）。

---

## 1. 缺陷清单

### [DESK-001] 全屏歌词打开后，全局快捷键全部失效（含界面文案承诺的 ESC 退出）

- **编号**：DESK-001
- **严重度**：P1
- **类别**：交互缺陷 / 文案不诚实
- **用户可见现象**：点击底栏歌词按钮（或按 L）进入巨幕全屏歌词后，按 ESC 无法退出（右上角 tooltip 明写"退出全屏 (ESC)"）、按空格无法播放/暂停、按 M/L/Q 全部无反应；只能用鼠标点右上角的关闭按钮才能返回。同一屏内"文案承诺的能力"与"实际按键行为"直接矛盾。
- **复现步骤**：1. 1440×900 启动桌面壳；2. 点击底部播放栏"展开巨幕全屏歌词"按钮（或按 L）；3. 按 ESC（等待 ≥900ms 动画后观察）→ 仍在全屏歌词；4. 按空格 → 播放状态不变；5. 点击右上角"退出全屏 (ESC)"按钮 → 正常返回。
- **代码证据**：`app/lib/navigation/desktop_scaffold.dart:81-85` 在构造 `CallbackShortcuts` **之前**就 early-return 了全屏歌词视图：
  ```dart
  if (_isFullscreenLyrics) {
    return DesktopFullscreenLyricsView(onClose: () => setState(() => _isFullscreenLyrics = false));
  }
  ```
  于是 `desktop_scaffold.dart:87-125` 的全部 10 条 `SingleActivator` 绑定与 `desktop_scaffold.dart:127-130` 的 `CallbackShortcuts`/`Focus(autofocus: true)` 都不在挂载树上；`DesktopFullscreenLyricsView` 自身不含任何 `Focus`/`Shortcuts`（`fullscreen_lyrics_view.dart:79-274`），ESC 绑定 `desktop_scaffold.dart:118-124` 因此永远收不到按键。三处承诺文案：`fullscreen_lyrics_view.dart:104` `tooltip: '退出全屏 (ESC)'`、`desktop_views.dart:1439` `_buildShortcutChip('ESC', '退出全屏 / 关闭抽屉', …)`、`desktop_views.dart:1437` `'L' → '巨幕动效歌词'`。
  探针实测（`desk_esc_test.dart`）：`lyricsAfterMouseClick=1` → `spaceInLyrics was=false now=false` → `escapeInLyrics stillLyrics=1` → `onScreenClose stillLyrics=0`。
- **数据真实性**：不涉及数据，属交互实现缺失（快捷键在桌面壳存在、在全屏歌词不存在）。
- **原型/文档依据**：`index.html:3190-3249` 原型把快捷键监听挂在 `window` 上（`toggleLyricsScreen()` 后监听依然生效，ESC 能退出歌词屏）；`docs/SPEC.md:138` 只描述全屏歌词内容，未声明快捷键失效；`docs/PC_E2E_FIX_PLAN.md:693` 明确要求"ESC 关弹窗/退出歌词"作为可测验收标准。
- **建议修复**：把 `CallbackShortcuts` + `Focus` 提到 `_isFullscreenLyrics` 判断**之外**（即在 `build` 里先包 `CallbackShortcuts`，内部再决定返回哪种子视图），并让 `DesktopFullscreenLyricsView` 自带 `Focus(autofocus: true)`；同时给全屏歌词补 Space/方向键的本地处理。
- **可验收标准**：widget 测试：泵入 `DesktopScaffold` → `sendKeyEvent(keyL)` → 断言 `DesktopFullscreenLyricsView` 存在 → `sendKeyEvent(escape)` → `pumpAndSettle`（注意 `AcousticMeshGlow` 无限动画，应用 `pump(1s)`）→ 断言 `find.byType(DesktopFullscreenLyricsView)` 为空；再加一条 `sendKeyEvent(space)` 断言 `player.isPlaying` 翻转。
- **状态**：已修复
- **复审证据**：desktop_scaffold.dart:122-129 将 CallbackShortcuts+Focus 提到全屏判断之外；fullscreen_lyrics_view.dart:114-127 自带 ESC/Space/M/L/方向键绑定。验证方式：读码 + flutter analyze 无问题。

### [DESK-002] EQ 弹窗是"死开关"：10 频段增益/预设/开关不进任何音频链路，界面仍宣称"声学校准 / DSP EQ"

- **编号**：DESK-002
- **严重度**：P1
- **类别**：功能缺失 / 文案不诚实
- **用户可见现象**：拖动 10 个频段滑块、切换"澎湃低音/通透人声"等预设、打开/关闭"均衡器已启用"开关，**声音完全无变化**；而弹窗标题写着"声学 10 频段均衡器 (EQ)""多频段声音动态补偿与声学校准"，底栏按钮 tooltip 写着"10 频段专业声学 EQ"。
- **复现步骤**：1. 播放任意曲目；2. 点底栏 EQ 按钮；3. 拖动 31Hz 到 +12dB、点"澎湃低音 (Bass Boost)"；4. 听感与播放器后端调用均无变化。
- **代码证据**：`app/lib/core/audio/equalizer_manager.dart:51-57` `setBandGain()` 只改内存列表并 `notifyListeners()`；`:59-81` `applyPreset()` 同上；`:87-99` 的滤镜串方法（现名 `toDspFilterDescription()`，哈希变动前为 `toLibmpvFilterString()`）在 `app/lib` **仅 1 处命中（定义处本身）**，全仓（含测试）0 调用方：`grep -rn "toDspFilterDescription\|toLibmpvFilterString" app` → 仅 `equalizer_manager.dart:89`。`EqualizerManager` 只被 `main.dart:18`（provide）、`modals.dart:166,273`（UI 读写）、`sync_data_model.dart:227`（快照）引用，**与 `AudioPlayerBackend`/`RealAudioPlayerBackend` 之间没有任何调用链**（`player_backend.dart:7-19` 接口无任何 EQ 相关方法）。
  探针实测（`desk_probe_test.dart` EQ 用例）：`preset=EqualizerPreset.custom g0=9.0 filter=[firequalizer=gain='gain_interpolate(31,9.0)+…'] backend=`（**后端调用记录为空**）。
  同时 `equalizer_manager.dart:16-22` 已由主 Agent 补上诚实注释"bandGains 不会改变实际输出声音…UI 必须向用户明确标注"，但 UI 文案未同步：`modals.dart:203` `'声学 10 频段均衡器 (EQ)'`、`modals.dart:212` `'多频段声音动态补偿与声学校准'`、`desktop_scaffold.dart:721` `tooltip: '10 频段专业声学 EQ'`。
- **数据真实性**：不涉及数据；属"能力宣称与实现矛盾"（当前引擎 audioplayers 无 DSP 能力）。
- **原型/文档依据**：`docs/SPEC.md:198-208` 规定"通过 media_kit 向 libmpv 动态挂载 lavfi firequalizer 滤镜"；`docs/SPEC.md:451`（E2E-05）要求"实时生成 libmpv firequalizer 参数，音色变化平滑"；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:507-514`（P1-09）已判定"EQ 无 DSP 链路"，`docs/PC_E2E_FIX_PLAN.md:375-386`（阶段 1.3）要求"接到真实滤镜，**或降级标注"未实现"**"。当前只做到 manager 内部注释，用户可见层未标注。
- **建议修复**：① 在 EQ 弹窗顶部加显式提示条（如"当前音频引擎不支持实时音效，以下调节仅预览，不会改变声音"）并把底栏 tooltip 改为"10 频段均衡器（暂不支持实时生效）"；② 或在 UI 上直接禁用滑块（`onChanged: null`）直到接入 DSP。
- **可验收标准**：`grep -rn "不支持实时音效" app/lib` 命中 ≥1 处且位于 `EqualizerModal` 渲染树内；widget 测试断言打开 EQ 弹窗后 `find.textContaining('不支持实时音效')` 非空。
- **状态**：已修复
- **复审证据**：modals.dart:212 明示「当前音频引擎不支持实时音效，调节仅记录参数、暂不改变声音」；desktop_scaffold.dart:767 tooltip 同步为「10 频段 EQ（当前引擎不支持实时音效）」。验证方式：读码。

### [DESK-003] 底栏与全屏歌词的"时长/进度上限"取自编造元数据 `track.duration`，不使用真实音频时长；iTunes 30 秒试听被显示为整曲时长

- **编号**：DESK-003
- **严重度**：P1
- **类别**：数据造假 / 交互缺陷
- **用户可见现象**：底栏右侧时长与进度条满量程来自曲目元数据里的编造时长。播放"云水禅心"时，真实音频（SoundHelix demo，实测后端上报 3:30）却在界面写 `04:28`；导入/搜索到的 iTunes 曲目只播放 **30 秒试听**，但界面显示整曲时长（例如 `05:19`）——进度条几乎不动、永远走不到头，到 30 秒却突然切歌。
- **复现步骤**：1. 播放任一预置曲目；2. 观察底栏时长 `04:28` 与真实音频（3:30）不符；3. 在搜索浮层搜索并播放一首 iTunes 结果（`trackTimeMillis` = 整曲时长，`previewUrl` = 30 秒）；4. 观察进度条比例失真、30 秒后触发 `onPlayerComplete`。
- **代码证据**：
  - 底栏：`desktop_scaffold.dart:510` `final track = player.currentTrack ?? mockPresetTracks[0];`；`:688-690` 滑块 `value/max` 用 `track.duration.inMilliseconds`；`:704` 时长文案 `track.formattedDuration`。
  - 全屏歌词：`fullscreen_lyrics_view.dart:189-190` 同样用 `track.duration`。
  - 真实时长其实已存在但桌面端不用：`audio_player_service.dart:55` `Duration get duration => _duration > Duration.zero ? _duration : (currentTrack?.duration ?? Duration.zero);`，`_duration` 由 `_backend.onDurationChanged` 写入（`audio_player_service.dart:169-174`）；全仓只有移动壳用了它（`mobile_scaffold.dart:196`）。
  - 元数据来源：`track_model.dart:118-120` 等 33 首全部写死 `duration` 并指向 16 个 SoundHelix demo；`online_music_service.dart`（新 iTunes 实现）把 `trackTimeMillis`（整曲）写入 `Track.duration`，而 `audioUrl` 是 30 秒 `previewUrl`（该文件注释自称"30 秒试听直链"）。
  - 探针实测：`duration realMs=210000 trackMetaMs=268000 shown=04:28`。
- **数据真实性**：时长是**编造/不匹配**的元数据（与真实播放资源长度不一致），真实值就在内存里却未用于桌面 UI。
- **原型/文档依据**：`docs/SPEC.md:171-196`（分级双流）要求进度/时长来自真实播放流；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:664-679`（P2-04）已指出播放状态机边界问题。
- **建议修复**：底栏与全屏歌词的 `max`/`value` 与时长文案改用 `player.duration`（>0 时）并保留元数据兜底；对试听源在 UI 上明确标注"30 秒试听"。
- **可验收标准**：在 `InMemoryAudioPlayerBackend`（固定 3:30）下播放 `track-1`，widget 测试断言底栏显示的时长字符串为 `03:30` 而非 `04:28`；或断言 `Slider.max == player.duration.inMilliseconds`。
- **状态**：已修复
- **复审证据**：desktop_scaffold.dart:518/726-729/746-750 与 fullscreen_lyrics_view.dart:140/286-290 的进度上限与时长文案均改用 player.duration。验证方式：读码。

### [DESK-004] 桌面端 13 处 `ListView(children:)` + `shrinkWrap` 网格：无任何列表虚拟化

- **编号**：DESK-004
- **严重度**：P1（当前数据量小无感，接真实曲库即卡死/爆内存）
- **类别**：工程卫生 / 性能
- **用户可见现象**：导入 200 首歌单或接入真实曲库后，列表页首帧构建全部子项、滚动卡顿、内存随列表长度线性增长。
- **复现步骤**：1. 打开"播放历史"（若已有数十条）或导入歌单页；2. DevTools Performance 观察首帧构建数量 = 全部条目数；3. 代码检查列表构造方式。
- **代码证据**：`grep -n "ListView(" app/lib/views/desktop/desktop_views.dart` → `23, 295, 449, 675, 741, 862, 924, 1043, 1170, 1251, 1298, 1489, 1581`（13 处，均为 `ListView(children: [...])`）；内嵌网格全部 `shrinkWrap: true` + `NeverScrollableScrollPhysics`（`desktop_views.dart:141-147`、`:324-332`、`:478-486`、`:680-688`、`:867-875`），即网格项也全量构建；歌手详情代表作用 `...List.generate(artist.tracks.length, …)`（`:817-845`）；侧边栏 `desktop_scaffold.dart:417` 同为 `ListView(children:)`。唯一用了 builder 的是 `modals.dart:89`（队列）与 `:675`（搜索结果）。
- **数据真实性**：不涉及。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:700-703`（5.5 P2-01）要求"改为 `CustomScrollView` + `SliverList/SliverGrid`（去掉 shrinkWrap），至少改 `ListView.builder`"；`docs/SPEC.md:149` 的"数十万曲库毫秒级检索"目标与一次性构建互斥。当前仍为修复前状态。
- **建议修复**：主视图改 `CustomScrollView` + `SliverList/SliverGrid`；有界高度的内嵌网格去 `shrinkWrap` 或改 `SliverGrid`；`tracks.take(5)` 改懒加载全量。
- **可验收标准**：`grep -c "ListView(" app/lib/views/desktop/desktop_views.dart` 中不带 `.builder/.separated` 的用法为 0；或 widget 测试断言构建 1000 条列表时 `find.byType(SoftCard)` 的元素数 < 100（非可见区域未构建）。
- **状态**：已修复
- **复审证据**：desktop_views.dart:23-48 _virtualizedList、:214/:414/:800 等 Sliver 网格，发现歌单/歌单广场/榜单/歌手/代表作/收藏/导入/历史/本地/音源等长列表全部 builder/sliver。残留 4 处 ListView( 为榜单/电台/设置/同步等固定少量卡片页与 12 项侧边栏，非长列表。验证方式：读码 + grep。

### [DESK-005] "本地与下载"整页是死模块：无文件选择/目录扫描/拖拽导入能力，却写着支持 FLAC/WAV/MP3

- **编号**：DESK-005
- **严重度**：P1
- **类别**：功能缺失 / 与文档不符
- **用户可见现象**：进入"本地与下载"，只有一个图标 + 文案"本地音频导入与目录扫描 / 支持 FLAC, WAV, MP3 等格式（功能正在接入中）"和一个按钮"本地扫描接入中"；点击只弹 SnackBar"本地文件与目录扫描功能正在接入中..."，页面下方永久显示"本地曲库暂无内容"。全页无任何文件选择器、拖拽区、扫描入口。
- **复现步骤**：1. 侧边栏点"本地与下载"；2. 点击"本地扫描接入中"；3. 观察只出现 SnackBar，无文件对话框；4. 尝试拖拽音频文件到页面 → 无反应。
- **代码证据**：`desktop_views.dart:1243-1286`：`:1265` `'支持 FLAC, WAV, MP3 等格式（功能正在接入中）'`；`:1267-1277` 按钮 `onTap` 仅 `ScaffoldMessenger…showSnackBar('本地文件与目录扫描功能正在接入中...')`；`:1282` `'本地曲库暂无内容'`。全文件无 `FilePicker`/`DragTarget`/`dart:io` 引用（`grep -n "FilePicker\|DragTarget" app/lib` → 0 命中）。`Track.localPath` 字段（`track_model.dart:56`）无任何写入点。
- **数据真实性**：该页无数据可造假，是**真·功能缺失**（按钮本身是死按钮，但文案诚实写了"接入中"）。
- **原型/文档依据**：`docs/SPEC.md:136`（`viewLocal`）声称"拖拽/点击导入音频文件（FLAC/APE/MP3/WAV）、比特率解析、离线曲库回放"；`docs/ROADMAP.md:62` 标注"✅ 1:1 对齐"；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:341-357`（P0-08）已判定不可用，状态未变。
- **建议修复**：要么接入 `file_picker`+扫描（写入 `Track.localPath` 并落盘），要么把页面降级为纯说明页并删除"支持 FLAC/APE…"的能力宣称。
- **可验收标准**：点击"本地扫描"能打开系统文件选择器且在选中 mp3 后曲目出现在列表中并可从磁盘播放（`audioUrl == null && localPath != null` 的 Track 出现在 `getAllKnownTracks()`）。
- **状态**：已修复
- **复审证据**：desktop_views.dart:2 引入 file_picker、:1958 FilePicker.pickFiles；core/sources/local_music_service.dart 真实导入并落盘。验证方式：读码。

### [DESK-006] "LX 音源管理"整页是死模块：仅 1 个 SnackBar + 1 张静态卡片

- **编号**：DESK-006
- **严重度**：P1
- **类别**：功能缺失 / 与文档不符
- **用户可见现象**：进入"LX 音源管理"，只有标题"自定义音源管理 / 支持扩展音源解析脚本（功能接入中）"、"在线导入音源"按钮（点击弹 SnackBar"自定义音源在线导入功能接入中..."）和一张写死"网易云在线开放音源 (Built-in)"的卡片。无脚本列表、无导入、无开关、无可用性测试。
- **复现步骤**：1. 侧边栏点"LX 音源管理"；2. 点"在线导入音源"；3. 仅出现 SnackBar；4. 尝试寻找脚本列表/启用开关 → 不存在。
- **代码证据**：`desktop_views.dart:1481-1542`：`:1499` 文案、`:1502-1512` 死按钮（仅 SnackBar）、`:1516-1538` 静态卡片。`lx_script_sandbox.dart`（1227 行）在 `app/lib` 内 **无生产调用方**（FORMAT.md 第 4 节基线已确认，本轮未复验）。
- **数据真实性**：功能缺失；卡片文案"支持在线搜索与公开歌单导入解析"倒是指向了真实存在的 OnlineMusicService。
- **原型/文档依据**：`docs/ROADMAP.md:65` 标注"✅ 深度集成"、`:102` 声称"集成 flutter_js QuickJS 运行时沙箱…脚本链接一键导入与测试"；`docs/SPEC.md:139/212-249` 有完整沙箱与脚本协议规范；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:323-340`（P0-07）已判定为空壳。ROADMAP 的"✅"与实现矛盾。
- **建议修复**：删除 ROADMAP 的"深度集成"标注，或真正接入脚本列表/导入/热重载/测试；页面文案去掉"支持扩展音源解析脚本"。
- **可验收标准**：`grep -rn "LxScriptSandbox\|lx_script_sandbox" app/lib --include=*.dart | grep -v "core/sources/lx_script_sandbox.dart"` 命中 ≥1 个 UI/服务调用点。
- **状态**：已修复
- **复审证据**：DesktopSourceManagerView（desktop_views.dart:1910 起）真实脚本本地导入/在线订阅/启停/可用性测试。验证方式：读码。

### [DESK-007] "多端同步中心"整页不可用，且同页文案自相矛盾（"实时双向热备"vs"功能接入中"）；core/sync 两个真实服务零引用

- **编号**：DESK-007
- **严重度**：P1
- **类别**：功能缺失 / 文案不诚实 / 与文档不符
- **用户可见现象**：页面副标题写"支持 WebDAV 私有云盘实时双向热备，与局域网近场毫秒级 P2P 跨端流转"，同一屏的卡片副标题却写"支持标准 WebDAV 协议（功能接入中）""局域网近场设备协同…（功能接入中）"；"立即云端备份""从云端恢复"点击只弹"尚未完整接入，请勿依赖此页面备份数据"；云端端点固定显示"未配置端点 (例如 https://dav.jianguoyun.com/dav/)"、账号"未绑定账号"、状态"未配置"，无任何可编辑控件（纯静态常量）。
- **复现步骤**：1. 侧边栏点"多端同步中心"；2. 点"立即云端备份" → SnackBar"尚未完整接入"；3. 点"从云端恢复" → SnackBar"尚未完整接入"；4. 寻找配置 WebDAV/扫码配对的入口 → 不存在。
- **代码证据**：`desktop_views.dart:1545-1845`：`:1554-1556` `final String _syncStatusText='未配置';` / `_serverUrl='未配置端点…'` / `_username='未绑定账号';`（`final` 常量，页面永远无法进入"已配置"态）；`:1558-1570` 两个 `_triggerUpload/_triggerRestore` 仅弹 SnackBar；`:1592` 副标题"实时双向热备/毫秒级 P2P"；`:1718` 与 `:1808` 写"（功能接入中）"；`:1717-1737` 状态徽标写死"待配置"；`:1820-1838` 设备列表为写死的空状态卡片。`core/sync/webdav_sync_service.dart`（410 行，真实 HTTP PROPFIND/MKCOL）与 `lan_sync_service.dart`（513 行）在本轮取证前无任何 UI/服务引用（FORMAT.md 第 4 节基线）。
- **数据真实性**：无假数据成功态（这点是诚实的），但**页面级能力宣称与实现矛盾**，且"实时双向热备""毫秒级 P2P"属未实现的营销文案。
- **原型/文档依据**：`docs/ROADMAP.md:104` 声称"1. WebDAV：配置坚果云/Nextcloud/群晖，实现歌单增量双向加密同步；2. 局域网直连 (LX-Sync)：…移动端扫码瞬间同屏互传歌单"；`docs/SPEC.md:281-365` 有完整 Drift 与 LX-Sync 协议规范；`docs/PC_E2E_FIX_PLAN.md:612-633`（阶段 4.1）要求"多端同步（P0-03 + P0-04）"落地或删除。
- **建议修复**：二选一：① 接入 `WebdavSyncService`（可编辑端点/账号/密码 + 真实上传下载 + 失败提示）；② 把副标题改为"云端与局域网同步（规划中）"并删除"实时双向热备/毫秒级 P2P"表述，保留 SnackBar 的诚实提示。
- **可验收标准**：配置一个真实 WebDAV 端点后点"立即云端备份"，能在服务端看到 `mellow_sync.json` 落盘并返回成功/失败原因；或 `grep -c "实时双向热备" app/lib/views/desktop/desktop_views.dart` == 0。
- **状态**：已修复
- **复审证据**：DesktopSyncView（desktop_views.dart:2407 起）真实 WebDAV（PROPFIND/MKCOL/PUT/GET）与 LAN HttpServer 扫描，失败如实展示。验证方式：读码。

### [DESK-008] 桌面端播放量/更新时间/听众数/粉丝数全是编造常量，且与真实数据量矛盾（榜单写"100首"实际每榜 5 首）

- **编号**：DESK-008
- **严重度**：P1
- **类别**：数据造假
- **用户可见现象**：发现页歌单卡写"48.6万播放 · 巫娜 / 常静""129.4万播放";歌单广场每张卡右上角"184.2万""92.6万"…；巅峰榜卡片写"每日09:00更新 · 100首""每周四更新 · 200首"；歌手卡写"粉丝 128.5万"；电台卡写"24.8万在听""58.2万在听"。这些数字没有任何数据源，且榜单"100首"与点开后的 5 首明显不符。
- **复现步骤**：1. 打开"发现音乐"看推荐歌单播放量；2. 打开"歌单广场"看卡片角标；3. 打开"巅峰榜单"，读卡片"每日09:00更新 · 100首"，点击后右侧 Top5 与列表实际只有 5 首；4. 打开"热门歌手"看粉丝数。
- **代码证据**：`desktop_views.dart:152` `'48.6万播放 · 巫娜 / 常静'`、`:159`、`:166`、`:173`；`:414-447` 四个榜单的 `title/desc/update/badge` 全部硬编码（`:418` `'每日09:00更新 · 100首'`、`:426` `'每周四更新 · 200首'`）；`:493` `toplistTracksMap[chartTitle] ?? mockPresetTracks`；`:711` `'粉丝 ${a.fans}'`；`:897` `r.listeners`。数据源：`track_model.dart:525/579/604/657` 四个榜单各 5 首；`track_model.dart:894` `playCount: '184.2万'`；`:775` `listeners: '24.8万在听'`；`:479-505` 歌手 `fans` 常量。
- **数据真实性**：**全部为编造常量**（第一优先级判定项）。真实播放量/粉丝数/更新时间/在听人数无任何来源。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:789-812`（假数据总账 A/C 节）已登记；`docs/SPEC.md:130` 描述巅峰榜为真实内容模块。FORMAT.md 第 4 节已确认内置曲库为编造元数据。
- **建议修复**：删除全部编造数字，改为真实可得的字段（如"共 5 首"）；无法获得的（播放量/更新时间/在听）直接移除或标注"示例数据"。
- **可验收标准**：`grep -nE "[0-9]+\.[0-9]+万" app/lib/views/desktop/desktop_views.dart app/lib/core/audio/track_model.dart` 命中 0（或全部位于显式标注"示例数据"的常量块内）。
- **状态**：已修复
- **复审证据**：track_model.dart:199/229-230 编造曲库/歌手/电台均为空；desktop_views 内无「万」级编造数字。验证方式：grep 0 命中 + 读码。

### [DESK-009] 导入的外部歌单，每一首的 `audioUrl` 都指向已失效的网易云直链（实测 302→404）——"导入成功但点哪首都不响"

- **编号**：DESK-009
- **严重度**：P1
- **类别**：数据造假 / 功能缺失
- **用户可见现象**：导入网易云公开歌单（如 3778678）后，卡片显示"共解析成功 200 首高保真曲目"，但点任意一首播放都会失败（新代码会弹"音频加载失败"提示，旧代码是静默无声）；文案"高保真"与实际不符。
- **复现步骤**：1. 顶栏"导入歌单" → 输入 3778678 → 解析；2. 出现歌单卡（真实 200 首，标题/歌手为真实数据）；3. 点"一键全部播放"或任意曲目 → 无声音/播放失败提示；4. `curl -I 'https://music.163.com/song/media/outer/url?id=186016.mp3'` → 302 → `http://music.163.com/404`。
- **代码证据**：`app/lib/core/sources/online_music_service.dart`（哈希 `6bc82a90`）中导入链路仍在使用失效直链：搜索结果已改用 iTunes `previewUrl`（该文件注释明确写了"历史实现（已删除）：调用网易云 `song/media/outer/url?id=` 直链，该直链实测已失效（302 → HTML 404）"），但同一文件的 `importNeteasePlaylist` 仍保留 `audioUrl = 'https://music.163.com/song/media/outer/url?id=$id.mp3'`（原读取行为 `online_music_service.dart:132`，改写后位于导入分支内，可用 `grep -n "song/media/outer/url" app/lib/core/sources/online_music_service.dart` 定位）。UI 侧：`modals.dart:796` 调用导入、`:824` 失败文案、`desktop_views.dart:1117` `'包含 ${pl.trackCount} 首完整音轨 · ${pl.description}'`、`desktop_views.dart:1126` `playPlaylist(pl.tracks)`；探针实测导入在离线环境下走真实失败分支（`import err=true`）。
- **数据真实性**：曲目元数据（标题/歌手/时长/封面）**来自真实接口**（我实测 200 首 + `picUrl` 存在），但音频直链是**死链**，因此"可播放"是假的。
- **原型/文档依据**：`docs/SPEC.md:136-137` 与 `docs/ROADMAP.md:103` 声称外部歌单"自动解析歌曲名与歌手列表，并利用当前可用音源全网搜索匹配并建立本地歌单"——即应当**再用可用音源匹配到可播地址**，当前实现没有这一步；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:53` 已登记网易云直链 302→404。
- **建议修复**：导入后用 ITunes/其他可用源按"标题+歌手"匹配 `previewUrl`（匹配不到就标灰并提示"暂无可播源"），或直接去掉无法播放的曲目并如实显示导入数量。
- **可验收标准**：导入 3778678 后随机抽 3 首，每首的 `audioUrl` 请求返回 HTTP 200 + `audio/*`；或列表页对无 `previewUrl` 的曲目显示"不可播放"徽标且不可点击播放。
- **状态**：已修复
- **复审证据**：全仓 grep song/media/outer/url 0 命中；导入链路改为真实可播源匹配。验证方式：grep。

### [DESK-010] 搜索浮层文案过度承诺："搜索全网歌曲、歌手、专辑" 实际只有单一 iTunes 源、无歌手/歌单聚合、无关键词高亮

- **编号**：DESK-010
- **严重度**：P2
- **类别**：文案不诚实 / 与文档不符
- **用户可见现象**：输入框提示"搜索全网歌曲、歌手、专辑 (按 ESC 退出)..."；实际结果只有歌曲（iTunes），没有歌手/歌单分组，命中关键词也不高亮；同一个搜索词在 iTunes 中文曲库命中率很低（实测"周杰伦"limit=20 仅返回 1 条），用户会以为"全网只有一首"。
- **复现步骤**：1. 点顶栏搜索框或 ⌘K；2. 输入"周杰伦"；3. 观察结果只有歌曲、无歌手/歌单分组、无高亮；4. 对照 `docs/SPEC.md:448`（E2E-02）"聚合 6 大音源结果并发返回，列表去重，关键词高亮"。
- **代码证据**：`modals.dart:595` hint 文案"搜索全网歌曲、歌手、专辑 (按 ESC 退出)...";结果渲染只遍历 `_results`（Track 列表）`modals.dart:675-752`，无分组、无 `highlightMatch` 等价实现（全仓 `grep -n "highlightMatch\|RichText\|TextSpan" app/lib/views/common/modals.dart` 0 命中）；结果来源单点：`modals.dart:551` `OnlineMusicService.searchOnlineTracks(clean)` → `online_music_service.dart:33-38` 单条 `itunes.apple.com/search`（该文件注释自述只有 iTunes 一个源，且只丢弃无 `previewUrl` 的条目）。新空态脚注 `modals.dart:687` 写"结果来自 iTunes 公开试听库（30 秒试听）"，与 hint 的"全网"口径不一致。`modals.dart:508/634-660` 的"热搜标签"是硬编码 6 个词，非真实热搜（见 DESK-023）。
- **数据真实性**：**结果数据现在是真实的**（iTunes `previewUrl` 实测可播、封面为真实 `artworkUrl100`）；问题在"全网/6 源"的宣称。
- **原型/文档依据**：`docs/SPEC.md:143` "毫秒级聚合联想歌手、歌单与单曲"；`docs/SPEC.md:448`（E2E-02）"聚合 6 大音源结果并发返回…关键词高亮"——三项（歌手/歌单聚合、6 源、高亮）均未实现。
- **建议修复**：hint 改为"搜索在线曲库（iTunes 试听）"；或补歌手/歌单分组 + 关键词高亮；SPEC 口径同步收敛为实际来源数。
- **可验收标准**：搜索"周杰伦"后结果区出现"歌曲/歌手/歌单"三个分组标题中的至少两个，且命中的关键词出现在高亮 `TextSpan` 中；或 SPEC 文案与 hint 一致（`grep -c "全网" modals.dart` 对应行改为单一来源描述）。
- **状态**：已修复
- **复审证据**：modals.dart:637 hint 改「在线曲库」、:569-596 关键词高亮、:748-803 按真实来源标注；desktop_views.dart:1901 快捷键标签改「在线曲库即时搜索」。验证方式：读码 + grep「全网」仅剩诚实说明性文案。

### [DESK-011] 窄视口 RenderFlex 溢出清单（800×600 / 600×800 / 360×640），附实测报错行号与可达性说明

- **编号**：DESK-011
- **严重度**：P2（部分场景在真实路由下不可达，见下）
- **类别**：视觉缺陷
- **用户可见现象**：窗口越窄，黄黑条纹溢出越多：360px 宽时发现页 Hero、歌手详情关注按钮行、歌单广场卡片、导入歌单页整行、同步中心三张指标卡均溢出；600px 宽时底栏右侧工具区与标题栏按钮溢出；800×600 时榜单卡片内文字列溢出 5.9px、全屏歌词左栏溢出 38px。
- **复现步骤**：1. 用探针工程按固定画布尺寸泵入各视图（`/tmp/desk_probe/test/desk_overflow_test.dart`）；2. 读取 `RenderFlex overflowed by N pixels` 与 `The relevant error-causing widget was` 的 file:line。
- **代码证据**（实测，格式：视图/尺寸 ⇒ 溢出量与创建位置）：
  - `scaffold 600x800` ⇒ 33px @ `desktop_views.dart:36`（发现页 Hero Row）、69px @ `soft_button.dart:125`（SoftButton 内部 Row 文本溢出）、57px @ `soft_button.dart:125`
  - `scaffold 360x640` ⇒ 156px @ `desktop_views.dart:30`、204px @ `desktop_scaffold.dart:531`（**底栏控制区 Row，desktop_scaffold.dart:531**）
  - `toplist 800x600` ⇒ 5.9px（纵向）@ `desktop_views.dart:533`；`toplist 600x800` ⇒ 66/32/30/36px @ `:609`、`:590`、`:533`；`toplist 360x640` ⇒ 54px @ `:503`、96px @ `:452`
  - `artists 800x600` ⇒ 19px/2.6px（纵向）@ `:695`；`artists 600x800` ⇒ 30px @ `:700`；`artists 360x640` ⇒ 25/41px @ `:700`
  - `artist_detail 360x640` ⇒ 144px @ `:787`（关注/播放按钮 Row）
  - `podcast 600x800` ⇒ 22px（纵向）@ `:889`；`podcast 360x640` ⇒ 28px @ `:884`
  - `favorite 360x640` ⇒ 201px @ `:930`；`imported 360x640` ⇒ 215px @ `:1046`
  - `settings 360x640` ⇒ 104px @ `soft_button.dart:125`（主题/明暗按钮文字）
  - `sources 360x640` ⇒ 70px @ `:1492`；`sync 800x600` ⇒ 83px @ `:1750`；`sync 600x800` ⇒ 121/12/24/12px @ `:1584`、`:1613`、`:1640`、`:1667`；`sync 360x640` ⇒ 139/155/153px @ `:1700`、`:1757`、`:1790`
  - `lyrics 800x600` ⇒ 38px（纵向）@ `fullscreen_lyrics_view.dart:120`；`lyrics 360x640` ⇒ 90px @ `:195`
  - `modal-search 800x600` ⇒ 15px（纵向）@ `modals.dart:580`；`modal-import 360x640` ⇒ 130px @ `modals.dart:825`、58px @ `:905`
  - 无溢出的：`playlists`、`history`、`local`、`modal-eq`、`modal-sleep`、`modal-queue` 在全部 5 个尺寸下均 ok；`scaffold 1024x640`、`scaffold 800x600` ok。
  - **可达性（诚实声明）**：`adaptive_scaffold.dart:14` `constraints.maxWidth >= 1024` 才进桌面壳，因此 **800/600/360 下的桌面视图与桌面脚手架在真实路由中不可达**（会切到移动壳）；但 `QuickSearchOverlay` 被移动壳复用（`mobile_scaffold.dart:71`），`EqualizerModal/SleepTimerModal` 亦然（`mobile_sheets.dart:312,320`），所以 `modal-search 800x600` 的 15px 纵向溢出在"平板/横屏 800px 宽"下是**真实可达**的；`ImportPlaylistModal` 仅桌面使用（`desktop_scaffold.dart:344`、`desktop_views.dart:974/1064/1089`），其 360px 溢出不可达。另外弹窗测量是把 `Dialog` 组件直接泵入 `Scaffold.body`（非 `showDialog` 路由），高度约束可能偏松，实际路由下量级可能略有差异（未用真实路由复现）。
- **数据真实性**：不涉及。
- **原型/文档依据**：`docs/SPEC.md:115` 断点 1024px 与 `docs/SPEC.md:454`（E2E-08）"跨越 800px 阈值"自相矛盾（该矛盾会影响上面"可达性"结论，故一并记录）；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:516-523`（P1-10）已判定极小尺寸布局崩坏。
- **建议修复**：把固定宽度行改为 `Wrap`/`Flexible`（重点：`desktop_views.dart:787`、`:930`、`:1046`、`:452/503`、`desktop_scaffold.dart:531`、`fullscreen_lyrics_view.dart:120/195`），并给 QuickSearchOverlay 内容加 `SingleChildScrollView`（消除 800×600 的 15px 纵向溢出）。
- **可验收标准**：`flutter test /tmp/desk_probe/test/desk_overflow_test.dart` 中 `modal-search 800x600`、`lyrics 800x600`、`scaffold 600x800` 三项输出 `ok`；或统一在 1024×640 与 800×600 下无 `RenderFlex overflowed`。
- **状态**：已修复（本轮复审补修同步页残留溢出与歌单广场空态）
- **复审证据**：desktop_views.dart 同步页标题/模块头改 Expanded+ellipsis（约 :2653/:2797/:3003），歌单广场补诚实空态（约 :411 起）；test/zz_desk_overflow_probe_test.dart 在 1440×900/1024×640/800×600 三档 0 条 OVERFLOW。验证方式：flutter test 该探针通过。

### [DESK-012] 清空待播队列后，底栏仍把内置示例曲"云水禅心 / 巫娜"显示为当前播放

- **编号**：DESK-012
- **严重度**：P2
- **类别**：数据造假 / 交互缺陷
- **用户可见现象**：在队列抽屉点"清空列表"后，队列变空，但底部播放栏左侧仍显示封面 + "云水禅心" + "巫娜 · 天禅 · 琴筝和鸣"，看起来像有一首在播；点播放按钮无反应（正确），但界面信息是假的。
- **复现步骤**：1. 按 Q 打开队列；2. 点垃圾桶图标清空；3. 观察底栏仍显示"云水禅心/巫娜"；4. 点播放 → 无反应、无提示。
- **代码证据**：`desktop_scaffold.dart:510` `final track = player.currentTrack ?? mockPresetTracks[0];`（队列空时回落到内置示例曲）；`audio_player_service.dart:100-103` `currentTrack` 在 `_playlist.isEmpty` 时返回 `null`；`:433-441` `clearQueue()` 清空列表并 `pause()`。探针实测（`desk_queue_test.dart`）：`emptyQueue playlist=0 currentTrack=null dockShowsMockTitle=true dockShowsArtist=true`。
- **数据真实性**：**编造**——把不存在于任何列表的示例曲显示为"正在播放"。
- **原型/文档依据**：`docs/SPEC.md:140`（queueDrawer）要求队列抽屉与正在播放指示一致；`index.html` 原型在无曲目时播放条显示空态（`updateQueueDrawer()` 与 `currentTrackIndex` 联动）。
- **建议修复**：`track` 为 null 时底栏渲染空态（无封面/标题，显示"未选择曲目"），并禁用进度条与播放按钮。
- **可验收标准**：widget 测试：`player.clearQueue()` 后 `find.text('云水禅心')` 为空且播放按钮 `onPressed == null`。
- **状态**：已修复
- **复审证据**：desktop_scaffold.dart:512-518 currentTrack 为 null 时渲染「未选择曲目」空态并禁用播放/进度控件。验证方式：读码。

### [DESK-013] 歌手详情页默认"已关注"且不落盘；未知歌手名回落为编造档案（128.5万粉丝 / 播放破亿 / 借用他人代表作）

- **编号**：DESK-013
- **严重度**：P2
- **类别**：数据造假 / 交互缺陷 / 与文档不符
- **用户可见现象**：打开任意歌手详情，按钮初始就是"已关注"（用户从未关注过）；切走再回来又变回"已关注"（状态不持久）；若通过任何非内置歌手名进入详情，会看到"官方认证音乐人 / 128.5万粉丝 / 累计播放破亿"和一个陌生头像，且"代表作列表"是 6 首内置示例曲（与该歌手无关）。
- **复现步骤**：1. 热门歌手 → 点任意歌手 → 观察按钮为"已关注"；2. 点一下变"\+ 关注歌手"，退出该页再进入 → 又变"已关注"；3. （代码级）用 `getArtistProfileByName('任意名字')` 观察回落档案。
- **代码证据**：`desktop_views.dart:733` `bool _isFollowing = true;`（默认已关注）；`:790-794` 仅 `setState` 改本地状态，无任何 StorageService 调用（`grep -n "saveArtist\|follow" app/lib/core/storage/storage_service.dart` 0 命中）；`track_model.dart:509-521` `getArtistProfileByName` 的 `orElse` 返回编造档案：`:512-519` `role: '官方认证音乐人', fans: '128.5万', bio: '官方认证音乐人 · 原创先锋作者 · 累计播放破亿'`、`avatarUrl` 为 unsplash 图、`tracks: mockPresetTracks`（把内置示例曲当作该歌手代表作）。
- **数据真实性**：**编造**（fans/bio/role/头像/代表作均为常量），且"已关注"是伪造的用户状态。可达性：桌面端只会用 `mockArtistsProfiles` 里的真实存在的名字跳转（`desktop_views.dart:189-196`、`:694`），故回落档案在桌面端需"名字不匹配"才触发（**未被 UI 直接触发**，属潜在雷）。
- **原型/文档依据**：`docs/SPEC.md:132` 要求歌手详情"关注/已关注**本地持久化状态**"；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:444-452`（P1-02）已判定"歌手数据编造/头像张冠李戴/详情页共用同一份代表作/默认已关注"。
- **建议修复**：`_isFollowing` 改为从 StorageService 读取（新增 `mellow_followed_artists` key），默认 false；`getArtistProfileByName` 查不到时返回"暂无该歌手资料"空态而不是编造档案。
- **可验收标准**：首次进入歌手详情按钮为"\+ 关注歌手"；点关注后重启应用仍为"已关注"（`StorageService.prefs.getBool/…` 有对应键值）；`getArtistProfileByName('不存在的歌手')` 不再返回 `fans` 字段常量。
- **状态**：已修复
- **复审证据**：desktop_views.dart:895-914 关注状态经 StorageService（storage_service.dart:44、170-174）落盘、默认 false；track_model.dart:242 getArtistProfileByName 返回 null；desktop_views.dart:921-930 仅用真实曲库构建档案。验证方式：读码。

### [DESK-014] 桌面端零可访问性实现：全仓 0 处 `Semantics`，主要控件是不可聚焦的裸 `GestureDetector`

- **编号**：DESK-014
- **严重度**：P2
- **类别**：交互缺陷 / 工程卫生
- **用户可见现象**：Windows 讲述人/NVDA 读不出任何按钮名；Tab 键无法在播放/暂停、静音、音量、强调色圆点、顶栏搜索条之间移动焦点；只能靠鼠标。
- **复现步骤**：1. 开启屏幕阅读器；2. Tab 遍历界面 → 无焦点停靠点；3. 代码检索 `Semantics`/`semanticLabel`。
- **代码证据**：`grep -rn "Semantics\|semanticLabel" app/lib` → **0 命中**。关键控件是裸 `GestureDetector`：`desktop_scaffold.dart:294-325`（顶栏搜索条）、`:362-377`（5 个强调色圆点）、`:540-547`（封面→全屏歌词）、`:570-581`（红心）、`:634-656`（播放/暂停）、`:750-757`（静音）；`soft_button.dart:139-143` 用 `GestureDetector` 且无 `Semantics(button: true)`（只有可选 `Tooltip`，见 `:176-181`）。`SoftButton` 也没有 `Focus`/`InkWell`，因此键盘无法聚焦。
- **数据真实性**：不涉及。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:598-606`（P1-18）与 `docs/PC_E2E_FIX_PLAN.md:707` 明确要求为所有 `IconButton`/`GestureDetector` 加 `tooltip` 或 `Semantics` 并改用 `InkWell`/`IconButton`；当前未落地。
- **建议修复**：`SoftButton` 内部改用 `InkWell`+`Semantics(button: true, label: tooltip ?? label)`；裸 `GestureDetector` 补 `Semantics`/`tooltip`。
- **可验收标准**：widget 测试断言 `meetsGuideline(labeledTapTargetGuideline)`；或 `grep -rc "Semantics" app/lib/design_system/soft_button.dart` ≥1 且 Tab 键可在播放按钮上停焦。
- **状态**：已修复（第三轮 D1；修复范围本轮已放开到 `design_system/**`）
- **复审证据（读码 + 真实 widget 探针）**：
  - `design_system/tap_target.dart` 新增 `MellowFocusableTap`：`Semantics(button:true, enabled/focused/selected, label)` + `Focus(canRequestFocus: enabled, onKeyEvent)`（Enter/NumpadEnter/Space 真实激活）+ 可见焦点环（2px 强调色描边 + 光晕）。`soft_button.dart:198-242` 亦已是 `Semantics(button/focused)` + `Focus` + 键盘激活 + 焦点环 + 禁用态不可聚焦。
  - 本轮替换 4 处**残留裸 `GestureDetector`**：`desktop_views.dart:441`（发现页歌手头像，"歌手 X，查看歌手详情"）、`:1987`（设置页 5 个强调色圆点，"强调色：X"）、`:2073`（设置页 4 档音质胶囊，"音质偏好：X"）、`modals.dart:1012`（导入弹窗快速填充胶囊，"快速填充歌单 X"）。其余 `GestureDetector`（`fullscreen_lyrics_view.dart:521`、`modals.dart:686`）此前已带 `Semantics(button,label)`。
  - 探针 `app/test/desk_a11y_and_scroll_storage_test.dart`（4 条，全部真实渲染 + `ensureSemantics`）：① 强调色圆点/音质胶囊读屏标签齐备；② Tab 真实停焦到「FLAC 无损音质」胶囊后按 Space，断言 `player.preferredQuality` 由 320K 真实切换为 FLAC（非只画焦点环）；③ 歌手头像带语义且由 `MellowFocusableTap` 承载；④ `flutter analyze`（scoped：views/desktop、views/common、navigation/desktop_scaffold、design_system）No issues found。
  - 未做（如实声明）：Windows 讲述人/NVDA 实机朗读未验证（本机 macOS，无该读屏）。

### [DESK-015] 依赖里声明了 `go_router` 但全仓 0 引用、`PageStorageKey` 0 处：切页丢滚动与筛选状态，与 SPEC 架构描述不符

- **编号**：DESK-015
- **严重度**：P2
- **类别**：与文档不符 / 工程卫生
- **用户可见现象**：在榜单/歌手/历史等长列表滚到中部，切到设置再切回，滚动位置被重置到顶部；歌单广场选中的分类标签、歌手详情的状态也不保留；无法通过 URL 深链直达页面。
- **复现步骤**：1. 进入"巅峰排行榜"滚到中部；2. 切"个性化设置"；3. 切回"巅峰榜单" → 回到顶部。
- **代码证据**：`grep -rn "GoRouter\|GoRoute\|go_router" app/lib` → **0 命中**（`app/pubspec.yaml` 仍声明 `go_router: ^18.0.1`）；`grep -rn "PageStorageKey" app/lib` → **0 命中**。导航实现是字符串状态机：`desktop_scaffold.dart:26` `String _activeView = 'discover';` + `:472-503` `switch (_activeView)`。
- **数据真实性**：不涉及。
- **原型/文档依据**：`docs/SPEC.md:123` "所有视图采用强类型路由 (go_router)，并配合 PageStorageKey 保证切换 Tab 或页面时不丢弃滚动状态与播放状态"；`docs/PC_E2E_FIX_PLAN.md:638-641`（5.1）要求改 `StatefulShellRoute` + `PageStorageKey`。**注意：该项在历史上被误记为"后退永远跳回发现/前进是死按钮"，本轮实测该交互已被修复（见第 2 节 R-01），但 go_router/PageStorageKey 仍未实现。**
- **建议修复**：迁移到 `go_router`（保留 `onNavigate` 签名做适配层）；给各主视图的 `ListView` 加 `PageStorageKey`/`PageStorageBucket`。
- **可验收标准**：`grep -rn "PageStorageKey" app/lib/views/desktop/desktop_views.dart` ≥1；widget 测试：滚动到中部 → 切页 → 切回，断言 `ScrollController.offset` 不变。
- **状态**：部分修复（用户可见的"切页丢滚动"已闭环；go_router 迁移**已确认不修**并说明理由）
- **复审证据（第三轮 D1）**：`desktop_views.dart` 共 16 处 `PageStorageKey`，本轮补齐此前遗漏的 **同步中心**（`:2938 key: PageStorageKey<String>('desktop-sync')`），长列表页（discover/playlists/toplist/artists/artist-detail/favorite/imported/history/local/settings/sources 及每个导入歌单的曲目列表）全部覆盖。
  - 真实探针：`app/test/desk_a11y_and_scroll_storage_test.dart` 的 `DESK-015` 用例——桌面壳内进入"本地曲库"滚动 320px（offset>50）→ 切"播放历史"→ 切回"本地曲库"，断言重建后 `ScrollPosition.pixels` 与离开前 `closeTo(1.0)`，通过。
  - **go_router 不修的理由（非"没时间"）**：① 该依赖已由并发依赖清理（pubspec 注释 "P1-15 依赖清理"）从 `app/pubspec.yaml` 真实移除，故原条目"声明了却 0 引用"的**工程卫生问题已消失**；② 迁移到 `go_router` 需重新引入第三方依赖、重写 `main.dart` 路由入口与 `adaptive_scaffold.dart` 的桌面/移动分支，两者均在本次允许改动文件之外；③ 该迁移的核心用户价值（滚动状态保持）已由 `PageStorageKey` 真实满足，深链 URL 对 macOS 桌面单窗口应用无实际用户价值。故本轮如实判定"不做"，不计入已修。

### [DESK-016] 歌词不渲染译文（接口已返回 tlyric）、激活行缩放与 SPEC 不符、无滑动拖拽 seek

- **编号**：DESK-016
- **严重度**：P2
- **类别**：功能缺失 / 与文档不符
- **用户可见现象**：全屏歌词只有原文行，没有译文行；歌词行只能单击跳播，按住拖动不会连续预览（SPEC 要求"滑动自由拖拽跳播，抬手即定位"）。
- **复现步骤**：1. 播放任意曲目进全屏歌词；2. 观察是否出现第二行译文（不会）；3. 在歌词区按住上下拖动 → 无任何松手定位行为（只有点击生效）。
- **代码证据**：`fullscreen_lyrics_view.dart:260` `child: Text(line.text)`（`LyricLine.translation` 定义在 `track_model.dart:5/10`，全仓无读取点）；`:252-254` 激活行 `fontSize: isActive ? 26 : 18`（≈1.44×，SPEC 要求 1.18×）；`:244-245` 只有 `onTap: () => player.seek(line.time)`，无 `onVerticalDrag*`；探针实测点击有效：`lyricTap pos=65000 calls=seek:65000`。
- **数据真实性**：译文数据本身存在（`online_music_service.dart` 的歌词接口我实测同时返回 `lrc` 与 `tlyric`；解析函数 `LyricLine.parseLrc` 在 `track_model.dart:32-43` 只取原文，未解析译文）。
- **原型/文档依据**：`docs/SPEC.md:261-268`（6.1）"激活行…放大至 1.18x""支持手指在歌词流中滑动自由拖拽跳播（Seek），抬手即定位"；`docs/PC_E2E_FIX_PLAN.md:709`（P2-02）要求渲染 `translation` 次行。
- **建议修复**：`fullscreen_lyrics_view.dart:236-265` 的 item 改为 `Column`（原文 + 译文，字号更小、`textSecondary`）；补译文解析（`lrc`/`tlyric` 合并）；缩放改 1.18×；补拖拽 seek。
- **可验收标准**：含 tlyric 的曲目播放时 `find.text(译文)` 非空；触发 `onVerticalDragUpdate/End` 后 `player.seek` 被调用（可用 recording backend 断言）。
- **状态**：已修复
- **复审证据**：fullscreen_lyrics_view.dart:421-468 渲染 translation 次行、:450 激活行放大 1.18×、:66-100 支持拖拽松手 seek。验证方式：读码。

### [DESK-017] 发现页"今日私享雷达 · 根据您常听的古风与经典流行智能漫游"是静态文案，无任何听歌数据参与

- **编号**：DESK-017
- **严重度**：P2
- **类别**：文案不诚实 / 数据造假
- **用户可见现象**：无论新装用户还是听了 100 首的用户，Hero 卡片永远写"根据您常听的古风与经典流行智能漫游"，并永远推荐同一批 4 张歌单；"开启漫游播放"永远播放固定曲目（`playlist[0]`）。
- **复现步骤**：1. 清空播放历史后打开发现页 → 仍显示"根据您常听…"；2. 点击"开启漫游播放"→ 播放固定第 1 首。
- **代码证据**：`desktop_views.dart:63-64` `'根据您常听的古风与经典流行智能漫游'`（编译期常量）；`:96-100` `onTap` 固定 `player.playTrack(player.playlist[0])`；`:149-176` 4 张歌单卡与配图全部硬编码；无任何 `playHistory`/`favoriteIds` 参与推荐（`grep -n "playHistory\|favoriteIds" app/lib/views/desktop/desktop_views.dart` 在发现页范围内 0 命中）。
- **数据真实性**：**编造个性化**（暗示有听歌画像，实际没有）。
- **原型/文档依据**：`docs/SPEC.md:128` 只描述"今日私享雷达 Hero 卡片"，未要求个性化；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:789-810`（假数据总账 A/D 节）。
- **建议修复**：文案改为"精选推荐"；或真正按 `player.playHistory`/`favoriteIds` 生成推荐（并在"无历史"时显示冷启动引导）。
- **可验收标准**：清空 `playHistory` 并重启后，Hero 文案不再出现"根据您常听"；或注入不同的 `playHistory` 后推荐歌单集合发生变化。
- **状态**：已修复
- **复审证据**：desktop_views.dart:105-106 文案改「精选推荐 · 来自你的曲库与在线试听」，不再宣称听歌画像与个性化。验证方式：读码。

### [DESK-018] 内置示例曲的歌词/专辑/歌手是硬编码编造的，与它实际播放的 SoundHelix 器乐 demo 毫无关系

- **编号**：DESK-018
- **严重度**：P2
- **类别**：数据造假
- **用户可见现象**：播放"海阔天空 - Beyond"时全屏歌词滚动出《海阔天空》的歌词，但实际听到的是 SoundHelix 第 3 号演示器乐曲；"云水禅心""起风了"等同理；时长、专辑、封面也全是编造的。
- **复现步骤**：1. 播放列表第 3 首"海阔天空"；2. 进全屏歌词观察歌词逐行滚动；3. 与实际音频内容对比（器乐 demo）。
- **代码证据**：`track_model.dart:164-174`（`track-3` 海阔天空 9 行硬编码歌词 + `:162` `audioUrl: …SoundHelix-Song-3.mp3`）；`:122-132`、`:206-212` 等 30+ 首同构；`track_model.dart:110` 注释自称"预置高保真曲目池"；电台"单集"同理（`:776-792` 编造单集标题 + `:784` SoundHelix-14.mp3）。探针实测：`lyric lines=9 first=[海阔天空 - Beyond]`。
- **数据真实性**：**硬编码编造**（FORMAT.md 第 4 节已确认 33 首指向 16 个 demo mp3，标题/歌手为编造元数据）。
- **原型/文档依据**：`docs/SPEC.md:128` 把发现页列为真实内容模块；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:795-812`（假数据总账 A/B 节）已登记。
- **建议修复**：把内置曲目改成"演示音频 1..16"这类如实标名（含真实时长与"演示音频"标注），或改为空曲库 + 引导用户搜索/导入。
- **可验收标准**：`grep -nE "海阔天空|云水禅心|夜的第七章" app/lib/core/audio/track_model.dart` 命中 0，或对应曲目 UI 上带"演示音频"徽标且 `Track.duration` 与真实音频时长一致。
- **状态**：已修复
- **复审证据**：track_model.dart:199 mockPresetTracks 为空、:203+ 测试夹具移入 demoFixtureTracks(source=test-fixture)。验证方式：grep 无「海阔天空/云水禅心/夜的第七章」。

### [DESK-019] 桌面端实际 14 个视图 ≠ SPEC/ROADMAP 的"12 视图"；设置页缺 SPEC 声明的"音源管理与音质首选项"

- **编号**：DESK-019
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：侧边栏实际有 12 个导航项 + 歌手详情 + 全屏歌词 = 14 个界面，其中"导入与自建歌单""多端同步中心"在 SPEC 的 12 视图表里没有对应行；设置页只有外观/强调色/光晕/快捷键说明 4 块，没有"音源管理与音质首选项"。
- **复现步骤**：1. 数侧边栏导航项（在线音乐 5 + 我的资料库 4 + 系统与生态 3 = 12）；2. 打开"个性化设置"→ 只有 4 张卡（`desktop_views.dart:1305-1444`）。
- **代码证据**：侧边栏 12 项：`desktop_scaffold.dart:421-438`；视图分派 13 个 case + 歌词：`:473-502`（含 `imported`、`sync`）；设置页卡片：`desktop_views.dart:1305/1339/1383/1408`（外观/强调色/光晕/快捷键）。
- **数据真实性**：不涉及。
- **原型/文档依据**：`docs/SPEC.md:125-143` 表格仅列 12 视图（无 `imported`、无 `sync`）与 4 个弹窗；`:137` 声称设置中心含"音源管理与音质首选项"；`docs/ROADMAP.md:50-69` 同样为 12+4 且全部标"✅ 1:1 对齐"。属于"文档矩阵与实际 IA 双向不一致"。
- **建议修复**：更新 SPEC/ROADMAP 的视图矩阵，或把 `imported`/`sync` 合并进已有视图以符合矩阵；设置页补音质/音源入口或从 SPEC 删除。
- **可验收标准**：SPEC 3.1 表格行数 = 侧边栏可导航视图数（12），或 `desktop_views.dart` 中不出现表外视图类；设置页出现"音质"与"音源"两个入口。
- **状态**：部分修复（实现侧已满足；文档矩阵差异**已确认不修**）
- **复审证据（第三轮 D1）**：设置页「音源与音质首选项」卡片在 `desktop_views.dart:2037-2112`（真实读写 `player.preferredQuality` 并落盘、4 档胶囊带可访问性语义），原"设置页缺 SPEC 声明的音源管理与音质首选项"**实现侧缺口已闭合**。
  - **剩余差异不修的理由**：侧边栏 14 视图 ≠ SPEC/ROADMAP 的 12 视图，属 `docs/SPEC.md` / `docs/ROADMAP.md` 的**文档口径**问题；两份文档均不在本次允许改动范围，且改文档不改变任何用户可见行为，不应以改文档冒充修缺陷。

### [DESK-020] 窗口仍无最小尺寸约束、无无边框标题栏：只有窗口标题字符串被改成了 "Mellow Music"

- **编号**：DESK-020
- **严重度**：P2
- **类别**：工程卫生 / 与文档不符
- **用户可见现象**：窗口可被拖到任意小，<1024px 时桌面壳整体替换为移动壳（桌面软件里出现手机界面）；窗口顶部同时有系统原生标题栏和应用自绘 56px 标题栏（双标题栏），自绘标题栏内没有最小化/最大化/关闭按钮，也不能拖动窗口。
- **复现步骤**：1. 缩小窗口到 <1024px → 变为移动壳；2. 观察双标题栏与自绘栏缺少窗口按钮；3. 尝试把自绘标题栏拖拽移动窗口 → 无效。
- **代码证据**：`grep -rn "setMinimumSize\|window_manager\|WM_GETMINMAXINFO" app/lib app/windows/runner app/pubspec.yaml` → **0 命中**（未引入 `window_manager`，`windows/runner` 无最小尺寸处理）；`git diff app/windows/runner/main.cpp` 仅把 `window.Create(L"app", …)` 改为 `L"Mellow Music"`，窗口尺寸仍是 `Win32Window::Size size(1280, 720)`；自绘标题栏无 `DragToMoveArea`/`WindowCaption`：`desktop_scaffold.dart:225-407`；断点：`adaptive_scaffold.dart:14`。
- **数据真实性**：不涉及（`app/windows/runner/Runner.rc`、`CMakeLists.txt`、`ios/Info.plist`、`web/manifest.json` 的并发改动属品牌化，非我覆盖范围）。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:695-698`（5.3/5.4）要求引入 `window_manager`、`minimumSize: Size(1024, 640)`、窗口尺寸 (1440,900)、`setAsFrameless()` + 三个窗口按钮；`docs/SPEC.md:447`（E2E-01）要求"无边框标题栏交互……最小化/最大化、关闭"。
- **建议修复**：按 FIX_PLAN 5.3/5.4 落地（`window_manager` + `DragToMoveArea` + 三按钮 + 最小尺寸），或把断点从 1024 提高并明确"小窗不支持"。
- **可验收标准**：Windows/macOS 上把窗口拖到最小停在 1024×640 且布局不破；屏幕上只有一个标题栏；自绘栏三按钮可用。
- **状态**：已确认不修（第三轮 D1 评估后如实判定，附收益/风险与阻塞条件）
- **评估结论**：本轮允许改动范围不含 `app/pubspec.yaml`、`app/macos/runner`、`app/windows/runner`、`app/lib/navigation/adaptive_scaffold.dart`，而"最小尺寸 + 无边框标题栏 + 三窗口按钮 + 拖拽移动"**必须**同时改动"新增 `window_manager` 依赖 + 各平台 runner + 自绘标题栏接 `DragToMoveArea`"，无法在范围内完成；
  - **收益**：消除 <1024px 时桌面壳被整体替换为移动壳、以及系统原生标题栏与应用自绘 56px 标题栏"双标题栏"。
  - **风险（不盲加依赖的实测依据）**：`window_manager` 需 macOS/Windows/Linux 三端 runner 同步接入与窗口事件通道；`grep -rn "window_manager" app` 当前 0 命中，属**从零接入**，会新增平台通道与三端构建面，而本机只能验证 macOS，Windows/Linux 无法验证——按"无真实证据不声称通过"的口径，这一改动无法在本轮闭环，故不做"盲加依赖"。
  - **可验收前置条件**：由掌握平台工程与三端 CI 的 Agent/人接入 `window_manager`，设 `minimumSize: Size(1024,640)`、窗口尺寸 (1440,900)、`setAsFrameless()` + 三按钮 + `DragToMoveArea`，并在 macOS 与 Windows 实机验证后再回填本条。

### [DESK-021] 搜索浮层"热搜标签"是 6 个硬编码词，不是真实热搜

- **编号**：DESK-021
- **严重度**：P2
- **类别**：数据造假
- **用户可见现象**：搜索浮层顶部展示"周杰伦 / 告五人 / 落日飞车 / 陈奕迅 / 轻音乐 / 粤语经典"六个标签，视觉上等同"热搜榜"，但任何用户任何时刻看到的都是这六个，且与真实在线曲库的命中率无关（实测 iTunes 对"落日飞车"等中文词条覆盖很差，点进去常常搜不到）。
- **复现步骤**：1. ⌘K 打开搜索；2. 观察六个标签；3. 点击"落日飞车" → 结果可能为空，但标签仍然显示。
- **代码证据**：`modals.dart:508` `final List<String> _hotTags = ['周杰伦', '告五人', '落日飞车', '陈奕迅', '轻音乐', '粤语经典'];`；`:634-660` 渲染为标签行（`:634` 注释"热搜标签"）。
- **数据真实性**：**编造**（无热度数据来源）。
- **原型/文档依据**：`docs/SPEC.md:143` 未要求热搜；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:493` 已指出"快捷标签为硬编码，非热搜榜"。
- **建议修复**：注释与视觉改为"常用搜索词/示例搜索"；或删除该行。
- **可验收标准**：UI 文案中不出现"热搜"字样（`grep -n "热搜" app/lib/views/common/modals.dart` 0 命中）。
- **状态**：已修复
- **复审证据**：modals.dart:509-511 与 :676-703 改为「常用搜索词（示例，非真实热搜榜）」，代码注释同步。验证方式：读码。

### [DESK-022] 导入歌单成功后只给看前 5 首，无"查看全部"入口

- **编号**：DESK-022
- **严重度**：P2
- **类别**：功能缺失 / 与文档不符
- **用户可见现象**：导入 200 首歌单后，卡片里只列 5 首，其余 195 首无处可看（既没有展开，也没有"查看全部"按钮），用户无法确认/播放后面的曲目。
- **复现步骤**：1. 导入 3778678；2. 在"导入与自建歌单"页观察每张卡只列 5 行；3. 寻找展开/查看全部入口 → 不存在。
- **代码证据**：`desktop_views.dart:1134` `for (final t in pl.tracks.take(5))`（注释 `:1133` 写"前 5 首曲目预览"），卡片内无任何展开控件；`:1117` 文案却写"包含 ${pl.trackCount} 首完整音轨"。
- **数据真实性**：数据本身真实（`importNeteasePlaylist` 返回真实 200 首），只是展示被截断。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:708`（P2-11）要求"懒加载全量列表 + 封面兜底占位"，验收"导入 200 首歌单能滚到第 200 首"。
- **建议修复**：卡片改为可展开的 `ListView`（懒加载全量）或加"查看全部"跳转。
- **可验收标准**：导入 200 首歌单后能滚动看到第 200 首（`find.text(<第200首标题>)` 可滚动命中）。
- **状态**：已修复
- **复审证据**：desktop_views.dart:1394-1419 折叠态前 5 首 + 「查看全部 N 首」展开为有界高度 ListView.builder，可滚到第 N 首。验证方式：读码。

---

## 2. 本轮取证期间由主 Agent 并发修复的项（复审用，附验证证据）

> 说明：以下两项在我开始取证时确实存在（探针第一轮输出可证），取证过程中主 Agent 已改掉。保留条目以便复验，行号取自我最后一次读取的版本；若后续再被改动请以哈希为准。

### [DESK-023] 搜索浮层曾用内置示例曲库冒充"搜索结果"，且网络失败完全静默

- **编号**：DESK-023
- **严重度**：P1（修复前）
- **类别**：数据造假 / 文案不诚实
- **用户可见现象（修复前）**：未输入关键词时结果列表已列出内置示例曲；输入"周杰伦"会看到编造的《夜的第七章》；断网时既不报错也不提示，用户无法区分"没搜到"和"网络坏了"。
- **代码证据（修复前）**：`modals.dart` 旧实现 `initState: _results = mockPresetTracks;`、`_onSearch` 先做本地 `mockPresetTracks` 匹配再 `if (onlineSongs.isNotEmpty)` 静默合并，无 else 分支；`online_music_service.dart` 网络异常 `catch (_) {}` 返回空数组。
- **修复后证据（当前哈希 `e291896a`）**：`modals.dart:515` `_results = const [];`（`:513-514` 注释"不再用内置示例曲库冒充"）；`:539-544` 搜索直接置空并 loading；`:547-561` 真实在线检索 + `try/catch` → `_searchError = '网络请求失败：$e'`；`:680` 三态文案（引导/无结果/网络失败）；`:687` "结果来自 iTunes 公开试听库（30 秒试听）"。数据源改为 iTunes `previewUrl`（`online_music_service.dart:33-38`，注释明确删除了失效的网易云直链）。
- **验证证据（探针，修复后）**：`searchInitial … guide=true`；搜索"周杰伦" → `mockJay=false netErr=true noResult=false itunesNote=true spinner=false`（内置编造曲目不再出现；离线时如实显示网络失败）。网络裸测：iTunes `/search` HTTP 200、`previewUrl` HTTP 200 `audio/x-m4p`。
- **数据真实性**：结果与封面均为真实网络数据；iTunes 中文曲库覆盖有限（"周杰伦" limit=20 仅 1 条）属数据源覆盖问题，非造假。
- **建议修复**：已完成；剩余口径问题见 DESK-010。
- **可验收标准**：断网（测试环境 HTTP 400）下搜索任意词，界面出现"网络请求失败"文案；有网时结果条目的 `audioUrl` 均为 `*.itunes.apple.com/*`。
- **状态**：已修复（附上述探针与 curl 证据）

### [DESK-024] 收藏曾是预置的 4 首编造数据（冷启动就有"我喜欢的音乐"）

- **编号**：DESK-024
- **严重度**：P1（修复前）
- **类别**：数据造假
- **用户可见现象（修复前）**：全新安装启动后，"我喜欢的音乐"里已有 4 首红心曲目（track-1/3/5/6），侧边栏计数与底栏红心都是亮的，但这些是系统预置、不是用户操作产生的。
- **代码证据（修复前，哈希 `9a8aa6d1`）**：`audio_player_service.dart:29` `final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};`。
- **修复后证据（当前哈希 `6b858e2b`）**：`audio_player_service.dart:28-31` `// 诚实化：不再预置任何编造的「默认收藏」…` + `final Set<String> _favoriteIds = <String>{};`；收藏由 `toggleFavorite` 真实落盘（`audio_player_service.dart` 的 `StorageService.instance.saveFavoriteIds/saveFavoriteTracks`）并在 `_loadFromStorage` 恢复。
- **数据真实性**：修复后为"仅用户操作产生的真实数据"。
- **建议修复**：已完成。
- **可验收标准**：清空 `SharedPreferences` 后首次启动，"我喜欢的音乐"为空态；收藏一首后重启仍存在。
- **状态**：已修复（附代码哈希对比证据；未做重启实测）

---

## 3. 逐项结论速览（对应任务书 1~10，仅列结论与证据指针）

| # | 任务项 | 结论 | 关键证据 |
| :--- | :--- | :--- | :--- |
| 1 | 快捷键是否真绑定？输入框聚焦是否误触发？ | **已真绑定** 10 条 `SingleActivator`（`desktop_scaffold.dart:87-125`，`CallbackShortcuts` 在 `:127-130`）。实测：Space 触发 `play:`+ `setVolume:0.850`；M → 音量 0.85→0→0.8；→ 触发 `seek:5000`；↑ 音量 +0.05；^K/⌘K 打开浮层；Q 开队列且 ESC 关队列。**输入框聚焦时不误触发**（聚焦搜索框后 Space/M/↑ 均不改播放与音量）。**唯一严重例外：进入全屏歌词后全部快捷键失效（含 ESC）→ DESK-001** | 探针 `desk_probe_test.dart`、`desk_esc_test.dart`、`desk_queue_test.dart` 输出 |
| 2 | 后退/前进是否接真实历史栈？无历史时表现？ | **已接真实栈**（`_history`/`_historyIndex`，`desktop_scaffold.dart:33-74`）：发现→榜单→歌手 后点后退回到**榜单**（不是发现），前进回到歌手；到末端后前进按钮变为 `tooltip: '无前进历史'` 且 `onTap: null`（`:278-282`）。实测 `afterBack toplist=true discover=false`、`afterForward fwdEnabled=0 fwdDisabled=1`。**遗留**：无 `PageStorageKey`/go_router → 切页丢滚动与筛选状态（DESK-015） | 探针 HISTORY 用例 |
| 3 | 搜索是否发真实 HTTP？无网是否有诚实反馈？本地匹配是否拿示例曲库冒充？ | **真实 HTTP**（`modals.dart:547-551` → iTunes，裸测 200 且 `previewUrl` 可播）。**无网现在有诚实反馈**（`:553/680` "网络请求失败"）。**不再用示例曲库冒充**（`:515` 置空、`:539-544` 清空本地匹配）——该问题在我取证期间刚被主 Agent 修掉（DESK-023）。**剩余**：文案仍写"搜索全网…歌手、专辑"，实际单源、无歌手/歌单聚合与高亮（DESK-010） | 探针 + curl |
| 4 | 播放栏控件是否真驱动 backend？音量是否真 `setVolume`？切歌进度/时长是否正确重置？ | **真驱动**：播放/暂停/上下曲/模式切换/进度拖拽/音量滑杆全部落到 `AudioPlayerBackend`（探针记录 `play:…Song-1.mp3`、`seek:157086`、`setVolume:0.500|0.000`、`next → play:Song-2`）。**问题**：① 时长与进度上限取自编造元数据 `track.duration`，不使用真实 `player.duration`（DESK-003，实测 real=210000 vs meta=268000，界面显示 04:28）；② 清空队列后底栏仍显示示例曲（DESK-012）；③ 全屏歌词里的进度条每帧 `seek`（`fullscreen_lyrics_view.dart:191` 的 `onChanged` 直接 seek，无 `onChangeEnd` 防抖，与底栏 `:691-697` 的做法不一致） | 探针 `desk_probe_test.dart` PLAYERBAR/duration 用例 |
| 5 | 全屏歌词是否来自真实解析？示例曲歌词是否硬编码编造？逐行点击是否真 seek？ | 歌词来源：内置曲目**硬编码编造**（`track_model.dart:122-232` 等，与 SoundHelix 器乐 demo 无关）；在线曲目目前**不取歌词**（`audio_player_service.dart:_loadLyricIfNeed` 仅对 `netease_` 前缀生效，而新搜索源 id 前缀是 `itunes_` → 在线曲目的歌词**永远为空**，全屏歌词显示"纯音乐，请静心聆听"）。**逐行点击确实真 seek**（`fullscreen_lyrics_view.dart:244-245`；实测 `lyricTap pos=65000 calls=seek:65000`）。详情见 DESK-016/DESK-018，另新增"iTunes 曲目歌词链路断"结论（见 §4 未验证/新发现） | 探针 + 代码 |
| 6 | EQ 增益是否作用到音频输出？ | **完全没有调用链，EQ 是死开关**：`toDspFilterDescription()` 全仓 0 调用方，`player_backend.dart` 接口无任何 EQ 方法，探针记录 `backend=`（空）。manager 已补诚实注释但 UI 文案仍宣称"声学校准/专业声学 EQ" → DESK-002 | 探针 EQ 用例 + grep |
| 7 | 800/600/360 是否存在 RenderFlex 溢出？ | **存在**，逐条行号与可达性见 DESK-011（含 600×800：`desktop_scaffold.dart:531` 底栏 204px @360；`desktop_views.dart:36` 33px、`soft_button.dart:125` 69px；`sync` 在 800×600 即溢 83px @`:1750`；全屏歌词 800×600 纵向 38px @`fullscreen_lyrics_view.dart:120`）。桌面壳在 <1024px 会被移动壳替换，故大部分不可达；`QuickSearchOverlay` 800×600 的 15px 溢出可达 | 探针 `desk_overflow_test.dart` |
| 8 | 12 视图逐个：真实数据 / 内置示例 / 死按钮 | discover=内置示例+编造播放量（真实音频）；playlists=内置示例歌单+编造播放量（真实音频）；toplist=内置示例曲库+编造更新/描述（真实音频）；artists=编造粉丝/头像；artist_detail=编造 bio/粉丝 + 默认已关注不持久化（回落档案编造）；podcast=编造单集/在听人数（音频为示例 mp3）；favorite=**真实**（落盘）；imported=**真实导入数据**但音频死链、只显示前 5 首；history=**真实**（落盘）；local=**死模块**（无任何导入能力）；settings=**真实**主题/强调色/光晕落盘（缺音质/音源）；sources=**死模块**（1 个 SnackBar + 静态卡片）；sync=**死模块**（2 个 SnackBar + 静态常量）；lyrics=硬编码编造歌词。详见 §1 各条目与 §2 表 | 代码 + 探针 |
| 9 | 列表是否虚拟化？ | **无虚拟化**：13 处 `ListView(children:)`（行号见 DESK-004）+ 5 处 `shrinkWrap` 网格全量构建；仅队列/搜索结果用了 builder | grep + 代码 |
| 10 | 空状态/错误状态是否存在？ | **有**：收藏空态 `desktop_views.dart:985-997`、历史空态 `:1200-1214`、导入歌单空态 `:1071-1094`、本地静态空态 `:1282`、同步"未发现设备" `:1820-1838`、搜索三态（引导/无结果/网络失败，`modals.dart:680`）、导入失败 `modals.dart:824`、播放失败横幅 `desktop_scaffold.dart:180-216` + 新 SnackBar（`main.dart` 的 `PlaybackNoticeListener`）、图片加载失败占位（`mellow_image.dart:56`）。**缺**：发现页/榜单/歌手/电台/歌单广场是静态 mock，无"数据为空"设计（一旦真实源为空将渲染空白而非空态） | 代码 |

---

## 4. 未验证 / 待确认事项（诚实清单）

1. **GUI 真机（Windows 产物）未验证**：本机为 macOS，未构建 Windows 产物；"双标题栏""窗口最小尺寸""任务栏名称"等结论基于代码与 `win32_window.cpp` 静态检查（DESK-020），需 Windows 真机复验。
2. **弹窗窄视口溢出的路由保真度**：DESK-011 中弹窗类溢出是把 `Dialog` 组件直接泵入 `Scaffold.body` 测得，未经 `showDialog` 真实路由；数值可能有偏差（尤其是 `modal-search 800x600` 的 15px），需用 `showDialog` 复现确认。
3. **`playbackNotice` 横幅与 SnackBar 是否重复提示**：`desktop_scaffold.dart:180-216` 会渲染横幅，且 `main.dart` 新增的 `PlaybackNoticeListener` 会同时弹 SnackBar；同一次失败可能"横幅+SnackBar"双提示。我未在真机/完整 App（含 `mellowScaffoldMessengerKey`）下实测，**未验证**。
4. **在线曲目歌词链路（新发现，未列入正式条目）**：`audio_player_service.dart` 的 `_loadLyricIfNeed` 只对 `id.startsWith('netease_')` 触发歌词拉取；而搜索源已改为 `itunes_` 前缀，因此**在线曲目永远拿不到歌词**（全屏歌词恒为"纯音乐，请静心聆听"）。我未构造完整端到端（真实 iTunes 曲目 + 歌词接口）验证，仅代码证据；且主 Agent 正在并发改动该文件，建议单独复核后编号。
5. **`_executeRealPlay` 改动的副作用**：主 Agent 新增"无 audioUrl/localPath 则不伪装播放"，我未验证其与"队列里混入无源曲目"的交互（例如导入歌单曲目全部有 audioUrl 只是死链，仍会走 `play()` 失败分支并提示）——死链会在真实设备上以"加载失败"提示呈现，需真机确认提示文案可读。
6. **history/mobile 侧**：移动端、数据真实性、FIX_PLAN 进度分别由子 Agent B/C/D 负责，本账本不重复；但 `modals.dart` 与 `track_model.dart` 是双端共享文件，DESK-010/013/016/021 的修复会同时影响移动端。
7. **并发修改**：本账本所有行号对应 §0 表中的哈希；取证结束后主 Agent 仍在改 `app/lib/core/audio/*`、`app/lib/views/common/modals.dart`、`app/lib/core/sync/webdav_sync_service.dart`，复审前请先重新核对行号。
