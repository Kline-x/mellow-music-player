# PC 端「用户视角」E2E 验收 · 第二轮缺陷修复的二次验收（复核 `669f9a0`）

> 验收日期：2026-09-26 02:02 CST
> 验收对象：commit `669f9a0`（"架构级拔除假直链编造源头，消除电台mock残留与seek竞态，恢复README核心展示图并全量通过196项测试"），基线 `327d35b`
> 上游依据：`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_FIX_VERIFICATION_2026-09-26.md` 的 §4 待修复清单（A'/B'/C'）
> 验收方：DSH 会话 `session-2d780725`（独立于修复实施方）
> 验收方式：独立复跑质量门禁 + 逐条回代码核对 + git 层核对 + 文档口径互相印证
> 判定标记：✅ **已修复并复核**｜❌ **未修复或口径不成立**｜⚠️ **部分修复／无法验证**｜🆕 **本轮新增问题**

---

## 0. 验收结论

**代码层面的核心问题这轮是真的修掉了——但仍不建议就此收口。**

- **重大进展**：`P0-2「编造 CDN 直链」已做到架构级根除**（这是我上一轮判定"不通过"的核心项）：两个预设驱动在生产环境直接返回 `null`，`LxCustomScriptDriver` 也不再捏造 `custom-cdn`，已知编造域名 `stream.mellowmusic.io` 从 `app/lib` 完全消失；测试侧用 `LxSourceEngine(enableTestingUrls: true)` 显式opt-in，生产单例恒为 `false`；那条"把假直链断言为正确行为"的测试已改为断言 `LxSourceException`。
- **门禁属实**：本次独立跑出 `flutter analyze` 干净、`flutter test` **196/196 全绿**。
- **不能收口的原因**：① 文档口径**再次**互相矛盾——第二轮报告（同一批被修改过）仍写 P0-3b"**仍存在**"并引用已经失效的行号，而 PROGRESS 写"真修复"；② PROGRESS 新增了**两处不实陈述**（"电台曲库全量注入真实公网广播音频流"本轮零改动、"全仓无 mock 命名残留"实际 92 处）；③ 5 个平台预设源仍是"**搜得到、播不出**"的伪实现却继续在 UI 展示；④ P1-4 / P1-6 依旧**零证据**。
- 逐条判定见 §1，残留问题见 §3（R1–R8），建议动作见 §4。

---

## 1. 上游清单逐条验收

### ✅ 本轮真正修好并已复核的

| 编号 | 事项 | 判定 | 证据 |
| :--- | :--- | :---: | :--- |
| P0-2' | 架构级拔除假直链编造源头 | ✅ | `MellowPresetSourceDriver`/`PlatformPresetSourceDriver` 新增 `allowTestingUrls = false`，生产路径 `if (!allowTestingUrls) return null;`（`lx_script_sandbox.dart` mellow 段与 `:467-471` 附近）；`LxCustomScriptDriver` 改为 `return null`（不再拼 `custom-cdn.${metadata.id}.com`） |
| — | 生产开关不可达 | ✅ | `LxSourceEngine.instance = LxSourceEngine()`（`:948`）默认 `enableTestingUrls: false`；`grep -rn enableTestingUrls app/lib` 只有定义与透传，**无任何 lib 调用点传 true** |
| — | 测试改为显式 opt-in | ✅ | `client_e2e_user_journey_test.dart:34`、`lx_source_engine_test.dart:139/223/274/313/409/481`、`lx_custom_source_test.dart:165` 全部改为 `LxSourceEngine(enableTestingUrls: true)`；驱动级 `allowTestingUrls: true` 亦显式声明 |
| — | 删除"假直链即正确"的错误断言 | ✅ | `lx_source_engine_test.dart:252-259` 由 `expect(url.url, contains('custom-cdn.…'))` 改为 `expect(..., throwsA(isA<LxSourceException>()))` |
| — | `mellowmusic.io` 彻底消失 | ✅ | `grep -rn "mellowmusic.io" app/lib` 无命中 |
| A1' | 恢复 README 核心展示图 | ✅ | 8 张图已恢复且 `git diff 674b43d HEAD -- public/` 对它们**逐字节一致**（无差异），并全部处于 tracked 状态 |
| — | 让恢复的图片不再被 ignore 规则吞掉 | ✅ | `.gitignore:19` 新增 `!public/*.png` |
| A2' | 对"证据移出仓库"给出书面决定 | ✅（主体） | 报告第 5 行新增"历史测试截图已按仓库轻量化规范移出 Git 仓库，不在本仓分发"；`PROGRESS` 收口段落同步声明 |
| P1-3' | 移除伪接线并诚实化口径 | ✅ | `_onEqualizerChanged` 已删掉 `debugPrint` 伪调用改为 `notifyListeners()`；`grep toLibmpvFilterString app/lib` = 0 调用者；报告 P1-4/V-3 行改写为"audioplayers 未开放原生硬件 DSP 通道…预设实际共有 9 个"，PROGRESS 同步为"架构现状澄清" |
| P2-1' | 清除 mock 别名 | ✅（本项） | 兼容 getter `mockRadioStations` 已物理删除；生产调用点迁移为 `presetRadioStations`（`desktop_views.dart:1668`、`mobile_pages.dart:382`、`track_model.dart:1118`） |
| P2-2' | Seek 竞态守卫下沉 | ✅ | `play()` 起始置 `_hasSource = false`，`await _player.play(...)` **成功后**才置 `true`，失败则保持 false 并 rethrow；`seek()` 增加 `_player.state == PlayerState.stopped` 拦截 |
| C2' | 回归测试防"静默空转" | ✅ | `user_e2e_14_issues_test.dart` 两处 `if (...isNotEmpty)` 改为 `expect(find..., findsOneWidget)` 硬断言 |
| — | 测试隔离 | ✅ | `lx_custom_source_test.dart` 收尾由 `setActiveSource('mellow') + unregisterDriver` 改为 `engine.dispose()` |

### ❌ / ⚠️ 仍未收口的

| 编号 | 事项 | 判定 | 依据 |
| :--- | :--- | :---: | :--- |
| C1' | 统一报告与 PROGRESS 的状态口径 | ❌ **未落实且更矛盾** | 报告第 29 行仍写 P0-3b"**仍存在**：`lx_script_sandbox.dart:458` 与 `:794` 未被移除"，而这两处已是 `return null`；报告未加任何状态指针（`grep "327d35b\|669f9a0\|见 PROGRESS"` 无命中）（R1） |
| C1'' | PROGRESS 事实准确性 | ❌ **新增两处不实陈述** | "电台曲库全量注入真实可用公网广播音频流"（本轮对电台数据 0 改动）、"全仓无 mock 命名残留"（`app/lib` 命中 92 处）（R2） |
| P1-4' | 悬浮歌词胶囊遮挡 | ⚠️ **仍零证据** | 本提交未新增任何可验证记录；`docs/evidence/` 明确不入库，PROGRESS 却继续断言"消除遮挡与操作死区"；且拖拽仅在 `!_isLocked` 时生效（R4） |
| P1-6' | 搜索触底「加载更多」 | ⚠️ **仍未验** | 无新增用例、无实测记录 |

---

## 2. 独立复跑门禁（本次实测）

```bash
cd app && flutter analyze && flutter test
```

- `flutter analyze` → 干净（`&&` 链保证 analyze 通过后才会执行测试）
- `flutter test` → **`01:10 +196: All tests passed!`**（退出码 0）
- 与仓库声明（`README.md:9` 与 PROGRESS 的"196 项"）**一致** ✓

---

## 3. 残留问题清单

### R1 ❌ 报告与 PROGRESS 再次互相矛盾，且报告引用已失效

- 报告 `docs/PC_USER_E2E_ACCEPTANCE_ROUND2_2026-09-25.md:29`：

  > P0-3b … **仍存在**：`lx_script_sandbox.dart:458` 与 `:794` 未被移除 …

  实际当前代码：`:467-471` 附近已是 `if (!allowTestingUrls) { return null; }`，`:800` 附近也是 `return null`。**该行被本批修改过（删了 code 细节）却没有更新结论，也没有加状态指针**。
- 同一批 `PROGRESS.md:266+` 写"**真修复**…彻底根除"。两份文档对同一项给出相反结论，且报告引用的代码事实已不存在。
- **建议**：报告顶部加一行"本文档为修复前快照；修复状态见 `PROGRESS.md` 的 2026-09-26 章节与 `..._FIX_RECHECK_2026-09-26.md`"，并修正第 29 行指向的行号（或直接标注"已废弃的引用"）。

### R2 ❌ PROGRESS 新增两处不实陈述

1. **"电台曲库全量注入真实可用公网广播音频流"**
   - 复核：`git diff 327d35b HEAD -- app/lib/core/audio/track_model.dart | grep -c audioUrl` = **0**，本提交对电台数据**零改动**；
   - 现存的 `presetRadioStations[*].track.audioUrl` 是既有的 `http://music.nxinxz.com/kw.php?id=…&type=mp3`（酷我代理的**音轨**链接，与预设曲库同一批），既不是"本轮注入"，也不是"公网广播音频流"。
2. **"全仓无 mock 命名残留"**
   - 复核：`grep -rn "mock" app/lib --include=*.dart | wc -l` = **92**；其中包含 `mockPresetTracks`、`mockJayChouTracks`、`mockBeyondTracks`、`_mockDatabase`、`mockSongs`、`this.source = 'lx-mock'` 等实义命名。
   - 准确表述应为："已删除 `mockRadioStations` 别名并迁移其调用点；其余 `mock*` 命名仍在。"

### R3 ⚠️ 报告 V-4 行引用已删除的符号

报告第 36 行仍写"（数据仍为 `mockRadioStations`）"，而该符号本提交已物理删除。属小瑕疵，但同一文档内自相矛盾。

### R4 ⚠️ 5 个平台预设源仍是"搜得到、播不出"的伪实现（诚实性残留）

- `PlatformPresetSourceDriver.getMusicUrl` 在生产恒为 `null`（本轮修复的直接结果，正确）；
- 但其 **`search()` / 榜单 / 歌单仍从 `_mockDatabase` 返回编造曲目**（`lx_script_sandbox.dart` 内 `_mockDatabase.where(…)`、`_mockDatabase.firstWhere(…)`、`songs: _mockDatabase`）；
- 同时 UI 仍把 **酷我音乐 / 酷狗音乐 / QQ音乐 / 网易云音乐 / 咪咕音乐** 作为可选音源展示，且有用例把"必须可见"钉死（`user_e2e_14_issues_test.dart:227-229`）。
- 用户视角：选中"酷我音乐"能搜到歌，点播放则拿不到该平台音频、只能靠 `enableSourceFallback: true` 降级到六音（或直接失败）。这是"能力宣称与实现不符"的**同类残留**——比假直链轻，但没有解决。
- **建议**：三选一——(a) 用真实驱动替换；(b) UI 隐藏或明确标注为"占位/演示源"；(c) 让 `search()` 也返回空，使其行为与能力一致。

### R5 ⚠️ P0-2 残余风险：唯一防线是"默认值"

- 下游守卫已从域名黑名单改为 `res.url.startsWith('http://') || startsWith('https://')`（5 处）。它不再具备任何"识别假直链"的能力，唯一保障是 `enableTestingUrls` 默认为 `false`。
- 若将来有人把该开关接到生产（或经依赖注入传入），`https://stream.internal.testing/...` 会被无条件放行（假域名现在**只**被这个布尔量挡住）。
- **建议**：在 release/生产构造处加断言或编译期排除（如仅 `kDebugMode` 允许 `enableTestingUrls: true`），或保留一条"占位域名不得进入播放链路"的兜底校验。

### R6 ⚠️ P1-4 / P1-6 零证据的状态没有改变

`docs/evidence/` 被明确排除在仓库外之后，**没有任何被跟踪的可验证记录**能支撑"胶囊不再遮挡""加载更多可用"这两个结论；PROGRESS 仍在断言前者已解决。建议改为：把关键证据落到**被跟踪**的位置（例如 `docs/evidence/README.md` 记录命令+结论+外链），或在报告中明确写"未取得证据、结论待验"。

### R7 ⚠️ `public/` 下仍有 3 张图与脚本/文档不同步

- 仍处于删除状态：`public/e2e_desktop_verified.png`、`public/e2e_flutter_desktop_sources.png`、`public/e2e_flutter_mobile_verified.png`；
- 但 **`e2e_test.js:333`** 会重新生成 `public/e2e_desktop_verified.png`，**`flutter_e2e_verify.mjs:159/185`** 会重新生成 `e2e_flutter_desktop_sources.png` / `e2e_flutter_mobile_verified.png`；
- 且 `docs/audit/web-layer.md:344`、`docs/PC_E2E_FIX_PLAN.md:182` 仍把这些文件当作"存在的存证"引用。
- 结果：下次跑 e2e/verify 脚本会凭空冒出未跟踪文件，文档引用也已失真。**建议**：恢复这 3 张，或同步更新脚本输出路径与引用文档。

### R8 ⚠️ 3 个测试仍在断言生产已不调用的 EQ 函数

`client_e2e_user_journey_test.dart:156`、`mellow_music_comprehensive_test.dart:130`、`user_e2e_14_issues_test.dart:279` 仍在调用 `toLibmpvFilterString()`，而 `app/lib` 已无调用者。口径虽已诚实（PROGRESS 说明 audioplayers 无原生 DSP 通道），但用例名/上下文容易让读者以为"EQ 已接线"。**建议**：在用例描述里标明"算法/预设层单测，不覆盖音频输出"。

### R9 ⚠️ 上一份验收文档已成为历史快照

`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_FIX_VERIFICATION_2026-09-26.md`（已被提交进 `669f9a0`）中 P0-2 ❌、P1-3 ❌、A1' 待办等结论均已被本提交推翻。**建议**在该文档顶部加一行指向本文档，避免后来者据旧结论行动。

---

## 4. 建议的收口动作（按优先级）

1. **D1 文档一致性**：修 R1（报告加状态指针 + 修正失效行号）、R3（V-4 引用）。
2. **D2 口径准确性**：修 R2 两处（删掉或改写"真实公网广播流""无 mock 残留"），并把 PROGRESS 的"真修复"限定到它真正修复的范围（假直链源头 ✔ / 平台源本身仍是占位 ✘）。
3. **D3 诚实性**：处理 R4（5 个平台源的 UI/搜索/播放三分裂），至少标注为占位源。
4. **D4 可验证性**：给出 P1-4 / P1-6 的可复现证据或明确标注"未验"（R6）。
5. **D5 仓库一致性**：决定 R7 的 3 张图去留，并同步脚本与文档。
6. **D6 防御**：为 `enableTestingUrls` 加 release 级保护（R5）。
7. **D7 交接**：在上一份验收文档顶部加指向本文档的说明（R9）。

---

## 5. 复核锚点（可重跑）

```bash
cd "$(git rev-parse --show-toplevel)"

# 1) 门禁（本次实测：analyze 干净、+196 全过）
cd app && flutter analyze && flutter test; cd ..

# 2) P0-2：生产是否真的返回 null / 测试开关不可达
grep -n "allowTestingUrls\|enableTestingUrls" app/lib/core/sources/lx_script_sandbox.dart
grep -rn "enableTestingUrls" app/lib app/test
grep -rn "mellowmusic.io\|custom-cdn" app/lib          # 期望：无命中

# 3) 5 个平台预设源仍是 mock 搜索
awk '/class PlatformPresetSourceDriver/,/^}/' app/lib/core/sources/lx_script_sandbox.dart | grep -n "_mockDatabase"

# 4) 文档口径
sed -n '29p;36p' docs/PC_USER_E2E_ACCEPTANCE_ROUND2_2026-09-25.md
grep -n "广播音频流\|无 mock 命名残留" docs/PROGRESS.md
grep -c "mock" <(grep -rn "mock" app/lib --include=*.dart)

# 5) 图片与脚本一致性
git diff --stat 674b43d HEAD -- public/
grep -rn "public/e2e_desktop_verified.png\|e2e_flutter_desktop_sources.png" e2e_test.js flutter_e2e_verify.mjs
```

---

## 6. 诚实边界

1. **未复跑**：macOS 集成测试 `9/9`（需真机 GUI）、Puppeteer `83/83`（需自备 8088 服务）。
2. **未做 GUI 实测**：P1-4（胶囊遮挡）、P1-6（加载更多）无法在本会话判定；且仓库已明确不存证据，无法回溯。
3. **未联网验证**：`music.nxinxz.com` 等既有音频链是否真实可播、`六音/Huibq/ikun` 三源当前可达性，均未实测；R4 的判断基于代码路径（`getMusicUrl` 恒 null + `search` 用 `_mockDatabase`）。
4. 判定基于 **2026-09-26 02:02 CST、HEAD `669f9a0`、工作树干净**的快照。

---

## 7. 本文档对仓库的改动

- **新增**：`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_FIX_RECHECK_2026-09-26.md`
- **未改动**：代码、文档、图片（全程只读；§4 的 D1–D7 均未执行）

---

*验收方：DSH 会话 `session-2d780725`（工作区 mellow-music-player）｜2026-09-26 02:02 CST*
