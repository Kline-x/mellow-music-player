# Mellow Music × AlgerMusicPlayer —— 能力差距清单（ALGER-FEATURE-GAPS）

> **对标基线**：AlgerMusicPlayer **v5.1.0**，commit `b277ef17a8d6f05152d42528e6930205b95d0fab`（2026-09-19）。
> 本轮在 `/tmp/alger-ref` 浅克隆后**逐文件真实阅读**，下文所有 `file:line` 均为该 commit 下的真实位置。
> **本方基线**：`app/pubspec.yaml` version 1.0.0+1。
> **验收口径**：`cd app && flutter analyze` → **No issues found!**；`cd app && flutter test` → **177 passed**（本轮实测；本 agent 新增 10 项，其余为并行 agent 同期新增）。
> **成本口径**：S = ≤1 人日；M = 1~3 人日；L = >3 人日（含平台真机验证）。
> **铁律**：本清单只记录**可真实落地**的能力；任何需要编造数据的「对标」一律标为「不值得引入」。

---

## 0. 结论摘要

| # | 能力 | 他们（Alger 5.1.0） | 我们现状 | 值得引入 | 成本 | 优先级 | 本轮动作 |
|:-:|:--|:--|:--|:--|:--|:--|:--|
| 1 | 桌面歌词独立窗口 + 窗口行为 | 无边框透明置顶 / 锁鼠标穿透 / 位置持久化 | 仅应用内全屏页 | 是 | L | P1 | 只记录 |
| 2 | 系统托盘 | 状态栏图标 + 播放菜单 + 歌词标题 | **缺失** | 是（桌面） | M | P1 | 只记录 |
| 3 | 全局快捷键 | globalShortcut + 冲突检测 + 持久化 | 仅应用内快捷键 | 是（桌面） | M | P1 | 只记录 |
| 4 | 本地曲库扫描 / 标签解析 | 递归扫描 + music-metadata 全标签 + 封面歌词 | 选择器导入 + **本轮补目录递归扫描/增量** | 是（标签部分） | S/M/L | P1 | **已落地路径级增量扫描** |
| 5 | 队列管理 | 洗牌真实顺序 / 插入下一首 / 预加载后两首 | 洗牌为伪随机、无插入下一首 | 是 | S/M | P1 | **已落地洗牌牌堆 + playNext** |
| 6 | 播放进度记忆 | 记录 + 冷启动恢复 + 起播 seek | **缺失** | 是 | S | P1 | **已落地** |
| 7 | 下载与磁盘缓存 | 下载队列（并发/续传/写标签）+ LRU 缓存 | **缺失** | 是（缓存优先） | L | P2 | 只记录 |
| 8 | 音源管理与失败降级 | 每曲音源列表 + 试听差异择优 + URL 过期有限重试后切歌 | 单源取流 + 诚实失败提示 | 是 | S/M | P1 | 只记录 |
| 9 | 主题外观 | 跟随系统 + 封面取色 + 字体 + 歌词外观配置 | 明暗/强调色/光晕 | 部分 | S/M | P2 | 只记录 |
| 10 | 系统媒体控制（SMTC/MPRIS/锁屏） | MediaSession + mpris-service | **缺失** | 是 | L | P1 | 只记录 |
| 11 | 启动更新 | electron-updater 状态机 | **缺失** | 部分 | M/L | P2 | 只记录 |
| 12 | 错误降级体验 | generation 取消 + 失败重试后自动跳曲 | 诚实失败但不自动降级 | 是 | S/M | P1 | 只记录 |

> 说明：表中第 4/5/6 项的「已落地」部分是**本轮真实实现**，实现要点与测试见 §2，其余项**只写清单与建议、未动手**。

---

## 1. 逐项对标明细

### 1.1 桌面歌词与窗口行为

**他们的实现要点**
- 独立歌词窗口：无边框 + 透明 + 无阴影 + 可缩放，`src/main/lyric.ts:156-167`（`frame:false / transparent:true / hasShadow:false / resizable:true`）。
- 置顶开关：`src/main/lyric.ts:291`（`setAlwaysOnTop`）。
- **锁定 + 鼠标穿透**（桌面歌词的核心体验）：`src/main/lyric.ts:305-311`（锁定后 `setResizable(false)` + `setIgnoreMouseEvents(true, {forward:true})`）、`:398`；配合鼠标进出追踪 `:57-88`。
- **位置/尺寸持久化 + 多显示器回退**：`src/main/lyric.ts:91-156`（保存 `lyricWindowBounds` 含 `displayId`，找不到原显示器时回退主屏并按有效区间钳制）、保存节流 `:12-20`、resize 保存 `:209-220`。
- 主窗口行为：最小尺寸计算 `src/main/modules/window.ts:208-209`；macOS 关窗即隐藏 `:372-381` 与 `close-window` `:134-150`；迷你窗口 `:153-160`。
- 窗口状态（位置/尺寸/最大化）持久化与内容缩放自适应：`src/main/modules/window-size.ts:371-465`、`:517-580`（按系统 `scaleFactor` 取 0.7~1.0 缩放因子）。

**我们现状**
- 全屏歌词是**应用内页面**而非独立窗口：`app/lib/views/desktop/fullscreen_lyrics_view.dart:14`，由 `app/lib/navigation/desktop_scaffold.dart:128-131` 切换。
- 快捷键与主工作台共用：`app/lib/navigation/desktop_scaffold.dart:83-126`；歌词页内再挂一套：`fullscreen_lyrics_view.dart:115-130`。
- 无置顶 / 无鼠标穿透 / 无锁定 / 无独立位置持久化；窗口缩放由 OS 处理（`grep -riE "miniMode|MiniWindow"` 0 命中）。

**是否值得引入**：是（「桌面歌词」是音乐播放器桌面端的高频刚需，Alger 把它做成了可锁定的置顶悬浮窗）。
**成本**：独立歌词窗口 L（需 `window_manager` 类插件 + Windows/macOS/Linux 三端真机验证）；内容缩放自适应 M。
**优先级**：P1（独立歌词窗口）/ P3（缩放自适应，Flutter 侧 OS 已处理）。

---

### 1.2 托盘与全局快捷键

**他们的实现要点**
- 托盘菜单：上一首 / 播放暂停 / 收藏 / 下一首 / 语言 / 显示隐藏，`src/main/modules/tray.ts:141-330`。
- macOS 状态栏**逐图标**控制（上一首/播放/下一首/歌名独立 Tray），`tray.ts:335-397`；歌词滚动到状态栏标题 `tray.ts:88-138`；初始化 `tray.ts:406-430`。
- 全局快捷键真实注册：`src/main/modules/shortcuts.ts:158-215`（`globalShortcut.register`，逐个回传注册结果，失败不静默）。
- 配置持久化 + 归一化校验：`shortcuts.ts:76-121`、`:303-324`；启用/停用 `:344-352`。
- **冲突检测与保留键**：`src/shared/shortcuts.ts:282-318`（同 scope 同键分组报冲突）、`:320`（保留加速键）；`global/app` 双 scope 定义 `:35-41`。
- 应用内按键：`src/renderer/utils/appShortcuts.ts`、`shortcutKeyboard.ts`、`shortcutToast.ts`。

**我们现状**
- **无托盘**：`app/lib` 内 `TrayIcon|SystemTray|system_tray` 0 命中。
- **无全局快捷键**：`hotkey_manager|GlobalShortcut|RegisterHotKey` 0 命中；仅 `CallbackShortcuts` 应用内生效 `app/lib/navigation/desktop_scaffold.dart:86-126`（空格/K/←/→/↑/↓/M/L/Q/ESC）。
- 无自定义快捷键、无冲突检测、无持久化。

**是否值得引入**：是（桌面端「最小化到托盘 + 全局播放键」是留存型功能）。
**成本**：托盘 M；全局快捷键 M（注册需插件，但**归一化/冲突检测/保留键是纯 Dart，可先落地并单测**）。
**优先级**：P1。
**建议路径**：先做纯 Dart 的快捷键模型（默认表 + 归一化 + 冲突检测 + 持久化 + 单测，S），再接插件做真实注册（M）——避免「先接插件无法验证」的顺序。

---

### 1.3 本地曲库扫描与标签解析

**他们的实现要点**
- 支持格式与递归遍历：`src/main/modules/localMusicScanner.ts:12`、`:152-196`；带 `mtime` 的扫描 `:203-248`。
- **music-metadata 标签解析**：标题/艺术家/专辑/时长/内嵌封面/内嵌歌词，`localMusicScanner.ts:256-301`；解析失败回退文件名（诚实 fallback）`:268-279`。
- 封面落盘 `userData/AudioCovers/<sha256>.<ext>` 且带大小上限 8MB：`:99-126`。
- 并发解析（按 CPU 数 2~8）：`:309-328`。
- **增量扫描**：仅当 `mtime` 变化才重新解析，旧条目自动自愈（缺 `coverPath` 字段也重解析）：`src/renderer/store/modules/localMusic.ts:159-271`；文件夹路径管理 `:116-144`；失效文件清理 `:295-333`。
- UI：`src/renderer/views/local-music/index.vue:62,94,160,245`（播放全部/歌曲数/文件夹列表/触发扫描）。

**我们现状**
- 导入方式：系统文件选择器多选，`app/lib/core/sources/local_music_service.dart:28-42`；曲目只由**真实文件名**构造，歌手固定「本地文件」，时长 0 由真实解码回填 `:83-102`。
- **本轮新增**：目录递归扫描 `app/lib/core/sources/local_music_service.dart:63-80`（`.handleError` 跳过不可读子目录，不因一个坏目录丢整库）；按路径增量导入 `app/lib/core/audio/audio_player_service.dart:413-436`；桌面 UI 入口 `app/lib/views/desktop/desktop_views.dart:1595-1614`。
- **仍缺失**：ID3/FLAC/Vorbis 标签解析、内嵌封面提取与缓存、内嵌歌词、`mtime` 级增量（当前是**路径级**去重，文件内容变更不会重新识别）。

**是否值得引入**：是。当前曲库每首歌都是「文件名 + 本地文件」，用户真实价值最高的下一步就是标签解析。
**成本**：路径级增量扫描 **S（已完成）**；标签解析 M（需引入 music-metadata 等价 Dart 包并真机验证）；封面/歌词提取 M；`mtime` 级增量 M。
**优先级**：P1（标签解析）。
**诚实约束提醒**：解析失败必须回退「文件名 + 未知」并在 UI 明示，**不得**用假歌手/假专辑填充。

---

### 1.4 队列管理

**他们的实现要点**
- 列表与下标为单一数据源：`src/renderer/store/modules/playlist.ts:35-46`。
- **预加载后两首**（含歌词与封面预热）：`playlist.ts:141-167`、`preloadService`（`playlist.ts:111-119`）。
- **真实洗牌顺序 + 原序还原**：`playlist.ts:178-221`（`performShuffle`，当前曲目置首，退出随机恢复 `originalPlayList`）、`:305-315`。
- **插入「下一首播放」**：`playlist.ts:336-350`（`playListIndex+1` 处 `splice`）；移除（含正在播放）`:359-371`；清空 `:388-393`。
- UI 入口：`src/renderer/components/common/songItemCom/SongItemDropdown.vue:157-158,230`（`playNext` 菜单项）。

**我们现状**
- 已有：`addToQueue` `app/lib/core/audio/audio_player_service.dart:992`、`removeTrackAt` `:1043`、`clearQueue` `:1066`、队列落盘 `:1111`、队列抽屉 `app/lib/views/common/modals.dart:44-152`。
- **本轮修复（真实缺陷）**：旧 `next()` 在随机模式下每次 `Random().nextInt(length)`，**可能立刻重播当前曲目**（表现为「按下一首没反应」），且一轮内可重复——已改为 Fisher-Yates 洗牌牌堆，`audio_player_service.dart:771-813`；切随机模式不打断当前曲目 `:973-985`；`previous()` 在随机下走真实历史而非再随机 `:736-745`。
- **本轮新增**：`playNext()` 真实插入当前曲目之后，`audio_player_service.dart:1009-1041` + UI `app/lib/views/desktop/desktop_views.dart:1706`。
- **仍缺失**：下一首/下下首取流预加载；拖拽重排；洗牌后「恢复原顺序」。

**是否值得引入**：预加载值得（切歌秒开、少一次卡顿）；重排可选。
**成本**：预加载 M（要给 LX/网易云取流加预热缓存与失效策略）；重排 M。
**优先级**：P2。

---

### 1.5 播放进度记忆与续播

**他们的实现要点**
- 播放时保存进度、起播时恢复：`src/renderer/services/playbackController.ts:94-100`（读 `playProgress` 作为 `initialPosition` 传给 `audioService.play`）。
- 禁用自动播放时仅恢复 UI 进度、不发声：`playbackController.ts:561-574`。
- 启动恢复状态机（元数据与音频分离、失败则清空状态）：`playbackController.ts:525-596`。

**我们现状**
- **本轮落地**：`StorageService.savePlaybackProgress/getPlaybackProgress/clearPlaybackProgress` `app/lib/core/storage/storage_service.dart:138-168`；位置节流落盘（每前进 5s）`app/lib/core/audio/audio_player_service.dart:343-351`；暂停与拖动立即落盘 `:518-524`、`:873-885`；冷启动恢复（**不自动出声**、距结尾 5s 内回开头、跨曲目不复用）`:256-271`；真实起播后 seek 回续播点 `:373-382`（统一入口，3 处取流分支共用）。

**是否值得引入**：是（长音频/播客场景刚需）。
**成本**：**S（已完成）**。
**优先级**：P1（已完成）。

---

### 1.6 下载与磁盘缓存

**他们的实现要点**
- 下载队列：并发上限 3、暂停/恢复/取消/批量、持久化与退出时同步落盘、临时文件清理：`src/main/modules/downloadManager.ts:85-130`、`:158-260`；单曲完成通知合并（连续下载不刷屏）`:90-99`。
- 落盘时写标签与内嵌封面（node-id3）：`downloadManager.ts:378-414`、`:667-770`；歌词原文+译文合并 `:31-79`。
- 磁盘缓存：LRU/FIFO 策略、容量上下限与目录迁移/清理/统计：`src/main/modules/cache.ts:12-24`、`:125-215`、`:330-400`。
- 设置项：`src/renderer/views/set/tabs/SystemTab.vue:4-105`（缓存开关/目录/上限/策略/状态/管理）。

**我们现状**
- **缺失**：无下载器、无磁盘音频缓存（`downloader|DownloadManager|diskCache|CacheManager` 在 `app/lib` 0 命中）；仅有 LAN / WebDAV 数据同步 `app/lib/core/sync/sync_controller.dart:34-568`。

**是否值得引入**：缓存值得（二次播放秒开、离线可用）；完整下载器中等。
**成本**：缓存 M~L（音频落盘 + 索引 LRU + 目录上限与清理）；下载器 L（并发/续传/写标签/通知）。
**优先级**：P2（缓存）/ P3（下载器）。
**诚实约束提醒**：下载进度、缓存命中率必须来自真实 IO 统计，禁止预置漂亮的假数字。

---

### 1.7 音源管理与失败降级

**他们的实现要点**
- 每首歌的音源列表 + 手动/自动类型，落盘：`src/renderer/services/SongSourceConfigManager.ts:31-108`。
- 已尝试音源集合与「试听差异」择优（差异最小者优先）：`SongSourceConfigManager.ts:119-184`。
- 手动换源并重解析当前曲（成功后更新播放列表实体）：`playbackController.ts:337-391`。
- **失败/URL 过期分级恢复**：清掉可能损坏的解析 URL 缓存 → 仅重试 1 次（`MAX_URL_EXPIRED_RETRIES=1`）→ 仍失败**自动切下一首**：`playbackController.ts:393-518`。
- 网易云解灰：`src/main/unblockMusic.ts:86-130`（带重试）。
- 设置 UI：`src/renderer/views/set/tabs/PlaybackTab.vue:15`。

**我们现状**
- 网易云真实取流 + 档位降级 + 实际音质诚实回传：`app/lib/core/sources/netease_music_service.dart:362`、`:84`、`:157`；播放侧分档提示 `app/lib/core/audio/audio_player_service.dart:610-624`。
- LX 脚本引擎（flutter_js 沙箱）多源回退：`app/lib/core/audio/audio_player_service.dart:690-723`（`resolveMusicUrlWithFallback`）。
- **缺失**：用户手动切源并重解析当前曲；跨平台「试听差异」择优；URL 过期自动恢复与「有限重试后自动切歌」；解灰。

**是否值得引入**：是。长歌单里遇到死链时，目前只能停在诚实提示上，无法自救。
**成本**：手动切源 S~M；URL 过期恢复 M（需要给已解析 URL 加过期时间与缓存清理）；解灰 L（引入开源服务）。
**优先级**：P1（失败自动降级）/ P2（手动切源）。

---

### 1.8 主题与外观

**他们的实现要点**
- 跟随系统主题 + 手动切换 + 监听系统变化：`src/renderer/store/modules/settings.ts:20,94-200`；`src/renderer/utils/theme.ts:4-35`（`matchMedia('(prefers-color-scheme: dark)')` + `watchSystemTheme`）。
- **封面主色提取 + 渐变背景**：`src/renderer/utils/linearColor.ts:31-96`（canvas 取像素算主色，生成渐变）；主题色面板 `src/renderer/components/lyric/ThemeColorPanel.vue`。
- 字体选择与预览：`src/renderer/views/set/tabs/BasicTab.vue:63-92`。
- **歌词外观可配置且持久化**：字号/字距/字重/行高/居中/纯模式/聚焦当前行/内容宽度/自定义背景与 CSS，见 `src/renderer/types/lyric.ts`（`LyricConfig` + `DEFAULT_LYRIC_CONFIG`）；读写 `src/renderer/utils/lyricConfig.ts:3-23`（跨组件事件同步）。
- 逐字歌词解析（yrc）：`src/renderer/utils/yrcParser.ts`。

**我们现状**
- 明暗 + 强调色 + 光晕浓度，真实落盘：`app/lib/design_system/theme_provider.dart:6-71`、`app/lib/core/storage/storage_service.dart:54-64`。
- 全屏歌词字号/行/译文渲染（**硬编码，不可配置、不落盘**）：`app/lib/views/desktop/fullscreen_lyrics_view.dart:255-268`、`:421-462`。
- **缺失**：跟随系统主题（`platformBrightness|ThemeMode.system` 0 命中）；封面取色（`Palette|dominantColor|extractColor` 0 命中，现有 `gradient` 只是写死的卡片渐变 `desktop_views.dart:547`）；字体选择；歌词外观配置持久化；逐字歌词（`lx_script_engine.dart:1025` 只是读取脚本返回的 `yrc` 字段，未做逐字渲染）。

**是否值得引入**：跟随系统主题（是，S）；歌词外观配置（是，S~M）；封面取色（可选，M）。
**成本**：S（系统主题）/ S~M（歌词外观配置 + 持久化）/ M（取色，需图片解码，建议用 Flutter 自带 `ui.Image` 采样，避免新依赖）。
**优先级**：P2。

---

### 1.9 系统媒体控制（SMTC / MPRIS / 锁屏 / 媒体键）

**他们的实现要点**
- 渲染侧 **MediaSession**（Windows SMTC / macOS Now Playing / 浏览器）：动作绑定 play/pause/stop/seekto/seekbackward/seekforward/previoustrack/nexttrack `src/renderer/services/audioService.ts:110-144`。
- 元数据（多尺寸封面 96~1024，提升 SMTC/AMLL 清晰度）+ 播放状态 + 位置状态：`audioService.ts:146-190`；停止时清空 `audioService.ts:562-563`。
- Linux MPRIS：`src/main/modules/mpris.ts:40-190`（`playbackStatus`/`metadata`/`Seek`/`mpris-position-update` 同步）。
- Windows 缩略图工具栏 + 手机遥控 HTTP 服务：`src/main/modules/remoteControl.ts:50-150`。

**我们现状**
- **缺失**：`MediaSession|MPRIS|MPNowPlaying|audio_service|just_audio_background|remote_command` 在 `app/lib` 与 `pubspec.yaml` 0 命中；仅有 `audioplayers` 物理播放，不注册任何系统媒体会话。

**是否值得引入**：是，优先级很高——媒体键/锁屏控制缺失意味着用户必须回到应用窗口才能操作。
**成本**：L（需引入 `audio_service`/`media_kit` 类方案或自写平台通道，Windows/macOS/Linux/Android/iOS 需逐一真机验证）。
**优先级**：P1。
**风险提示**：当前播放引擎是 `audioplayers`（`app/lib/core/audio/player_backend.dart:25-79`），接入系统媒体控制往往需要同时更换/包装引擎；建议与「EQ 真实生效」（§1.12）合并评估一次引擎选型，避免二次返工。

---

### 1.10 启动与更新

**他们的实现要点**
- 更新状态机（检查/下载/安装，带并发去重 Promise 与进度事件）：`src/main/modules/update.ts:103-201`；事件与 IPC `:203-296`；`autoUpdater.autoDownload=false`、退出时安装 `:214-215`。
- 跳过版本 / 镜像 / 打开发布页：`src/renderer/utils/update.ts`。
- 关于页版本展示：`src/renderer/views/set/tabs/AboutTab.vue:3`。

**我们现状**
- **缺失**：`checkForUpdate|UpdateChecker|releases/latest|appUpdater` 0 命中；版本以 `pubspec.yaml` 为单一来源。

**是否值得引入**：部分值得。桌面端做「真实检查 + 诚实告知有新版本 + 打开发布页」即可；自动下载安装价值有限且平台成本高。
**成本**：M（检查 GitHub Releases + 诚实提示，网络失败必须静默降级）/ L（自动下载与安装，需各平台签名与安装器）。
**优先级**：P2。
**诚实约束提醒**：无网络或接口失败时必须明确「检查失败」，禁止把「检查失败」显示成「已是最新版本」。

---

### 1.11 错误降级与体验兜底

**他们的实现要点**
- **generation-based 取消**：每次 `playTrack` 递增 generation，所有异步步骤 `await` 后校验，切歌后旧请求结果全部作废（避免「上一首的取流结果覆盖当前曲」）：`src/renderer/services/playbackController.ts:160-328`；请求登记 `src/renderer/services/playbackRequestManager.ts`。
- 播放失败：错误提示 + `playLoading` 复位 + 请求标记失败 + 状态回到未播放：`playbackController.ts:299-327`。
- URL 过期：清坏缓存 → 有限重试 → 自动切下一首（详见 §1.7）：`playbackController.ts:393-518`。
- 元数据加载失败不阻塞播放：`playbackController.ts:219-227`；历史写入失败不影响播放 `:229-241`。

**我们现状**
- 诚实失败（已具备）：无真实音源不伪装播放 `app/lib/core/audio/audio_player_service.dart:705-714`；取流失败/无版权/音质降档均给出可读提示 `:592-723`。
- **本轮补强**：冷启动续播不自动出声；随机播放不重复；本地增量导入不重复入库（见 §2）。
- **缺失**：切歌竞态取消（无 generation/requestId，快速连续切歌时旧取流结果可能后到）；播放失败有限重试后自动跳过。

**是否值得引入**：是，「有限重试 + 自动跳过」成本低、收益直接。
**成本**：S（有限重试 + 自动跳过的纯 Dart 逻辑 + 单测）/ M（竞态取消需要重构 `_executeRealPlay` 的异步链路）。
**优先级**：P1。

---

### 1.12 其他次要能力（仅登记）

| 能力 | 他们 | 我们 | 成本 | 优先级 |
|:--|:--|:--|:--|:--|
| 均衡器（真实生效） | WebAudio BiquadFilter 10 段，`src/renderer/services/eqService.ts:31-181` | 诚实标注「当前引擎不支持」，`app/lib/core/audio/equalizer_manager.dart:19-23` | L（需换 DSP 引擎） | P2 |
| 迷你窗口/迷你模式 | `src/main/modules/window.ts:153-160` | 缺失 | M | P3 |
| 手机遥控（局域网） | `src/main/modules/remoteControl.ts:50-150` | 缺失 | L | P3 |
| 多语言（5 语言） | `src/i18n/lang/*` | 仅中文（无 i18n 框架） | L | P3 |
| 播客 / MV / 听歌热力图 | `src/renderer/views/podcast|mv|heatmap` | 缺失 | L | P3 |
| 歌词翻译 | `src/renderer/services/lyricTranslation.ts` + opencc | 缺失（仅展示接口自带的 `translation` 字段） | M | P3 |
| 睡眠定时器 | `src/renderer/store/modules/sleepTimer.ts` | **已有**：`audio_player_service.dart:1078-1090` + `app/lib/views/common/modals.dart:362+` | — | 已对齐 |
| 倍速 / 音量 / 静音 | `src/renderer/store/modules/playerCore.ts:60-113` | **已有**：`audio_player_service.dart:913-956` | — | 已对齐 |
| 播放历史 | `src/renderer/store/modules/playHistory.ts` | **已有**：`audio_player_service.dart:953`、`:1127` | — | 已对齐 |
| 数据同步 | 无（Alger 未内置云同步） | **我们有真实 WebDAV + 局域网同步** `app/lib/core/sync/` | — | 我们领先，保留 |

---

## 2. 本轮已落地的 3 个 S 项（真实实现 + 测试）

> 三项均为**纯 Dart 真实实现**，无占位、无假成功；不新增第三方依赖，不改动移动端视图与被占用文件。

### S-01 冷启动续播定位（对标 `playbackController.ts:94-100, 561-574`）

| 项 | 内容 |
|:--|:--|
| 落盘 | `StorageService.getPlaybackProgress/savePlaybackProgress/clearPlaybackProgress` — `app/lib/core/storage/storage_service.dart:138-168`；快照类 `:398-404` |
| 节流写入 | 播放中每前进 5s 落盘一次 — `app/lib/core/audio/audio_player_service.dart:343-351` |
| 即时写入 | 暂停 `:518-524`、拖动进度条 `:873-885` |
| 冷启动恢复 | 只恢复「队列 + 当前曲目 + 位置」，**不自动出声**；距结尾 5s 内回到开头；曲目 ID 不匹配则丢弃 — `:256-271` |
| 真实 seek | 统一起播入口 `_dispatchToBackend`，起播并重放用户偏好后真实 `backend.seek(续播点)` — `:373-382`，三个取流分支共用 `:631, 692, 721` |

**测试**（`app/test/alger_parity_s_features_test.dart`）
- 暂停后冷启动恢复到上次听到的位置，并在真实起播时 seek 回去（断言后端真实 `position == 42s`）。
- 换到另一首后不会把上一首的续播位置套用过来（断言起播仍为 `0`）。

### S-02 队列：真实随机播放顺序 + 插入「下一首播放」（对标 `playlist.ts:178-221, 336-350`）

| 项 | 内容 |
|:--|:--|
| 修复的真实缺陷 | 旧 `next()` 在随机模式下每次新建 `Random()` 抽下标，**可能抽到当前曲目**（按下一首无反应）且一轮内可重复 |
| 洗牌牌堆 | Fisher-Yates 生成排列 + 游标；一轮内每首恰好一次；牌堆用尽重新洗牌且保证不立刻重播上一首 — `audio_player_service.dart:771-813` |
| previous 真实历史 | 随机模式 `previous()` 沿牌堆回退，不再随机乱跳 — `:736-745` |
| 切模式不打断 | 进入随机把当前曲目置牌堆首位 — `:973-985` |
| 插入下一首 | `playNext()` 真实 `insert(currentIndex+1)`，随机模式同步重映射牌堆 — `:1009-1041`；UI 入口 `app/lib/views/desktop/desktop_views.dart:1706` |
| 队列增删自愈 | `addToQueue` 随机下排到当前之后 `:992-1007`；`removeTrackAt` 重映射下标与牌堆 `:1043-1060`；`clearQueue` 清牌堆 `:1066-1075` |

**测试**
- 随机播放一轮内覆盖全部曲目且不连续重复（含跨越重新洗牌的一整轮，断言新一轮首曲 ≠ 上一首）。
- 随机模式下 previous 回到真实上一首，而不是随机乱跳。
- playNext 把曲目真实插入当前之后，next 立即播放它。
- 随机模式下 playNext / addToQueue 的曲目都在下一首播放。
- 从队列移除曲目后随机游标仍指向真实当前曲目（含移除当前曲目本身不越界）。

### S-03 本地文件夹递归扫描 + 增量导入（对标 `localMusicScanner.ts:152-248, 256-301`、`localMusic.ts:159-271`）

| 项 | 内容 |
|:--|:--|
| 目录选择 | `LocalMusicService.pickLocalAudioFolder()` — `app/lib/core/sources/local_music_service.dart:47-48` |
| 递归扫描 | `scanDirectoryForAudio()`：扩展名大小写不敏感、递归子目录、排序去重、不可读子目录跳过而非整库失败、目录不存在**如实抛错** — `:63-80` |
| 增量入库 | `AudioPlayerService.importLocalFolderPath()`：按真实路径去重，返回 `{scanned, added, skipped}` 真实计数 — `audio_player_service.dart:413-436`；结果类 `local_music_service.dart:106-125` |
| UI | 「导入整个文件夹」按钮 + 诚实计数提示 — `app/lib/views/desktop/desktop_views.dart:1595-1614`、`:1642-1661` |
| 诚实边界 | 只做**路径级**真实扫描；不做标签解析、不编造歌手/专辑/时长（时长仍由真实解码回填） |

**测试**
- 递归扫描只收录真实存在的受支持音频文件（`.mp3`/`.FLAC`/子目录 `.m4a`/`.opus` 收录；`.txt`/无扩展名排除；扩展名大小写不敏感）。
- 目录不存在时如实抛 `FileSystemException`，不伪装成空成功。
- 文件夹导入是真实增量：第二次导入全部跳过、不重复入库，标题取自真实文件名。

---

## 3. 未动手的中/高成本项（只写清单与建议）

> 以下**本轮未改任何代码**，仅登记建议顺序，供后续排期。

| 顺序 | 事项 | 成本 | 前置条件 / 建议 |
|:-:|:--|:--|:--|
| 1 | 播放失败「有限重试 → 自动跳过」+ 切歌竞态取消 | S / M | 纯 Dart，可先单测；注意保持「诚实提示 + 不伪造播放」的既有约束 |
| 2 | 跟随系统主题 + 歌词外观配置（字号/行高/聚焦）+ 持久化 | S | 无新依赖，UI 改动集中在设置中心与全屏歌词 |
| 3 | 快捷键纯 Dart 模型（默认表/归一化/冲突检测/保留键/持久化） | S | 先做模型与单测，再评估插件注册 |
| 4 | 系统媒体控制（媒体键/锁屏/SMTC/MPRIS） | L | **与引擎选型一起决策**（当前 `audioplayers` 受限），需五端真机验证 |
| 5 | 托盘 + 关闭到托盘 | M | 需 `system_tray` 类插件；三端验证；与快捷键同批做 |
| 6 | 本地曲库 ID3/FLAC 标签解析 + 内嵌封面落盘 | M | 需引入 music-metadata 等价 Dart 包并真机验证；失败必须回退「未知」 |
| 7 | 下一首取流预加载 | M | 需给已解析 URL 加 TTL 与失效清理，否则会命中过期直链 |
| 8 | 磁盘音频缓存（LRU + 上限 + 清理） | L | 与预加载共享「URL/文件索引」；统计必须真实 |
| 9 | 桌面更新检查（诚实提示，不自动安装） | M | 无网络必须显示「检查失败」，不得显示「已是最新」 |
| 10 | 桌面歌词独立窗口（置顶/锁定/穿透/位置持久化） | L | 需窗口插件 + 三端真机；建议在托盘/媒体控制之后 |
| 11 | 完整下载器（并发/续传/写标签/通知）、手机遥控、多语言、播客/MV/热力图 | L | 价值密度低于上述项，靠后 |
| 12 | EQ 真实生效 | L | 需替换/包装音频引擎，与第 4 项合并评估 |

---

## 4. 证据与复现

**对标仓库**
```bash
rm -rf /tmp/alger-ref
git clone --depth 1 https://github.com/algerkong/AlgerMusicPlayer /tmp/alger-ref
cd /tmp/alger-ref && git log -1 --format='%H %ad'   # b277ef1... 2026-09-19
grep -m1 '"version"' package.json                    # 5.1.0
```
本清单所有 Alger 侧 `file:line` 均可在该 commit 下用 `grep -n` 直接复核，例如：
```bash
grep -nE "setIgnoreMouseEvents|lyricWindowBounds" src/main/lyric.ts
grep -nE "globalShortcut.register" src/main/modules/shortcuts.ts
grep -nE "music-metadata|parseFile|extractCover" src/main/modules/localMusicScanner.ts
grep -nE "mediaSession" src/renderer/services/audioService.ts
```

**本方验证**
```bash
cd app && flutter analyze            # 期望：No issues found!
cd app && flutter test               # 本轮实测：177 passed（基线 160 + 本 agent 新增 10 + 并行 agent 新增 7）
cd app && flutter test test/alger_parity_s_features_test.dart   # 本轮新增 10 项
```

**本轮改动文件**
- `app/lib/core/audio/audio_player_service.dart`（续播、洗牌牌堆、playNext、队列索引自愈、本地文件夹导入）
- `app/lib/core/storage/storage_service.dart`（播放进度快照读写）
- `app/lib/core/sources/local_music_service.dart`（目录递归扫描 + 导入结果计数）
- `app/lib/views/desktop/desktop_views.dart`（文件夹导入按钮、下一首播放按钮）
- `app/test/alger_parity_s_features_test.dart`（新增 10 项测试）

**未触碰**（按分工要求）：`app/lib/views/mobile/**`、`app/lib/navigation/mobile_scaffold.dart`、`app/integration_test/**`、`docs/e2e/ledger-*.md`、`docs/e2e/ledger-desktop-visual.md`。
