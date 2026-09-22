> # ⚠️ 本规范是「目标设计」，不是已交付实现（2026-09-22 校准）
>
> 本 SPEC 第 4~7 章声称的核心依赖（`media_kit` + `audio_service` 双流播放、`flutter_js` QuickJS 音源沙箱、`Drift` + SQLite3 数据库、`desktop_multi_window` 穿透歌词、`go_router` 强类型 34 路由、`libmpv firequalizer` EQ）**在 `app/pubspec.yaml` 中一项都不存在**；其中音源沙箱与同步引擎共 3319 行代码在生产代码中 **0 引用**（仅被测试引用）。
>
> **接手前请先读**：[`docs/PC_E2E_ACCEPTANCE_ISSUES.md`](PC_E2E_ACCEPTANCE_ISSUES.md)（验收问题清单 44 条，含逐条"文档声称 vs 代码实现"对照）+ [`docs/PC_E2E_FIX_PLAN.md`](PC_E2E_FIX_PLAN.md)（修复建议）。
>
> ---

# Mellow Music · 润音 · 跨平台生产级客户端系统工程规范说明书 (System Specification)

> **版本**：v1.1.0 (Full-Platform & E2E Verification Specification)  
> **生效时间**：2026-09-22  
> **系统定位**：融合 **AlgerMusicPlayer** 的极致视觉美学（Modern Soft UI 现代柔和质感、声学生态流体光晕、巨幕动效歌词）与 **LX-Music (洛雪音乐)** 强大音源沙箱与多端同步能力，面向 **Windows、macOS、Linux、Android、iOS、鸿蒙 (HarmonyOS / OpenHarmony)** 的全平台高保真无损音乐播放系统。

---

## 目录 (Table of Contents)
1. [系统总体架构规范](#1-系统总体架构规范)
2. [Modern Soft UI 设计系统规范 (Design Tokens)](#2-modern-soft-ui-设计系统规范-design-tokens)
3. [双端全量路由与信息架构规范 (Zero-Omission IA)](#3-双端全量路由与信息架构规范-zero-omission-ia)
4. [音频播放底座与系统通道规范 (Audio & Media Pipeline)](#4-音频播放底座与系统通道规范-audio--media-pipeline)
5. [QuickJS 音源脚本沙箱与接口规范 (Source Script Sandbox)](#5-quickjs-音源脚本沙箱与接口规范-source-script-sandbox)
6. [双模动效歌词与独立穿透窗口规范 (Kinetic Lyrics Engine)](#6-双模动效歌词与独立穿透窗口规范-kinetic-lyrics-engine)
7. [本地数据库模型与多端同步规范 (Drift & Sync Protocol)](#7-本地数据库模型与多端同步规范-drift--sync-protocol)
8. [工程目录结构与交付规范 (Project Structure)](#8-工程目录结构与交付规范-project-structure)
9. [全平台产物端到端 (E2E) 闭环验收与质量红线规范 (Hard Quality Gate)](#9-全平台产物端到端-e2e-闭环验收与质量红线规范-hard-quality-gate)
10. [多端 CI/CD 自动化发版流水线规范 (GitHub Actions Pipeline)](#10-多端-cicd-自动化发版流水线规范-github-actions-pipeline)

---

## 1. 系统总体架构规范

### 1.1 架构分层
系统严格遵循 **分层响应式架构 (Layered Reactive Architecture)**，分为表现层、状态控制层、核心引擎层与基础设施层：

```
+-------------------------------------------------------------------------+
|                  1. 表现层 (Presentation Layer - Flutter)                |
|  - 响应式双壳 (Adaptive DesktopScaffold / MobileScaffold)                 |
|  - Modern Soft UI 原子组件库 (SoftCard, SoftButton, RecessedWell, Glow)    |
|  - 桌面端 12 主视图 + 4 弹窗抽屉 | 移动端 4 主 Tab + 9 二级页 + 5 底部抽屉   |
+-------------------------------------------------------------------------+
                                    | Stream & BLoC Events
+-------------------------------------------------------------------------+
|                  2. 业务与状态层 (Business Logic Layer)                  |
|  - PlayerBloc (播放状态机、队列控制、三态循环、历史追踪)                     |
|  - SourceBloc (QuickJS 音源沙箱管理、全网多平台聚合搜索)                   |
|  - SyncBloc (WebDAV 增量同步客户端、LX-Sync 局域网配对服务端/客户端)       |
|  - StorageBloc (Drift 本地曲库流式查询、离线缓存管理、外部歌单导入)          |
|  - SettingsBloc (深浅主题、5大强调色、弥散浓度、DSP EQ 曲线调校)           |
+-------------------------------------------------------------------------+
                                    | FFI & MethodChannels
+-------------------------------------------------------------------------+
|                  3. 核心引擎层 (Core Engines & Runtime)                 |
|  - 音频底座：media_kit (C 原生 libmpv，支持 FLAC/APE/DSD/Hi-Res 无损解码)    |
|  - 系统通道：audio_service (Win SMTC / Android MediaSession / iOS Control) |
|  - 脚本沙箱：flutter_js (QuickJS 原生内存沙箱 + Dart Polyfill 桥接层)     |
|  - 歌词引擎：LRC/QRC 毫秒级解析器 + 60fps 贝塞尔插值平滑渲染驱动器           |
|  - 悬浮窗口：desktop_multi_window + Win32/macOS 鼠标透明穿透通道          |
+-------------------------------------------------------------------------+
                                    | SQLite3 C-API & I/O
+-------------------------------------------------------------------------+
|                  4. 基础设施与持久化 (Infrastructure Layer)              |
|  - 数据库：Drift (SQLite3 FTS5 全文搜索、多对多歌单外键、响应式 Stream)     |
|  - 缓存库：LRU 无损流式切片缓存、离线曲目归档目录                           |
|  - 局域网传输：内置轻量 WebSocket/HTTP 同步服务器 (监听 23332 端口)          |
+-------------------------------------------------------------------------+
```

---

## 2. Modern Soft UI 设计系统规范 (Design Tokens)

### 2.1 画布与表面基色 (Surfaces & Canvas)
| Token 标识符 | 浅色模式 (温润白瓷 Porcelain) | 深色模式 (深石墨夜间 Graphite) | 说明与视觉作用 |
| :--- | :--- | :--- | :--- |
| `surface-canvas` | `#F5F7FB` (冷灰瓷质底色) | `#0D1117` (深石墨夜间底色) | 全局底层背景，杜绝刺眼纯白与死黑 |
| `surface-card` | `#FFFFFF` (柔和微浮卡片) | `#161B22` (次级石墨浮雕层) | 承载功能块与列表卡片 |
| `surface-recessed` | `#EBF0F8` (内凹沉槽背景) | `#0B0E14` (内凹沉槽暗区) | 搜索栏、进度槽、EQ 滑块背景 |
| `surface-sidebar` | `rgba(255, 255, 255, 0.75)` | `rgba(22, 27, 34, 0.8)` | 侧边栏与底栏毛玻璃毛化层 (`blur(20px)`) |

### 2.2 五大声学柔光强调色 (Acoustic Accent Colors)
系统支持 5 种高品质声学主色，动态作用于播放指示条、高亮歌词、音量游标与弥散光斑：
1. **Oceanic Blue (浩瀚蔚蓝 - 默认)**：`#3B82F6` (Light) / `#60A5FA` (Dark)
2. **Lavender Purple (星河微紫)**：`#8B5CF6` (Light) / `#A78BFA` (Dark)
3. **Blossom Pink (晨樱柔粉)**：`#EC4899` (Light) / `#F472B6` (Dark)
4. **Amber Gold (琥珀金晖)**：`#F59E0B` (Light) / `#FBBF24` (Dark)
5. **Emerald Jade (碧波翡翠)**：`#10B981` (Light) / `#34D399` (Dark)

### 2.3 三层漫散射景深阴影规范 (Layered Diffused Shadows)
摒弃粗糙生硬的黑投影，采用 3 级高扩散、低浓度（4%~8%）的环境光漫散射阴影：
- **Flat Card (微浮卡片)**：
  ```css
  box-shadow: 0 4px 20px -2px rgba(15, 23, 42, 0.05),
              0 2px 6px -1px rgba(15, 23, 42, 0.03),
              inset 0 1px 0 rgba(255, 255, 255, 0.9);
  ```
- **Floating Pill (悬浮胶囊/底栏)**：
  ```css
  box-shadow: 0 20px 40px -8px rgba(15, 23, 42, 0.12),
              0 8px 16px -4px rgba(15, 23, 42, 0.06),
              inset 0 1px 0 rgba(255, 255, 255, 0.8);
  ```
- **Recessed Well (内凹沉槽)**：
  ```css
  box-shadow: inset 0 2px 4px rgba(15, 23, 42, 0.06),
              inset 0 1px 2px rgba(15, 23, 42, 0.04),
              0 1px 0 rgba(255, 255, 255, 0.8);
  ```

### 2.4 圆角曲率与物理触觉反馈
- **连续曲率圆角 (Squircle)**：
  - 窗口与大卡片：`radius = 24px`；
  - 悬浮胶囊与操作按钮：`radius = 9999px` (全胶囊)；
  - 歌曲封面与列表条目：`radius = 16px`。
- **触感按压 (Tactile Press)**：所有交互按钮在 PointerDown 时执行：
  `transform: scale(0.97)`，动画曲线 `Cubic(0.2, 0.8, 0.2, 1.0)`，耗时 `150ms`。

---

## 3. 双端全量路由与信息架构规范 (Zero-Omission IA)

自适应布局以 `1024px` 为断点。所有视图采用强类型路由 (`go_router`)，并配合 `PageStorageKey` 保证切换 Tab 或页面时不丢弃滚动状态与播放状态。

### 3.1 桌面端视图与模态 (12 视图 + 4 弹窗抽屉)
| 模块 ID | 路由路径 | 对应组件类名 | 详细交互规范 |
| :--- | :--- | :--- | :--- |
| `viewDiscover` | `/desktop/discover` | `DesktopDiscoverView` | Bento Grid 仪表盘：今日私享雷达 Hero 卡片、推荐歌单网格、热门歌手环、新歌速递流 |
| `viewPlaylists` | `/desktop/playlists` | `DesktopPlaylistSquareView` | 歌单广场：全部分类/流行/治愈/电音/民谣多胶囊即时过滤，瀑布流卡片展示 |
| `viewToplist` | `/desktop/toplist` | `DesktopToplistView` | 官方巅峰榜：飙升/热歌/新歌/原创榜，前三名冠亚季军特殊徽章排位，支持一键整榜播放 |
| `viewArtists` | `desktop/artists` | `DesktopArtistsView` | 热门歌手库：圆形头像柔和微凹描边、官方认证徽标、粉丝数量格式化与专页跳转 |
| `viewArtistDetail` | `/desktop/artist/:id` | `DesktopArtistDetailView` | 歌手详情：超大圆角海报背景、关注/已关注本地持久化状态、精选代表作与专辑列表 |
| `viewPodcast` | `/desktop/podcast` | `DesktopPodcastView` | 声音电台：深夜治愈、助眠白噪、音乐故事、科技前沿 4 大板块单集试听 |
| `viewFavorite` | `/desktop/favorite` | `DesktopFavoriteView` | 我喜欢的音乐：红心曲目清单、收藏总数角标、批量播放、取消/收藏即时响应 |
| `viewHistory` | `/desktop/history` | `DesktopHistoryView` | 播放历史：按播放时间戳倒序呈现完整足迹，支持单曲移除与一键清空 |
| `viewLocal` | `/desktop/local` | `DesktopLocalMusicView` | 本地与下载：拖拽/点击导入音频文件（FLAC/APE/MP3/WAV）、比特率解析、离线曲库回放 |
| `viewSettings` | `/desktop/settings` | `DesktopSettingsView` | 设置中心：深浅色切换、5 大强调色圆盘、弥散光晕浓度滑块、音源管理与音质首选项 |
| `fullscreenLyrics` | `/desktop/lyrics` | `DesktopFullscreenLyricsView` | 巨幕歌词大屏 (MusicFull)：左侧微凹旋转黑胶唱机+唱臂，右侧 Apple Music 动效歌词 |
| `viewSourceManager` | `/desktop/sources` | `DesktopSourceManagerView` | LX 音源管理：本地脚本导入、网络 URL 订阅、热重载、可用性测试与启用开关 |
| `queueDrawer` | `Drawer` | `PlaybackQueueDrawer` | 右侧抽屉：当前待播曲目清单、正在播放声波动画指示、单曲删除与一键清空 |
| `eqModal` | `Dialog` | `EqualizerModal` | 声学 10 频段 EQ：31Hz~16kHz 垂直触觉滑块、Flat/Bass/Vocal/Jazz/Spatial 预设一键套用 |
| `sleepTimerModal` | `Dialog` | `SleepTimerModal` | 睡眠定时器：15/30/45/60 分钟倒计时选择、当前曲目播完再停止选项、微光呼吸指示 |
| `searchDropdown` | `Overlay` | `QuickSearchOverlay` | 全局联想搜索：快捷键 `Ctrl/Cmd + K` 呼出，毫秒级聚合联想歌手、歌单与单曲 |

### 3.2 移动端视图与模态 (4 主 Tab + 9 二级页 + 5 底部抽屉)
| 模块 ID | 路由路径 | 对应组件类名 | 详细交互规范 |
| :--- | :--- | :--- | :--- |
| **Tab 1: 发现** | `/mobile/tabs/discover` | `MobileDiscoverTab` | 顶部灵动岛沉浸条、全局搜索胶囊、5 大金刚区入口、专属雷达滑动卡片 |
| **Tab 2: 探索** | `/mobile/tabs/explore` | `MobileExploreTab` | 风格标签横滑栏（流行/民谣/电子/Lo-Fi）、每日精选歌单推荐流 |
| **Tab 3: 资料库** | `/mobile/tabs/library` | `MobileLibraryTab` | 个人资料卡片、本地与下载入口、关注歌手快捷入口、红心收藏清单 |
| **Tab 4: 我的** | `/mobile/tabs/profile` | `MobileProfileTab` | 用户中心、深浅色一键切换、强调色圆盘选择、音质偏好与离线缓存清理 |
| `mViewDailyRecommend` | `/mobile/recommend` | `MobileDailyRecommendPage` | 拟物日历便签头（实时系统日期）、6 首个性化日推、一键播放全部 |
| `mViewPlaylistSquare` | `/mobile/playlists` | `MobilePlaylistSquarePage` | 分类胶囊横向滚动筛选，双列歌单网格瀑布流卡片展示 |
| `mViewToplist` | `/mobile/toplist` | `MobileToplistPage` | 四大官方巅峰榜纵向卡片，冠亚季军高亮排位，一键播放榜单 |
| `mViewRadio` | `/mobile/radio` | `MobileRadioPage` | 4 大播客专区，精选单集轻量收听与进度记录 |
| `mViewPersonalFM` | `/mobile/fm` | `MobilePersonalFMPage` | 全屏沉浸黑胶大碟旋转、Next 切歌漫游、红心喜欢切换、垃圾桶屏蔽曲目 |
| `mViewArtists` | `/mobile/artists` | `MobileArtistsPage` | 热门歌手列表，头像微凹描边，粉丝数据展示与快速进入歌手专页 |
| `mViewArtistDetail` | `/mobile/artist/:id` | `MobileArtistDetailPage` | 沉浸式折叠海报、关注/已关注本地状态切换、歌手代表作清单 |
| `mViewLocal` | `/mobile/local` | `MobileLocalMusicPage` | 离线曲库列表、本地文件扫描导入、存储占用容量展示 |
| `mViewPlaylistDetail` | `/mobile/playlist/:id` | `MobilePlaylistDetailPage` | 歌单超大封面头图、作者信息、收藏歌单、播放全部 |
| `mFullLyrics` | `BottomSheet` | `MobilePlayerBottomSheet` | 全屏播放器：大黑胶唱片与 Apple Music 动效歌词双向横滑切换、胶囊进度条拖动 |
| `mQueueSheet` | `BottomSheet` | `MobileQueueBottomSheet` | 底部待播抽屉：向上滑动手势呼出、列表曲目平滑移除与清空 |
| `mEqModal` | `BottomSheet` | `MobileEqBottomSheet` | 移动端 10 频段触控均衡器、声学曲线一键套用 |
| `mSleepTimerModal` | `BottomSheet` | `MobileSleepTimerBottomSheet` | 移动端定时器弹层：多档倒计时选择、倒计时剩余时间微光显示 |
| `mVolumeTrack` | `BottomSheet` | `MobileVolumeModal` | 触觉滑动音量控制条、一键静音与原值记忆恢复 |

---

## 4. 音频播放底座与系统通道规范 (Audio & Media Pipeline)

### 4.1 分级双流通信架构 (Dual-Stream Architecture)
为根治跨平台高频通信引发的卡顿与耗电，系统严格实施**分级双流模型**：

```
       [ media_kit (libmpv C-Core) ]
                     |
       +-------------+-------------+
       |                           |
[ 60Hz 内部高刷流 ]        [ 1s 节流系统广播 ]
       |                           |
  (Dart 内存通道)           (PlatformChannel IPC)
       |                           |
+-------------------+      +-------------------------------+
|  Apple Music 动效歌词 |      |  audio_service                |
|  胶囊进度条毫秒插值  |      |  - Windows SMTC (媒体快捷键)   |
|  声波均衡器跳动      |      |  - Android MediaSession (通知栏)|
+-------------------+      |  - iOS Control Center (锁屏)  |
                           +-------------------------------+
```

1. **60Hz 表现层高刷流**：直接订阅 `player.stream.position`，仅在 Flutter UI 线程内部用于贝塞尔平滑插值滚动与声波绘制，不产生任何系统 IPC 成本。
2. **1s 节流系统广播 (Throttled Broadcast)**：对 `audio_service.playbackState` 上报实施防抖节流。仅当发生以下事件时触发系统状态广播：
   - 播放/暂停状态改变 (`playing: true/false`)；
   - 用户主动拖拽进度条 (`seek`)；
   - 歌曲切换 (`currentTrackChanged`)；
   - 正常播放期间每满整 `1000ms` 周期上报一次。

### 4.2 硬件声学 10 频段 EQ 规范
通过 `media_kit` 向 `libmpv` 动态挂载 `lavfi` 音频滤镜：
```
firequalizer=gain='if(between(f,31,62),G1,if(between(f,63,125),G2,...))'
```
10 组标准中心频率点：`31Hz`, `62Hz`, `125Hz`, `250Hz`, `500Hz`, `1kHz`, `2kHz`, `4kHz`, `8kHz`, `16kHz`。调节范围：`-12dB ~ +12dB`。
- **Flat**：全频段 `0dB` 直通；
- **Bass Boost**：`31Hz (+7dB)`, `62Hz (+5.5dB)`, `125Hz (+3dB)`；
- **Clear Vocal**：`1kHz (+3dB)`, `2kHz (+5dB)`, `4kHz (+3.5dB)`；
- **Warm Jazz**：`125Hz (+2dB)`, `250Hz (+3.5dB)`, `500Hz (+4dB)`, `1kHz (+2dB)`；
- **Spatial 3D**：`62Hz (+2dB)`, `4kHz (+3dB)`, `8kHz (+5dB)`, `16kHz (+6.5dB)`。

---

## 5. QuickJS 音源脚本沙箱与接口规范 (Source Script Sandbox)

### 5.1 沙箱环境与 Dart Polyfill 注入规范
采用 `flutter_js` 构建 QuickJS 独立实例。在载入任何脚本前，Dart 必须向引擎全局空间注入以下标准桥接对象：

```javascript
// Dart 预注入环境对象
globalThis.lx = {
  version: '2.0.0',
  env: 'desktop',
  currentScriptInfo: { name: '', description: '', version: '' },
  EVENT_NAMES: {
    request: 'request',
    inited: 'inited',
    updateAlert: 'updateAlert'
  },
  _listeners: {},
  on(event, handler) { this._listeners[event] = handler; },
  send(event, data) { DartBridge.emit(event, data); },
  request(url, options, callback) {
    // 转发至 Dart 原生 Dio 客户端，完全规避 CORS 限制
    DartBridge.httpRequest(url, options).then(res => {
      callback(null, { statusCode: res.statusCode, headers: res.headers }, res.body);
    }).catch(err => callback(err, null, null));
  },
  utils: {
    buffer: {
      from(data, encoding) { return DartBridge.bufferFrom(data, encoding); }
    },
    crypto: {
      md5(str) { return DartBridge.md5(str); },
      aesEncrypt(buffer, mode, key, iv) { return DartBridge.aesEncrypt(buffer, mode, key, iv); },
      rsaEncrypt(buffer, key) { return DartBridge.rsaEncrypt(buffer, key); }
    }
  }
};
```

### 5.2 脚本动作响应标准 (Action Protocol)
脚本必须响应 `request` 事件，并支持以下 4 类操作并返回 `Promise`：
1. `action: 'search'`：接收 `{ query, page, limit, type }`，返回 `{ total, list: [SongInfo] }`；
2. `action: 'musicUrl'`：接收 `{ musicInfo, quality }`，返回 `{ url: 'https://...' }`；
3. `action: 'lyric'`：接收 `{ musicInfo }`，返回 `{ lyric: '[00:01.00]...', tlyric: '...', lxlyric: '...' }`；
4. `action: 'pic'`：接收 `{ musicInfo }`，返回 `{ url: 'https://...' }`。

---

## 6. 双模动效歌词与独立穿透窗口规范 (Kinetic Lyrics Engine)

### 6.1 应用内全屏动效大幕 (`MusicFull`)
- **动态流体光晕 (Fluid Mesh Glow)**：
  - 提取当前播放专辑封面 3 处主导色彩（主调、亮调、辅调）；
  - 使用 `CustomPainter` 在全屏绘制 3 组具有轻微漂移位移的径向高斯渐变球，层叠 `BackdropFilter(ImageFilter.blur(sigmaX: 90, sigmaY: 90))`；
- **逐字高精度渲染**：
  - 采用动态加权贝塞尔曲线（`Cubic(0.25, 0.1, 0.25, 1.0)`）平滑插值歌词滚动；
  - 激活行采用线性渐变填充高亮并放大至 `1.18x`，非激活行透明度自适应淡出至 `35%`；
  - 支持手指在歌词流中滑动自由拖拽跳播（Seek），抬手即定位。

### 6.2 独立跨平台穿透桌面歌词 (`desktop_multi_window`)
- **多窗口架构**：主窗口与桌面歌词分别运行在独立的 Flutter Engine 实例中；
- **透明与穿透样式注入**：
  - **Windows**：调用 Win32 API 赋予歌词子窗口 `WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOPMOST` 样式，实现鼠标完全穿透；
  - **macOS**：设置 `NSWindow.level = .floating`，并在锁定状态下 `ignoresMouseEvents = true`；
- **锁定时态切换**：
  - **解锁状态**：显示微弱半透明悬浮控制胶囊，支持拖拽移动窗口位置、调整文字大小、关闭歌词；
  - **锁定状态**：控制条自动淡出隐形，窗口全面进入防误触鼠标穿透状态。

---

## 7. 本地数据库模型与多端同步规范 (Drift & Sync Protocol)

### 7.1 Drift (SQLite3 FTS5) 核心表结构规范
```dart
// 1. 本地与在线歌曲元数据表
class SongsTable extends Table {
  TextColumn get id => text()(); // 复合主键 source_songId
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  IntColumn get duration => integer()(); // 毫秒
  TextColumn get source => text()(); // 音源标识 (kw, kg, tx, wy, mg, local)
  TextColumn get localPath => text().nullable()(); // 本地缓存或下载绝对路径
  IntColumn get bitrate => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {id};
}

// 2. 歌单表
class PlaylistsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {id};
}

// 3. 歌单-歌曲关联表 (多对多)
class PlaylistSongsTable extends Table {
  TextColumn get playlistId => text().references(PlaylistsTable, #id)();
  TextColumn get songId => text().references(SongsTable, #id)();
  IntColumn get sortOrder => integer()();
  
  @override
  Set<Column> get primaryKey => {playlistId, songId};
}

// 4. 播放历史表
class HistoryTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get songId => text().references(SongsTable, #id)();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

// 5. 音源脚本配置表
class SourcesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get version => text()();
  TextColumn get scriptContent => text()(); // JS 源码全文
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get subscribeUrl => text().nullable()(); // 订阅自动更新 URL
  
  @override
  Set<Column> get primaryKey => {id};
}
```

### 7.2 局域网直连同步协议规范 (LX-Sync 100% 原生兼容)
- **服务启动**：桌面端监听 `0.0.0.0:23332`，路由端点：
  - `GET /sync/hello`：握手探针，返回服务端版本号与设备名；
  - `WS /sync`：WebSocket 双向长连接，握手阶段进行 RSA/AES 鉴权秘钥交换；
- **数据帧格式**：
  ```json
  {
    "action": "sync_list",
    "version": "1.0.0",
    "data": {
      "defaultList": [ /* 歌曲列表快照 */ ],
      "loveList": [ /* 我喜欢列表快照 */ ],
      "userList": [ /* 用户自建歌单及排序 */ ]
    }
  }
  ```
- **配对交互**：电脑端生成标准二维码格式 `lxsync://192.168.x.x:23332?key=AUTH_KEY`，手机端扫码瞬间自动拉取增量合并。

---

## 8. 工程目录结构与交付规范 (Project Structure)

在项目根目录设立 `app/` 跨平台多端工程，与现存 Web 原型资产共存：

```
mellow-music-player/
├── docs/                                  # 权威工程规范与进度看板
│   ├── ROADMAP.md                         # 架构蓝图与零遗漏对齐矩阵
│   ├── PROGRESS.md                        # 研发里程碑与实时进度看板
│   └── SPEC.md                            # 本系统技术规格说明书 (System Specification)
├── design_tokens.css                      # 原生 Web 质感设计系统变量 (基准参考)
├── index.html / mobile.html               # 100% 验收通过的 Web 高保真双端原型
├── e2e_test.js                            # 83 项全自动化 E2E 交互测试用例集
└── app/                                   # Flutter 跨平台客户端核心源码
    ├── pubspec.yaml                       # 生产级依赖配置清单
    └── lib/
        ├── main.dart                      # 应用程序入口与初始化
        ├── design_system/                 # Modern Soft UI 原子设计系统
        │   ├── tokens.dart                # 色彩、三层阴影、圆角、光晕参数
        │   ├── soft_card.dart             # 微浮柔和卡片
        │   ├── soft_button.dart           # 物理触觉按压按钮 (scale: 0.97)
        │   ├── recessed_well.dart         # 内凹沉槽微阴影组件
        │   └── acoustic_mesh_glow.dart    # 3点流体声学高斯弥散动态光效
        ├── core/                          # 核心底层引擎
        │   ├── audio/                     # media_kit + audio_service 双流播放底座
        │   ├── sources/                   # QuickJS 沙箱 + Dart Polyfill 桥接层
        │   ├── database/                  # Drift SQLite3 FTS5 响应式数据库
        │   └── sync/                      # LX-Sync 局域网直连与 WebDAV 客户端
        ├── navigation/                    # go_router 自适应响应式双壳脚手架
        │   ├── app_router.dart            # 全量强类型路由表
        │   ├── desktop_scaffold.dart      # 桌面端侧边栏与标题栏脚手架
        │   └── mobile_scaffold.dart       # 移动端灵动岛与原生 4-Tab 脚手架
        ├── views/
        │   ├── desktop/                   # 桌面端 12 大核心视图与 4 大抽屉弹窗
        │   │   ├── discover_view.dart
        │   │   ├── playlist_square_view.dart
        │   │   ├── toplist_view.dart
        │   │   ├── artists_view.dart
        │   │   ├── artist_detail_view.dart
        │   │   ├── podcast_view.dart
        │   │   ├── favorite_view.dart
        │   │   ├── history_view.dart
        │   │   ├── local_music_view.dart
        │   │   ├── settings_view.dart
        │   │   ├── fullscreen_lyrics_view.dart
        │   │   ├── source_manager_view.dart
        │   │   └── modals/                # QueueDrawer, EqualizerModal, SleepTimerModal...
        │   └── mobile/                    # 移动端 4 大主 Tab、9 大二级页与 5 大抽屉
        │       ├── tabs/                  # DiscoverTab, ExploreTab, LibraryTab, ProfileTab
        │       ├── pages/                 # DailyRecommend, Square, Toplist, FM, ArtistDetail...
        │       └── sheets/                # PlayerSheet, QueueSheet, EqSheet, TimerSheet...
        └── features/
            └── lyrics/                    # 双模歌词系统 (MusicFull + desktop_multi_window)
```

---

## 9. 全平台产物端到端 (E2E) 闭环验收与质量红线规范 (Hard Quality Gate)

本项目将**产物级真实用户端到端 (E2E) 闭环验收**作为团队交付的**不可逾越之硬性红线 (Hard Quality Gate)**。任何代码合入或发版前，均必须严格执行以下四阶段递进闭环流程：

```
+-------------------------------------------------------------------------------------------------+
|                       产物级用户视角 E2E 闭环研发循环 (E2E User-Centric Loop)                     |
|                                                                                                 |
|   [1. 全平台产物物理编译]                                                                         |
|       │ Windows (.exe) / macOS (.app) / Linux (Bundle) / Android (.apk) / Web (PWA)             |
|       ▼                                                                                         |
|   [2. 真实用户视角 E2E 体验与自动化探索]                                                            |
|       │ 8 大核心业务链路全量巡检、视口缩放、按键监听、手势触控、未捕获异常监控                         |
|       ▼                                                                                         |
|   [3. 结构化缺陷清单记录 (Defect Matrix)]                                                         |
|       │ 录入现象、触发平台、严重程度 (P0~P3)、复现路径与渲染堆栈                                    |
|       ▼                                                                                         |
|   [4. 统一归因修复与全量回归复测]                                                                   |
|       │ 实施代码优化 -> 重新触发全平台编译 -> E2E 回归验证 -> 直至达成【零未捕获缺陷】可交付成果    |
+-------------------------------------------------------------------------------------------------+
```

### 9.1 真实产物编译前置原则 (Real Artifact Compilation First)
- **绝对禁止仅凭单元测试或局部 Widget 测试直接宣布交付**；
- 交付前，当前物理宿主机支持的目标平台必须首先成功编译出完整的生产级发布包（如 Windows `mellow_music.exe`、Android `app-release.apk`、Web 发布包）；
- 跨宿主平台（macOS、Linux、iOS）必须通过 GitHub Actions CI/CD 流水线完成真实容器/虚拟机的交叉编译构建与产物归档。

### 9.2 用户视角 8 大端到端使用链路全景矩阵 (User-Centric E2E Matrix)
测试人员与自动化探针必须以真实最终用户视角，对编译后的可执行产物依次执行以下 8 大业务链路闭环验证：

| 链路编号 | 业务链路场景 | 真实用户行为验证点 | 严格验收标准 |
| :--- | :--- | :--- | :--- |
| **E2E-01** | **冷启动与无边框标题栏交互** | 打开应用、拖拽窗口、最大化/最小化、关闭、深浅色模式切换 | 启动冷加载 `<= 1.2s`，无闪白，暗黑主题切换即时无卡顿，无边框贴靠正常 |
| **E2E-02** | **Bento 仪表盘与全网聚合搜索** | 浏览今日私享雷达、快捷搜索输入、防抖联想、按 Enter 搜索 | 聚合 6 大音源结果并发返回，列表去重，关键词高亮，无布局挤压溢出 |
| **E2E-03** | **多音质无损播放与双重降级** | 点击歌曲播放、切换 128k/320k/FLAC/24bit 母带、单曲/列表/随机切歌 | 触发两重降级：高码率受限平滑回退，首选源下架自动毫秒级跨源热切换源，无爆音 |
| **E2E-04** | **巨幕沉浸黑胶歌词与动力学** | 点击底部 Mini 播放栏展开全屏巨幕 (MusicFull)、跟随歌词滚动 | 黑胶转盘平滑匀速旋转，逐行 LRC 歌词以 60fps 缓动高亮居中，拖拽进度精准对齐 |
| **E2E-05** | **声学 10 频段 EQ 与音质调校** | 呼出均衡器弹窗、切换 9 款声学预设 (摇滚/重低音等)、手动拖拽 10 频段滑块 | 图形滑块阻尼触感灵敏，实时生成 libmpv `firequalizer` 参数，音色变化平滑无咔嗒声 |
| **E2E-06** | **多端数据协同与 WebDAV 备份** | 配置 WebDAV 地址与账号、点击探活、手动上传快照、一键恢复 | PROPFIND/PUT 全链路通畅，执行毫秒级 LWW (Last-Write-Wins) 冲突解决，歌单数据零丢失 |
| **E2E-07** | **局域网近场直连与扫码互传** | 开启本机局域网服务、展示 `lxsync://` 配对二维码、跨机握手投送快照 | 端口 23332 握手成功，配对密钥安全校验通过，支持与原生 LX-Music 双向收发报文 |
| **E2E-08** | **双端自适应触控与折叠屏分流** | 拖动浏览器/窗口边界使其跨越 800px 阈值，或在桌面上切换手机预览模式 | $\ge 800\text{px}$ 稳定展示桌面工作台，$< 800\text{px}$ 零缝隙切换为移动端 4-Tab 触控底栏 |

### 9.3 缺陷日志矩阵与闭环修复机制 (Defect Matrix & Resolution Loop)
在各端测试过程中发现的任何问题，必须统一记录入结构化缺陷追踪看板：
1. **缺陷标识与元数据**：记录缺陷 ID、发现平台（Win/Mac/Linux/Android/iOS/Web）、视口分辨率、所属 E2E 场景；
2. **严重级别分类**：
   - `P0 (阻断性)`：进程闪退、编译崩溃、死循环卡死、核心音频流断流；
   - `P1 (严重性)`：音源换源彻底失败、数据同步丢失、布局严重破坏或溢出；
   - `P2 (一般性)`：动效掉帧、深色模式个别文字对比度不足、缓存清理延迟；
   - `P3 (轻微性)`：非核心文案瑕疵、微小圆角偏差；
3. **闭环验收条件**：**必须实现 P0 与 P1 零遗留，P2 修复率 `>= 95%`，未捕获异常 (Uncaught Exceptions) 必须为 0**。

### 9.4 本地桌面物理可执行产物 (Binary E2E) 进程级验收规范
- **物理可执行二进制前置**：必须针对物理编译出的 `app/build/windows/x64/runner/Release/mellow_music.exe`（包含 `flutter_windows.dll`、`data/app.so`）执行实际进程级端到端启动验收；
- **自动化探针驱动脚本**：运行 `windows_physical_client_e2e_verify.ps1`，自动化捕获：
  1. 操作系统物理进程 PID 正常分配；
  2. Win32 消息循环正常初始化，主窗口无静默崩溃，`$proc.Responding == true`；
  3. 工作集内存分配稳定（常规常驻约 150MB 物理内存），无内存暴涨或泄漏；
  4. 进程退出前支持平滑优雅终止，句柄正常释放。

---

## 10. 多端 CI/CD 自动化发版流水线规范 (GitHub Actions Pipeline)

为保障跨平台发布质量与工程交付效率，项目全量集成 GitHub Actions 自动化流水线：

### 10.1 持续集成门禁 (`.github/workflows/ci.yml`)
- **触发时机**：每次对 `main` 分支的 Push 或 Pull Request；
- **拦截规则**：
  1. `flutter analyze` 静态代码分析必须达到 **No issues found!**（0 错误、0 警告、0 提示）；
  2. `flutter test` 全量单元与集成测试必须达到 **100% 全部通过**（包含客户端原生全链路 E2E 旅程测试，共 55/55 Suites）；
  3. 并发触发 `build-windows-desktop-client` 在 `windows-latest` 上构建 Windows 原生 Release 可执行产物并上传归档；
  4. 自动编译 Web Release 产物并通过跨平台自适应探针执行真实浏览器端到端渲染挂载验收。

### 10.2 多端并发发版流水线 (`.github/workflows/release.yml`)
- **触发时机**：推送以 `v*` 开头的版本 Tag（如 `git push origin v1.0.0`）或在 Actions 面板手动派发；
- **并发构建矩阵 (`strategy.matrix`)**：
  1. `build-windows` (`windows-latest` 虚拟化宿主)：编译 Windows x64 原生应用并打包为 `Mellow-Music-Windows-x64.zip`；
  2. `build-macos` (`macos-14` Apple Silicon 宿主)：编译 macOS 原生 App 并打包为 `Mellow-Music-macOS.zip`；
  3. `build-linux` (`ubuntu-latest` 容器环境)：安装 Clang/CMake/GTK3 运行时，编译 Linux Bundle 并打包为 `Mellow-Music-Linux-x64.tar.gz`；
  4. `build-android` (`ubuntu-latest` 容器环境)：配置 JDK 17 与 Android SDK，编译发布版并重命名为 `Mellow-Music-Android.apk`；
  5. `build-web` (`ubuntu-latest` 容器环境)：编译静态 Web PWA 独立部署包并压缩为 `Mellow-Music-Web.tar.gz`；
- **聚合发布 (`publish-release`)**：
  - 汇聚所有平台的编译归档产物；
  - 自动通过 `softprops/action-gh-release` 创建正式的 GitHub Release，并将上述 5 大平台的独立安装包作为 Release Assets 上传发布，全球用户可直接点击下载安装。

