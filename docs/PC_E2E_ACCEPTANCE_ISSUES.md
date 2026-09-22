# Mellow Music · 润音 — PC 端产物端到端（E2E）验收报告

> **本报告为验收问题文档（What's wrong）**。配套文档：修复建议见 `docs/PC_E2E_FIX_PLAN.md`；四份原始审计报告见 `docs/audit/`；20 张实测存证截图见 `docs/evidence/pc-e2e/`。

## 0. 结论速览

| 项目 | 内容 |
| :--- | :--- |
| **验收对象** | `release_windows/app.exe`（Windows x64 桌面产物，Flutter 构建） |
| **产物标识** | MD5 `4839AFE576D5297AB9B2BCD707ADC9EF`，90,624 B；`data/app.so` 6,308,744 B |
| **构建时间** | 2026-09-22 17:37:18（**新于最新源码** `app/lib/views/desktop/desktop_views.dart` 17:26:19，故为与当前源码一致的产物） |
| **验收方式** | 真实启动产物 + Win32 合成鼠标/键盘事件逐项操作 + 窗口位图抓取 + 截图像素级热区测量 + 重启对比实验；并辅以 4 路并行代码/文档/假数据/Web 层静态审计 |
| **验收日期** | 2026-09-22 |
| **验收结论** | ❌ **不通过**。当前产物是**视觉完成度很高的原型（high-fidelity prototype）**，不具备其对外声明的产品能力 |

### 0.1 一句话结论

> **这是一个"看起来像成品、点下去是空壳"的产物**：14 个桌面视图全部能渲染、动效与主题切换都很精致，但**它不发出任何声音、关掉就忘记一切、并且会用"已成功备份到云端"这类提示欺骗用户**。

### 0.2 三个致命结论

| # | 结论 | 一句话证据 |
| :--- | :--- | :--- |
| **1** | **不能发声** | 进程加载的 85 个模块中音频相关模块数为 **0**；pubspec 无任何音频依赖；进度由 `Timer.periodic(50ms)` 手工累加（P0-01） |
| **2** | **关掉就忘** | 重启前「深色 + 绿色强调色 + 4 首收藏」→ 重启后「浅色 + 蓝色 + 默认收藏」，用户数据全部归零（P0-02，有前后对比截图） |
| **3** | **说得到做不到** | 点「从云端恢复」弹出"已成功从 WebDAV 云端合并最新快照数据！"，代码里只有 `await Future.delayed(900ms)`，**未发出任何网络请求**（P0-03）；同类虚假声明还有"服务就绪"、"QuickJS"、"libmpv firequalizer"、"24bit/192kHz 无损直出"、"Gaore 的 iPhone 15 Pro 在线"等（P0-04/P0-07/P0-10） |

### 0.3 严重度统计

| 级别 | 数量 | 含义 | 代表条目 |
| :--- | :---: | :--- | :--- |
| **P0** | 12 | 核心功能缺失 / 欺骗性反馈 / 安全与发布阻断 | P0-01 无音频、P0-02 零持久化、P0-03 同步伪造成功、P0-12 服务端可被单请求打死 |
| **P1** | 20 | 数据编造、文案与实现矛盾、工程与交付可信度 | P1-01 四榜单雷同、P1-02 歌手数据编造、P1-14 测试断言 mock |
| **P2** | 12 | 体验、性能、工程卫生 | P2-01 列表一次性构建、P2-05 设计 Token 与 CSS 不一致 |
| **合计** | **44** | | |

**可直接对外演示的真实功能比例（保守估计）**：14 个桌面视图 100% 可渲染，但**端到端数据真实且可用的链路只有 3 条**——网易云在线搜索、网易云歌单导入（实测成功返回 200 首真实曲目）、LRC 歌词拉取；且这 3 条同样受 P0-02（不持久化）影响。**占比约 3/20 个用户旅程场景可完整跑通 = 0 个场景达到完整期望**（详见 §5 场景判定汇总）。

### 0.4 什么情况下可以重新验收

完成修复建议文档（`docs/PC_E2E_FIX_PLAN.md`）中的**阶段 0（止血）+ 阶段 1（播放底座）+ 阶段 2（持久化）**后，可重新执行本报告 §2 的验收方法复验。在此之前，**不建议对外演示、不建议发布到任何应用商店、不建议让任何真实用户录入数据**——因为用户录入的数据一定会丢，而界面会告诉他"已备份到云端"。

---

## 1. 验收对象、环境与判定标准

### 1.1 被测产物（唯一认定）

| 项 | 值 |
| :--- | :--- |
| 主程序 | `release_windows/app.exe`（Windows x64 桌面产物） |
| 打包目录时间戳 | 2026-09-22 17:37:18（该目录内全部文件一致） |
| 字节码 | `release_windows/data/app.so` = **6,308,744 字节**（MD5 `2A8A7044A1163C90FA87BAD51B308134`） |
| app.exe | 90,624 字节，MD5 `4839AFE576D5297AB9B2BCD707ADC9EF` |
| 最新源码文件 | `app/lib/views/desktop/desktop_views.dart` = **17:26:19** |
| 关键依赖 | `release_windows/data/flutter_assets/`、`flutter_windows.dll`(21,274,112 B)、`dartjni.dll`、`icudtl.dat` |

### 1.2 为什么选它，而不是仓库里另外两份副本

仓库内同时存在 **3 份互相不一致的 Windows 构建副本 + 1 个更早的陈旧可执行文件**。逐份实测：

| 路径 | 时间戳 | app.exe MD5 | app.so 大小 | 判定 |
| :--- | :--- | :--- | :--- | :--- |
| `release_windows/` | **17:37:18** | `4839AFE5…C9EF` | **6,308,744** | ✅ 新于源码 17:26:19，**与当前源码一致，本次验收对象** |
| `app/build/windows/x64/runner/Release/` | 16:52:41 | `1232DE1B…9684` | 6,210,440 | ❌ 早于源码 34 分钟，**过期产物** |
| `app/build/windows/latest_release/` | 16:52:41 | `1232DE1B…9684` | 6,210,440 | ❌ 与上一份二进制完全相同，同为过期产物 |
| `.../Release/mellow_music.exe` | 15:43:56 | `E9C60E58…B8B1` | — | ❌ 更早的遗留 exe，位于 Release 目录内 |

判定依据：`release_windows/data/app.so` 晚于最新源码文件 `desktop_views.dart`(17:26:19)，其余两份 app.so 均早于源码，因此只有 `release_windows/` 承载的是当前源码的编译结果。**三份副本并存且互不一致、Release 目录残留两个 exe，本身即发布卫生缺陷**；更严重的是 `release.yml:44` 用 `Compress-Archive -Path app/build/windows/x64/runner/Release/*` 整目录打包，会把陈旧 `mellow_music.exe` 一并打进对外发布包（见 P1-20）。

### 1.3 运行环境

| 项 | 值 |
| :--- | :--- |
| OS | Windows（x64） |
| 屏幕 | 1920x1080，DPI 96（100% 缩放，无系统缩放干扰） |
| 浏览器 | Chrome 与 Edge 均存在 |
| Node | v24.14.1 |
| Python | 3.6.8 |
| **环境限制（必须声明）** | 本机**未安装 Flutter / Dart CLI**，因此 `flutter analyze` / `flutter test` / `flutter build` **无法实机重跑**。凡涉及测试通过率、静态分析 0 告警的条目，结论只能基于源码静态阅读，文中均标注为「静态证据，未实机复现」 |

### 1.4 判定标准（四个维度）

1. **核心功能可用性**：以"音乐播放器"的核心链路（选歌 → 出声 → 控制 → 记忆）能否端到端跑通为准。判定不看 UI 是否存在，只看真实副作用是否发生。
2. **数据真实性**：界面呈现的每一条数据（曲目、粉丝数、播放量、设备、端口、同步时间）是否有真实数据源。无来源的常量字符串一律判"编造"。
3. **文案与实现一致性**：所有技术名词（libmpv / firequalizer / QuickJS / 24bit·192kHz / 无损 / 服务就绪 / 已同步 / 监听中）都必须能在代码中找到对应实现与调用方。
4. **交付可发布性**：产物身份、版本号、管道可跑性、服务端安全、依赖完整性、发布包卫生。

**严重度定义**：**P0** = 产品核心价值不成立 / 数据安全层面欺骗用户 / 交付物可被远程打死；**P1** = 功能缺失或数据编造，用户可感知且影响信任，但不会造成数据丢失或安全事件；**P2** = 工程质量、一致性、适配性问题，影响体验与可维护性。

---

## 2. 验收方法（可复现步骤）

全部结论来自真实用户视角的实机操作，不做纯静态推断（纯静态的条目均已在正文标注）。以下步骤他人可照做复现。

### 2.1 启动与置窗

1. 从**未被改写的原始副本**启动 `release_windows/app.exe`（双击或 `Start-Process`），不使用任何 IDE/调试器附加。
2. 用 Win32 `SetWindowPos` 将主窗口置为 **1440x900 @ (0,0)**：`SetWindowPos(hwnd, HWND_TOP, 0, 0, 1440, 900, SWP_SHOWWINDOW)`。置窗后再做所有测量，避免窗口尺寸变化导致热区漂移。
3. 启动后**持续轮询 24 秒**（`Get-Process -Name app` 每秒一次，检查 `Responding` 与 `HasExited`），确认无崩溃、无"未响应"。实测：24 秒内进程稳定，共加载 **85 个模块**。

### 2.2 抓图（PrintWindow 优先，屏幕抓取兜底）

1. 取窗口句柄：`GetWindowText` 读标题（实测返回 `'app'`），`GetClassName` 读类名（实测 `FLUTTER_RUNNER_WIN32_WINDOW`）。
2. 主路径：`PrintWindow(hwnd, hdcMem, PW_RENDERFULLCONTENT)` 抓取窗口位图，得到的位图不受窗口遮挡影响。
3. 兜底路径：当 `PrintWindow` 返回 0 或位图为全黑/全白（Flutter 使用 GPU 合成时偶发）时，回退到屏幕抓取（`BitBlt` 从桌面 DC 抓 1440x900 区域），并保证窗口位于前台且无其他窗口压盖。
4. 每次抓图落盘为 PNG，存放于 `docs/evidence/pc-e2e/`（20 张，清单见 §6）。

### 2.3 像素级热区测量（本方法的关键，决定了结论可信度）

1. 侧边栏条目为规则重复的卡片，取其**颜色跳变行**做像素级扫描：沿 x=60 的竖直像素线逐行读取 RGB，记录"背景色 → 卡片底色"的分界行。
2. 实测得到：侧边栏条目**高度 34px**，条目间距 **12px**。
3. 由分界行推算每条条目热区的垂直中心，实测值（窗口左上角为原点）：

| 分组 | 热区中心 y（实测） |
| :--- | :--- |
| 在线音乐组 | **147 / 193 / 239 / 285 / 331**（发现音乐 / 歌单广场 / 巅峰榜单 / 热门歌手 / 声音电台） |
| 我的资料库组 | **419 / 465 / 511 / 557**（我喜欢的音乐 / 导入与自建歌单 / 播放历史 / 本地与下载） |
| 系统与生态组 | **645 / 691 / 733**（多端同步中心 / LX 音源管理 / 个性化设置） |

4. 横向热区中心取侧边栏可视宽度中点（实测 x=120 可靠命中，x=60~180 均为条目有效区域）。
5. **所有最终结论均在上述精确坐标下复验过**；第一轮的目测坐标仅用于探索，不作为本文档任何条目的证据。

### 2.4 输入合成（真实用户输入路径）

1. 鼠标：`SetCursorPos(x, y)` → `mouse_event(MOUSEEVENTF_LEFTDOWN/LEFTUP)`（用真实合成事件而非 `SendMessage`，确保走 Flutter 的命中测试与手势识别链路）。
2. 键盘：置窗口前台（`SetForegroundWindow`）→ `keybd_event(VK_ESCAPE, ...)` / `keybd_event(VK_CONTROL + 'K')`，按下并抬起各一次，间隔 ≥100ms。
3. 每次操作后等待 ≥800ms 再抓图，避免拿到过渡帧。

### 2.5 重启对比实验（持久化能力的判定方法）

这是判定 P0-02 的核心方法，任何"是否持久化"的结论都必须用它，不能靠读代码：

1. **造态**：启动 → 切深色主题 → 选绿色强调色（碧波翡翠）→ 对 4 首曲目点红心 → 开始播放 → 等进度走到 00:11。
2. **抓图存证**：`11-before-restart-dark-green-4fav.png`。
3. **杀进程**：`Stop-Process -Name app -Force`，确认进程列表已无 `app`。
4. **冷启动**：再次运行同一个 exe，不触碰任何设置。
5. **抓图对比**：`12-after-restart-light-blue-defaultfav.png`，逐项核对主题、强调色、收藏数、播放进度。
6. 判定：任何一项回到初值即判定"未持久化"。

### 2.6 进程与模块取证（判定"是否具备音频能力"的方法）

不读代码也能判定"能否发声"：

```powershell
Get-Process -Name app | ForEach-Object {
  $_.Modules | Where-Object { $_.ModuleName -match 'audio|mpv|fmod|bass|sound|media|avcodec' }
}
```

实测：**输出为空**。即该进程 85 个已加载模块中，音频相关模块数为 **0**。该结论比任何提示文案都硬。

### 2.7 接口与服务端裸测

1. 网易云在线接口：直接用 HTTP 客户端请求搜索 / 歌词 / 歌单详情，记录状态码；音频直链单独请求并跟踪 302 跳转（见 P1-19）。
2. `server.js`：因 `package.json` 的 `"type":"module"` 与其 CommonJS `require()` 冲突，原文件无法用 `node server.js` 启动，故**逐字节复制为 `.probe_server.cjs`**（仅改扩展名，`__dirname` 与行为不变）后启动，再用**原始 TCP socket** 发送畸形请求（绕过一切客户端 URL 规范化），每个用例都在全新进程上执行，并在之后用一次正常请求探测服务是否存活。审计结束后探针文件与越权取证文件已删除。

### 2.8 证据存放位置

- 截图：`docs/evidence/pc-e2e/`（20 张 PNG，文件名见 §6）。
- 四份并行审计报告（本文可直接引用，不复制全文）：`docs/audit/code-review.md`（28 条）、`docs/audit/doc-gap.md`（主表 80 条断言）、`docs/audit/fake-data.md`（174 条）、`docs/audit/web-layer.md`（含实测 HTTP 原始输出）。

### 2.9 过程透明性与方法局限（诚实声明）

1. 第一轮使用了**目测坐标**。期间出现过一次**无法归因的现象**：窗口尺寸被改为 869x900 且视图变为歌手详情页，可能来自宿主环境干扰。该现象**此后未能复现**，也未被任何结论采用，**本文档不包含该现象**。此后全部结论都用 §2.3 的像素测量坐标重新验证。
2. 本机无 Flutter / Dart CLI，测试通过率类结论无法实机复现（已在相应条目标注）。
3. 本机无 macOS / Android 产物，P0-05、P0-06、P1-12 为**静态证据**（读平台清单与 workflow 得出），未在对应平台实机验证。
4. `server.js` 与 `e2e_test.js` 不属于 `app.exe` 的内容，相关条目标注为"交付仓库范围"，不影响主产物判定。

---

## 3. 总体判定（一页结论）

### 3.1 一句话结论

**这不是一个音乐播放器，而是一个视觉完成度很高、但功能内核由内存 Mock 数据与假状态文案撑起来的 Flutter UI 演示程序（high-fidelity prototype），被包装成"Phase 0~6 全部 100% 交付的生产级跨平台音乐播放器"。**

### 3.2 三个致命结论

1. **不能发声。** 点播放后按钮变为暂停、进度条从 00:00 走到 00:11（约 10 秒），但扬声器没有任何声音，系统音量合成器里看不到该应用。进程 85 个模块中音频相关模块数为 **0**；`pubspec.yaml` 无任何音频依赖；进度由 `Timer.periodic(50ms)` 手工累加（`audio_player_service.dart:305-329`）。**【P0-01】**
2. **关掉就忘。** 重启实测：重启前"深色主题 + 绿色强调色（碧波翡翠）+ 4 首收藏 + 正在播放 00:11"；杀进程冷启动后变为"浅色主题 + 蓝色强调色（默认）+ 收藏恢复为默认 4 首 + 进度 00:00"。**收藏 / 播放历史 / 主题 / 强调色 / 光晕浓度 / EQ 全部归零**，因为 `shared_preferences` 虽在 `pubspec.yaml:41` 声明却在 `app/lib` 中 **0 次引用**。**【P0-02】**
3. **说得到做不到。** "已成功备份到云端""拉取完成！数据已合并""服务就绪""本机端口 18585 监听中""QuickJS""libmpv firequalizer""24bit/192kHz 无损直出""已同步红心收藏""拖拽导入""48.6 万播放""已探测到 2 台在线设备"——**全部为虚假声明**：或为硬编码字符串，或为 `Future.delayed(900ms)` 伪造的成功态，或指向从未被调用的死代码。**【P0-03 / P0-04 / P0-07 / P0-10】**

### 3.3 严重度统计表

| 严重度 | 条数 | 编号区间 | 性质概括 |
| :--- | :---: | :--- | :--- |
| **P0** | **12** | P0-01 ~ P0-12 | 核心能力不存在、数据安全欺骗、发布管道与产物身份破损、服务端可被单请求打死 |
| **P1** | **20** | P1-01 ~ P1-20 | 数据编造、交互死按钮、文档与实现矛盾、测试与 CI 假绿灯、工程卫生 |
| **P2** | **12** | P2-01 ~ P2-12 | 性能、渲染一致性、响应式、组件质量、可观测性 |
| **合计** | **44** | — | 本文档第 4 章逐条展开 |

### 3.4 "可直接对外演示的功能比例"估计（保守）

- **能渲染**：桌面 **14 个视图全部可从侧边栏进入并正常渲染，无异常白屏**（发现音乐 / 歌单广场 / 巅峰榜单 / 热门歌手 / 歌手详情 / 声音电台 / 我喜欢的音乐 / 导入与自建歌单 / 播放历史 / 本地与下载 / 多端同步中心 / LX 音源管理 / 个性化设置，+ 全屏歌词模式）。**该层"看起来"完成度接近 100%**，这也是本产物最容易被误判为可交付的原因。
- **真正端到端可用且数据真实的链路只有 3 条**：
  1. 网易云在线搜索（真实 HTTP，返回真实 `netease_<id>` 曲目）；
  2. 网易云歌单导入（实测返回"热歌榜 · 共解析成功 200 首高保真曲目"并真实入库）；
  3. LRC 歌词拉取与逐行渲染（真实 HTTP，LRC 解析器实测正确）。
- **且这 3 条全部受 P0-02 影响**：导入的歌单、搜索到的曲目，只要关掉应用就全部丢失；搜索到的曲目也**没有任何播放器消费其 audioUrl**。
- **结论**：按"端到端可用且数据真实"口径，可对外演示的比例 **约 3/14 ≈ 21%，且这 21% 也不完整**（不能发声、不能持久化）。按"能渲染"口径则接近 100%——**两个口径的差距，正是本次验收要传达的核心风险**。

### 3.5 必须写上的正面结论（避免报告只有负面）

1. **进程稳定性**：启动后持续轮询 24 秒无崩溃、无未响应；共加载 85 个模块。
2. **14 个桌面视图全部可正常渲染**，无白屏、无异常溢出（正常尺寸下）。
3. **队列抽屉可用**：6 首曲目、单曲移除 ✕、清空垃圾桶、关闭 ✕ 均生效。
4. **全屏歌词页可用**：旋转黑胶 + 逐行歌词 + 当前行高亮 + 进度 + 上一首/播放/下一首 + 红心，视觉效果与交互均正常（`16-fullscreen-lyrics.png`）。
5. **主题与强调色切换即时生效**且渲染正常：浅/深色切换正常，5 种强调色切换正常。
6. **歌手"关注/取消关注"按钮在本次会话内可切换**（仅内存态，见 P1-02）。
7. **弹窗点击遮罩可关闭**（实测睡眠定时器弹窗）。
8. **睡眠定时器弹窗功能完整**：15/30/45/60/90 分钟 + "播放完当前曲目后停止"。
9. **真实数据链路确实存在**：网易云搜索 / 歌单导入（实测 200 首真实入库）/ LRC 歌词三条链路真的联网、真的返回真实数据，失败时如实报错（"解析失败，请检查歌单ID或网络连接"），**不伪造数据**——这一点比同步中心诚实得多。
10. **移动端全屏播放页（黑胶 + 唱片/歌词切换 + EQ/睡眠定时入口）与"私人漫游 FM"页可作为 UI 正常打开**（`17-mobile-player-sheet.png`）。
11. 该机器对网易云接口的裸 HTTP 实测：搜索 API **200**、歌词 API **200**、歌单详情 API **200**，音频直链 `https://music.163.com/song/media/outer/url?id=...` 返回 **302**（并非可直接播放的音频流）。

---

## 4. 缺陷清单

> 编号严格沿用统一问题编号，共 44 条。每条给出用户可见现象、可复现步骤、证据（代码位置 `文件:行号` 与/或实测证据）、对应的文档声称、影响、严重度理由。

### 4.1 P0 级缺陷（12 条）

### [P0-01] 完全没有音频播放能力：点播放永远无声

- **用户可见现象**：点击播放按钮后按钮变为暂停、进度条从 00:00 走到 00:11（约 10 秒），但扬声器没有任何声音；打开系统音量合成器，**看不到该应用**在输出音频。
- **复现步骤**：
  1. 启动 `release_windows/app.exe`，置窗 1440x900@(0,0)；
  2. 在"发现音乐"页点击任意曲目播放；
  3. 观察按钮状态与进度条——会正常变化；
  4. 听扬声器、查系统音量合成器——无任何输出；
  5. 运行 §2.6 的模块查询命令——输出为空。
- **证据**：
  - 进程实测：85 个已加载模块中音频相关模块数 **0**（命令见 §2.6，输出为空）；
  - `app/pubspec.yaml:30-46` 无任何音频依赖（`media_kit|just_audio|audioplayers|audio_service` 在 pubspec 中 **0 命中**）；
  - 进度是手工累加：`app/lib/core/audio/audio_player_service.dart:305-329` `Timer.periodic(Duration(milliseconds: 50))` 每次 `_position + 50ms`；`play()` 只做 `_isPlaying = true; _startPositionTicker();`（`:129-134`），类中不存在任何播放器实例；
  - `Track.audioUrl`（`track_model.dart:55`）全库无任何读取方用于播放。
- **对应的文档声称**：`docs/SPEC.md:47` 声称"音频底座：media_kit (C 原生 libmpv，支持 FLAC/APE/DSD/Hi-Res 无损解码)"；`docs/SPEC.md:183` 声称"60Hz 表现层高刷流，直接订阅 player.stream.position"；`docs/PROGRESS.md:15` 声称 Phase 1"核心播放底座" **100%**。**均与实现不符**：无依赖、无解码器、无播放器实例。
- **影响**：产品的核心价值完全不成立。任何真实用户 3 秒内即可发现，属"产品定义级"失败；同时无系统媒体控制（SMTC/MediaSession）、无后台播放、无音频焦点、无 wakelock（`WakelockPlus|wakelock|audio_session` 在 `app/lib` **0 命中**），播放时设备会正常息屏。
- **严重度理由**：P0。这是被测产品的**唯一核心能力**，缺失即产品不成立，不属于可延后的缺陷。

### [P0-02] 零持久化：重启后收藏/历史/主题/强调色/EQ 全部归零

- **用户可见现象**：把主题改成深色、强调色改成绿色、红心 4 首歌、播放到 00:11；关掉应用再打开，**变回浅色主题 + 蓝色强调色 + 收藏仍是默认 4 首 + 进度 00:00**。用户的所有个性化与收藏行为在关闭瞬间蒸发。
- **复现步骤**：严格按 §2.5 的六步重启对比实验执行；对比 `11-before-restart-dark-green-4fav.png` 与 `12-after-restart-light-blue-defaultfav.png`。
- **证据**：
  - 重启对比实验（§2.5）实测：重启前后主题、强调色、收藏、进度四项全部回到初值；截图 `11-before-restart-dark-green-4fav.png`、`12-after-restart-light-blue-defaultfav.png`；
  - `app/pubspec.yaml:41` 声明了 `shared_preferences: ^2.5.5`，但 `app/lib` 内 `SharedPreferences|shared_preferences` **0 命中**（从未 import）；
  - 全部用户数据是内存字段：`audio_player_service.dart:19-22`（`_playlist` / `_playHistory` / `_favoriteIds` / `_importedPlaylists`）；`theme_provider.dart:6-8`（`_isDarkMode` / `_accentType` / `_glowIntensity`）；`equalizer_manager.dart:32`（`_bandGains`）；
  - 无本地数据库：`drift|sqlite|sqflite|openDatabase` 无任何实现，`app/lib/core/database/` 目录不存在。
- **对应的文档声称**：`docs/SPEC.md:115` 声称"配合 PageStorageKey 保证切换 Tab 或页面时不丢弃滚动状态与播放状态"（`PageStorageKey` 在 `app/lib` **0 命中**）；`docs/SPEC.md:56` 与 `:278-335` 声称 Drift(SQLite3+FTS5) 与 5 张表（`SongsTable` 等标识符全仓 **0 命中**）；`docs/SPEC.md:124` 声称歌手详情"关注/已关注**本地持久化**状态"；`docs/PROGRESS.md:5` 声称"Phase 0 ~ Phase 5 全量核心工程交付完毕"。**均与实现不符**。
- **影响**：数据可靠性为零。用户导入的 200 首真实歌单、收藏、历史、EQ 曲线、音源启用状态全部丢失；任何"个人曲库"类商业承诺（会员同步、跨端续听）在技术上不可能成立。副作用："已同步红心收藏 N 首"（`desktop_views.dart:1526`）在任何真实使用前即显示 ≥4，永久虚高。
- **严重度理由**：P0。用户数据丢失且用户无法通过任何操作规避，属数据安全层面的实质性缺陷。

### [P0-03] 云端同步/备份伪造成功：900ms 定时器冒充 WebDAV 同步

- **用户可见现象**：同步中心显示"云端端点: https://dav.jianguoyun.com/dav/""绑定账号: gaore@mellow.music""服务就绪"绿色徽标；点击"从云端恢复"，等待约 0.9 秒后状态变为"拉取完成！数据已合并"、显示"上次同步时间: 2026-09-22 18:14:32"，并弹出绿色提示"已成功从 WebDAV 云端合并最新快照数据！"——**但全过程没有任何网络请求**。
- **复现步骤**：
  1. 侧边栏进入"多端同步中心"（热区中心 y=645）；
  2. 点击"立即云端备份"，观察转圈约 0.9 秒后出现成功提示；
  3. 点击"从云端恢复"，同样约 0.9 秒后出现"拉取完成！数据已合并"与同步时间戳；
  4. 用抓包工具/进程网络监控观察该进程——**无任何出站请求**；
  5. 页面上寻找可修改服务器地址/账号/密码的入口——**不存在**。
- **证据**：
  - 截图 `06-cloud-restore-fake-success.png`、`05-sync-center-fake-devices.png`；
  - `app/lib/views/desktop/desktop_views.dart:1417-1435` 上传实现只有 `await Future.delayed(const Duration(milliseconds: 900))`（实测 `:1422`）后置 `_syncStatusText = '同步成功！已热备全量数据'` 并弹 SnackBar"已成功将本地播放数据、收藏及歌单备份至 WebDAV 云端！"（`:1432`）；
  - 恢复实现同构：`desktop_views.dart:1437-1455`（`Future.delayed` 在 `:1442`，SnackBar 在 `:1452`）；
  - 端点与账号硬编码：`desktop_views.dart:1414-1415` `_serverUrl = 'https://dav.jianguoyun.com/dav/'` / `_username = 'gaore@mellow.music'`，**页面无任何配置入口**；
  - "服务就绪"绿标是硬编码常量：`desktop_views.dart:1627-1632`（`Colors.green` + `Text('服务就绪')`）；
  - **关键反证**：项目里真实实现的 401 行 `WebDavSyncService`（含 PROPFIND/MKCOL/PUT/GET/LWW，`webdav_sync_service.dart`）在整个 App 中**0 个生产调用方**，仅被测试文件 import；`main.dart:12-17` 只注册 ThemeProvider / AudioPlayerService / EqualizerManager。
- **对应的文档声称**：`docs/SPEC.md:452`（E2E-06）要求"配置 WebDAV 地址与账号、点击探活、手动上传快照、一键恢复 → PROPFIND/PUT 全链路通畅，执行毫秒级 LWW 冲突解决，歌单数据零丢失"；`docs/PROGRESS.md:19` 声称 Phase 5"多端云同步" **100%**、`docs/PROGRESS.md:48` 声称"实现 WebDAV 客户端备份与还原逻辑"。**验收项要求的"配置入口"不存在，"全链路"未发起过一次请求**。
- **影响**：这是**数据安全层面的欺骗性功能**——比功能缺失更严重，因为它让用户误以为自己有了云端备份，从而放弃手动备份；换机/重装后数据为零，用户会归因于"同步失败"而反复尝试。对验收场景属实质性误导。
- **严重度理由**：P0。伪造成功反馈直接导致用户数据丢失风险，且用户无法察觉。

### [P0-04] 局域网 P2P 假设备 + 端口不符：绿点写死、服务从未启动

- **用户可见现象**：同步中心局域网板块列出两台"已探测到的在线设备"——"Gaore 的 iPhone 15 Pro · 在线 · IP: 192.168.1.103 · iOS 17.5 · Mellow v2.1.0"与"客厅立体声音响 (HomePod) · 在线 · IP: 192.168.1.108 · 无线音频接力"，均带绿色在线圆点；页脚显示"本机端口: 18585 监听中"；点"投送当前播放列表"只弹一个提示条。
- **复现步骤**：
  1. 进入"多端同步中心"；
  2. 观察局域网设备列表——两台设备恒为"在线"（无论局域网是否存在这些设备）；
  3. 用 `netstat -ano | findstr 18585` 与 `findstr 23332` 检查——**两个端口均无监听**；
  4. 点击"投送当前播放列表"——只弹出 SnackBar，无任何网络投送；
  5. 关闭/断开本机网络后重复步骤 2-4——表现**完全不变**。
- **证据**：
  - 截图 `05-sync-center-fake-devices.png`；
  - 设备名为硬编码 `Text`：`desktop_views.dart:1755`（iPhone 15 Pro）、`:1766`（IP/iOS 版本/App 版本）、`:1799`（HomePod）、`:1810`；绿色在线圆点为 `const BoxDecoration(shape: BoxShape.circle, color: Colors.green)`（`:1760` / `:1804`），"在线"文案 `:1763` / `:1807`；
  - 投送按钮只弹 SnackBar：`desktop_views.dart:1777`；
  - 端口文案与实现矛盾：`desktop_views.dart:1733` 写"本机端口: 18585 监听中"，而真实 `LanSyncServer` 默认端口是 **23332**（`app/lib/core/sync/lan_sync_service.dart:112`），且**从未启动**（`LanSyncService` 在整个 App 中仅被自身与测试引用，`main.dart` 未注册、无任何 `start()` 调用）。
- **对应的文档声称**：`docs/SPEC.md:339` 声称"桌面端监听 `0.0.0.0:23332`"；`docs/SPEC.md:354` 声称"电脑端生成标准二维码格式 `lxsync://192.168.x.x:23332?key=AUTH_KEY`，手机端扫码瞬间自动拉取增量合并"；`docs/SPEC.md:453`（E2E-07）要求"开启本机局域网服务、展示配对二维码、跨机握手投送快照"；`docs/PROGRESS.md:49` 声称"实现了基于端口 23332 的局域网直连同步互传服务，100% 兼容原生 LX-Sync 配对与报文流转协议"。**实际：UI 端口号与代码端口号不一致（18585 vs 23332），服务未启动，无二维码渲染（无 qr_flutter 依赖，无 dart:io WebSocket），设备数据全部编造。**
- **影响**：用户被引导相信存在可用的近场互传能力，实际无任何设备能发现或被投送。多端协同（产品的差异化卖点）在实现层为零；配合 P0-02，即便投送成功也无数据可投。
- **严重度理由**：P0。跨端能力是产品核心叙事之一，且此处为"伪造在线设备"式欺骗（比"功能未做"严重），同时 UI 展示的端口与代码不符，属自查即可发现的交付缺陷。

### [P0-05] Android release 缺 INTERNET 权限：线上包所有网络功能静默失效

- **用户可见现象**：Android release APK 安装到手机上后，封面/头像全部降级为灰色占位音符；搜索永远返回空；导入歌单永远提示"解析失败，请检查歌单ID或网络连接"。用户与测试都拿不到"权限不足"的错误提示。
- **复现步骤**（需 Android 环境，本次未实机执行）：
  1. 读 `app/android/app/src/main/AndroidManifest.xml`——**无任何 uses-permission**；
  2. 对比 `app/android/app/src/debug/AndroidManifest.xml:6` 与 `.../profile/AndroidManifest.xml:6`——各有一行 `<uses-permission android:name="android.permission.INTERNET"/>`，注释写明"required **for development**"；
  3. 交叉核对 `.github/workflows/release.yml:159-161` 执行的正是 `flutter build apk --release`（release 变体**不会合并** debug manifest）；
  4. 装机后观察网络请求——`SocketException` 被 `catch (_) {}` 静默吞掉（`online_music_service.dart:80/157/182`）。
- **证据**：静态证据（本环境无 Android 构建链）：`app/android/app/src/main/AndroidManifest.xml` 全文无 `uses-permission`（实测 `uses-permission` 在 `app/android` 下仅命中 debug/profile 两处，main 仅有 `android:label="app"`）；`release.yml:161` `flutter build apk --release`。**标注：未在真机/模拟器实机复现。**

- **对应的文档声称**：`docs/SPEC.md:5` 与 `docs/SPEC.md:424` 声称产物覆盖 Android(.apk)；`docs/SPEC.md:48` 与 `docs/SPEC.md:176-180` 声称 Android 侧具备 audio_service 系统通道与在线能力；`README.md:145` 声称移动端能力完整。**全部文档均未提及 release 变体缺失 INTERNET 权限这一事实。**
- **影响**：release APK 是一个完全离线的空壳，且异常被 `catch (_) {}` 静默吞掉——属最难排查的一类线上故障（用户看到"搜索无结果"，工程师看到"无报错"）。合规上，无法联网的"音乐播放器"上架后必然被大量差评/退款，且属应用商店审核关注项。
- **严重度理由**：P0。整平台产物在所有网络功能上 100% 失效，且无任何错误提示，属线上事故级。


### [P0-06] macOS release 缺 network.client entitlement：发布版所有出网请求被沙箱拒绝

- **用户可见现象**：macOS 发布版封面全灰、搜索无结果、同步无声失败，与 P0-05 表现一致。
- **复现步骤**（需 macOS 环境，本次未实机执行）：
  1. 读 `app/macos/Runner/Release.entitlements`——实测仅两个键：`com.apple.security.app-sandbox` = `true`（第 5-6 行）；
  2. 无 `com.apple.security.network.client`，无 `network.server`；
  3. 对照 `app/macos/Runner/DebugProfile.entitlements`（Flutter 模板在 debug 下默认放行 `network.client`）；
  4. 结论：release 构建开启 App Sandbox 却未授予任何网络客户端权限。
- **证据**：静态证据（本环境无 macOS）：`app/macos/Runner/Release.entitlements:5-6` 仅 `app-sandbox=true`。**标注：未在 macOS 实机复现。**
- **对应的文档声称**：`docs/SPEC.md:489-498` 声称 release.yml 进行 5 平台矩阵构建并发布；`docs/SPEC.md:424` 声称产物覆盖 macOS(.app)。**文档未提及 entitlement 缺失**。
- **影响**：macOS 发布版中 `Image.network`、`OnlineMusicService`（网易云搜索/歌单/歌词）、`WebDavSyncService` 的全部出站 HTTP 在沙箱层被拒，异常同样被 `catch (_) {}` 吞掉。与 P0-05 叠加，两个平台的"在线能力"在发布产物上双双归零。iOS 侧同类配置亦未发现网络相关声明，属待确认项。
- **严重度理由**：P0。与 P0-05 同性质，属整平台交付物不可用。

### [P0-07] "LX 音源管理 (QuickJS)" 是空壳，1836 行音源代码在生产不可达

- **用户可见现象**：页面标题写着"自定义音源管理 (QuickJS)"，页内只有一条硬编码的"内置综合聚合音源 (Built-in) v2.1.0 · 运行中"，右侧开关恒为"开"且**点了没反应**；"在线导入音源链接"按钮**点了完全无响应**。
- **复现步骤**：
  1. 侧边栏进入"LX 音源管理"（热区中心 y=691）；
  2. 点击右侧启用开关——状态不变，无任何反馈；
  3. 点击"在线导入音源链接"——无对话框、无报错、无反应（截图 `07-source-manager-empty-shell.png`）；
  4. 全仓检索 `flutter_js|quickjs|JavascriptRuntime`——唯一命中是页面标题这句 UI 文案本身。
- **证据**：
  - 截图 `07-source-manager-empty-shell.png`；
  - 页面仅 2 张 Card：`desktop_views.dart:1331-1398`；标题 `:1348`；空实现按钮 `:1357`；不可用开关 `:1391` `Switch.adaptive(value: true, ..., onChanged: (_) {})`；硬编码版本 `:1383` `'v2.1.0 · 运行中'`；
  - 无 JS 引擎依赖（`pubspec.yaml:30-46` 无 `flutter_js`/任何 JS 运行时）；
  - **1836 行音源代码在生产 0 引用**：`lx_script_sandbox.dart`(1204 行) + `lx_source_model.dart`(632 行)，在整个 `app/lib` 中无任何文件 import 它们，仅被 `app/test` 下测试文件引用；
  - 沙箱内部本身也是仿真：`PlatformPresetSourceDriver` 持有 `final List<LxSongInfo> _mockDatabase;`（`lx_script_sandbox.dart:354`）与 `final bool simulateFailure`(`:355`)，"解析出的直链"是拼字符串（`:204-205` / `:452` / `:646`）。
- **对应的文档声称**：`docs/SPEC.md:49` 声称"脚本沙箱：flutter_js (QuickJS 原生内存沙箱 + Dart Polyfill 桥接层)"；`docs/SPEC.md:204-207` 为"第 5 章 QuickJS 音源脚本沙箱与接口规范"；`docs/SPEC.md:448`（E2E-02）要求"聚合 6 大音源结果并发返回"；`docs/PROGRESS.md:16` 声称 Phase 2"音源沙箱与六维解析引擎" **100%**。**实际：无 JS 运行时，脚本物理上无法执行；引擎对最终用户 100% 不可见。**
- **影响**：用户看到的功能页没有任何可操作功能（不能导入、不能切换、不能停用）。1836 行代码进入仓库与 CI 编译/分析范围却对产品零贡献，属纯维护负债与"看起来做了很多"的假象；对投资/验收场景构成进度误导。
- **严重度理由**：P0。SPEC 中最"重"的两个交付物之一（QuickJS 沙箱）在真实 App 中为死代码，且 UI 以空壳冒充已完成，属虚假交付。

### [P0-08] 本地扫描/拖拽导入完全不可用，假本地曲目与假文件大小

- **用户可见现象**：本地与下载页赫然写着"拖拽音频文件或文件夹至此，或点击导入""支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式"，但点击"选择本地文件夹扫描"**毫无反应**（无系统文件对话框、无报错）；"已解析本地曲目"列表就是 6 首 mock 曲目，且**每一行都显示完全相同的 "FLAC 24bit/96kHz · 42.8 MB"**。
- **复现步骤**：
  1. 侧边栏进入"本地与下载"（热区中心 y=557）；
  2. 点击"选择本地文件夹扫描"——无任何反应（截图 `04-local-fake-metadata-dead-button.png`）；
  3. 观察下方"已解析本地曲目"列表——6 行副标题完全相同；
  4. 尝试把音频文件拖到页面的拖拽凹槽上——无任何反应。
- **证据**：
  - 截图 `04-local-fake-metadata-dead-button.png`；
  - 按钮为空实现：`desktop_views.dart:1170-1175` `SoftButton(label: '选择本地文件夹扫描', ..., onTap: () {},)`（实测 `:1174` 为 `onTap: () {}`）；
  - 文案：`desktop_views.dart:1166`（拖拽提示）、`:1168`（格式列表）；
  - 假元数据：`desktop_views.dart:1195` `Text('FLAC 24bit/96kHz · 42.8 MB')`，6 行全部同一常量；
  - 列表内容 = mock 曲目：`desktop_views.dart:1180-1202` 遍历 `mockPresetTracks`；
  - 无文件选择能力：`file_picker|file_selector|DragTarget|Directory(` 在 `app/lib` **0 命中**（实测）；无 `dart:io` 文件遍历（`dart:io` 仅出现在死代码 `lan_sync_service.dart:3`）。
- **对应的文档声称**：`docs/SPEC.md:57` 声称"缓存库：LRU 无损流式切片缓存、离线曲目归档目录"；`docs/SPEC.md:143` 声称移动端含"离线缓存清理"；`docs/PROGRESS.md:17` 声称 Phase 3"桌面端 12 视图 + 移动端 13 页面 1:1 落地" **100%**。**实际：无任何本地文件系统能力，无 file_picker 类依赖，无 DragTarget。**
- **影响**：用户无法导入自己的音乐——这是"本地播放器"的基本盘。同时"已解析本地曲目""FLAC 24bit/96kHz · 42.8 MB"对 6 首内存常量重复渲染，属编造元数据（移动端同类文案"已缓存 6 首无损音频 · 占用空间 182 MB"与 42.8MB×6 也自相矛盾）。
- **严重度理由**：P0。导入链路是产品的入口能力之一，此处为"死按钮 + 假数据"，用户第一分钟即可发现。

### [P0-09] 键盘交互全缺：Ctrl+K / ESC 等文案全部为假

- **用户可见现象**：界面顶栏有"Ctrl K"徽标，搜索框提示"搜索全网歌曲、歌手、专辑 (按 ESC 退出)..."，全屏歌词有"退出全屏 (ESC)"tooltip；但**在应用处于前台时按 ESC 与 Ctrl+K 完全无反应**。
- **复现步骤**：
  1. 置窗口前台（`SetForegroundWindow`）；
  2. `keybd_event(VK_ESCAPE)` 按下抬起（两次独立尝试）——搜索浮层不关闭、全屏歌词不退出；
  3. `keybd_event(VK_CONTROL)` + `'K'`——搜索浮层不弹出（只能靠鼠标点击搜索框打开）。
- **证据**：
  - 实测：ESC 与 Ctrl+K 均无反应（两次独立尝试）；
  - 代码：`Shortcuts|RawKeyboard|HardwareKeyboard|KeyboardListener|LogicalKeyboardKey|Focus(|onKeyEvent` 在 `app/lib` **0 命中**（实测，含宽口径 `RawKey|Keyboard|KeyEvent` 亦为 0）；
  - 三处假文案：`desktop_scaffold.dart:186`（"Ctrl K"徽标）、`modals.dart:567`（"按 ESC 退出"）、`fullscreen_lyrics_view.dart:104`（"退出全屏 (ESC)"）。
- **对应的文档声称**：`docs/SPEC.md:135` 声称全局联想搜索"快捷键 `Ctrl/Cmd + K` 呼出"；`README.md:62` 与 `docs/SPEC.md:135` 声称存在 Space/M/L/Q/Escape/Arrow 全局快捷键体系。**文档未提及"快捷键未实现"**。
- **影响**：桌面端产品的效率特征（键盘操作）为零；三处可见文案公然承诺不存在的交互，属"文案级欺骗"，用户按键无效后会立刻质疑产品完成度。
- **严重度理由**：P0（判定为"界面文案与实现矛盾"的最硬证据之一）。为零成本即可验证的虚假声明，直接摧毁验收可信度。

### [P0-10] 界面能力文案与实现矛盾（libmpv / firequalizer / 24bit 无损 / 服务就绪 / v2.1.0）

- **用户可见现象**：界面上密集出现"基于 libmpv firequalizer 高保真声学校准""声学 10 频段硬件均衡器 (DSP EQ)""精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出""FLAC 24bit/96kHz · 42.8 MB""已缓存 6 首无损音频 · 占用空间 182 MB""服务就绪""已同步红心收藏""本机端口: 18585 监听中""v2.1.0 · 运行中"等技术名词——**没有一条成立**。
- **复现步骤**：
  1. 依次打开：发现音乐、个性化设置、本地与下载、EQ 弹窗、多端同步中心、LX 音源管理；
  2. 逐条记录上述文案；
  3. 对照 `pubspec.yaml` 依赖清单与 `app/lib` 检索结果，逐条验证是否存在对应实现与调用方。
- **证据**（逐条对照，代码位置均已核实）：

| 文案 | 位置 | 事实 |
| :--- | :--- | :--- |
| 基于 libmpv firequalizer 高保真声学校准 | `modals.dart:207` | `libmpv` 在 `app/lib` 0 次出现；无音频引擎；EQ 滑块只改内存数组 |
| 声学 10 频段硬件均衡器 (DSP EQ) | `modals.dart:199` | 无 DSP、无硬件；`setBandGain` 仅写 `List<double>` |
| 精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出 | `desktop_views.dart:79` | 曲库实际 6 首（`track_model.dart:111-228`）；无解码器 |
| 支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式 | `desktop_views.dart:1168` | 无任何格式解析代码 |
| FLAC 24bit/96kHz · 42.8 MB | `desktop_views.dart:1195` | 硬编码字符串，6 行全同 |
| 已缓存 6 首无损音频 · 占用空间 182 MB | `mobile_pages.dart:611` | 硬编码，无缓存实现 |
| v2.1.0 · 运行中 | `desktop_views.dart:1383` | `pubspec.yaml:19` 真实版本 `1.0.0+1`；`PROGRESS.md:3` 又写 v1.0.0，三处互斥 |
| 服务就绪 | `desktop_views.dart:1632` | 硬编码常量（见 P0-03） |
| 已同步红心收藏 | `desktop_views.dart:1526` | 从未同步过（见 P0-02 / P0-03） |
| 本机端口: 18585 监听中 | `desktop_views.dart:1733` | 无监听；真实默认端口 23332（见 P0-04） |
| 高品质无损回放 | `mobile_pages.dart:86` | 无音频输出（见 P0-01） |

- **对应的文档声称**：`docs/SPEC.md:47`（media_kit/libmpv）、`docs/SPEC.md:191-193`（向 libmpv 动态挂载 lavfi 滤镜）、`docs/SPEC.md:451`（E2E-05 要求"实时生成 libmpv firequalizer 参数，音色变化平滑无咔嗒声"）、`docs/SPEC.md:449`（E2E-03"128k/320k/FLAC/24bit 母带"）。**这些文案正是文档声称的转述，而实现层为空。**
- **影响**：用户被明确告知具备其并不具备的能力，一旦试用即信任崩塌。对验收/投资场景属**实质性误导**，不是文案瑕疵；同时"v2.1.0/1.0.0/1.1.0"三处版本号互斥，合规上属产品身份不明。
- **严重度理由**：P0。这不是单点瑕疵，而是贯穿全界面的系统性虚假声明，直接决定"交付物是否可信"这一验收结论。

### [P0-11] 移动壳内置假 iOS 状态栏与 "Mobile" 调试角标

- **用户可见现象**：当窗口逻辑宽度 < 1024px 时桌面工作台被替换为移动端外壳，顶部出现一条**假的 iOS 状态栏**——时间恒为硬编码 "10:09"（实测当时真实系统时间为 17:59），信号/WiFi/电池均为装饰图标；"发现音乐"标题旁还有一个 "Mobile" 浅蓝调试角标。
- **复现步骤**：
  1. 启动应用，将窗口宽度缩至 < 1024px（如 430x860）；
  2. 观察顶部状态栏：时间显示 "10:09"，与系统时钟（实测 17:59）不符；电量图标恒为"充电中"；
  3. 观察"发现音乐"标题旁的 "Mobile" 角标（截图 `14-mobile-shell-fake-statusbar-overlap.png`）；
  4. 保持窗口等待 5 分钟——假时钟不会走。
- **证据**：
  - 截图 `14-mobile-shell-fake-statusbar-overlap.png`；
  - `app/lib/navigation/mobile_scaffold.dart:104-113`：`// 1. 左侧时间 (10:09)` + `Text('10:09', ...)`（实测 `:106`）；`:174-183` 为信号/WiFi/充电电池三个装饰 `Icon`；
  - "Mobile" 角标为 `const Text('Mobile', ...)`（`mobile_tabs.dart:72-90`，实测该处为常量）；
  - 该 Header 被放在 `SafeArea` 内，真机上会渲染在真实状态栏下方，形成"双状态栏"；
  - 测试把假状态栏当作验收标准：`mobile_prototype_1to1_test.dart:64-70` `expect(find.text('10:09'), findsOneWidget)`——**把 mock 固化为契约**。
- **对应的文档声称**：`docs/SPEC.md:140` 声称移动端"顶部灵动岛沉浸条"是正式设计；`docs/PROGRESS.md:29` 声称"完成移动端 390x844 原生 4-Tab 框架"。**文档未说明该状态栏是原型资产。**
- **影响**：灵动岛/状态栏是**纯原型资产**，属交付物污染生产包：真机上出现视觉穿帮（假时钟、假电量、假灵动岛覆盖真实 UI）。结合 P1-10（无最小尺寸约束），桌面用户只要把窗口拉窄就会看到移动壳，正常桌面使用路径上也会撞见。
- **严重度理由**：P0。原型资产进入生产包且以测试断言固化为"正确行为"，属交付边界失守；同时是"面向桌面用户"的产物却内置 iOS 装饰，产品定位矛盾。

### [P0-12] server.js 可被单条请求打死 + 目录穿越 + 0.0.0.0 + CORS 通配 + npm start 崩溃

- **用户可见现象**（交付仓库范围，不属于 `app.exe` 内容）：按 README"快速启动"执行 `npm start` 第一步即崩溃；启动起来的静态服务可被**任意一条畸形 HTTP 请求**打死后拒绝一切后续连接；可通过 URL 读取出工程根目录之外的任意文件，并读出 `.git/config`、`package.json`、`node_modules/**`；服务还监听在 `0.0.0.0` 且对所有响应（含敏感文件）返回 `Access-Control-Allow-Origin: *`。
- **复现步骤**：
  1. `node server.js` → 崩溃（`ReferenceError: require is not defined in ES module scope`，exit code 1）；
  2. 逐字节复制为 `.probe_server.cjs` 后启动，用原始 TCP socket 发送 `GET /%ZZ` / `GET /%00.html` / `Range: bytes=abc-` / `bytes=-500` / `bytes=100-50` / `bytes=99999999-` → 每次均使进程退出（`ECONNRESET`，随后 `ECONNREFUSED`）；
  3. 在工程根目录之外放置取证文件后请求 `GET /../qa_canary_secret.txt` → 返回 `200 OK` 与文件原文；`/..%5c...`、`/%2e%2e/...` 同样成功；
  4. `GET /.git/config` → `200 OK`，body 含 `[remote "origin"] url = ...`，响应头带 `Access-Control-Allow-Origin: *`。
- **证据**：`docs/audit/web-layer.md` 第 1 节 #1~#10 与第 2.5 节"实测命令与原始输出"（原始 TCP 响应原文、崩溃堆栈、`Content-Length` 实测值）。关键代码位置：`server.js:35`（`decodeURI` 无保护）、`server.js:40/44`（`path.join` 无 `path.resolve` 前缀校验）、`server.js:62-76`（Range `parseInt` 结果未校验即传入 `createReadStream`）、`server.js:25`（CORS 通配）、`server.js:88-89`（监听 `0.0.0.0`）、`package.json:5`（`"type":"module"` 与 `server.js:1` 的 `require()` 冲突）。
- **对应的文档声称**：`README.md:126-136` 的"快速启动"第 3 步要求 `npm start`；`README.md:5` 与 `README.md:109-113` 以 `83/83 Passed` 作为质量证据——而该结果**必须手工另起 8088 服务**（因 `npm start` 崩），文档未记录该前置条件。
- **影响**：① 未认证远程 DoS——任何浏览器/爬虫/恶意脚本一条请求即令本地服务失效；② 任意文件读取（配置、密钥、同盘其他工程源码），叠加 CORS 通配后可由任意网页远程读取并外传；③ 监听 `0.0.0.0` 使局域网内任意设备可读取上述文件；④ 文档宣称的一键启动路径第一步即断，属交付可用性缺陷。**风险等级：安全事件级，必须立刻修。**
- **严重度理由**：P0。安全缺陷（DoS + 任意文件读取）与"文档命令不可执行"叠加，且这是被 README 作为卖点的质量基础设施。

### 4.2 P1 级缺陷（20 条）

### [P1-01] 四榜单曲目池相同 + 静态更新文案

- **用户可见现象**：巅峰榜单页的四个榜单（飙升榜/热歌榜/新歌榜/原创榜）曲目池**几乎完全相同**（云水禅心/晚风告白/海阔天空/夜的第七章/City of Stars），仅顺序略有差别；每个榜单都写着"每日 09:00 更新 · 100 首""每周四更新 · 200 首"等更新承诺。
- **复现步骤**：进入"巅峰榜单"（热区中心 y=239），依次点开四个榜单，记录每榜 Top 5 曲名并对比（截图 `03-four-charts-same-tracks.png`）；记录各榜的更新文案。
- **证据**：截图 `03-four-charts-same-tracks.png`；`desktop_views.dart:354-387` 四榜为方法内局部常量数组（实测 `:356/364/372/380`），并含静态 `'update'` 文案；`:530-532` 用取模公式 `final trackIndex = (idx * 3 + i) % mockPresetTracks.length;` 从**同 6 首池**错位取 5 首，制造"不同榜单"的错觉；`:408-412`"播放全部榜单"播放的是同一套 6 首；移动端同构（`mobile_pages.dart:304,340-348`）。
- **对应的文档声称**：`docs/SPEC.md:122` 声称"官方巅峰榜：飙升/热歌/新歌/原创榜，前三名冠亚季军特殊徽章排位，支持一键整榜播放"。**文档未声明各榜曲目池应互不相同，但"100/200 首"的更新文案与四榜共享 6 首常量池的事实不符。**
- **影响**：榜单是内容型产品的核心流量位，"四榜同源 + 静态更新承诺（每日 09:00 / 每周四更新）"直接构成数据编造，用户点两个榜单即可发现。
- **严重度理由**：P1。数据编造但无数据丢失或安全后果。

### [P1-02] 歌手数据编造 / 头像张冠李戴 / 详情页共用同一份代表作 / 默认已关注

- **用户可见现象**：热门歌手 4 张卡片（巫娜/周杰伦/Beyond/伯远，粉丝数 86.4万 / 3890.2万 / 1240.8万 / 512.6万），头像为与艺人无关的 Unsplash 人像（巫娜=随机年轻女性照、周杰伦=黑人男性照、Beyond=西装白人男性照、伯远=林间男性照，肉眼即可判定张冠李戴）；进入任意歌手详情页，**头像固定、简介恒为"官方认证音乐人 · 粉丝量 189.4万 · 单曲播放突破 1.2 亿"、"代表作列表"恒为同一份 6 首 mock 曲目**，且默认就是"已关注"。
- **复现步骤**：进入"热门歌手"（热区中心 y=285），记录 4 张卡片的头像与粉丝数（截图 `02-artists-avatars-mismatched.png`）；依次点进 4 位歌手，对比头像/简介/代表作；观察"关注"按钮初始态；点击切换后返回再进入，观察是否复位。
- **证据**：截图 `02-artists-avatars-mismatched.png`；`desktop_views.dart:612-615`（4 位歌手 + 粉丝数硬编码）、`:643-649`（无条件"认证"蓝勾）、`:704`（所有歌手共用同一头像）、`:719`（简介恒为同一串，实测）、`:751-776`（代表作恒为 `mockPresetTracks`）、`:676` `bool _isFollowing = true;`（默认已关注，仅内存态，返回即重置）；头像张冠李戴经实际下载取样确认（`docs/audit/fake-data.md` §3.2 与 B4）。
- **对应的文档声称**：`docs/SPEC.md:123` 声称热门歌手页含"官方认证徽标、粉丝数量格式化与专页跳转"；`docs/SPEC.md:124` 声称歌手详情页含"关注/已关注**本地持久化**状态、精选代表作与专辑列表"。**"本地持久化"不成立（见 P0-02），"精选代表作"为全站共用常量，粉丝数在列表页（86.4万）与详情页（189.4万）自相矛盾。**
- **影响**：内容可信度归零。头像张冠李戴属艺人形象层面的不当使用，有肖像权合规风险。"默认已关注"让用户以为自己曾关注过，属状态欺骗。
- **严重度理由**：P1。多项数据编造 + 版权/肖像合规风险。

### [P1-03] 歌单广场实为单曲 + 播放量编造 + 图片复用

- **用户可见现象**：歌单广场卡片展示的是"歌曲名 + 歌手"而**不是歌单**；播放量"48.6万播放 / 129.4万播放 / 98.2万播放 / 34.1万播放"为编造；同一张"城堡"Unsplash 图既作为歌单封面又作为歌曲封面、Hero 大图、电台封面在多个页面复用；7 个分类标签切换只改高亮、不过滤数据。
- **复现步骤**：进入"歌单广场"（热区中心 y=193），观察卡片标题格式与播放量；点击任意卡片，观察实际播放内容（是单曲而非歌单）；依次点 7 个分类标签，观察列表是否变化；跨多个页面比对同一张封面图。
- **证据**：`desktop_views.dart:144-172`（4 张"甄选歌单"卡片 + 硬编码播放量）、`:149/156/163/170`（点击播放 `mockPresetTracks[0..4]` 单曲）、`:273-274`（7 个分类标签）、`:303`（切换只改高亮）、`:310-338`（网格 `itemCount: mockPresetTracks.length`，所谓"歌单"即 6 张单曲卡片）；图片复用矩阵见 `docs/audit/fake-data.md` §3.1（`photo-1518709268805` 城堡照共 10 处复用，同时充当古琴曲封面、华语流行歌单封面、助眠电台封面与艺人头像）。**注：本项未单独存证截图，证据为代码 + 审计报告。**
- **对应的文档声称**：`docs/SPEC.md:121` 与 `docs/SPEC.md:120-131` 将歌单广场列为独立内容模块；`docs/SPEC.md:292-331`（歌单表结构）。**文档未说明该页实为单曲列表，也未说明播放量无数据源。**
- **影响**：歌单是音乐产品的核心组织单元，此页无歌单实体；"播放量"无数据源；封面图张冠李戴（同一张城堡照承担 4 种语义）。属内容层信任崩塌。
- **严重度理由**：P1。数据编造，不影响数据安全。

### [P1-04] 播放历史冷启动自插 1 条且无移除/清空

- **用户可见现象**：首次启动进入"播放历史"，即显示"已记录最近 1 首曲目"，内容为用户**从未播放过**的《云水禅心》；页面上**没有任何移除/清空按钮**。
- **复现步骤**：冷启动应用（不播放任何歌）→ 侧边栏进入"播放历史"（热区中心 y=511）→ 观察已有 1 条记录及其内容 → 在页面内寻找单曲移除 ✕ 与一键清空入口（截图 `19-history-no-clear-button.png`）。
- **证据**：截图 `19-history-no-clear-button.png`；构造函数在启动时硬塞一条假历史：`audio_player_service.dart:76-80` `AudioPlayerService() { if (_playlist.isNotEmpty) { _recordHistory(_playlist[0]); } }`（实测 `:78`）；历史页仅一个标题行 + `...player.playHistory.map(...)` 列表（`desktop_views.dart:1098-1142`，实测全文无移除/清空控件，仅 `:1114` 一处统计文案）。
- **对应的文档声称**：`docs/SPEC.md:127` 声称"播放历史：按播放时间戳倒序呈现完整足迹，**支持单曲移除与一键清空**"。**文档明确声称的两项操作均不存在。**
- **影响**：用户零操作即产生"播放足迹"，隐私观感差；无法删除任何记录，是明确的文档承诺落空。数据层本身可用（去重 + 50 条上限逻辑真实，`audio_player_service.dart:296-302`），即"有实现、未接线 UI"。
- **严重度理由**：P1。文档明文承诺的功能完全缺失 + 冷启动伪造用户数据。

### [P1-05] 收藏硬编码预置 4 首

- **用户可见现象**：首次启动（用户从未收藏任何歌曲）进入"我喜欢的音乐"，即显示"共收藏 4 首心动单曲"，内容为 云水禅心/海阔天空/City of Stars/起风了。
- **复现步骤**：冷启动应用 → 进入"我喜欢的音乐"（热区中心 y=419）→ 观察收藏数量与曲目（截图 `20-favorites-default-hardcoded.png`）→ 核对这 4 首是否由用户操作产生。
- **证据**：截图 `20-favorites-default-hardcoded.png`；`audio_player_service.dart:21` `final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};`（= 云水禅心/海阔天空/City of Stars/起风了）；另有 4 首在模型层直接写死 `isFavorite: true`（`track_model.dart:120/160/200/217`）；文案 `desktop_views.dart:891`"共收藏 4 首心动单曲 · 实时云端同步"。红心功能本身会话内可用（`audio_player_service.dart:207-218`）。
- **对应的文档声称**：`docs/SPEC.md:129` 等文档**均未提及预置收藏**（即"文档未提及"）；`desktop_views.dart:891` 自称"实时云端同步"，与 P0-03 直接矛盾。
- **影响**：伪造用户个人数据（收藏）比伪造内容数据更敏感——用户会怀疑产品擅自操作其账号。叠加"实时云端同步"文案与 P0-02，构成双重误导。
- **严重度理由**：P1。伪造用户数据 + 虚假同步声明。

### [P1-06] 设置中心仅 3 项，缺音质/缓存等

- **用户可见现象**：个性化设置页只有 3 个板块——外观与主题质感（浅色/深色分段控件）、声学柔光强调色（5 色）、动态声学弥散光晕浓度（65% 滑块）。**没有**音质首选项、离线缓存清理、快捷键说明、关于等。
- **复现步骤**：进入"个性化设置"（热区中心 y=733）；逐项清点页面内容（截图 `10-dark-mode-settings.png`）；尝试寻找音质偏好/缓存清理入口——不存在。
- **证据**：截图 `10-dark-mode-settings.png`；`desktop_views.dart:1209-1328` 全量内容 = 3 张卡片（外观 `:1225-1255`、强调色 `:1259-1299`、光晕浓度 `Slider` `:1303-1324`）；无缓存目录与清理逻辑（`path_provider` 已声明但 `app/lib` **0 引用**，实测）。
- **对应的文档声称**：`docs/SPEC.md:129` 声称设置中心含"深浅色切换、5 大强调色圆盘、弥散光晕浓度滑块、**音源管理与音质首选项**"；`docs/SPEC.md:143` 声称移动端"我的"含"音质偏好与离线缓存清理"。**4 项声称中 3 项落地（深浅色/5 色/浓度），音源管理与音质首选项不在设置页，缓存清理在两端均无。**
- **影响**：设置项缺失使产品无法提供音质选择与存储管理，与"无损母带/离线缓存"叙事直接冲突（配合 P0-08）。
- **严重度理由**：P1。文档承诺项缺失，用户可感知。

### [P1-07] 搜索面板初始结果 = 本地 mock、"按 ESC 退出"无效、网络失败静默

- **用户可见现象**：点击搜索框可打开搜索浮层；**未输入任何关键词，结果列表已经列出 6 首本地 mock 曲目**，却显示在"搜索全网歌曲、歌手、专辑"的输入框下；输入框提示写着"按 ESC 退出"，但 ESC 键实测无效；输入关键词后**会真的发起网络搜索**，但网络失败时静默降级为本地结果，无任何失败提示。
- **复现步骤**：点击顶栏搜索框打开浮层（截图 `09-search-overlay-local-results.png`）→ 观察初始结果列表 → 按 ESC 尝试关闭（无效）→ 输入"周杰伦"等关键词，观察 350ms 防抖后是否发起网络请求 → 断网重试，观察是否有失败提示。
- **证据**：截图 `09-search-overlay-local-results.png`；`modals.dart:478-481` `initState() { ... _results = mockPresetTracks; }`（实测 `:480`）；`:495-501`（清空输入后同样回落 mock）；`:567` `hintText: '搜索全网歌曲、歌手、专辑 (按 ESC 退出)...'`；`:516-533`（350ms 防抖 → `OnlineMusicService.searchOnlineTracks`，真实联网）；`:519-532` 在线搜索失败时 `if (onlineSongs.isNotEmpty)` **无 else**，静默保持本地结果；`online_music_service.dart:78-84` `catch (_) { ... }` 静默返回空数组。快捷标签为 周杰伦/告五人/落日飞车/陈奕迅/轻音乐/粤语经典（`modals.dart:475`，硬编码，非热搜榜）。
- **对应的文档声称**：`docs/SPEC.md:135` 声称"全局联想搜索：快捷键 `Ctrl/Cmd + K` 呼出，毫秒级聚合联想歌手、歌单与单曲"；`docs/SPEC.md:448`（E2E-02）要求"聚合 6 大音源结果并发返回，列表去重，关键词高亮"。**"Ctrl/Cmd+K 呼出"不成立（P0-09），"聚合 6 大音源"不成立（只 1 个真实源 + 本地 mock）。**
- **影响**：搜索是唯一真正联网的入口之一，但初始结果伪造 + 无失败提示，用户无法区分"没搜到"与"网络坏了"。**值得肯定的是：失败时不伪造新数据**（不像 P0-03/04 造假成功），但无提示仍是可用性缺陷。
- **严重度理由**：P1。交互缺陷 + 无错误可观测性。

### [P1-08] 声音电台卡片点击播放无关歌曲、无单集概念

- **用户可见现象**：声音电台 4 张卡片（深夜治愈故事馆/助眠白噪音与雨声/音乐背后的人文故事/科技前沿早知道），点击任意卡片实际播放的是 `mockPresetTracks[idx]`（与卡片主题无关的歌曲）；没有"单集/节目"概念，也没有可播放的音频。
- **复现步骤**：进入"声音电台"（热区中心 y=331）→ 点击"助眠白噪音与雨声"→ 观察实际播放的曲目名（与卡片主题无关）→ 尝试寻找单集列表/主播/时长概念（截图 `18-podcast-dead-cards.png`）。
- **证据**：截图 `18-podcast-dead-cards.png`；`desktop_views.dart:792-797`（4 个节目为文案常量）、`:818-821` `player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);`；移动端同构（`mobile_pages.dart:369-374`）。
- **对应的文档声称**：`docs/SPEC.md:126`（`viewPodcast` 声音电台）将其列为内容模块。**文档未给出单集模型要求，也未说明点击行为是播放单曲。**
- **影响**：电台/播客是长音频内容形态，此处既无音频（P0-01）也无内容模型（无单集、无时长、无主播），属内容形态缺失 + 交互错配。
- **严重度理由**：P1。用户在正常路径上会立即发现"点播客放的是歌"。

### [P1-09] EQ 第 5 个预设被裁切不可见、EQ 无 DSP 链路

- **用户可见现象**：EQ 弹窗有 10 频段滑块（31Hz…16kHz）与预设胶囊行；预设行超出弹窗可视宽度——第 4 个"温润爵士 (Warr"被视口边缘截断、第 5 个"全景声场 (Spatial 3D)"在 1440px 窗口下**完全不可见**，且**没有任何可横向滚动的提示**（无滚动条、无渐隐、无箭头）。
- **复现步骤**：打开 EQ 弹窗 → 观察预设胶囊行右端（截图 `08-eq-modal-preset-clipped.png`）→ 尝试横向滚动（无任何可滑动提示，用户无法感知）→ 拖动任意频段滑块，听感无任何变化。
- **证据**：截图 `08-eq-modal-preset-clipped.png`；`modals.dart:199-240` 预设行**确实包在横向 SingleChildScrollView 中**（实测 `:224-225`，即"技术上可滚、体验上不可发现"，属可用性缺陷而非纯缺失）；预设共 **6 项**（`equalizer_manager.dart:4-14`：flat / bassBoost / clearVocal / warmJazz / spatial3d / custom，第 4 项 label 为"温润爵士 (Warm Jazz)"、第 5 项为"全景声场 (Spatial 3D)"）；**EQ 无 DSP 链路**：`equalizer_manager.dart:81-92` `toLibmpvFilterString()` 只拼接字符串，在 `app/lib` 内 **0 个生产调用方**（仅测试断言其字符串格式）。
- **对应的文档声称**：`docs/SPEC.md:451`（E2E-05）要求"呼出均衡器弹窗、切换 **9 款**声学预设、手动拖拽 10 频段滑块 → 图形滑块阻尼触感灵敏，**实时生成 libmpv firequalizer 参数**，音色变化平滑无咔嗒声"；`README.md:60` 又称"5 大预设"；`modals.dart:199/207` 弹窗自称"硬件均衡器 (DSP EQ)""基于 libmpv firequalizer"。**预设数量三处口径不一（SPEC 9 / README 5 / 实际 6），且 firequalizer 参数从未被应用到任何播放器。**
- **影响**：EQ 是音频产品的关键差异化功能，此处对声音零影响（即便 P0-01 修好，EQ 也不会生效，因为方法无调用方）；预设不可发现使实际可感知项从 6 降到 3-4。SPEC 的 E2E-05 验收项无法通过。
- **严重度理由**：P1。功能不可用 + 预设数量文档自相矛盾 + 已写出但未接线的 DSP 代码。

### [P1-10] 窗口无最小尺寸约束、<1024px 退化为移动壳、极小尺寸布局崩坏

- **用户可见现象**：应用**没有最小窗口尺寸约束**，可被拖到任意小。窗口逻辑宽度 < 1024px 时，桌面工作台被替换为**移动端外壳填满桌面窗口**；实测 430x860 时移动壳可渲染，但底部悬浮迷你播放胶囊**遮挡了下方"新碟与精选专栏"卡片及其文字**；420x420 时更差；220x200 时布局严重重叠错乱。
- **复现步骤**：将窗口拖到 430x860 → 观察到移动壳与胶囊遮挡（截图 `14-mobile-shell-fake-statusbar-overlap.png`）；继续缩到 420x420、220x200 → 观察布局重叠错乱（截图 `15-tiny-window-layout-broken.png`）；尝试找到窗口最小尺寸限制——不存在。
- **证据**：截图 `14-mobile-shell-fake-statusbar-overlap.png`、`15-tiny-window-layout-broken.png`；`app/windows/runner/win32_window.cpp` 无 `WM_GETMINMAXINFO` / `kMinSize`（实测 `app/windows` 下 `windowManager|setMinimumSize|WM_GETMINMAXINFO|kMinSize` **0 命中**）；断点 `app/lib/navigation/adaptive_scaffold.dart:14` `constraints.maxWidth >= 1024`。
- **对应的文档声称**：`docs/SPEC.md:447`（E2E-01）要求"无边框标题栏交互……最大化/最小化、关闭、深浅色模式切换"（隐含需有尺寸约束与可用的小窗行为）；`docs/SPEC.md:115` 称断点为 `1024px`，而 `docs/SPEC.md:454`（E2E-08）又称"跨越 **800px** 阈值"——**同一文档两个阈值自相矛盾**。
- **影响**：桌面用户在正常使用（分屏、并排）时极易触发移动壳，产生"桌面软件里出现手机界面"的严重体验错位；极小尺寸下布局崩坏属可复现的渲染缺陷。
- **严重度理由**：P1。核心体验路径缺陷 + 文档阈值自相矛盾。

### [P1-11] 原生标题栏与全平台产物名为模板默认值 "app"

- **用户可见现象**：系统原生标题栏文字为 **"app"**；同时应用内部又自绘了一套标题栏，形成"双标题栏"。安装后系统各处（任务栏、进程、安装记录）显示的名称均为 "app"。
- **复现步骤**：启动应用 → 用 Win32 `GetWindowText` 读取窗口标题（实测返回 `'app'`）、`GetClassName`（实测 `FLUTTER_RUNNER_WIN32_WINDOW`）→ 观察窗口顶部同时存在系统标题栏与应用自绘标题栏（截图 `01-launch-window-title-app.png`）→ 查看任务栏/任务管理器显示名称。
- **证据**：截图 `01-launch-window-title-app.png`；`GetWindowText` 实测 `'app'`；`app/windows/runner/main.cpp:30` `window.Create(L"app", origin, size)`；`app/windows/CMakeLists.txt:3` `project(app ...)`、`:7` `set(BINARY_NAME "app")`；Android `app/android/app/src/main/AndroidManifest.xml:3` `android:label="app"`（实测）；macOS `app/macos/Runner/Configs/AppInfo.xcconfig:8` `PRODUCT_NAME = app`（实测）。
- **对应的文档声称**：`docs/SPEC.md:467` 与 `docs/SPEC.md:439` 给出的产物名是 `mellow_music.exe`；`docs/PROGRESS.md:31` 声称"将项目正式命名为 **Mellow Music · 润音**"（品牌重塑已完成）。**实际产物名 app.exe，窗口标题 "app"，六端应用名均未品牌化。**
- **影响**：用户安装一个叫 "app" 的软件，会对来源与安全性产生怀疑；商店/上架审核会因应用名与品牌不符被拒；与"品牌重塑已完成"的声明直接矛盾。
- **严重度理由**：P1。交付物身份与合规问题，用户第一眼可见。

### [P1-12] release.yml macOS 打包名不匹配导致发版流水线跑不通

- **用户可见现象**（交付仓库范围）：打 `v*` 标签触发发版流水线，macOS 构建在"Package macOS Binary"步骤失败，发版流程中断。
- **复现步骤**（需 macOS Runner，本次为静态核对）：
  1. 读 `app/macos/Runner/Configs/AppInfo.xcconfig:8` → `PRODUCT_NAME = app`（实测），即构建产物为 `app.app`；
  2. 读 `.github/workflows/release.yml:80-82` → `ditto -c -k --sequesterRsrc --keepParent app/build/macos/Build/Products/Release/mellow_music.app Mellow-Music-macOS.zip`（实测 `:82`）；
  3. 结论：打包源路径 `mellow_music.app` 与实际产物 `app.app` 不匹配，`ditto` 必然失败。
- **证据**：上述两处代码（均已实测核对）；另 `release.yml:56` 的 job 名为 `Build macOS Universal`、`:57` 为 `runs-on: macos-14`（arm64），`:78` 为 `flutter build macos --release`（**无 universal 参数**），故产物必然单架构，"Universal"名不符实。**标注：未在 macOS Runner 实机执行流水线。**
- **对应的文档声称**：`docs/SPEC.md:489-498` 声称 release.yml 完成 5 平台矩阵构建并聚合发布；`docs/PROGRESS.md:20` 声称 Phase 6"GitHub Actions 矩阵发版流水线" **100%**；`docs/PROGRESS.md:55` 声称"自动编译 Windows (x64 ZIP)、macOS (Universal ZIP)、Linux (tar.gz)、Android (APK) 与 Web (ZIP) 产物并自动发布"。**"macOS Universal ZIP 自动发布"不成立。**
- **影响**：发版流水线是交付闭环的最后一环，此处断裂意味着"永远发不出官方 Release"（或只能手工绕过）。"Universal"命名误导 Intel Mac 用户。
- **严重度理由**：P1。交付管道不可用，属发布阻塞级。

### [P1-13] CI 未固定 Flutter 版本、flutter_e2e_verify.mjs 零断言、CI 不跑 83 项原型 E2E

- **用户可见现象**（交付仓库范围）：CI 绿灯**不反映功能正确性**——页面白屏、路由全坏、渲染崩溃（只要不抛 page error）都会"通过"；README 的 `83/83 Passed` 徽章是静态文本，无任何门禁保护。
- **复现步骤**：
  1. 读 `.github/workflows/ci.yml:20` 与 `:60` → 均为 `channel: 'stable'`，**无 flutter-version 固定**（实测）；
  2. 读 `ci.yml:48` → `run: node flutter_e2e_verify.mjs`，而该脚本只做 `goto` + 等 canvas + `screenshot` + 无条件打印 PASS，全文无 `assert`/`expect`；
  3. 全 workflow 检索 `e2e_test.js` → **0 命中**，即 83 项原型套件不在 CI 中运行；
  4. 让产物缺失（例如不执行 `flutter build web`）再跑该脚本 → 仍打印"100% 通过"。
- **证据**：`ci.yml:20/60`（未固定版本）、`ci.yml:48`（调用零断言脚本，实测）；`docs/audit/web-layer.md` #13/#14/#15/#11（`flutter_e2e_verify.mjs` 零断言、关键等待被 `catch (_) {}` 吞掉、产物缺失也报 PASS、CI 从不运行 `e2e_test.js`、含 3 处硬编码坐标点击）。
- **对应的文档声称**：`docs/SPEC.md:486` 与 `docs/PROGRESS.md:57` 声称"真实浏览器端到端渲染挂载验收""零未捕获异常"；`docs/SPEC.md:415-435,464` 将"未捕获异常必须为 0"列为硬性质量红线；`README.md:5` 以 `83/83` 作为质量证据。**"硬性红线"无任何技术手段兜底。**
- **影响**：最严重的"假绿灯"——质量结论不可信，属虚假验收材料。未固定 Flutter 版本使构建结果随上游渠道漂移，随时可能无故变红/变绿。
- **严重度理由**：P1。质量门禁失效，直接影响"是否可发布"的判断依据。

### [P1-14] 测试断言 mock 自身 / 条件断言 / 两测试文件逐行重复、声称 47 实际 77

- **用户可见现象**（交付仓库范围）：文档宣称的测试通过数（47/47）与实际用例数（77）不符；其中两个测试文件**整整 279 行逐行完全相同**；部分断言的判据是 mock/死代码自身。
- **复现步骤**：
  1. 统计用例：`Get-ChildItem app/test,app/integration_test -Recurse -Filter *.dart` 分别计数 `^\s*test(` 与 `^\s*testWidgets(`；
  2. 比对两文件：`Compare-Object (Get-Content client_e2e_user_journey_test.dart) (Get-Content app_client_e2e_test.dart)`；
  3. 查断言对象：EQ 相关断言的判据是 `toLibmpvFilterString()` 生成的字符串格式，而该方法无生产调用方。
- **证据**：实测计数 **test=44 + testWidgets=33 = 77**（分文件：lx_source_engine 25、sync_services 15、client_e2e_journey 8、integration 8、mobile_prototype 6、comprehensive 4+3、alger_features 3、modals_and_lyrics 3、toplist_and_sync 2）；实测比对：`app/test/client_e2e_user_journey_test.dart` 与 `app/integration_test/app_client_e2e_test.dart` 各 279 行，**279/279 行全部相同**；`eq` 断言位置 `app/test/mellow_music_comprehensive_test.dart:130-132`、`client_e2e_user_journey_test.dart:156-158`、`app/integration_test/app_client_e2e_test.dart:156-158`；且 `integration_test/` 目录下 8 个 `testWidgets` **默认不被 flutter test 执行**。
- **对应的文档声称**：`docs/PROGRESS.md:5` 与 `:60` 声称"全工程 **47 项**单元与集成测试用例 100% 通过"；`docs/SPEC.md:484` 要求 **55/55** Suites；`docs/PROGRESS.md:54` 声称 CI"包含客户端原生全链路 E2E 旅程测试"。**实际 77 个用例，三处数字全部不符，且 CI 从未运行 integration_test。**
- **影响**：测试数量与文档不符使"100% 通过"失去意义；两个文件逐行重复意味着测试覆盖是**虚增的**（同一份测试被计两次）；断言 mock 自身使死代码看起来是活的（维护者会误判 EQ 已打通）。
- **严重度理由**：P1。验收证据链本身失真。

### [P1-15] pubspec 8/11 依赖未使用 + 缺关键依赖 + PingFang SC 在 Windows 无效

- **用户可见现象**（工程层）：11 个依赖中有 8 个不参与任何业务逻辑；同时缺失音频、JS 引擎、数据库、文件选择等关键依赖；应用字体指定为 `PingFang SC`，该字体在 Windows 上不存在，实际渲染回退到默认字体。
- **复现步骤**：读 `app/pubspec.yaml:30-46` 列出 11 个依赖；逐个在 `app/lib` 检索引用；读 `app/lib/main.dart:42` 与 `:52` 的 `fontFamily`。
- **证据**：`pubspec.yaml:36-46` 共 11 个依赖（cupertino_icons / google_fonts / provider / go_router / intl / shared_preferences / http / dio / crypto / path_provider / path）；实测 `app/lib` 中 `google_fonts|GoogleFonts` **0 命中**、`GoRouter|GoRoute` **0 命中**、`intl|DateFormat` **0 命中**、`SharedPreferences` **0 命中**、`package:dio|Dio(` **0 命中**、`path_provider|getApplicationDocuments` **0 命中**、`package:path` **0 命中**，`package:crypto` 仅 1 处且位于死代码 `lx_script_sandbox.dart:3`；关键依赖缺失：`media_kit|just_audio|audioplayers|audio_service|flutter_js|drift|sqlite|file_picker` 在 pubspec 中 **0 命中**（实测）；字体 `main.dart:42/52` `fontFamily: 'PingFang SC'`。
- **对应的文档声称**：`docs/SPEC.md:47-58` 列出了应当存在的技术栈依赖；`docs/SPEC.md:384` 声称存在 `core/database/` 目录。**依赖清单与规格书不符。**
- **影响**：零引用依赖会被审计/合规视为"僵尸依赖"；字体在 Windows 无效意味着设计规范（温润白瓷观感）在目标平台上不可达，两端观感漂移。
- **严重度理由**：P1。工程基础不实 + 目标平台字体失效。

### [P1-16] 50ms ticker 驱动 20Hz 全树 rebuild + 常驻模糊

- **用户可见现象**：播放期间界面持续高频重绘；滚动列表、切页时可见轻微卡顿感；窗口在空闲与播放时都有明显的背景模糊开销（GPU 占用偏高）。
- **复现步骤**：启动播放 → 观察任务管理器 GPU/CPU 占用随播放上升；对照代码判断 rebuild 粒度（本环境无 Flutter CLI，未能用 DevTools 量化，**性能量化部分标注未执行**）。
- **证据**：`audio_player_service.dart:307` `Timer.periodic(const Duration(milliseconds: 50))` 每 50ms 调用一次 `notifyListeners()`（`:327`），即 **20Hz**；而 `AudioPlayerService` 是根级 Provider，各视图通过 `context.watch<AudioPlayerService>()` 订阅（如 `desktop_views.dart:1105`），**进度变化会触发整棵子树 rebuild**；常驻模糊：`app/lib/design_system/acoustic_mesh_glow.dart:82-83` `BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70))`（实测存在）。
- **对应的文档声称**：`docs/SPEC.md:183` 声称"60Hz 表现层高刷流，**直接订阅 player.stream.position**"（即只驱动叶子组件）；`docs/SPEC.md:254-256` 声称光晕由封面取色驱动（`acoustic_mesh_glow.dart:26-33` 实际使用主题色 + 两个硬编码色）。**实际是全树 rebuild + 硬编码色常驻模糊。**
- **影响**：性能与耗电问题；在低端设备上会导致播放期间整体掉帧。文档承诺的"订阅 position 流"架构（细粒度重建）未落地。
- **严重度理由**：P1。架构级性能缺陷，随曲库/复杂度增长会迅速恶化。

### [P1-17] 无 go_router / 无路由栈 / 无 PageStorageKey，前进按钮空实现

- **用户可见现象**：顶栏有前进/后退按钮，但**后退永远跳回"发现音乐"**（不按浏览顺序返回），**前进是死按钮**（点了完全无反应）；切换页面后返回，滚动位置与筛选状态不保留；Web 端无法通过 URL 直达任意页面。
- **复现步骤**：进入"发现音乐"→ 进入"巅峰榜单"→ 进入"热门歌手"→ 点后退（回到"发现音乐"而非"巅峰榜单"）→ 点前进（无反应）；在列表页滚动到中部后切换页面再返回，观察滚动位置。
- **证据**：`desktop_scaffold.dart:25` `String _activeView = 'discover';` + `_navigateTo()`(`:30-37`) + `switch`（`:334-358`，实测为字符串 switch），**无路由栈**；前进按钮为空实现：`desktop_scaffold.dart:149` 图标 `Icons.chevron_right_rounded` + `:153` `onTap: () {}`（实测）；`GoRouter|GoRoute|context.go(|context.push(` 在 `app/lib` **0 命中**（实测）；`PageStorageKey` 在 `app/lib` **0 命中**（实测）。
- **对应的文档声称**：`docs/SPEC.md:115` 声称"所有视图采用**强类型路由 (go_router)**，并配合 `PageStorageKey` 保证切换 Tab 或页面时不丢弃滚动状态与播放状态"；`docs/SPEC.md:118-157` 列出 34 个路由路径。**依赖已声明（`pubspec.yaml:39`）但 0 引用，`app_router.dart` 不存在。**
- **影响**：桌面应用的导航预期（可预期的返回、前进）被破坏；状态丢失使长列表浏览体验差；Web 端无深链接能力，与"PWA"叙事冲突。
- **严重度理由**：P1。核心导航交互缺陷 + 文档架构描述失真。

### [P1-18] 可访问性缺失（0 Semantics）

- **用户可见现象**：屏幕阅读器（Windows 讲述人 / NVDA）无法读出任何控件名称——所有按钮、列表项、滑块对辅助技术不可见；键盘 Tab 焦点也无法用于操作（配合 P0-09）。
- **复现步骤**：启动讲述人/NVDA → 用 `Tab`/方向键尝试浏览界面 → 观察无任何朗读输出。
- **证据**：`Semantics|semanticLabel|ExcludeSemantics` 在 `app/lib` **0 命中**（实测）。
- **对应的文档声称**：`docs/SPEC.md` 全文与 `README.md` **均未提及可访问性要求**，即"文档未提及"。此处按通用交付标准（WCAG / 平台无障碍规范）判定为缺陷。
- **影响**：视障用户完全无法使用；对有政府采购、教育、企业采购场景的产品构成合规门槛（无障碍常为硬性要求）。
- **严重度理由**：P1。整类用户不可用 + 合规风险；文档未提及，说明需求侧也遗漏了该维度。

### [P1-19] 硬编码第三方私有接口 + 明文账号

- **用户可见现象**（技术/合规层）：应用的在线能力依赖**未鉴权的第三方私有接口**（非公开 API），并伪造 User-Agent 与 Referer 抓取；同步中心页面上明文展示账号 `gaore@mellow.music`；音频直链返回的是 302 跳转而非可播放音频流。
- **复现步骤**：
  1. 读 `app/lib/core/sources/online_music_service.dart:29-84`（搜索）、`:87-161`（歌单详情）、`:164-184`（歌词）——均为 `music.163.com/api/...` 私有端点；
  2. 读 `:37-40` / `:104-107` 的伪造请求头；
  3. 裸测音频直链 `https://music.163.com/song/media/outer/url?id=...` → 返回 **302**（本轮实测）；
  4. 读 `desktop_views.dart:1414-1415` 的明文账号与端点。
- **证据**：上述代码位置；本轮裸 HTTP 实测：搜索 API **200**、歌词 API **200**、歌单详情 API **200**、音频直链 **302**；伪造请求头 `'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ...'` / `'Referer': 'https://music.163.com/'`（`online_music_service.dart:37-40`）；请求超时 6 秒为真实参数（`:26`）。
- **对应的文档声称**：`docs/SPEC.md:448`（E2E-02）要求"聚合 6 大音源结果并发返回，列表去重"；`docs/ROADMAP.md:103` 与 `desktop_views.dart:992` 声称"支持网易云音乐、QQ音乐分享链接与 ID 一键秒级抓取导入"。**实际只支持网易云一种（QQ/酷狗无任何分支），且依赖非公开接口。**
- **影响**：接口随时可能失效或被封禁（无 SLA、未授权），产品在线能力不可持续；明文账号展示属凭据管理不当；"支持三类链接"的对外承诺落空。合规上，未授权抓取与用户歌单数据转载存在版权风险。
- **严重度理由**：P1。可持续性与合规风险，非即时安全事件。

### [P1-20] 工程卫生：超大文件 / 死代码 / 版本号四处不一致 / 鸿蒙仅 README / 无错误上报

- **用户可见现象**（工程层）：`desktop_views.dart` 单文件 1828 行（含 14 个视图类）；约 3319 行代码在生产不可达；版本号在四处互不相同（`1.0.0+1` / `v2.1.0` / `v1.1.0` / `v1.0.0`）；`app/harmonyos/` 只有一个 README；应用无任何错误上报能力；发布包内并存两个 exe。
- **复现步骤**：统计各 dart 文件行数；检索死代码模块的 import 引用；比对四处版本号；列出 `app/harmonyos/` 目录内容；检索错误上报/日志调用；列出 Release 目录内容（§1.2）。
- **证据**：
  - 单文件规模实测：`desktop_views.dart` **1828 行**、`lx_script_sandbox.dart` 1204、`mobile_tabs.dart` 1055、`modals.dart` 985；
  - 死代码：`lx_script_sandbox.dart`(1204) + `lx_source_model.dart`(632) + `sync_data_model.dart`(573) + `lan_sync_service.dart`(509) + `webdav_sync_service.dart`(401) = **3319 行**（约 29.5%），在生产代码中 0 引用（仅测试 import）；
  - 版本号：`app/pubspec.yaml:19` `1.0.0+1` vs `desktop_views.dart:1383/1766` `v2.1.0` vs `docs/SPEC.md:3` `v1.1.0` vs `docs/PROGRESS.md:3` `v1.0.0`；另 `lx_script_sandbox.dart:143` 写 `'2.0.0'`、`:375` 默认 `'2.1.0'`，两套并存；
  - 鸿蒙：`app/harmonyos/` 仅有 `README.md`，SPEC/ROADMAP 描述的 `AppScope/app.json5`、`entry/`、`module.json5`、`EntryAbility.ets` 全部不存在；`release.yml` 无 HarmonyOS job；
  - 无错误上报：`FlutterError|runZonedGuarded|ErrorWidget|Crashlytics|Sentry|developer.log` 在 `app/lib` **0 命中**（实测），`debugPrint` 仅 1 处且位于死代码 `webdav_sync_service.dart:391`；
  - 发布卫生：`release.yml:44` 打包 `Release/*` 整目录，而该目录同时含 `app.exe` 与陈旧 `mellow_music.exe`（本次实测见 §1.2）。
- **对应的文档声称**：`docs/PROGRESS.md:52` 声称"补齐 Linux 原生 CMake & GTK3 构建脚手架与 **HarmonyOS NEXT / OpenHarmony** 架构对接文档"；`docs/SPEC.md:5` 与 `docs/ROADMAP.md:160` 声称支持鸿蒙；`docs/SPEC.md:415-435` 将"未捕获异常为 0"列为红线。
- **影响**：超大单文件与死代码使代码审查、单测、重构成本剧增（这正是 P1-14 测试失真的根因）；版本号四处不一使发布与合规追溯不可能；鸿蒙"支持"为零工程文件，属平台矩阵承诺无法兑现；无错误上报使线上问题不可发现（配合 P0-05/P0-06 的静默吞异常，形成"永远无告警"的假象）；发布包含两个 exe 会直接误导用户。
- **严重度理由**：P1。多项工程红线同时失守，是上述所有缺陷得以长期隐藏的结构性原因。

### 4.3 P2 级缺陷（12 条）

### [P2-01] ListView(children:) 一次性构建

- **用户可见现象**：列表页在长列表下滚动略有卡顿，首帧渲染时间随列表长度线性增长。
- **复现步骤**：在列表较长的页面（如导入后的歌单、播放历史）滚动，观察流畅度；检查代码中的列表构造方式。
- **证据**：`app/lib/views/desktop/desktop_views.dart` 中 **13 处** `ListView(` 均为 `ListView(children: [...])` 形式（实测行号：23、281、389、618、683、799、861、980、1107、1154、1218、1339、1466），一次性构建全部子项，未使用 `ListView.builder` / `.separated` 的懒加载。
- **对应的文档声称**：`docs/SPEC.md:149` 声称"本地**数十万**曲库毫秒级 FTS5 联想检索"、`docs/SPEC.md:57` 声称"LRU 无损流式切片缓存"（隐含需要懒加载与索引）。**文档未直接规定必须使用 builder，但"数十万曲库"目标与一次性构建互斥。**
- **影响**：一旦接入真实曲库（数十万首），当前列表实现会直接卡死/内存暴涨。属可扩展性缺陷。
- **严重度理由**：P2。当前假数据量（6 首）下无感，属潜在性能债。

### [P2-02] 歌词翻译不渲染、SPEC 称 9 款预设实际 6 款

- **用户可见现象**：即使歌词接口返回了翻译歌词，界面上**不会显示翻译行**（只有原文行）；EQ 的预设数量与文档所述不一致。
- **复现步骤**：导入一首带翻译歌词的曲目播放，观察歌词区是否出现译文——没有；打开 EQ 弹窗清点预设数量（6 个）。
- **证据**：`translation` 字段在 `track_model.dart:5`（声明）与 `:10`（构造赋值）存在，但**全仓无任何读取点**（实测 `.translation` 读取命中仅构造赋值 1 处）；`app/lib/views` 下 `tlyric|translation` **0 命中**（实测）；翻译解析逻辑位于死代码 `lx_source_model.dart:544/561/580`。预设实际 **6 项**：`equalizer_manager.dart:4-14`。
- **对应的文档声称**：`docs/SPEC.md:451`（E2E-05）称"切换 **9 款**声学预设 (摇滚/重低音等)"；`README.md:60` 又称"5 大预设"。**同一能力三处口径：文档 9 / README 5 / 实际 6。**
- **影响**：双语歌词是歌词体验的关键功能，字段已解析却不渲染属"半成品"；预设数量口径不一使验收标准不可判定。
- **严重度理由**：P2。功能小项缺失 + 文档不一致。

### [P2-03] 自绘标题栏无无边框配置 → 双标题栏

- **用户可见现象**：窗口顶部同时存在**系统原生标题栏**（显示 "app"）和**应用自绘标题栏**（显示"Mellow Music · 润音"），形成明显的"双标题栏"；自绘标题栏内**没有最小化/最大化/关闭按钮**，用户只能依赖系统按钮。
- **复现步骤**：启动应用 → 观察窗口顶部两层标题栏（截图 `01-launch-window-title-app.png`）→ 在自绘标题栏区域寻找最大化/最小化/关闭控件——不存在。
- **证据**：截图 `01-launch-window-title-app.png`；自绘标题栏 `desktop_scaffold.dart:102-250`；窗口仍为 stock 有边框窗口：`app/windows/runner/win32_window.cpp:137-138` `CreateWindow(..., WS_OVERLAPPEDWINDOW, ...)`（实测），无 `WM_NCCALCSIZE` 处理。
- **对应的文档声称**：`README.md:54` 与 `docs/SPEC.md:447` 声称"无边框拟物标题栏（可拖拽、最大化 / 最小化 / 关闭）"。**实测双标题栏，且自绘栏内无这三个按钮。**（`README.md:54` 另称 Mac 交通灯，代码中已无该实现。）
- **影响**：视觉上直接暴露"原型未打磨"；自绘栏的空壳（无窗口控制能力）使用户误点无响应。
- **严重度理由**：P2。外观与交互打磨问题，不阻塞核心链路（与 P1-11 的"名称"问题区分）。

### [P2-04] 播放状态机边界问题

- **用户可见现象**：删除"正在播放"的曲目后，播放器会切到另一首歌但**进度条不归零**（从旧曲目的时间点继续，进度与曲目时长脱节）；在**暂停状态**下点"下一首/上一首"，会把没听过的歌写进"播放历史"；清空队列后播放按钮状态与空队列无提示。
- **复现步骤**：
  1. 播放一首歌至 00:11 → 打开队列抽屉 → 删除当前正在播放的曲目 → 观察进度条是否归零；
  2. 暂停播放 → 点"下一首" → 打开"播放历史" → 观察是否新增了一条未被播放的记录；
  3. 清空队列 → 观察主界面播放按钮与迷你播放器状态。
- **证据**（静态读码；**用户可见后果为代码推论，本次未逐项截图复现，复验时应补做**）：
  - `audio_player_service.dart:251-259` `removeTrackAt`：删除后仅夹取 `_currentIndex = max(0, _playlist.length - 1)`，**不重置 _position**，也不重启 ticker；
  - `:156-171` `next()` 与 `:173-193` `previous()`：无论是否正在播放都无条件执行 `_recordHistory(...)`（`:165` / `:187`）；
  - `:261-266` `clearQueue()`：清空后 `currentTrack` 为 null，而 `play()` 在 `:130` 直接 `return`；
  - 正面：`seek` 有 `[0, duration]` 夹取（`:195-205`），单曲循环与"播完停止"分支正确（`:312-323`）。
- **对应的文档声称**：`docs/SPEC.md:38` 声称"PlayerBloc (播放状态机、队列控制、三态循环、历史追踪)"；`docs/SPEC.md:132` 声称队列抽屉含"单曲删除与一键清空"。**文档未定义边界行为，但"历史追踪"不应记录未播放的曲目。**
- **影响**：进度/曲目错配会让用户困惑（"这歌怎么一上来就到一半"）；历史被污染使 P1-04 的"历史不真实"问题进一步放大。
- **严重度理由**：P2。边界场景缺陷，不阻塞正常播放路径（且当前本就无声）。

### [P2-05] design_tokens.css 与 tokens.dart 不一致

- **用户可见现象**：同一设计系统在 Web 原型与 Flutter 客户端呈现不同的灰度层级与阴影景深；README 主打的"内白高光内边"在 Flutter 端不存在。
- **复现步骤**：对照 `design_tokens.css` 与 `app/lib/design_system/tokens.dart` 的同名 token 取值。
- **证据**（`docs/audit/web-layer.md` #35~#38，含逐项数值）：
  - 亮色：`--soft-bg-recessed: #E8EEF5`(css:20) vs `recessedLight = 0xFFEBF0F8`(dart:26)；`--soft-text-main: #1E293B`(css:24) vs `textPrimaryLight = 0xFF0F172A`(dart:29)；
  - 暗色：CSS 的 `bg-surface` 在 Dart 里成了 `cardMuted`，`bg-subtle` 成了 `card`（语义角色被调换）；
  - 圆角：CSS 独有 18/14，Dart 独有 8/16/20/32，两套值域互不覆盖；
  - 阴影：Dart 缺 `convex`/`pressed` 两级；`README.md:40` 宣称的 `inset 0 1px 0 rgba(255,255,255,0.9)` 高光内边在 Flutter `BoxShadow` 中不可实现，`tokens.dart` 全文无等价实现。
- **对应的文档声称**：`README.md:40/44` 与 `docs/SPEC.md:71` 将这套 token 作为设计规范。**两套实现无法互相校验，规范失效。**
- **影响**：双端观感漂移；后续维护者极易改错（同名不同义）。属设计系统单点事实源缺失。
- **严重度理由**：P2。一致性与可维护性问题。

### [P2-06] README 引用 2 张不存在截图、npm start 命令失败

- **用户可见现象**：GitHub README 的"界面预览"表格中 **2 张图片显示为坏图**；按 README"快速启动"操作，第一步 `npm start` 即失败。
- **复现步骤**：检查 `README.md:18` 引用的 `public/showcase_desktop_dark.png` 与 `:22` 引用的 `public/showcase_desktop_lyrics.png` 是否存在；执行 `npm start` → `ReferenceError: require is not defined in ES module scope`（exit code 1）。
- **证据**：`README.md:18`、`README.md:22`（实测引用，已核对）；两个文件不存在（`docs/audit/web-layer.md` #33 实测 exists=False，而同页其他 4 张 `public/showcase_mobile_*.png` 存在）；`package.json:5` `"type":"module"` vs `server.js:1` `require()`（见 P0-12）。
- **对应的文档声称**：`README.md:126-136` 的"快速启动"步骤；`README.md:109-113` 的 `83/83` 结果。**该结果依赖手工另起服务，文档未记录前置条件。**
- **影响**：交付证据链（截图、启动命令）断裂；新接手者按文档操作第一步就失败，直接影响协作与验收可信度。
- **严重度理由**：P2。文档与仓库状态不同步（其根因 P0-12 已达 P0）。

### [P2-07] Web 原型播放为振荡器合成音、mp3 零引用

- **用户可见现象**：Web 原型的"播放"听不到歌曲，而是循环演奏同一段和弦音；仓库里 34.5 MB 的真实 mp3 音频文件**从未被任何代码引用**。
- **复现步骤**：打开 `index.html` 点播放 → 听感为持续和弦（每 2500ms 换一个）；全仓检索 `track1|track2|track3|track4|public/audio|audio/track` → **0 命中**；检索 `new Audio|<audio|decodeAudioData|createBufferSource` → **0 命中**。
- **证据**：`index.html:1665-1836`（`ModernSoftAudioEngine`，`:1807` `this.ctx.createOscillator()`）、`index.html:1676-1683`（硬编码和弦表）、`:1829-1834`；`mobile.html:1359-1523`、`:1494` 同构；"导入本地音频"写入的 `fileUrl` 全文件仅 1 处赋值、无消费者（`index.html:3013`）；"扫描本地磁盘"是空函数（`index.html:3050-3053` 只弹 toast）；`app/pubspec.yaml` 的 `assets:` 段全被注释（Flutter 也未打包这些 mp3）。
- **对应的文档声称**：`README.md:3`"专为全平台**高保真**体验打造"；`index.html:893`"**Hi-Res 无损母带音频 (192kHz / 24bit)**"且该单选**无 onchange**；`mobile.html:2661-2666` 列表写 `(无损离线版).flac`。**与 `README.md:85` 自述的"通过 Web Audio API AudioContext 实时生成 440Hz 纯净旋律"直接冲突。**
- **影响**：Web 原型是文档里 `83/83` E2E 的测试对象，其实质是"UI 能点、声音是假的"，用它证明"高保真"属口径错位；34.5 MB 死文件进版本库拖慢 clone。
- **严重度理由**：P2。原型层问题（不影响 app.exe 主产物判定）。

### [P2-08] 双端数据/文案不一致（含 e2e 断言互斥数据同时通过）

- **用户可见现象**：同一歌手在桌面与移动原型的粉丝数不同（周杰伦 1,290万 vs 3280 万）；同一首歌的歌名/专辑/歌词行数/时间轴两端不一致；EQ 预设参数两端是两套数值；**同一次 E2E 运行同时"验证通过"了两套互相矛盾的数据**。
- **复现步骤**：比对 `index.html` 与 `mobile.html` 的曲名、专辑、歌词、歌手粉丝数、EQ 参数；读 `e2e_test.js:747` 的断言值并与 `index.html:1123` 的桌面文案对照。
- **证据**（`docs/audit/web-layer.md` §2.4 逐项对照表）：曲名/专辑/歌词行数（晴天 12 行 vs 9 行）/光晕色数（3 vs 2）/歌手阵容（仅 3 人重合）/粉丝数（周杰伦 1,290万 vs 3280 万，格式亦不一致）/字段命名（`fans` vs `followers`）/EQ 参数（bass `120Hz +9dB` vs `200Hz +6.0dB`）；自相矛盾实证：`e2e_test.js:747` 断言移动端 '3280 万'，而 `index.html:1123` 桌面写死 `1,290万 粉丝 · 5,420,100 月度听众`；两端 **210 行 >40 字符的代码逐字重复**。
- **对应的文档声称**：`docs/ROADMAP.md` 与 `docs/SPEC.md` 宣称"零遗漏对齐矩阵"。**数据层没有单一事实源，双端各维护一份常量。**
- **影响**：跨端一致性不可保证，改一处必漏另一处；E2E 断言互斥数据同时通过，说明测试不具备"发现不一致"的能力。
- **严重度理由**：P2。一致性与测试有效性问题。

### [P2-09] 移动端缺 1 个二级页、5 抽屉只有 2

- **用户可见现象**：移动端**无法进入歌单详情页**；文档承诺的移动端 10 频段触控 EQ 弹层、定时器弹层、触觉音量条**均无对应页面**（EQ 与定时器直接复用桌面 `showDialog`，音量弹层无实现）。
- **复现步骤**：在移动壳中尝试点开歌单查看详情——无法进入；尝试呼出移动端音量弹层——无实现；检查移动端 EQ/定时器是否为桌面弹窗样式。
- **证据**：`MobilePlaylistDetailPage` 类不存在，`mobile_scaffold.dart:423-438` 仅 8 个 case（无 `playlist_detail`）；移动端底部抽屉仅存在 2 个（`MobilePlayerBottomSheet` `mobile_sheets.dart:15`、`MobileQueueBottomSheet` `:295`），`MobileEqBottomSheet` / `MobileSleepTimerBottomSheet` / `MobileVolumeModal` 三个类均不存在，EQ 与定时器复用桌面 `showDialog`（`mobile_sheets.dart:269/277`）。
- **对应的文档声称**：`docs/SPEC.md:144-152` 列出 9 个二级页；`docs/SPEC.md:153-157` 列出 5 个底部抽屉；`docs/PROGRESS.md:38` 又写"移动端 4 主 Tab + **8** 二级页面 + 5 大弹窗/抽屉"。**文档内部互相打架（SPEC 9 / PROGRESS 8），实际 8 页、2 抽屉。**
- **影响**：移动端核心路径（查看歌单详情、调 EQ、调音量）缺失或形态不符；"双端 1:1 对齐"声明落空。
- **严重度理由**：P2。移动壳在桌面产物中属次要路径（但见 P1-10，桌面用户会被迫进入它）。

### [P2-10] MellowImage 无 loading/磁盘缓存 + isInTest hack

- **用户可见现象**：网络图片加载时无占位/无骨架屏，加载过程中出现空白闪烁；图片不落磁盘缓存，同一张图每次进入页面都重新下载；在"测试环境"下直接显示占位图（掩盖了真实的图片加载问题）。
- **复现步骤**：断网/弱网进入含封面图的页面，观察是否有加载态与失败态；反复进出同一页面，观察图片是否重新请求；读 `mellow_image.dart` 中的测试开关。
- **证据**：`imageCache|precacheImage|CachedNetworkImage|loadingBuilder|frameBuilder` 在 `app/lib` **0 命中**（实测）；`app/lib/design_system/mellow_image.dart:7` `static bool isInTest = false;`、`:26` `final bool usePlaceholder = isInTest || ...`（实测）——生产代码内保留测试开关。
- **对应的文档声称**：`docs/SPEC.md:57` 声称"LRU 无损流式切片缓存、离线曲目归档目录"。**图片层与音频层均无缓存实现。**
- **影响**：弱网下体验差、流量浪费；`isInTest` 开关使测试环境下图片问题被掩盖（测试与生产行为不一致），是"测试通过但线上坏"的隐患。
- **严重度理由**：P2。体验与测试可信度问题。

### [P2-11] 导入歌单仅预览前 5 首、封面加载失败

- **用户可见现象**：导入"官方热歌榜"成功返回"共解析成功 200 首高保真曲目"，入库后列表中**只显示前 5 首**，且**没有任何"查看全部"入口**；导入歌单的封面加载失败，显示为音符占位图。
- **复现步骤**：进入"导入与自建歌单"（热区中心 y=465）→ 点"导入新歌单"→ 点"官方热歌榜"快捷标签（自动填入 3778678）→ 点"解析"→ 观察返回文案与入库列表条数（截图 `13-real-import-worked-cover-missing.png`）→ 观察封面显示。
- **证据**：截图 `13-real-import-worked-cover-missing.png`；`desktop_views.dart:1071` `for (final t in pl.tracks.take(5))`（实测），**只渲染前 5 首且无"查看全部"**；封面为音符占位（实测截图）。对比（正面）：真实链路本身成功——返回"热歌榜 · 共解析成功 200 首高保真曲目"及真实榜单简介，入库曲目为真实歌曲（明知故犯 - Max李玄 / 海屿你 - 马也_Crabbit / 两难 - 加木 / 甲乙丙丁(你我怎么两清) - 李佳薇 / 我不难过 - 孙燕姿）。
- **对应的文档声称**：`docs/SPEC.md:448`（E2E-02）与 `desktop_views.dart:1018/992` 声称"一键秒级抓取导入""完整同步"。**"完整同步"不成立（只预览 5/200）。**
- **影响**：用户导入 200 首却只能看到 5 首，会认为导入失败或数据丢失；封面失败进一步降低可信度。**注意：这是本产物为数不多的真实可用链路之一（§3.5），缺陷仅在"预览截断 + 封面"，且其结果受 P0-02 影响（重启全部丢失）。**
- **严重度理由**：P2。真实链路的表现缺陷（核心可用性已在 §3.5 记为正面）。

### [P2-12] 无音频焦点/后台播放/wakelock、无日志与错误上报

- **用户可见现象**：播放时设备会正常息屏（无 wakelock）；切换到其他应用后无后台播放与系统媒体控制；出现异常时用户看不到任何提示，开发者也无从获知（无日志、无崩溃上报）。
- **复现步骤**：播放中让屏幕自动息屏，观察是否继续；切换到其他应用，观察通知栏/媒体键是否有控制项；制造一次网络异常（断网搜索），观察是否有用户提示与本地日志。
- **证据**（实测检索，均在 `app/lib`）：`WakelockPlus|wakelock|audio_session|AudioSession|MediaSession|SMTC` **0 命中**；`FlutterError|runZonedGuarded|ErrorWidget|Crashlytics|Sentry|developer.log` **0 命中**，`debugPrint` 仅 1 处且位于死代码 `webdav_sync_service.dart:391`。此外 `online_music_service.dart:80/157/182` 用 `catch (_) {}` 静默吞掉网络异常。
- **对应的文档声称**：`docs/SPEC.md:48` 与 `docs/SPEC.md:176-180` 声称 audio_service 系统通道（Windows SMTC / Android MediaSession / iOS Control Center）；`docs/SPEC.md:415-435,464` 将"未捕获异常为 0"列为硬性红线；`README.md:62` 声称锁屏封面流控与锁屏歌词。**全部未实现；红线无技术手段兜底。**
- **影响**：作为播放器缺少后台播放与系统控制属功能缺失（但当前本就无声，故列 P2）；无日志与无错误上报是**质量放大因素**——它使 P0-05/P0-06 的静默失败、P1-13 的假绿灯都无法被发现。
- **严重度理由**：P2。本身不阻塞，但与多项 P0/P1 形成"问题不可见"的闭环，是本次验收需要点明的系统性风险。

---

## 5. 用户旅程逐场景验收记录

**被测对象与环境（共享事实，本文不复述推导）**：产物 `release_windows/app.exe`（MD5 `4839AFE576D5297AB9B2BCD707ADC9EF`，90,624 B；`data/app.so` = 6,308,744 B），该目录内全部文件时间戳 2026-09-22 17:37:18，**新于最新源码文件** `app/lib/views/desktop/desktop_views.dart`（17:26:19），因此它是与当前源码一致的产物。窗口置为 1440x900@(0,0)，Win32 合成鼠标/键盘事件逐项操作，PrintWindow(PW_RENDERFULLCONTENT) 抓图，**从截图中像素级测量控件热区**后再点击（侧边栏 12 个条目热区中心 y = 147/193/239/285/331、419/465/511/557、645/691/733，条目高 34 px、间距 12 px，x ≈ 147）。

| 场景编号 | 用户操作 | 期望结果 | 实测结果（含证据截图文件名） | 判定 |
|---|---|---|---|---|
| S01 | 双击 `release_windows/app.exe` 启动，等待主窗口出现 | 进程正常启动，标题为品牌名「Mellow Music · 润音」，无崩溃 | 进程正常启动并完整渲染主界面；持续轮询 24 s **无崩溃、无未响应**，进程共加载 85 个模块。但窗口系统标题栏显示模板默认值 **"app"**，且与应用内自绘标题栏同时存在（双标题栏，P1-11/P2-03）。证据：`01-launch-window-title-app.png`、`08-eq-modal-preset-clipped.png`（顶部双标题栏可见） | 部分通过 |
| S02 | 依次点击侧边栏 12 个入口（像素实测坐标），并进入歌手详情、全屏歌词 | 14 个桌面视图均可进入、布局完整、内容与所选视图对应 | 12 个侧边栏入口 + 歌手详情 + 全屏歌词共 **14 个视图全部可渲染**，无白屏、无异常、切换响应正常；但全部视图数据来自内存 mock（6 首常量曲目 + 手写艺人/榜单/歌单），导航为字符串 switch，前进按钮空实现（P1-17），桌面实为 14 视图而文档只写 12（doc-gap 4.7）。证据：`02`/`03`/`06`/`07`/`10`/`13`/`16`/`18`/`19`/`20` | 部分通过 |
| S03 | 点击底栏播放按钮 / 任意曲目「播放」 | 扬声器输出对应音频，时间轴与音频同步 | 播放/暂停图标与进度条状态正常切换、进度会前进；但**无任何声音输出**：pubspec.lock 中 `audioplayers`/`just_audio`/`media_kit`/`audio_service` 全 0 命中，6 首 mock 曲目 `audioUrl` 全为 null，全仓无 `audioUrl` 读取方（P0-01）。证据：`01-launch-window-title-app.png` | 不通过 |
| S04 | 保持「播放」状态，观察进度条、时间文案与歌词滚动 | 进度与真实音频播放位置同步 | 进度每 50 ms 自增 50 ms、时间文案与歌词同步推进（`audio_player_service.dart:305-329` 的 `Timer.periodic`）；但该时钟与音频解码无关，是纯计时器模拟，seek 亦只改内存变量（P0-01）。证据：`08-eq-modal-preset-clipped.png`（底栏 02:00/04:28） | 部分通过 |
| S05 | 点击标题栏月亮图标 / 设置页「深色石墨夜间 (Dark)」 | 切换为深色主题，且记住选择 | 深色主题**即时生效且渲染正确**，配色层次一致；但主题仅存内存，`shared_preferences` 声明却全仓 0 调用，**重启后回到浅色默认值**（P0-02）。证据：`10-dark-mode-settings.png`、`11-before-restart-dark-green-4fav.png`、`12-after-restart-light-blue-defaultfav.png` | 部分通过 |
| S06 | 设置页依次点击 5 个强调色圆盘 | 全应用强调色与弥散光晕同步变化 | 5 种强调色均可即时切换，卡片/按钮/光晕同步生效（11 号截图为深色 + 绿色）；但重启后回到默认蓝色（P0-02）。证据：`11-before-restart-dark-green-4fav.png` → `12-after-restart-light-blue-defaultfav.png` | 部分通过 |
| S07 | 点击曲目/底栏红心，收藏与取消收藏 | 收藏状态切换，「我喜欢的音乐」数量随之变化 | 红心切换即时生效、计数与列表同步（`audio_player_service.dart:207-218`）；但开箱即 **4 首硬编码收藏**（`track-1/3/5/6`），文案「共收藏 4 首心动单曲 · 实时云端同步」中的同步为假，重启回到 4 首（P1-05/P0-02）。证据：`20-favorites-default-hardcoded.png`、`11`、`12` | 部分通过 |
| S08 | 点击底栏队列图标，在队列中删除一首曲目 | 打开播放队列面板，删曲后队列与播放计划同步 | 队列面板（`PlaybackQueueView`，`modals.dart:16`）正常打开，增删逻辑真实生效（`audio_player_service.dart:246-266`）；但队列初值是 6 首 mock，删曲对「声音」无任何影响（本就无音频）。证据：`16-fullscreen-lyrics.png` 同屏底栏 | 部分通过 |
| S09 | 点击底栏歌词图标进入全屏歌词页 | 全屏歌词页打开，歌词按播放位置高亮滚动 | 页面正常打开，黑胶转盘动画与歌词高亮滚动均正常；但歌词来自 6 首曲目的手写常量（时间戳整秒凑数），滚动时钟即 50 ms 定时器，无逐字动画、无独立穿透歌词窗（P2-02）。证据：`16-fullscreen-lyrics.png` | 部分通过 |
| S10 | 点击底栏 EQ 图标打开均衡器 | 10 频段 EQ 完整可见可调，拖动滑块改变声音 | 弹窗打开，10 个频段滑块与数值可交互（状态管理真实，`equalizer_manager.dart:40-79`）；但**第 5 个预设「Spatial 3D」被裁切到可视区外不可见**（P1-09），副标题「基于 libmpv firequalizer 高保真声学校准」为假（无 mpv 依赖，`toLibmpvFilterString` 全仓 0 生产调用），调参对声音零影响。证据：`08-eq-modal-preset-clipped.png` | 部分通过 |
| S11 | 点击底栏定时器图标，选择 15/30 分钟档位 | 打开睡眠定时器弹窗，倒计时归零后停止播放 | 弹窗打开、档位可选，倒计时使用真实 `Timer.periodic`（`audio_player_service.dart:269-294`）；但「到点停止播放/淡出」因无音频链路**无法观察验证**。证据：`08-eq-modal-preset-clipped.png`（底栏定时器图标） | 部分通过 |
| S12 | 点击顶部搜索框输入中文关键词（并尝试 Ctrl+K / ESC） | Ctrl+K 呼出全局搜索，输入后返回结果，ESC 退出 | 点击搜索框可打开 `QuickSearchOverlay`，输入后 350 ms 防抖触发**真实网易云 HTTP 检索**（在线结果带「在线音源」徽章）；但按 **Ctrl+K 与 ESC 完全无反应**（lib 内 `Shortcuts`/`RawKeyboard`/`LogicalKeyboardKey` 0 命中，P0-09/P1-07），打开即预置 6 条本地 mock「结果」，网络失败静默降级且无提示。证据：`09-search-overlay-local-results.png` | 部分通过 |
| S13 | 在「导入与自建歌单」用真实歌单 ID 3778678 导入 | 导入真实歌单并完整展示全部曲目与封面 | 真实 HTTP 成功（`music.163.com/api/playlist/detail`），导入「热歌榜」成功，页面写明「包含 200 首完整音轨」，前 5 首为真实曲目（明知故犯-Max李玄 / 海屿你-马也_Crabbit / 两难-加木 / 甲乙丙丁-李佳薇 / 我不难过-孙燕姿）；但**仅预览前 5 首、歌单封面加载失败显示占位音符图标**（P2-11）。证据：`13-real-import-worked-cover-missing.png` | 部分通过 |
| S14 | 导入后切换到「导入与自建歌单」查看资料库 | 新歌单入库，可查看并「播放全部」 | 导入歌单真实入库并渲染为卡片（`audio_player_service.dart:83-92`、`desktop_views.dart:970`），列表与计数正确；点「播放全部」会把队列换成 200 首，但 `audioUrl` 无消费方 → 依旧无声。证据：`13-real-import-worked-cover-missing.png` | 部分通过 |
| S15 | 进入「本地与下载」，点「选择本地文件夹扫描」，尝试拖拽导入 | 弹出目录选择器，扫描本地音频并列出真实曲目 | 按钮 `onTap: () {}` 空函数，**点击无任何反应**（P0-08）；「已解析本地曲目」列表实际渲染 6 首 mock 曲目，每行副标题固定为「FLAC 24bit/96kHz · 42.8 MB」；拖拽导入凹槽为纯装饰（无 `file_picker` 依赖、无 `DragTarget` 实现）。证据：`04-local-fake-metadata-dead-button.png` | 不通过 |
| S16 | 进入「多端同步中心」，点「从云端恢复」（并试「立即云端备份」） | 真实连接 WebDAV 拉取快照并按 LWW 合并 | 点击后转圈约 900 ms 即提示「拉取完成！数据已合并」/「已成功从 WebDAV 云端合并」，全程**无任何网络请求**（`Future.delayed` 伪造，`desktop_views.dart:1437-1455`）；端点与账号为硬编码常量（`dav.jianguoyun.com` / `gaore@mellow.music`），「服务就绪」绿标无条件渲染；真实 `WebDavSyncService` 完整存在但 UI 完全不引用（P0-03）。证据：`06-cloud-restore-fake-success.png`、`05-sync-center-fake-devices.png` | 不通过 |
| S17 | 进入「LX 音源管理」页，尝试导入音源链接、切换音源开关 | 看到已注册音源列表，可导入脚本、启停音源 | 页面为单张静态卡片「内置综合聚合音源 (Built-in) · v2.1.0 · 运行中」；「在线导入音源链接」按钮 `onTap` 为空（`desktop_views.dart:1352-1358`），启用开关 value 恒为 true 且 `onChanged` 为空（`:1391`），页面不含任何音源引擎引用（P0-07）。证据：`07-source-manager-empty-shell.png` | 不通过 |
| S18 | 进入「个性化设置」 | 深色、5 强调色、光晕浓度、音源管理与音质、缓存清理 | 仅 **3 张卡片**真实可用：外观 / 强调色 / 光晕浓度滑块；音源管理与音质首选项、离线缓存清理均无入口（P1-06）。证据：`10-dark-mode-settings.png` | 部分通过 |
| S19 | 反复拖动缩小窗口（869x900 → 430x860 → 220x200） | 窗口受最小尺寸约束，布局自适应不崩坏 | 无最小尺寸约束（`win32_window.cpp` 无 `WM_GETMINMAXINFO`）；宽度 <1024 px 整体退化为移动壳：**假 iOS 状态栏 10:09 + "Mobile" 角标 + 迷你胶囊遮挡内容**（P1-11/P1-10）；继续缩至 220x200 布局崩坏、控件互相覆盖。证据：`14-mobile-shell-fake-statusbar-overlap.png`、`15-tiny-window-layout-broken.png` | 不通过 |
| S20 | 记录当前状态后关闭 exe 并重新启动 | 主题/强调色/收藏/历史/歌单/设置全部保留 | 重启后主题回到浅色默认、强调色回到默认蓝、收藏回到硬编码 4 首、播放历史回到 1 条「云水禅心」（冷启动自插）、导入歌单全部消失——**零持久化**（`shared_preferences` 声明但全仓 0 调用，P0-02）。证据：`11-before-restart-dark-green-4fav.png`（重启前）→ `12-after-restart-light-blue-defaultfav.png`（重启后） | 不通过 |

**场景判定汇总**：20 个场景中 **通过 0 个、部分通过 14 个、不通过 6 个**（不通过：S03 播放、S15 本地扫描、S16 同步恢复、S17 音源管理、S19 缩小窗口、S20 重启持久化）。无一个场景达到「期望结果」的完整定义。

---

## 6. 假数据总账（用户视角去重清单）

- **口径**：本节从 `docs/audit/fake-data.md` 的 174 条中挑选**用户可见**的代表性条目，去重后按 A~L 分组，共 **83 条**（每组 5~10 条）。原报告编号在「证据」列以 `→ 原编号` 标注，可逐条回溯。
- **取值**：`假` = 纯编造或纯装饰；`真假混杂` = 名称真实但元数据/资源被编造；`真` = 真实实现或真实 I/O。
- **★ 标记**：fake-data.md §0/§7 点出的 5 个最严重项——★1 无任何音频播放能力；★2 WebDAV/云端同步 900 ms 伪造成功；★3 局域网虚构设备 + 端口不符；★4 全部封面/头像为 Unsplash 无关照片并大面积复用；★5 本地扫描/拖拽导入/音源管理为空函数或死代码。

### A 曲库与歌曲元数据

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| A-01 | 全局曲库、底部播放栏、所有歌曲列表 | 「云水禅心 / 巫娜 / 天禅 · 琴筝和鸣」等曲目 | 假 | `app/lib/core/audio/track_model.dart:110-111` → A1；截图 12、13 | ★1 整个 App 的「曲库」= 6 元素常量数组 `mockPresetTracks`，与应用内任何扫描/网络结果无关，注释自称「与原型 83 项 E2E 验证曲目 100% 对齐」 |
| A-02 | 每条曲目的音源标签 | 无损 FLAC / 320k 来源标识 | 假 | `track_model.dart:119/140/159/180/199/216` → A3 | `source: 'preset-flac'` / `'preset-320k'` 为硬写字符串，UI 据此显示「无损」话术 |
| A-03 | 歌曲封面、发现页 Hero 大图、歌单封面 | 城堡风景照、麦克风照、DJ 台照等 | 假 | `track_model.dart:117/138/157/178/197/214` → A11、§3.1；截图 12 | ★4 一张 Unsplash 城堡照 `photo-1518709268805` 被复用于 **10 处**（含《云水禅心》封面与「东方禅境 · 古筝」歌单封面），与内容无任何对应关系 |
| A-04 | 6 首预置曲目的播放地址 | （用户不可见，但是无声的根因之一） | 假 | `track_model.dart:67-68` → A2、A18 | ★1 `audioUrl` 全为 null，且 `@audioUrl` 在全仓只被赋值与序列化，**无任何读取方用于播放** |
| A-05 | 曲目 1《云水禅心》的 9 行歌词 | 「古筝幽弦，流水静淌」等 | 假 | `track_model.dart:121-131` → A5 | 器乐曲本无词，9 行全部手写；时间戳 0/12/24/38/52/68/88/110/135 s 人工凑数 |
| A-06 | 曲目 2《晚风告白 / 伯远 / 晚风拂过告白季》 | 专辑名与 7 行歌词 | 假 | `track_model.dart:133-151` → A6 | 专辑名编造，歌词手写（10/22/35/48/62/78 s） |
| A-07 | 《海阔天空》《夜的第七章》《City of Stars》《起风了》 | 曲名/歌手/专辑/时长 | 真假混杂 | `track_model.dart:152-227` → A7~A10 | 曲名与艺人真实，但封面为无关照片、歌词手写录入、时长与来源标签为手写 |
| A-08 | 底部播放栏进度 02:00 / 04:28 与歌词滚动 | 进度条与时间在走 | 假 | `audio_player_service.dart:305-329` → A16；截图 08 | ★1 「播放」是 50 ms `Timer.periodic` 自走时钟，注释自称「60fps 高刷进度驱动」，与解码无关 |
| A-09 | 应用启动后的播放队列 | 队列里已有 6 首歌 | 假 | `audio_player_service.dart:19` → A13 | `List.from(mockPresetTracks)`，启动即「有」一个歌单 |
| A-10 | 应用「支持播放音乐」这一能力本身 | —— | 假 | `app/pubspec.yaml:30-46` + `pubspec.lock` → A17 | ★1 依赖仅 http/dio/provider/go_router/intl/shared_preferences/crypto/path_provider/path，**无任何音频依赖**，无论 mock 还是在线曲目都不可能发声（P0-01） |

### B 歌手

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| B-01 | 发现页「热门入驻与关注歌手」、热门歌手页 | 巫娜 86.4万 / 周杰伦 3890.2万 / Beyond 1240.8万 / 伯远 512.6万 | 假 | `desktop_views.dart:611-616` → B1；截图 02 | 粉丝数为手写字符串，无任何 API 来源 |
| B-02 | 歌手头像（头像环、歌手列表） | 4 张人物照 | 假 | `desktop_views.dart:185-188、612-615` → B3、B4、§5；截图 02 | ★4 实测图片内容：蓝紫打光年轻女性、白人男性微笑照、白人男性肖像、户外年轻男性——与巫娜（古琴演奏家）/周杰伦/Beyond（4 人乐队）/伯远**无一人对应** |
| B-03 | 歌手详情页头像 | 一张年轻女性肖像 | 假 | `desktop_views.dart:702-705`、`mobile_pages.dart:525-528` → B9 | ★4 **无论点进哪位歌手都是同一张图**，该图还同时充当 App 用户头像 |
| B-04 | 歌手详情页副标题 | 「官方认证音乐人 · 粉丝量 189.4万 · 单曲播放突破 1.2 亿」 | 假 | `desktop_views.dart:719` → B7 | 对所有歌手完全相同，与列表页的 86.4万 自相矛盾 |
| B-05 | 歌手详情页「代表作列表」 | 6 首代表作 | 假 | `desktop_views.dart:751-776` → B10 | 不论哪位歌手，代表作都是同样 6 首 mock 曲目 |
| B-06 | 歌手名后的蓝色认证勾 | 「认证」徽章 | 假 | `desktop_views.dart:643-649` → B6 | 无条件渲染，无任何认证接口 |
| B-07 | 歌手详情页「关注」按钮初始态 | 显示为「已关注」 | 假 | `desktop_views.dart:676`、`mobile_pages.dart:499` → B11 | `bool _isFollowing = true;` 硬编码，用户从未关注 |

### C 排行榜

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| C-01 | 巅峰榜单页 4 个榜单卡片 | 飙升榜 / 热歌榜 / 新歌榜 / 原创榜 | 假 | `desktop_views.dart:354-387` → C1；截图 03 | 榜单为方法内局部常量数组 |
| C-02 | 榜单卡片更新文案 | 「每日09:00更新 · 100首」「每周四更新 · 200首」「每周五更新 · 50首」 | 假 | `desktop_views.dart:358/366/374/382` → C2 | 无任何定时任务或接口；100/200/100/50 与实际返回的 6 首完全不符 |
| C-03 | 每个榜单右侧「Top 5」 | 5 首「不同」的曲目 | 假 | `desktop_views.dart:530-532` → C3；截图 03 | 用取模公式 `(idx*3+i)%6` 从同一 6 首池错位取 5 首，制造「不同榜单」的错觉 |
| C-04 | 「播放全部榜单」按钮 | 播放该榜单 | 假 | `desktop_views.dart:408-412` → C4、C5 | 4 个榜单点进去播的都是同一套 6 首 |
| C-05 | 音源引擎内的榜单定义 | 「Mellow 飙升巅峰榜 · 每日 06:00 更新 · total: 100」 | 假 | `lx_script_sandbox.dart:241-275、279-295` → C9、C10 | 与 UI 的「09:00」互相矛盾；4 个榜单详情返回完全相同 5 首，`limit` 参数不生效（且该引擎生产不可达） |
| C-06 | 移动端榜单页 | 4 个榜单名 + 每榜 3 首 | 假 | `mobile_pages.dart:304、340-348` → C6~C8 | 仅剩 4 个字符串 + 取模复用同 6 首 |

### D 歌单与推荐

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| D-01 | 发现页「甄选歌单推荐」4 张卡片 | 「48.6万播放」「129.4万播放」「98.2万播放」「34.1万播放」 | 假 | `desktop_views.dart:144-172` → D1；截图 12 | 播放量为手写常量，无数据源 |
| D-02 | 4 张歌单卡片点击 | 播放整张歌单 | 假 | `desktop_views.dart:149/156/163/170` → D2 | 实际只 `playTrack(mockPresetTracks[i])` 播单曲，歌单内容并不存在 |
| D-03 | 歌单广场 7 个分类标签 | 精选推荐 / 华语流行 / 沉静治愈 / 古风雅乐 / 经典粤语 / 深夜爵士 / 纯音乐 | 假 | `desktop_views.dart:273-274、303` → D3 | 切换分类只改高亮，**不过滤任何数据** |
| D-04 | 歌单广场网格 | 6 张「歌单」卡片 | 假 | `desktop_views.dart:310-338` → D4 | `itemCount = mockPresetTracks.length`，所谓歌单就是 6 张单曲卡 |
| D-05 | 导入页栏目标题下的说明 | 「支持网易云音乐、QQ音乐分享链接与 ID 一键秒级抓取导入」 | 假 | `desktop_views.dart:992` → D5；截图 13（可见原文） | 实际只有网易云一个未鉴权接口，QQ 音乐从未实现（P1-19） |
| D-06 | 声音电台页 4 个节目 | 深夜治愈故事馆 / 科技播客等 | 假 | `desktop_views.dart:792-797、818-821` → D13、D14；截图 18 | 节目为文案常量，点击播的是 mock 曲目（P1-08） |
| D-07 | 移动端「新碟与精选专栏」 | 4 张专辑卡 + 「全部 48 专」 | 假 | `mobile_tabs.dart:632-657、677-688` → D16、D17；截图 14 | 实际只有 4 张卡；专辑名拼写错误（M83 实为 *Hurry Up, We're Dreaming*），年份/风格手写 |
| D-08 | 移动端「4 位入驻音乐人」 | 4 位音乐人 | 假 | `mobile_tabs.dart:894` → D18 | 与写死的 4 条艺人常量对应 |

### E 同步与设备

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| E-01 | 多端同步中心页头 | 「云端端点: https://dav.jianguoyun.com/dav/」「绑定账号: gaore@mellow.music」 | 假 | `desktop_views.dart:1414-1415` → E1；截图 05、06 | 端点是坚果云公共地址，账号为编造演示邮箱；页面**无任何输入框/密码字段**可修改（P1-19） |
| E-02 | 「立即云端备份」按钮 | 转圈约 900 ms →「同步成功！已热备全量数据」+ SnackBar「已成功将本地播放数据、收藏及歌单备份至 WebDAV 云端！」 | 假 | `desktop_views.dart:1417-1435` → E2；截图 06 | ★2 完全没有网络请求，是 `Future.delayed(900ms)` 伪造的成功态（P0-03） |
| E-03 | 「从云端恢复」按钮 | 900 ms →「拉取完成！数据已合并」 | 假 | `desktop_views.dart:1437-1455` → E3；截图 06 | ★2 同上，文案里的「LWW 合并」是假的 |
| E-04 | 同步页绿色徽标 | 「服务就绪」 | 假 | `desktop_views.dart:1627-1632` → E5 | 无条件渲染，与 E-02/E-03 的假动作互相背书 |
| E-05 | 「后台自动定时同步 (每 30 分钟)」开关 | 开关可切换 | 假 | `desktop_views.dart:1684-1689` → E7 | 只切本地 bool，`startAutoSync` 全仓无调用方，从未启动任何定时器 |
| E-06 | 局域网设备卡片 | 「Gaore 的 iPhone 15 Pro」「IP: 192.168.1.103 · iOS 17.5 · Mellow v2.1.0」+ 绿色「在线」点 | 假 | `desktop_views.dart:1755/1766/1757-1763` → E9~E11；截图 05 | ★3 硬编码字符串，非扫描结果；「在线」圆点写死（P0-04） |
| E-07 | 第二台设备 + 投送/接力按钮 | 「客厅立体声音响 (HomePod)」「IP: 192.168.1.108 · 无损立体声流媒体投送」→「已接力音频流至客厅立体声音响！」 | 假 | `desktop_views.dart:1799/1810/1814-1822` → E12、E13；截图 05 | ★3 假设备 + 假投送提示，无任何网络投送，目标设备本身不存在 |
| E-08 | 同步页端口文案 | 「本机端口: 18585 监听中」 | 假 | `desktop_views.dart:1733` vs `lan_sync_service.dart:112` → E8、L3 | ★3 UI 显示 18585，代码默认端口是 **23332**；且 LAN 服务**从未被启动**（P0-04） |

### F 收藏与历史

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| F-01 | 「我喜欢的音乐」页 | 开箱即 4 首收藏 | 假 | `audio_player_service.dart:21` → A14、F4；截图 20 | `{'track-1','track-3','track-5','track-6'}` 硬编码（云水禅心/海阔天空/City of Stars/起风了），与用户行为无关（P1-05） |
| F-02 | 收藏页副标题 | 「共收藏 4 首心动单曲 · 实时云端同步」 | 假 | `desktop_views.dart:891` → F5 | 数字真实，后缀「实时云端同步」为假（从未同步） |
| F-03 | 播放历史页（冷启动） | 已有 1 条「云水禅心」 | 假 | `audio_player_service.dart:76-80` → F1；截图 19 | 构造函数里 `_recordHistory(_playlist[0])`，用户零操作即产生历史（P1-04） |
| F-04 | 播放历史页 | 「播放足迹历史」列表，无移除/清空入口 | 真假混杂 | `desktop_views.dart:1113-1138` → F2；截图 19 | 渲染逻辑真实、50 条上限与去重真实（`audio_player_service.dart:296-302`），但初值是 F-03 的假记录，且无清空功能 |
| F-05 | 红心收藏/取消收藏行为 | 收藏即时生效 | 真（范围有限） | `audio_player_service.dart:207-218` → F7 | ★做对的部分：会话内增删逻辑真实可用 |
| F-06 | 「收藏与历史会被保存」 | —— | 假 | `app/pubspec.yaml:41` → F8；截图 11 → 12 | `shared_preferences` 已声明但代码中从未 import/调用，重启即还原为硬编码初值（P0-02） |

### G 本地与下载

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| G-01 | 「本地与下载」页按钮 | 「选择本地文件夹扫描」 | 假（未接线） | `desktop_views.dart:1170-1175` → G1；截图 04 | ★5 `onTap: () {}` 空函数，点击无任何反应（P0-08） |
| G-02 | 「已解析本地曲目」列表 | 6 首「本地曲目」 | 假 | `desktop_views.dart:1180-1202` → G5；截图 04 | ★5 列表内容 = 6 首 mock 曲目，从未解析任何本地文件 |
| G-03 | 每行本地曲目副标题 | 「FLAC 24bit/96kHz · 42.8 MB」 | 假 | `desktop_views.dart:1195` → G6；截图 04 | 6 行全部同一串常量，不随曲目变化 |
| G-04 | 本地页说明文案 + 拖拽凹槽 | 「支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式」+ 装饰性导入凹槽 | 假 | `desktop_views.dart:1159-1178` → G3、G9 | 无解码器、无 `file_picker` 依赖、无 `DragTarget` 实现，格式列表无意义 |
| G-05 | 移动端「本地与离线下载」 | 「已缓存 6 首无损音频 · 占用空间 182 MB」/ 每行「FLAC 24bit · 42.8 MB」 | 假 | `mobile_pages.dart:611、629` → G7、G8 | 编造容量，与 42.8MB×6=256.8MB 自相矛盾 |
| G-06 | Web 原型「扫描本地曲库」 | toast「本地磁盘扫描完成，已同步 6 首无损曲目」 | 假 | `index.html:3055-3058` → G11 | 函数名自带 `Demo`，不扫描任何磁盘（且无本地文件时直接把在线歌单前 6 首当「本地曲目」，`index.html:3032` → G10） |

### H 音源管理（LX / QuickJS）

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| H-01 | LX 音源管理页标题 | 「自定义音源管理 (QuickJS)」「原生兼容 LX-Music 六音脚本生态规范」 | 假 | `desktop_views.dart:1348-1349` → H1；截图 07 | ★5 无任何 JS 运行时依赖，`"QuickJS"` 全仓仅此一处文案（P0-07） |
| H-02 | 「在线导入音源链接」按钮 | 可导入音源脚本 | 假（未接线） | `desktop_views.dart:1352-1358` → H2；截图 07 | ★5 `onTap: () {}` 空实现 |
| H-03 | 音源卡片徽标 + 启用开关 | 「内置综合聚合音源 (Built-in)」「v2.1.0 · 运行中」 | 假 | `desktop_views.dart:1378-1383、1391` → H3、H4；截图 07 | 版本号取自代码默认值；开关 value 恒 true、`onChanged: (_) {}` 空实现，开关不可用 |
| H-04 | 音源解析返回的「无损直链」 | https://stream.mellowmusic.io/... .flac 等 | 假 | `lx_script_sandbox.dart:204-205、452、646` → H10、H12、H15 | 域名全部编造（另有 `cdn.<platform>.music.net`、`custom-cdn.<id>.com`），无真实 CDN |
| H-05 | 自定义脚本的搜索结果与安全检查 | 「能启用」的脚本能搜到歌 | 假 | `lx_script_sandbox.dart:616-637、574-599` → H14、H18 | 用 query 的 MD5 前 8 位**现编**歌名/歌手/专辑；「安全检查」仅做字符串 `contains`，任何脚本都不会被执行 |
| H-06 | 「初始化官方六大音源维度」 | 六大平台聚合曲库 | 假 | `lx_script_sandbox.dart:846-963` → H19 | 同一批 5 首 `sampleSongs` 用 `copyWith(source:)` 复制成 5 个平台「曲库」（曲名完全相同） |

### I 移动端装饰

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| I-01 | 移动壳顶部状态栏 | 时钟「10:09」 | 假 | `mobile_scaffold.dart:104-113` → I1；截图 14、15 | 完全写死，不读系统时间、无 Timer（P0-11） |
| I-02 | 移动壳顶部图标 + 灵动岛 | 信号 / WiFi / 充电电池图标、自绘灵动岛 | 假 | `mobile_scaffold.dart:174-183、52-63` → I2、I6；截图 14 | 恒定装饰，不读取任何设备状态 |
| I-03 | 「发现音乐」标题旁角标 | 「Mobile」浅蓝胶囊 | 假 | `mobile_tabs.dart:72-90` → I3；截图 14 | `const` 常量角标，用于标识原型而非真实平台信息 |
| I-04 | 我的页头像与用户名 | 「Mellow 音乐探索家」+「PRO」徽章 | 假 | `mobile_tabs.dart:124-139、950-977` → I4、I5；截图 14 | 头像与「艺人头像」是同一张 Unsplash 图；会员等级无登录体系支撑 |
| I-05 | 移动端日推/榜单文案 | 「更新于 06:00」「今日契合度 99.4% · 已匹配 6 首温润曲目」 | 假 | `mobile_tabs.dart:308-315`、`mobile_pages.dart:64-66` → I7、I8 | 99.4% 与更新时间为编造（注：日历卡的 `now.month`/`now.day` 倒是真实系统时间） |
| I-06 | 移动端雷达卡与 4 张小卡 | 副标题「周杰伦 / 告五人 / M83」；小卡「午夜霓虹 M83」 | 假 | `mobile_tabs.dart:331、350-361` → I10~I12；截图 14 | 曲库中根本没有 M83/Midnight，点击**必然 fallback 到「云水禅心」**，与卡片文案完全无关 |

### J 搜索

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| J-01 | 搜索浮层「热搜」标签 | 周杰伦 / 告五人 / 落日飞车 / 陈奕迅 / 轻音乐 / 粤语经典 | 假 | `modals.dart:475` → J1 | 写死标签，非热搜榜 |
| J-02 | 打开搜索浮层的初始「结果」 | 未输入关键词就列出 6 首 | 假 | `modals.dart:478-481` → J2、J3；截图 09 | `_results = mockPresetTracks`（P1-07） |
| J-03 | 搜索框提示「按 ESC 退出」 | 按 ESC 可退出 | 假 | `modals.dart:567` → L11、§8.3 | lib 内键盘监听 0 命中，ESC 完全无反应（P0-09） |
| J-04 | 在线搜索失败时 | 无任何提示，静默显示本地 mock 结果 | 假（静默降级） | `modals.dart:519-532` → J6 | `if` 无 `else`：失败/空结果时保持 `_results = localMatches`，UI 不提示网络失败（不伪造新数据，此点比 E-02/E-03 诚实） |
| J-05 | 「快速体验」预设与导入失败提示 | 官方热歌榜 3778678 / 飙升巅峰榜 19723756 / 新歌推荐榜 3779629；失败提示「解析失败，请检查歌单ID或网络连接」 | 真 | `modals.dart:744-748、770-774` → J10、J11；截图 13 | ★做对的部分：三个歌单 ID 是真实的网易云公开歌单；失败时如实报错 |

### K Web 原型

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| K-01 | `index.html` 曲库与歌词 | 晴天 / Midnight City / 慢冷 / Golden Hour / 爱在西元前 / Starboy + 手写歌词 | 假 | `index.html:1475-1600` → K1、K2 | 代码注释直接自认 Mock，曲目/时长/封面/歌词全部硬编码 |
| K-02 | 原型「播放」 | 点播放能听到声音 | 假（合成器） | `index.html:1663-1836`、`mobile.html:1359-1523` → K4~K6、K17 | 播放的是 Web Audio 振荡器循环演奏的 6 个爵士和弦（每 2500 ms 换一个），两文件 grep `<audio>`/`new Audio` **0 命中**（P2-07） |
| K-03 | 原型的数据来源 | 内容看似「全平台曲库」 | 假 | `index.html`/`mobile.html` grep `@fetch(`@/`XMLHttpRequest`/`axios` → K7 | 两文件均 0 命中：原型完全不联网，所有内容一次写死 |
| K-04 | 原型收藏与历史初值 | 打开即有 3 首收藏 + 1 条「刚刚」的历史 | 假 | `index.html:1862/1870` → K8 | localStorage 兜底默认值 |
| K-05 | 原型 localStorage key | —— | 假（命名遗留） | `index.html:1848/1923-1925` → K10 | 使用 `alger_volume`/`alger_theme`/`alger_accent`，暴露原型来源 |
| K-06 | 移动端原型状态栏与本地曲目 | 时钟 10:09；「晴天 (无损离线版).flac · 32.4 MB」等 6 条 | 假 | `mobile.html:256、2660-2667` → K11、K12 | 写死；列表含 `size` 字段但无对应文件 |
| K-07 | 原型音量/主题/主色 + 拖拽文件读入 | 刷新后设置保留；拖入文件能读入 | 真（范围有限） | `index.html:1848/2587/3075/3115、3003/3013` → K9、K19 | 真 localStorage 读写与真实文件读入（blob URL）；但 `fileUrl` 全程无消费方，播放仍走合成器 |

### L 其它硬编码（版本号、端口、URL、账号、时间、播放量）

| 序号 | 界面/位置 | 用户看到的内容 | 真实/假/部分真 | 证据 | 说明 |
|---|---|---|---|---|---|
| L-01 | 音源页徽标 / 同步页设备行 / 安装包元数据 / 文档 | 「v2.1.0 · 运行中」/「Mellow v2.1.0」/ `1.0.0+1` / SPEC v1.1.0 / PROGRESS v1.0.0 | 假 | `desktop_views.dart:1383、1766`；`app/pubspec.yaml:19` → L1、L2 | 版本号四处不一致（P1-20、P2-08） |
| L-02 | 同步页端口文案 | 「本机端口: 18585 监听中」 | 假 | `desktop_views.dart:1733` vs `lan_sync_service.dart:112` → L3 | UI 与代码默认端口 23332 不符，且服务未启动 |
| L-03 | EQ 弹窗副标题 | 「基于 libmpv firequalizer 高保真声学校准」 | 假 | `modals.dart:206-208` → L8；截图 08 | 无 mpv 依赖，`EqualizerManager.toLibmpvFilterString()` 全仓仅有定义、0 生产调用（P1-09/P0-10） |
| L-04 | 发现页 Hero 副标题 | 「精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出，实时声学生态律动」 | 假 | `desktop_views.dart:78-81` → L12；截图 12 | 「30 首」与实际 6 首矛盾；「24bit/192kHz 无损直出」无解码器支撑（P0-10） |
| L-05 | 标题栏徽标与搜索提示 | 「Ctrl K」徽标 / 「按 ESC 退出」 | 假 | `desktop_scaffold.dart:186`、`modals.dart:567` → L11 | 有文案、无键盘实现（P0-09） |
| L-06 | 本地/缓存容量文案 | 「FLAC 24bit/96kHz · 42.8 MB」「已缓存 6 首无损音频 · 占用空间 182 MB」 | 假 | `desktop_views.dart:1195`、`mobile_pages.dart:611` → L3、G6、G7 | 编造容量且两处互相矛盾 |
| L-07 | 歌手页兜底参数 | 参数缺失时进入「巫娜」页 | 假（兜底常量） | `mobile_scaffold.dart:436`、`desktop_scaffold.dart:34/343` → L16 | 静默显示巫娜页面 |
| L-08 | 网络请求身份 | 以伪造 UA 抓取网易云私有接口；WebDAV 账号明文硬编码 | 真假混杂 | `online_music_service.dart:37-40、104-107`；`desktop_views.dart:1414-1415` → L18、E1 | 请求真实（非假数据），但属未授权抓取第三方私有接口 + 明文账号，随时可能失效（P1-19） |

---

### 6.1 真正使用真实数据的链路（逐条代码证据 + 实测证据）

> 以下 8 条是本次审计中**确实发生真实 I/O 或真实逻辑运算**的链路。它们可以工作，但其中 3 条未被 UI 接线。

| # | 链路 | 代码证据 | 本次实测证据 | 真实程度与限制 |
|---|---|---|---|---|
| ① | 网易云在线搜索 | `online_music_service.dart:29-84`：`http.get('https://music.163.com/api/search/get/web?s=...')`，解析真实 `result.songs`；调用链 `modals.dart:516-533` → 服务 | 输入中文关键词后 350 ms 防抖触发，加载态结束后返回真实 `netease_<id>` 曲目并渲染「在线音源」徽章（`modals.dart:650`，依据真实 source 前缀判断） | 真实 HTTP；无鉴权、依赖非公开接口；失败时静默降级为本地结果且不伪造数据（`modals.dart:519-532`、`online_music_service.dart:80-83`）；返回的 `audioUrl` 无播放器消费 |
| ② | 网易云歌单导入 | `online_music_service.dart:87-161`：`/api/playlist/detail?id=`，ID 正则提取（`:93-98`）支持纯数字与 `id=` 链接；入库 `audio_player_service.dart:83-92` | **实测成功**：导入官方热歌榜 3778678，返回「包含 200 首完整音轨」，前 5 首为真实曲目；证据 `13-real-import-worked-cover-missing.png` | 真实 HTTP + 真实入库 + 真实错误提示；限制：仅预览前 5 首、封面加载失败（P2-11） |
| ③ | 单曲 LRC 歌词拉取 | `online_music_service.dart:164-184`：`/api/song/lyric?os=pc&id=`；触发点 `audio_player_service.dart:106-118`（仅当 `track.lyrics.isEmpty && id.startsWith('netease_')`）；解析器 `track_model.dart:14-43` | 真实 HTTP 与真实 LRC 解析（正则 `\[(\d{2}):(\d{2})\.(\d{2,3})\]` + 排序 + 毫秒 `padRight(3,'0')`） | 触发条件狭窄：6 首 mock 曲目 `lyrics` 非空，**永不触发**；本次未观察到该链路实际发起（未验证） |
| ④ | WebDAV 协议实现 | `webdav_sync_service.dart`：`testConnection()` 真发 PROPFIND(:199-203)、失败退 HEAD(:212-214)、401/404 处理(:226-239)、MKCOL(:250-251)、PUT(:272-281)、GET(:304-309)、`sync()` 拉取→LWW 合并→上传(:334-372)；`updatedAt` 时间戳比较 `sync_data_model.dart:96-120` | 未做端到端连通性实测（无 UI 入口） | 真代码 / **0 调用方**：`DesktopSyncView` 完全不引用该服务，用户看到的是 900 ms 假成功 |
| ⑤ | 局域网 HttpServer | `lan_sync_service.dart:141-145` `HttpServer.bind(InternetAddress.anyIPv4, 23332)`；路由 `/sync/hello`(:171-183)、`/sync/pair` 校验 `_authKey`(:184-201)、`/sync/push` 校验 `x-auth-key`(:202-234)；客户端 `scanSubnet` 真并发扫 254 个 IP(:378-401) | 未实测（服务从未启动，23332 无监听） | 真代码 / **从未启动**：全仓无 `LanSyncService()` 实例化、无 `startServer()` 调用；UI 显示端口 18585 与代码 23332 不符 |
| ⑥ | 本地会话内状态管理 | `audio_player_service.dart`（播放模式 :225-243、随机 :158-160、队列增删 :246-266、睡眠定时器 :269-294、音量 :220-223）、`equalizer_manager.dart:40-79`、`theme_provider.dart`（被 UI 真实调用，如 `mobile_tabs.dart:1006/1015/1038`） | **实测有效**：主题/强调色/收藏/队列在会话内全部真实生效（截图 11 与 12 对比可见主题确实切换过） | 真逻辑但不持久化：`shared_preferences` 声明却 0 调用，重启即回到硬编码初值 |
| ⑦ | `server.js` 静态托管 | `server.js:24-90`：真实 `http.createServer`、MIME 表(:8-22)、HTTP Range 支持(:62-76，206 + `Content-Range`)、404 处理(:51-55)、`server.listen(PORT,'0.0.0.0')`(:88) | 审计侧实测可用（详见 `docs/audit/web-layer.md` §2.5 原始 HTTP 输出） | 唯一真实可用的服务端链路；但含 P0-12（单请求打死 / 目录穿越 / 0.0.0.0 / CORS 通配 / `npm start` 崩溃），且只做静态托管、不含任何数据接口 |
| ⑧ | 两个 Web 原型的 localStorage | `index.html:1848/2587` 音量、`1923-1925/3075/3115` 主题与强调色；`mobile.html:1572-1576/1824/2914` 主题与强调色 | 刷新后设置保留（审计侧实测） | 真持久化，但仅覆盖音量/主题/主色；原型播放仍走振荡器合成（K-02），localStorage 不改变这一点 |

---

## 7. 文档声称 vs 代码实现 差距矩阵

> 数据来源：`docs/audit/doc-gap.md`（主表 80 条断言）。本节将其**归并**为 14 个决策层可读的技术主题，不替代原报告的 80 条明细。文档引用格式为 `文档.md:行号`，代码证据格式为 `文件:行号`。

| 模块 | 文档声称（文档:行号） | 实际实现（代码证据） | 结论 | 风险 |
|---|---|---|---|---|
| 1. 播放底座：media_kit + audio_service 双流 / SMTC / 无损解码 | SPEC.md:47、48、176-184、382；ROADMAP.md:28-29 | `app/pubspec.yaml:30-46` 无 media_kit/audio_service（`pubspec.lock` 内 `media_kit`/`audio_service`/`just_audio`/`audioplayers` 0 命中）；「60Hz 高刷流」实为 `audio_player_service.dart:304-329` 的 50 ms `Timer.periodic` 自增；无任何 PlatformChannel 上报代码 | **完全未实现**（0/5） | **P0-01 产品核心价值不成立**：无解码即无发声，进度条是纯计时器 |
| 2. QuickJS 音源沙箱 + Dart Polyfill + 六平台聚合 + 双重降级 | SPEC.md:49、207、229-247；ROADMAP.md:30、116-121 | 无 `flutter_js`（lib 内 QuickJS 仅 `desktop_views.dart:1348` 文案）；无 `globalThis.lx` 注入、无 AES/RSA；`LxCustomScriptDriver` 只做字符串检查(580-586)、`search()` 返回 1 首硬编码(616-636)、直链为假域名(646)；降级算法 `resolveMusicUrlWithFallback`(:1040-1119) 真实但无调用方 | **部分实现**（框架真 / JS 运行时 0 / 数据 6-6 为 mock / UI 接入 0） | P0-07：1836 行音源代码生产不可达；用户以为「导入了脚本就能用」 |
| 3. Drift + SQLite3 + FTS5 + 5 张表 | SPEC.md:56、278-335、384 | pubspec/lock 无 `drift`/`sqlite3_flutter_libs`；`app/lib` 下无 `core/database/` 目录；`SongsTable`/`PlaylistsTable`/`PlaylistSongsTable`/`HistoryTable`/`SourcesTable`/`FTS5` 全仓 0 匹配 | **完全未实现**（0/6） | **P0-02 零持久化**：收藏/历史/歌单/设置/EQ 重启即丢 |
| 4. go_router 强类型 34 路由 | SPEC.md:115、118-157、387 | `app/pubspec.yaml:39` 已声明 `go_router: ^18.0.1`，但 lib 内 `GoRouter`/`GoRoute`/`context.go(`/`context.push(` 0 匹配；`navigation/` 下无 `app_router.dart`；实际为 `_activeView` 字符串 switch（`desktop_scaffold.dart:25、334-358`）与 `_currentTab`（`mobile_scaffold.dart:423-438`） | **与文档不一致**（真实路由 0/34；UI 组件 30/34） | P1-17：无路由栈/无深链接，前进按钮空实现 |
| 5. 双模动效歌词 + 桌面穿透独立歌词窗 | SPEC.md:50、255-269；ROADMAP.md:31、134-140 | LRC 毫秒解析真实（`track_model.dart:14-43`）；lib 内 `Curves.` 0 匹配（无贝塞尔/逐字插值）；无 `desktop_multi_window`；`win32_window.cpp` 无 `WS_EX_TRANSPARENT`/`WS_EX_LAYERED`；AndroidManifest 无 `SYSTEM_ALERT_WINDOW` | **部分实现**（1.5/7） | P2-02：歌词翻译被解析却从不渲染；无穿透歌词窗 |
| 6. 10 频段 libmpv firequalizer EQ + 5 大预设 | SPEC.md:190-200、451；README.md:60 | 10 频段数据层真实（`equalizer_manager.dart:18-29`、`setBandGain` `clamp(-12,12)` :45-51）；`toLibmpvFilterString()`(:81-93) 无生产调用；预设实际 **6 项**（`equalizer_manager.dart:4-14`）而 README 说 5 大、SPEC 说 9 款 | **部分实现**（1/3，仅 UI 数值） | P1-09：第 5 个预设被裁切不可见；调 EQ 对声音零影响 |
| 7. WebDAV 加密双向同步 | SPEC.md:452；ROADMAP.md:104、152 | 服务层真实（PROPFIND/MKCOL/PUT/GET/`sync+LWW`）；**无任何 encrypt/AES 代码**；UI 侧 `desktop_views.dart:1417-1455` 用 `Future.delayed(900ms)` 伪造成功；服务全仓无引用 | **部分实现**（服务层真 / 加密 0 / UI 假成功 / 未接线） | **P0-03 数据丢失 + 误导**：用户以为已备份，实际什么都没发生 |
| 8. LX-Sync 100% 协议兼容（端口 23332 / gzip / 公私钥 / 二维码） | SPEC.md:339-354；ROADMAP.md:154-155 | 端口 23332 真实（`lan_sync_service.dart:112、141-145`）；无 WebSocket、无 RSA/AES，lib 内 `gzip`/`rsa`/`signature` 0 匹配；无 `qr_flutter` 依赖，仅拼 `lxsync://` URI(:96-106)；配对为 6 位码明文比对(:188-201)，密钥用时间种子 LCG(:256-266) | **部分实现**（1.5/6） | P0-04：UI 端口 18585 与代码 23332 不符，服务从未启动；鉴权强度弱（P1-19） |
| 9. 全局键盘快捷键（Space/M/L/Q/ESC/Arrow/Ctrl+K） | README.md:62；SPEC.md:135、447 | lib 内 `Shortcuts`/`RawKeyboard`/`HardwareKeyboard`/`KeyboardListener`/`LogicalKeyboardKey` **全部 0 匹配**；仅 `desktop_scaffold.dart:186` 的「Ctrl K」文案与 `modals.dart:567` 的 hint（原型侧 `index.html:3191-3240` 有完整实现） | **完全未实现** | P0-09：客户端按任何键都无反应，与界面承诺矛盾 |
| 10. 系统托盘 + 无最小尺寸约束 + 真无边框标题栏 | ROADMAP.md:163；SPEC.md:447 | 无 `tray_manager`/`system_tray` 依赖与代码；`win32_window.cpp` 无 `WM_GETMINMAXINFO`/`kMinSize`，窗口为 stock `WS_OVERLAPPEDWINDOW`(:137-138) | **完全未实现**（0/6，2 项部分） | P1-10 + P2-03：窗口可缩到极小且布局崩坏；系统标题栏与应用自绘标题栏并存 |
| 11. 移动端 4 Tab + 9 二级页 + 5 底部抽屉 | SPEC.md:140-157 | Tab **4/4** ✅；二级页 **8/9**（缺 `MobilePlaylistDetailPage`，`mobile_scaffold.dart:423-438` 仅 8 个 case）；抽屉 **2/5**（`MobileEqBottomSheet`/`MobileSleepTimerBottomSheet`/`MobileVolumeModal` 不存在，EQ 与定时器直接复用桌面 `showDialog`，`mobile_sheets.dart:269、277`） | **部分实现**（14/18） | P2-09；SPEC 说 9 页 / PROGRESS 说 8 页 / README 说 9 页，文档内部打架 |
| 12. 六端平台矩阵（Windows / macOS / Linux / Android / iOS / HarmonyOS） | SPEC.md:5、424；ROADMAP.md:159-165 | 5 端为 `flutter create` stock 脚手架、**0 平台定制**（跨平台目录 grep `SMTC`/`MediaSession`/`backgroundTask`/`tray` 0 匹配）；`app/harmonyos/` **只有一个 README.md**（README 中列的 3 个配置文件均不存在）；release.yml **无 iOS job** | **部分实现**（5/6 脚手架、0/6 定制；鸿蒙完全未实现） | P0-05/P0-06（Android 缺 INTERNET、macOS 缺 network.client）；P1-20 平台承诺无法兑现 |
| 13. CI/CD 矩阵发版 | SPEC.md:481-498 | `ci.yml` 2 job ✅、`release.yml` 5 build job + `publish-release` ✅；但 `release.yml:57` 构建机为 `macos-14`（arm64）却命名「Universal」；`release.yml:82` 打包 `app/build/macos/Build/Products/Release/mellow_music.app`，而 `app/macos/Runner/Configs/AppInfo.xcconfig:8` `PRODUCT_NAME = app` → 路径不匹配；`build-android` 未配置 Android SDK 且与 `build-web` 未跑测试 | **部分实现 / 与文档不一致** | **P1-12 macOS 打包步骤必然失败，阻断发版**；门禁覆盖不均 |
| 14. 测试与质量门禁（83/83、47/47、0 issue） | README.md:5、95、109-113；PROGRESS.md:5、59-60；SPEC.md:484 | 静态计数 `test(` **44** + `testWidgets(` **33** = **77** 用例（文档称 47）；`integration_test` 8 例 `flutter test` 默认不执行；`e2e_test.js` 真实 83 个断言点但**对象是 Web 原型**；`flutter_e2e_verify.mjs` 零断言永远 PASS；`flutter analyze` 本机无工具链无法复现，且 `analysis_options.yaml:13` 用 exclude 排除 android/ios/windows/macos/web/linux | **与文档不一致 / 无法验证** | **P1-13、P1-14：质量结论不可信**（详见第 8 节） |

**统计口径（引用 doc-gap.md §3「汇总（按主表 80 条断言计）」）**：

| 结论分类 | 条数 |
|---|---|
| 已实现 | **13 条**（2.5、4.4、5.1、6.1、7.3、9.5、10.1、10.4、12.1、12.2、12.4、13.1、14.1） |
| 部分实现或仅 UI | **14 条**（2.4、2.7、4.5、5.6、6.4、7.1、7.2、7.6、8.1、8.4、9.1、9.4、12.7、13.4） |
| 与文档不一致 | **12 条**（1.5、4.3、4.6、6.3、11.1、11.2、11.3、11.4、12.6、14.2、14.3、14.4） |
| 文档漏写（代码有、文档无） | **1 条**（4.7） |
| 完全未实现 | **39 条** |
| 无法验证 | **1 条**（11.5，本环境无 flutter/dart CLI） |
| 合计 | **80 条** |

另：doc-gap.md 记录**文档内部自相矛盾 8 处**、**代码有而文档无 7 处**。按大项统计的关键命中率：播放底座 0/5、数据库 0/6、路由 0/34（组件 30/34）、桌面交互 0/6、动效歌词 1.5/7、EQ 1/3、同步 1.5/6、移动端 14/18、平台定制 0/6、版本一致性 0/2。

---

## 8. 交付物可信度问题（文档与流水线）

### 8.1 「83/83 E2E 通过」为什么不可信

| 疑点 | 事实 | 证据 |
|---|---|---|
| 测试对象错位 | 83 项套件的对象是 **Web 原型** `index.html` / `mobile.html`（SUITE 1 桌面 1440x900、SUITE 2 移动 390x844），**不是 Flutter 客户端产物** | `e2e_test.js:34-36`、`:331-333` |
| 数字本身是真的，但口径被偷换 | 实测 `Total Scenarios Tested : 83 / Passed 83 / Failed 0`，exit 0 —— 「83」可复现；但它只是 83 个**检查点**，不等于 83 条独立用户旅程，更不覆盖 exe | web-layer.md #18；README.md:5、109-113 |
| CI 从不运行它 | `ci.yml:48` 只跑 `node flutter_e2e_verify.mjs`，全 workflow grep 无 `e2e_test.js` 调用；README 的 83/83 badge 是**静态文本** | web-layer.md #11 |
| 复现前提是断的 | 1) 需手工先起 8088，而 README 第 3 步 `npm start` 实测崩溃（`package.json:5` `"type": "module"` 与 `server.js:1` `require()` 冲突）；2) 套件硬编码 Windows Chrome/Edge 绝对路径 | web-layer.md #10、#12、#48；`package.json:5/8`、`server.js:1` |
| 断言质量低 | 「元素存在即通过」、`$eval(sel, el => !!el)` 恒真、条件断言（找不到元素静默跳过仍记 PASS）、硬编码坐标点击、单个全局 try/catch 无 per-scenario 隔离、**无「必须等于 83」的断言** | web-layer.md #16、#17、#19、#21、#22、#23 |

### 8.2 「47/47 测试通过」为什么不可信

- **数量对不上**：静态计数 `test(` 44 + `testWidgets(` 33 = **77** 个用例（PROGRESS.md:5、60 称 47；SPEC.md:484 称 55）。分文件：lx_source_engine 25、sync_services 15、client_e2e_journey 8、mobile_prototype 6、comprehensive 4+3、alger_features 3、modals_and_lyrics 3、toplist_and_sync 2、integration 8（doc-gap 11.3）。
- **断言的是 mock 自身**：测试把 `mockPresetTracks` 的期望值写死，等于「断言 mock == mock」；同时存在条件断言与两个测试文件整行重复（P1-14，code-review §14）。
- **门禁假覆盖**：`app/integration_test/app_client_e2e_test.dart`（8 个 `testWidgets`）位于 `integration_test/`，`flutter test` **默认不执行**，而 PROGRESS.md:54 声称 CI「包含客户端原生全链路 E2E 旅程测试」——实际 CI 从未运行该目录。
- 结论：47/47 既非真实用例数，也非真实执行范围。

### 8.3 「flutter analyze 0 issue」为什么不可信

- 本机 `Get-Command flutter,dart` 无输出（无 Flutter/Dart 工具链），**结论未经验证**，无法实机复现（doc-gap 11.5，标为「无法验证」）。
- 即便执行，`app/analysis_options.yaml:13` 用 `analyzer.exclude` 排除了 android / ios / windows / macos / web / linux，静态分析范围被收窄到 lib + test，**不构成「全工程 0 issue」的证据**。
- 与之互证的 `flutter_e2e_verify.mjs` 是**零断言脚本**：只 `goto` + 等 canvas + `screenshot` + 无条件打印 `[PASS]`（:135-137、:199-205），关键等待失败被 `catch (_) {}` 吞掉（:121-126），产物缺失/404 页面照样 PASS（:48-58）。它是「假绿灯」的最大单点（P1-13）。

### 8.4 文档与发布卫生问题

| 问题 | 事实 | 证据 |
|---|---|---|
| README 引用 2 张不存在的截图 | `public/showcase_desktop_dark.png`（README.md:18）、`public/showcase_desktop_lyrics.png`（README.md:22）实测 `exists=False`；`e2e_test.js` 也只生成 5 类截图，无法产出这两张 | web-layer.md #33、#34 |
| README 快速启动命令失败 | `npm start` / `node server.js` 实测 exit 1：`ReferenceError: require is not defined in ES module scope` | web-layer.md #10 |
| CI 未固定 Flutter 版本 | `ci.yml:18-20` 与 `release.yml` 5 处均用 `subosito/flutter-action@v2` + `channel: 'stable'`，**无 version 参数**；而 `app/pubspec.lock:620-622` 要求 `dart: ">=3.13.3 <4.0.0"` / `flutter: ">=3.47.0"` | 实测 `ci.yml:18-20`、`release.yml:24/63/106/150/184`、`pubspec.lock:620-622` |
| `release.yml` macOS 产物名不匹配 → 发版流水线跑不通 | `release.yml:82` 打包 `.../Release/mellow_music.app`，而 macOS 工程 `PRODUCT_NAME = app`（`app/macos/Runner/Configs/AppInfo.xcconfig:8`），产物实为 `app.app` → `ditto` 找不到源路径 | 实测；code-review §15；P1-12 |
| macOS「Universal」名不符实 | job 名 `Build macOS Universal` 但构建机为 `macos-14`（arm64）、无 universal 参数 → 单架构产物 | `release.yml:55-57`；doc-gap 12.6 |
| 平台矩阵与文档不符 | `release.yml` 无 iOS job（`needs` 列表仅 windows/macos/linux/android/web），HarmonyOS 无 job | `release.yml:212`；doc-gap 12.5、12.9 |
| **Windows 产物发布卫生** | 仓库内并存 **3 份互相不一致的 Windows 构建副本** + 1 个更早的残留 exe：`release_windows/`（17:37:18，`app.exe` MD5 `4839AFE5…`，`data/app.so` 6,308,744 B）、`app/build/windows/x64/runner/Release/`（16:52，`app.exe` MD5 `1232DE1B…`；目录内还嵌套一份 `mellow-music-windows-x64-release/`，时间戳 15:43）、`app/build/windows/latest_release/`（16:52，`app.so` 6,210,440 B）、以及 15:43 的 `mellow_music.exe`。最新源码 `desktop_views.dart` 为 17:26:19 → **只有 `release_windows/` 与当前源码一致**，另两份与残留 exe 均为过期产物，却都能被误当作交付物取用 | 实测 `Get-ChildItem`/`Get-FileHash`；doc-gap 14.4（产物名 `mellow_music.exe` vs 实际 `app.exe`） |

---

## 9. 做对的部分（保持客观）

> 本节从 `docs/audit/code-review.md` 第 28 节与本次实测中提炼。**问题清单不是全部结论**，以下内容在重构时应原样保留。

| # | 做对的事 | 证据 |
|---|---|---|
| 1 | **设计系统分层干净**：`tokens.dart`（176 行）集中颜色/圆角/阴影/动效时长，`soft_card.dart` / `soft_button.dart` / `recessed_well.dart` / `acoustic_mesh_glow.dart` 统一通过 `context.watch<ThemeProvider>()` 读取主题，**全项目没有散落的硬编码主题色**（仅语境化渐变/品牌色例外）。这是本仓库工程质量最高的部分 | code-review §28.1；本次实测截图 11/12：5 种强调色 + 深浅色切换即时生效且视觉一致 |
| 2 | **dispose 纪律良好**：逐个核对 **12 处 `dispose()`** 定义全部正确释放——AnimationController（`acoustic_mesh_glow.dart:42-45`、`mobile_sheets.dart:40-44`、`mobile_pages.dart:143-146`、`fullscreen_lyrics_view.dart:37-41`）、PageController、ScrollController、TextEditingController ×2（`modals.dart:484-488`、`:751-754`）、Timer ×2（`audio_player_service.dart:332-336`、`:485`）、StreamController ×2（`lan_sync_service.dart:268-271`、`lx_script_sandbox.dart:1224`）；HttpServer 亦有 `stop()` 与 `close(force: true)`。**未发现控制器或 Timer 泄漏** | code-review §28.2 |
| 3 | **同步模块的 LWW 算法与测试方法质量是全仓最好的**：基于 `updatedAt` 毫秒时间戳 + 软删除（`isRemoved`）对收藏/歌单/历史/EQ/播放状态分别合并（`sync_data_model.dart:505+`），并考虑 LX-Sync 报文互转（`:448+`）；测试用 `package:http/testing.dart` 的 MockClient 注入验证 PROPFIND 降级、401 处理、MKCOL+PUT、LWW 回传（`test/sync_services_test.dart:362/396/452/480`），并用 `InternetAddress.loopbackIPv4 + port: 0` 起**真实 HttpServer** 验证握手/配对/投递与鉴权拒绝（`:528-562`）。**这套方法应作为其他模块的模板**——可惜它测的是未接线代码 | code-review §28.3、§28.4 |
| 4 | **AdaptiveScaffold 单断点双壳简洁**：`constraints.maxWidth >= 1024` 一个判断切换桌面/移动两套壳（`adaptive_scaffold.dart:12-21`），代码量与可读性都好 | code-review §28.5；本次实测：1440 px 走桌面壳、430 px 走移动壳，切换判定正确 |
| 5 | **模型层实现规整**：`Track.copyWith` 与 `LyricLine.parseLrc`（`track_model.dart:14-43、74-100`）细节到位，LRC 解析对 2/3 位毫秒做 `padRight(3,'0')`（`:21`），并含排序 | code-review §28.6；doc-gap 5.1 判为「已实现」 |
| 6 | **Web 原型层是真能跑的高保真原型**：83 项 E2E 检查点实测可复现（83/83，exit 0），双端视觉完成度高；且 README.md:7 的 badge 如实写的是 `Audio-Web Audio API Synthesizer`，原型定位本身并未隐瞒 | web-layer.md #18；README.md:7 |
| 7 | **网易云搜索 / 歌单导入 / 歌词三条真实链路可用**：本次实测导入官方热歌榜成功返回 200 首真实曲目，失败时有真实错误提示（不伪造数据） | 本文 §6.1 ①②③；截图 13 |
| 8 | **UI 视觉完成度高、14 个视图均可渲染**：启动后持续轮询 24 s 无崩溃、无未响应（85 个模块）；14 个桌面视图 + 移动壳 + 移动端全屏播放页均正常渲染，无白屏 | 本次实测 S01/S02；截图 16-fullscreen-lyrics.png、17-mobile-player-sheet.png |

---

## 10. 附录（存证截图、复现方法与未验证事项）

### 10.1 存证截图清单（路径：`docs/evidence/pc-e2e/`，共 20 张，均为本次实测产物）

| 文件名 | 一句话说明 |
|---|---|
| `01-launch-window-title-app.png` | 启动即发现：窗口系统标题栏写着模板默认值「app」 |
| `02-artists-avatars-mismatched.png` | 热门歌手头像张冠李戴（Unsplash 无关人物照） |
| `03-four-charts-same-tracks.png` | 四个榜单曲目雷同（同一 6 首池取模错位） |
| `04-local-fake-metadata-dead-button.png` | 本地曲目假元数据（固定 42.8 MB）+「选择本地文件夹扫描」按钮无效 |
| `05-sync-center-fake-devices.png` | 同步中心的编造局域网设备（iPhone 15 Pro / HomePod） |
| `06-cloud-restore-fake-success.png` | 「已成功从 WebDAV 云端合并」实为 `Future.delayed` 定时器伪造 |
| `07-source-manager-empty-shell.png` | LX 音源管理空壳页（导入按钮无响应、开关不可用） |
| `08-eq-modal-preset-clipped.png` | EQ 第 5 个预设「Spatial 3D」被裁切不可见 |
| `09-search-overlay-local-results.png` | 搜索浮层初始结果是本地 mock（未输入即出 6 条） |
| `10-dark-mode-settings.png` | 深色模式下的设置页，仅 3 个板块 |
| `11-before-restart-dark-green-4fav.png` | 重启前：深色 + 绿色强调色 + 4 首默认收藏 |
| `12-after-restart-light-blue-defaultfav.png` | 重启后：全部回到默认，持久化丢失 |
| `13-real-import-worked-cover-missing.png` | 真实导入 200 首成功，但封面缺失、仅预览 5 首 |
| `14-mobile-shell-fake-statusbar-overlap.png` | 移动壳假状态栏（10:09）+ 迷你胶囊遮挡内容 |
| `15-tiny-window-layout-broken.png` | 220x200 窗口布局崩坏 |
| `16-fullscreen-lyrics.png` | 全屏歌词页，功能正常 |
| `17-mobile-player-sheet.png` | 移动端全屏播放页，功能正常 |
| `18-podcast-dead-cards.png` | 声音电台卡片点击播放无关歌曲 |
| `19-history-no-clear-button.png` | 播放历史无移除/清空按钮 |
| `20-favorites-default-hardcoded.png` | 收藏开箱即 4 首（硬编码） |

### 10.2 截图 ↔ 缺陷条目映射（20 张存证）


| 文件名 | 对应条目 |
| :--- | :--- |
| `01-launch-window-title-app.png` | P1-11、P2-03 |
| `02-artists-avatars-mismatched.png` | P1-02 |
| `03-four-charts-same-tracks.png` | P1-01 |
| `04-local-fake-metadata-dead-button.png` | P0-08 |
| `05-sync-center-fake-devices.png` | P0-03、P0-04 |
| `06-cloud-restore-fake-success.png` | P0-03 |
| `07-source-manager-empty-shell.png` | P0-07 |
| `08-eq-modal-preset-clipped.png` | P1-09 |
| `09-search-overlay-local-results.png` | P1-07 |
| `10-dark-mode-settings.png` | P1-06 |
| `11-before-restart-dark-green-4fav.png` | P0-02 |
| `12-after-restart-light-blue-defaultfav.png` | P0-02 |
| `13-real-import-worked-cover-missing.png` | P2-11（真实链路正面结论） |
| `14-mobile-shell-fake-statusbar-overlap.png` | P0-11、P1-10 |
| `15-tiny-window-layout-broken.png` | P1-10 |
| `16-fullscreen-lyrics.png` | §3.5 正面结论（4） |
| `17-mobile-player-sheet.png` | §3.5 正面结论（10）、P0-11 |
| `18-podcast-dead-cards.png` | P1-08 |
| `19-history-no-clear-button.png` | P1-04 |
| `20-favorites-default-hardcoded.png` | P1-05 |

---

### 10.3 本次未能验证 / 待确认事项（诚实清单）

| # | 未能验证 / 待确认的事项 | 原因 / 替代手段 |
| :---: | :--- | :--- |
| 1 | `flutter analyze` / `flutter test` / `flutter build` **未实机执行** | 本机无 Flutter/Dart 工具链（`Get-Command flutter` 不可用）。因此「No issues found!」「47/47 通过」等结论仅为**静态计数复核**，不是运行结论；用例数 44 + 33 = 77 来自源码正则计数 |
| 2 | Android / macOS / iOS / Linux / HarmonyOS 产物**未实机运行** | 仓库内只有 `release_windows/` 一个本地产物，其余平台无产物可运行，仅做静态配置审计（HarmonyOS 甚至只有一个 README.md） |
| 3 | P0-05（Android INTERNET）、P0-06（macOS network.client） | 来自 `AndroidManifest.xml` 与 `macos/Runner/*.entitlements` 的**静态阅读**，**非真机抓包**验证 |
| 4 | P1-12（release.yml macOS 打包名不匹配） | 无 macOS 构建链，未实机执行流水线；结论来自两侧常量比对（`AppInfo.xcconfig:8` PRODUCT_NAME=app vs `release.yml:82` 打包 mellow_music.app） |
| 5 | Web 原型层与 `server.js` 的**破坏性**实测结论 | 引用 `docs/audit/web-layer.md` 的原始 HTTP 输出（进程崩溃、目录穿越、CORS 头等），本次未重复执行这些破坏性请求 |
| 6 | 睡眠定时器「到点停止播放」、EQ 对声音的影响、无损解码等**全部音频类宣称** | 因**不存在音频链路（P0-01）**，物理上不可验证；本次只确认 UI 状态与内存逻辑 |
| 7 | P1-16 / P2-01 / P2-10 / P2-12 的**性能与加载态**表现 | 无 Flutter DevTools 可量化（无 CLI），结论基于代码事实与交互观察 |
| 8 | P2-04 播放状态机边界问题的**用户可见后果** | 静态读码推演，本次未逐项截图复现，复验时应补做 |
| 9 | P0-01 中「系统音量合成器看不到该应用」 | 结论基于「进程音频模块数 = 0」这一**实测硬证据**与听感；若后续接入音频库，该判据需换成「合成器中出现该应用」复验 |
| 10 | P0-03 中「无任何出站请求」 | 由代码（`Future.delayed` 是唯一动作）+ 无生产调用方双重证据得出；本次未做进程级抓包存证，复验建议补一次网络监控 |
| 11 | 网易云在线搜索/导入的**长期可用性与频控行为** | 仅做单次成功导入（200 首）与搜索验证，未做压力或长期稳定性验证 |
| 12 | 移动端与 Web 端 UI 的**真机观感** | 本次仅在 430x860 窗口下观察 Flutter 移动壳（截图 14），未在真机/触屏设备走查 |
| 13 | **一次无法归因现象** | 早期测试中窗口被改为 869x900 且视图变为歌手详情页，未能复现，**未计入任何结论**；复验中若再次出现需作为独立问题排查 |
| 14 | `docs/audit/doc-gap.md` 5.6 称光晕「无 BackdropFilter」 | 与该审计结论不一致：实测 `app/lib/design_system/acoustic_mesh_glow.dart:82-83` **存在** `BackdropFilter + ImageFilter.blur(70)`。本报告采用实测结论，该审计条目应视为**待更正** |

---

### 10.4 验收环境与工具清单（含本次 GUI 自动化复现方法）


**环境**

| 项 | 值 |
|---|---|
| 操作系统 | Windows（桌面会话） |
| 屏幕 | 1920x1080，DPI 96（100% 缩放） |
| 浏览器 | Chrome 与 Edge 均存在（用于原型层审计） |
| Node | v24.14.1 |
| Python | 3.6.8 |
| Flutter/Dart 工具链 | **本机无**（`Get-Command flutter,dart` 无输出）→ 影响见 10.3 |

**被测产物（三份副本辨析）**

| 路径 | 时间戳 | app.exe MD5 | app.so | 判定 |
|---|---|---|---|---|
| `release_windows/` | 2026-09-22 17:37:18 | `4839AFE576D5297AB9B2BCD707ADC9EF` | 6,308,744 B | **本次被测对象**，新于最新源码（`desktop_views.dart` 17:26:19），与当前源码一致 |
| `app/build/windows/x64/runner/Release/` | 16:52（其内嵌套 `mellow-music-windows-x64-release/` 为 15:43） | `1232DE1B96BE1184A03A656A4FFE9684` | — | 早于源码 17:26，**过期产物** |
| `app/build/windows/latest_release/` | 16:52 | — | 6,210,440 B | 早于源码，**过期产物** |
| `app/build/windows/x64/runner/Release/mellow_music.exe` | 15:43 | — | — | 更早的残留 exe，**过期产物** |

**自动化方法（真实用户视角）**

1. **启动真实产物**：直接运行 `release_windows/app.exe`（非源码、非 Web）。
2. **固定窗口几何**：将窗口置为 1440x900 @ (0,0)，保证坐标可复现。
3. **Win32 合成输入**：`SetCursorPos` 移动指针 + `mouse_event`（左键按下/抬起、滚轮）+ `keybd_event` 发送键盘事件；不使用 Flutter 测试框架、不注入 Dart 层。
4. **抓图**：`PrintWindow(hwnd, hdc, PW_RENDERFULLCONTENT)` 抓取窗口位图；失败时回退全屏抓取再裁剪。
5. **像素级测量热区后再点击**（关键改进）：对截图做像素分析定位控件边界，再换算为窗口坐标点击。**侧边栏实测**：条目高 34 px、间距 12 px，热区中心 y = 147/193/239/285/331（第一组 5 项）、419/465/511/557（第二组 4 项）、645/691/733（第三组 3 项），x ≈ 147。
6. **稳定性轮询**：启动后持续轮询进程状态 24 s，确认无崩溃、无「未响应」；记录模块加载数（85）。

**过程透明性说明（必须与结论一并阅读）**

- 第一轮使用**目测坐标**；期间出现过一次**无法归因的现象**（窗口尺寸被改为 869x900 且视图变为歌手详情页，可能来自宿主环境干扰）。此后全部结论都用**像素测量的坐标**重新验证。
- 本文档**不包含**该未能复现的现象，也不据此做任何判定。

## 11. 验收结论与放行建议


### 5.1 结论

**当前产物 `release_windows/app.exe` 不建议发布，也不建议对外演示。**

理由（按决策重要性排序）：

1. **产品定义不成立**：核心能力（出声）不存在（**P0-01**），"音乐播放器"这一名称与事实不符。
2. **用户数据不可留存**：零持久化（**P0-02**），任何真实使用都会在关闭瞬间丢失。
3. **存在欺骗性功能**：云端备份/局域网同步伪造成功（**P0-03 / P0-04**），会让用户误以为数据已备份而放弃手动备份——这是数据安全层面的风险，比功能缺失更严重。
4. **整面板界面文案与技术名词不成立**：libmpv / firequalizer / QuickJS / 24bit·192kHz 无损 / 服务就绪 / 已同步 / 监听中（**P0-07 / P0-09 / P0-10**）。
5. **交付物身份与管道破损**：窗口与全平台应用名为 "app"（**P1-11**）、macOS 发版步骤必然失败（**P1-12**）、CI 零断言假绿灯（**P1-13**）、发布包含陈旧 exe（**P1-20**）。
6. **安全事件**：`server.js` 可被单条请求打死 + 目录穿越 + 0.0.0.0 + CORS 通配 + `npm start` 崩溃（**P0-12**）。

**唯一可以对外展示的部分**：14 个桌面视图的**视觉与布局**（§3.5），以及网易云搜索 / 歌单导入 / LRC 歌词三条真实链路的**联网取数能力**（需明确告知"不能播放、不能保存"）。任何以"功能可用"为前提的演示都不应进行。

### 5.2 重新验收的前置条件（最小修复集，仅引用编号）

按"必须先满足才谈复验"的顺序排列，全部完成后才可重新验收；本表不展开修复方案（方案见配套修复建议书 `docs/PC_E2E_FIX_PLAN.md`）。

**门槛一：先止血（安全与虚假声明）——未完成前不得再发起任何对外演示**

| 序 | 编号 | 复验通过判据（可客观验证） |
| :--- | :--- | :--- |
| 1 | **P0-12** | 畸形 Range / `%ZZ` / `%00` 请求均返回 416/400 且进程存活；`/../` 类路径返回 403；监听 127.0.0.1；`.git`/`node_modules` 等敏感路径 403；`npm start` 可正常启动 |
| 2 | **P0-03 / P0-04 / P0-07 / P0-08 / P0-10** | 界面上所有未实现能力的文案与假按钮**被移除或明确标注"未实现"**；不再出现无网络请求的"同步成功"，不再出现"服务就绪 / 18585 监听中 / QuickJS / libmpv / 1836 行引擎"式声明 |
| 3 | **P0-05 / P0-06** | release 变体具备 INTERNET 权限与 `network.client` entitlement（可用 `aapt dump permissions` 与 `codesign -d --entitlements` 验证） |
| 4 | **P0-11** | 移动壳内不再有假 iOS 状态栏与 "Mobile" 调试角标；固化 mock 的测试断言（`find.text('10:09')`）被删除 |
| 5 | **P1-11 / P1-12 / P1-13 / P1-20（发布卫生）** | 窗口标题与全平台应用名品牌化；发版流水线可完整跑通并产出正确命名的产物；CI 具备真实断言且运行 83 项套件；发布包内只有一个可执行文件且与源码一致（§1.2 的三份副本收敛为一） |
| 6 | **P0-09 / P1-17** | 移除"Ctrl K""按 ESC 退出""退出全屏 (ESC)"等假文案，或补上真实键盘处理与前进按钮实现 |

**门槛二：核心能力闭环——未完成前不得对外宣称"音乐播放器"**

| 序 | 编号 | 复验通过判据 |
| :--- | :--- | :--- |
| 7 | **P0-01** | 点击播放后扬声器真实出声；系统音量合成器可见该应用；系统媒体控制（SMTC）可用；`Timer.periodic(50ms)` 手工 ticker 已删除 |
| 8 | **P0-02** | §2.5 重启对比实验四项（主题/强调色/收藏/进度）全部保持，且导入歌单、EQ 曲线一并保留 |
| 9 | **P1-16** | 进度只驱动叶子组件，播放期间无 20Hz 全树 rebuild |
| 10 | **P1-09 / P2-02** | EQ 预设完整可见且可发现（或有明确滚动提示）；EQ 真实作用于声音；预设数量在 SPEC/README/代码三处口径统一 |

**门槛三：数据与内容真实性——未完成前不得宣称"内容平台"**

| 序 | 编号 | 复验通过判据 |
| :--- | :--- | :--- |
| 11 | **P1-01 / P1-02 / P1-03 / P1-05** | 榜单曲目池各不相同；歌手头像与本人对应、简介/粉丝数来源可追溯且跨页一致；歌单广场展示真实歌单实体；无预置收藏与预置"已关注" |
| 12 | **P1-04 / P1-06 / P1-07 / P1-08 / P2-11** | 历史无冷启动自插且支持单曲移除与一键清空；设置中心补足音质与缓存项；搜索初始为空、ESC 有效、网络失败有提示；电台具备单集模型；导入歌单可查看全部曲目且封面正常 |
| 13 | **P1-18 / P1-19** | 关键控件具备语义标注；在线数据来源合规、不依赖明文凭据与非公开接口 |

**门槛四：工程与质量基础设施**

| 序 | 编号 | 复验通过判据 |
| :--- | :--- | :--- |
| 14 | **P1-14 / P1-15 / P1-20** | 测试数量与文档一致且无逐行重复文件；清理零引用依赖并补齐关键依赖；死代码清理或接入；版本号建立单一事实源；补充错误上报 |
| 15 | **P1-10 / P2-01 / P2-03 / P2-04 / P2-05 / P2-06 / P2-07 / P2-08 / P2-09 / P2-10 / P2-12** | 窗口最小尺寸约束与响应式断点统一；列表懒加载；单标题栏；状态机边界修正；设计 token 单一事实源；README 截图与启动命令可用；原型播放与 mp3 引用一致；双端数据单一事实源；移动端补齐缺失页与抽屉；图片加载态与缓存；音频焦点/后台播放/wakelock 与日志上报 |

### 5.3 复验方式要求

1. 复验必须使用**与当前源码一致的产物**（以 `app.so` 时间戳晚于最新源码文件为准，见 §1.2），并在验收记录中写明该产物的路径、时间戳与 MD5；三份副本必须收敛为一。
2. 复验必须复用 §2 的方法（像素级热区测量 + 真实输入合成 + 重启对比实验 + 模块取证），**不接受仅凭截图或仅凭代码阅读的放行结论**。
3. 门槛一的第 2 项（移除虚假声明）具有独立性：可与其它修复并行，且**必须在任何对外演示之前完成**。

---


---

*本报告为 PC 端产物 E2E 验收的问题文档。修复方案见 docs/PC_E2E_FIX_PLAN.md；四份原始审计报告见 docs/audit/；20 张实测存证截图见 docs/evidence/pc-e2e/。所有结论均可回溯到代码「文件:行号」或实测截图；无法确认的事项已在 10.3 节明确标注，未做推测性断言。*
