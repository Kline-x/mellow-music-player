# 移动端 E2E 验收缺陷账本 (Mobile Defect Ledger)

> 负责人：子 Agent B。格式遵循 `docs/e2e/FORMAT.md`。
> 取证基线：工作区 HEAD `21ecef8`（取证时工作区另有其它 Agent 对 `README.md` / `docs/*` 的改动，`app/lib` 未被本 Agent 触碰）。
> 本轮实测：`cd app && flutter analyze` → `No issues found! (ran in 3.3s)`。
> 取证方式：逐文件 read 当前工作区内容（行号全部来自本轮真实读取）+ 对真实网络/真实音频文件的实测命令；仅当图形设备不可得时使用代码级几何推算（均已显式标注）。
> 编号规则：MOB-001 起，三位递增，不重号。

## 0. 本轮实测命令与原始输出（证据底座）

| 编号 | 命令 | 实测输出 | 用途 |
| :--- | :--- | :--- | :--- |
| E1 | `cd app && flutter analyze` | `No issues found! (ran in 3.3s)` | 静态分析基线：这些缺陷不是“编译不过” |
| E2 | `curl -sI https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3` | `HTTP/2 200`、`content-length: 8945229`、`content-type: audio/mpeg` | 内置曲库的真实音源存在 |
| E3 | `curl -s -o /tmp/s1.mp3 .../SoundHelix-Song-1.mp3 && afinfo /tmp/s1.mp3` | `estimated duration: 372.715083 sec`（= 06:12） | 与 MOB-003 的编造时长 04:28 直接对撞 |
| E4 | `curl -s 'https://music.163.com/api/search/get/web?s=周杰伦&type=1&limit=3'` | `HTTP:200 bytes:3186`，返回真实 `{"result":{"songs":[...]}}` | 在线搜索链路本身真实可达 |
| E5 | `curl -sL 'https://music.163.com/song/media/outer/url?id=186016.mp3'` | `content_type=text/html;charset=utf8 size=107191 code=200`，body 为网易云 404 HTML 页 | 在线音源直链不是音频，必然播放失败 |
| E6 | `git status --porcelain` | `app/lib` 下 0 项改动 | 遵守 FORMAT §3.6（只取证不改生产代码） |

## 1. 缺陷记录

### [MOB-001] 下钻任意二级页再返回，4 个 Tab 的滚动位置与“探索”的风格标签选择全部重置

- **编号**：MOB-001
- **严重度**：P1
- **类别**：交互缺陷
- **用户可见现象**：在“发现”页向下滚到“新碟与精选专栏”，点金刚区“歌单广场”下钻，再点左上角返回箭头 → 页面回到顶部；切到“探索”选“摇滚”，下钻“排行榜”再返回 → 标签回到“全部”。用户期待：返回后停留在原来的位置与选择。
- **复现步骤**：1. 打开移动壳（窗口宽度 < 1024px）；2. 任意 Tab 内滚动一段距离；3. 点任一金刚区入口进入二级页；4. 点 AppBar 左上角返回；5. 观察滚动位置与“探索”标签。
- **代码证据**：
  - `app/lib/navigation/mobile_scaffold.dart:46-48`：`if (_subPageId != null) { return _buildSubPage(); }` —— 二级页整体替换了返回的 Widget 树，主 `Stack`（含 `IndexedStack`）被移出树并 dispose；
  - `app/lib/navigation/mobile_scaffold.dart:66-77`：`IndexedStack(index: _currentTab, children: [...4 个 Tab...])` —— 4 Tab 之间切换确实保状态，但保不住“离开再重建”；
  - `app/lib/navigation/mobile_scaffold.dart:34-39`：`_popSubPage()` 只把 `_subPageId` 置空，靠重建主树回到列表页；
  - `app/lib/views/mobile/mobile_tabs.dart:777`：`String _currentTag = '全部';` 位于 `_MobileExploreTabState`，State 被销毁即回默认值；
  - 全项目 grep `PageStorageKey` / `PageStorageBucket` / `AutomaticKeepAlive` 仅命中 `IndexedStack` 一处，无任何 `PageStorageKey` 兜底（任务第 1 问的关键：IndexedStack 只在“Tab 之间”成立）。
- **数据真实性**：与数据无关，纯状态管理缺陷。
- **原型/文档依据**：`docs/SPEC.md:157` 宣称 Tab 为沉浸式导航壳，未声明“下钻返回会重置”；原型 `mobile.html:1629` 用 `switchMobileTab` 复用同一 `#mMainContent` 容器，不卸载内容区。
- **建议修复**：把二级页改为内层 `Navigator.push` 或 `Stack` 覆盖层保活，使主 Tab 树始终留在 Widget 树内；并给 4 个 `ListView` 加 `PageStorageKey`。
- **可验收标准**：widget 测试——发现页 drag 滚动 300px → 记录 `Scrollable` 的 `position.pixels` → 点“歌单广场” → 点返回 → 断言 `pixels == 300`；探索页断言返回后 `_currentTag` 未回默认（可用选中软按钮的 `isActive` 断言）。
- **状态**：**已修复**（二级页改为 `Stack` 全屏覆盖层，主 `IndexedStack` 常驻树内不再 dispose；4 个 Tab 及列表均补 `PageStorageKey`。`app/test/mobile_prototype_1to1_test.dart` 的 MOB-07/09 断言下钻返回后滚动位置与「来源」筛选标签保持，`flutter test` 全绿）

### [MOB-002] 私人 FM 的“垃圾桶屏蔽”与“下一首”是同一行代码：既不屏蔽也不落盘

- **编号**：MOB-002
- **严重度**：P1
- **类别**：功能缺失 / 文案不诚实
- **用户可见现象**：进入“私人漫游 FM”，对不想听的歌点垃圾桶 → 只是跳到下一首；被“屏蔽”的歌在循环一圈后原样再次出现，且没有任何“已屏蔽 N 首”的落盘痕迹。垃圾桶与右侧 Next 按钮效果完全相同。
- **复现步骤**：1. 金刚区点“私人漫游”；2. 记下当前曲名；3. 点垃圾桶图标；4. 连续点 Next 直到回到该曲目；5. 观察该曲再次播放，且重开 App 无任何屏蔽记录。
- **代码证据**：
  - `app/lib/views/mobile/mobile_pages.dart:216-222`：垃圾桶 `SoftButton(icon: Icons.delete_outline_rounded, ..., onTap: () => player.next())`；
  - `app/lib/views/mobile/mobile_pages.dart:234-241`：Next 按钮 `onTap: () => player.next()` —— 二者字节级等价；
  - `app/lib/core/audio/audio_player_service.dart:300-314`：`next()` 只做 `(_currentIndex + 1) % _playlist.length`，无黑名单集合、无 `StorageService` 调用；
  - 全项目无屏蔽字段：grep `blocklist` / `blacklist` / `dislike` → 0 命中。
- **数据真实性**：“屏蔽”只有文案承诺，底层无任何数据；FM 队列就是当前 `_playlist`（通常是 6 首内置曲），与“漫游”算法无关。
- **原型/文档依据**：`docs/SPEC.md:165` 与 `docs/ROADMAP.md:94` 均写“垃圾桶屏蔽曲目 / 垃圾桶丢弃”，属承诺副作用；当前实现不符。
- **建议修复**：`AudioPlayerService` 增加 `Set<String> _blockedIds` + `blockTrack(id)` + `StorageService.saveBlockedIds`；FM 垃圾桶调用 `blockTrack` 并在切歌时跳过被屏蔽曲目，UI 显示“已屏蔽 N 首 · 恢复”。
- **可验收标准**：单元测试——`service.blockTrack(currentTrack.id)` 后连续 `next()` 两圈，断言 `currentTrack.id != blockedId`，且持久层含该 id。
- **状态**：待修复

### [MOB-003] 播放页进度条总时长用编造值 04:28，真实音源 06:12 → 末尾 1 分 44 秒进度条钉死且无法拖到后段

- **编号**：MOB-003
- **严重度**：P1
- **类别**：数据造假 / 功能缺失
- **用户可见现象**：全屏播放页进度条走满、右侧时间停在 04:28 后不再变化，而音乐还在继续放 1 分 44 秒；把滑块拖到最右端松手，seek 到的是 4:28 而不是真实的 6:12，后段内容永远听不到。
- **复现步骤**：1. 点迷你播放条打开播放页；2. 等待进度走满右侧的 04:28；3. 观察音乐继续播放而进度条不再前进；4. 把滑块拖到最右松手 → 实际只 seek 到 4:28。
- **代码证据**：
  - `app/lib/views/mobile/mobile_sheets.dart:220-223`：`value: (_dragPositionMs ?? player.currentPosition.inMilliseconds.toDouble()).clamp(0.0, max(1.0, track.duration.inMilliseconds.toDouble())), max: max(1.0, track.duration.inMilliseconds.toDouble())` —— `max` 与 clamp 上界都取 `track.duration`（内置编造元数据），而非后端真实 `player.duration`；
  - `app/lib/views/mobile/mobile_sheets.dart:249`：右侧总时长显示 `track.formattedDuration`；
  - `app/lib/core/audio/track_model.dart:118`：`duration: const Duration(minutes: 4, seconds: 28)`；`:120`：`audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'`；
  - 实测 E3：同一 URL 真实时长 372.715083 秒（06:12），差 104 秒；
  - 对照：迷你播放条用的是真实值 `app/lib/navigation/mobile_scaffold.dart:196`：`final totalMs = player.duration.inMilliseconds;`，`app/lib/core/audio/audio_player_service.dart:53`：`duration => _duration > Duration.zero ? _duration : (currentTrack?.duration ?? Duration.zero)` —— 同一 App 两处进度条对“总时长”取值口径不同；
  - 元数据本身随手写：`track_model.dart:782` 电台曲目写 6:12 却指向另一个 URL。
- **数据真实性**：编造元数据（duration 与真实 mp3 无关联），是本项目第一优先级判定项。
- **原型/文档依据**：`docs/SPEC.md:170` 承诺“胶囊进度条拖动”可用；`docs/SPEC.md:466`（E2E-03）要求可拖动可降级播放。
- **建议修复**：`mobile_sheets.dart` 的 `max` 与显示时长统一改用 `player.duration`（后端 `onDurationChanged` 已在 `audio_player_service.dart:169-174` 接入），无后端时长时再回退 `track.duration`。
- **可验收标准**：播放“云水禅心” → 打开播放页 → 断言右侧总时长随 `onDurationChanged` 变为 06:12；拖到最右松手后断言 `player.position.inSeconds > 300`。
- **状态**：待修复

### [MOB-004] 迷你播放条与底部导航栏宣称“毛玻璃”，实际没有任何模糊层

- **编号**：MOB-004
- **严重度**：P2
- **类别**：视觉缺陷 / 文案不诚实
- **用户可见现象**：滚动列表时，从迷你播放条与底部导航栏下方“透”出来的内容清晰可见（仅被 0.92~0.95 不透明色覆盖），没有 iOS 式背景虚化；注释与文档所述“毛玻璃”未实现。
- **复现步骤**：1. 在“发现”页快速上下滚动；2. 观察迷你播放条/底部 Tab 栏后面的专辑封面——边缘清晰、无模糊；3. 与原型 `mobile.html` 的 `backdrop-blur` 对比。
- **代码证据**：
  - `app/lib/navigation/mobile_scaffold.dart:216-219`：`color: theme.cardColor.withValues(alpha: 0.95)`，`Container` 无 `BackdropFilter`；
  - 自称“毛玻璃”的注释：`mobile_scaffold.dart:83`、`:189`、`:329`；底栏 `:341`：`color: MellowColors.canvas(isDark).withValues(alpha: 0.92)`；
  - 全项目 grep `BackdropFilter` / `ImageFilter.blur` 仅 1 处命中：`app/lib/design_system/acoustic_mesh_glow.dart:82-83`（背景光晕），与这两个组件无关。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：原型队列浮层用 `bg-slate-900/95 backdrop-blur-2xl`（`mobile.html:1121` 附近）；`docs/SPEC.md:170` 以“胶囊/沉浸”表述。
- **建议修复**：给这两个容器包 `ClipRRect` + `BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18))`，或降低底色 alpha 并叠加模糊层。
- **可验收标准**：widget 测试断言该子树存在 `BackdropFilter` 且 filter 非空；真机截图与基准图人工比对（滚动内容不可辨识）。
- **状态**：**已修复**（`mobile_scaffold.dart` 迷你条与底栏均包 `ClipRRect`+`BackdropFilter(ImageFilter.blur(18,18))`，底色 alpha 0.95/0.92 降至 0.72；新增 MOB-11 断言两处 `BackdropFilter` 真实存在。真机视觉比对待新构建复验）

### [MOB-005] 移动端全壳无音量控制入口；SPEC 承诺的 MobileVolumeModal 在整个工程不存在

- **编号**：MOB-005
- **严重度**：P1
- **类别**：功能缺失 / 与文档不符
- **用户可见现象**：移动壳里找不到任何音量条、静音键；全屏播放页底部只有“均衡器 EQ / 睡眠定时”。用户在移动端无法调音量、无法静音、无法体验“原值记忆恢复”。
- **复现步骤**：1. 打开移动壳；2. 点迷你播放条打开播放页，逐行检查底部控件；3. 打开 EQ 弹窗检查是否含音量；4. 全应用搜索音量 UI → 无。
- **代码证据**：
  - 移动壳三文件 grep `setVolume` / `toggleMute` / `volume` 仅命中颜色名 `textMuted` / `cardMuted`，无一处音量控件；
  - `app/lib/views/mobile/mobile_sheets.dart:304-324`：播放页底部辅助入口只有 `均衡器 EQ` 与 `睡眠定时`；
  - 音量能力本身真实：`app/lib/core/audio/audio_player_service.dart:373-387`（`setVolume` 调 `_backend.setVolume` 且 `StorageService.instance.saveVolume`；`toggleMute` 用 `_lastNonZeroVolume` 恢复）；
  - 唯一消费者在桌面壳：`app/lib/navigation/desktop_scaffold.dart:751-771`；
  - grep `MobileVolumeModal` → 0 命中（`docs/SPEC.md:174` 与 `docs/ROADMAP.md:103` 都把它列为已交付组件）。
- **数据真实性**：能力真实、入口缺失——“有引擎没方向盘”。
- **原型/文档依据**：原型有完整音量条：`mobile.html:1104-1113`（Tactile Volume Slider + `mVolumeTrack` + `toggleMobileMute()`，逻辑在 `:2867-2906`）；`docs/SPEC.md:174` 列出 `MobileVolumeModal`；`docs/ROADMAP.md:103` 标注“✅ 1:1 对齐”——实际该类不存在，属虚假对齐。
- **建议修复**：在 `mobile_sheets.dart` 播放页加音量行（滑块 + 静音），直接绑 `player.volume` / `player.setVolume` / `player.toggleMute`；或新建 `MobileVolumeModal` 对齐 SPEC。
- **可验收标准**：widget 测试——在 `MobilePlayerBottomSheet` 内拖动音量滑块后断言 `audioService.volume` 变化且 `StorageService.getVolume()` 同步；点静音断言 `volume == 0`，再点断言恢复原值。
- **状态**：待修复

### [MOB-006] 底部 4-Tab 栏与迷你播放条脱离 SafeArea，忽略底部系统内边距

- **编号**：MOB-006
- **严重度**：P1
- **类别**：交互缺陷
- **用户可见现象**：在带手势条 / Home Indicator 的手机上，底部导航栏文字与图标被系统手势条压住；点击“资料库/我的”容易误触系统手势。带刘海机型上底部区域还会出现被系统区域遮挡的空档。
- **复现步骤**：1. 在 iPhone（底部 inset 34px）或 Android 手势导航机上打开移动壳；2. 观察底部 4 个标签与系统手势条是否重叠；3. 尝试点击最底部文字区域。
- **代码证据**：
  - `app/lib/navigation/mobile_scaffold.dart:50-89`：`Stack` 直接作为 `Scaffold.body`，只有中间的 `Column` 被 `SafeArea` 包裹（`:58`）；
  - `mobile_scaffold.dart:200-203`：迷你播放条 `Positioned(left: 14, right: 14, bottom: 72, ...)`；`:334-340`：导航栏 `Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 64, ...))` —— 二者都在 `SafeArea` 之外；
  - 移动壳内 grep `MediaQuery.of(context).padding` / `viewPadding` / `viewInsets` → 0 命中。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：原型底栏用 `bottom-2` 内缩以避让系统区域（`mobile.html:984`）；`docs/SPEC.md:50` 承诺这是真机移动形态。
- **建议修复**：用 `MediaQuery.paddingOf(context).bottom` 抬升底栏与迷你条，或把整个 `Stack` 包进 `SafeArea` 并把 `bottom` 偏移改为 `72 + inset`。
- **可验收标准**：widget 测试注入 `padding.bottom = 34`，断言底栏 `Rect.bottom <= 屏高 - 34`；真机截图比对。
- **状态**：待修复

### [MOB-007] “探索”页 7 个风格标签只换高亮、不过滤任何曲目

- **编号**：MOB-007
- **严重度**：P1
- **类别**：功能缺失
- **用户可见现象**：点“摇滚”“民谣”“电子”等标签，标签变蓝，但下方 6 张专辑网格一首都不变；也没有原型里的实时搜索输入框。
- **复现步骤**：1. 切换到底部“探索”；2. 点风格标签“古典”；3. 观察下方网格仍是全部 6 首；4. 尝试找搜索框 → 不存在。
- **代码证据**：
  - `app/lib/views/mobile/mobile_tabs.dart:778`：`final List<String> _tags = ['全部','华语','流行','摇滚','民谣','电子','古典'];`；
  - `mobile_tabs.dart:797-804`：`SoftButton(label: tag, isActive: isSel, onTap: () => setState(() => _currentTag = tag))` —— 仅改选中态；
  - `mobile_tabs.dart:809-842`：`GridView.builder(itemCount: mockPresetTracks.length, itemBuilder: ... mockPresetTracks[idx])` —— 数据源与 `_currentTag` 零关联。
- **数据真实性**：标签是死筛选；曲目本身全为内置演示曲。
- **原型/文档依据**：原型 Tab 2 是真实过滤的搜索框 + 结果列表（`mobile.html:434-447` 的 `mSearchInput` 与 `:1682 filterMobileSearch(query)`）；`docs/ROADMAP.md:87` 写“动态标签过滤器（流行/民谣/轻音乐等）… ✅ 1:1 对齐”。
- **建议修复**：为 `_tags` 建立到曲目风格字段的映射并在 `itemBuilder` 前过滤；或按原型补 `TextField` 做 title/artist/album 模糊过滤。
- **可验收标准**：widget 测试——点“电子”后断言网格中不再出现 `artist == '巫娜'` 等非电子项（或断言过滤后数量小于全部）。
- **状态**：待修复

### [MOB-008] 搜索到“在线音源”后点播必然失败，且移动端零失败反馈

- **编号**：MOB-008
- **严重度**：P1
- **类别**：功能缺失 / 失败无诚实反馈
- **用户可见现象**：在移动端搜索歌手名 → 出现带“在线音源”蓝色角标的真实网易云曲目 → 点击后弹层关闭，没有任何声音、没有任何报错，音乐仍在放上一首；用户不知道发生了什么。
- **复现步骤**：1. 点“发现”页搜索胶囊；2. 输入“周杰伦”；3. 等待在线结果（带“在线音源”角标）出现并点击；4. 观察无播放、无 Toast、无 SnackBar。
- **代码证据**：
  - 在线音源直链：`app/lib/core/sources/online_music_service.dart:63`：`final audioUrl = 'https://music.163.com/song/media/outer/url?id=<歌曲ID>.mp3';`（实际由 Dart 字符串插值拼出 `id`；歌单导入同款写法在 `:132`）；
  - 实测 E5：该 URL 跟随跳转后 `content_type=text/html; charset=utf8`、107191 字节的 404 HTML，不是音频；
  - 失败反馈逻辑存在：`app/lib/core/audio/audio_player_service.dart:293-297`：`catch (e) { ... _playbackNotice = '歌曲「<曲名>」音频资源加载失败，可能需要专属授权或网络受限'; notifyListeners(); }`（曲名由插值拼入）；
  - 但 `playbackNotice` 的 UI 消费者只有桌面：grep `playbackNotice` → `desktop_scaffold.dart:180-209` 唯一渲染点，移动壳 0 消费；
  - 搜索浮层点击播放：`app/lib/views/common/modals.dart:686-689`：`onTap: () { player.playTrack(track); Navigator.of(context).pop(); }`。
- **数据真实性**：搜索元数据来自真实网易云 API（E4 实证 200），但音频直链是死链；“能渲染”不等于“能用”。
- **原型/文档依据**：`docs/SPEC.md:466`（E2E-03）承诺“首选源下架自动毫秒级跨源热切换源”；实际无任何跨源回退，且移动端静默。
- **建议修复**：① 移动壳消费 `playbackNotice`（迷你条上方红条或 `SnackBar`）；② 在线音源不可用时降级到内置同曲或明确提示“该音源暂不可用”。
- **可验收标准**：搜索“周杰伦” → 点在线结果 → 断言出现可见错误提示（`find.byType(SnackBar)` 或 `find.textContaining('加载失败')`），不再“静默无反应”。
- **状态**：待修复

### [MOB-009] “本地与下载”页没有导入/扫描/缓存计数，主体是 6 首内置演示曲目冒充本地曲库

- **编号**：MOB-009
- **严重度**：P1
- **类别**：功能缺失 / 数据造假
- **用户可见现象**：进入“资料库 → 本地与下载”，标题写着“本地与离线曲库”，正文列出 6 首曲目（副标题“演示曲目”），但没有“导入本地音频文件”入口、没有文件选择器、没有“已缓存 N 首”、没有容量显示；顶部只写“本地离线音频扫描功能正在接入中”。点击曲目播放的是网络 soundhelix 音频，不是本地文件。
- **复现步骤**：1. 资料库 → 本地与下载；2. 寻找导入按钮（不存在）→ 只能点列表曲目播放网络演示音频；3. 检查页面任何位置是否有缓存数量/容量（无）。
- **代码证据**：
  - `app/lib/views/mobile/mobile_pages.dart:633-644`：`RecessedWell` 内文案 `'设备离线音频扫描'` + `'本地离线音频扫描功能正在接入中'`，无任何按钮；
  - `mobile_pages.dart:646-666`：`...mockPresetTracks.map((t) => SoftCard(... onTap: () => player.playTrack(t)))`，副标题为 `'<歌手> · 演示曲目'`（Dart 插值）—— 内置演示曲冒充“本地离线曲库”；
  - 无文件选择能力：`app/pubspec.yaml:31-47` 依赖中没有 `file_picker` / `file_selector`；
  - `localPath` 链路在服务层是通的（`app/lib/core/audio/audio_player_service.dart:287-288`：`else if (track.localPath != null && track.localPath!.isNotEmpty) await _backend.play(track.localPath!);`），但没有任何移动端 UI 能产生带 `localPath` 的 Track（`localPath` 仅出现在未被引用的 `core/sync/sync_data_model.dart`，见 FORMAT §4 基线）；
  - grep `已缓存` app/lib → 0 命中：任务书问的“已缓存 N 首”文案在移动端根本不存在。
- **数据真实性**：列表数据 = 内置演示曲（`mockPresetTracks` 6 首，`app/lib/core/audio/track_model.dart:111-241`），并非设备文件；“本地”是标题级误导。
- **原型/文档依据**：原型有真实导入 UI：`mobile.html:922-927`（`input type="file" id="mLocalFileInput" accept="audio/*" multiple` + “点此导入本地音频文件”）、`:933-934`（“已缓存与本地曲目 / 6 首”）；`docs/SPEC.md:168` 要求离线曲库列表 + 本地文件扫描导入 + 存储占用容量展示；`docs/ROADMAP.md:97` 标注“✅ 1:1 对齐”。
- **建议修复**：接入 `file_picker` 取文件路径，用 `path_provider` 维护本地曲库清单并落盘 `localPath`；页面加导入按钮 + “已缓存 N 首 / 占用 X MB”。
- **可验收标准**：真机手测——点导入 → 文件选择器出现 → 选 mp3 → 列表 +1 且 `player.currentTrack.localPath` 非空 → 断网仍可播放；widget 测试断言导入后出现“已缓存 1 首”。
- **状态**：待修复

### [MOB-010] “我的”页展示编造的账号体系（用户名 / PRO 徽章 / “声学生态已连接”）

- **编号**：MOB-010
- **严重度**：P1
- **类别**：数据造假
- **用户可见现象**：打开“我的”，顶部卡片显示“Mellow 音乐探索家”、金色 PRO 徽章、副标题“享受温润微质感 · 声学生态已连接”。全 App 无登录、无账号、无订阅；该用户与 PRO 权益是硬编码装饰。
- **复现步骤**：1. 底部切到“我的”；2. 观察用户名/PRO 徽章/副标题；3. 全应用寻找登录/退出/会员入口 → 无。
- **代码证据**：
  - `app/lib/views/mobile/mobile_tabs.dart:954-988`：`SoftCard`（无 onTap）内 `Text('Mellow 音乐探索家')`（`:969`）、`const Text('PRO', ...)`（`:971-978`）、`Text('享受温润微质感 · 声学生态已连接')`（`:982`）；
  - 头像为固定 Unsplash 图（`mobile_tabs.dart:958-961`），与 `:133-137` 的“用户头像”、`track_model.dart:517` 的“歌手头像”是同一张图；
  - 全项目无 auth 业务：grep `login` / `signIn` 无业务命中。
- **数据真实性**：硬编码编造（对照 `docs/PC_E2E_ACCEPTANCE_ISSUES.md:899` I-04 已认定同类问题）。
- **原型/文档依据**：`docs/SPEC.md:160` 与 `docs/ROADMAP.md:89` 把 Tab 4 描述为“用户中心”，未声明是占位；`docs/PC_E2E_ACCEPTANCE_ISSUES.md:899` 要求标注为假数据。
- **建议修复**：接真实账号体系，或把用户名改为“本地用户”、去掉 PRO 与“已连接”文案、加“演示数据”标记。
- **可验收标准**：`mobile_tabs.dart` 中不再出现无数据支撑的会员徽章，或存在真实登录态来源（`StorageService` 中的 profile 键）。
- **状态**：待修复

### [MOB-011] 歌手详情页默认“已关注”、关注不落盘，bio/粉丝数/头像全为编造

- **编号**：MOB-011
- **严重度**：P1
- **类别**：数据造假
- **用户可见现象**：进入任意歌手详情，蓝底按钮直接显示“已关注”（用户从未关注过）；点一下变“+ 关注”，退回再进又变回“已关注”；简介“当代古琴领军名家 · …累计播放量突破 3000 万”、“粉丝 3890.2万”等数字无任何来源。
- **复现步骤**：1. 资料库 → 关注歌手 → 点任一位；2. 观察默认就是“已关注”；3. 点成“+ 关注”；4. 返回列表再进入该歌手 → 又变“已关注”。
- **代码证据**：
  - `app/lib/views/mobile/mobile_pages.dart:503`：`bool _isFollowing = true;` —— 默认已关注；
  - `mobile_pages.dart:546-551`：`SoftButton(label: _isFollowing ? '已关注' : '+ 关注', ..., onTap: () => setState(() => _isFollowing = !_isFollowing))` —— 仅本地 setState，无 `StorageService` 调用；
  - 编造档案：`app/lib/core/audio/track_model.dart:473-506`（`fans: '86.4万'`、`bio: '当代古琴领军名家 …'` 等 4 位）；未知名还会即时编造：`track_model.dart:509-521`（`fans: '128.5万'`、`bio: '官方认证音乐人 · 原创先锋作者 · 累计播放破亿'`）；
  - “播放热门”链路真实：`mobile_pages.dart:553-563` → `player.playPlaylist(artist.tracks, startIndex: 0)`（音频可达时确实播放）。
- **数据真实性**：头像为 Unsplash 摆拍图，bio/粉丝数为编造；关注态既不真实也不持久。
- **原型/文档依据**：`docs/SPEC.md:167` 写“关注/已关注本地状态切换”，`docs/ROADMAP.md:67`（桌面）明确要求本地持久化，`:96`（移动）只写“切换”——文档间不一致；但“默认已关注”在任何文档中都没有依据。
- **建议修复**：`_isFollowing` 初值改 `false` 或从 `StorageService.getFollowedArtists()` 读取；切换时落盘；bio/粉丝数改为真实来源或标注“示例数据”。
- **可验收标准**：widget 测试——首次进入断言显示“+ 关注”；点选后重新进入断言仍为“已关注”（需读持久化键存在）。
- **状态**：待修复

### [MOB-012] 资料库“已收藏 N 首”取自当前队列交集，队列一变就显示 0

- **编号**：MOB-012
- **严重度**：P2
- **类别**：数据造假
- **用户可见现象**：收藏 4 首（默认红心）后资料库显示“已收藏 4 首心动单曲”；一旦播放某个榜单/歌手（会替换队列）或清空队列，“我喜欢的音乐”立刻显示 0 首，而收藏其实还在（迷你条红心仍是实心）。
- **复现步骤**：1. 资料库记录“已收藏 4 首”；2. 点歌单广场任一卡片（替换队列）后返回资料库 → 计数变化；3. 打开播放队列点清空 → 资料库显示“已收藏 0 首”。
- **代码证据**：
  - `app/lib/views/mobile/mobile_tabs.dart:857`：`final favCount = player.playlist.where((t) => player.isFavorite(t.id)).length;` —— 分母是当前队列 `_playlist`，不是收藏集合；
  - 收藏真源是 `_favoriteIds`：`app/lib/core/audio/audio_player_service.dart:49`：`Set<String> get favoriteIds`，另有 `favoriteTracks`（`:71-96`）可直接计数；
  - 队列会被整体替换/清空：`audio_player_service.dart:216-225`（`playPlaylist` → `_playlist.clear()`）、`:433-438`（`clearQueue`）。
- **数据真实性**：统计口径错误导致展示数字与真实收藏不符（`_favoriteIds` 已落盘，见 `:136-146`、`:366-367`）。
- **原型/文档依据**：`docs/SPEC.md:159` 与 `docs/ROADMAP.md:88` 承诺“红心收藏歌曲清单”。
- **建议修复**：`mobile_tabs.dart:857` 改为 `player.favoriteTracks.length`（或 `player.favoriteIds.length`）。
- **可验收标准**：单元/widget 测试——`toggleFavorite` 后 `clearQueue()`，断言资料库仍显示“已收藏 N 首”且 N 不变。
- **状态**：待修复

### [MOB-013] 清空播放队列后迷你播放条仍显示幻影曲目，播放键点了没反应

- **编号**：MOB-013
- **严重度**：P2
- **类别**：交互缺陷
- **用户可见现象**：打开播放队列 → 点垃圾桶“清空队列” → 队列空了，但底部迷你播放条依然显示“云水禅心 / 巫娜”并带封面；点它的播放键毫无反应，进度条恒为 0。
- **复现步骤**：1. 播放页 → 队列图标 → 清空；2. 回到列表看迷你播放条；3. 点播放/暂停键 → 无任何变化。
- **代码证据**：
  - `app/lib/views/mobile/mobile_sheets.dart:360-364`：`SoftButton(icon: Icons.delete_outline_rounded, ..., onTap: () => player.clearQueue())`；
  - `app/lib/core/audio/audio_player_service.dart:433-438`：`clearQueue()` 清空 `_playlist` 并 `pause()`，`currentTrack` 变 null（`:98-103`）；
  - `app/lib/navigation/mobile_scaffold.dart:97`：`final track = player.currentTrack ?? mockPresetTracks[0];`（`:193` 同款兜底）—— 队列为空时回落到硬编码第 0 首，显示幽灵曲目；
  - 播放静默失败：`audio_player_service.dart:250-252`：`void play() { if (_playlist.isEmpty) return; ... }` 直接 return，无任何提示。
- **数据真实性**：展示的是“并不存在的当前曲目”，是状态撒谎。
- **原型/文档依据**：`docs/SPEC.md:171` 要求队列抽屉支持“曲目平滑移除与清空”；清空后应进入空态而非显示幽灵。
- **建议修复**：队列为空时迷你播放条渲染空态（“队列已清空” + 灰态按钮）或整体隐藏；`play()` 队列为空时给出 `SnackBar`。
- **可验收标准**：widget 测试——`clearQueue()` 后 pump，断言迷你播放条不再包含文本 `'云水禅心'`（或存在空态标识）。
- **状态**：待修复

### [MOB-014] 金刚区雷达/新碟卡片文案与实际点播曲目无关（Golden Hour → 海阔天空），测试还把错配写成断言

- **编号**：MOB-014
- **严重度**：P1
- **类别**：数据造假 / 工程卫生
- **用户可见现象**：点带“Golden Hour / JVKE”字样的卡片，迷你播放条显示“海阔天空 / Beyond”；点“午夜霓虹 / M83”播放的是“云水禅心 / 巫娜”；点“新碟与精选专栏”任意一张专辑，播放的都是当前队列第 0 首。左大卡副标题“周杰伦 / 告五人 / M83”里根本没有 M83 的曲目。
- **复现步骤**：1. “发现”页点“Golden Hour”卡片；2. 观察迷你播放条标题变为“海阔天空”；3. 点“午夜霓虹” → 变“云水禅心”；4. 点任一“新碟”卡 → 播放当前队列第 0 首。
- **代码证据**：
  - `app/lib/views/mobile/mobile_tabs.dart:386-396`：“Golden Hour”卡片 `onPlay: () { if (player.playlist.length > 2) player.playTrack(player.playlist[2]); }`；
  - `mobile_tabs.dart:353-361`：“午夜霓虹”卡片 `firstWhere((x) => x.title.contains('Midnight') || x.artist.contains('M83'), orElse: () => mockPresetTracks[0])` —— 内置曲库无 M83，必然回落“云水禅心”；
  - 索引 2 的实际曲目：`app/lib/core/audio/track_model.dart:154-158`（`id: 'track-3'`、`title: '海阔天空'`、`artist: 'Beyond'`）；
  - `mobile_tabs.dart:700-705`：新碟 4 张卡片 `onTap: () { if (player.playlist.isNotEmpty) player.playTrack(player.playlist[0]); }` —— 与卡片所标专辑/歌手无关；
  - 测试把错配固化为契约：`app/test/mobile_prototype_1to1_test.dart:174-180`：`await tester.tap(find.text('Golden Hour')); ... expect(audioService.currentIndex, equals(2));`。
- **数据真实性**：卡片标题/歌手为编造，与内置曲库无映射关系；原型 `mobile.html:371` 同样如此，但生产壳未修正。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:901`（I-06）已列为“假”（点击必然 fallback 到云水禅心）；本轮实测确认移动壳仍未修且被单测固化。
- **建议修复**：雷达/新碟卡片数据源改为 `mockPresetTracks` / `getAllKnownTracks()` 的真实条目（文案由数据生成）；同时修正 `mobile_prototype_1to1_test.dart:180` 的魔法下标断言。
- **可验收标准**：对 5 张雷达卡逐一断言“卡片标题 == 播放后 currentTrack.title”，而非断言下标 2。
- **状态**：待修复

### [MOB-015] 编造统计与更新时间：99.4% 契合度、更新于 06:00、“24.8万在听”、“全部 48 专”（实际 4）

- **编号**：MOB-015
- **严重度**：P2
- **类别**：文案不诚实
- **用户可见现象**：日推页宣称“今日契合度 99.4% · 已匹配 6 首温润曲目”、“每日 06:00 更新”；雷达区写“更新于 06:00”；电台每条写“24.8万在听 / 58.2万在听”；新碟区“全部 48 专”——这些数字没有任何后端/统计来源，也不会随时钟变化。
- **复现步骤**：1. 依次打开“每日推荐”、“发现”页雷达区与“新碟与精选专栏”、“声音电台”；2. 记录上述数字；3. 修改系统时间/联网重试，数字不变；4. 数一数新碟卡实际只有 4 张。
- **代码证据**：
  - `app/lib/views/mobile/mobile_pages.dart:64-66`：`Text('专属声学日推 · 每日 06:00 更新')`、`Text('今日契合度 99.4% · 已匹配 6 首温润曲目')`（其中“已匹配 6 首”恰好等于 `mockPresetTracks.length == 6`，此项属实；99.4% 与 06:00 为编造）；
  - `app/lib/views/mobile/mobile_tabs.dart:308-315`：`Text('更新于 06:00')` 硬编码；
  - 电台收听人数：`app/lib/core/audio/track_model.dart:775` / `:799` / `:822` / `:845`（`listeners: '24.8万在听'` 等 4 条硬编码）；
  - `mobile_tabs.dart:673-688`：`Text('全部 48 专')` 而实际 `albums` 列表只有 4 项（`mobile_tabs.dart:632-657`）；
  - 对照：日历头用真实系统日期 `mobile_pages.dart:22` / `:54-55`（`DateTime.now()`）；`mobile_tabs.dart:894` 的“4 位入驻音乐人”与 `track_model.dart:473-506` 的 4 位一致，属实。
- **数据真实性**：编造统计（99.4%、06:00、在听人数、48 专）。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:900`（I-05）已认定“99.4% 与更新时间为编造”。
- **建议修复**：删除无来源的百分比/更新时间，或改为由真实变量拼接（曲目数量取 `mockPresetTracks.length`、更新时间取 `lastRefresh.hour`）；“全部 48 专”改为按 `albums.length` 生成；去掉或标注电台“在听”人数。
- **可验收标准**：grep `99.4` / `更新于 06:00` / `48 专` / `万在听` 在 `app/lib/views/mobile` 与 `track_model.dart` 中 0 命中，或每处都能溯源到真实变量。
- **状态**：待修复

### [MOB-016] 均衡器是纯内存假效果：从不作用于播放后端、不落盘、libmpv 滤镜字符串无调用方

- **编号**：MOB-016
- **严重度**：P1
- **类别**：功能缺失 / 数据造假
- **用户可见现象**：播放页点“均衡器 EQ” → 弹窗标题“声学 10 频段均衡器”、可拖 10 个频段、可套“澎湃低音/通透人声”预设、开关“均衡器已启用”，但听感毫无变化；关掉 App 重开，之前调的音又归零。
- **复现步骤**：1. 播放页 → 均衡器 EQ；2. 把 31Hz/62Hz 拉到 +12；3. 切“澎湃低音”预设；4. 听感无变化；5. 重启 App 再打开 EQ → 全部归 0。
- **代码证据**：
  - `app/lib/core/audio/equalizer_manager.dart:32`：`List<double> _bandGains = List.filled(10, 0.0);`；`:40-51`：`toggleEnabled` / `setBandGain` 只 `notifyListeners()`，全文无 `StorageService`、无 `AudioPlayerBackend` 调用；
  - `equalizer_manager.dart:82-92`：`String toLibmpvFilterString()` —— grep `toLibmpvFilterString` 仅命中定义处，无调用方；且本项目播放后端是 `audioplayers`（`app/lib/core/audio/player_backend.dart:26`），没有 mpv 滤镜通道；
  - UI 接线只写内存：`app/lib/views/common/modals.dart:166` / `:244` / `:302` / `:336`。
- **数据真实性**：UI 呈现的“实时音色变化”不存在；`docs/SPEC.md:468`（E2E-05）宣称“实时生成 libmpv firequalizer 参数，音色变化平滑无咔嗒声”属虚假声明。
- **原型/文档依据**：`mobile.html:1152`（“声学校准均衡器”）、`docs/SPEC.md:172` 与 `docs/ROADMAP.md:101`（移动端均衡器弹层）——原型同样是视觉态，但文档宣称已对齐。
- **建议修复**：要么接真实可改音频的通道，要么把文案改为“均衡器（界面预览，暂未接入音频引擎）”。
- **可验收标准**：若宣称可用：`setBandGain` 后用 fake backend 断言收到参数；若不接入：UI 必须显示“暂未接入”字样。
- **状态**：待修复

### [MOB-017] 歌词自动居中按固定 48px 行高估算，真实行高约 38/44px，长歌词越滚越偏

- **编号**：MOB-017
- **严重度**：P2
- **类别**：视觉缺陷
- **用户可见现象**：歌词页前几句还能居中，播到 20 句以后当前高亮行明显偏下/偏上，甚至滚出可视区中部；用户需要手动拖动找回。
- **复现步骤**：1. 打开全屏播放页 → 切到“歌词”；2. 选歌词较多的曲目（如“云水禅心” 9 行）；3. 播放到后半段，观察高亮行位置逐渐偏离屏幕中部。
- **代码证据**：
  - `app/lib/views/mobile/mobile_sheets.dart:50-59`：`final targetOffset = max(0.0, index * 48.0 - 120.0); _lyricScrollController.animateTo(targetOffset, ...)` —— 假定每行 48px；
  - 实际行高：`mobile_sheets.dart:187-198`：`Padding(padding: EdgeInsets.symmetric(vertical: 10))` + `fontSize: isActive ? 20 : 15` → 非高亮行约 15×1.2 + 20 ≈ 38px，高亮行约 20×1.2 + 20 ≈ 44px（都不是 48）；
  - 列表顶部 `padding: EdgeInsets.symmetric(vertical: 120)`（`:180`）与 `-120.0` 抵消，只对第 0 行成立；
  - 活动行计算本身真实（见 T4/T5）。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：`docs/SPEC.md:170` 承诺“Apple Music 动效歌词”，其关键特性即当前行恒居中。
- **建议修复**：用 `GlobalKey` + `Scrollable.ensureVisible(alignment: 0.5)` 让高亮行自身居中，或用 RenderBox 实测行高替代常数估算。
- **可验收标准**：widget 测试——注入任意 `currentPosition`，断言高亮行 `Rect.center.dy` 与视口中心差 < 24px（对第 1 行与最后一行各断言一次）。
- **状态**：待修复

### [MOB-018] 自适应断点 1024px 与文档约定的 800px 不符

- **编号**：MOB-018
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：在 800~1023px 宽的窗口（900px 的 Windows 窗口、竖屏平板、分屏）里，用户拿到的是移动壳而不是桌面工作台；按文档预期此处应是桌面端。
- **复现步骤**：1. 把窗口宽度调到 900px；2. 观察出现的是移动 4-Tab 壳（而不是 `DesktopScaffold`）；3. 继续缩到 799px，外观无变化（阈值实际为 1024）。
- **代码证据**：
  - `app/lib/navigation/adaptive_scaffold.dart:12-20`：`final isDesktopWidth = constraints.maxWidth >= 1024; if (isDesktopWidth) return const DesktopScaffold(); else return const MobileScaffold();`；
  - 文档：`docs/SPEC.md:471`（E2E-08）“跨越 800px 阈值”、“≥800px 稳定展示桌面工作台，<800px 零缝隙切换为移动端 4-Tab 触控底栏”。
- **数据真实性**：不涉及数据；该差异同时放大 MOB-006/MOB-010 的影响面（桌面用户把窗口拉窄就会看到移动壳，见 `docs/PC_E2E_ACCEPTANCE_ISSUES.md:417`）。
- **原型/文档依据**：上述 `docs/SPEC.md:471`。
- **建议修复**：阈值改为 800（与 SPEC/E2E-08 一致），或反向更新 SPEC 并说明理由，两者必须一致。
- **可验收标准**：widget 测试——注入 `Size(900, 800)`，断言渲染 `DesktopScaffold`（若采用 800 阈值）。
- **状态**：待修复

### [MOB-019] 文档承诺的移动端页面/组件缺失：MobilePlaylistDetailPage、歌单广场分类胶囊、存储占用展示

- **编号**：MOB-019
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：歌单广场只有 6 张卡片（其实是曲目），没有原型/文档里的“分类胶囊筛选”；点卡片直接播放，没有“歌单超大封面头图 + 作者信息 + 收藏歌单”的歌单详情页；本地页没有存储占用容量。
- **复现步骤**：1. 金刚区 → 歌单广场 → 看不到分类胶囊；点卡片 → 直接播放，无详情页；2. 资料库 → 本地与下载 → 无容量显示。
- **代码证据**：
  - `app/lib/navigation/mobile_scaffold.dart:394-415`（`_buildSubPage` switch）共 8 个分支：recommend / fm / playlists / toplist / radio / artists / artist_detail / local，没有 playlist_detail；
  - grep `MobilePlaylistDetailPage` / `MobileVolumeModal` → 0 命中（二者分别被 `docs/SPEC.md:169` / `ROADMAP.md:98` 与 `SPEC.md:174` / `ROADMAP.md:103` 列为已交付）；
  - `app/lib/views/mobile/mobile_pages.dart:273-301`：`MobilePlaylistSquarePage` 只有 `GridView.builder(itemCount: mockPresetTracks.length, onTap: () => player.playTrack(t))`，无分类胶囊，卡片是曲目不是歌单；
  - `mobile_pages.dart:630-669`：本地页无任何容量/缓存展示。
- **数据真实性**：“✅ 1:1 对齐”是虚假标注。
- **原型/文档依据**：`docs/SPEC.md:162`（分类胶囊横向滚动筛选）、`:168`（存储占用容量展示）、`:169`（`MobilePlaylistDetailPage`）；原型有分类筛选实现（`mobile.html:702-707` 的 `filterMobilePlaylistCategory`，逻辑在 `:2289`）。
- **建议修复**：补分类映射 + 歌单详情页；本地页加 `path_provider` 统计的缓存占用；或把这些从文档的“已对齐”改为“未实现”。
- **可验收标准**：grep `MobilePlaylistDetailPage` 在 app/lib 命中，或文档对应行状态改为“未实现”。
- **状态**：待修复

### [MOB-020] 无系统返回键处理，二级页只能靠左上角箭头，Android 返回直接退出应用

- **编号**：MOB-020
- **严重度**：P2
- **类别**：交互缺陷
- **用户可见现象**：在“歌单广场/每日推荐/FM”等二级页按手机系统返回键（或 Android 手势返回）→ 整个 App 退出到桌面，而不是回到 4-Tab 主页。
- **复现步骤**：1. 金刚区进入“排行榜”；2. 按系统返回键；3. 观察 App 直接退出。
- **代码证据**：
  - 二级页是同一 `Scaffold` 内的条件渲染，未压入 `Navigator`：`app/lib/navigation/mobile_scaffold.dart:46-48`、`:394-415`；
  - 全项目 grep `PopScope` / `WillPopScope` → 0 命中；
  - 二级页唯一返回入口是手写 `IconButton`（如 `mobile_pages.dart:29-32`、`:170-173`）。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：原型是 Web 单页，返回键无对应语义；但 `docs/SPEC.md:169` 承诺 Android/iOS/HarmonyOS 三端真机形态，必须处理。
- **建议修复**：给移动壳加 `PopScope(canPop: _subPageId == null, onPopInvokedWithResult: (_, __) => _popSubPage())`；更彻底的做法是把二级页改为 `Navigator.push`。
- **可验收标准**：widget 测试——进入二级页后 `await tester.binding.handlePopRoute()`，断言回到主 Tab（`find.text('发现音乐')`）且未触发退出。
- **状态**：**已修复**（`mobile_scaffold.dart:44` `PopScope(canPop: _subPageId == null, onPopInvokedWithResult: …)`：二级页按系统返回键层级返回到主壳，浮层由 Navigator 路由自行关闭，无上级时才交还系统；MOB-08 断言 `handlePopRoute()` 被消费且 `MobileScaffold` 未退出）

### [MOB-021] 窄屏/大字号下金刚区 5 张固定宽卡片无 Wrap/FittedBox，标签存在溢出风险（未真机实测）

- **编号**：MOB-021
- **严重度**：P2
- **类别**：视觉缺陷
- **用户可见现象**：在 320px 窄屏或系统字体放大（Android 字体 1.3x / iOS 辅助功能大字体）时，“每日推荐/歌单广场/排行榜/声音电台/私人漫游”5 个标签可能互相挤压或出现黄黑 Overflow 条纹并截断。
- **复现步骤**：1. 把窗口宽缩到 320px；2. 系统设置里把字体调到最大档后重进；3. 观察金刚区一行 5 个标签是否溢出。
- **代码证据**：
  - `app/lib/views/mobile/mobile_tabs.dart:190-234`：`Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [5 × _buildKingKongCard])` —— 固定横向 Row，无 `Wrap` / `Flexible` / `FittedBox`；
  - 卡片宽度固定 52（`mobile_tabs.dart:252-254`），标签 `fontSize: 11` 且无 `maxLines` / `overflow`（`:270-277`）→ 宽度取 `max(52, 标签宽)`；
  - 静态估算：5×52 = 260px，页面左右各 16px padding（`mobile_tabs.dart:25`）→ 320px 屏可用 288px，静态勉强放得下（余 28px）；但中文标签在 `textScaler > 1.15` 时“每日推荐”4 字即 > 52px，5 张卡按标签宽撑开后总宽必然超过 288px；
  - **诚实标注**：本项为代码级尺寸推算，未在 320px 真机/模拟器上截图验证。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：原型金刚区容器为 `flex items-center justify-between` + 固定 `w-12 h-12`（`mobile.html:319-350`），同样未做文字缩放适配。
- **建议修复**：该行改为每张卡 `Expanded`（图标固定、标签 `maxLines: 1, overflow: ellipsis`），或在 `LayoutBuilder` 中当宽度 < 360px 时改为两行 `Wrap`。
- **可验收标准**：widget 测试注入 `textScaler: TextScaler.linear(1.3)` + `Size(320, 640)`，`pumpAndSettle` 后断言 `tester.takeException() == null`（无 RenderFlex overflow）。
- **状态**：待修复（未真机验证）

### [MOB-022] 原型调试角标“Mobile”仍在生产壳，并被单测固化为断言（P0-11 I-03 未闭环）

- **编号**：MOB-022
- **严重度**：P2
- **类别**：工程卫生 / 与文档不符
- **用户可见现象**：生产 App 的“发现音乐”标题旁常驻一个浅蓝 “Mobile” 胶囊角标——原型用来标注“这是移动端预览”的调试标记，不是产品功能。
- **复现步骤**：1. 打开移动壳；2. 观察标题右侧的 “Mobile” 胶囊；3. 全 App 无任何开关能隐藏它。
- **代码证据**：
  - `app/lib/views/mobile/mobile_tabs.dart:72-90`：`Container(... child: const Text('Mobile', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w700)))` —— const 常量，无数据来源；
  - 测试固化：`app/test/mobile_prototype_1to1_test.dart:92-93`：`expect(find.text('Mobile'), findsOneWidget);`；
  - 对照 `docs/PC_E2E_ACCEPTANCE_ISSUES.md:898`（I-03）与 `:413`：被点名为“原型资产进入生产包”。
- **数据真实性**：非数据，属交付物污染。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:413` 明确要求处理；`mobile.html:287` / `:1629` 说明它是模板标题旁的固定角标。
- **建议修复**：删除该角标，或仅在 `kDebugMode` 下显示；同步修改 `mobile_prototype_1to1_test.dart:93`。
- **可验收标准**：release 构建中 `find.text('Mobile')` 为 `findsNothing`；实现处被 `if (kDebugMode)` 包裹。
- **状态**：**已修复**（角标已从 `mobile_tabs.dart` 删除（`find.text('Mobile')` 在 `app/lib` 0 命中），未保留任何 `kDebugMode` 分支，生产壳不再含该常量；`mobile_prototype_1to1_test.dart:150` 已改为 `expect(find.text('Mobile'), findsNothing)`）

### [MOB-023] 移动端搜索浮层是桌面形态：固定 620px、提示“按 ESC 退出”、无键盘提交

- **编号**：MOB-023
- **严重度**：P2
- **类别**：与文档不符 / 交互缺陷
- **用户可见现象**：手机上打开搜索浮层，提示写着“搜索全网歌曲、歌手、专辑 (按 ESC 退出)”，但手机没有 ESC；卡片被硬编码 620px 宽裁到屏宽；结果列表最高 380px，键盘弹起后可视区进一步被压缩。
- **复现步骤**：1. 点“发现”页搜索胶囊；2. 读提示“按 ESC 退出”；3. 找 ESC 键 → 无；4. 观察弹层宽度被屏幕裁切。
- **代码证据**：
  - `app/lib/views/common/modals.dart:575-576`：`insetPadding: const EdgeInsets.only(top: 80, left: 20, right: 20)` + `SoftCard(width: 620, ...)`；
  - `modals.dart:597-599`：`hintText: '搜索全网歌曲、歌手、专辑 (按 ESC 退出)...'`；
  - `modals.dart:663-664`：`ConstrainedBox(constraints: const BoxConstraints(maxHeight: 380), ...)`；
  - 该浮层由移动壳打开：`app/lib/navigation/mobile_scaffold.dart:71`：`onOpenSearch: () => showDialog(context: context, builder: (_) => const QuickSearchOverlay())`。
- **数据真实性**：不涉及数据；ESC 提示是桌面文案在移动端的残留。
- **原型/文档依据**：`docs/SPEC.md:157` 只承诺“全局搜索胶囊”；原型移动端用的是 Tab2 内嵌搜索框（`mobile.html:434-447`），不是 620px 桌面弹窗。
- **建议修复**：宽度按屏宽自适应，提示改为移动端文案（去掉 ESC），加 `onSubmitted` 与 `textInputAction: TextInputAction.search`。
- **可验收标准**：在 `Size(390, 844)` 下打开该浮层，断言 `tester.takeException() == null` 且提示文案不含“ESC”。
- **状态**：待修复

### [MOB-024] 位置流每 tick 触发整个移动壳（含 4 个 Tab）全量重建

- **编号**：MOB-024
- **严重度**：P2
- **类别**：手感(动效) / 工程卫生
- **用户可见现象**：播放时在长列表（发现页/资料库）滚动明显比暂停时更易掉帧；迷你条进度在低端机上跳动。
- **复现步骤**：1. 播放一首歌；2. 在发现页快速滚动并观察帧率（`flutter run --profile` + DevTools）；3. 暂停后再滚动作对比。
- **代码证据**：
  - 进度推送频率：`app/lib/core/audio/audio_player_service.dart:164-167`：`_positionSub = _backend.onPositionChanged.listen((p) { _position = p; notifyListeners(); })`（audioplayers 位置流为高频增量流，`app/lib/core/audio/player_backend.dart:26`）；
  - `context.watch<AudioPlayerService>()` 出现在 `_MobileScaffoldState` 的方法中：`app/lib/navigation/mobile_scaffold.dart:96`（灵动岛）、`:192`（迷你条）→ 该 State 成为依赖者，任何位置 tick 都会重跑 `build()`；
  - `build()` 直接构造 4 个 Tab：`mobile_scaffold.dart:66-77`，因此 4 个 Tab 的 build（含发现页多层 Column/Row 与图片组件）每 tick 全部重建；`IndexedStack` 保 State 不省 rebuild。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：`docs/SPEC.md:157` 强调沉浸式滚动体验；无显式性能预算。
- **建议修复**：把迷你条/灵动岛抽成独立 `Consumer<AudioPlayerService>` 或 `Selector`（只选 position/duration/isPlaying），避免整壳重建；对进度做 ≥100ms 节流。
- **可验收标准**：`flutter run --profile` 播放中滚动，DevTools 的 rebuild 计数在 1 秒内不应等于位置回调次数 × 4 个 Tab；或 widget 测试断言发现页 build 次数不随位置 tick 线性增长。
- **状态**：待修复

### [MOB-025] 动画控制器在 build 内直接 repeat()/stop()（两处 build 副作用）

- **编号**：MOB-025
- **严重度**：P2
- **类别**：工程卫生
- **用户可见现象**：功能上旋转/启停是对的，但在高频位置 tick 下，每次 build 都改写动画控制器状态，逼近 Flutter“build 期间修改状态”的断言边界。
- **复现步骤**：1. 打开 FM 页或播放页；2. 反复快速切歌与暂停/播放；3. 观察调试控制台是否出现 build 期间修改状态的异常/警告。
- **代码证据**：
  - `app/lib/views/mobile/mobile_pages.dart:159-163`：在 `build()` 内 `if (player.isPlaying) { if (!_rotationController.isAnimating) _rotationController.repeat(); } else { if (_rotationController.isAnimating) _rotationController.stop(); }`；
  - `app/lib/views/mobile/mobile_sheets.dart:69-73`：同一写法（`_turntableController`）。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：无直接对应；属 Flutter 官方推荐模式（动画启停放 `initState` 的监听回调或 `Selector` 回调）。
- **建议修复**：把启停移到 `AudioPlayerService` 的监听回调（`initState` 中 `addListener`），或由 `isPlaying` 驱动 `TickerMode`。
- **可验收标准**：播放/暂停 50 次后 `tester.takeException() == null`；代码审查确认 `build()` 内不再出现 `repeat()` / `stop()`。
- **状态**：待修复

### [MOB-026] 悬浮迷你播放条会遮住列表最后一张卡片下沿（按代码尺寸推算，未真机实测）

- **编号**：MOB-026
- **严重度**：P2
- **类别**：视觉缺陷
- **用户可见现象**：滚到列表最底部时，最后一个条目的下边缘可能被悬浮的迷你播放条压住，需要再往上蹭一点才能完整看到（在底部系统内边距较小的设备上更明显）。
- **复现步骤**：1. 进入“发现”页滚到底；2. 观察最底部“新碟”卡下沿与迷你条的关系；3. 在无底部 inset 的设备（部分 Android）重复。
- **代码证据**：
  - 迷你条位置与高度：`app/lib/navigation/mobile_scaffold.dart:200-203`（`bottom: 72`）+ `:232-239`（进度条 2.2 + 内边距 14）→ 外沿自下而上约 72px~128px；
  - 列表底部留白：`app/lib/views/mobile/mobile_tabs.dart:25`（`EdgeInsets.fromLTRB(16, 8, 16, 110)`）、`:786`（`(16,16,16,100)`）、`:860`（`(16,16,16,100)`）、`:951`（`(16,16,16,100)`）；
  - 110 < 128 → 在最坏情况（底部 `SafeArea` inset ≈ 0）下最后一张卡约 18px 落在迷你条之后；iPhone 类 inset 34px 时不遮挡；
  - **诚实标注**：本项为几何推算，未真机截图确认，是否可见取决于 `MediaQuery.padding.bottom`。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：原型内容区统一 `pb-36`（`mobile.html:304`），比 Flutter 壳的 100/110 更保守。
- **建议修复**：4 个 Tab 的底部 padding 统一提到 `128 + MediaQuery.paddingOf(context).bottom`。
- **可验收标准**：widget 测试注入 `padding.bottom = 0`，滚到底后断言最后一条 `Rect.bottom <= 迷你条 Rect.top`。
- **状态**：**已修复**（4 个 Tab 底部 padding 统一改用 `_tabListBottomPadding(context) = (136 - MediaQuery.viewPaddingOf(context).bottom).clamp(100, 136)`，136 = 迷你条外沿 128.2 + 8dp 呼吸；新增 MOB-12 在 320×640、底部 inset=0 下滚到底断言 `末项Rect.bottom <= 迷你条Rect.top`）

### [MOB-027] 假数据清理置空了内置曲库，10 处 currentTrack ?? mockPresetTracks[0] / [idx] 让 App 启动即崩（本轮引入的回归）

- **编号**：MOB-027
- **严重度**：P0
- **类别**：工程卫生（阻断可用性）
- **用户可见现象**：App 一启动就红屏 / 直接闪退，任何 Tab 都进不去。因本轮工作区中途不可编译，本条为代码级确定结论，待 analyze 变绿后在安卓真机复现留证。
- **复现步骤**：1. 用当前工作区构建并启动 App（Android/iOS/桌面任一）；2. 首帧构建移动壳灵动岛；3. 观察 `RangeError (index): Invalid value: Valid value range is empty: 0`。
- **代码证据**（全部来自本轮重新 read 的当前树）：
  - `app/lib/core/audio/track_model.dart:199`：`final List<Track> mockPresetTracks = <Track>[];`（本轮"假数据清理"把它从 33 首内置编造曲改为空列表；同文件 :229-236 的 `mockArtistsProfiles`/`mockRadioStations`/`toplistTracksMap` 一并置空，:242 `getArtistProfileByName` 改为 `=> null`）；
  - `app/lib/core/audio/audio_player_service.dart:27`：`final List<Track> _playlist = List.from(mockPresetTracks);` → 启动时 `_playlist` 为空；
  - `app/lib/core/audio/audio_player_service.dart:98-103`：`currentTrack` 在 `_playlist.isEmpty` 时返回 `null`；
  - 于是下列 10 处在空列表上取下标：`mobile_scaffold.dart:97`（灵动岛，首帧执行）、`mobile_scaffold.dart:193`（迷你播放条）、`mobile_sheets.dart:67`、`mobile_pages.dart:157`、`mobile_tabs.dart:358`、`desktop_scaffold.dart:510`、`views/desktop/fullscreen_lyrics_view.dart:60`；另有 `mobile_pages.dart:93`/`:283`、`mobile_tabs.dart:820` 以 `mockPresetTracks[idx]` 渲染（列表恒 0 项，不崩但全空）；
  - 同批清理还让 `mobile_pages.dart:509` 起的 `artist.avatarUrl/bio/tracks` 对可空返回值解引用，`flutter analyze` 因此报 30~46 个 error（本轮实测）。
- **数据真实性**：本条不是数据造假，而是"删除编造数据"时未同步处理消费端空态；清理方向正确、收口不完整。
- **原型/文档依据**：`docs/SPEC.md:157-174` 承诺移动壳 4 Tab 与 9 二级页可用；诚实化不应以启动崩溃为代价。
- **建议修复**：① 所有 `?? mockPresetTracks[0]` 改为空态渲染；② `mobile_pages.dart` 对 `getArtistProfileByName` 的可空返回加空态；③ `mobile_tabs.dart:818-820` 的 `itemCount`/`itemBuilder` 改用 `allKnownTracks` 并在空库时给导入引导。
- **可验收标准**：`flutter analyze` = `No issues found`；`flutter test` 全绿；真机启动停在"发现"页不崩，空库时 4 个 Tab 显示空态文案而非红屏（截图留证）。
- **状态**：修复中（主 Agent 正在收口本轮假数据清理；本 Agent 不修改生产代码）

## 2. 本轮核实为“真”的项（非缺陷，供总账避免误判）

以下 12 项经代码/实测确认真实可用，不应再被当作“假实现”：

| # | 结论 | 证据 |
| :--- | :--- | :--- |
| T1 | 4 个 Tab 之间切换保留各自滚动位置与 State（`IndexedStack` 是有效实现） | `mobile_scaffold.dart:66-77` |
| T2 | 迷你播放条的 2.2px 进度条绑定真实 position 流（非假动画） | `mobile_scaffold.dart:196-198` / `:232-239` + `audio_player_service.dart:164-167` / `:53` |
| T3 | 播放页进度条“松手才 seek”的防抖真实实现（onChanged 只改本地 `_dragPositionMs`，onChangeEnd 才 `player.seek`） | `mobile_sheets.dart:220-235` |
| T4 | 歌词单行高亮真实（按 `currentPosition` 与 `lyric.time` 比较取最大索引） | `mobile_sheets.dart:75-80` / `:182-184` |
| T5 | 歌词自动滚动在暂停时确实停止（位置不再变化 → 活动行不变 → `_lastActiveIndex` 守卫阻止再次 animateTo） | `mobile_sheets.dart:50-52` / `:81-85` |
| T6 | FM 黑胶旋转随播放状态真实启停（`AnimationController.repeat/stop`；写法问题见 MOB-025） | `mobile_pages.dart:159-163`、`mobile_sheets.dart:69-73` |
| T7 | 红心收藏真实落盘（`saveFavoriteIds` + `saveFavoriteTracks`，启动 `_loadFromStorage` 恢复） | `audio_player_service.dart:349-369` / `:135-146` |
| T8 | 音量/静音/原值恢复在服务层真实（`_backend.setVolume` + `saveVolume` + `_lastNonZeroVolume`），仅移动端缺入口（见 MOB-005） | `audio_player_service.dart:373-387` / `:117-122` |
| T9 | 播放模式（列表/单曲/随机）真实落盘并恢复 | `audio_player_service.dart:395-415` / `:124-133` |
| T10 | 睡眠定时器是真实计时器（每秒递减，到点 `pause()`；支持“播完当前曲目后停止”） | `audio_player_service.dart:441-466` / `:188-192`；`mobile_sheets.dart:316-321` |
| T11 | 在线搜索确实发真实 HTTP（实测 200 且返回真实歌曲 JSON），仅音频直链是死链（见 MOB-008） | 实测 E4；`online_music_service.dart:29-84` |
| T12 | 内置音源真实可播（soundhelix mp3 真实存在，实测 content-type audio/mpeg、8945229 字节） | 实测 E2/E3；`track_model.dart:120` |

## 3. 点按“无反应 / 无真实副作用”元素枚举（任务第 12 项）

| 序号 | 元素 | 位置 | 点了会怎样 | 判定 |
| :--- | :--- | :--- | :--- | :--- |
| D1 | “发现音乐”右侧圆角头像 | `mobile_tabs.dart:124-139` | 无任何 onTap，完全无反应 | 死元素 |
| D2 | “我的”用户名卡片（含 PRO 徽章） | `mobile_tabs.dart:954-988` | `SoftCard` 无 `onTap`，完全无反应 | 死元素 |
| D3 | “探索”7 个风格标签 | `mobile_tabs.dart:790-807` | 只换高亮，曲目列表不变（MOB-007） | 无真实副作用 |
| D4 | 搜索胶囊里的麦克风图标 | `mobile_tabs.dart:179` | 点击落入父级 GestureDetector → 打开文本搜索，无语音输入 | 装饰性图标 |
| D5 | FM“垃圾桶” | `mobile_pages.dart:216-222` | 等于“下一首”，无屏蔽、无落盘（MOB-002） | 无真实副作用 |
| D6 | 资料库“我喜欢的音乐”卡片（收藏为 0 时） | `mobile_tabs.dart:906-909` | `if (favs.isNotEmpty)` 否则静默无反应，无提示 | 静默空操作 |
| D7 | “本地与下载”页的 6 首“本地”曲目 | `mobile_pages.dart:646-666` | 能播，但播的是网络演示音频，非本地文件（MOB-009） | 语义欺骗 |
| D8 | 均衡器全部控件（10 频段/预设/开关/重置） | `modals.dart:236-349` | 只改内存值，音色无变化、不落盘（MOB-016） | 无真实副作用 |
| D9 | 迷你播放条播放键（队列被清空后） | `mobile_scaffold.dart:286-288` | `play()` 队列空直接 return，无反应无提示（MOB-013） | 静默空操作 |
| D10 | “新碟与精选专栏”4 张专辑卡 | `mobile_tabs.dart:700-705` | 都播放当前队列第 0 首，与卡片文案无关（MOB-014） | 无真实副作用 |
| D11 | 在线音源搜索结果条目 | `modals.dart:686-689` | 播放必然失败且移动端无提示（MOB-008） | 无真实副作用 |
| D12 | “关注歌手”的关注切换 | `mobile_pages.dart:546-551` | 点“+ 关注”后返回再进回到“已关注”（MOB-011） | 无持久副作用 |

未发现“点了完全无反应”的大范围功能入口：金刚区 5 项下钻、4 Tab、迷你条、播放页、播放队列、睡眠定时都有真实导航或副作用。问题集中在“有反应但副作用是假的”（D3/D5/D8/D10/D11）与个别死元素（D1/D2/D4）。

## 4. 假状态栏 / 假设备名 / 假在线用户核对（任务第 11 项，对照 P0-11）

| 项 | P0-11 原描述 | 本轮实测结论 |
| :--- | :--- | :--- |
| 假时钟 “10:09” | 旧 `mobile_scaffold.dart:104-113` | 已移除：grep `10:09` 在 app/lib 为 0 命中 |
| 假信号/WiFi/充电电池图标 | 旧 `mobile_scaffold.dart:174-183` | 已移除：现顶部为灵动岛胶囊，显示真实 `player.currentTrack.title` 与 `player.isPlaying` 频谱（`mobile_scaffold.dart:94-160`） |
| “Mobile” 调试角标 | `mobile_tabs.dart:72-90` | 仍存在（`mobile_tabs.dart:83`），且仍被单测断言（MOB-022） |
| 假账号 / PRO 徽章 / “声学生态已连接” | I-04 | 仍存在（MOB-010） |
| 假设备名 | —— | 未发现移动壳中出现机型/设备名串（grep `iPhone` / `Android` / `HUAWEI` / `Xiaomi` 无业务命中） |
| 假在线用户数 | —— | 存在：电台“24.8万在听”等 4 条硬编码（MOB-015） |

## 5. 未验证事项（诚实标注，需额外条件）

1. **窄屏 320px / 360px 的真实溢出表现**（MOB-021、MOB-026）：本 Agent 无法启动图形设备或真机，结论基于代码尺寸推算；需真机/模拟器截图或带 `textScaler: 1.3` 的 widget 测试才能定论。
2. **毛玻璃在真机上的观感**（MOB-004）：本轮确认“无 `BackdropFilter`”是代码事实；“看起来像不像毛玻璃”属观感，需真机截图。
3. **audioplayers 对网易云 404 HTML 的具体异常表现**（MOB-008）：本轮只证明 URL 返回 `text/html`（非音频）；`_backend.play` 是抛异常还是静默失败需真机跑一次区分（但两种情况下移动端都无 UI 反馈，缺陷成立）。
4. **移动端真机三端产物**：仓库内无 Android/iOS 构建产物，本次结论基于 `app/lib` 源码 + 对真实网络与真实音频文件的实测。
5. **`docs/SPEC.md` / `ROADMAP.md` 行号**：这两个文件在本轮取证时正被其它 Agent 修改（`git status` 显示为 M），本账本引用的是本轮读取到的工作区内容；若其后再改动，行号可能漂移。
6. **取证后发生的并发改动（重要）**：本 Agent 取证结束后，工作区出现他人对 `app/lib/core/audio/equalizer_manager.dart` 的修改（`git diff` 显示新增诚实注释、并把 `toLibmpvFilterString` 改名为 `toDspFilterDescription`，见 `git diff app/lib/core/audio/equalizer_manager.dart`）。因此 **MOB-016 引用的 `equalizer_manager.dart:82-92` 与该行号已随之漂移**；但该条的实质结论（`bandGains` 不改变实际声音、不落盘、无消费方）在改动后依旧成立，且他人改动方向正是本条建议的“诚实标注”。其余被引用的 `app/lib` 文件（`mobile_scaffold.dart` / `mobile_tabs.dart` / `mobile_pages.dart` / `mobile_sheets.dart` / `audio_player_service.dart` / `track_model.dart` / `online_music_service.dart` / `modals.dart` / `adaptive_scaffold.dart` / `player_backend.dart`）在取证时未被改动。

## 6. 统计汇总

- 条目总数：**32**（MOB-001 ~ MOB-032；§7.3 新增 5 条）
- 严重度分布：**P0 = 1 条**；**P1 = 12 条**；**P2 = 19 条**
  - P0：MOB-027（已修复，见 §7.4）
  - P1：MOB-001、002、003、005、006、007、008、009、010、011、014、016
  - P2：MOB-004、012、013、015、017、018、019、020、021、022、023、024、025、026、028、029、030、031、032
- **状态分布（截至 §8 第二轮真机复验，APK 06:23 构建）**：已修复 **19** 条（MOB-001/002/003/004/005/007/008/009/010/011/013/014/015/016/020/022/026/027/031）、已确认不修 **1** 条（MOB-021）、部分修复 **3** 条（MOB-006/019/023）、待修复 **9** 条（MOB-012/017/018/024/025/028/029/030/032）
- 原最严重 5 条的最新状态：MOB-003 **已修复**（进度上限改用真实 ¬player.duration¬，真机显示真实解码时长）、MOB-009 **已修复**（真实系统文件选择器导入并可播放，遗留 cache 路径问题见 MOB-029）、MOB-002 **已修复**（垃圾桶真实屏蔽并落盘，重启仍在）、MOB-008 **已修复**（移动端也弹诚实 SnackBar，真机复现）、MOB-005 **已修复**（移动端新增音量滑杆+静音，三态落盘）
- 核实为真的项：12 条（§2）
- 未验证 / 需真机条件：5 项（§5）+ 5 项（§7.5）
## 7. 安卓真机验收记录（本轮 APK 构建时间：2026-09-23 02:26）

> 本节由子 Agent B 在真机上实测产出。**构建指纹**：¬app/build/app/outputs/flutter-apk/app-debug.apk¬（02:26:00，206,847,490 字节）。主 Agent 之后又落了新改动并重新构建，故本节结论对应 02:26 构建；若后续构建表现不一致，以新构建为准。
> **截图证据目录**：¬/tmp/mob/*.png¬（本轮全部真机截图）。
> **仅允许改动本文件**：本轮未修改 ¬app/lib¬ / ¬app/test¬，未执行 git commit/push。

### 7.1 设备与安装

| 项 | 实测值 |
| :--- | :--- |
| 设备 | Redmi ¬23013RK75C¬（mondrian），Android 15 / API 35，1440x3200 @560dpi ≈ **411x914 dp**（<1024 走移动壳） |
| 包名 / 入口 | ¬com.mellow.music.app¬ / ¬.MainActivity¬ |
| 系统字体 | 原始 ¬font_scale = 0.9¬（测试后已还原为 0.9） |
| 安装 | 首次 ¬adb install -r¬ 失败：¬Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]¬（HyperOS 限制）。绕过路径：¬adb push ... /sdcard/Download/mellow.apk¬ → ¬adb shell am start -a android.intent.action.INSTALL_PACKAGE -d file:///sdcard/Download/mellow.apk¬ → 手机上依次点「继续安装」(bounds ¬[131,2885][698,3068]¬)、勾选「已了解此应用未经安全检测」、再点「继续安装」→ ¬pm list packages¬ 出现 ¬com.mellow.music.app¬。此后 ¬adb install -r¬ 可直接 ¬Success¬ |
| 启停命令 | ¬adb shell am start -n com.mellow.music.app/.MainActivity¬ / ¬am force-stop¬ |
| 音频限制（诚实标注） | ¬dumpsys audio¬ 显示 ¬ringer mode = VIBRATE¬ 且 "ringer mode muted streams = 0x12e (…STREAM_MUSIC…)"。即该机把 STREAM_MUSIC 静音了，**"能否听见声音"无法核实**；本轮改用三条替代证据交叉验证：① ¬dumpsys audio¬ 出现真实播放器实例；② UI 上出现由 ¬onDurationChanged¬ 回填的**真实解码时长**；③ flutter 日志。另：应用层 ¬setVolume¬ 是 audioplayers 的**每播放器音量**，不会改变系统 STREAM_MUSIC 的档位，故"音量改变 STREAM_MUSIC"这一预期本身不成立，见 7.2-B4 的说明与替代证据。 |

### 7.2 逐项结论（对应主 Agent 的 B1~B8）

**B1 首启不崩溃 + 空库诚实引导 → 通过。** ¬am start¬ 后 ¬pidof¬ 有进程（20431）、¬mCurrentFocus¬ 为 ¬com.mellow.music.app/.MainActivity¬、¬logcat -s flutter:* AndroidRuntime:E¬ 无异常；截图 ¬60_relaunch.png¬ 显示「你的曲库为空」+「曲库还是空的…去顶部搜索在线试听，或在「资料库 → 本地与下载」导入你自己的音乐文件」+「我的专辑 共 0 张 / 还没有专辑」。

**B2 真实搜索 + 来源标注 + 无版权诚实提示 → 通过。** 搜索框输入 ¬jay¬（¬adb shell input text¬）→ 弹出结果：¬想你就写信 (Live)¬ 周杰伦/李硕/张鑫、¬屋顶¬ 周杰伦/温岚/吴宗宪、¬默 (Live)¬ 李荣浩/周杰伦、¬布拉格广场¬，每条带蓝色「网易云」来源角标（截图 ¬66_search3.png¬）；输入 ¬beatles¬ → ¬Let It Be (Remastered)¬/¬Hey Jude¬/¬In My Life (Remastered)¬，同为真实元数据。点第一条 → 迷你条与资料库出现该曲，同时弹出**诚实失败提示**（截图 ¬67_after_pick.png¬）：¬「想你就写信 (Live)」该曲目当前无版权/不可播放（需 VIP 或版权受限）¬；日志同步输出 ¬[AudioPlayerService] 网易云无可用直链: 该曲目当前无版权/不可播放（需 VIP 或版权受限）¬。**没有假播放**（UI 保持暂停态、进度不动）。

**B3 真实系统文件选择器 + 导入 + 可播放 → 通过。** 资料库 → 本地与下载 → 「选择音频文件」→ 弹出 ¬com.google.android.documentsui/com.android.documentsui.picker.PickActivity¬（截图 ¬34_picker.png¬）；抽屉进「下载内容」后 ¬uiautomator dump¬ 可见 ¬e2e_long.wav¬ / ¬e2e_test_one.wav¬ / ¬e2e_test_two.wav¬ 真实文件（事先用 ¬say --data-format=LEI16@22050¬ + ¬adb push¬ 放入 ¬/sdcard/Download¬）；选中后返回 App，列表变「本地曲库 (1 首)」，条目显示真实 ¬localPath¬（截图 ¬61_import1.png¬），并落盘 ¬flutter.mellow_local_library¬；点击播放后 ¬dumpsys audio¬ 出现 ¬new player … usage=USAGE_MEDIA content=CONTENT_TYPE_MUSIC¬、¬format update … sampleRate=22050¬（与该 wav 采样率一致），列表显示**真实解码时长 ¬00:02¬**（旧实现这里是编造元数据）。

**B4 音量/静音真实且落盘 → 通过（但"改变 STREAM_MUSIC"的预期不成立，如实说明）。** 播放页滑杆初始 85% → ¬adb shell input swipe¬ 拖到 40% → UI 变 ¬40%¬，¬shared_prefs/FlutterSharedPreferences.xml¬ 出现 ¬flutter.mellow_audio_volume = …0.3996012460554307¬；点静音 → UI ¬0%¬、落盘 ¬…0.0¬；再点 → 恢复 ¬40%¬、落盘回到 ¬…0.3996012460554307¬（截图 ¬27_volume40.png¬/¬28_muted.png¬/¬29_unmuted.png¬）。**注意**：audioplayers 的 ¬setVolume¬ 作用于播放器实例，不会改写系统 STREAM_MUSIC 档位，所以不能拿 ¬dumpsys audio¬ 的 stream 音量来验收；本轮用"UI + SharedPreferences 落盘 + 代码路径（¬player_backend.dart:63-65¬ → ¬AudioPlayer.setVolume¬）"三者交叉验证。进度上限：见 MOB-003 状态更新（已改为 ¬player.duration¬）。

**B5 FM 垃圾桶真实屏蔽 + 重启仍在 → 通过。** 私人漫游 FM 当前曲 ¬想你就写信 (Live)¬ → 点垃圾桶（坐标 (428,2458)）→ 立即切到 ¬e2e_long¬（截图 ¬68_fm_before.png¬ → ¬69_fm_after_trash.png¬），日志无异常；¬shared_prefs¬ 出现 ¬flutter.mellow_blocked_track_ids = ["netease_509781655","local_75390135"]¬；¬am force-stop¬ 后重启，该键值**原样仍在**（同一条命令两次输出一致），¬mellow_local_library¬ 也在。

**B6 Tab 切换/下钻返回丢状态 → 真机复现，问题仍在。** 在「探索」选中「本地曲目」筛选（截图 ¬46_explore_filtered.png¬ 蓝底选中）→ 回「发现」→ 进「每日推荐」二级页 → 点左上返回 → 再进「探索」：筛选回到「全部」（截图 ¬49_explore_after_subpage.png¬）。同因还会重置 4 个 Tab 的滚动位置（代码：二级页整体替换 Widget 树，见 MOB-001）。另实测：**二级页按系统返回键直接退出到 MIUI 桌面**（¬mCurrentFocus¬ 变 ¬com.miui.home¬，截图 ¬40_after_back_subpage.png¬），对应 MOB-020，真机确认。

**B7 残留编造内容 → 大部分已清除，仅「Mobile」角标仍在。** 实测截图确认已消失：¬99.4%¬、¬更新于 06:00¬、¬全部 48 专¬、¬24.8万在听¬、Unsplash 假封面（专辑/雷达/头像全部为灰底音符占位或真实封面）、¬PRO¬ 徽章。日推页现在写「今日推荐 · 来自你的曲库」「按曲库顺序选取 1 首 · 非算法推荐」「来自你的真实曲库」（截图 ¬47_daily_recommend.png¬）；「我的」页为通用人像图标 +「演示占位」徽章 +「未接入任何账号 / 会员体系，昵称仅为界面演示占位」（截图 ¬45_profile.png¬/¬73_narrow_profile.png¬）；「探索」标签改为真实来源筛选（¬全部 / 本地曲目¬）并写明「标签按曲目真实来源（source）筛选，应用不内置任何流派标签」（截图 ¬43_explore.png¬）。**仍存在的原型资产**：¬发现音乐¬ 标题旁的浅蓝「Mobile」角标（截图 ¬60_relaunch.png¬ 等每一张都有），即 MOB-022 未修。

**B8 窄屏 320dp 与大字号 1.3 → 无溢出条纹，通过。** ¬adb shell wm size 1120x2489¬（560dpi 下 = **320dp 宽 × 711dp 高**）→ 发现/资料库/我的均无黄黑 overflow 条纹（截图 ¬71_narrow_discover.png¬/¬72_narrow_library.png¬/¬73_narrow_profile.png¬）；¬adb shell settings put system font_scale 1.3¬ + 重启 App → 仍无 overflow（截图 ¬77_font13_discover.png¬/¬78_font13_library.png¬）。测完已还原：¬wm size reset¬、¬font_scale 0.9¬（截图 ¬79_font_restored.png¬）、导航模式回 ¬gestural¬（¬cmd overlay list¬ 显示 ¬[x] gestural¬）。320dp 下可见一处真实遮挡，见 MOB-031。

### 7.3 新缺陷条目

### [MOB-028] 二级页把底部 4-Tab 栏与迷你播放条一并隐藏，用户在二级页无法切 Tab 或控制播放

- **编号**：MOB-028
- **严重度**：P2
- **类别**：交互缺陷
- **用户可见现象**：进入「每日推荐 / 私人漫游 FM / 本地音乐 / 排行榜」等任一二级页后，底部导航栏和正在播放的迷你条整条消失；想换歌、暂停或切到别的 Tab，只能先点左上角返回键退回主页。
- **复现步骤**：1. 播放任意一首曲目（出现迷你条）；2. 点金刚区「每日推荐」进入二级页；3. 观察底部：既无 4-Tab 栏也无迷你播放条（真机截图 ¬47_daily_recommend.png¬、¬33_local.png¬）；4. 想暂停只能先返回。
- **代码证据**：¬app/lib/navigation/mobile_scaffold.dart:45-47¬：¬if (_subPageId != null) { return _buildSubPage(); }¬ —— 二级页 return 的是**另一个完整 Scaffold**（例如 ¬mobile_pages.dart:848¬ 起的 ¬MobileLocalMusicPage¬ 自带 ¬Scaffold¬），而迷你条与底栏只在主页那条 ¬Stack¬ 分支里创建（¬mobile_scaffold.dart:83-86¬）。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：¬docs/SPEC.md:157-174¬ 描述"4 主 Tab + 9 二级页 + 5 底部抽屉"的形态；¬mobile.html¬ 原型里播放器是覆盖层，不卸载底栏。
- **建议修复**：把二级页从"替换整棵树"改为覆盖层（¬Stack¬ + ¬Offstage/Visibility¬ 或半透明路由），或在二级页 Scaffold 内同样渲染迷你条。
- **可验收标准**：播放中进入任一二级页，断言 ¬find.byKey(const Key('mini_player_pill'))¬ 仍能命中，且底部 4 个 Tab 文本仍可见。
- **状态**：待修复（真机实测复现）

### [MOB-029] 导入的本地音频被复制进应用 cache 目录，系统清缓存后落盘曲库会指向不存在的文件

- **编号**：MOB-029
- **严重度**：P2
- **类别**：工程卫生（数据可靠性）
- **用户可见现象**：导入成功的曲目"看起来"已入库，但系统存储不足/清理缓存后该条目会播放失败或无声；用户没做任何"删除"操作却丢歌。
- **复现步骤**：1. 资料库 → 本地与下载 → 选择音频文件；2. 查看条目副标题路径；3. 或 ¬adb shell run-as com.mellow.music.app cat shared_prefs/FlutterSharedPreferences.xml | grep mellow_local_library¬。
- **代码证据**：真机落盘值：¬flutter.mellow_local_library = [{"id":"local_256321739", … "localPath":"/data/user/0/com.mellow.music.app/cache/file_picker/1790097394076/e2e_test_one.wav"}]¬ —— 路径位于 **cache** 分区；¬app/lib/core/sources/local_music_service.dart:31-39¬ 直接把 ¬FilePicker¬ 返回的 ¬f.path¬ 交给 ¬trackFromPath¬ 存库，未拷贝到 documents 目录。
- **数据真实性**：路径与文件都真实（实测可播放、采样率 22050 与源文件一致），问题在**存储位置不持久**。
- **原型/文档依据**：¬docs/SPEC.md:168¬ 要求"离线曲库列表、本地文件扫描导入、存储占用容量展示"；¬docs/ROADMAP.md:97¬ 标注"离线已下载音乐列表"。
- **建议修复**：导入时把文件拷贝到 ¬getApplicationDocumentsDirectory()/local_music/¬ 再入库（或申请持久化 URI 权限），落盘前校验文件存在。
- **可验收标准**：导入后断言 ¬localPath¬ 不含 ¬/cache/¬；清空应用缓存后曲目仍可播放。
- **状态**：待修复（真机取到落盘路径为 cache）

### [MOB-030] HyperOS/MIUI 上 adb 安装被系统策略阻断，无人值守安装不可行

- **编号**：MOB-030
- **严重度**：P2
- **类别**：工程卫生（交付 / CI）
- **用户可见现象**：¬adb install -r app-debug.apk¬ 直接失败，必须人工在手机上点两次「继续安装」并勾选"已了解此应用未经安全检测"才能装上；自动化脚本（含 ¬flutter run¬）首次安装会失败。
- **复现步骤**：1. ¬adb install -r app/build/app/outputs/flutter-apk/app-debug.apk¬；2. 观察 ¬Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]¬；3. 手动确认后才成功。
- **代码证据**：原始输出：¬Performing Streamed Install¬ → ¬adb: failed to install …: Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]¬；¬settings get global verifier_verify_adb_installs¬ 已为 ¬0¬、¬secure install_non_market_apps = 1¬，说明不是 Play 校验而是 HyperOS 的"USB 安装"策略（¬ro.miui.ui.version.name=V816¬ / ¬ro.mi.os.version.name=OS3.0¬）。
- **数据真实性**：不涉及数据；属设备/交付流程限制。
- **原型/文档依据**：¬docs/SPEC.md:169¬ 声明 Android 三端产物为交付形态；README 快速启动未提示小米系前置开关。
- **建议修复**：在 docs 的真机验收章节补充"小米/HyperOS 需开启开发者选项『USB 安装』"的前置条件；CI 改用非 MIUI 设备或侧载流程。
- **可验收标准**：在一台 HyperOS 设备上 ¬adb install -r¬ 返回 ¬Success¬，或文档明确记录该前置开关与手动步骤。
- **状态**：待修复（文档/流程，非代码）

### [MOB-031] 悬浮迷你播放条遮挡列表内容；320dp 真机实测到条目被压住

- **编号**：MOB-031
- **严重度**：P2
- **类别**：视觉缺陷
- **用户可见现象**：在发现页把列表往下滚，中间的「我的专辑」标题与专辑卡片被悬浮的迷你播放条压住一半（窄屏 320dp 下尤其明显）。
- **复现步骤**：1. ¬adb shell wm size 1120x2489¬（=320dp 宽）；2. 回到「发现」页并向下滚动；3. 观察迷你条与其上方内容重叠（真机截图 ¬71_narrow_discover.png¬）。
- **代码证据**：迷你条固定 ¬app/lib/navigation/mobile_scaffold.dart:202-205¬：¬Positioned(left: 14, right: 14, bottom: 72, …)¬，自身高度约 2.2 + 上下内边距 14（¬:234-243¬）+ 内容行（封面 38 / 播放键 34）≈ 56dp，占据自底部 72dp~128dp 的带状区域；4 个 Tab 列表底部留白只有 ¬mobile_tabs.dart:25¬（¬(16, 8, 16, 110)¬）与 ¬:786/:860/:951¬（100）——**110dp < 128dp**，最后一个条目无法完全滚到播放条之上。
- **数据真实性**：不涉及数据。
- **原型/文档依据**：原型内容区统一 ¬pb-36¬（=144px，¬mobile.html:304¬），比当前 Flutter 壳保守。
- **建议修复**：4 个 Tab 的底部 padding 提到 ¬128 + MediaQuery.paddingOf(context).bottom¬，或让迷你条参与布局而非覆盖。
- **可验收标准**：320dp 下滚动到底，断言最后一个条目 ¬Rect.bottom <= 迷你条 Rect.top¬；¬mobile_tabs.dart¬ 4 处底部 padding 改为动态值。
- **状态**：**已修复**（与 MOB-026 同源修复：4 处底部 padding 已改为动态值 ¬_tabListBottomPadding¬，MOB-12 widget 测试在 320×640 复现该场景并通过；真机新构建截图待补）

### [MOB-032] FM 把队列内所有曲目都屏蔽后，界面又回到被屏蔽的曲目上

- **编号**：MOB-032
- **严重度**：P2
- **类别**：交互缺陷
- **用户可见现象**：队列只剩 2 首时连点两次垃圾桶把两首都"屏蔽"了，界面显示的还是刚被屏蔽的那首，用户以为屏蔽失效。
- **复现步骤**：1. 曲库仅 2 首时进入私人漫游 FM；2. 点垃圾桶（当前曲被屏蔽并切走）；3. 再点一次垃圾桶；4. 观察界面回到第一首（截图 ¬68_fm_before.png¬ → ¬69_fm_after_trash.png¬ → ¬70_fm_after_trash2.png¬），此时 ¬mellow_blocked_track_ids¬ 已含两个 id。
- **代码证据**：¬app/lib/views/mobile/mobile_pages.dart:212-226¬：¬_playNextUnblocked()¬ 兜底为"最多绕行一圈"——¬for (var i = 0; i < total; i++) { player.next(); … if (!blocked.contains(current.id)) return; }¬；当**全部**曲目都在黑名单里时循环结束也不 return，位置留在被屏蔽曲目上，且无"全部已屏蔽"提示。
- **数据真实性**：屏蔽 id 与落盘都真实（¬netease_509781655¬ 与 ¬local_75390135¬），只是"全部屏蔽"边界缺空态。
- **原型/文档依据**：¬docs/SPEC.md:165¬/¬docs/ROADMAP.md:94¬ 要求"垃圾桶屏蔽曲目"，未定义全部屏蔽的边界行为。
- **建议修复**：统计未被屏蔽数量，为 0 时显示空态（"曲库中所有曲目都已被屏蔽 · 一键恢复"）并提供清空 ¬mellow_blocked_track_ids¬ 的入口。
- **可验收标准**：曲库 2 首全部屏蔽后断言出现"全部已屏蔽"空态文案；点恢复后断言 ¬mellow_blocked_track_ids¬ 被清空。
- **状态**：待修复（真机复现）

### 7.4 老条目状态变更表（**本表覆盖各条目正文的「状态」字段**）

| 编号 | 新状态 | 本轮证据（真机 / 代码，行号均为本轮重新 read 所得） |
| :--- | :--- | :--- |
| MOB-001 | **已修复** | 二级页改为 ¬Stack¬ 覆盖层（¬mobile_scaffold.dart:99-103¬），主 ¬IndexedStack¬ 常驻树内；4 个 Tab/列表补 ¬PageStorageKey¬。MOB-07/09 widget 测试断言下钻返回后滚动位置与来源筛选标签保持 |
| MOB-002 | **已修复** | ¬mobile_pages.dart:169-226¬（¬_blockedIdsKey='mellow_blocked_track_ids'¬、¬_blockCurrentTrack¬、¬_playNextUnblocked¬；垃圾桶绑定 ¬:315-322¬）；真机 prefs 含两个 id 且重启后仍在 |
| MOB-003 | **已修复** | ¬mobile_sheets.dart:71-73¬（¬totalMs = max(1.0, player.duration.inMilliseconds…)¬）、¬:255-261¬（总时长用 ¬player.duration¬）；真机显示真实解码时长 ¬00:02¬ |
| MOB-004 | **已修复** | 迷你条与底栏包 ¬ClipRRect¬+¬BackdropFilter(ImageFilter.blur(18,18))¬，底色 alpha 0.95/0.92 → 0.72；MOB-11 widget 测试断言两处模糊层存在（真机视觉待新构建复验） |
| MOB-005 | **已修复** | ¬mobile_sheets.dart:316-349¬ 真实音量滑杆 + 静音；真机 85%→40%→0%→40% 三态落盘 ¬flutter.mellow_audio_volume¬ |
| MOB-006 | 部分未验证 | 仍无任何 ¬MediaQuery.padding/viewPadding¬ 处理（¬mobile_scaffold.dart¬ 0 命中），底栏/迷你条仍在 ¬SafeArea¬ 之外（¬:51-88¬、¬:202-205¬、¬:336-340¬）；手势导航下标签位于手势区之上，切 3 键导航后 MIUI 截图不含导航栏 → 保留缺陷并注明"3 键下无可视证据" |
| MOB-007 | **已修复** | ¬mobile_tabs.dart:732-852¬ 按 ¬Track.source¬ 真实来源筛选 + 诚实说明与空态；真机 ¬43_explore.png¬/¬46_explore_filtered.png¬ |
| MOB-008 | **已修复** | ¬main.dart:32-66¬ ¬PlaybackNoticeListener¬ + ¬:77/101¬ 全局 ¬scaffoldMessengerKey¬ → 移动端也弹 SnackBar；真机 ¬67_after_pick.png¬ + ¬audio_player_service.dart:366/377/385/402/413/425¬ 诚实文案 |
| MOB-009 | **已修复**（遗留 MOB-029） | ¬mobile_pages.dart:822-909¬ 真实 ¬file_picker¬ 导入 + ¬player.localTracks¬ + 空态；¬audio_player_service.dart:245-269¬ ¬importLocalFiles/addLocalTracks/localTracks¬ + ¬saveLocalLibrary¬；真机走通并播放成功 |
| MOB-010 | **已修复** | ¬mobile_tabs.dart:973-1013¬ 通用人像 +「演示占位」+「未接入任何账号 / 会员体系…」；真机 ¬45_profile.png¬/¬73_narrow_profile.png¬ |
| MOB-011 | **已修复（未真机复核）** | ¬mobile_pages.dart:680-697¬ ¬_isFollowing=false¬ 初值 + ¬StorageService.getFollowedArtists/saveFollowedArtists¬ 落盘；¬:604-662¬ 歌手列表来自真实曲库；本轮未进详情页复核 |
| MOB-012 | 待修复 | ¬mobile_tabs.dart:867¬ 仍取 ¬player.playlist.where(…)¬ 计数（¬:947¬ 展示），分母仍是当前队列 |
| MOB-013 | **已修复** | ¬mobile_scaffold.dart:96-97¬、¬:193-195¬、¬mobile_sheets.dart:66-69¬ 空态；真机空库 ¬60_relaunch.png¬ 无迷你条 |
| MOB-014 | **已修复** | ¬mobile_tabs.dart:283-300¬ 雷达由 ¬player.playlist¬ 派生（¬:351-391¬），¬:337-343¬ 空态；真机 ¬67_after_pick.png¬ 卡片标题 = 实际曲目 |
| MOB-015 | **已修复** | 硬编码统计消失：真机日推页「今日推荐 · 来自你的曲库」「按曲库顺序选取 1 首 · 非算法推荐」（¬47_daily_recommend.png¬）；雷达右上改 ¬player.playlist.length¬（¬mobile_tabs.dart:322-331¬）；资料库歌手数真实统计（¬:865-869¬、¬:907¬） |
| MOB-016 | **已修复（诚实化）** | ¬modals.dart:212¬「当前音频引擎不支持实时音效，调节仅记录参数、暂不改变声音」；¬equalizer_manager.dart¬ 诚实注释 + 改名 ¬toDspFilterDescription¬ |
| MOB-017 | 待修复 | ¬mobile_sheets.dart:52¬ 仍为 ¬index * 48.0 - 120.0¬ |
| MOB-018 | 待修复 | ¬adaptive_scaffold.dart:14¬ 仍 ¬>= 1024¬（文档约定 800） |
| MOB-019 | 部分修复 | 歌单广场改为只展示真实导入歌单（¬mobile_pages.dart:351-360¬）；二级页 switch 仍 8 项、无 ¬MobilePlaylistDetailPage¬（¬mobile_scaffold.dart:396-417¬） |
| MOB-020 | **已修复** | ¬mobile_scaffold.dart:44¬ ¬PopScope(canPop: _subPageId == null, onPopInvokedWithResult: …)¬；MOB-08 widget 测试断言 ¬handlePopRoute()¬ 被消费、回主壳且未退出 |
| MOB-021 | **已确认不修（实测无溢出）** | 320dp + ¬font_scale 1.3¬ 下发现/资料库/我的均无 overflow 条纹（¬71/72/73/77/78¬） |
| MOB-022 | **已修复** | 角标已删（¬app/lib¬ 内 ¬find.text('Mobile')¬ 0 命中）；¬mobile_prototype_1to1_test.dart:150¬ 断言 ¬findsNothing¬ |
| MOB-023 | 部分修复 | 仍 ¬width: 620¬（¬modals.dart:615¬）且提示含「按 ESC 退出」（¬:637¬）；但**旧构建必现的 121px 溢出在 02:26 构建已消失**（对比 ¬14_search_tap.png¬/¬15_search_results.png¬ 的 BOTTOM OVERFLOWED BY 121 PIXELS 与新截图 ¬66_search3.png¬ 无条纹） |
| MOB-024 | 待修复 | 仍由 ¬_MobileScaffoldState¬ 内 ¬context.watch<AudioPlayerService>()¬ 驱动整壳重建（¬mobile_scaffold.dart:94-95¬、¬:191-192¬），而 ¬audio_player_service.dart:164-167¬ 每个位置回调都 ¬notifyListeners()¬ |
| MOB-025 | 待修复 | build 内直接启停动画：¬mobile_sheets.dart:75-79¬、¬mobile_pages.dart:211-215¬ |
| MOB-026 | **已修复** | 4 个 Tab 底部 padding 改用 ¬_tabListBottomPadding¬（¬(136 - viewPadding.bottom).clamp(100,136)¬，136 = 迷你条外沿 128.2 + 8dp）；MOB-12 在 320×640、inset=0 下滚到底断言末项不被遮挡（详见 MOB-031） |
| MOB-027 | **已修复** | 空态兜底 ¬mobile_scaffold.dart:96-97¬、¬:193-195¬、¬mobile_sheets.dart:66-68¬；真机空库启动无 RangeError |

### 7.5 本节新增的未验证 / 限制

1. **听感**：设备 ¬ringer=VIBRATE¬ 且 ringer mode 静音 STREAM_MUSIC，无法用耳朵确认有声；以 ¬dumpsys audio¬ 播放器实例 + 真实解码时长 + 日志替代。若要听感验收，需先把铃声模式调回"响铃"。
2. **iTunes 试听未在真机点播成功**：结果按"网易云优先"合并（¬core/sources/online_music_service.dart:85-94¬），实测 ¬jay¬/¬beatles¬ 可见前 4 条全为网易云，iTunes 结果排在其后；本轮未滚到底逐个点播，故"iTunes 30 秒试听真的能播"**未取得真机证据**，仅确认代码路径存在（¬itunes_music_service.dart:20-56¬ 只收有 ¬previewUrl¬ 的条目）。
3. **3 键导航遮挡**：切到 ¬navbar.threebutton¬ 后 MIUI 截图不包含系统导航栏，无法目视证明底栏被覆盖；已还原 gestural（MOB-006 保留、注明证据不足）。
4. **歌手详情关注落盘**：本轮曲库只有 1 位歌手且未进详情页点击关注，MOB-011 的"落盘"仅代码级确认。
5. **进度推进**：本机生成的可播放样本过短（¬say¬ 生成的 wav 实际约 1 秒），未取得"进度条连续推进多秒"的截图；但取得更强证据——真实解码时长回填与 ¬dumpsys audio¬ 播放器实例。
## 8. 安卓真机复验（第二轮，本轮 APK 构建时间：2026-09-23 06:23:34）

> **构建指纹**：¬app/build/app/outputs/flutter-apk/app-debug.apk¬（06:23:34，230,760,763 字节）。安装：¬adb install -r¬ → ¬Success¬（本轮未再触发 HyperOS 拦截）。启动 ¬pid 27808¬，¬logcat -s flutter:* AndroidRuntime:E¬ 无异常。
> **截图证据**：¬/tmp/mob/80~101*.png¬。**设置已还原**：¬wm size¬ 回到 1440x3200、¬font_scale¬ = 0.9、导航模式 gestural。
> 本轮只改动本文件；未改 ¬app/lib¬ / ¬app/test¬，未执行 git commit/push。

### 8.1 本轮新修项复验

| 复验项 | 结论 | 真机 / 代码证据 |
| :--- | :--- | :--- |
| MOB-004 真实毛玻璃 | **已修复** | 代码：¬navigation/mobile_scaffold.dart:251-252¬（迷你条）与 ¬:374-376¬（底栏）均为 ¬BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18))¬；真机：迷你条与底栏呈半透明磨砂，透过它可见下层专辑卡片的模糊色块（不可辨字），内容仍可辨识轮廓（截图 80 / 85 / 96 / 101） |
| MOB-026 / MOB-031 底部留白 | **已修复** | 代码：¬views/mobile/mobile_tabs.dart:16-20¬ ¬_tabListBottomPadding¬ = ¬(136.0 - MediaQuery.viewPaddingOf(context).bottom).clamp(100.0, 136.0)¬；真机 320dp（¬wm size 1120x2489¬）滚到底后，最后两项「中国新歌声第二季 第1…」与「未知专辑 / 本地文件 · 1 首」完整位于迷你条之上，无遮挡（截图 96） |
| MOB-020 系统返回键 | **已修复** | 代码：¬mobile_scaffold.dart:46-52¬ ¬PopScope(canPop: _subPageId == null, onPopInvokedWithResult: …)¬；真机在「每日推荐」「私人漫游 FM」「本地音乐」三处按 ¬input keyevent 4¬ 后 ¬mCurrentFocus¬ 仍为 ¬com.mellow.music.app/MainActivity¬、¬pidof¬ 仍 27808（未退出），界面回到主页（截图 83 / 91 / 100→101） |
| MOB-001 状态保留 | **已修复** | 代码：二级页改为覆盖层 ¬mobile_scaffold.dart:101-105¬，主树常驻（¬IndexedStack¬ ¬:68-90¬ + 4 个 ¬PageStorageKey¬ ¬:73/78/82/86¬）；真机：探索「本地曲目」筛选经二级页往返仍选中（82 → 84）；320dp 下发现页滚动位置往返后像素级一致（99 → 101） |
| MOB-022 Mobile 调试角标 | **已修复** | ¬grep -rn "'Mobile'" views/mobile/mobile_tabs.dart¬ → **0 命中**；真机各截图（80/83/85/91/96/101）标题旁已无浅蓝角标 |
| FM 副标题悬挂「·」 | **已修复** | ¬mobile_pages.dart:141-152¬：¬_joinMetadata¬ 过滤空字段、¬_fmSubtitle¬ 为空时回退「未知曲目信息」；真机对 album 为空的本地曲目 e2e_long，副标题仅显示「本地文件」，无尾随「·」（截图 89） |

### 8.2 回归验证（移动端真实播放链路）

| 项 | 结论 | 证据 |
| :--- | :--- | :--- |
| 本地导入文件播放 | 仍正常 | 点播放后 ¬dumpsys audio¬：¬new player piid:27855 uid/pid:10233/27808¬（本 App 进程）、随后 ¬event:stopped¬（约 1 秒样本播完即停）；播放页按钮切为暂停态（截图 93） |
| 音量三态 + 落盘 | 仍正常 | 拖动 → ¬mellow_audio_volume = …0.795764428972428¬；静音 → ¬…0.0¬；再点 → 恢复 ¬…0.795764428972428¬；播放页显示 80%（截图 92） |
| 搜索无版权曲目诚实提示 | 仍正常 | 搜索 ¬jay¬ → 点「想你就写信 (Live)」→ 底部 SnackBar「…该曲目当前无版权/不可播放（需 VIP 或版权受限）」（截图 94），UI 不进入假播放 |
| 首启 / 空态不崩溃 | 仍正常 | 本轮启动 pid 27808，无异常；空态与导入态均正常渲染 |

### 8.3 本轮新发现

**无新增缺陷**（因此未分配 MOB-033）。逐项走查未发现新问题：三处二级页的系统返回、320dp 与 1.3 字号、两个来源的搜索与播放、导入与落盘均符合预期。既有条目中仍待修复的见 8.4。

### 8.4 状态变更表（**覆盖**各条目正文的「状态」字段）

| 编号 | 新状态 | 本轮证据 |
| :--- | :--- | :--- |
| MOB-001 | **已修复** | 见 8.1（82 → 84 筛选保留；99 → 101 滚动保留） |
| MOB-004 | **已修复** | ¬mobile_scaffold.dart:251-252 / :374-376¬ + 截图 80 / 96 / 101 |
| MOB-020 | **已修复** | ¬mobile_scaffold.dart:46-52¬ + 截图 83 / 91 / 100→101 |
| MOB-022 | **已修复** | grep 0 命中 + 各截图无角标 |
| MOB-026 | **已修复** | ¬mobile_tabs.dart:16-20¬ + 截图 96 |
| MOB-031 | **已修复** | 截图 96（最后两项完整位于迷你条之上） |
| MOB-006 / 019 / 023 | 部分修复（不变） | 本轮未改动这三项；PO 见 §7.4 |
| MOB-012 / 017 / 018 / 024 / 025 / 028 / 029 / 030 / 032 | 待修复（不变） | 本轮未改动；正文与 §7.4 证据仍有效 |
| MOB-021 | 已确认不修（不变） | 320dp 与 1.3 字号实测无溢出（§7.4） |

**最新状态分布**：已修复 **19** 条（MOB-001/002/003/004/005/007/008/009/010/011/013/014/015/016/020/022/026/027/031）；部分修复 **3** 条（MOB-006/019/023）；已确认不修 **1** 条（MOB-021）；待修复 **9** 条（MOB-012/017/018/024/025/028/029/030/032）。

### 8.5 限制（沿用 §7.5，未变）

1. 听感仍无法核实（该机 ¬ringer=VIBRATE¬ 且 ringer mode 静音 STREAM_MUSIC）；播放验证依赖 ¬dumpsys audio¬ 播放器实例 + UI 状态 + 日志。
2. iTunes 试听仍未在真机点播成功（结果网易云优先排序；本轮未再滚到底部验证）。
3. 3 键导航遮挡仍缺可视证据（MIUI 截图不含系统导航栏），MOB-006 按"部分修复"保留。


## 8. V3 收口：MOB-001 / 004 / 020 / 022 / 026 修复记录（代码 + widget 测试级，真机复验待新构建）

> 本节由子 Agent V3 落地。§7 的真机结论对应 02:26 的旧 APK 构建；本节改动发生在其后，**尚未在真机上重新构建复验**，因此只声明"代码 + widget 测试已验证"，不冒充真机通过。

### 8.1 修复清单

| 编号 | 修复 | 落点 | 回归测试 |
| :--- | :--- | :--- | :--- |
| MOB-020 | 系统返回键层级返回：二级页→主壳；浮层由 Navigator 路由关闭；无上级才交还系统 | ¬app/lib/navigation/mobile_scaffold.dart:44-50¬ ¬PopScope(canPop: _subPageId == null, onPopInvokedWithResult: …)¬ | MOB-08 ¬handlePopRoute()¬ |
| MOB-001 | 二级页由「替换整棵树」改为 ¬Stack¬ 全屏覆盖，主 ¬IndexedStack¬ 常驻树内；4 个 Tab 与列表补 ¬PageStorageKey¬ | ¬mobile_scaffold.dart:58-103¬ | MOB-07 / MOB-09 |
| MOB-022 | 删除原型调试角标「Mobile」，不留 ¬kDebugMode¬ 分支 | ¬app/lib/views/mobile/mobile_tabs.dart¬（¬find.text('Mobile')¬ 0 命中） | MOB-02 ¬findsNothing¬ |
| FM 副标题 | 专辑为空时不再渲染「本地文件 · 」悬挂分隔符，改由 ¬_joinMetadata/_fmSubtitle¬ 过滤空字段 | ¬mobile_pages.dart:141-151¬ | MOB-10 |
| MOB-004 | 迷你条/底栏加真实 ¬ClipRRect¬+¬BackdropFilter(ImageFilter.blur(18,18))¬，底色 alpha 0.95/0.92 → 0.72 | ¬mobile_scaffold.dart:236-258 / :372-386¬ | MOB-11 |
| MOB-026 / MOB-031 | 4 个 Tab 底部 padding 动态化 ¬(136 - MediaQuery.viewPaddingOf(context).bottom).clamp(100, 136)¬（136 = 迷你条外沿 128.2 + 8dp 呼吸） | ¬mobile_tabs.dart:13-22¬ + 4 处列表 | MOB-12（320×640, 底部 inset=0） |

### 8.2 证据

- ¬cd app && flutter analyze¬ → ¬No issues found!¬
- ¬cd app && flutter test¬ → ¬All tests passed!¬（+162，含新增 MOB-11 / MOB-12；基线 149+）
- 新增测试均为无条件断言，无 ¬if¬/环境分支跳过。

### 8.3 仍未闭环 / 遗留

1. **真机复验未做**：本节修复未重新构建 APK 走真机，MOB-004 的「滚动内容不可辨识」、MOB-020 的 Android 手势返回、MOB-026 的 320dp 实拍均需新构建补图。
2. **MOB-006 仍在**：底栏/迷你条仍位于 ¬SafeArea¬ 之外；MOB-026 只调整了列表留白，未改系统内边距避让，两者不可互相代替。
3. **MOB-028 仍待决策**：二级页当前依旧隐藏底栏与迷你条（¬mobile_scaffold.dart:94/97¬），本次未改动该行为。

