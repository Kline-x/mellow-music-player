# PC 端「用户视角」E2E 验收 · 第二轮缺陷修复的独立验收记录

> ⚠️ **历史过程快照声明**：本文档为针对 commit `327d35b` 的历史验收过程快照。后续在 `669f9a0` 及后续提交中已完成 P0-2 架构级根除、README 展示图恢复与全量复核。最新二次复核验收结论请参阅：`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_FIX_RECHECK_2026-09-26.md`。
> 验收日期：2026-09-26 01:40 CST
> 验收对象：commit `327d35b`（2026-09-26 01:30，"闭环输入法空格与默认收藏修复，完成第二轮E2E复验缺陷清零并彻底删除所有截图文件"）及其同批文档修订（`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_2026-09-25.md`、`docs/PROGRESS.md`）
> 上游依据：`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_VERIFICATION_2026-09-26.md` 的待修复清单（A 交付物 / B 产品缺陷 / C 仓库卫生）
> 验收方：DSH 会话 `session-2d780725`（独立于修复实施方）
> 验收方式：**独立复跑质量门禁** + 逐条回代码核对 + git 层核对删除影响面 + 钉住每条问题的 file:line
> 判定标记：✅ **已修复并复核**｜❌ **未修复或口径不成立**｜⚠️ **部分修复／无法验证**｜🆕 **本次新增问题**

---

## 0. 验收结论

**不通过（不能判定为"缺陷清零"）。**

- **实测可信的部分**：质量门禁是真的——本次独立跑出 `flutter analyze` 干净、`flutter test` **196/196 全绿**（192 + 4 个新增测试，数目吻合）；**P0-1 快捷键焦点丢失是真修复**，实现方式正是上一轮建议的 `Shortcuts`+`Actions`，且带回归测试。
- **未通过的原因**：**P0-2「编造 CDN 直链」在结构上没有修复**（只给假域名改名 + 加了一份只含两个旧域名的黑名单，三条泄漏路径仍在，且测试仍把假直链断言为正确行为）；**P1-3 是假接线**（只 `debugPrint`，后端根本没有 DSP 接口）；**P2-1 只是改名**。此外 **A1 收口过度**：为删 2 张黑帧而删除 102 个文件 / 67.1 MB，导致 README 8 张图片断链、7 份文档出现悬空引用、第二轮报告的"67 张证据"指向空目录。
- 逐条判定见 §1，问题详情见 §3，待修复清单见 §4。

---

## 1. 待修复清单逐条验收

### A. 交付物收口

| 编号 | 事项 | 判定 | 依据 |
| :--- | :--- | :---: | :--- |
| A1 | 删除 2 张纯黑废帧 | ⚠️ **做过头并产生新回归** | 实际删除 **102 个文件 / 67.1 MB**（含 `docs/evidence/**` 全部与 `public/*.png`），并新增 `.gitignore:19-20` 忽略 `docs/evidence/`、`evidence/`（§3.1） |
| A2 | 报告"69 张"与 §6 清单自洽 | ✅ | 报告第 5 行与 §6 已改为"67 张有效截图" |
| A3 | 补像素度量口径 + 修正落款 | ✅ | 报告第 6 行新增"灰度差 >8 / >24 + 上 75% 页面区 / 下 180px 播放栏"；落款改为 `21:15–00:13 CST` |
| A4 | P1-4 措辞改为"仅测试在断言" | ⚠️ 改对后又被改假 | 报告第 32 行已按 A4 改；但同一提交给 `toLibmpvFilterString()` 加了一个 lib 调用者，该行**再次失实**（§3.3） |
| A5 | 修正 `online_music_service.dart` 行号 | ✅ | 报告第 29 行已改为 `:462 / 508 / 528 / 548 / 580` |
| A6 | `PROGRESS.md` 补第二轮记录 | ✅ | 新增章节 `## 2026-09-26 · PC 端「用户视角」E2E 验收第二轮复核问题全面收口与缺陷清零`（`PROGRESS.md:266`） |

### B. 产品缺陷

| 编号 | 事项 | 判定 | 依据 |
| :--- | :--- | :---: | :--- |
| P0-1 | 全局快捷键焦点丢失 | ✅ **真修复** | `CallbackShortcuts` → 自研 `ContextAwareShortcuts`（`Shortcuts.manager`+`Actions`）；新增 `_rootFocusNode` 并在 `_navigateTo/_goBack/_goForward` 后复位、空白点击复位、搜索页 dispose 时 `unfocus`；新增回归测试（§2） |
| P0-2 | LX 预设音源编造 CDN 直链 | ❌ **未修复** | 假域名只是改名（`:459` → `stream.internal.testing`），黑名单只含 `music.net`/`custom-cdn`；mellow 分支仍无条件返回已知编造域名 `stream.mellowmusic.io`（`:211`）；`:795` 的 `custom-cdn` 原样保留；测试仍在断言假直链（§3.2） |
| P1-3 | EQ 未接线 | ❌ **假接线** | 新增 `_onEqualizerChanged`（`audio_player_service.dart:171`）内部只有 `debugPrint`；`player_backend.dart` 中 `filter|equalizer|dsp` 命中数 **0**（§3.3） |
| P1-4 | 悬浮歌词胶囊遮挡 | ⚠️ 代码有改动、**无可验证证据** | 默认坐标 `(280,520)` → `(360,60)`，新增 `onPanUpdate` 拖动（仅未锁定时）；但证据目录已整体删除，无任何截图可判定（§3.4） |
| P1-5 | README 178 / PROGRESS 192 口径打架 | ✅ | 统一为"**196 项**"（`README.md:9,17`） |
| P1-6 | 搜索触底「加载更多」未验完 | ⚠️ **仍未验** | 无新增用例、无证据（证据已删） |
| P2-1 | 电台数据仍为 mock | ❌ **仅改名** | `presetRadioStations` + 兼容 getter `mockRadioStations`（`track_model.dart:998`），生产调用点仍用 mock 名（`desktop_views.dart:1668`、`mobile_pages.dart:382`、`track_model.dart:1121`），数据仍是写死预设（§3.5） |
| P2-2 | 集成测试 seek 竞态 | ⚠️ **收窄未消除** | `_hasSource` 在 `play()` 中 `await` 之前即置 `true`，prepare 期间的 seek 仍会进入 `catch`（§3.6） |
| P2-3 | E2E 属"有条件门禁" | ✅ | `README.md:112-118` 已写明必须先起 `node server.cjs`（8088），否则 `ERR_CONNECTION_REFUSED`（本次未复跑 e2e） |

### C. 仓库卫生

| 编号 | 事项 | 判定 | 依据 |
| :--- | :--- | :---: | :--- |
| C1 | `app/pubspec.lock` 164 行 churn | ✅ | 未进入该提交，工作树 `git status` 干净 |
| C2 | 6 个受控 `public/*.png` 被 e2e 覆盖 | ❌ **改为整体删除** | 连带删掉 README 依赖的展示图，README 第 31/35/40 行 8 张图片全部断链（§3.1） |
| C3 | 固化"跑完 integration_test 必须重建" | ✅ | `README.md:151` 已加避坑提示 |
| C4 | 证据目录对 git 不可见 | ⚠️ **改为显式忽略** | `.gitignore:19-20` 新增 `docs/evidence/`、`evidence/`；策略上等于"证据永久不入库"，但报告 §6 仍指向该目录（§3.1） |

### 其他（本次提交顺带做的改动）

| 事项 | 判定 | 依据 |
| :--- | :--- | :--- |
| 清空"我喜欢的音乐"硬编码 4 首 | ✅ 真改动 | `_favoriteIds = {}`（`audio_player_service.dart`），并新增空集合断言 |
| UI 剔除 `mellow` / `lx_official_builtin` | ✅ 真改动 | `desktop_views.dart:3438`、`modals.dart` 删除卡片；两个旧用例同步改为 `findsNothing` |
| integration test 隔离修复 | ✅ | `app_client_e2e_test.dart` 在禁用 `kg` 后补回 `setSourceEnabled('kg', true)` |
| 新增"输入态感知"快捷键（IME 空格） | ✅ 代码存在 | `ContextAwareShortcutManager.handleKeypress`：焦点在 `EditableText` 时放行无修饰单键 |

---

## 2. 本次独立复跑门禁（可信）

```bash
cd app && flutter analyze && flutter test
```

- `flutter analyze` → **No issues found! (ran in 6.6s)**（0 error / 0 warning）
- `flutter test` → **`00:59 +196: All tests passed!`**（退出码 0）
- 测试数对账：上一轮基线 `674b43d` 的 PROGRESS 写 `192/192`，本次新增 4 个用例（`app/test/user_e2e_14_issues_test.dart` 中 `^+\s*test(Widgets)?\(` 命中 4），192 + 4 = **196** ✓
- 结论：**"196 项测试 100% 通过"这一句属实**。但注意——全绿**不能**证明 P0-2 已修复，因为测试里仍有一条把假直链断言为正确行为的用例（§3.2 e）。

---

## 3. 问题清单（详情）

### 3.1 🆕 A1 收口过度：删证据 → 断链 + 悬空引用

**事实**（`git show --name-status 327d35b`）：

- 删除 `docs/evidence/**` 与 `public/*.png` 共 **102 个文件**；按 `674b43d` 树统计 **67.1 MB**；
- `.gitignore` 新增第 19-20 行 `docs/evidence/`、`evidence/`；
- 该提交的说明把这一步记为"彻底清理删除仓库内所有历史证据截图与图片，大幅轻量化仓库体积"。

**后果**：

1. **README 8 张本地图片全部断链**（文件已不存在）：`README.md:31`（`e2e_flutter_desktop_verified.png`、`e2e_flutter_desktop_toplist.png`）、`:35`（`e2e_flutter_desktop_sync.png`、`showcase_mobile_eq.png`）、`:40`（`e2e_mobile_verified.png`、`showcase_mobile_fm.png`、`showcase_mobile_artist.png`、`showcase_mobile_local.png`）。
2. **第二轮报告 §6 指向空目录**：报告称"`docs/evidence/pc-user-acceptance-round2/`，共 67 张有效截图"，该目录已不存在 → 报告的核心证据链**无法自证**。
3. **7 份文档出现悬空引用**：`PC_E2E_ACCEPTANCE_ISSUES.md`、`PC_E2E_FIX_PLAN.md`、`PC_NATIVE_E2E_ACCEPTANCE_2026-09-25.md`、`PC_USER_E2E_ACCEPTANCE_2026-09-25.md`、`PC_USER_E2E_ACCEPTANCE_2026-09-25_VERIFICATION.md`、`PC_USER_E2E_ACCEPTANCE_ROUND2_2026-09-25.md`，以及 `PC_USER_E2E_ACCEPTANCE_ROUND2_VERIFICATION_2026-09-26.md`（本清单的上游文档，其 §3.3/§5-A1 已失效）。
4. 上一轮"待修复清单 A1"的原意只是**删掉 2 张纯黑废帧**；`C2` 的原意是**确认 `public/*.png` 是否有意刷新/回滚**，不是删除。

**建议**：`git checkout 674b43d -- public/` 恢复 README 依赖的图片（或删除 README 中对应图片行）；对证据清理二选一并落到文档里——(a) 回滚 `docs/evidence` 保留历史证据；(b) 保留删除，但在 README 与所有验收报告中显式注明"历史证据已按 `327d35b` 移出仓库，不在本仓库分发"，避免文档指向空目录。

### 3.2 ❌ P0-2「编造 CDN 直链」未修复（本轮最严重）

**(a) 只是改了个名字。** `app/lib/core/sources/lx_script_sandbox.dart:459`：

```dart
// 平台预设驱动仅在单元与降级测试中返回内部测试直链，生产网络由落雪标杆源驱动
return 'https://stream.internal.testing/$platformId/${targetSong.songMid}_${quality.value}.mp3';
```

仍是不可解析的自造域名；注释里的"仅在单元与降级测试中"**没有任何代码强制**——`_initializeDefaultDrivers()` 在生产把 `kw/kg/tx/wy/mg` 五个 `PlatformPresetSourceDriver` 全部注册，UI 也只过滤了 `mellow`/`lx_official_builtin`，这五个仍然可见可选（新增用例还断言 `酷我音乐/QQ音乐/网易云音乐` 必须可见）。

**(b) 黑名单与新域名不匹配，新占位域名直接放行。** 五处守卫（`online_music_service.dart:466/514/536/556/588`）仍是：

```dart
if (res.url.isNotEmpty && !res.url.contains('music.net') && !res.url.contains('custom-cdn')) { ... }
```

`stream.internal.testing` **不在这两个子串里** → 守卫失效。修假直链的思路从"清除假实现"退化成了"打域名黑名单"，且这次改动还**把假链从一个被拉黑的域名搬到了一个不被拉黑的域名**。

**(c) mellow 分支无条件泄漏已知编造域名。** `online_music_service.dart:540-559`（方法 `resolveUrlFromSpecificSource`）：

- 条件 `targetSource.contains('mellow') || targetSource.contains('preset')`；
- 预设曲库 `mockPresetTracks` 的 `source` 就是 `'preset-flac'` / `'preset-320k'`（`track_model.dart:119/141/161/183/203`）→ **该分支是常规路径**；
- 分支内 `resolveMusicUrlWithFallback(sourceId: LxPlatformId.mellow, enableSourceFallback: true)` → 主源 mellow 的 `getMusicUrl` 返回 `lx_script_sandbox.dart:211`：
  ```dart
  return 'https://stream.mellowmusic.io/${song.source}/${song.songMid}/audio_$qTag.flac';
  ```
- 该 URL 非空即被判定为"解析成功"返回 → 守卫放行 → **假 URL 交给播放器**；
- 而这个域名**早在仓库自己的审计文档里被判为编造**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:888`（H-04）"域名全部编造（另有 `cdn.<platform>.music.net`、`custom-cdn.<id>.com`），无真实 CDN"。**本次提交没有改它，也没有把它加进黑名单。**

**(d) 降级链会落到预设驱动。** `resolveMusicUrlWithFallback` 的候选列表 = 主源 + **所有 enabled 驱动**；`isEnabled` 默认为 `true`（`lx_source_model.dart:131`）。因此当 `lx_sixyin/lx_huibq/lx_ikun` 取不到流时，链会走到 `kw/kg/tx/wy/mg` 预设驱动并返回 `stream.internal.testing`，同样被守卫放行（`enableSourceFallback` 还从 `false` 全部改成了 `true`，等于**扩大了**这条路径的触发概率）。

**(e) 测试仍在替假实现背书。** `app/test/lx_source_engine_test.dart:257`：

```dart
expect(url.url, contains('custom-cdn.six_custom_01.com'));
```

即"自定义音源返回编造假直链"被写成**期望行为**，所以 196/196 全绿与 P0-2 是否修复无关。同时 `:795` 的 `custom-cdn.${metadata.id}.com` 构造器原样保留。

**建议（正确做法）**：让 `PlatformPresetSourceDriver` 与 `MellowPresetSourceDriver` 在生产环境直接返回 `null`（或仅在测试注册这两个驱动），把假直链断言从 `lx_source_engine_test.dart` 删除；下游守卫改为"按驱动类型/是否真实源"判定，而不是维护域名黑名单。

### 3.3 ❌ P1-3 是假接线，且使 A4 的措辞重新失实

`app/lib/core/audio/audio_player_service.dart:167-175`：

```dart
void _initEqualizerListener() {
  EqualizerManager.instance.addListener(_onEqualizerChanged);
}

void _onEqualizerChanged() {
  final eq = EqualizerManager.instance;
  final filterStr = eq.toLibmpvFilterString();
  if (kDebugMode && filterStr.isNotEmpty) {
    debugPrint('[AudioPlayerService] 声学 DSP 10 频段 EQ 滤镜参数更新: $filterStr');
  }
}
```

- 除了 `debugPrint`，**没有任何消费者**；`player_backend.dart` 中 `filter|equalizer|dsp` 命中数为 **0**，即后端根本没有可接收滤镜参数的接口。所以"监听 EqualizerManager 联动声学 DSP 滤镜参数调度"实际等于"把字符串打到调试日志"，**EQ 对听感依旧无影响**。
- 该改动让 `toLibmpvFilterString` 第一次有了 `app/lib` 调用者，于是报告第 32 行"生产代码 `app/lib` 内无调用者，仅 `app/test` 两处在断言"**重新变成不实陈述**。
- 附带定案（修正第二轮报告的一处误读）：`EqualizerPreset` 共 **9** 个枚举值，含 `spatial3d('全景声场 (Spatial 3D)')`（`equalizer_manager.dart:10`），弹窗用 `EqualizerPreset.values.map` **全量渲染**（`modals.dart:245`，横向可滚动）。因此报告"预设由 5 个减为 4 个（原型的「空间 3D」不存在）"是**横向视口截断造成的误读**；而 PROGRESS 里"对齐「空间 3D (Spatial 3D)」10 频段增益"在本次提交中**对应零改动**（`equalizer_manager.dart` 未被该提交修改）。
- **建议**：要么给后端加真正的滤镜/音效接口并接线，要么把 PROGRESS 与报告改回"仅文案诚实化、功能未接入"的口径。

### 3.4 ⚠️ P1-4 / P1-6 无可验证证据

- P1-4 代码改动存在（默认坐标 `Offset(360,60)`、卡片整体 `onPanUpdate` 拖动、仅未锁定时可拖），但因证据目录整体删除，**没有任何截图可供判定"是否仍遮挡"**；另外 PROGRESS 写"保证冷启动默认关闭"，而代码里 `_isFloatingLyricEnabled = ... ?? false`（`desktop_scaffold.dart:101-102`）本来就是默认关——与第二轮报告"默认开启"的描述相矛盾，说明该现象的原始描述本身存疑。
- P1-6「加载更多」无新增用例、无实测记录。

### 3.5 ❌ P2-1 只是改名，mock 事实未变

`track_model.dart:901` 定义 `presetRadioStations`，`:998` 又给出兼容 getter `mockRadioStations`；生产调用点仍用 mock 名（`desktop_views.dart:1668`、`mobile_pages.dart:382`、`track_model.dart:1121`）。数据本身仍是写死的预设电台列表，不涉及任何真实数据源。改名不影响"数据是 mock"这一事实，也未消除代码里的 `mock` 命名。

### 3.6 ⚠️ P2-2 只是收窄

`player_backend.dart`：`play()` 中先 `_hasSource = true` 再 `await _player.play(...)`，`seek()` 仅在该标志为 false 时提前返回。因此只能挡掉"从未 play 过就 seek"，**prepare 期间（play 已开始、尚未就绪）的 seek 仍会进入 `catch`**，日志里的 `seek exception handled` 仍可能出现。方向正确，但不是"消除"。

### 3.7 🆕 文档口径互相矛盾

同一提交里三处说法不一致：

| 位置 | 说法 | 实际情况 |
| :--- | :--- | :--- |
| 第二轮报告第 29 行 | P0-3b ❌ **未修复** | 与本次代码核查一致（仍成立） |
| `PROGRESS.md:266+` | P0-2"**彻底**清理…彻底消灭物理 404 死链"、"已解决" | 与代码不符（§3.2） |
| 第二轮报告第 32 行 | EQ"生产代码 `app/lib` 内无调用者" | 已被本次提交改假（§3.3） |
| `PROGRESS.md:266+` | "生产代码实时消费 `toLibmpvFilterString()` 调度声学 DSP" | 实际仅 `debugPrint`（§3.3） |

建议：报告作为"修复前快照"保留原判，但加一行状态指针（"修复状态与结论更新见 PROGRESS 2026-09-26 章节及本文档"）；PROGRESS 的措辞按实际实现收敛。

### 3.8 🆕 新增回归测试存在"静默空转"风险

`app/test/user_e2e_14_issues_test.dart` 的 P0-1 用例中，关键步骤被条件包住：

```dart
final searchNav = find.text('全网搜索');
if (searchNav.evaluate().isNotEmpty) { await tester.tap(searchNav); ... }
```

若导航文案变更或未渲染，用例会**跳过关键步骤仍然通过**，无法起到回归保护作用。建议改为硬断言（`expect(find.text('全网搜索'), findsOneWidget)` 后再点）。

---

## 4. 待修复清单（下一轮）

### A. 仓库与交付物

- **A1'** 恢复 README 依赖的展示图：`git checkout 674b43d -- public/e2e_flutter_desktop_verified.png public/e2e_flutter_desktop_toplist.png public/e2e_flutter_desktop_sync.png public/showcase_mobile_eq.png public/e2e_mobile_verified.png public/showcase_mobile_fm.png public/showcase_mobile_artist.png public/showcase_mobile_local.png`（或删掉 README 第 31/35/40 行的图片引用）
- **A2'** 对"删除全部证据"做书面决定：要么回滚，要么在 README + 7 份引用文档中标注"历史证据已移出仓库"，并修正第二轮报告 §6 指向空目录的问题
- **A3'** 收紧 `.gitignore` 新增的 `docs/evidence/`：若未来仍要留存证据，需保留 `git add -f` 通道并在文档中写明

### B. 产品缺陷

- **P0-2'（最高优先）** 让两个预设驱动在生产返回 `null`；删除 `lx_source_engine_test.dart:257` 的假直链断言；守卫改为按驱动类型判定，而非域名黑名单；评估 `stream.mellowmusic.io`（已知编造）与 `custom-cdn.*` 的彻底清除
- **P1-3'** 真接线（后端支持滤镜）或回退口径；同步修正报告第 32 行与 PROGRESS 描述
- **P1-4' / P1-6'** 补一次真实 GUI 实测并留证（触底"加载更多"、胶囊遮挡与拖动）
- **P2-1'** 清理生产代码里的 `mockRadioStations` 调用点（或明确保留理由）；若目标是"无假数据"，需替换为真实电台数据源
- **P2-2'** 把 seek 守卫下沉到"后端就绪"状态（真实播放状态事件），而非 `play()` 入口的布尔量

### C. 流程与文档

- **C1'** 统一报告 / PROGRESS 的状态口径（§3.7）
- **C2'** P0-1 回归测试改为硬断言（§3.8）
- **C3'** 修正第二轮报告"EQ 预设 5→4 / 空间 3D 不存在"的误读（实为 9 个预设、横向滚动）

---

## 5. 复核锚点（可重跑）

```bash
cd "$(git rev-parse --show-toplevel)"

# 1) 门禁（本次实测：analyze 干净、+196 全过）
cd app && flutter analyze && flutter test; cd ..

# 2) P0-2：假域名 / 黑名单 / 预设驱动注册
grep -n "stream.internal.testing\|stream.mellowmusic.io\|custom-cdn" app/lib/core/sources/lx_script_sandbox.dart
grep -n "contains('music.net')" app/lib/core/sources/online_music_service.dart
sed -n '/void _initializeDefaultDrivers/,/^  }/p' app/lib/core/sources/lx_script_sandbox.dart | grep -n "registerDriver"
grep -n "source: 'preset" app/lib/core/audio/track_model.dart
grep -n "custom-cdn" app/test/lx_source_engine_test.dart

# 3) P1-3：EQ 是否真的接线
sed -n '160,180p' app/lib/core/audio/audio_player_service.dart
grep -cE "filter|equalizer|dsp" app/lib/core/audio/player_backend.dart   # 期望 0 = 未接线

# 4) A1：删除影响面
git show --name-status --format='' 327d35b | grep -cE '^D.*\.png$'
git ls-tree -r --long 674b43d -- docs/evidence public | awk '{s+=$4; n++} END {printf "files=%d size=%.1f MB\n", n, s/1048576}'
grep -rln "docs/evidence" docs/*.md | wc -l
```

---

## 6. 诚实边界

1. **未复跑**：macOS 集成测试 `9/9`（需真机 GUI）与 Puppeteer `83/83`（需自备 8088 服务）。本次只独立复跑了 `flutter analyze` 与 `flutter test`。
2. **未做 GUI 实测**：P1-4（胶囊遮挡）、P1-6（加载更多）无法在本会话判定；且证据已被删除，无法回溯比对。
3. **未核查**：Windows 真机、移动端、Web 端；`lx_sixyin/lx_huibq/lx_ikun` 三个"真实源"的实际可达性未联网验证（仅依据代码路径判断"假直链仍可返回"）。
4. 判定基于 **2026-09-26 01:40 CST、HEAD `327d35b`、工作树干净**的快照。

---

## 7. 本次记录对仓库的改动

- **新增**：本文件 `docs/PC_USER_E2E_ACCEPTANCE_ROUND2_FIX_VERIFICATION_2026-09-26.md`
- **未改动**：代码、`README.md`、`PROGRESS.md`、既有验收报告与证据（全程只读；§4 的修复动作未执行）

---

*验收方：DSH 会话 `session-2d780725`（工作区 mellow-music-player）｜2026-09-26 01:40 CST*
