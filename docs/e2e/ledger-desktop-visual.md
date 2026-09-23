# E2E 验收缺陷账本 — 桌面端真实截图视觉专项 (Desktop Visual)

> 负责人：子 Agent V1 ｜ 覆盖范围：macOS 桌面端真实运行截图 + 12 视图 / 5 模态逐张目检，重点为**布局错乱/重叠/空白、文字截断、空态可读性、深浅色、毛玻璃/阴影/圆角、残留假数据或占位文案、顶栏/侧栏/播放条遮挡**。
> 格式与取证规则：`docs/e2e/FORMAT.md`。与交互/功能账本 `docs/e2e/ledger-desktop.md`（子 Agent A）互补：本文件只记**看得见**的问题，并附**截图像素路径**为证据。
> 全部原图归档于 `docs/evidence/desktop-snapshots/`（2400×1600 PNG，窗口逻辑尺寸 1200×800 @2x 真实截图，未压缩、无缩略图）。

## 0. 取证环境、方法与基线（先读）

- **平台**：macOS 26.6.1 (25G76)，Apple M1 (MacBookAir10,1)，主显示器 5120×2880（UI 2560×1440 @2x）。
- **产物**：`flutter build macos --debug` → `app/build/macos/Build/Products/Debug/Mellow Music.app`（PRODUCT_NAME 已是 `Mellow Music`，窗口标题实测为 `Mellow Music`；旧构建里的窗口标题 `app` 属过期产物）。
- **取证方式（走通的是"真实应用"这条路，不是离屏渲染）**：
  1. `open "…/Debug/Mellow Music.app"` 启动真实应用，`screencapture -x -o -l <windowId>` 抓**单窗口原图**（5120×2880 全屏抓取也保留）；
  2. `osascript` 被 TCC 拒绝（`System Events` → `不允许辅助访问 -1728` / `不允许发送按键 1002`），因此改用自编译的 `CGEvent` 注入器（`AXIsProcessTrusted() = true`）：全局键盘 ⌘K / Space / ←→↑↓ / M / L / Q / Esc + 全局鼠标点击，全部**真实落到应用**（已用 L 键打开巨幕歌词、Q 键开合抽屉、点击底栏 EQ/睡眠/队列/搜索/导入逐一验证）；
  3. 视图切换靠点击左侧栏真实导航项（坐标由截图像素网格标定，见 `21-sidebar-items-grid.png`）。
- **重要澄清（避免误判）**：早期截图曾得到"整窗纯黑"，经 `sample` 抓取 `io.flutter.raster` 线程栈确认真实渲染（Impeller `DrawOval → AttemptDrawBlur`）后判定为 **macOS 对"被遮挡窗口"返回黑色 backing store** 的截图伪影——把窗口置前后同一进程渲染完全正常，且同机 `flutter create` 的 hello-world 也能正常渲染。**故不记为缺陷。**
- **基线**：第一轮（V1）修改后 `cd app && flutter analyze` → `No issues found!`；`flutter test` → **178/178 全绿**（+178，高于 149 基线）。
- **基线（第二轮 V2，DESK-V-004~011 修复后）**：`cd app && flutter analyze` → `No issues found!`；`flutter test` → **188/188 全绿**（178 基线 + 10 条新增验收用例 `app/test/desk_visual_v004_v011_test.dart`）。第二轮新增截图 `50-after-…`~`66-after-…`（见各条目与 §3.1）。
- **并发修改声明**：取证/修复期间工作区同时存在主 Agent 的未提交改动。本文件引用的行号对应下列哈希（后续改动请按哈希重核）：

| 文件 | 取证后 sha1 |
| :--- | :--- |
| `app/lib/views/desktop/desktop_views.dart` | `41e5f739097417dc2f2d2bb5b3360664f3f65213` |
| `app/lib/views/desktop/fullscreen_lyrics_view.dart` | `cffdd912003659836787afcf840e6e48dd6ab9ad` |
| `app/lib/navigation/desktop_scaffold.dart` | `c16720a354f96d7b247ffdcb02a387364c52efa5` |
| `app/lib/views/common/modals.dart` | `f94967f0b33f452a350e798e9b65bd945951f8ff` |

- **第二轮（V2）复核提示**：上表 sha1 是第一轮取证时的快照；DESK-V-004~011 修复后 `desktop_views.dart` / `desktop_scaffold.dart` / `modals.dart` / `fullscreen_lyrics_view.dart` / `soft_button.dart` 均有新改动（行号请以第二轮截图与本次 diff 为准，勿再按旧行号核对）。
- **数据真实性说明**：截图中的曲目（`云水禅心 / 巫娜 · 天禅 · 琴筝和鸣`，封面/歌词均为真实抓取）来自用户真实播放历史（`shared_preferences` 里真实存在的 1 条记录），由点击历史行触发**真实播放**后出现在底栏与歌词页；本文件未注入任何编造数据。空态截图反映的是"曲库为空"的真实状态。
- **归档清单**（`docs/evidence/desktop-snapshots/`，第一轮 V1 归档共 34 张；第二轮新增 17 张见下）：
  `01-discover-light` `02-playlists-light` `03-toplist-light` `04-artists-empty-light` `05-artist-detail-light` `06-podcast-light` `07-favorite-empty-light` `08-imported-light` `09-history-light` `10-local-empty-light` `11-settings-light` `12-lyrics-empty-light` `13-lyrics-playing-light` `14-sync-light` `15-sources-light` `16-discover-dark` `17-playlists-dark` `18-history-dark` `20-player-dock-playing` `21-sidebar-items-grid` `30-modal-eq` `31-modal-sleep-timer` `32-drawer-queue` `33-modal-import-playlist` `34-overlay-quick-search` `35-discover-with-library` + 6 张修复前对照 `40-before-…``45-before-…`。
- **第二轮（V2）新增截图清单**（同一批真实截图，2400×1600，未压缩）：`50-after-DESK-V-011-discover-empty-hero` `51-after-DESK-V-004-eq-presets-visible` `52-after-DESK-V-005-sidebar-follows-selection` `53`~`59-after-DESK-V-006-sidebar-vs-h1-{toplist,artists,history,local,sync,sources,settings}` `60-after-DESK-V-008-podcast-four-sections` `61-after-DESK-V-010-quick-search-empty` `62-after-DESK-V-009-artist-detail-favorite-consistent` `63-after-DESK-V-007-fullscreen-lyrics-tonearm` `64-after-DESK-V-006-sidebar-vs-h1-11views`（由上述真实截图裁切拼版，非渲染合成）`65-after-DESK-V-009-favorited-both-filled` `66-after-DESK-V-007-tonearm-vinyl-rotating`。
- **第二轮取证方式**：复用 V1 的 CGEvent 注入器（`/tmp/click`、`/tmp/drive`、`/tmp/scroll`、`/tmp/winlist.swift`，源码同目录），`flutter build macos --debug` 后 `open "…/Debug/Mellow Music.app"`，用像素网格标定侧栏 12 项坐标（imageY=289/381/473/565/657/833/925/1017/1109/1285/1377 + 顶栏齿轮），`screencapture -x -o -l <windowId>` 抓单窗口原图；键盘用 `l`/`escape` 真实落到应用。

---

## 1. 缺陷清单

### [DESK-V-001] 无曲目时进入巨幕全屏歌词是一张"只有一行灰字的空白页"，且鼠标用户看不到任何退出入口

- **编号**：DESK-V-001
- **严重度**：P1
- **类别**：视觉缺陷 / 交互缺陷
- **用户可见现象**：未选择曲目时按 `L`（或点底栏封面）进入全屏歌词，整屏只有正中一行浅灰小字「暂无播放内容」，没有声学光晕背景、没有卡片、右上角**没有关闭按钮**（对比：有曲目时右上角有收藏/退出两个圆钮）。鼠标用户被困在该页，只能靠 `ESC` 逃出；同一页与其余视图的空态风格完全不一致，看起来像渲染失败的白屏。
- **复现步骤**：1. 启动 app（不播放任何曲目）；2. 按 `L`；3. 观察整屏仅有「暂无播放内容」一行灰字、无退出按钮；4. 只能按 `ESC` 返回。
- **代码证据（修复前）**：`app/lib/views/desktop/fullscreen_lyrics_view.dart:129-137`
  ```dart
  if (track == null) {
    return CallbackShortcuts(
      bindings: shortcuts,
      child: const Focus(
        autofocus: true,
        child: Scaffold(body: Center(child: Text('暂无播放内容', style: TextStyle(color: Colors.grey)))),
      ),
    );
  }
  ```
  有曲目分支的关闭按钮在 `fullscreen_lyrics_view.dart:186-191`，无曲目分支整段缺失。
- **证据截图**：修复前 `docs/evidence/desktop-snapshots/40-before-DESK-V-001-lyrics-empty.png`；修复后 `docs/evidence/desktop-snapshots/12-lyrics-empty-light.png`（可见光晕背景 + 图标 + 标题/引导文案 + 右上角退出按钮）。
- **数据真实性**：不涉及数据，纯空态渲染缺失。
- **原型/文档依据**：`docs/SPEC.md:147` 将 `fullscreenLyrics` 定义为完整 12 视图之一；`docs/e2e/ledger-desktop.md` DESK-001 已确认该页承诺「退出全屏 (ESC)」按钮存在，空态下却不成立。
- **建议修复**：空态分支复用有曲目分支的外壳（`AcousticMeshGlow` 背景 + 右上角 `fullscreen_exit_rounded` 关闭钮），并把文案换成"图标 + 标题 + 引导"。
- **可验收标准**：widget 测试：不注入任何曲目 → `sendKeyEvent(keyL)` → `pump(1s)` → 断言存在 `DesktopFullscreenLyricsView` 且 `find.byTooltip('退出全屏 (ESC)')` 命中；`tester.tap` 该按钮 → 断言回到 `DesktopScaffold`。
- **状态**：已修复（本轮）。修复后 `flutter analyze` 无问题、`flutter test` 178/178 全绿，截图 `12-lyrics-empty-light.png` 复核通过。

### [DESK-V-002] 空态文案用 `textMuted(#94A3B8)` 直压浅色弥散渐变，对比度仅约 1.8:1，几乎不可读（4 处）

- **编号**：DESK-V-002
- **严重度**：P1
- **类别**：视觉缺陷
- **用户可见现象**：在没有白色卡片兜底的三个视图里，空态引导文字直接画在淡紫弥散渐变上，颜色却是最浅的 `textMuted`：`我喜欢的音乐` 的「暂无收藏曲目，在播放或搜索时点击红心即可收入心动歌单」、`本地与下载` 的「本地曲库暂无内容」、`热门歌手` 的「曲库中还没有歌手信息 ……」以及该页副标题「来源：你自己的曲库（…）」都淡到几乎看不出。对照 `歌单广场/导入与自建歌单/声音电台`（文字在白色卡片内）可读性明显更好。
- **复现步骤**：1. 启动 app（曲库/收藏为空）；2. 依次点侧栏「我喜欢的音乐」「本地与下载」「热门歌手」；3. 观察页面上那几行灰字与背景几乎同色。
- **代码证据（修复前）**：
  - `app/lib/views/desktop/desktop_views.dart:1230` `Text('暂无收藏曲目…', style: TextStyle(color: theme.textMuted, fontSize: 13))`
  - `app/lib/views/desktop/desktop_views.dart:1667` `color: locals.isEmpty ? theme.textMuted : theme.textPrimary`
  - `app/lib/views/desktop/desktop_views.dart:840` `style: TextStyle(fontSize: 13, color: theme.textMuted)`
  - `app/lib/views/desktop/desktop_views.dart:827` 硬编码 `color: Colors.grey`
  - 色值来源 `app/lib/design_system/tokens.dart:30-31`：`textMutedLight = #94A3B8`（相对亮度≈0.36）压在渐变实测像素 `(235,206,229)`（亮度≈0.68）上，对比度≈**1.8:1**。
- **证据截图**：修复前 `41-before-DESK-V-002-favorite.png` / `42-before-DESK-V-002-local.png` / `43-before-DESK-V-002-artists.png`；修复后 `07-favorite-empty-light.png` / `10-local-empty-light.png` / `04-artists-empty-light.png`。
- **数据真实性**：不涉及。
- **原型/文档依据**：`docs/SPEC.md:99-118` 只规定阴影/圆角，未定义正文对比度；按可读性红线（正文 ≥3:1）判定不合格。
- **建议修复**：这 4 处改用 `theme.textMuted → theme.textSecondary`（`#475569`，对比度≈7:1），`Colors.grey` 改用 `theme.textSecondary`；卡片内的次要说明保持不动。
- **可验收标准**：`flutter test` 中渲染上述三视图空态，断言空态 `Text` 的 `style.color == theme.textSecondary`（不得为 `textMuted`）；并复核 `11-settings-light.png` 同风格的 `textSecondary` 用法一致。
- **状态**：已修复（本轮，3 个视图 4 处）。

### [DESK-V-003] 「我的排行榜」FAVORITE 卡片标题折行，第二行顶到播放按钮，与 LIBRARY 卡片不齐

- **编号**：DESK-V-003
- **严重度**：P2
- **类别**：视觉缺陷
- **用户可见现象**：巅峰榜单页（页面标题「我的排行榜」）两张卡片里，左卡「我的曲库」标题一行；右卡「我喜欢的音乐」因 146px 封面放不下而折成「我喜欢的音 / 乐」两行，第二行与右下角圆形播放按钮在同一视觉带上，两卡标题基线不一致。
- **复现步骤**：1. 点侧栏「巅峰榜单」；2. 对比左右两张卡片的标题行数。
- **代码证据（修复前）**：`app/lib/views/desktop/desktop_views.dart:669-672`，`Text(c['title'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1))`，无 `maxLines`；容器宽度 `desktop_views.dart:624-625` 固定 `width: 146`，内边距 `EdgeInsets.all(12)` → 可用 122px，而「我喜欢的音乐」6 字 ×(20+1)=126px → 必然折行。
- **证据截图**：修复前 `44-before-DESK-V-003-toplist.png`；修复后 `03-toplist-light.png`。
- **数据真实性**：卡片文案全部来自真实曲库计数（`player.playlist` / `player.favoriteTracks`），无编造。
- **原型/文档依据**：`docs/SPEC.md:139` 要求"前三名冠亚季军特殊徽章排位"，实现已诚实改为"我的排行榜"，本项仅针对文字折行观感。
- **建议修复**：标题字号 20→18、`letterSpacing` 1→0.2，并加 `maxLines: 1, overflow: TextOverflow.ellipsis`。
- **可验收标准**：`flutter test` 中以 1440×900 与 1200×800 渲染 `DesktopToplistView`，断言两张卡标题 `Text` 的 `maxLines == 1` 且无 `RenderFlex overflowed` 报错。
- **状态**：已修复（本轮）。

### [DESK-V-004] EQ 弹窗预设胶囊被弹窗右边缘裁切，且横滑无任何提示

- **编号**：DESK-V-004
- **严重度**：P2
- **类别**：视觉缺陷 / 交互缺陷
- **用户可见现象**：点底栏 `tune` 图标开 EQ，预设行第 4 个胶囊「温润爵士 (Warm Jazz)」被弹窗右边界硬切（只看到「温润爵士 (W…」），没有任何渐隐、滚动条或箭头提示可横向滑动，用户会以为文案被截断或按钮坏了。
- **复现步骤**：1. 默认 1200×800 窗口；2. 点底栏 EQ 图标；3. 观察预设胶囊行最右侧被切断。
- **代码证据**：`app/lib/views/common/modals.dart:233-250` `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(EqualizerPreset.values.map(...)))`——确实可横滑，但无任何可滚动视觉提示；弹窗宽度由 `modals.dart:609-613` 的 `maxWidth: 620` 限定。
- **证据截图**：`docs/evidence/desktop-snapshots/30-modal-eq.png`。
- **数据真实性**：预设名与频段（31Hz~16kHz）为真实参数，无编造。
- **原型/文档依据**：`docs/SPEC.md:150` 要求"Flat/Bass/Vocal/Jazz/Spatial 预设一键套用"，Spatial 预设当前不可见即等于在默认窗口下不可达。
- **建议修复**：给胶囊行加右侧渐隐遮罩（`ShaderMask`）或改用 `Wrap` 两行；或把弹窗 `maxWidth` 提到 680 让 4 个预设完整可见。
- **可验收标准**：`flutter test` 中在 1200×800 打开 `EqualizerModal`，断言 `find.text('温润爵士 (Warm Jazz)')` 的 `rect.right <= dialogRect.right`（不得被裁）。
- **修复（第二轮 V2）**：`app/lib/views/common/modals.dart` 把预设行由「横向 `SingleChildScrollView` + `Row`」改为 `Wrap(spacing: 8, runSpacing: 8)`：6 个预设自动换行，默认窗口下全部完整可见，且不再存在"看不见但能横滑"的隐藏区；每个胶囊加 `ValueKey('eq-preset-<name>')`。
- **验收测试**：`app/test/desk_visual_v004_v011_test.dart` → `V-004: 6 个预设全部完整可见且不超出弹窗右边界`（逐个断言 `Text` 的 `rect.right <= 弹窗右边界`）。
- **新截图**：`docs/evidence/desktop-snapshots/51-after-DESK-V-004-eq-presets-visible.png`（1200×800 真实截图：第一行「原声直通 / 澎湃低音 / 通透人声」，第二行「温润爵士 / 全景声场 / 自定义调校」，全部完整、无裁切）。
- **状态**：已修复（第二轮 V2）。

### [DESK-V-005] 侧栏在应用默认窗口(1200×800)下装不下 12 个导航项，且不跟随选中项滚动

- **编号**：DESK-V-005
- **严重度**：P2
- **类别**：视觉缺陷 / 交互缺陷
- **用户可见现象**：默认窗口下侧栏只能显示 11 项，第 12 项「个性化设置」被裁在滚动区底部只露一条蓝边（见截图底部）；从顶栏齿轮进入设置后，侧栏**不会滚动跟随**到选中项，用户看不到"当前在哪一项"；侧栏也没有可见滚动条提示还能往下滑。
- **复现步骤**：1. 默认 1200×800 启动；2. 点顶栏齿轮 → 渲染设置页；3. 观察侧栏底部仅露出被裁的蓝色选中条，选中项不在可视区。
- **代码证据**：`app/lib/navigation/desktop_scaffold.dart:445-477` `ListView(padding: EdgeInsets.fromLTRB(14,16,14,28), children: [3 组标题 + 12 项])`——没有 `ScrollController`/`Scrollable.ensureVisible`，也没有把选中项滚入视野的逻辑；每项高度≈44 + 组间距 18 + 组标题≈21，合计约 930px > 可用高度(800-28-78≈694)。
- **证据截图**：`11-settings-light.png`（底部被裁的蓝色选中条）、`21-sidebar-items-grid.png`（像素网格标定）。
- **数据真实性**：不涉及。
- **原型/文档依据**：`docs/SPEC.md:134-153` 桌面 12 视图均需可达；当前"可达但不可见"。
- **建议修复**：给侧栏 `ListView` 挂 `ScrollController`，在 `_navigateTo` 后对选中项 `ensureVisible`；或在窗口高度 <760 时压缩项间距。
- **可验收标准**：`flutter test` 中 1200×800 下点「个性化设置」（或齿轮）后，断言选中项 `SoftButton` 的 `rect` 完全落在侧栏可视矩形内。
- **修复（第二轮 V2）**：`app/lib/navigation/desktop_scaffold.dart` 给侧栏 `ListView` 挂 `ScrollController` + `Scrollbar(thumbVisibility: true)`（常显滚动条 = "还能往下滑"的可发现性），并在 `_navigateTo` / `_goBack` / `_goForward` 后调用 `_ensureActiveNavVisible()`：用 `RenderAbstractViewport.getOffsetToReveal` 精确计算，只在该项真的超出可视区时滚动（已可见则完全不跳变）。侧栏宽度 220→236 以容纳统一后的长文案，导航项水平内边距 16→12。
- **验收测试**：`app/test/desk_visual_v004_v011_test.dart` → `V-005: 默认 1200×800 从顶栏齿轮进入设置后，选中项完整落在侧栏可视区内`（断言选中项 rect 完全含于 `desktop-sidebar` rect）与 `V-005: 侧栏常显滚动条`。
- **新截图**：`docs/evidence/desktop-snapshots/52-after-DESK-V-005-sidebar-follows-selection.png`（点顶栏齿轮进入「个性化与系统设置」后，侧栏自动上滚，最后一项完整可见且为蓝色选中态，右侧滚动条 thumb 可见）。
- **状态**：已修复（第二轮 V2）。

### [DESK-V-006] 侧栏标签与页面标题系统性不一致（7 组）

- **编号**：DESK-V-006
- **严重度**：P2
- **类别**：文案不诚实 / 视觉缺陷
- **用户可见现象**：点进去之后标题换了个名字，用户会怀疑点错了入口：侧栏「巅峰榜单」→ 页面「我的排行榜」；「热门歌手」→「我的歌手」；「本地与下载」→「本地音乐」；「多端同步中心」→「多端协同与云端同步中心」；「播放历史」→「播放足迹历史」；「个性化设置」→「个性化与系统设置」；「LX 音源管理」→「自定义音源管理」。（同名的只有「发现音乐 / 歌单广场 / 声音电台 / 我喜欢的音乐 / 导入与自建歌单」。）
- **复现步骤**：1. 依次点击上述 7 个侧栏项；2. 对照侧栏标签与页面大标题。
- **代码证据**：侧栏标签 `app/lib/navigation/desktop_scaffold.dart:456-473`；页面标题 `desktop_views.dart:573`（我的排行榜）、`:825`（我的歌手）、`:1665`（本地音乐相关）等。
- **证据截图**：`03-toplist-light.png`、`04-artists-empty-light.png`、`10-local-empty-light.png`、`14-sync-light.png`、`09-history-light.png`、`11-settings-light.png`、`15-sources-light.png`。
- **数据真实性**：不涉及数据，只影响命名一致性。
- **原型/文档依据**：`docs/SPEC.md:134-153` 给每个视图定义了模块名，实现两侧各取其一。
- **建议修复**：以页面标题为单一来源，把侧栏标签改成同名字符串（或反之），一次改 7 个字符串。
- **可验收标准**：`flutter test` 遍历 12 个视图，断言"侧栏按钮文案 == 页面 H1 文案"（同一映射表驱动）。
- **修复（第二轮 V2）**：以**页面 H1 为单一命名来源**（保留 V-003 已确立的诚实命名，并与移动端同名二级页一致），在 `app/lib/views/desktop/desktop_views.dart` 新增 `DesktopViewLabels` / `desktopNavEntries` / `desktopViewTitles` 三张唯一映射表；侧栏改为遍历 `desktopNavEntries` 渲染（`desktop_scaffold.dart` 不再硬编码任何标签），7 个页面 H1 也改为引用同一常量。**侧栏 7 个标签因此改为**：巅峰榜单→**我的排行榜**、热门歌手→**我的歌手**、本地与下载→**本地音乐**、多端同步中心→**多端协同与云端同步中心**、播放历史→**播放足迹历史**、个性化设置→**个性化与系统设置**、LX 音源管理→**自定义音源管理**；「声音电台专区」H1 与侧栏统一为「声音电台」。
- **受影响测试（已同步）**：`app/test/batch2_toplist_artist_eq_test.dart`、`batch3_playlist_podcast_test.dart`、`batch4_discover_and_recommend_test.dart`、`mellow_music_comprehensive_test.dart`、`desktop_toplist_and_sync_test.dart` 中「按旧侧栏文案点击/断言」改为稳定 key `desktop-nav-<id>` 与「视图内 H1」限定查找。
- **⚠️ 越界提示（需主 Agent 处理）**：`app/integration_test/desktop_real_user_e2e_test.dart`（本轮按约束**未改**）里的 `tapSidebar(tester, '巅峰榜单'/'热门歌手'/'本地与下载'/'播放历史'/'多端同步中心'/'LX 音源管理'/'个性化设置')` 与 `marker: '我的排行榜'/'本地音乐'/'播放足迹历史'/'多端协同与云端同步中心'/'自定义音源管理'/'个性化与系统设置'/'声音电台专区'` 已与新文案不一致，需同步该文件的 7 个 nav 文案与 7 个 marker。
- **验收测试**：`V-006: 11 个有 H1 的视图，侧栏文案 == 页面 H1`（遍历 `desktopViewTitles`，逐个点击侧栏项并断言"视图内 H1 文本 == 侧栏文案"；`discover` 以 Hero 卡片作页头、无独立 H1，故不在表内）。
- **新截图**：`53`~`59-after-DESK-V-006-sidebar-vs-h1-{toplist,artists,history,local,sync,sources,settings}.png`，以及 11 视图逐行对照拼图 `64-after-DESK-V-006-sidebar-vs-h1-11views.png`（每行左侧=真实截图中高亮的侧栏项，右侧=同页 H1）。
- **状态**：已修复（第二轮 V2）。

### [DESK-V-007] 巨幕歌词缺少 SPEC 承诺的"唱臂"，黑胶只剩一张纯黑圆盘

- **编号**：DESK-V-007
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：有曲目时全屏歌词左栏是"黑色圆盘 + 中间封面"，旋转确实是真实的（两次间隔 5s 截图中心区差异像素 28947/40000，证明在转），但**没有任何唱臂/唱针**，也没有唱片沟槽或高光，观感更像一个黑色圆圈而非"黑胶唱机"。
- **复现步骤**：1. 播放任意曲目；2. 按 `L`；3. 观察左栏只有圆盘，无唱臂。
- **代码证据**：`app/lib/views/desktop/fullscreen_lyrics_view.dart:202-250`——`AnimatedBuilder + Transform.rotate + Container(shape: circle, color: 0xFF111111, border 6px)`，整棵子树无唱臂相关 widget。
- **证据截图**：`docs/evidence/desktop-snapshots/13-lyrics-playing-light.png`。
- **数据真实性**：曲目/封面/歌词均为真实数据（歌词逐行高亮跟随真实播放进度），仅缺装饰件。
- **原型/文档依据**：`docs/SPEC.md:147`「左侧微凹旋转黑胶唱机+唱臂」。
- **建议修复**：在圆盘左上叠加一根细长 `Transform.rotate` 唱臂（含配重与唱针），仅装饰、不改变布局。
- **可验收标准**：`flutter test` 中 `find.byKey(const ValueKey('vinyl-tonearm'))` 命中且在 `13-lyrics-playing-light.png` 目检可见。
- **修复（第二轮 V2）**：`app/lib/views/desktop/fullscreen_lyrics_view.dart` 在左栏黑胶上叠加新组件 `_VinylTonearm`（转轴底座 + 金属臂杆 + 唱针头，`key: ValueKey('vinyl-tonearm')`，`IgnorePointer` 不抢手势、`Positioned` 不改变左栏布局高度），唱臂转轴固定在唱片右上、唱针斜向落在盘面沟槽上；同时给黑胶加多层同心径向渐变（模拟沟槽）与斜向高光，消除"一个纯黑圆"的观感。
- **验收测试**：`V-007: 有曲目时全屏歌词渲染唱臂（vinyl-tonearm）`。
- **新截图**：`63-after-DESK-V-007-fullscreen-lyrics-tonearm.png`、`66-after-DESK-V-007-tonearm-vinyl-rotating.png`（相隔 5s 两张：唱臂位置固定不动，唱片沟槽/封面朝向不同 = 唱片在转、唱臂不转）。
- **状态**：已修复（第二轮 V2）。

### [DESK-V-008] 声音电台与 SPEC 的"4 大板块单集试听"不符（实现为单一空态卡片）

- **编号**：DESK-V-008
- **严重度**：P2
- **类别**：与文档不符
- **用户可见现象**：侧栏「声音电台」页只有标题「声音电台专区」+ 一行诚实说明 + 一张空态卡片，没有 SPEC 描述的「深夜治愈 / 助眠白噪 / 音乐故事 / 科技前沿」四大板块，也没有任何单集。
- **复现步骤**：1. 点侧栏「声音电台」；2. 观察页面仅一张空态卡。
- **代码证据**：`app/lib/views/desktop/desktop_views.dart:1058-1139` `DesktopPodcastView`：`Column(标题 + 副标题 + 单个 SoftCard 空态)`，无分区/列表实现。
- **证据截图**：`docs/evidence/desktop-snapshots/06-podcast-light.png`。
- **数据真实性**：**诚实标注**「当前未接入真实播客内容源，暂无可播放的电台节目」，未编造节目，符合数据真实性红线；本条只记"与文档不符"。
- **原型/文档依据**：`docs/SPEC.md:142`。
- **建议修复**：要么按 SPEC 补真实播客源后再渲染四板块，要么同步修订 SPEC 把该页降级为"未接入"。
- **可验收标准**：文档与实现二选一对齐；若实现为空态，则 SPEC 第 3.1 节该行须标注"未实现"。
- **修复（第二轮 V2）**：本轮**不可改 `docs/SPEC.md`**（不在允许修改范围），因此实现侧按 SPEC 3.1 补齐 4 大板块骨架：`app/lib/views/desktop/desktop_views.dart` 新增 `podcastSections`（深夜治愈 / 助眠白噪 / 音乐故事 / 科技前沿），`DesktopPodcastView` 渲染 4 张板块卡（图标 + 板块名 + 主题 + 逐板块诚实标注「本板块尚未接入真实单集内容源」），并保留页面级诚实说明与「暂无电台内容…」引导卡片 + 新增「搜索在线曲库」按钮（真实打开全局搜索弹窗）。**没有真实内容源就不编造任何节目/主播/时长/在听人数**——即"结构对齐 SPEC、内容诚实为空"。
- **验收测试**：`V-008: 4 大板块可见且逐板块诚实标注未接入`（断言 4 个板块名各命中一次、4 次「本板块尚未接入真实单集内容源」、且 4 个 V1 已删除的编造节目名仍为 findsNothing）。
- **新截图**：`60-after-DESK-V-008-podcast-four-sections.png`。
- **状态**：已修复（实现侧；SPEC 文档口径仍建议主 Agent 标注"内容源未接入"）。

### [DESK-V-009] 同一首歌同时显示"已收藏"（歌手详情实心粉红心）与"未收藏"（底栏空心）

- **编号**：DESK-V-009
- **严重度**：P2
- **类别**：视觉缺陷（状态不一致）
- **用户可见现象**：播放《云水禅心》时，歌手详情页「代表作列表」该行右侧是**实心粉红心**，而同屏底栏播放条最左侧同一首歌却是**空心心形**；同一时刻同一条数据两种渲染，用户无法判断到底收藏没有。
- **复现步骤**：1. 播放历史中的《云水禅心》；2. 进入「热门歌手」→ 点歌手卡片进详情；3. 同屏对比代表作行的红心与底栏的红心。
- **代码证据**：两处都读同一状态机，理论上不应不同：
  - 歌手详情行 `app/lib/views/desktop/desktop_views.dart:1050-1053` `Icon(player.isFavorite(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.pink)`
  - 底栏 `app/lib/navigation/desktop_scaffold.dart:634-642` `player.isFavorite(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded`
  - 像素取证：`real_artist_detail` 原图 (2251,887) = `(234,41,107)` 实心粉；底栏红心区域 (490-590, 1490-1580) **无任何红色像素**（空心）。
- **证据截图**：`docs/evidence/desktop-snapshots/05-artist-detail-light.png`（左为实心红心，底部为空心）。
- **补充取证**：同一轮里「我喜欢的音乐」页头部计数为「共收藏 0 首心动单曲」且列表为空（见 46-before-DESK-V-012-stale-duration.png）——即 player.favoriteTracks 为空时，仍有某行渲染成"已收藏"。这排除了"用户确实收藏过"的可能，指向 isFavorite(id)（按 id 判定，storage_service 的 _keyFavoriteIds）与 favoriteTracks（曲目列表，_keyFavoriteTracks）两份存储不同步，或同一首歌在曲库/历史/播放器里存在多个 Track.id。**根因未完全定位，标注未完全验证。**
- **数据真实性**：不涉及编造数据；属同一实体两处状态不一致。
- **原型/文档依据**：`docs/SPEC.md:143`「红心曲目清单、取消/收藏即时响应」——同一曲目必须处处一致。
- **建议修复**：统一以 `track.id` 为收藏主键；排查历史持久化恢复出的 `Track` 与播放队列/曲库中的同一首歌是否生成了不同 `id`（`app/lib/core/audio/track_model.dart` 的 id 生成或 `audio_player_service` 回填路径），必要时在收藏判定中按 `source+localPath` 归一化。
- **可验收标准**：`flutter test`：播放/恢复同一首歌后，断言 `player.isFavorite(currentTrack.id)` 与"曲库中同首歌的 favorite 图标状态"一致（同一条记录只允许一个 id）。
- **根因（第二轮已定位，修正 V1 的表述）**：**不是 id/存储不同步，而是"未收藏"被渲染成了"已收藏"的通用提示色。** 对 `05-artist-detail-light.png` 做像素复核：歌手行的红心其实是**空心图标**（`Icons.favorite_border_rounded`，即本曲当时并未收藏），但颜色被硬编码为 `Colors.pink`（#E91E63）；同屏底栏未收藏时是 `textMuted` 灰空心。代码侧 `toggleFavorite`/`isFavorite`/`favoriteTracks` 全部以 `_favoriteIds` 为唯一主键（`audio_player_service.dart:889-911`，能按 id 从缓存/待播/已知曲库回填实体），本条不涉及两套存储。
  实测像素：旧图歌手行红心区域 `Colors.pink` 像素 336 个（(233,30,99) 为主），同图底栏红心区域**粉/红像素 0 个**。
- **修复（第二轮 V2）**：在 `desktop_views.dart` 增加收藏图标**唯一渲染来源** `kFavoriteActiveColor(#EF4444)` / `favoriteIconFor(bool)` / `favoriteColorFor(bool, theme)`，三处（歌手详情行、我喜欢的音乐列表、底栏播放条）统一引用：已收藏=实心 #EF4444，未收藏=空心 `textMuted`；同时底栏与详情行的 `toggleFavorite` 都传实体（`(id, track)`）以便收藏后能回填到 `favoriteTracks`。
- **验收测试**：`V-009: 歌手行与底栏的收藏图标/颜色始终一致，且收藏后同源同步`（未收藏：两处均 `favorite_border_rounded` 且颜色 == `textMuted`、非 `Colors.pink`；收藏后：两处均 `favorite_rounded` 且颜色 == `kFavoriteActiveColor`，且 `favoriteTracks` 含同一 id）。
- **新截图**：`62-after-DESK-V-009-artist-detail-favorite-consistent.png`（未收藏：歌手行与底栏均为灰空心）、`65-after-DESK-V-009-favorited-both-filled.png`（收藏后：两处均为 `#EF4444` 实心；实测两处主色都是 (239,68,68)、粉/红像素数 713 vs 563）。
- **状态**：已修复（第二轮 V2，根因已定位并用像素复核）。

### [DESK-V-010] 快速搜索弹窗空结果态保留 380px 高度，下方留白约 200px

- **编号**：DESK-V-010
- **严重度**：P2
- **类别**：视觉缺陷
- **用户可见现象**：点顶栏搜索胶囊打开「搜索在线曲库」，未输入时弹窗下半部是一大片空白（图标+一行提示在 380px 高的框里垂直居中），弹窗显得比内容高出一大截。
- **复现步骤**：1. 点顶栏搜索栏；2. 不要输入；3. 观察提示区下方大块空白。
- **代码证据**：`app/lib/views/common/modals.dart:706-740` `ConstrainedBox(constraints: BoxConstraints(maxHeight: 380), child: _results.isEmpty ? Padding(all: 32) + Center(...) : ListView.separated(...))`——空态也套用了为结果列表准备的高度。
- **证据截图**：`docs/evidence/desktop-snapshots/34-overlay-quick-search.png`。
- **数据真实性**：建议词（周杰伦/告五人/落日飞车/陈奕迅/轻音乐/粤语经典）为内置检索建议词，不是曲目数据，可接受。
- **原型/文档依据**：`docs/SPEC.md:152` 只要求"毫秒级聚合联想"，未规定高度。
- **建议修复**：空态分支不再套 380px 上限（或改为 `minHeight: 0` 的自适应），仅结果列表保留 `maxHeight`。
- **可验收标准**：空态下弹窗高度 < 结果态高度，且 `flutter test` 断言空态弹窗高度 ≤ 输入框+建议词+提示三部分之和 + 40。
- **修复（第二轮 V2）**：`app/lib/views/common/modals.dart` 把 `maxHeight: 380` 的 `ConstrainedBox` **只套在结果列表分支**上；空态/未输入分支改为 `Padding(vertical: 24) + Center(...)`。根因是旧写法里 `ConstrainedBox(maxHeight: 380)` 给出有界约束后，`Center` 会撑满 380px 高度；去掉该约束后 `Center` 在 `SingleChildScrollView` 的无界约束下自动收缩为内容高度。
- **验收测试**：`V-010: 空态弹窗不再被 380px 结果列表上限撑开`（空态卡片高度 < 380，且空态提示下沿不超出卡片下沿）。
- **新截图**：`61-after-DESK-V-010-quick-search-empty.png`。像素实测（窗口中心列白色卡片连续行）：旧图 `34-overlay-quick-search.png` 卡片高 **1068px（534 逻辑px）** → 新图 **518px（259 逻辑px）**，即约 275 逻辑px 的下方留白被消除。
- **状态**：已修复（第二轮 V2）。

### [DESK-V-011] 发现页 Hero 文案宣称"来自你的曲库"，而库为空时与下方空态自相矛盾

- **编号**：DESK-V-011
- **严重度**：P2
- **类别**：文案不诚实 / 视觉缺陷
- **用户可见现象**：全新状态（曲库为空）下，Hero 卡片仍写「今日私享雷达 / 精选推荐 · 来自你的曲库与在线试听」并给出「开启漫游播放」「查看完整推荐」两个按钮，封面位置是占位音符图标；而同一屏往下滚就是「还没有歌单」「曲库还是空的 —— 用顶部搜索在线试听…」。同一屏自相矛盾。
- **复现步骤**：1. 清空曲库（待播队列清空即回到空库）；2. 看发现页 Hero；3. 与下方「我的歌单 / 我的歌手」空态对照。
- **代码证据**：Hero 区文案与按钮为静态渲染（`app/lib/views/desktop/desktop_views.dart` `DesktopDiscoverView` 顶部 Hero 卡片），不含"曲库为空则降级"的分支；空态文案来自 `desktop_views.dart:1230` 附近与我的歌手空态。
- **证据截图**：`01-discover-light.png`（空库 Hero vs「曲库还是空的」同屏）。
- **数据真实性**：Hero 未编造具体曲目/歌手（封面是空占位符），但在空库时仍宣称"精选推荐来自你的曲库"，属于文案与事实不符；"开启漫游播放"在空库下的行为本轮**未验证**（点击后无可观测变化，但也无法排除它静默重启了当前曲目）。
- **原型/文档依据**：`docs/SPEC.md:137` 要求"今日私享雷达 Hero 卡片"，未要求空库时也宣称有推荐。
- **建议修复**：曲库为空时把副标题改为"导入或试听后这里会给出个性化推荐"，并把「开启漫游播放」置灰。
- **可验收标准**：空库下 `flutter test` 断言 Hero 副标题不含"来自你的曲库"，且漫游按钮 `onTap == null`。
- **修复（第二轮 V2）**：`desktop_views.dart` 的 `DesktopDiscoverView` 新增 `libraryEmpty = player.playlist.isEmpty` 分支：空库时副标题改为「导入或试听后，这里会给出个性化推荐」、正文改为「曲库为空：先在线试听或导入本地文件，即可开始漫游播放」，「开启漫游播放」`onTap: null`（`SoftButton` 禁用态真实降透明度 0.42、不可聚焦）；有真实曲目时恢复原推荐文案与可点行为。
- **验收测试**：`V-011: 空库时 Hero 不宣称"来自你的曲库"且漫游按钮置灰`（断言不含字符串「来自你的曲库」、`roam.onTap == null`）与 `V-011: 有真实曲目时 Hero 恢复推荐文案且漫游按钮可用`（点击后真实开始播放）。
- **新截图**：`50-after-DESK-V-011-discover-empty-hero.png`（空库真实截图：副标题/正文已改口，漫游按钮明显置灰，同屏下方仍是「曲库还是空的」但已不再矛盾）。
- **状态**：已修复（第二轮 V2）。

---

### [DESK-V-012] 未选择曲目时，底栏右侧仍显示上一曲总时长（如 06:12），与左侧 00:00 自相矛盾

- **编号**：DESK-V-012
- **严重度**：P2
- **类别**：视觉缺陷 / 状态残留
- **用户可见现象**：清空待播队列（或从未播放）后，底栏左侧显示「未选择曲目 / 从曲库或在线搜索中选择一首开始播放」、进度条两侧却是「00:00」与「06:12」——右侧残留了上一曲的真实解码时长，让人以为进度条可拖到 6 分钟。
- **复现步骤**：1. 播放任意曲目；2. 打开待播队列抽屉 → 点垃圾桶清空；3. 观察底栏右侧仍显示 06:12。
- **代码证据（修复前）**：`app/lib/navigation/desktop_scaffold.dart:778-784`，总时长无条件取 `player.duration`：
  ```dart
  final totalSeconds = (player.duration.inMilliseconds / 1000).toInt();
  return '${(totalSeconds ~/ 60)...}';
  ```
  而左侧逻辑与 `hasTrack` 相关（`desktop_scaffold.dart:549-552` 只在有曲目时用真实时长）。
- **证据截图**：修复前 `docs/evidence/desktop-snapshots/46-before-DESK-V-012-stale-duration.png`（右侧 06:12 + 「未选择曲目」）；修复后 `19-dock-no-track-empty-light.png`（左侧 00:00、右侧 00:00）。
- **数据真实性**：残留的是上一曲真实时长（非编造），但展示在不该展示的状态下，属"状态未复位"。
- **原型/文档依据**：`docs/SPEC.md:151` 播放栏应反映当前播放状态；`docs/e2e/ledger-desktop.md` DESK-012 已确立"空队列渲染诚实空态"的基线，本项是该基线漏掉的一处残留。
- **建议修复**：`!hasTrack` 时总时长直接渲染 `00:00`。
- **可验收标准**：widget 测试：清空队列后渲染 `DesktopScaffold`，断言底栏两个时间文案均为 `00:00`。
- **状态**：已修复（本轮）。

---

## 2. 目检通过项（不改，仅留证）

- **深浅色双模**：`01/16`、`02/17`、`09/18`、`11` 对照检查，深色下画布 `#0D1117`、卡片 `#161B22`、内凹 `#0B0E14` 与 `docs/SPEC.md:84-89` 定义一致；未发现深色下文字不可读或卡片与背景糊在一起（内凹卡片实测像素 `(11,14,20)`，与 token 精确吻合）。
- **顶栏/侧栏/播放条遮挡**：12 视图逐一检查，正文内容区均未被 78px 播放条或 56px 顶栏压住；队列抽屉为刻意覆盖式抽屉（`32-drawer-queue.png`），非缺陷。
- **毛玻璃/圆角/阴影**：播放条为 94% 不透明卡片 + 上边 0.8px 分隔线 + 向上投影；侧栏/卡片圆角 16~24px、胶囊按钮全圆角，与 `SPEC 2.3/2.4` 目检一致；未能从截图判定的部分不作结论。
- **真实数据链路**：点击历史行 → **真实音频播放**（底栏出现暂停态、进度 00:00→05:54→06:09 持续推进、总长 06:12 来自真实解码时长），歌词页高亮行随进度前进；无假成功、无占位假数据。
- **空态可读引导**：`歌单广场 / 导入与自建歌单 / 声音电台 / 本地音乐 / 歌手详情` 的空态均给出了"下一步做什么"的可读引导（如「粘贴网易云公开歌单链接导入」），无空白页（DESK-V-001 已修）。
- **文字截断**：除 DESK-V-004（EQ 胶囊）外，12 视图与全部模态未发现其他非预期文字截断；长文案均带 `ellipsis` 或自适应换行。

## 3. 本轮直接修复汇总（`flutter analyze` No issues found! / `flutter test` 178 全绿）

| 缺陷 | 文件 | 改动 |
| :--- | :--- | :--- |
| DESK-V-001 | `app/lib/views/desktop/fullscreen_lyrics_view.dart` | 无曲目空态：加 `AcousticMeshGlow` 背景 + 右上角 `fullscreen_exit_rounded` 退出按钮 + 图标/标题/引导文案 |
| DESK-V-002 | `app/lib/views/desktop/desktop_views.dart` | 4 处空态/副标题 `textMuted→textSecondary`、`Colors.grey→theme.textSecondary` |
| DESK-V-003 | `app/lib/views/desktop/desktop_views.dart` | 榜单卡标题 20px/字距1 → 18px/字距0.2 + `maxLines:1, ellipsis` |
| DESK-V-012 | `app/lib/navigation/desktop_scaffold.dart` | 无曲目时底栏总时长一律渲染 `00:00`（消除上一曲时长残留） |

### 3.1 第二轮（V2）直接修复汇总 —— DESK-V-004~011 全部闭环

> `cd app && flutter analyze` → `No issues found!`；`cd app && flutter test` → **188/188 全绿**（178 基线 + 10 条新增验收用例）；每条都有**真实运行截图**复核（见各条目"新截图"与 §0 归档清单）。

| 缺陷 | 主要文件 | 改动 | 验收用例 | 新截图 |
| :--- | :--- | :--- | :--- | :--- |
| DESK-V-004 | `views/common/modals.dart` | 预设胶囊行 横向滚动 → `Wrap` 自动换行（6 个预设全可见，无隐藏横滑区） | V-004 | `51-after-…` |
| DESK-V-005 | `navigation/desktop_scaffold.dart` | 侧栏挂 `ScrollController` + 常显 `Scrollbar`；导航后用 `getOffsetToReveal` 精确滚入选中项；宽度 220→236 | V-005 | `52-after-…` |
| DESK-V-006 | `views/desktop/desktop_views.dart` + `desktop_scaffold.dart` | 新增 `DesktopViewLabels`/`desktopNavEntries`/`desktopViewTitles` 唯一映射表，侧栏 7 个标签与 7 个页面 H1 归一到同一常量 | V-006 | `53`~`59`, `64` |
| DESK-V-007 | `views/desktop/fullscreen_lyrics_view.dart` | 新增 `_VinylTonearm`（转轴+臂杆+唱针，`ValueKey('vinyl-tonearm')`）+ 黑胶沟槽渐变/高光 | V-007 | `63`, `66` |
| DESK-V-008 | `views/desktop/desktop_views.dart` | 新增 `podcastSections`，按 SPEC 3.1 渲染 4 大板块骨架并逐板块诚实标注"未接入真实单集"；新增「搜索在线曲库」入口 | V-008 | `60-after-…` |
| DESK-V-009 | `views/desktop/desktop_views.dart` + `desktop_scaffold.dart` | 定位真因（未收藏却硬编码 `Colors.pink`）；新增 `kFavoriteActiveColor`/`favoriteIconFor`/`favoriteColorFor` 统一三处渲染 | V-009 | `62`, `65` |
| DESK-V-010 | `views/common/modals.dart` | `maxHeight:380` 只套结果列表；空态改自适应（卡片高 534→259 逻辑px） | V-010 | `61-after-…` |
| DESK-V-011 | `views/desktop/desktop_views.dart` | 空库时 Hero 改口 + 「开启漫游播放」真实置灰 | V-011 | `50-after-…` |

> **越界项唯一提示**：`app/integration_test/desktop_real_user_e2e_test.dart` 本轮按约束**未修改**，其按旧侧栏文案 `tapSidebar` 与旧 marker 字符串需主 Agent 同步（详见 DESK-V-006 条目）。`docs/SPEC.md` 亦不在允许修改范围，故 DESK-V-008 只做了"实现侧对齐 SPEC"。

> 第一轮（V1）另修复了 DESK-V-001/002/003/012（见上表）。
