# PC 端「用户视角」E2E 验收 · 第二轮复验报告 —— 独立复核与验收记录

> 复核日期：2026-09-26 00:33 CST（接续 09-25 夜间的第二轮验收）　复核对象：`docs/PC_USER_E2E_ACCEPTANCE_ROUND2_2026-09-25.md`（116 行，由会话 `session-4dc23e63` 于 00:13 产出）
> 复核方：DSH 会话 `session-2d780725`（**独立于原验收会话**，`workspace-write` 策略）
> 复核方式：读取被复核会话的**原始事件日志**（`~/.dsh/sessions/.../session-4dc23e63.../session.v3.jsonl.zstd`，1352 条事件）核对"自述做过"与"实际执行过"是否一致 + 报告全文逐条回代码核对 file:line + 用 PIL **重算全部关键像素差** + 尝试独立复跑质量门禁
> 复核纪律：结论只来自**仓库内可复算的产物**（源码、证据图、git 状态）与原始日志；`/tmp/iverify` 仅用于交叉印证时间线，不作为结论依据。

> 判定标记：✅ **确认**（独立复算成立）｜❌ **口径不成立/需修正**｜⚠️ **部分成立或无法复核**｜🆕 **本次新增**

---

## 0. 验收结论（一句话）

**它的技术判断可以信，可作为下一轮修复的输入；但这份交付不能原样入库。**
理由：被核对的 8 条源码级断言**全部属实**，关键像素实验的方向与量级**全部可复现**，且它主动把 P0-3b 记为"未修复"、爆料了比上轮更严重的新 P0——没有粉饰；但证据集里混入 2 张纯黑废帧且未披露、报告未给像素差度量口径、P1-4 有一处措辞不实、工作区被弄脏未记录，另有 2 项自认未验 + PROGRESS 未写 + 交付物未收口。**收口动作见 §5。**

---

## 1. 复核结论总表

| # | 被复核断言（原报告） | 复核判定 | 我的依据 |
| :--- | :--- | :---: | :--- |
| 1 | 验收基线为 HEAD `674b43d`，优化提交 `a3ce7c7` | ✅ 确认 | `git log --oneline -5`：HEAD 即 `674b43d`；`a3ce7c7` 存在（第 5 条） |
| 2 | P0-3b「LX 预设音源编造 CDN 直链」**未修复** | ✅ 确认 | `lx_script_sandbox.dart:458`、`:794` 两条编造 URL 原样在；kw/kg/tx 预设驱动仍在注册；换源路径 5 处 `enableSourceFallback:false`（§3.1） |
| 3 | P0-3a 歌手粉丝数公式已删、不再渲染该行 | ✅ 确认 | `desktop_views.dart:1050-1052`（注释"不再用公式编造" + `fans: ''`）、`:1165`（空值守卫） |
| 4 | P1-2 底部播放栏遮挡已修（统一 `fromLTRB(32,24,32,128)`，电台页 120） | ✅ 确认 | 13 处 `...128` + 电台页 `...120` = 14 处命中，逐条与报告一致（§3.1） |
| 5 | 上轮 P0-1/P0-2 已修复（Space/L/Q/M、ESC 两条分支） | ⚠️ 部分确认 | 像素复算支持"ESC 后回到主页面"（42 vs 主页 4.90%、46 vs 主页 0.91%）；百分比口径未给，不能逐字复现（§3.2） |
| 6 | 🆕 本轮新 P0：访问过带输入框页面后全局快捷键集体失效 | ✅ 确认（代码 + 像素双证据） | `desktop_scaffold.dart` 的 `CallbackShortcuts`+`Focus(autofocus:true)`、`desktop_search_view.dart:271`；复算：A 组播放栏 maxΔ=132 / B 组 maxΔ=11 |
| 7 | P1-1 搜索长列表已可达（62 首、可滚到第 12 行，位移 36.1%） | ✅ 确认 | 复算 `83→85` = **36.85%**（>8 阈值）；本人肉眼查 `85_scroll_deep.png`：第 02–12 行均在屏 |
| 8 | 证据为"**69 张本轮实测截图**" | ❌ **口径不成立** | 其中 2 张是 md5 相同的纯黑废帧（`81_search_scrolled`≡`82_search_bottom`），另有编号重号；有效 67 张（§3.3） |
| 9 | §6 证据清单"共 69 张" | ❌ **内部不自洽** | §6 四行只列 26+20+16+5 = **67** 个文件名，漏登 `81_search_scrolled`、`82_search_scrolled`（§3.3） |
| 10 | P1-4「`toLibmpvFilterString()` 仍无任何调用者」 | ⚠️ 结论成立、措辞不实 | `app/lib` 内确无调用者，但 `app/test` 有 2 处调用（§3.1） |
| 11 | README 写 178 / PROGRESS 写 192，README 口径滞后 | ✅ 确认 | README.md:9、PROGRESS.md:14 原文如此 |
| 12 | 质量门禁：analyze 0 issue、`flutter test` 192/192、集成 9/9、e2e 83/83 | ⚠️ **本次无法独立复核** | 本会话 `workspace-write`，flutter 需写 `/opt/homebrew/share/flutter/bin/cache` → `Operation not permitted`（§3.4） |
| 13 | 报告落款"21:15–23:00 CST" | ❌ 过期 | 报告文件 mtime = 00:13，日志显示工作持续到 00:13:28（§3.5） |

---

## 2. 复核方法与独立性

1. **自述 vs 日志**：解压被复核会话的 `session.v3.jsonl.zstd`（1352 事件、7 轮、131 步），逐条比对它声称执行的动作与实际 `tool/call` 是否一致——**没有发现"报告里写了但没执行过"的动作**。
2. **源码级回核**：报告里每条 `file:line` 都用 `grep`/`sed` 回到当前工作区核对（§3.1）。
3. **像素级重算**：对仓库内证据图用 PIL/numpy 独立重算（`docs/evidence/` 只读），**不使用**它的中间产物或 /tmp 数值（§3.2）。
4. **门禁复跑**：尝试在本会话独立跑 `flutter analyze` / `flutter test`，被文件沙箱拒绝（§3.4）——按纪律如实记录为"未复核"，不猜。
5. **完整性扫描**：对 69 张证据做 md5 去重 + 亮度直方（§3.3）。

---

## 3. 逐条复核记录

### 3.1 源码级断言（8/8 属实，2 处行号需修）

| 报告断言 | 复核结果 |
| :--- | :--- |
| `lx_script_sandbox.dart:458` 编造直链 | ✅ 原文：`return 'https://cdn.$platformId.music.net/media/${targetSong.songMid}_${quality.value}.mp3';` |
| `lx_script_sandbox.dart:794` 编造直链 | ✅ 原文：`return 'https://custom-cdn.${metadata.id}.com/stream/...';` |
| 预设驱动仍注册 | ✅ `registerDriver(PlatformPresetSourceDriver(platformId: LxPlatformId.kw/kg/tx, ...))` 依次注册 |
| `online_music_service.dart:445-560` 以 `enableSourceFallback:false` 命中预设驱动 | ⚠️ 现象属实，**行号需修**：实际命中点在 `:462 / :508 / :528 / :548 / :580`（共 5 处），报告区间未覆盖 580 |
| `desktop_scaffold.dart:193-197` 快捷键依赖 `CallbackShortcuts`+`Focus(autofocus:true)` | ✅ 结构完全吻合（`bindings: shortcuts` → `Focus(autofocus: true, child: Scaffold(...))`） |
| `desktop_search_view.dart:271` 输入框 `autofocus: widget.initialQuery == null` | ✅ 逐字命中 |
| `desktop_search_view.dart:923-932` 底部"加载更多" | ✅ 命中 `if (_hasMoreSongs && _searchResults.isNotEmpty)` 区块 |
| `equalizer_manager.dart:134` `toLibmpvFilterString()` 无调用者 | ⚠️ **`app/lib` 内 0 处调用者属实**（结论成立）；但 `app/test` 有 2 处：`client_e2e_user_journey_test.dart:156`、`mellow_music_comprehensive_test.dart:130` → 措辞应改为"**生产代码无调用者，仅测试在断言它**" |

> 补充发现（比原结论更重）：`toLibmpvFilterString` 在测试里被断言、在生产里没人调——**测试正在替一个未接线的功能背书**。

### 3.2 像素证据复算（方向与量级 7/7 可复现）

复算方法（本次自定，供他人重跑）：转 8-bit 灰度取全窗绝对差，**同时报"差>8"与"差>24"的像素占比**，并按"上 75% 页面 / 底部 180px 播放栏"分带；纯全窗"任意差异像素占比"会被 1 LSB 抗锯齿噪声污染，不作为判据。

| 原报告说法 | 我的复算 | 判定 |
| :--- | :--- | :---: |
| A 全新启动按空格**生效** | 播放栏（下 180px）maxΔ=**132**、>24 = 0.20%；页面区 maxΔ=19（安静） | ✅ 局部真实变化 |
| B 访问搜索页后按空格，播放栏差 **0.00%** | 播放栏 maxΔ=**11**、>24 = **0.00%**（全窗 maxΔ=16，属噪声） | ✅ 复现 |
| B' 同状态按 L，页面差 **0.94%** | 页面 maxΔ=**29**、>24 = 0.44%（全窗 >8 = 16.76%） | ✅ 未进入巨幕歌词；百分比随阈值变动 |
| `42_ESC_exit` 与主页面差 **2.9%** | 对 `30_fresh_main`：>8 = **4.90%**、>24 = 0.03% | ✅ 同量级 |
| `46_ESC_queue` 与主页面差 **0.67%** | 对 `30_fresh_main`：>8 = **0.91%**、>24 = 0.03% | ✅ 同量级 |
| `83_before_scroll → 85_scroll_deep` 位移 **36.1%** | 全窗 >8 = **36.85%**（>24 = 28.54%） | ✅ 几乎逐字复现 |
| `41_L_lyrics → 42_ESC_exit` 退出巨幕 | 全窗 >8 = 72.84%、>24 = 57.53%（确实是两种完全不同的界面） | ✅ |
| P1-6 收藏 4→5 | `07_favorites` vs `71_favorites_after`：maxΔ=172、>24 = 2.62%（数字区有真实改动） | ✅ 方向成立 |

**结论**：没有任何一条像素结论是编造的；但**报告未写度量口径（阈值 / 裁剪区 / "位移"定义）**，导致它的百分比无法被逐字复现（例如同一对图"差异像素占比"在无阈值下可到 16–36%）。这一条必须补写。

### 3.3 证据完整性（❌ 发现 2 张纯黑废帧）

- `81_search_scrolled.png` 与 `82_search_bottom.png` **md5 完全相同**，灰度均值 **0.26/255**、非零像素 **0.4%**、各 101 KB → 纯黑帧。
- 目录内另有 `82_search_scrolled.png`（编号重号），其均值为 **232.44**，是有效帧。
- 来源可在会话日志中坐实：22:48:29 它自己贴出的两张小图 `80_search_results_small.png` / `82_search_bottom_small.png` **同为 6070 字节且 attachmentId 相同**（当时搜索结果未渲染），23:33–23:40 才重拍成有效的 83/84/85——**81/82 是那次失败尝试的未清理废帧**。
- 与报告自述冲突：第 5 行称"**69 张本轮实测截图**"，§6 清单也只列 67 个名字，均未披露该情况。
- 其余 67 张亮度正常（`80`=232.57、`83`=232.30、`84`=236.72、`85`=241.48），无白屏。
- 与上轮的关联：上一轮曾专门删除 24 张白屏伪证据——**同类问题在本轮以"未清理废帧"的形式复发**。
- 好消息：这两张黑帧**没有被任何结论引用**（`docs/*.md` 中 0 处引用 `81_search_scrolled`/`82_search_bottom`），P1-1 的结论挂在 83/85 上——所以**结论未受污染，污染的是交付物**。

### 3.4 质量门禁：本次**未能**独立复核（诚实边界）

- 本会话为 `workspace-write`；`flutter` 执行时需要写 `/opt/homebrew/share/flutter/bin/cache/engine.stamp.tmp.*`、`engine.realm` → `Operation not permitted`（沙箱拒绝）。
- 陷阱记录：该命令因管道末段是 `tail`，**退出码仍为 0**（假成功）——复核此类门禁必须看真实输出而非 exit code。
- 因此 `192/192`、集成 `9/9`、Puppeteer `83/83` 目前**只有它自己与当天更早的独立复核**作为佐证（更早那份复核当时实测为 172/172，测试数在优化提交后增长到 192）。
- `/tmp/iverify/e2e_full.log` 确实显示 `83 / 83 (100%)`，但那是它自己的产物，**不算独立证据**。

### 3.5 时间线与收尾状态

- 报告落款"2026-09-25 21:15–23:00 CST"，但工作持续到 **00:13:28**（报告文件 mtime 也是 00:13）→ 落款过期。
- 00:13:28 用户发"能加快速度吗？"，**00:20:53 该轮以 `aborted(user)` 结束**，该提问未获回答。
- 中断点可精确定位：最后一步是读 `docs/PROGRESS.md`（用 `offset 400`，而该文件仅 243 行）→ `ToolCallError: offset 400 is out of range`。**因此 `PROGRESS.md` 至今没有第二轮记录**。
- 交付物未 present、无收口总结；goal（`goal-475b23ba`，"已经做了一轮优化，重新走一遍之前的验收流程"）仍为 active。

---

## 4. 原报告自认未验 + 复核补充

| 项 | 状态 |
| :--- | :--- |
| 搜索触底「加载更多歌曲（已呈现 N 首）」行为 | 未验（报告 §5.1 自认） |
| 换源弹窗是否真会拿到编造直链（酷我/QQ 在线源） | 未验（仅静态链路确认，报告 §5.2 自认） |
| 悬浮歌词胶囊遮挡且默认开启 | **本次补充确认现象真实**：`85_scroll_deep.png` 中胶囊压在列表行上（报告 §5.3 已登记但未定案） |
| 与 `SPEC.md`/`index.html`/`design_tokens.css` 逐项再对齐 | 仅增量确认（EQ 预设 5→4、mock 数据仍在） |
| Windows 真机 / 移动端 / Web 端 | 不在本轮范围 |
| EQ 预设"4 个" | 本次未复核数量（未定位预设清单定义处），留待下轮 |

---

## 5. 待修复清单（收口用）

### A. 交付物收口（不改产品代码，先做完这 6 条再谈"验收通过"）

- **A1** 删除 `docs/evidence/pc-user-acceptance-round2/81_search_scrolled.png` 与 `82_search_bottom.png`（纯黑、md5 相同）；解决 `82_*` 编号重号
- **A2** 报告第 5 行"69 张本轮实测截图"改为实际有效张数；§6 清单补齐缺失的 2 个文件名，使分组合计与总数自洽
- **A3** 报告补一行**像素差度量口径**（阈值、裁剪区、"位移"定义），并修正落款时间（21:15–23:00 → 至 00:13）
- **A4** P1-4 措辞改为"`app/lib` 内无调用者，仅 `app/test` 两处在断言"（`client_e2e_user_journey_test.dart:156`、`mellow_music_comprehensive_test.dart:130`）
- **A5** 修正引用行号：`online_music_service.dart:445-560` → `462 / 508 / 528 / 548 / 580`
- **A6** 在 `docs/PROGRESS.md` 补第二轮复验记录（原会话中断未写）

### B. 产品缺陷（按严重度）

- **P0-1 🆕 全局快捷键"焦点丢失"失效**（本次复核确认）：根因指向 `desktop_scaffold.dart` 的 `CallbackShortcuts` + `Focus(autofocus: true)`——同一路由内视图替换后焦点不回退。修法：迁移到 `Shortcuts`+`Actions`，或在视图切换/输入框失焦时 `requestFocus(_rootFocusNode)`；**并补一条"访问搜索页后 Space 仍能切播放"的回归测试**（否则同类回归必然复发）
- **P0-2 LX 预设音源编造 CDN 直链未修复**：`lx_script_sandbox.dart:458/794`（`cdn.<平台>.music.net` / `custom-cdn.<id>.com`）+ 预设驱动注册 + 换源显式路径。要么接真实解析、要么按上一轮的做法**诚实降级并标注**
- **P1-3 EQ 未接线**：`toLibmpvFilterString()` 生产无调用者（听感不受 EQ 影响）；同时预设 5→4 与原型「空间 3D」缺失；测试却断言了滤镜串 → 需接线或改测试口径
- **P1-4 悬浮歌词胶囊遮挡内容**：默认开启、固定在中部、压住歌单卡与搜索结果行（`85_scroll_deep.png` 可见）→ 需可拖动/可关闭或避让
- **P1-5 文档口径打架**：README.md:9 写 178，PROGRESS.md:14 写 192 → 统一为实测值
- **P1-6 搜索触底「加载更多」未验完** → 补一次到底实测
- **P2-1 声音电台页数据仍为 `mockRadioStations`**（视觉改善但非真实数据，与"不能有假数据"目标不符）
- **P2-2 集成测试 seek 竞态未消除**：`seek exception handled` / `Stream closed before it got prepared` 被 try/catch 兜住，仍会静默换源
- **P2-3 Puppeteer E2E 属"有条件门禁"**：必须先自备 8088 服务，且存在 flaky（82/83 → 83/83）；README 应写明前置条件（承接上一轮 F-13）

### C. 仓库卫生

- **C1** `app/pubspec.lock` 有 164 行变动（`flutter pub get` 副作用）→ 决定回滚或提交，不要带进无关提交
- **C2** 6 个受版本控制的 `public/*.png` 被 `node e2e_test.js` 在 22:48 覆盖回写 → 确认是否有意刷新，否则回滚（原报告未披露此副作用）
- **C3** **黑屏工程陷阱需固化**：跑完 `flutter test integration_test -d macos` 后必须重新 `flutter build macos --debug` 再做人工验收，建议写进 README 或验收脚本前置（原报告已定位，未落文档）
- **C4** **证据目录对 git 不可见**：`.gitignore:18` 的 `*.png` 使整个 `docs/evidence/pc-user-acceptance-round2/` 处于 ignored 状态（`git status` 显示 `!!`，跟踪数 0）→ 若要入库必须 `git add -f`，否则下次 `git add docs/` 会把证据静默丢掉

---

## 6. 复核锚点（便于他人重跑）

```bash
# 1) 证据完整性：重复内容 + 亮度
python3 - <<'PY'
import hashlib, glob, os
from PIL import Image, ImageStat
base = "docs/evidence/pc-user-acceptance-round2"
h = {}
for f in sorted(glob.glob(base + "/*.png")):
    h.setdefault(hashlib.md5(open(f, 'rb').read()).hexdigest(), []).append(os.path.basename(f))
    im = Image.open(f).convert("L")
    m = ImageStat.Stat(im).mean[0]
    if m < 20:
        print("near-black:", os.path.basename(f), round(m, 2))
print("dups:", [v for v in h.values() if len(v) > 1])
PY

# 2) 像素差（分带 + 双阈值），替换 <A>/<B> 为两张证据图名
python3 - <<'PY'
import numpy as np
from PIL import Image
base = "docs/evidence/pc-user-acceptance-round2/"
a, b = "30_fresh_main", "31_fresh_space"
d = np.abs(np.asarray(Image.open(base+a+".png").convert("L"), np.int16)
         - np.asarray(Image.open(base+b+".png").convert("L"), np.int16))
H = d.shape[0]
for name, seg in {"全窗": d, "页面(上75%)": d[:int(H*0.75)], "播放栏(下180px)": d[H-180:]}.items():
    print(f"{name}: >8={100*(seg>8).mean():.2f}% >24={100*(seg>24).mean():.2f}% max={seg.max()}")
PY

# 3) 源码断言回核
grep -rnE "music\.net/media|custom-cdn" app/lib/core/sources
grep -rn "enableSourceFallback" app/lib
grep -rn "toLibmpvFilterString" app/lib app/test
grep -rn "fromLTRB(32, 24, 32, 128)" app/lib
```

---

## 7. 诚实边界

1. **未独立复跑质量门禁**（沙箱拒绝 flutter 写工具链缓存）——`192/192`、`9/9`、`83/83` 仍属"单方声明 + 更早的第三方复核"。
2. **未亲自跑 GUI**：本会话不抢占前台，快捷键/ESC 的"生效与失效"结论建立在**对原始证据图的独立复算**之上，属"证据复核"而非"独立复现实验"。
3. **未复核**：EQ 预设 4 vs 5 的数量、`SPEC.md` 逐项对齐、Windows/移动/Web 端。
4. 判定基于 **2026-09-26 00:33、HEAD `674b43d`、含未提交改动的当前工作区**快照；工作区此后若变动，结论需重跑锚点。

---

## 8. 本次复核对仓库的实际改动

- **新增**：本文件 `docs/PC_USER_E2E_ACCEPTANCE_ROUND2_VERIFICATION_2026-09-26.md`
- **未改动**：产品代码、证据图、`PROGRESS.md`、任何既有报告（全程只读；§5-A1 的黑帧删除**故意未执行**，留待收口时与重拍一并处理）
- 本文件本身被 `*.png` 之外的规则覆盖，可正常 `git add`；**证据目录仍需 `git add -f`**（见 C4）

---

*复核方：DSH 会话 `session-2d780725`（工作区 mellow-music-player）｜2026-09-26 00:33 CST*
