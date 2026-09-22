# Mellow Music · 润音 — Flutter 客户端深度代码 Review

> **评审对象**：E:/code/AI/vibCoding/mellow-music-player/app/（app/lib 26 个 Dart 文件 / 11245 行；app/test 8 个文件；app/integration_test 1 个文件）
> **评审基准**：以代码为唯一事实来源，对照 docs/SPEC.md（362 行）与 docs/PROGRESS.md（82 行）的对外声明逐条核实。
> **评审方式**：全量读取 26 个 lib 文件 + 9 个测试文件 + 平台构建配置（Windows/macOS/Android/Linux/web）+ 2 个 GitHub Actions workflow + server.js，并用 ripgrep 对 20+ 组关键 API 做存在性验证。
> **环境限制（必须声明）**：本机 **未安装 Flutter/Dart 工具链**（Get-Command flutter 返回"无法将 flutter 项识别为 cmdlet"），因此 flutter analyze / flutter test / flutter build **无法实际执行**。所有关于"测试是否通过""0 告警"的结论只能基于源码静态阅读，凡不能证实的均标注为「未验证」。
> **行号口径**：本报告中 文件:行号 全部来自逐行读取（Get-Content 计数会把末尾无换行的最后一行漏掉，故与 Measure-Object -Line 存在 ±1~70 行差异，本报告统一采用逐行读取口径）。

---

## 0. 总体结论

我读到的代码是：**一个视觉完成度很高、但功能内核几乎全部为模拟数据的 UI 演示工程（high-fidelity prototype），被包装并对外声明为"生产级跨平台音乐播放器"。**

三个最关键的判定：

1. **不存在任何真实音频播放能力。** app/lib 中 media_kit / just_audio / audioplayers / audio_service / dart:ffi / MethodChannel 的匹配数 **全部为 0**。pubspec.yaml 的 11 个依赖里没有任何音频相关包。所谓"播放"是 Timer.periodic(50ms) 手工把 _position 加 50ms（audio_player_service.dart:305-329）。→ 用户点击播放按钮**不会发出任何声音**。
2. **不存在任何持久化。** SharedPreferences / shared_preferences 在整个 app/lib 的匹配数为 **0**。收藏、历史、歌单、主题、EQ、音源配置全部是内存中的 ChangeNotifier 字段，进程退出即归零。→ 重启后用户所有个性化设置与收藏**全部丢失**。
3. **SPEC 声明的技术栈与依赖清单基本落空。** SPEC 声称的 8 项核心技术（media_kit / audio_service / flutter_js QuickJS / Drift SQLite / desktop_multi_window / go_router / PlayerBloc 系 / libmpv firequalizer）**无一项存在于依赖或代码中**。go_router 甚至已写进 pubspec.yaml 却在 lib 中 0 次使用。

**代码量分布**：11245 行中有 **约 3319 行（29.5%）在 main() 的调用图上完全不可达**——core/sources/lx_script_sandbox.dart(1204) + core/sources/lx_source_model.dart(632) + core/sync/sync_data_model.dart(573) + core/sync/lan_sync_service.dart(509) + core/sync/webdav_sync_service.dart(401)，这五个文件在整个 app/lib 中**没有任何一个文件 import 它们**（仅在 app/test 下被 4 个测试文件 import）。也就是说：SPEC 里最"重"的两个交付物（QuickJS 音源沙箱、多端同步引擎）在真实 App 里是**死代码**；UI 上对应的"LX 音源管理""多端同步中心"页面是**纯静态展示**。

---

## 1. [P0] 完全没有音频播放能力，播放按钮是一个 50ms 计时器

- **位置**：app/pubspec.yaml:30-46；app/lib/core/audio/audio_player_service.dart:129-134, 305-329；app/lib/core/audio/track_model.dart:55
- **证据**：
  - 依赖清单（pubspec.yaml:36-46）只有 cupertino_icons / google_fonts / provider / go_router / intl / shared_preferences / http / dio / crypto / path_provider / path，**无任何音频包**。
  - ripgrep `media_kit|just_audio|audioplayers|audio_service|dart:ffi|MethodChannel|AudioPlayer(` over app/lib → **0 matches**。
  - 我读到的 play() 实现是：
    ```dart
    void play() {
      if (_playlist.isEmpty) return;
      _isPlaying = true;
      _startPositionTicker();   // 只是启动一个定时器
      notifyListeners();
    }
    ```
  - 进度推进（audio_player_service.dart:304-329）：
    ```dart
    // 60fps 高刷进度驱动 (前台丝滑歌词插值，每 50ms 模拟推进)
    void _startPositionTicker() {
      _positionTicker?.cancel();
      _positionTicker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        final track = currentTrack;
        if (track == null) return;
        final nextPos = _position + const Duration(milliseconds: 50);
        ...
      });
    }
    ```
  - Track.audioUrl 字段（track_model.dart:55）在整个 lib 中**从未被读取用于播放**，只在构造与序列化时传递。
- **影响**：
  - **核心功能不存在**。产品名"音乐播放器"与事实不符，任何真实用户 3 秒内即可发现。
  - 没有系统媒体控制（Windows SMTC / Android MediaSession / iOS Now Playing / MPRIS），没有后台播放、没有音频焦点、没有耳机线控、没有蓝牙 AVRCP，没有 wakelock（ripgrep `WakelockPlus|wakelock` → 0 matches），播放时设备会正常息屏。
  - 没有解码能力，SPEC 宣称的 FLAC/APE/DSD/Hi-Res 全部为虚构。
- **建议**：选定 media_kit（libmpv，跨平台且与 SPEC 叙事一致）或 just_audio + audio_service，新增依赖并实现 AudioPlayerServiceImpl，把 AudioPlayerService 改为对播放器状态的监听转发（StreamSubscription → notifyListeners），删除手工 ticker；同时接入 audio_service 的 PlaybackState 上报与 MediaItem 元数据。

---

## 2. [P0] 零数据持久化：收藏/历史/歌单/设置/EQ/主题/音源配置重启即全部丢失

- **位置**：app/lib/core/audio/audio_player_service.dart:19-22, 76-80；app/lib/design_system/theme_provider.dart:6-8；app/lib/core/audio/equalizer_manager.dart:32-34；app/pubspec.yaml:41
- **证据**：
  - ripgrep `SharedPreferences|shared_preferences` over app/lib → **0 matches**（依赖声明了 shared_preferences: ^2.5.5 但代码从未 import）。
  - 所有用户数据都是内存字段（audio_player_service.dart:19-22）：
    ```dart
    final List<Track> _playlist = List.from(mockPresetTracks);
    final List<Track> _playHistory = [];
    final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};  // 硬编码预置收藏
    final List<ImportedPlaylist> _importedPlaylists = [];
    ```
  - ThemeProvider 只有 bool _isDarkMode = false; AccentColorType _accentType = AccentColorType.blue; double _glowIntensity = 0.65;（theme_provider.dart:6-8），无任何读写存储的代码。
  - EqualizerManager._bandGains（equalizer_manager.dart:32）同样只在内存。
  - 我读到的构造函数甚至在启动时硬塞一条假历史（audio_player_service.dart:76-80）：
    ```dart
    AudioPlayerService() {
      if (_playlist.isNotEmpty) { _recordHistory(_playlist[0]); }
    }
    ```
    → 首次启动"播放历史"永远已有 1 条。
  - **副作用**：由于 _favoriteIds 预置了 4 个 id，desktop_views.dart:1526 的"已同步红心收藏 N 首"在任何真实使用前就显示 ≥4 首，永久虚高。
- **影响**：
  - 用户收藏的歌、导入的歌单、播放历史、睡眠定时器偏好、主题/强调色/光晕浓度、10 频段 EQ 曲线、音源启用状态——**全部在关闭 App 后丢失**。
  - 「已同步红心收藏」文案（desktop_views.dart:1526）与实际存储行为矛盾。
  - 无任何本地曲库/缓存能力；SPEC 第 7 章「Drift (SQLite3 FTS5) 核心表结构规范」在代码中 **0 实现**（ripgrep `drift|sqlite|sqflite|openDatabase` over app/lib 的 9 条命中全部是 lx_script_sandbox.dart 里的 _mockDatabase 变量名，与数据库无关）。
- **建议**：接入 shared_preferences 存轻量设置（主题/EQ/音源启用），接入 drift 或 sqflite 存收藏/歌单/历史（SPEC 已给出表结构，可直接落地）；为每个 ChangeNotifier 加 toJson/fromJson + 启动时 load()，并在 provider 的 create 中 await 初始化后再 runApp。

---

## 3. [P0] Android release APK 缺失 INTERNET 权限——线上包所有网络功能静默失效

- **位置**：app/android/app/src/main/AndroidManifest.xml（全文 41 行，无 uses-permission）；对照 app/android/app/src/debug/AndroidManifest.xml、app/android/app/src/profile/AndroidManifest.xml
- **证据**：
  - main/AndroidManifest.xml 我读到的全部内容是 manifest → application android:label="app" → activity → queries，**没有 uses-permission android:name="android.permission.INTERNET"**。
  - debug/AndroidManifest.xml 与 profile/AndroidManifest.xml 各有一行：
    ```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    ```
    但注释明确写着 "The INTERNET permission is required **for development**"——这是 Flutter 模板的默认状态，release 变体不会合并 debug manifest。
  - .github/workflows/release.yml:161 执行的正是 flutter build apk --release。
- **影响**：
  - **release APK 装到手机上是一个完全离线的空壳**：所有 Image.network（封面、歌手头像）全部走 errorBuilder 降级成灰色占位音符；OnlineMusicService 的 http.get 抛出 SocketException，被 catch (_) {}（online_music_service.dart:80/157/182）**静默吞掉**，搜索永远返回空、导入歌单永远提示"解析失败，请检查歌单ID或网络连接"（modals.dart:773）。
  - 用户与测试都拿不到任何"权限不足"的错误提示，属于最难排查的一类线上故障。
- **建议**：在 main/AndroidManifest.xml 顶部补 uses-permission INTERNET（若要做 LAN 同步补 ACCESS_NETWORK_STATE / ACCESS_WIFI_STATE），并在 release 流水线里加一条 aapt dump permissions 断言。

---

## 4. [P0] macOS release 构建缺少 network.client entitlement——发布版所有出网请求被沙箱拒绝

- **位置**：app/macos/Runner/Release.entitlements；对照 app/macos/Runner/DebugProfile.entitlements
- **证据**：
  - 我读到的 Release.entitlements 全文只有一个键：`com.apple.security.app-sandbox = true`。
  - DebugProfile.entitlements 则有 `com.apple.security.network.server`（且 Flutter 模板在 debug 下默认放行 `network.client`）。
  - 即：**release 构建开启 App Sandbox 且未授予任何网络客户端权限**。
- **影响**：
  - macOS 发布版中 Image.network、OnlineMusicService（网易云搜索/歌单/歌词）、WebDavSyncService 的全部出站 HTTP 在沙箱层被拒，异常同样被 catch (_) {} 吞掉，用户看到的是"封面全灰 + 搜索无结果"。
  - 与第 3 条叠加，iOS 侧同类问题亦需核查（ios/Runner 未发现网络相关配置）。
- **建议**：在 Release.entitlements 中补 `com.apple.security.network.client`（LAN 同步服务端还需 `network.server`），并在 CI 中对 .app 做 codesign -d --entitlements 校验。

---

## 5. [P0] "多端同步 / 云端备份 / LAN P2P" 是 Future.delayed(900ms) 假实现；真实同步引擎 1483 行从未被实例化

- **位置**：app/lib/views/desktop/desktop_views.dart:1409-1455, 1475-1477, 1526, 1632, 1697-1829；app/lib/core/sync/webdav_sync_service.dart（401 行）；app/lib/core/sync/lan_sync_service.dart（509 行）
- **证据**：
  - 我读到的"立即云端备份"实现（desktop_views.dart:1417-1435）：
    ```dart
    void _triggerUpload() async {
      setState(() { _isSyncing = true; _syncStatusText = '正在打包数据快照并上传至 WebDAV...'; });
      await Future.delayed(const Duration(milliseconds: 900));   // ← 没有任何网络请求
      if (!mounted) return;
      setState(() { _isSyncing = false; _lastSyncTime = DateTime.now(); _syncStatusText = '同步成功！已热备全量数据'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功将本地播放数据、收藏及歌单备份至 WebDAV 云端！')),   // ← 纯谎言
      );
    }
    ```
    _triggerRestore()（desktop_views.dart:1437-1455）结构完全一样，只是文案换成"拉取完成！数据已合并"。
  - UI 上写死的凭据与端点（desktop_views.dart:1414-1415）：
    ```dart
    final String _serverUrl = 'https://dav.jianguoyun.com/dav/';
    final String _username = 'gaore@mellow.music';
    ```
    页面上以"云端端点 / 绑定账号"形式展示（desktop_views.dart:1650-1658），**不存在任何配置入口**。
  - "服务就绪"绿标（desktop_views.dart:1627-1635）是硬编码的 `const Row(... Text('服务就绪', ...))`，与任何状态无关。
  - "本机端口: 18585 监听中"（desktop_views.dart:1733）是硬编码字符串；而真实 LanSyncServer 的默认端口是 23332（lan_sync_service.dart:112），并且**从未启动**。
  - 两台"已探测到的在线设备"是硬编码的 'Gaore 的 iPhone 15 Pro'（desktop_views.dart:1755，IP 192.168.1.103）与 '客厅立体声音响 (HomePod)'（desktop_views.dart:1799，IP 192.168.1.108），"在线"绿点是 `const BoxDecoration(shape: BoxShape.circle, color: Colors.green)`。
  - 投送按钮只弹 SnackBar（desktop_views.dart:1774-1779）：
    ```dart
    onTap: () { ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已向 Gaore 的 iPhone 15 Pro 成功投送当前播放列表！'))); },
    ```
  - **关键反证**：ripgrep `WebDavSyncService` over app/lib → **2 matches，且全部是它自己的类/构造函数定义**（webdav_sync_service.dart:160, 171）。LanSyncService 同理（lan_sync_service.dart:411, 418）。ripgrep `lan_sync|webdav_sync`（即 import 语句）over app/lib → **0 matches**。main.dart:14-17 只注册了 3 个 provider（ThemeProvider / AudioPlayerService / EqualizerManager）。
  - 也就是说：**1483 行写得很像真的 WebDAV/LAN 同步代码，是整个 lib 里测试覆盖最好的模块，却一行都没被生产代码调用。**
- **影响**：
  - 用户以为自己做了云端备份，实际上**什么都没发生**；换机/重装后数据为零，且用户会归因于"同步失败"而反复尝试。
  - 这是**数据安全层面的欺骗性功能**——比功能缺失更严重，因为它让用户放弃了手动备份。
  - 页面文案"支持 WebDAV 私有云盘实时双向热备，与局域网近场毫秒级 P2P 跨端流转"（desktop_views.dart:1477）完全不成立。
- **建议**：二选一——（a）把 DesktopSyncView 真正接到 WebDavSyncService/LanSyncService，加配置弹窗（服务器地址/账号/应用密码，密码走 flutter_secure_storage），并在 main.dart 注册 provider 与启动 startAutoSync；（b）在实现前**移除整个同步页面与所有"已同步/服务就绪/在线设备"文案**。当前状态不可发布。

---

## 6. [P0] 移动端内置一个假的 iOS 状态栏："10:09" + 假信号/WiFi/电池 + 假灵动岛

- **位置**：app/lib/navigation/mobile_scaffold.dart:93-187（_buildDynamicIslandHeader）
- **证据**：我读到的代码是——
  ```dart
  // 1. 左侧时间 (10:09)
  Text('10:09', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, ...)),
  // 2. 居中黑色胶囊灵动岛 (Dynamic Island)
  GestureDetector(key: const Key('dynamic_island_capsule'), onTap: () { showModalBottomSheet(...); },
    child: Container(height: 32, decoration: BoxDecoration(color: const Color(0xFF09090B), ...))),
  // 3. 右侧状态栏图标组 (信号、WiFi、电池电量)
  Icon(Icons.signal_cellular_alt_rounded, ...), Icon(Icons.wifi_rounded, ...),
  Icon(Icons.battery_charging_full_rounded, ...),
  ```
  （mobile_scaffold.dart:104-113、115-171、173-183）
  该 Header 被放在 SafeArea 内部（mobile_scaffold.dart:58-62），因此会**渲染在真机真实状态栏的下方**，出现"双状态栏"。
  测试把这个假状态栏当作验收标准（mobile_prototype_1to1_test.dart:64-70：`expect(find.text('10:09'), findsOneWidget)`），等于把 mock 固化为契约。
  另外 Icons.mic_none_rounded（mobile_tabs.dart:179）是一个语音搜索图标，其点击行为未指向任何语音能力。
- **影响**：
  - 真机（无论 iOS 还是 Android）上出现明显的视觉穿帮：假时钟永远 10:09、假电量永远"充电中"、假灵动岛覆盖在真实 UI 上。
  - 灵动岛/状态栏是**纯原型资产**，属于交付物污染生产包；docs/SPEC.md:262 反而把它描述成正式设计。
- **建议**：删除 _buildDynamicIslandHeader 中的时间/信号/WiFi/电池三组图标，改用 SystemChrome.setSystemUIOverlayStyle 与真实 MediaQuery.padding；若"灵动岛"是品牌设计语言，改名为"迷你播放胶囊"并放置到内容区内，同时更新相应测试断言。

---

## 7. [P0] "LX 音源管理 (QuickJS)" 是空壳页面，1669 行沙箱代码在 App 中不可达，导入按钮为空实现

- **位置**：app/lib/views/desktop/desktop_views.dart:1330-1398；app/lib/core/sources/lx_script_sandbox.dart（1204 行）；app/lib/core/sources/lx_source_model.dart（632 行）
- **证据**：
  - 我读到的"LX 音源管理"页面总共只有 **2 个 Card**：一个标题行，一个硬编码"内置综合聚合音源 (Built-in)…v2.1.0 · 运行中"卡片，唯一交互是一个**永远为 true 且 onChanged 为空**的开关：
    ```dart
    Switch.adaptive(value: true, activeTrackColor: theme.accentColor, onChanged: (_) {}),   // desktop_views.dart:1391
    ```
  - "在线导入音源链接"按钮的 onTap: () {}（desktop_views.dart:1357）——**空实现按钮**。
  - 页面标题写"自定义音源管理 (QuickJS)"（desktop_views.dart:1348），但 ripgrep `flutter_js|quickjs|JavascriptRuntime` over app/lib → **仅 1 条命中，就是这行 UI 文案本身**。没有任何 JS 引擎。
  - ripgrep `lx_script_sandbox` over app/lib → **0 matches**（无任何 import）；`lx_source_model` → **1 match，且是 lx_script_sandbox.dart:4 的自身 import**。
  - 两个文件**只在 app/test 下被 import**（lx_source_engine_test.dart:2-3、client_e2e_user_journey_test.dart:11-12）。
  - 沙箱内部本身也是仿真：PlatformPresetSourceDriver 持有 final List<LxSongInfo> _mockDatabase;（lx_script_sandbox.dart:354）与 final bool simulateFailure（lx_script_sandbox.dart:355），搜索就是在内存数组里 where（lx_script_sandbox.dart:402），"解析出的直链"是拼字符串。
- **影响**：
  - 用户看到的"LX 音源管理"页面**没有任何可操作功能**：不能导入、不能切换、不能停用，开关是装饰品。
  - SPEC 第 5 章「QuickJS 音源脚本沙箱与接口规范」、docs/PROGRESS.md:16（Phase 2 "已完成 100%"）均为不实声明。
  - 1204+632 行代码进入仓库与 CI 编译/分析范围，却对产品零贡献，属于纯粹的维护负债与"看起来做了很多"的假象。
- **建议**：若短期不做，删除 core/sources/ 整个目录与对应测试，并从导航栏移除"LX 音源管理"；若要做，引入 flutter_js 并按 SPEC 5 章实现桥接对象，把 LxSourceEngine 注册进 provider，同时删掉 simulateFailure / _mockDatabase 这两处生产代码里的测试开关。

---

## 8. [P1] 界面上大量"技术能力"文案与实现直接矛盾（libmpv / firequalizer / 无损 / 服务就绪 / 版本号）

- **位置**：app/lib/views/common/modals.dart:199, 207；app/lib/views/desktop/desktop_views.dart:79, 1168, 1195, 1348, 1383, 1387, 1526, 1632, 1733；app/lib/views/mobile/mobile_pages.dart:86, 611, 629
- **证据**（逐条对照）：

| 文案 | 位置 | 事实 |
|---|---|---|
| 基于 libmpv firequalizer 高保真声学校准 | modals.dart:207 | libmpv 在 lib 中 0 次出现（除 EQ 死代码注释）；无音频引擎，EQ 滑块只改内存数组，**听感无任何变化** |
| 声学 10 频段硬件均衡器 (DSP EQ) | modals.dart:199 | 无 DSP、无硬件，setBandGain 仅写 List<double>（equalizer_manager.dart:45-51） |
| 精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出 | desktop_views.dart:79 | 曲库实际 6 首（track_model.dart:111-228）；无解码器 |
| 支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式 | desktop_views.dart:1168 | 无任何格式解析代码 |
| FLAC 24bit/96kHz · 42.8 MB | desktop_views.dart:1195 | 硬编码字符串，对每条曲目都相同 |
| 已缓存 6 首无损音频 · 占用空间 182 MB | mobile_pages.dart:611 | 硬编码，无缓存实现 |
| v2.1.0 · 运行中 | desktop_views.dart:1383 | pubspec 版本是 1.0.0+1（pubspec.yaml:19），PROGRESS.md:3 又写 v1.0.0。三处版本号互斥 |
| 服务就绪 | desktop_views.dart:1632 | 硬编码常量，与任何连接状态无关（见第 5 条） |
| 已同步红心收藏 | desktop_views.dart:1526 | 从未同步过（见第 2、5 条） |
| 本机端口: 18585 监听中 | desktop_views.dart:1733 | 无监听；真实默认端口 23332（lan_sync_service.dart:112） |
| 高品质无损回放 | mobile_pages.dart:86 | 无音频输出 |

- **影响**：用户被明确告知具备其并不具备的能力；一旦试用即信任崩塌。对投资/验收场景属于**实质性误导**，不是文案瑕疵。
- **建议**：建立"文案—实现"对照清单，任何未落地的能力从 UI 移除；已落地的能力才允许出现技术名词。统一版本号来源（用 package_info_plus 读 pubspec.yaml，禁止硬编码）。

---

## 9. [P1] EqualizerManager.toLibmpvFilterString() 无任何生产调用方——SPEC 中"实时生成 libmpv firequalizer 参数"是空的

- **位置**：app/lib/core/audio/equalizer_manager.dart:81-92
- **证据**：
  - ripgrep `toLibmpvFilterString` over app/lib → **1 match，即方法定义自身**。无调用方。
  - 该方法返回的字符串（firequalizer=gain='gain_interpolate(31,7.0)+...'）**从未被传给任何播放器**（也没有播放器可传）。
  - 它唯一被"使用"的地方是测试断言字符串格式：mellow_music_comprehensive_test.dart:130-132、client_e2e_user_journey_test.dart:156-158。**测试让死代码看起来是活的。**
  - 其实现本身也与 SPEC 给的语法不一致：SPEC:193 写的是 firequalizer=gain='if(between(f,31,62),G1,...)'，代码生成的是 gain_interpolate(31,7.0)+gain_interpolate(...)。
- **影响**：维护者会误以为 EQ 已打通 DSP 链路；SPEC 9 章 E2E-05 验收项「实时生成 libmpv firequalizer 参数，音色变化平滑无咔嗒声」（SPEC.md:451）无法通过。
- **建议**：接入 media_kit 后调用 player.setProperty('af', eq.toLibmpvFilterString()) 或在 Player.stream 变更时重设滤镜；在此之前删除该方法或标注 @visibleForTesting 并注释说明未接线。

---

## 10. [P1] 无路由框架、无路由栈、无键盘快捷键——"go_router 强类型路由"与"Ctrl K / ESC"全是假象

- **位置**：app/pubspec.yaml:39；app/lib/navigation/desktop_scaffold.dart:25-37, 138-156, 162-193；app/lib/views/common/modals.dart:567；app/lib/views/desktop/fullscreen_lyrics_view.dart:104
- **证据**：
  - ripgrep `go_router|GoRouter|GoRoute` over app/lib → **0 matches**；却在 pubspec.yaml:39 声明了 go_router: ^18.0.1。
  - 我读到的导航是一个 String _activeView + switch（desktop_scaffold.dart:25-37、332-363）：
    ```dart
    String _activeView = 'discover';
    void _navigateTo(String viewId, [String? extra]) { setState(() { _activeView = viewId; ... }); }
    // ...
    switch (_activeView) { case 'discover': return DesktopDiscoverView(onNavigate: _navigateTo); ... }
    ```
  - 顶栏"前进"按钮是**空实现**：SoftButton(icon: Icons.chevron_right_rounded, ..., onTap: () {})（desktop_scaffold.dart:148-154）；"后退"永远跳 discover（desktop_scaffold.dart:145）。
  - ripgrep `LogicalKeyboardKey|Shortcuts(|CallbackShortcuts|RawKeyboard|KeyboardListener|Focus(|onKeyEvent|Actions(` over app/lib → **0 matches**。即：**整个 App 没有任何键盘事件处理**。
  - 因此这三个文案全是假的："Ctrl K" 徽章（desktop_scaffold.dart:185-188）、搜索框提示"按 ESC 退出"（modals.dart:567）、全屏歌词 tooltip"退出全屏 (ESC)"（fullscreen_lyrics_view.dart:104）。
  - SPEC:115 声称「所有视图采用强类型路由 (go_router)，并配合 PageStorageKey 保证切换 Tab 或页面时不丢弃滚动状态」；ripgrep `PageStorageKey` → **0 matches**（仅 mobile_scaffold.dart:66 用了 IndexedStack 保住 Tab 子树）。
- **影响**：
  - 桌面端用户的核心操作习惯（快捷键）完全不支持；号称 Ctrl+K 的入口必须鼠标点击。
  - 无路由栈意味着：无法返回上一个视图、无深链接、Web 端浏览器前进/后退失效、弹窗与二级页状态不可寻址。
  - 每个视图是 switch 新建实例，切换后**滚动位置与内部 state 全部丢失**（DesktopPlaylistSquareView 的 _activeTag 等）。
- **建议**：落地 go_router（ShellRoute + 强类型 route 对象），为每个列表页加 PageStorageKey；用 Shortcuts/Actions（或 CallbackShortcuts）实现 Ctrl+K、Esc、Space、Ctrl+左右方向键。

---

## 11. [P1] 50ms Timer.periodic 驱动全树 rebuild，是常驻的 CPU/电量开销

- **位置**：app/lib/core/audio/audio_player_service.dart:30, 305-329；app/lib/navigation/desktop_scaffold.dart:41, 366-368, 332；app/lib/navigation/mobile_scaffold.dart:95-96, 218-219
- **证据**：
  - ticker 每 50ms 调用一次 notifyListeners()（audio_player_service.dart:327），即 **20 次/秒**，只要 _isPlaying 为真就永不停止。
  - _DesktopScaffoldState.build 通过 _buildBottomPlayerDock() 间接 context.watch<AudioPlayerService>()（desktop_scaffold.dart:368），依赖注册在 _DesktopScaffoldState 的 Element 上，因此每次 notify 都会**重建整个桌面工作台**：顶栏 + 12 项侧边栏 + 当前视图 + 底栏。
  - 而 _buildCurrentView() 每次返回**非 const 的新实例**（DesktopDiscoverView(onNavigate: _navigateTo)，desktop_scaffold.dart:335），于是发现页里的 GridView.count（shrinkWrap: true + NeverScrollableScrollPhysics，desktop_views.dart:137-173）连同其中的 MellowImage 子树每秒重建 20 次。
  - 移动端同构：mobile_scaffold.dart:96 与 :219 的 watch 使整个 MobileScaffold 每秒重建 20 次，包含 IndexedStack 下 4 个 Tab 的完整子树。
  - 叠加 AcousticMeshGlow：BackdropFilter(ImageFilter.blur(sigmaX: 70, sigmaY: 70))（acoustic_mesh_glow.dart:82-85）常驻 + 3 个 MaskFilter.blur(80/90/100) 圆（acoustic_mesh_glow.dart:110-133）在 AnimationController.repeat(reverse: true)（12 秒）下持续重绘。虽然 const Positioned.fill(child: AcousticMeshGlow())（desktop_scaffold.dart:54）避免了 rebuild，但每帧的 BackdropFilter 与三段模糊仍在 GPU 上跑。
  - _sleepTimer 每秒 notifyListeners()（audio_player_service.dart:275-283），叠加同样效应。
- **影响**：桌面端"播放中"持续空转 20Hz 全树 rebuild；笔记本/手机续航与风扇噪音可观测；flutter run --profile 下 jank 明显。这正是"用假 ticker 代替真实音频时钟"的连带代价。
- **建议**：接入真实播放器后，进度只驱动**叶子组件**——把位置用 ValueListenableBuilder / Selector<AudioPlayerService, Duration> 局部订阅，或在 _DesktopScaffoldState 中用 context.read 取服务、仅在需要的地方 watch；_buildCurrentView() 的结果用 const/缓存实例；notifyListeners 节流到 4Hz 足够歌词高亮。

---

## 12. [P1] 网络异常 100% 静默吞掉，用户零错误反馈

- **位置**：app/lib/core/sources/online_music_service.dart:80-82, 157-159, 182；app/lib/core/sync/lan_sync_service.dart:91, 294, 314, 343, 372；app/lib/core/sync/webdav_sync_service.dart:210, 259
- **证据**：
  - app/lib 中 catch (_) 共 **16 处**（catch 语句共 26 处）。典型（online_music_service.dart:80-83）：
    ```dart
    } catch (_) {
      // 网络波动或超时，静默返回空，由上层触发本地降级逻辑
    }
    return [];
    ```
    以及 online_music_service.dart:182-183（歌词）：`} catch (_) {}` 后 return []。
  - 注释声称"由上层触发本地降级逻辑"，但**上层没有降级逻辑**：modals.dart:516-533 只判断 if (onlineSongs.isNotEmpty)，为空时什么都不做，_results 保持在本地匹配结果。
  - views/ 与 navigation/ 目录下 **catch 语句数为 0**，UI 层完全不处理异常。
  - 唯一有超时的是 OnlineMusicService._timeout = Duration(seconds: 6)（online_music_service.dart:26）与 LAN/WebDAV 自带的 timeout；**没有重试策略**（ripgrep 无 retry / maxAttempts 相关代码）。
- **影响**：
  - 用户输入"周杰伦"后如果网络失败/被墙（见第 18 条），界面表现为"无匹配结果，支持任意关键词搜索全网"（modals.dart:639），用户无法区分"没这首歌"和"网络挂了"。
  - 排查线上问题几乎不可能：无日志（debugPrint 仅 1 处，webdav_sync_service.dart:391，且该文件是死代码）、无埋点、无错误上报（FlutterError.onError / runZonedGuarded / PlatformDispatcher.instance.onError 均 **0 matches**）。
- **建议**：定义 AppFailure / Result 类型区分网络/超时/解析/权限错误；每个 catch 至少 debugPrint 并向上抛；UI 层用 SnackBar/内联提示呈现"网络异常，请检查连接"；对幂等 GET 加 1~2 次指数退避重试；在 main() 装 runZonedGuarded + FlutterError.onError 做统一上报。

---

## 13. [P1] pubspec 依赖 8/11 未使用、功能必需依赖全缺、字体声明在 Windows 上无效

- **位置**：app/pubspec.yaml:30-46, 21-22
- **证据**：ripgrep over app/lib 的实测结果：

| 依赖 | pubspec 行 | lib 中匹配数 | 判定 |
|---|---|---|---|
| cupertino_icons | :36 | 0（无 CupertinoIcons） | **未使用** |
| google_fonts | :37 | 0 | **未使用** |
| provider | :38 | 13（12 个 import + 使用） | 使用 |
| go_router | :39 | 0 | **未使用** |
| intl | :40 | 0（无 package:intl） | **未使用** |
| shared_preferences | :41 | 0 | **未使用** |
| http | :42 | 3 个 import | 使用 |
| dio | :43 | 0 | **未使用** |
| crypto | :44 | 5（**全部在死代码 lx_script_sandbox.dart 内**） | 实质未使用 |
| path_provider | :45 | 0 | **未使用** |
| path | :46 | 0（无 import package:path/；4 条命中都是 String.join） | **未使用** |

  - 即**整个产品真实依赖只有 flutter + provider + http**。
  - 缺失但功能需要的依赖：media_kit / audio_service（播放）、drift / sqflite（持久化）、flutter_js（SPEC 声明的沙箱）、desktop_multi_window（SPEC 声明的穿透歌词）、file_picker（"选择本地文件夹扫描"按钮，desktop_views.dart:1170-1175；ripgrep `file_picker|FilePicker|pickFiles` → 0 matches）、flutter_secure_storage（WebDAV 密码）、window_manager（自绘标题栏需要无边框窗口，见第 25 条）。
  - 字体：main.dart:42 与 :52 声明 fontFamily: 'PingFang SC'，但 pubspec 的 flutter: 段**完全没有 fonts: 配置**（pubspec.yaml:65-101，全是注释）。PingFang SC 是 macOS/iOS 系统字体，**在 Windows/Linux/Web 上不存在**，Flutter 会静默回退到默认字体，导致"温润白瓷"设计在目标平台（windows/ 是一等公民）上字体不生效。
  - SDK 约束 sdk: ^3.13.3（pubspec.yaml:22），pubspec.lock 解析出 dart: ">=3.13.3 <4.0.0" / flutter: ">=3.47.0"。
- **影响**：依赖清单给人一种"技术栈很丰富"的错觉（且 dio + http 同时存在是典型的"两个都想要"），实际全是噪音；新增依赖的人无法从 pubspec 判断项目真实能力；字体问题让 Windows 端视觉与设计稿不一致。
- **建议**：删掉 8 个未使用依赖；按功能补齐 media_kit / audio_service / drift / file_picker 等；字体改为随包分发的 NotoSansSC（放 assets/fonts/ 并在 pubspec 声明 fonts:），或使用 google_fonts（既然已声明）配合 GoogleFonts.notoSansSc() 并在 release 构建中预下载字体。

---

## 14. [P1] 测试断言的是 mock 自身，且存在"条件断言"与整文件重复

- **位置**：app/test/*（8 文件，69 个用例）、app/integration_test/app_client_e2e_test.dart（8 用例）、docs/PROGRESS.md:5, 19, 60
- **证据**：
  - **用例数对比**：docs/PROGRESS.md:5 与 :60 声称 **47/47 通过**；实测 app/test 下 test( + testWidgets( = **69**，加 integration_test 8 个共 **77**。声称值与实际值不符（无论取哪个口径都对不上 47）。
  - **断言 mock 自身**（最典型）：
    - lx_source_engine_test.dart:169-176：断言"解析出的 URL 包含 128k"——而该 URL 是 PlatformPresetSourceDriver 用字符串模板拼出来的，"解析"就是查内存数组。测试**只是在验证 mock 的字符串格式**。
    - lx_source_engine_test.dart:257：expect(url.url, contains('custom-cdn.six_custom_01.com'))——域名由 mock 自己生成。
    - sync_services_test.dart 的 LWW 用例（:184-338）确实在测真实算法，属于**本项目质量最高的测试**，而它测的是**死代码**。
    - client_e2e_user_journey_test.dart:260-261：expect(lanDevice.port, equals(23332)); expect(lanDevice.name, equals('MacBook Pro'));——断言构造函数的默认参数与刚传入的值，无信息量。
    - desktop_toplist_and_sync_test.dart:106-123：这条名叫"多端协同与云端同步中心**闭环验证**"的用例，断言的是**假同步的 900ms 延迟 + 假 SnackBar + 假设备名**，等于把第 5 条缺陷写成了验收契约。
  - **条件断言（空断言风险）**：desktop_modals_and_lyrics_test.dart:53-58
    ```dart
    final bassPreset = find.text('澎湃低音 (Bass Boost)');
    if (bassPreset.evaluate().isNotEmpty) {      // ← 找不到就整段跳过，测试仍然绿
      await tester.tap(bassPreset.first);
      ...
      expect(equalizerManager.currentPreset, EqualizerPreset.bassBoost);
    }
    ```
  - **整文件重复**：app/test/client_e2e_user_journey_test.dart 与 app/integration_test/app_client_e2e_test.dart 通过 Compare-Object 比对为**逐行完全一致（279 行，DIFFERENCES: 0）**。
  - **命名误导**：client_e2e_user_journey_test.dart 中 E2E-03/04/06/08（:113-190, :264-283）是纯 ChangeNotifier 单元断言，却用 testWidgets 且命名为"客户端原生端到端真实用户全链路"。真正的 widget 级渲染测试只有少数几条（mellow_music_comprehensive_test.dart:49-71 的 SoftCard/SoftButton 点击是货真价实的）。
  - **可验证性**：本环境无 Flutter 工具链，flutter test **未验证**。因此 PROGRESS.md 的"47/47 100% 通过"与"flutter analyze: No issues found!"我**无法证实**（也无法证伪）。
- **影响**：测试套件提供了严重的虚假信心——77 个"通过"的用例中，覆盖真实生产逻辑的比例很低，且把假功能固化为契约；维护者改动真实实现时不会得到有效反馈。
- **建议**：删除重复的 integration_test 文件；删除所有 if (find...isNotEmpty) 条件断言；为 UI 层写真正的 golden/交互测试；把 simulateFailure 从生产类里移出、改用测试内 MockClient/依赖注入（sync_services_test.dart 用 MockClient 的做法应推广到 OnlineMusicService）；把 lx_source_engine_test.dart 中"断言 mock 字符串"的用例改为对注入的 fake http.Client 的请求/响应做断言。

---

## 15. [P1] 各平台产物名/标识/图标全为 Flutter 模板默认值，macOS 打包路径与 workflow 不匹配

- **位置**：app/windows/CMakeLists.txt:3, 7；app/windows/runner/Runner.rc:92-99；app/windows/runner/main.cpp:29-30；app/macos/Runner/Configs/AppInfo.xcconfig；app/android/app/src/main/AndroidManifest.xml:3；app/linux/runner/my_application.cc:52；app/web/manifest.json；.github/workflows/release.yml:82
- **证据**：
  - Windows（windows/CMakeLists.txt:3, 7）：
    ```cmake
    project(app LANGUAGES CXX)
    set(BINARY_NAME "app")
    ```
    Runner.rc:93, 95, 97, 98 的四个字段全为 "app"：FileDescription / InternalName / OriginalFilename("app.exe") / ProductName。
    main.cpp:29-30：
    ```cpp
    if (!window.Create(L"app", origin, size)) {   // 窗口标题就是 "app"
      ...
    Win32Window::Size size(1280, 720);
    ```
    → 产物是 app.exe，任务栏与窗口标题显示 **"app"**；仓库里已有的 release_windows/app.exe（90624 字节）实证产物名确实是 app。
  - Windows 版本资源本身没问题（FLUTTER_VERSION 由 Flutter 工具从 pubspec 注入，Runner.rc:63-73 有 fallback），即 FileVersion/ProductVersion = 1.0.0。但**公司名是 com.mellow.music 而非可读品牌名**（Runner.rc:92），LegalCopyright 写的是 "Copyright (C) 2026"（未来年份，Runner.rc:96）。
  - macOS：PRODUCT_NAME = app，PRODUCT_BUNDLE_IDENTIFIER = com.mellow.music.app。而 .github/workflows/release.yml:82 打包的是：
    ```yaml
    ditto -c -k --sequesterRsrc --keepParent app/build/macos/Build/Products/Release/mellow_music.app Mellow-Music-macOS.zip
    ```
    → **mellow_music.app 不存在（真实产物是 app.app），该步骤必然失败**，build-macos job 失败 → publish-release（needs: [build-windows, build-macos, ...]，release.yml:212）整体不触发，**发版流水线跑不通**。
  - Android：android:label="app"（AndroidManifest.xml:3）→ 手机桌面图标名显示为 "app"。
  - Linux：set(BINARY_NAME "mellow_music")（linux/CMakeLists.txt:7）但窗口标题 gtk_window_set_title(window, "mellow_music")（my_application.cc:52）——下划线命名，非品牌名。
  - Web：app/web/manifest.json 仍是模板内容——"name": "mellow_music"、"description": "A new Flutter project."、"background_color"/"theme_color": "#0175C2"（Flutter 蓝，与 tokens.dart 的 #F5F7FB/#3B82F6 完全不同）；app/web/index.html:21, 26, 32 同样是 "A new Flutter project." / mellow_music。
  - 图标：Windows 有 app/windows/runner/resources/app_icon.ico（33772 字节）；Android/iOS/macOS/web 的图标文件均存在，但从体积看（android ic_launcher.png 442~1443 字节）大概率仍是 Flutter 默认蓝色图标。
  - app/README.md 仍是 "A new Flutter project." 模板。
- **影响**：安装后在系统各处显示为 "app"，用户无法识别；macOS 发布流水线**直接失败**；PWA 元数据与品牌完全脱节。
- **建议**：统一 BINARY_NAME / PRODUCT_NAME / android:label 为 "Mellow Music"（或 mellow-music，注意 Windows 文件名避免空格）；修正 release.yml:82 的 .app 名（或改由 flutter build macos 后动态查找 *.app）；替换全平台图标与 manifest.json / index.html 元信息；修正版权年份。

---

## 16. [P1] CI 未固定 Flutter 版本，却依赖 flutter: ">=3.47.0" 的硬下限；"0 issues" 门禁无法复现

- **位置**：.github/workflows/ci.yml:17-33；.github/workflows/release.yml:23-27, 62-66, 105-109, 149-153, 183-187；app/pubspec.yaml:22；app/pubspec.lock（sdks: 段）
- **证据**：
  - 5 个 job 全部使用 subosito/flutter-action@v2 + channel: 'stable' + cache: true，**没有任何 flutter-version: 固定**。channel: stable 会随时间漂移。
  - 同时 pubspec.lock 的 sdks: 段解析出 flutter: ">=3.47.0"、dart: ">=3.13.3 <4.0.0"。也就是说构建对 Flutter 版本有很高的硬下限，而 CI 用的是"当时最新的 stable"——两者在时间上不保证一致（在 Flutter 3.47 发布之前，flutter pub get 会**直接失败**）。
  - ci.yml:29 的 flutter analyze 被当作"0 Issues Gate"（ci.yml:27 步骤名），但 flutter analyze 对 info 级别 lint 也会返回非 0；app/analysis_options.yaml 只 include 了 package:flutter_lints/flutter.yaml（第 10 行）并 exclude 了平台目录（第 13-20 行），未做任何放宽。PROGRESS.md:59 声称"0 错误，0 警告，0 提示"，**本环境无法验证**。
  - ci.yml:44-48 的 npm ci || npm install 后跑 node flutter_e2e_verify.mjs——该脚本与 e2e_test.js 在仓库根目录，会用 puppeteer-core 驱动**真实 Chrome**；puppeteer-core 需要外部浏览器路径（PUPPETEER_EXECUTABLE_PATH 或系统 Chrome），GitHub 的 ubuntu-latest 镜像是否有可用 Chrome 且脚本如何定位浏览器需要核实。**我未读取 flutter_e2e_verify.mjs 内容**，故不对其正确性下结论。
- **影响**：CI 可能因 SDK 漂移而随机失败/长时间阻塞；"0 issues"红线缺少版本锚点，任何人换一个 Flutter 小版本就可能红。
- **建议**：为所有 workflow 固定 flutter-version: 3.47.x（与 pubspec 下限对齐）并在 .fvmrc/.tool-versions 中同步；把 flutter analyze --fatal-infos 显式写进命令；给 E2E 步骤显式安装 google-chrome 或设 PUPPETEER_EXECUTABLE_PATH。

---

## 17. [P1] server.js 存在目录穿越 + 监听 0.0.0.0 + 通配 CORS

- **位置**：server.js:35-48, 88-89（仓库根目录；任务书第 12 项明确要求覆盖）
- **证据**：我读到的路径拼接是——
  ```js
  let reqPath = decodeURI(req.url.split('?')[0]);
  ...
  let filePath = path.join(BASE_DIR, reqPath);            // :40
  if (!fs.existsSync(filePath)) {
    const publicPath = path.join(BASE_DIR, 'public', reqPath);   // :44
  ```
  没有 path.normalize 后的前缀校验，也没有 reqPath.includes('..') 过滤。path.join 会自行归一化 ..，因此 GET /../../../../Windows/win.ini（或 %2e%2e%2f 编码形式，decodeURI 会先还原）可读取 BASE_DIR 之外的任意文件。
  ```js
  res.setHeader('Access-Control-Allow-Origin', '*');      // :25
  ...
  server.listen(PORT, '0.0.0.0', ...);                    // :88
  ```
  → 绑定所有网卡、无鉴权、允许任意源读取。
- **影响**：在同一 Wi-Fi 下的任意设备（含被入侵的 IoT 设备）可**无凭据读取开发者机器上的任意文件**（SSH 私钥、.git/config、.env、浏览器 cookie 数据库等）；浏览器中任意恶意网页也能通过 CORS 读取响应内容。这是一个真实的 P1 级漏洞（若该脚本在开发机上常驻运行，实际风险评估为 P0）。
- **建议**：先 path.resolve(BASE_DIR, '.' + path.posix.normalize('/' + reqPath)) 再校验结果以 BASE_DIR + path.sep 开头，否则 403；server.listen(PORT, '127.0.0.1')；把 Access-Control-Allow-Origin 收敛为白名单；该文件不应随 assets/发布目录分发。

---

## 18. [P1] 硬编码第三方私有接口（music.163.com）与明文账号；Web 端必然被 CORS 拦截

- **位置**：app/lib/core/sources/online_music_service.dart:35, 39, 63, 103, 106, 132, 168, 172；app/lib/views/desktop/desktop_views.dart:1415
- **证据**：
  - 4 处硬编码网易云**非公开**接口：
    ```dart
    'https://music.163.com/api/search/get/web?s=...&type=1&offset=0&total=true&limit=...'   // :35
    'https://music.163.com/api/playlist/detail?id=...'                                        // :103
    'https://music.163.com/api/song/lyric?os=pc&id=...&lv=-1&kv=-1&tv=-1'                     // :168
    final audioUrl = 'https://music.163.com/song/media/outer/url?id=....mp3';                 // :63, :132
    ```
    并伪造 User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 与 Referer: https://music.163.com/ 绕过防盗链（:37-40, :104-107, :170-173）。
  - 明文账号：final String _username = 'gaore@mellow.music';（desktop_views.dart:1415）。WebDavConfig.password 也是明文字段（webdav_sync_service.dart:25）并通过 base64(user:pass) 放入 Authorization 头（:117-123）——base64 不是加密。（该文件虽为死代码，但一旦接线即成为隐患。）
  - Web 构建下，浏览器对 music.163.com 发起 XHR/fetch 会被 CORS 预检拒绝（该域不返回 Access-Control-Allow-Origin），异常被 catch (_) {} 吞掉 → 搜索恒为空。Image.network 在 Web 上走 img 标签不受 CORS 限制，因此封面能显示但搜索不能——表现为"像半坏"的迷惑状态。
- **影响**：使用私有接口存在随时失效与法务风险；伪造 UA/Referer 属规避技术措施；明文账号出现在源码与 UI 上；Web 端在线搜索**从设计上就不可能工作**。
- **建议**：删除硬编码账号，改由用户在设置页填写并存入 flutter_secure_storage；在线音源改为可插拔的 provider 抽象（对已声明的 LxSourceEngine 做真正接线），并在 Web 端通过自建后端代理解决 CORS；在 UI 与文档中明确标注第三方接口的可用性限制。

---

## 19. [P1] LanSyncServer 的配对密钥用可预测的弱随机数，鉴权形同虚设

- **位置**：app/lib/core/sync/lan_sync_service.dart:256-266, 141-142, 204-212（死代码，但一旦接线即为漏洞）
- **证据**：我读到的实现是——
  ```dart
  String _generateRandomKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   // 32 字符表
    final now = DateTime.now().millisecondsSinceEpoch;  // ← 用时间做种子
    var result = '';
    var seed = now;
    for (int i = 0; i < 6; i++) {
      result += chars[seed % chars.length];
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;  // LCG，非加密安全
    }
    return result;
  }
  ```
  6 位取自 32 字符表约 30 bit 熵，且**完全由毫秒时间戳决定**——攻击者只需知道大致启动时间即可枚举（时间窗口内的搜索空间极小）。同时 HttpServer.bind(InternetAddress.anyIPv4, ...)（:141）监听所有网卡，Access-Control-Allow-Origin: *（:154）。
- **影响**：局域网内任意设备可暴力/预测密钥，获得 /sync/pair 配对与 /sync/push 投送权限，从而**向用户设备注入伪造的收藏/歌单/播放历史**。
- **建议**：改用 Random.secure() 生成至少 128bit 密钥（或直接展示 8 位以上 base32），配对采用一次性令牌 + 用户确认（比对短码）而非静态共享密钥；/sync/push 增加请求体大小上限与速率限制。

---

## 20. [P1] 巨型文件 + UI 层直接耦合 mock 数据（37 处）

- **位置**：app/lib/views/desktop/desktop_views.dart（1828 行）；app/lib/core/sources/lx_script_sandbox.dart（1204 行）；app/lib/views/mobile/mobile_tabs.dart（1055 行）；app/lib/views/common/modals.dart（985 行）
- **证据**：
  - desktop_views.dart 一个文件里塞了 **13 个顶层 Widget**（DesktopDiscoverView :14、DesktopPlaylistSquareView :264、DesktopToplistView :345、DesktopArtistsView :604、DesktopArtistDetailView :666、DesktopPodcastView、DesktopFavoriteView、DesktopImportedPlaylistsView、DesktopHistoryView :1098、DesktopLocalMusicView :1145、DesktopSettingsView :1209、DesktopSourceManagerView :1331、DesktopSyncView :1401），含大量重复的卡片布局代码。
  - UI 层直接引用 mockPresetTracks 的**点位共 37 处**（views/ 行 34 + navigation/ 行 3）：

| 文件 | 引用次数 |
|---|---|
| views/desktop/desktop_views.dart | 16 |
| views/mobile/mobile_pages.dart | 10 |
| views/common/modals.dart | 3 |
| views/mobile/mobile_tabs.dart | 3 |
| navigation/mobile_scaffold.dart | 2 |
| navigation/desktop_scaffold.dart | 1 |
| views/mobile/mobile_sheets.dart | 1 |
| views/desktop/fullscreen_lyrics_view.dart | 1 |
| （核心层）core/audio/audio_player_service.dart | 2 |
| （模型层）core/audio/track_model.dart | 1 |

  - 典型耦合：desktop_views.dart:319-321（榜单网格直接遍历 mock 数组）、:531-532（用 (idx * 3 + i) % mockPresetTracks.length 编造榜单排名）、:1182（本地音乐列表直接展开 mock 数组并配假文案 "FLAC 24bit/96kHz · 42.8 MB"）、mobile_pages.dart:341（mockPresetTracks[(idx + i) % mockPresetTracks.length]）。
  - 动画/看板类 widget 用 List<Map<String, dynamic>> 承载强类型数据并强转（desktop_views.dart:354-387, 429-430：c['gradient'] as List<Color>、c['icon'] as IconData），失去类型安全。
- **影响**：任何数据源变更都要改 37 个 UI 点位；mockPresetTracks 是顶层可变 final List<Track>（track_model.dart:111），**无 const 保护**，UI 可以随意改它导致全局状态污染；巨型文件使 code review、合并冲突与 IDE 性能持续恶化。
- **建议**：按视图拆分为 views/desktop/discover_view.dart 等独立文件；数据一律通过 context.watch<AudioPlayerService>()/专门 Repository 获取，UI 层禁止 import mockPresetTracks（用 lint 或自定义 dart_code_metrics 规则约束）；把 mock 数据移入 test/fixtures/ 或 lib/dev/mock_data.dart 并在 release 构建中通过 kReleaseMode 排除。

---

## 21. [P1] 可访问性完全缺失：0 个 Semantics，纯图标按钮仅靠 Tooltip

- **位置**：全 app/lib
- **证据**：ripgrep `Semantics(|semanticLabel` over app/lib → **0 matches**。Tooltip/tooltip: 共 14 处（其中 soft_button.dart:177 是唯一通用兜底，但也只在调用方传 tooltip 时生效）。大量交互元素是裸 GestureDetector / IconButton(icon: Icon(...)) 而没有无障碍标签，例如：
  - 底栏控制（desktop_scaffold.dart:494-516 的播放/暂停 GestureDetector，无 label、无 tooltip）
  - 音量静音开关（desktop_scaffold.dart:603-616，GestureDetector + Icon）
  - 5 个强调色圆点（desktop_scaffold.dart:225-240、desktop_views.dart:1270-1294，纯 Container 无 label）
  - 顶栏搜索条（desktop_scaffold.dart:162-193，GestureDetector 包 RecessedWell）
  - 歌手卡片、歌单卡片（SoftCard.onTap）等
- **影响**：屏幕阅读器（NVDA/VoiceOver/TalkBack）用户无法操作播放器；键盘焦点（Tab）遍历顺序不可控；Windows 高对比度模式下大量自绘 Container 颜色不会跟随系统主题。
- **建议**：为所有 IconButton / GestureDetector 加 tooltip 或 Semantics(label:, button: true)；把裸 GestureDetector 换成 InkWell / IconButton 以获得焦点与语义；为核心控件定义统一的 Semantics 包装组件；在测试中加 meetsGuideline(labeledTapTargetGuideline) 与 textContrastGuideline 断言。

---

## 22. [P1] MellowImage 无加载态、无磁盘缓存，且用"检测测试运行"的 hack 分支决定渲染

- **位置**：app/lib/design_system/mellow_image.dart:5-72
- **证据**：我读到的实现是——
  ```dart
  class MellowImage extends StatelessWidget {
    /// 是否在测试模式下运行（测试模式下跳过网络请求渲染占位）
    static bool isInTest = false;                       // ← 全局可变静态状态
    ...
    final bool usePlaceholder = isInTest ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');   // ← 靠运行时类型名字符串判断
    ...
    img = Image.network(url, width: width, height: height, fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder);        // ← 无 loadingBuilder
  ```
  只有 errorBuilder，**没有 loadingBuilder**，没有 cacheWidth/cacheHeight，没有磁盘缓存（cached_network_image 未声明）。
  isInTest 被测试侧赋值为 true（mellow_music_comprehensive_test.dart:29、client_e2e_user_journey_test.dart:20、mobile_prototype_1to1_test.dart:15）。
  MellowImage 共被使用在封面/头像等约 20 处（含 MellowAvatar，mellow_image.dart:76-94）。
  usePlaceholder 时返回的 placeholder 自身可能为 double.infinity 尺寸（调用方大量传 width: double.infinity，如 desktop_views.dart:206, 329），此时 iconSize 计算被 width!.isFinite 保护（:31），但 Container(color: ..., alignment: ...) 直接吃 double.infinity 仍依赖父约束。
- **影响**：弱网/首次加载时所有封面是一片与"未找到图"完全相同的灰色音符，用户无法区分"加载中"和"加载失败"；无磁盘缓存导致每次冷启动重新下载全部图片（Unsplash 原图 ?w=500，约 20 张），流量与首屏时间可观测；isInTest 静态全局在并行测试下会互相污染；依赖 runtimeType.toString().contains('Test') 判断运行环境是脆弱且不可靠的。
- **建议**：引入 cached_network_image（含磁盘缓存与 placeholder/errorWidget），或自建 ImageProvider + path_provider 缓存；用 loadingBuilder 展示 shimmer/进度；移除 isInTest，改用 @visibleForTesting 的注入点或 HttpOverrides（Flutter 测试标准做法）；给图片加 cacheWidth。

---

## 23. [P2] ListView(children:) + shrinkWrap 网格导致整页一次性构建

- **位置**：desktop_views.dart:23, 137-173, 281-338, 1182-1202；mobile_pages.dart:554, 616；mobile_tabs.dart:818
- **证据**：
  - 所有主视图都用 ListView(children: [...]) 而非 ListView.builder（desktop_views.dart:23, 281, 389, 618, 683, 1107, 1154, 1218, 1339, 1466）。
  - 内部网格用 GridView.count(shrinkWrap: true, physics: NeverScrollableScrollPhysics())（desktop_views.dart:137-142）或 GridView.builder(shrinkWrap: true, ...)（:310-318, 417-425, 623-631）→ shrinkWrap 会**一次性布局全部子项**。
  - 列表内容用列表展开语法一次性生成：...mockPresetTracks.map((t) => SoftCard(...))（desktop_views.dart:1182、mobile_pages.dart:554, 616、mobile_tabs.dart:818）。
  - 叠加第 11 条的 20Hz 全树 rebuild，代价被放大 20 倍。
- **影响**：当前 6 条 mock 数据下无感，但引入真实曲库（数千首）后会立刻 OOM/卡死。属于"A 轮演示能过、接真数据即崩"的架构债。
- **建议**：全面改用 CustomScrollView + SliverList/SliverGrid（去掉 shrinkWrap），或至少 ListView.builder；大数据集加分页/懒加载。

---

## 24. [P2] 歌词翻译（translation）被解析却从不渲染；SPEC 声称 9 款 EQ 预设实际 6 款

- **位置**：app/lib/core/audio/track_model.dart:5, 10；app/lib/core/sources/lx_source_model.dart:580；app/lib/views/desktop/fullscreen_lyrics_view.dart:236-265；app/lib/core/audio/equalizer_manager.dart:4-14；docs/SPEC.md:451
- **证据**：
  - LyricLine.translation 字段存在（track_model.dart:5, 10），LxLyricResult.toLyricLines() 会填充它（lx_source_model.dart:580），并有测试断言它（lx_source_engine_test.dart:128, 131）。
  - 但渲染侧只用 Text(line.text)（fullscreen_lyrics_view.dart:260），**全项目无任何读取 line.translation 的 UI 代码**（ripgrep translation over app/lib → 仅 3 处，全是模型/解析/测试）。
  - SPEC.md:451 的 E2E-05 验收项写"切换 **9 款**声学预设"，而 enum EqualizerPreset 只有 **6 个值**（equalizer_manager.dart:4-14，且其中 custom 不可手动选择）。
- **影响**：用户拿不到双语歌词（这是音乐 App 的常见期待）；SPEC 与实现对不上，验收标准失去意义。
- **建议**：在歌词行的 Column 中渲染 translation（次行、更小字号、textSecondary）；修正 SPEC 或补齐预设至 9 款（可基于 spatial3d 派生摇滚/电子/古典等）。

---

## 25. [P2] 自绘标题栏没有无边框窗口配置，Windows/Linux 会出现"双标题栏"

- **位置**：app/lib/navigation/desktop_scaffold.dart:60-61, 102-267；app/windows/runner/main.cpp:29-30；app/windows/runner/win32_window.cpp
- **证据**：
  - Flutter 侧画了一个 56px 高、带品牌 Logo/导航/搜索/工具集的"顶部拟物标题栏"（desktop_scaffold.dart:102-267）。
  - Windows 侧 window.Create(L"app", origin, size)（main.cpp:30）使用默认 Win32Window，**未做无边框/扩展标题栏处理**；ripgrep `window_manager|bitsdojo|WindowManager` → 0 matches；win32_window.cpp 未读取（从 window.Create 调用形态判断为 Flutter 默认模板实现）。
  - 同理 Linux（my_application.cc 默认 GTK HeaderBar，my_application.cc:50）。
- **影响**：Windows 上会同时存在系统标题栏（"app"）与 Flutter 自绘标题栏，视觉重复；自绘标题栏不可拖动（无 DragToMoveArea）；最大化/最小化/关闭按钮缺失。窗口初始尺寸 1280x720 但页面按 1440x900 设计（测试也是 Size(1440, 900)，如 desktop_toplist_and_sync_test.dart:35 与 mellow_music_comprehensive_test.dart:138），首屏会挤压。
- **建议**：引入 window_manager，setAsFrameless() + TitleBarStyle.hidden + DragToMoveArea 包裹自绘标题栏并补窗口控制按钮；把初始尺寸与最小尺寸设为 1440x900 / 1024x640。

---

## 26. [P2] 播放状态机若干边界行为与 UI 文案不符

- **位置**：app/lib/core/audio/audio_player_service.dart:156-171, 173-193, 319-323, 142-154, 158-160
- **证据**：
  - **单曲循环模式下按"下一首"仍会切歌**：next()（:156-171）只判断 shuffle，不判断 singleLoop；singleLoop 只在 ticker 播放结束时生效（:319-323）。UI 的 tooltip: player.playbackMode.label 会显示"单曲循环"（desktop_scaffold.dart:481），语义不一致。
  - **随机漫游可能"下一首还是这一首"**：next() 用 Random() 无排除本次索引（:158-160），小列表下重复命中概率可观。
  - **播放在线搜索结果会永久污染队列**：playTrack() 对不在队列中的曲目执行 _playlist.insert(0, track); _currentIndex = 0;（:146-149），用户在搜索框试听 10 首后队列顶部堆了 10 首，且 clearQueue() 会清掉原始队列。
  - **ticker 回调内重启自身**：ticker 在播完时调用 next()（:322），next() 又调用 play() → _startPositionTicker() → _positionTicker?.cancel()（:306）**在定时器自己的回调里取消并重建自己**。Dart 允许，但语义脆弱，任何后续改动（如在回调里 await）都可能引入重复 ticker。
  - clearQueue() 内调用 pause()（:265）会再触发一次 notifyListeners()（:139），造成同一帧双次通知。
- **影响**：行为与标签/直觉不符（尤其"单曲循环"语义），队列被隐式修改且用户无感知、无撤销。
- **建议**：next()/previous() 首行判断 _mode == PlaybackMode.singleLoop 并 seek(Duration.zero)；随机播放记录已播历史避免重复；试听不修改持久队列（引入独立的 now playing 与 queue）；playTrack 对非队列曲目使用 replaceCurrent 语义；clearQueue 不重复 notify。

---

## 27. [P2] 工程配置与文档卫生

- **位置**：app/analysis_options.yaml:12-20, 33-35；app/README.md；docs/PROGRESS.md:5, 19, 59-61；app/web/manifest.json
- **证据**：
  - analysis_options.yaml 只 include flutter_lints，未开启 strict-casts / strict-raw-types / strict-inference，linter.rules 整段是注释（:33-35）。对一个 11k 行工程而言门槛偏低——lx_script_sandbox.dart 中存在 dynamic/Object? 强转就是这类漏网。同时 exclude 把 windows/ macos/ android/ ios/ linux/ web/ 全部排除（:13-20），平台集成代码完全无静态检查。
  - app/README.md 仍是 Flutter 模板（"A new Flutter project."）。
  - docs/PROGRESS.md:5 与 :60 声称"全工程 47 项单元与集成测试用例 100% 通过""flutter analyze 结果：No issues found!"——与实测 69/77 个用例不符，且 analyze 结论在本环境**未验证**。
  - docs/PROGRESS.md:13 声称 e2e_test.js（83/83 通过）与 docs/SPEC.md 的目录结构（SPEC.md:382-410 含 database/、lyrics/ 目录）与实际 app/lib 目录（core/audio、core/sources、core/sync、design_system、navigation、views）不一致——**没有 database/，没有 lyrics/**。
  - docs/PROGRESS.md:19 声称"app/lib/core/sync/ (WebDAV 备份恢复, LX-Sync 局域网近场互传…)"已完成，实际该目录无任何调用方（第 5 条）。
- **影响**：文档与代码脱节，新加入的工程师/验收方会被系统性误导；README 无法上手。
- **建议**：修正 PROGRESS.md 的测试数字与完成度（对未接线的模块标记为"代码就绪、未集成"）；重写 app/README.md（环境要求、构建/测试命令、已知限制）；开启 strict-casts 等并使用 dart_code_metrics / custom_lint 约束 UI 层禁止引用 mock。

---

## 28. 值得肯定的部分（避免只有负面结论）

我读到的这些代码是**做对了**的，重构时应保留：

1. **设计系统分层清晰**：tokens.dart（176 行）集中了颜色/圆角/阴影/动效时长，soft_card.dart / soft_button.dart / recessed_well.dart 通过 context.watch<ThemeProvider>() 读取主题，全项目**没有散落的硬编码主题色**（只有语境化的渐变/品牌色例外）。这是本仓库工程质量最高的部分。
2. **dispose 纪律良好**：我逐个核对了 12 处 dispose() 定义。AnimationController（acoustic_mesh_glow.dart:42-45、mobile_sheets.dart:40-44、mobile_pages.dart:143-146、fullscreen_lyrics_view.dart:37-41）、PageController（mobile_sheets.dart:41）、ScrollController（fullscreen_lyrics_view.dart:39）、TextEditingController（modals.dart:484-488、:751-754）、Timer（audio_player_service.dart:332-336、:485）、StreamController（lan_sync_service.dart:268-271、lx_script_sandbox.dart:1224）**全部正确释放**。HttpServer 也有 stop()（lan_sync_service.dart:249-254）与 close(force: true)。**未发现控制器/Timer 泄漏。**
3. **sync_services_test.dart 是真实有效的测试**：用 package:http/testing.dart 的 MockClient 注入（:362, 396, 452, 480）验证 WebDAV 的 PROPFIND 降级、401 处理、MKCOL+PUT 首次备份、LWW 合并后回传；用 InternetAddress.loopbackIPv4 + port: 0 起真实 HttpServer 验证握手/配对/投送与鉴权拒绝（:528-562, 564+）。**这套测试方法应作为其他模块的模板**——可惜它测的是未接线的代码。
4. **LWW 冲突解决算法设计合理**：基于 updatedAt 毫秒时间戳 + 软删除（isRemoved），对收藏/歌单/历史/EQ/播放状态分别合并（sync_data_model.dart:505+），并考虑了 LX-Sync 报文互转（:448+）。算法本身可以直接复用。
5. **AdaptiveScaffold 断点策略简单明确**：constraints.maxWidth >= 1024 单断点切换双壳（adaptive_scaffold.dart:12-21），代码量与可读性都很好。
6. **模型层实现规整**：Track.copyWith 与 LyricLine.parseLrc（track_model.dart:14-43, 74-100）细节到位，LRC 解析对 2/3 位毫秒做了 padRight(3,'0') 处理（:21）。

---

## 附录 A：关键 grep 验证结果汇总

| 验证项 | ripgrep 模式 | app/lib 命中 | 结论 |
|---|---|---|---|
| 音频引擎 | 见脚注① | **0** | 无播放能力 |
| QuickJS | flutter_js / quickjs / JavascriptRuntime | **1**（仅 UI 文案 desktop_views.dart:1348） | 无 JS 引擎 |
| 数据库 | drift / sqlite / sqflite / openDatabase | 9（全是 _mockDatabase 变量名） | 无数据库 |
| 桌面多窗口 | desktop_multi_window / MultiWindow | **0** | 无穿透歌词 |
| 路由 | go_router / GoRouter / GoRoute | **0**（pubspec:39 已声明） | 未使用 |
| 持久化 | SharedPreferences / shared_preferences | **0**（pubspec:41 已声明） | 无持久化 |
| BLoC | Bloc / Cubit / flutter_bloc / Repository | **1**（_eventController 误匹配） | 无 BLoC、无 Repository 层 |
| 键盘 | LogicalKeyboardKey / Shortcuts / RawKeyboard / KeyboardListener / Focus / onKeyEvent | **0** | 无快捷键 |
| 无障碍 | Semantics / semanticLabel | **0** | 无可访问性 |
| 生命周期 | WidgetsBindingObserver / AppLifecycleState / didChangeAppLifecycleState | **0** | 无前后台处理 |
| 错误上报 | FlutterError.onError / runZonedGuarded / PlatformDispatcher | **0** | 无崩溃上报 |
| 文件选择器 | file_picker / FilePicker / pickFiles | **0** | 本地扫描按钮空实现 |
| 定时器 | Timer.periodic | 2（50ms 位置 ticker、1s 睡眠计时）+ WebDAV 30min | 见第 11 条 |
| 吞异常 | catch 下划线参数 | **16** | 见第 12 条 |
| EQ 死代码 | toLibmpvFilterString | **1**（定义自身） | 无生产调用方 |
| 沙箱是否被引用 | lx_script_sandbox | **0**（仅 test 引用） | 生产死代码 |
| 同步是否被引用 | WebDavSyncService / LanSyncService | **2 / 2**（均为自身定义） | 生产死代码 |
| mock 数据 UI 引用 | mockPresetTracks | 40（**UI 层 37**） | 见第 20 条 |

**脚注①**：模式为 media_kit OR just_audio OR audioplayers OR audio_service OR dart:ffi OR MethodChannel OR AudioPlayer( 。

## 附录 B：生产不可达代码量化

| 模块 | 行数 | app/lib 内 import 数 | 状态 |
|---|---|---|---|
| core/sources/lx_script_sandbox.dart | 1204 | 0 | **不可达** |
| core/sources/lx_source_model.dart | 632 | 1（被上一个不可达文件引用） | **不可达** |
| core/sync/sync_data_model.dart | 573 | 2（被下面两个不可达文件引用） | **不可达** |
| core/sync/lan_sync_service.dart | 509 | 0 | **不可达** |
| core/sync/webdav_sync_service.dart | 401 | 0 | **不可达** |
| **合计** | **3319** | — | 占 11245 行的 **29.5%** |

## 附录 C：P0/P1 汇总表

| 级别 | 编号 | 问题 |
|---|---|---|
| **P0** | 1 | 完全没有音频播放能力，播放是 50ms 计时器 |
| **P0** | 2 | 零数据持久化，收藏/历史/歌单/设置/EQ 重启即丢 |
| **P0** | 3 | Android release APK 缺 INTERNET 权限，线上包网络全废且静默 |
| **P0** | 4 | macOS release 缺 network.client entitlement，出网被沙箱拒绝 |
| **P0** | 5 | 多端同步/云端备份/LAN P2P 是 900ms 延迟 + 假 SnackBar；真实引擎 1483 行未接线 |
| **P0** | 6 | 移动端渲染假 iOS 状态栏（10:09/假信号/假灵动岛） |
| **P0** | 7 | "LX 音源管理 (QuickJS)" 是空壳，1669 行沙箱不可达，导入按钮 onTap: () {} |
| P1 | 8 | libmpv/firequalizer/无损/服务就绪/v2.1.0 等文案与实现矛盾 |
| P1 | 9 | toLibmpvFilterString() 无生产调用方，仅测试引用 |
| P1 | 10 | 无 go_router/无路由栈/无键盘快捷键，Ctrl K 与 ESC 文案为假 |
| P1 | 11 | 50ms ticker 驱动全树 20Hz rebuild + 常驻 BackdropFilter 模糊 |
| P1 | 12 | 16 处静默吞异常，UI 零错误反馈，无重试无上报 |
| P1 | 13 | 依赖 8/11 未使用；缺音频/持久化/沙箱/文件选择器依赖；PingFang SC 在 Windows 无效 |
| P1 | 14 | 测试断言 mock 自身、条件断言、整文件重复；47 对比实测 69/77 |
| P1 | 15 | 产物名/图标全为模板值（app）；release.yml macOS 打包路径不匹配致发版失败 |
| P1 | 16 | CI 未固定 Flutter 版本，与 flutter >=3.47.0 硬下限冲突；0 issues 门禁不可复现 |
| P1 | 17 | server.js 目录穿越 + 0.0.0.0 监听 + CORS 通配 |
| P1 | 18 | 硬编码 music.163.com 私有接口与明文账号；Web 端 CORS 必然失败 |
| P1 | 19 | LAN 配对密钥用时间种子 LCG，可预测 |
| P1 | 20 | 巨型文件（1828 行含 13 个视图）+ UI 层 37 处直接耦合 mock |
| P1 | 21 | 0 个 Semantics，可访问性完全缺失 |
| P1 | 22 | MellowImage 无 loading 态/无磁盘缓存 + isInTest 全局可变 hack |

---

**报告结束**。所有结论均基于对上述文件的逐行阅读与 ripgrep 实测；凡本环境无法验证的（flutter analyze、flutter test、flutter build 的实际结果）已在正文中显式标注为"未验证"，未做任何推断性断言。