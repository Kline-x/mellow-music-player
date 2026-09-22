# Mellow Music · 润音 — PC 端 E2E 验收问题修复建议书

> **文档性质**：可排期执行的技术修复方案（不是问题清单，问题清单见 `docs/audit/` 四份审计报告）。
> **依据材料**：`docs/audit/code-review.md`（28 条 Flutter 代码问题，含 file:line）、`docs/audit/doc-gap.md`（文档声称 vs 代码实现，主表 80 条断言）、`docs/audit/fake-data.md`（假数据全量清单 174 条，含「真可用链路」8 条）、`docs/audit/web-layer.md`（Web 原型层与 server.js 安全审计，含实测 HTTP 证据）。
> **问题编号**：严格沿用验收方已确认的 ID 体系（P0-01~P0-12 / P1-01~P1-20 / P2-01~P2-12）。`docs/PC_E2E_ACCEPTANCE_ISSUES.md` 在本仓库中**不存在**，本文直接引用上述 ID。
> **行号口径**：本文所有 `文件:行号` 均由本轮逐行读取源码重新核对（读不到的一律不写行号）。与审计报告标注存在 ±1 行差异时以本文为准。
> **环境限制**：本机未安装 Flutter/Dart 工具链，所有涉及 `flutter analyze` / `flutter test` / `flutter build` 的验收标准均标注为「需在装好工具链的机器上执行」，不做已通过的断言。

---

## 1. 摘要

**一句话现状**：这是一个视觉完成度很高、但功能内核几乎全为模拟数据的 UI 演示工程（high-fidelity prototype）——**没有任何音频解码与播放能力**（`app/pubspec.yaml:30-46` 无音频依赖，`audio_player_service.dart:305-329` 用 50ms `Timer.periodic` 伪造播放进度）、**零持久化**（`app/lib` 内 SharedPreferences 命中 0）、**同步/音源/本地导入三个重功能模块是假成功或死代码**，却被 `README.md`、`docs/SPEC.md`、`docs/PROGRESS.md` 对外声明为「生产级跨平台音乐播放器」，`docs/PROGRESS.md:5` 声称「Phase 0~5 全量交付完毕、47 项测试 100% 通过」。

**两条可选路线**：

| 路线 | 内容 | 工作量 | 交付物性质 |
| :--- | :--- | :--- | :--- |
| **A. 诚实化止损** | 只做阶段 0 + 阶段 4 的「删除分支」+ 阶段 6/7 的文档与发布修正。移除所有未落地能力的技术名词、假按钮、假成功提示，文档降级为「UI 原型 + 路线图」 | **约 3~4 人日** | 一个**诚实的 UI 原型**：不撒谎，但仍然不能放歌 |
| **B. 补实现做成真产品** | 阶段 0 → 7 全量执行：真播放、真持久化、真数据、真路由与快捷键、真门禁 | **约 29~49 人日**（1 名熟练 Flutter 工程师 6~10 周） | 一个**可用的本地音乐播放器**（MVP 见第 6 章），跨平台发布链路可跑通 |

**推荐：先执行阶段 0（1~2 人日，无论走哪条路都必须做），随后走路线 B，但用第 6 章的「10 天 MVP」切片交付，而不是按阶段 0→7 顺序从头做到尾。**

**推荐理由**：
1. 阶段 0 的成本极低（1~2 人日），但消除的是**信任与安全层面**的风险（假成功提示、目录穿越 + 未认证 DoS、明文账号、发版流水线跑不通），任何路线都必须做。
2. 当前代码并非「从零重写」的处境：设计系统分层干净（`tokens.dart` 176 行集中管理，全项目无散落硬编码主题色）、12 处 `dispose()` 全部正确、`sync_services_test.dart` 是真实有效测试、LWW 合并算法与 LRC 解析器可直接复用（见 `code-review.md` 第 28 节）。**UI 层 11245 行（除数据来源外）基本可以保留**，真实工程量的 80% 集中在「底座替换 + 数据层抽象」，不是重画界面。
3. 反过来，如果继续按当前文档口径对外交付，风险不是「功能缺失」（用户会失望），而是「**数据安全层面的欺骗**」——用户以为云端备份成功（`desktop_views.dart:1417-1435` 只 `Future.delayed(900ms)` + 假 SnackBar），于是放弃手动备份，换机后数据为零。

---

## 2. 修复原则

1. **先止损，再补实现。** 阶段 0 必须独立于一切功能开发先行合入。理由：假成功提示（P0-03）、假按钮（P0-07/08）、假状态栏（P0-11）与真实现无关，删掉它们不会阻塞任何后续开发，却立刻消除「误导用户」这一最高等级的产品风险。
2. **任何未落地的能力，禁止在 UI 上出现技术名词。** 具体禁止清单（当前全部违反）：`libmpv`、`firequalizer`、`DSP`、`硬件均衡器`、`QuickJS`、`无损`、`Hi-Res`、`24bit/96kHz`、`24bit/192kHz`、`DSD`、`APE`、`实时云端同步`、`服务就绪`、`监听中`、`已缓存 N 首`。判定标准：**打开 APK/exe 的「关于」与任意页面文案，逐条能对应到一行真实代码；对应不上的删掉。**
3. **测试不得断言 mock。** 禁止三类写法：断言 mock 自身生成的字符串（`lx_source_engine_test.dart:169-176`）、`if (find.xxx.evaluate().isNotEmpty)` 条件断言（`desktop_modals_and_lyrics_test.dart:53-58`）、把假实现当契约（`desktop_toplist_and_sync_test.dart:106-123` 断言假同步的 900ms 延迟 + 假设备名）。**任何一条测试，必须在「被它保护的生产代码被改坏」时变红**，否则删除。
4. **每条修复都必须带可测验收标准。** 不接受「优化体验」「提升观感」这类无法验收的描述。本文所有验收标准均可由命令、断言或一段固定操作流程复现。
5. **单一事实来源。** 版本号、设计 token、EQ 参数、曲库数据、端口号，各自只能有一个定义处，其余引用方读取它。当前版本号有 4 处（`pubspec.yaml:19` = 1.0.0+1 / UI `desktop_views.dart:1383` = v2.1.0 / `SPEC.md:3` = v1.1.0 / `PROGRESS.md:3` = v1.0.0）。
6. **删除也是一种交付。** 阶段 4 的两个二选一（同步、LX 音源），删除分支的收益（消除 3319 行不可达代码 + 1 个误导页面 + 1 个假开关）往往高于立刻实现。
7. **不允许把「补测试」当作「修功能」。** 先让功能真实，再为其写测试；反过来会固化假实现。

---

## 3. 分阶段修复计划

### 阶段 0（止血）— 1~2 人日

**目标**：让工程「不再说谎、不再自伤」，且不引入任何新功能。合入后，产品对外可诚实描述为「UI 原型」，服务端不再可被单请求打死，发版流水线的产物名错误被修正。

#### 0.1 P0-12 server.js：单请求 DoS + 目录穿越 + 0.0.0.0 + CORS 通配 + npm start 崩溃

**动作 A（最高优先级，`server.js` 整文件替换处理器）**。当前三处致命缺陷位置已核实：`server.js:35`（`decodeURI` 无保护，`GET /%ZZ` 抛 `URIError` 打死进程）、`server.js:40/44`（`path.join` 无前缀校验，`GET /../qa_canary_secret.txt` 实测 200 返回工程根目录外文件）、`server.js:62-68`（Range 内 `parseInt` 结果未校验，`bytes=abc-` / `bytes=-500` / `bytes=100-50` / `bytes=99999999-` 四种 payload 均实测杀进程）。

把 `server.js:24-86` 的整个 `http.createServer` 回调替换为（保留 `:1-22` 的 require 与 MIME 表，补全 `.md/.txt/.ico/.wasm/.ttf/.woff2`）：

```js
// server.cjs —— 替换原 server.js:24-90 的 createServer 回调（保留 :1-22 的 require 与 MIME 表）
const ROOT = path.resolve(__dirname);
const PUBLIC_DIR = path.join(ROOT, 'public');
const DENY = ['.git', 'node_modules', '.github', '.qa', 'release_windows', 'build'];
const ROOT_PREFIX = ROOT + path.sep;

function safeResolve(reqPath) {
  const rel = path.posix.normalize('/' + reqPath.replace(/\\/g, '/'));
  if (rel.includes('\0')) return null;                       // 空字节注入
  for (const base of [ROOT, PUBLIC_DIR]) {
    const abs = path.resolve(base, '.' + rel);
    if (!abs.startsWith(ROOT_PREFIX)) continue;               // 逃逸出工程根目录
    const segs = path.relative(ROOT, abs).split(path.sep);
    if (segs.some((s) => s.startsWith('.') || DENY.includes(s))) continue;
    return abs;
  }
  return null;                                                // 交给上层回 403
}

const server = http.createServer(async (req, res) => {
  try {
    if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405, { Allow: 'GET, HEAD' }); return res.end(); }
    // 不再发 CORS 通配头；如需跨域，按 Origin 白名单单独下发

    let reqPath;
    try { reqPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
    catch { res.writeHead(400); return res.end('400 Bad Request'); }   // 修 decodeURI 抛 URIError 打死进程

    if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
    const filePath = safeResolve(reqPath);
    if (!filePath) { res.writeHead(403); return res.end('403 Forbidden'); }

    let stats;
    try { stats = await fs.promises.stat(filePath); } catch { res.writeHead(404); return res.end('404 Not Found'); }
    if (!stats.isFile()) { res.writeHead(404); return res.end('404 Not Found'); }

    const total = stats.size;
    const type = MIME_TYPES[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
    const head = { 'Content-Type': type, 'Accept-Ranges': 'bytes' };

    const range = req.headers.range;
    const m = range && !String(range).includes(',') ? /^bytes=(\d*)-(\d*)$/.exec(String(range)) : null;
    if (!m) {   // 无 Range / 多段 Range → 回 200 全量（不再返回错误的单段）
      res.writeHead(200, { ...head, 'Content-Length': total });
      if (req.method === 'HEAD') return res.end();
      const s = fs.createReadStream(filePath); s.on('error', () => res.destroy()); return s.pipe(res);
    }

    const [, a, b] = m;
    let start, end;
    if (a === '') { const n = Number(b); start = Number.isInteger(n) && n > 0 ? Math.max(0, total - n) : NaN; end = total - 1; }
    else { start = Number(a); end = b === '' ? total - 1 : Number(b); }
    if (!Number.isInteger(start) || !Number.isInteger(end) || start > end || start >= total) {
      res.writeHead(416, { 'Content-Range': 'bytes */' + total }); return res.end();   // 修 EOF 越界 / start>end / NaN 打死进程
    }
    end = Math.min(end, total - 1);
    res.writeHead(206, { ...head, 'Content-Range': 'bytes ' + start + '-' + end + '/' + total, 'Content-Length': end - start + 1 });
    if (req.method === 'HEAD') return res.end();
    const stream = fs.createReadStream(filePath, { start, end }); stream.on('error', () => res.destroy()); stream.pipe(res);
  } catch (err) { res.writeHead(500); res.end('500 Internal Server Error'); }
});

process.on('uncaughtException', (err) => console.error('[fatal]', err));   // 进程级兜底
const HOST = process.env.MELLOW_HOST === 'lan' ? '0.0.0.0' : '127.0.0.1';  // 默认只听本机
server.listen(PORT, HOST, () => console.log('Server running at http://' + HOST + ':' + PORT + '/'));
```

同时：删除 `server.js:25` 的 `Access-Control-Allow-Origin: '*'` 通配（改为不发 CORS 头；如确需跨域，用 `Origin` 白名单比对 `http://localhost:${PORT}`），并在 `server.js:29-33` 的 OPTIONS 分支保留最小预检响应。

**动作 B（`npm start` 崩溃修复）**。根因已核实：`package.json:5` 的 `"type": "module"` 使 `.js` 被当作 ESM，而 `server.js:1-3` 用的是 `require`。最小改动（不影响同为 ESM 的 `e2e_test.js` 与 `flutter_e2e_verify.mjs`）：**将 `server.js` 重命名为 `server.cjs`**，并同步 `package.json:6` 的 `"main"` 与 `package.json:8-10` 的 `start` 脚本：

```json
"main": "server.cjs",
"scripts": {
  "start": "node server.cjs",
  "test": "node e2e_test.js",
  "test:e2e": "node e2e_test.js",
  "pretest": "node server.cjs & node -e \"setTimeout(()=>{},1000)\" || exit 0"
}
```

（`pretest` 在 Windows 上不可靠，阶段 6 用 `start-server-and-test` 替换；阶段 0 只需保证 `npm start` 能起来。）

**验收标准（可测）**：
1. `node server.cjs` 启动成功，输出 `Server running at http://127.0.0.1:8088/`；用原始 TCP socket 发 `GET /%ZZ`、`GET /%00.html`、`Range: bytes=abc-`、`Range: bytes=-500`、`Range: bytes=100-50`、`Range: bytes=99999999-` 六条 payload 后，服务进程仍存活（后续 `GET /index.html` 返回 200）。
2. `GET /../<工程根目录外的文件>`、`GET /..%5c<...>`、`GET /%2e%2e/<...>`、`GET /.git/config`、`GET /node_modules/puppeteer-core/package.json` 全部返回 **403**（不再是 200）。
3. `Range: bytes=0-999999999` 返回 `206` 且 `Content-Range` 的 end 被裁剪为 `totalSize-1`，`Content-Length` 与实际字节数一致；`Range: bytes=0-9,20-29` 返回 200 全量而非 206 单段。
4. `HEAD /` 不再返回 body；`POST /` 返回 405。
5. 从零克隆后按 `README.md:126-136` 操作，第 3 步 `npm start` 成功（当前在第 3 步即 `ReferenceError: require is not defined` 退出 1）。

**涉及文件**：`server.js`（重命名为 `server.cjs`）、`package.json`。
**风险**：`path.resolve` 前缀校验在 Windows 上对大小写不敏感（NTFS），需用 `path.relative` 判定而非字符串 `startsWith`（上方骨架已采用 `path.relative`）。低。
**注意（P1-19 关联）**：`public/audio/*.mp3` 4 个文件（8.53+9.75+7.88+7.45 = 33.6 MB）全仓零引用，阶段 0 先将其与 `.qa/` 一并加入 `.gitignore`（当前 `.gitignore` 无这两项），是否删库由阶段 3 决定。

#### 0.2 P0-03 / P0-04 / P0-07 / P0-08 / P0-10 / P0-11 的 UI 侧：删除假声明与假按钮

**目标**：不实现任何功能，只让 UI 停止说谎。逐条动作如下（均为「改哪一行 / 换成什么」级别）。

| ID | 文件:行号 | 具体动作 |
| :--- | :--- | :--- |
| P0-03 | `desktop_views.dart:1417-1435` | 删除 `_triggerUpload()` 整个方法体，替换为 `setState(() => _syncStatusText = '云端同步尚未实现');` + SnackBar 文案改为「云端同步功能尚未实现，请勿依赖此页面备份数据」 |
| P0-03 | `desktop_views.dart:1437-1455` | 同上处理 `_triggerRestore()`，文案改为「云端恢复功能尚未实现」 |
| P0-03 | `desktop_views.dart:1414-1415` | 删除硬编码端点与账号两行（`dav.jianguoyun.com` / `gaore@mellow.music`）；页面若保留则两处显示为「未配置」 |
| P0-03 | `desktop_views.dart:1632` | 删除硬编码「服务就绪」绿标（`const Row`），或替换为绑定真实状态的「未配置」灰标 |
| P0-03 | `desktop_views.dart:1526` | 「已同步红心收藏」→「本地红心收藏」 |
| P0-03 | `desktop_views.dart:1684-1689` | 「后台自动定时同步 (每 30 分钟)」开关：删除该开关（`startAutoSync` 无调用方，见 `fake-data.md` E7） |
| P0-04 | `desktop_views.dart:1733` | 「本机端口: 18585 监听中」→ 删除整行（真实默认端口为 `lan_sync_service.dart:112` 的 23332，且服务从未启动） |
| P0-04 | `desktop_views.dart:1755`、`1799` | 删除两个硬编码假设备（iPhone 15 Pro / HomePod）整个卡片区块 |
| P0-04 | `desktop_views.dart:1774-1779`、`1814-1822` | 删除「投送当前播放列表」「无线音频接力」两个假成功 SnackBar 按钮 |
| P0-07 | `desktop_views.dart:1357` | 「在线导入音源链接」按钮 `onTap: () {}` → `onTap: null` 并加 `enabled: false` 视觉禁用，或整按钮删除 |
| P0-07 | `desktop_views.dart:1391` | `Switch.adaptive(value: true, onChanged: (_) {})` → 删除该 Switch |
| P0-07 | `desktop_views.dart:1348-1349`、`1383`、`1387` | 「自定义音源管理 (QuickJS)」→「音源管理（未实现）」；「v2.1.0 · 运行中」→ 删除；「支持全网多引擎搜索、FLAC/320k 直链动态解析」→ 删除 |
| P0-08 | `desktop_views.dart:1174` | 「选择本地文件夹扫描」`onTap: () {}` → 同上禁用或删除 |
| P0-08 | `desktop_views.dart:1182-1202` | 删除「已解析本地曲目」整段（当前直接遍历 `mockPresetTracks`，且 `:1195` 每行固定显示「FLAC 24bit/96kHz · 42.8 MB」） |
| P0-08 | `desktop_views.dart:1166-1168` | 「拖拽音频文件或文件夹至此」「支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式」→ 改为「本地导入尚未实现」 |
| P0-10 | `modals.dart:199` | 「声学 10 频段硬件均衡器 (DSP EQ)」→「均衡器（调节暂不影响声音）」 |
| P0-10 | `modals.dart:207` | 「基于 libmpv firequalizer 高保真声学校准」→ 整行删除 |
| P0-10 | `desktop_views.dart:79` | 「精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出」→「精选 6 首演示曲目（演示数据）」 |
| P0-10 | `desktop_views.dart:1168`、`1383`、`1632` | 见上表对应行 |
| P0-10 | `mobile_pages.dart:611` | 「已缓存 6 首无损音频 · 占用空间 182 MB」→ 删除整行（无缓存实现） |
| P0-10 | `mobile_pages.dart:86`、`629` | 「高品质无损回放」「FLAC 24bit · 42.8 MB」→ 删除 |
| P0-10 | `desktop_views.dart:79` 等全部版本号文案 | 统一改为从 `package_info_plus` 读取（阶段 7 落地）；阶段 0 先删除「v2.1.0」「Mellow v2.1.0」等硬编码版本字符串（`:1383`、`:1766`） |
| P0-11 | `mobile_scaffold.dart:104-113` | 删除硬编码 `Text('10:09', ...)` 整块 |
| P0-11 | `mobile_scaffold.dart:173-183` | 删除假信号 / WiFi / 电池三组 `Icon` |
| P0-11 | `mobile_scaffold.dart:116-171` | 「灵动岛」胶囊：保留（它是品牌设计语言，且承担打开播放弹层的真实交互 `:118-125`），但**从 `SafeArea` 内移到内容区**，并改名「迷你播放胶囊」；同步更新测试断言 |
| P0-11 | `app/test/mobile_prototype_1to1_test.dart:64-70` | 删除 `expect(find.text('10:09'), findsOneWidget)`（这是把 mock 固化为契约，见原则 3） |
| P2-06 | `README.md:18`、`:22` | `public/showcase_desktop_dark.png` 与 `public/showcase_desktop_lyrics.png` **实测不存在**；改为引用已存在的 `public/e2e_desktop_verified.png` / `public/showcase_mobile_eq.png`，或补齐生成步骤后再引用 |
| P2-06 | `README.md:5`、`:104-115` | 「83/83 Passed」静态 badge 与手写报告正文：改为「Web 原型 E2E：需先 `node server.cjs` 且本机装有 Chrome」的前置说明；badge 改用 workflow status badge（阶段 6 落地） |
| P2-06 | `README.md:126-136` | 「快速启动」第 2/3 步补前置条件与预期输出（配合 0.1-B） |

**验收标准（可测）**：
1. 在 `app/lib` 全文检索以下字符串**命中 0**（除注释与测试）：`libmpv`、`firequalizer`、`QuickJS`、`24bit/192kHz`、`24bit/96kHz`、`已缓存 6 首`、`服务就绪`、`18585`、`已同步红心收藏`、`v2.1.0`。
2. 在 `app/lib` 全文检索 `onTap: () {}` 与 `onChanged: (_) {}` **命中 0**。
3. 在 `app/lib` 全文检索 `Future.delayed(const Duration(milliseconds: 900))` **命中 0**。
4. 手工走查同步中心页，点击任意按钮不再出现「已成功…备份至 WebDAV 云端」字样。
5. `mobile_prototype_1to1_test.dart` 中不再存在对 `'10:09'` 的断言。

**涉及文件**：`app/lib/views/desktop/desktop_views.dart`、`app/lib/views/mobile/mobile_pages.dart`、`app/lib/views/common/modals.dart`、`app/lib/navigation/mobile_scaffold.dart`、`app/test/mobile_prototype_1to1_test.dart`、`README.md`。
**风险**：删除假设备/假同步区块后，`desktop_toplist_and_sync_test.dart:106-123` 必然变红——**这是正确行为**，同步在阶段 0 中删除该用例（阶段 6 重写）。

#### 0.3 P0-05 / P0-06：Android INTERNET 与 macOS network.client

**动作 A（P0-05）**：`app/android/app/src/main/AndroidManifest.xml` 全文 45 行无任何 `uses-permission`（已核实）。在第 1 行 `<manifest ...>` 之后、第 2 行 `<application` 之前插入：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```

（`WAKE_LOCK` / `FOREGROUND_SERVICE*` 为阶段 1 的后台播放预留；若阶段 0 只想修 P0-05，至少补前两条。）同时把 `AndroidManifest.xml:3` 的 `android:label="app"` 改为 `android:label="Mellow Music"`（属 P1-11，顺手做）。

**动作 B（P0-06）**：`app/macos/Runner/Release.entitlements` 全文只有 `app-sandbox` 一个键（已核实，8 行）。在第 5-6 行后插入：

```xml
<key>com.apple.security.network.client</key>
<true/>
```

若阶段 4 选择接线 LAN 同步（会 `HttpServer.bind`），再加 `com.apple.security.network.server`。

**验收标准（可测）**：
1. 在装有 Android SDK 的机器执行 `flutter build apk --release`，然后 `aapt dump permissions app/build/app/outputs/flutter-apk/app-release.apk` 输出包含 `android.permission.INTERNET`。（当前 `.github/workflows/release.yml:161` 正是 `flutter build apk --release`。）
2. 将该 APK 装到真机，搜索框输入关键词能产生真实网络请求（用抓包或 `adb logcat` 观察），失败时不再静默（配合阶段 3）。
3. macOS：`codesign -d --entitlements - <产物>.app` 输出包含 `com.apple.security.network.client`。
4. 在 `.github/workflows/release.yml` 的 `build-android` job 中新增断言步骤，缺权限即 exit 1（防回归）。

**涉及文件**：`app/android/app/src/main/AndroidManifest.xml`、`app/macos/Runner/Release.entitlements`、`.github/workflows/release.yml`。
**风险**：极低。若阶段 0 决定「暂不出包」，本项可推迟，但**必须在第一次对外发版前完成**。



#### 0.4 P1-12：修正 release.yml 的 macOS 产物名，让发版流水线可跑通

**根因（已核实）**：`.github/workflows/release.yml:82` 打包的是 `app/build/macos/Build/Products/Release/mellow_music.app`，而真实产物名由 `app/macos/Runner/Configs/AppInfo.xcconfig:8` 的 `PRODUCT_NAME = app` 决定，即 **`app.app`**。该步骤必然失败 → `build-macos` job 失败 → `publish-release`（release.yml:212 `needs: [build-windows, build-macos, build-linux, build-android, build-web]`）整体不触发。

**动作**：
1. 阶段 0 最小修法：把 `release.yml:82` 的 `mellow_music.app` 改为 `app.app`。
2. 推荐修法（与 P1-11 品牌化合并）：在阶段 7 把 `AppInfo.xcconfig:8` 的 `PRODUCT_NAME` 改为 `Mellow Music`，并把 `release.yml:82` 改为动态查找，避免再次硬编码：

```yaml
- name: Package macOS Binary
  run: |
    APP_PATH=$(find app/build/macos/Build/Products/Release -maxdepth 1 -name "*.app" | head -n1)
    test -n "$APP_PATH" || { echo "macOS .app not found"; exit 1; }
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" Mellow-Music-macOS.zip
```

3. 顺手修 `release.yml:56` 的误导命名：`name: Build macOS Universal` 实为 `macos-14`（arm64）单架构产物，要么改名为 `Build macOS (arm64)`，要么补 `--config-only`/universal 构建参数（阶段 7）。

**验收标准（可测）**：
1. 在 mac 机器（或 CI）执行 `ditto -c -k --sequesterRsrc --keepParent <find 结果> Mellow-Music-macOS.zip`，命令退出码 0 且产物存在。
2. 推一个测试 tag（如 `v0.0.1-rc1`）后，GitHub Actions 的 6 个 job（`build-windows`/`build-macos`/`build-linux`/`build-android`/`build-web`/`publish-release`）全部为绿，Release 页出现 5 个附件。

**涉及文件**：`.github/workflows/release.yml`（若采用推荐修法再加 `app/macos/Runner/Configs/AppInfo.xcconfig`）。
**风险**：极低；纯 CI 脚本错误，当前是「流水线 100% 必失败」，改动只会让它变好。

#### 0.5 文档诚实化（P0-10 的文档侧 + P1-20 的版本口径）

**动作**：
1. `docs/PROGRESS.md:5`、`:13`、`:19`、`:44`、`:49`：把「Phase 0~5 全量交付完毕」「47 项测试 100% 通过」「LX-Sync 100% 兼容」改为如实口径。可测口径（本轮实测）：`app/test` 8 文件 + `app/integration_test` 1 文件合计 **77** 个用例（`test(` 44 + `testWidgets(` 33），其中 `integration_test` 目录默认不被 `flutter test` 执行。`docs/PROGRESS.md:13` 的「e2e_test.js (83/83 通过)」指的是 **Web 原型**（`index.html`/`mobile.html`），必须标注测试对象，不能作为客户端交付证据。
2. `docs/PROGRESS.md:15-20`：Phase 1~6 的「已完成 🟢 100%」改为「代码就绪、未集成」（针对音源引擎与同步服务）或「未实现」（针对播放底座、数据库、路由、快捷键）。
3. `docs/PROGRESS.md:16`、`:19`：为 `core/sources/` 与 `core/sync/` 标注「**生产不可达**：`app/lib` 内 import 数 0，仅测试引用」。
4. `docs/SPEC.md:3` 与 `docs/PROGRESS.md:3` 与 `README.md` 的版本号口径统一（阶段 6 建立单一来源）。
5. `app/README.md` 仍是 `A new Flutter project.` 模板（已核实）——阶段 0 至少替换为三行：环境要求、构建命令、已知限制（当前无播放能力）。

**验收标准（可测）**：
1. `Select-String -Path docs/PROGRESS.md,docs/SPEC.md,README.md -Pattern '100%|全量交付|100% 通过'` 的命中行，逐行人工核对后不存在无法用一行代码/一条命令证明的声称。
2. `docs/PROGRESS.md` 中引用的测试数字与 `app/test`+`app/integration_test` 的实际计数一致（当前真实值 77）。
3. `app/README.md` 不再是 Flutter 模板。

**涉及文件**：`docs/PROGRESS.md`、`docs/SPEC.md`、`README.md`、`app/README.md`。
**风险**：低。需要注意「不要过度删除」——路线图（`docs/ROADMAP.md`）作为未来规划可以保留，但需在文首加一行「本文件为规划，非交付证据」。

#### 阶段 0 出口标准（合入前必须全部为真）

- [ ] `node server.cjs` 可启动；六条 DoS payload 后进程存活；穿越读文件返回 403。（P0-12）
- [ ] `app/lib` 内 `onTap: () {}` / `onChanged: (_) {}` / `Future.delayed(...900ms)` / `libmpv` / `QuickJS` 命中 0。（P0-03/07/08/10）
- [ ] `mobile_scaffold.dart` 不再渲染假时钟与假状态图标。（P0-11）
- [ ] Android main manifest 含 `INTERNET`；macOS Release.entitlements 含 `network.client`。（P0-05/06）
- [ ] `release.yml` 的 `.app` 名与真实产物一致。（P1-12）
- [ ] `README.md` 不再引用不存在的截图；快速启动命令可复现。（P2-06）
- [ ] `docs/PROGRESS.md` 不再声称 47/47 与 Phase 全量完成。（P1-20 文档侧）

---

### 阶段 1（播放底座）— 5~8 人日

**目标**：让「播放」成为事实。**这是整个项目最关键的一步**——没有它，后续所有功能都建立在假地基上。

#### 1.1 P0-01：接入 media_kit + audio_service，彻底删除 50ms ticker

**依赖变更（`app/pubspec.yaml:30-46`）**：

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.5+1
  http: ^1.6.0
  # --- 阶段 1 新增 ---
  media_kit: ^1.1.11
  media_kit_libs_windows_audio: ^1.0.9      # 各平台按需：windows/macos/linux/android/ios
  media_kit_libs_android_audio: ^1.3.6
  media_kit_libs_macos_audio: ^1.1.4
  audio_service: ^0.18.15
  audio_session: ^0.1.21
  wakelock_plus: ^1.2.8
```

同时删除 8 个未使用依赖（P1-15：`cupertino_icons`/`google_fonts`/`go_router`/`intl`/`dio`/`shared_preferences`/`path_provider`/`path`——其中 `shared_preferences`/`path_provider` 在阶段 2 会重新以正确版本引入；`go_router` 在阶段 5 重新引入）。

**核心改造（`app/lib/core/audio/audio_player_service.dart`）**：删除 `import 'dart:async'` 里的 ticker 用法与整个 `_startPositionTicker()`（`:304-329`），改为订阅 media_kit 的真实流。骨架：

```dart
class AudioPlayerService extends ChangeNotifier {
  final Player _player = Player();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlaybackState>? _stateSub;

  AudioPlayerService() {
    _player.stream.position.listen((p) {
      _position = p;
      _notifyPosition();           // 见 1.4：位置只通知叶子组件，不 notifyListeners 全树
    });
    _player.stream.playing.listen((v) { _isPlaying = v; notifyListeners(); });
    _player.stream.duration.listen((d) { _duration = d; notifyListeners(); });
    _player.stream.completed.listen((done) { if (done) _onTrackCompleted(); });
  }

  Future<void> playTrack(Track track) async {
    final media = Media(track.audioUrl ?? Uri.file(track.localPath!).toString());
    await _player.open(media, play: true);
    _currentTrack = track;
    _recordHistory(track);
    notifyListeners();
  }

  void play() => _player.play();
  void pause() => _player.pause();
  Future<void> seek(Duration t) => _player.seek(t);

  @override
  void dispose() {
    _posSub?.cancel(); _playSub?.cancel(); _durSub?.cancel(); _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
```

**必须同时解决的问题（否则接了 media_kit 也放不出声）**：
- `track_model.dart:67-68`：6 首 mock 曲目的 `audioUrl` 默认 `null`，`source` 为 `'lx-mock'`。阶段 1 必须给出**真实可播的音频**，二选一：(a) 把仓库中已存在但零引用的 `public/audio/track1-4.mp3`（33.6 MB）移到 `app/assets/audio/` 并在 `pubspec.yaml` 声明 `assets:`（当前 `:72-81` 全是注释），把它们绑定到 4 首演示曲目；(b) 明确「演示曲目不可播放」，UI 上置灰并标注。**推荐 (a)**，因为文件已在仓库里，且能让阶段 1 的验收真正听到声音。
- `audioUrl` 字段当前全仓无读取方（`fake-data.md` A18）——改造后它必须是**唯一的播放源输入**。
- `playTrack()`（`:142-154`）对不在队列的曲目执行 `_playlist.insert(0, track)`，会永久污染队列（P2-04）——改为 `replaceCurrent` 语义，试听不修改持久队列。

**验收标准（可测）**：
1. 启动应用，点击任意演示曲目的播放按钮，**扬声器有声音输出**；用 Windows 音量合成器/Android 音频焦点观察，能看到进程的音频会话在播放/暂停时切换状态。
2. `app/lib` 内 `Timer.periodic` 命中数 ≤ 1（仅保留睡眠定时器 `:275`）；`_startPositionTicker` 命中 0。
3. 进度条数值与真实音频时长一致：播放 10 秒后 `player.currentPosition` 与系统秒表差值 < 300ms；拖动进度条到 2:00 能真实跳转。
4. `select * from grep`：`app/lib` 内 `media_kit` 命中 ≥ 1，`pubspec.lock` 含 `media_kit`。

#### 1.2 P0-01（续）：系统媒体控制、音频焦点、后台播放

**动作**：
1. 新增 `app/lib/core/audio/mellow_audio_handler.dart`，继承 `BaseAudioHandler`，把 `PlaybackState`、`MediaItem`（标题/歌手/专辑/封面/duration）、`queue` 上报。在 `main.dart:11-20` 的 `runApp` 之前 `await AudioService.init(builder: () => MellowAudioHandler(), config: AudioServiceConfig(androidNotificationChannelId: 'com.mellow.music.channel.audio', androidNotificationChannelName: 'Mellow Music 播放', androidNotificationOngoing: true))`。
2. 新增 `audio_session` 配置：声明 `AudioSessionConfiguration.music()`，处理来电/其他应用抢占（`becomingNoisy` 时 pause）。
3. 配 `wakelock_plus`：播放中 enable，暂停/停止 disable（当前全仓 `wakelock` 命中 0，播放时设备会正常息屏）。
4. 平台声明：Android 侧在 `AndroidManifest.xml` 注册 `com.ryanheise.audioservice.AudioService` 与 `MediaButtonReceiver`（audio_service 文档标准做法）；iOS 在 `Info.plist` 加 `UIBackgroundModes: audio`。

**验收标准（可测）**：
1. Windows：播放时按下键盘媒体键（或系统 SMTC 面板），能显示曲目信息并控制播放/暂停。
2. Android：锁屏与通知栏出现播放控制与封面；切后台 5 分钟后音频仍在播放；拔耳机自动暂停。
3. 播放中不再熄屏（`wakelock_plus` 生效）。

#### 1.3 P1-09：EQ 接到真实滤镜，或降级标注「未实现」

**动作（二选一，建议先选 B，阶段 5 再看是否升级 A）**：
- **A（真接）**：media_kit 下用 `_player.setProperty('af', equalizerManager.toLibmpvFilterString())`，并修正 `equalizer_manager.dart:82-92` 的语法——当前生成的 `firequalizer=gain='gain_interpolate(31,7.0)+...'` 与 `docs/SPEC.md:193` 要求的 `firequalizer=gain='if(between(f,31,62),G1,...)'` 不一致，且 libmpv 的 `gain_interpolate` 表达式本身需要按下标成对写。改法：以 SPEC 语法为准重写，并加一条**真实**单测（用一个已知增益数组断言生成的字符串逐字符相等），同时把 EQ 变更接到 `_player.setProperty` 的调用点上（当前 `toLibmpvFilterString` 生产调用方为 0）。
- **B（降级）**：删除 EQ 弹窗中的全部技术名词（阶段 0 已做），在弹窗顶部加一行「当前版本均衡器调节不影响声音」，或直接把 `modals.dart` 的 EQ 弹窗入口从 UI 移除（`desktop_scaffold.dart` 的工具集按钮）。

同时修 P1-09 的溢出：`modals.dart` 中 EQ 预设行在 1440px 下第 5 个预设（Spatial 3D）被裁切（实测截图 `docs/evidence/pc-e2e/08-eq-modal-preset-clipped.png`）。改法：预设行改为 `Wrap`（或 `SingleChildScrollView(scrollDirection: Axis.horizontal)`），并把弹窗宽度从固定值改为 `min(900, screenWidth * 0.8)`。

**验收标准（可测）**：
1. 选 A：改 EQ 的某一频段增益后，用 `ffmpeg`/听感比对可观察到频响变化；单测断言生成的 filter 字符串与预期逐字符相等；`toLibmpvFilterString` 的生产调用方 ≥ 1。
2. 选 B：`app/lib` 内不再出现任何 EQ 相关的技术名词；EQ 入口或存在但明确标注不影响声音。
3. 在 1440×900 与 1280×720 两个尺寸下，EQ 弹窗内 **6 个预设全部可见**（截图比对，不再有裁切）。

#### 1.4 P1-16：进度只驱动叶子组件，消除 20Hz 全树 rebuild

**根因（已核实）**：`desktop_scaffold.dart:368` 的 `context.watch<AudioPlayerService>()` 位于整个工作台的 build 路径上，而 `audio_player_service.dart:327` 每 50ms 调一次 `notifyListeners()` → 20Hz 全树重建；叠加常驻 `BackdropFilter(blur 70)` 与 3 段 `MaskFilter.blur`。

**动作**：
1. 在 `AudioPlayerService` 中新增一个独立的细粒度通知源：

```dart
class AudioPlayerService extends ChangeNotifier {
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  // 位置流回调中只更新它，不调 notifyListeners()
  // 播放状态/切歌/队列等低频事件仍走 notifyListeners()
}
```

2. 进度条、时间文本、歌词高亮行改为 `ValueListenableBuilder<Duration>(valueListenable: player.positionNotifier, builder: ...)`；`desktop_scaffold.dart` 顶层把 `context.watch<AudioPlayerService>()` 换成 `context.read`（只在需要状态的地方 watch）。
3. 位置通知节流到 4Hz（250ms）即可满足歌词高亮；把 `ValueNotifier` 的写入放在节流器里。
4. `_buildCurrentView()`（`desktop_scaffold.dart:332-363`）的结果做缓存/复用，避免每次父级重建都新建视图。

**验收标准（可测）**：
1. 用 Flutter DevTools 的 Performance 面板录制 10 秒播放，**帧率稳定 ≥ 55fps**，且 `_DesktopScaffoldState.build` 在 10 秒内的调用次数 **≤ 5 次**（当前为约 200 次）。
2. 把 `BackdropFilter` 的 blur 值临时改为 0，帧率无显著变化（证明瓶颈已不在模糊层）。
3. 歌词高亮仍能跟随播放（肉眼观察不卡顿）。

#### 1.5 P2-04 / P2-12（播放侧）：状态机边界与可观测性

**动作**：
1. `next()`（`:156-171`）首行加 `if (_mode == PlaybackMode.singleLoop) { seek(Duration.zero); return; }`（当前单曲循环下按「下一首」仍会切歌，与 UI tooltip `desktop_scaffold.dart:481` 显示的「单曲循环」矛盾）。
2. 随机播放（`:158-160`、`:180-182`）改为记录已播索引的环形队列，避免「下一首还是这一首」。
3. `clearQueue()`（`:261-266`）内的 `pause()` 会二次 `notifyListeners()`（`:139`）→ 改为内部 `_setPausedWithoutNotify()`。
4. 引入 `AppLogger`（`dart:developer` 的 `log` 或 `logger` 包），把 `online_music_service.dart:80-82/157-159/182` 等 16 处 `catch (_)` 改为至少记录 + 上抛 `AppFailure`（详细见阶段 3.4）。

**验收标准（可测）**：单曲循环下按「下一首」进度归零且曲目不变；随机模式下连续 20 次 next() 无相邻重复；`clearQueue()` 后单帧内 `notifyListeners` 调用计数 = 1（用带计数的测试替身验证）。

**涉及文件**：`app/pubspec.yaml`、`app/lib/core/audio/audio_player_service.dart`、`app/lib/core/audio/equalizer_manager.dart`、`app/lib/core/audio/track_model.dart`、`app/lib/core/audio/mellow_audio_handler.dart`（新增）、`app/lib/main.dart`、`app/lib/navigation/desktop_scaffold.dart`、`app/lib/views/common/modals.dart`、`app/android/app/src/main/AndroidManifest.xml`、`app/ios/Runner/Info.plist`。
**工作量**：5~8 人日。
**风险**：
- media_kit 在 Windows 上需要 `media_kit_libs_windows_audio`，漏加会 `MissingPluginException`；首次接线建议先在 Windows 单平台跑通再铺开。
- `public/audio/*.mp3` 一旦移入 `app/assets/`，APK/exe 体积增加约 34 MB——演示包可接受，正式包应改为按需下载或换更小的示例音频。
- audio_service 的 Android 前台服务需要 `FOREGROUND_SERVICE_MEDIA_PLAYBACK`（阶段 0 已预埋），Android 14 上还要求 `android:foregroundServiceType="mediaPlayback"`。

---

### 阶段 2（持久化与数据层）— 4~6 人日

**目标**：用户数据（收藏/历史/歌单/主题/EQ/设置）重启不丢；把散落在 UI 的 37 处 `mockPresetTracks` 收敛到一个可替换的数据源。

#### 2.1 P0-02：shared_preferences 起步 → drift 承接曲库

**动作（分两步，不要一步到位）**：
1. **轻量设置用 shared_preferences**（当前 `pubspec.yaml:41` 已声明但 `app/lib` 命中 0）：为 `ThemeProvider`（`theme_provider.dart:6-8` 的 `_isDarkMode`/`_accentType`/`_glowIntensity`）、`EqualizerManager`（`equalizer_manager.dart:32-34`）加 `toJson`/`load`。骨架：

```dart
class ThemeProvider extends ChangeNotifier {
  static const _kDark = 'theme.dark';
  static const _kAccent = 'theme.accent';
  static const _kGlow = 'theme.glow';

  Future<void> load(SharedPreferences prefs) async {
    _isDarkMode = prefs.getBool(_kDark) ?? false;
    _accentType = AccentColorType.values[prefs.getInt(_kAccent) ?? 0];
    _glowIntensity = prefs.getDouble(_kGlow) ?? 0.65;
    _prefs = prefs;
    notifyListeners();
  }
  void setDarkMode(bool v) { _isDarkMode = v; _prefs?.setBool(_kDark, v); notifyListeners(); }
  // setAccentType / setGlowIntensity 同理
}
```

2. **曲库/收藏/历史/歌单用 drift**（SPEC 第 8 章声称 `core/database/` 与 5 张表，实际目录不存在、表名标识符全仓 0 匹配）。引入 `drift` + `drift_flutter` + `sqlite3_flutter_libs` + `drift_dev`（dev），按 SPEC 的 `SongsTable`/`PlaylistsTable`/`PlaylistSongsTable`/`HistoryTable`/`SourcesTable` 落地；FTS5 联想检索放到阶段 3（曲库真有大几千首时才有价值）。

3. `main.dart:9-21` 改为 `async` 初始化：`WidgetsFlutterBinding.ensureInitialized(); final prefs = await SharedPreferences.getInstance(); final db = AppDatabase(); await db.customSelect('SELECT 1').get(); runApp(...)`，并在 `MultiProvider` 的 `create` 中注入已初始化的实例（不要让每个 Notifier 自己去异步 load 后再 `notifyListeners`，会产生首帧闪烁）。

**验收标准（可测）**：
1. 切换深色模式 + 改强调色为第 4 个 + 光晕浓度改为 0.3 → **完全杀掉进程**重启 → 三项全部保持。
2. 收藏 2 首、播放 3 首、导入 1 个歌单 → 杀进程重启 → 收藏为 2（不再是硬编码的 4）、历史为 3、导入歌单仍在。
3. `app/lib` 内 `shared_preferences` 命中 ≥ 1，`drift` 命中 ≥ 1；`pubspec.lock` 含 `drift` 与 `sqlite3_flutter_libs`。

#### 2.2 P1-04 / P1-05：删除预置收藏与冷启动假历史

**动作**：
1. `audio_player_service.dart:21` `final Set<String> _favoriteIds = {'track-1','track-3','track-5','track-6'};` → `Set<String> _favoriteIds = {};`（改为可空/可变并由持久化层注入初始值）。
2. `audio_player_service.dart:76-80` 的构造函数 `_recordHistory(_playlist[0])` → 整个删除（用户零操作不应有历史）。
3. `track_model.dart:120/160/200/217` 的 4 处 `isFavorite: true` → 删除（常量级「已收藏」是假的，收藏状态只能来自持久化）。
4. `desktop_views.dart:1525-1526`「已同步红心收藏」的阶段 0 文案已在 0.2 改为「本地红心收藏」，此处确认其数字来源为真实 `_favoriteIds`。
5. 补 SPEC 3.1 声称但缺失的能力：单条历史移除 + 一键清空。在 `AudioPlayerService` 加 `removeHistoryItem(String id)` 与 `clearHistory()`，并在 `DesktopHistoryView`（`desktop_views.dart:1098-1141`）与移动端历史页加对应按钮（滑动删除 + 顶部「清空」）。

**验收标准（可测）**：
1. 首次安装启动，进入「我喜欢的音乐」页显示 **0 首**（当前显示 4 首）；进入「播放足迹」页显示 **空**（当前有 1 条「云水禅心」）。
2. 生成 APK/exe 后，在全新用户目录（换个 Windows 用户或清 `%APPDATA%`）启动，以上两条仍成立。
3. 历史页可删除单条、可一键清空，重启后状态保持。

#### 2.3 P1-20（数据层）：Repository 抽象，把 37 处 mockPresetTracks 收敛

**根因（已核实）**：UI 层直接引用 `mockPresetTracks` 共 37 处（`desktop_views.dart` 16 / `mobile_pages.dart` 10 / `modals.dart` 3 / `mobile_tabs.dart` 3 / `navigation` 3 / `mobile_sheets.dart` 1 / `fullscreen_lyrics_view.dart` 1），另有核心层 2 处、模型层 1 处（`fake-data.md` / `code-review.md` 第 20 节）。`mockPresetTracks` 是顶层可变 `final List<Track>`（`track_model.dart:111`），无 `const` 保护。

**动作**：
1. 新增 `app/lib/data/track_repository.dart`：

```dart
abstract class TrackRepository {
  Future<List<Track>> getDiscoverTracks();
  Future<List<Track>> getToplistTracks(String chartId);
  Future<List<Artist>> getArtists();
  Future<ArtistDetail?> getArtistDetail(String artistId);
  Future<List<Playlist>> getPlaylists({String? category});
  Future<List<PodcastEpisode>> getRadioEpisodes();
  Future<List<Track>> searchLocal(String query);
  Future<List<Track>> searchOnline(String query);           // 阶段 3
  Future<List<Track>> getLocalLibrary();                     // 阶段 2.4
}

class MockTrackRepository implements TrackRepository { /* 阶段 2 的唯一实现，数据搬到 lib/dev/mock_data.dart */ }
class DriftTrackRepository implements TrackRepository { /* 阶段 2.4/3 的真实现 */ }
```

2. 在 `main.dart` 用 `Provider<TrackRepository>` 注入（`MultiProvider` 加一项）。所有 UI 通过 `context.read<TrackRepository>()` 获取数据，**`views/` 与 `navigation/` 下禁止 import `mock_data.dart`**。
3. 用 lint 固化约束（`analysis_options.yaml` 当前只有 `include: package:flutter_lints/flutter.yaml`，未开 strict，`linter.rules` 段全是注释）：开启 `strict-casts`/`strict-raw-types`/`strict-inference`，并加自定义规则/CI 脚本断言 `views` 目录不出现 `mockPresetTracks`。
4. 拆分 `desktop_views.dart`（1828 行含 13 个视图）为 `views/desktop/discover_view.dart` 等独立文件；同一提交内把 `mockPresetTracks` 引用改为 Repository 调用。

**验收标准（可测）**：
1. `Get-ChildItem app/lib/views,app/lib/navigation -Recurse -Filter *.dart | Select-String 'mockPresetTracks'` **命中 0**。
2. 把 `MockTrackRepository` 换成返回空列表的 `EmptyTrackRepository`（测试替身），**App 不崩溃**且各页面显示空态（当前会因 `mockPresetTracks[0]` 等硬索引而崩溃——这是「数据源可替换」的最小证明）。
3. `flutter analyze --fatal-infos` 在开启 strict 后为 0 issue（需装工具链）。
4. `desktop_views.dart` 行数 < 300。

#### 2.4 P0-08（真实现）：本地扫描与拖拽导入

**动作**：
1. 引入 `file_picker`（当前 `pubspec` 无 `file_picker`/`file_selector`，`app/lib` 命中 0）与 `desktop_drop`（拖拽）。
2. `desktop_views.dart:1170-1175` 的 `onTap: () {}` 改为调用 `FilePicker.platform.getDirectoryPath()` → 递归扫描音频扩展名（`.mp3/.flac/.wav/.m4a/.ogg/.ape/.dsd/.dff`）→ 读 ID3/Vorbis 元数据（`audio_metadata_reader` 或 `metadata_god`）→ 写入 drift `SongsTable`。
3. `desktop_views.dart:1159-1178` 的 `RecessedWell` 用 `DropTarget` 包裹，`onDragDone` 接收文件路径并入库。
4. `desktop_views.dart:1182-1202` 的假列表改为读 `getLocalLibrary()`；`:1195` 的固定字符串「FLAC 24bit/96kHz · 42.8 MB」改为真实格式/码率/文件大小（读不到元数据时显示文件名与大小，**不要编造**）。
5. 空态：无本地曲目时显示「尚未导入本地音乐」并保留导入按钮。

**验收标准（可测）**：
1. 选一个含 3 个 mp3 + 1 个 flac 的文件夹 → 列表出现 **4 条**记录，每条显示的格式/大小与 `ffprobe`/`Get-Item` 的结果一致。
2. 从资源管理器拖 2 个音频文件到导入区 → 列表新增 2 条。
3. 点击某条本地曲目 → **真实播放该文件**（阶段 1 已具备播放能力）。
4. 重启应用后本地曲库仍在（阶段 2.1 的 drift）。
5. 扫描一个含 500 首的目录：导入完成后列表可滚动到底，不出现 OOM（与阶段 5 的列表虚拟化联动）。

#### 2.5 P1-06：设置中心补齐

**动作**：`DesktopSettingsView`（`desktop_views.dart:1209-1330`）当前只有 3 张卡片（外观/强调色/光晕浓度），补 SPEC 声称但缺失的项：
- 音质首选项（`LxSourceEngine.preferredQuality` 存在但引擎未接线；阶段 4 做决策后再决定是「可选」还是「移除」）。
- 离线缓存目录与占用、一键清理（阶段 2.4 导入后才有意义）。
- 本地曲库路径管理（可增删扫描目录）。
- 「关于」区块：从 `package_info_plus` 读版本号（阶段 6 建立单一来源）。

**验收标准（可测）**：设置页卡片数 ≥ 6；「清理缓存」点击后显示的占用字节数与磁盘实际占用一致（±1 MB）。

**涉及文件**：`app/pubspec.yaml`、`app/lib/main.dart`、`app/lib/design_system/theme_provider.dart`、`app/lib/core/audio/audio_player_service.dart`、`app/lib/core/audio/equalizer_manager.dart`、`app/lib/core/audio/track_model.dart`、`app/lib/data/*`（新增）、`app/lib/dev/mock_data.dart`（新增）、`app/lib/views/**`、`app/lib/navigation/**`、`app/analysis_options.yaml`。
**工作量**：4~6 人日。
**风险**：drift 的代码生成（`build_runner`）会增加构建复杂度；如果团队不接受，可先用 `sqflite` + 手写 DAO 过渡，但 WAL/FTS 能力会打折。`file_picker` 在 Linux 上依赖 zenity，需在 CI 与文档注明。


---

### 阶段 3（真实数据接入）— 5~10 人日

**目标**：让「发现/榜单/歌单/歌手/搜索/电台」显示的数据有真实来源，或诚实地显示为空。**前置条件**：阶段 2 的 `TrackRepository` 已就位——本阶段只给它增加真实现，不触碰 UI 结构。

#### 3.1 P1-01 四个排行榜曲目池完全相同

**根因（已核实）**：`desktop_views.dart:531` 用 `final trackIndex = (idx * 3 + i) % mockPresetTracks.length;` 从同一 6 首池子里取模；榜单文案（`:358/366/374/382`）「每日09:00更新 · 100首」是静态字符串，全仓无任何定时任务。
**动作**：① `TrackRepository.getToplistTracks(chartId)` 返回按 chartId 区分的真实数据；② 删除「每日 09:00 更新 · 100 首」硬编码，无数据源时显示「更新时间未知」，不得编造；③ 若阶段 3 无法接入真实榜单服务，整页改为「榜单数据源未配置」空态或移除导航项——**禁止**保留取模伪装的 4 个榜单。
**验收标准（可测）**：4 个榜单点进去的曲目列表在 trackId 集合上**互不相同**（单测断言）；文案中的数字要么来自返回体，要么不存在。

#### 3.2 P1-02 歌手数据编造

**动作**：① `desktop_views.dart:611-616` 的 4 位歌手常量（粉丝数 86.4万/3890.2万/1240.8万/512.6万）→ 由 `getArtists()` 提供，无数据源时不显示粉丝数；② `desktop_views.dart:704`、`mobile_pages.dart:527` 所有歌手共用同一张 `photo-1534528741775` 头像（该图同时充当用户头像，`mobile_tabs.dart:134/960`）→ 有真实头像才显示，否则显示姓名首字占位块；③ `desktop_views.dart:719`、`mobile_pages.dart:536` 固定副标题「官方认证音乐人 · 粉丝量 189.4万 · 单曲播放突破 1.2 亿」（对所有歌手一样且与列表页 86.4万 矛盾）→ 删除；④ `desktop_views.dart:751-776`、`mobile_pages.dart:554-571` 所有歌手详情页代表作都是同一份 `mockPresetTracks` → 改为 `getArtistDetail(id).tracks`，无数据则空态；⑤ `desktop_views.dart:676`、`mobile_pages.dart:499` 的 `bool _isFollowing = true;`（默认已关注）→ 默认 false 并走阶段 2 持久化；⑥ `desktop_views.dart:643-649` 无条件渲染的认证蓝勾 → 移除。
**验收标准（可测）**：详情页粉丝数与列表页一致（或都不显示）；3 位不同歌手的详情页曲目列表互不相同；首次安装关注按钮为「关注」态，重启后状态保持。

#### 3.3 P1-03 歌单广场卡片实为单曲、播放量编造

**动作**：① `desktop_views.dart:310-338` 网格改用 `getPlaylists(category)`，卡片点击进入**歌单详情**（含全部曲目），而非 `playTrack(mockPresetTracks[i])`；② `:273-274/303` 的分类标签当前只改高亮不过滤（`onTap: () => setState(() => _activeTag = tag)`）→ 真正过滤；③ 删除 `:144-172` 手写播放量（48.6万/129.4万/98.2万/34.1万），有真实 playCount 才显示；④ 封面去重：同一张 Unsplash 图复用 10 处 → 建封面映射表，缺图时用「trackId 哈希生成的低饱和渐变色块 + 首字」占位。
**验收标准（可测）**：任一点开的歌单能看到属于它的完整曲目列表；切换分类后卡片数量或内容变化；同一 Unsplash URL 出现次数 ≤ 2。

#### 3.4 P1-07 搜索面板与错误反馈

**动作**：① `modals.dart:510-533` 搜索初始结果即为本地 mock 列表 → 改为「输入关键词开始搜索」空态；② `modals.dart:567` 的「按 ESC 退出」hint 在阶段 5 落地前改为「点击关闭」；③ 新增 `app/lib/core/error/app_failure.dart`，把 `online_music_service.dart:80-82/157-159/182` 等 16 处 `catch (_)` 改为区分失败类型并在 UI 呈现（`modals.dart:639` 的「无匹配结果」要能区分「无结果」与「网络异常」）——`views/` 与 `navigation/` 下当前 catch 数为 0，UI 必须开始处理异常；④ 幂等 GET 加 1~2 次指数退避重试（当前全仓无 retry）；⑤ `main.dart:9` 的 main() 包 `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.instance.onError`（当前三者命中均为 0）。

```dart
// app/lib/core/error/app_failure.dart
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});
  final String message;
  final Object? cause;
}
class NetworkFailure extends AppFailure { const NetworkFailure([String m = '网络不可用，请检查连接']) : super(m); }
class TimeoutFailure extends AppFailure { const TimeoutFailure([String m = '请求超时，请重试']) : super(m); }
class ParseFailure   extends AppFailure { const ParseFailure([String m = '返回数据解析失败']) : super(m); }
class AuthFailure    extends AppFailure { const AuthFailure([String m = '鉴权失败，请检查账号配置']) : super(m); }
class NotConfiguredFailure extends AppFailure { const NotConfiguredFailure([String m = '该数据源尚未配置']) : super(m); }
```

⑥ 统一 `AppLogger`：`debugPrint` 全仓仅 1 处（`webdav_sync_service.dart:391`，且是死代码）→ 网络请求/播放事件/导入扫描各留结构化日志（阶段 6 接错误上报）。
**验收标准（可测）**：断网搜索显示「网络异常」而非「无匹配结果」；用 `MockClient`（`sync_services_test.dart:362` 已示范）注入 500/超时/畸形 JSON，UI 呈现三种不同提示；`app/lib` 内 `catch (_)` 命中 0，`runZonedGuarded` 命中 ≥ 1。

#### 3.5 P1-08 声音电台卡片点击播放无关 mock 歌曲

**动作**：`desktop_views.dart:792-797` 的 4 个节目是文案常量，`:818-821` 点击播放 `mockPresetTracks[idx % ...]` → 引入「单集」模型 `PodcastEpisode{ id, title, showName, duration, audioUrl, coverUrl, publishedAt }`，仓储返回真实单集；无数据源时整页空态或移除导航项。**不得**点击「深夜治愈故事馆」却播放《海阔天空》。
**验收标准（可测）**：点击任意电台单集，播放队列中的标题/时长与该卡片显示一致。

#### 3.6 P1-19 第三方私有接口与明文账号

**动作**：① 删除 `desktop_views.dart:1415` 的明文账号（阶段 0 已做）；`webdav_sync_service.dart:25` 的明文 `password` 字段改为从 `flutter_secure_storage` 读取（阶段 4 接线时落地）；② `online_music_service.dart:35/103/168` 的 `music.163.com/api/*` 私有接口 + 伪造 UA/Referer（`:37-40/104-107/170-173`）属规避技术措施与法务风险，且 Web 端因 CORS 必然失败（表现为「封面能显示但搜索恒为空」的迷惑状态）。替代方案按优先级：**首选**本地曲库作一等数据源、在线仅作增强；**次选**自建/自托管代理后端（第三方请求放服务端，客户端只调自己的 HTTPS 接口）；**再次**使用有明确授权的官方开放平台；**兜底**保留但明确标注「第三方非公开接口，随时可能失效」并允许用户自填数据源；③ 无论哪条，在线音源都必须做成**可插拔 Provider**（与阶段 4 的音源决策合并），禁止硬编码 URL 散落。
**验收标准（可测）**：`app/lib` 内无明文邮箱/密码字面量；Web 构建下搜索要么真实可用、要么给出「当前平台不支持在线搜索」明确提示；切换 Provider 实现无需修改任何 `views/` 文件。

#### 3.7 P2-10 / P2-09 / P2-05 / P2-07 一致性

- **P2-10**：`mellow_image.dart:5-72` 只有 `errorBuilder`、无 `loadingBuilder`、无磁盘缓存，且用 `static bool isInTest` + `runtimeType.toString().contains('Test')` 判断测试环境（脆弱、并行测试互相污染）→ 引入 `cached_network_image`（或自建 `ImageProvider` + `path_provider` 缓存），补 `loadingBuilder` 与 `cacheWidth`；删除 `isInTest`，改用 `HttpOverrides` 或注入替身。验收：首次加载显示进度态而非灰色音符；冷启动二次进入封面**不重新联网**（DevTools Network 面板 0 请求）。
- **P2-09**：移动端 9 个二级页缺 `MobilePlaylistDetailPage`（8/9）；5 个底部抽屉只有 2 个（`MobileEqBottomSheet`/`MobileSleepTimerBottomSheet`/`MobileVolumeModal` 三个类不存在，当前 EQ 与定时器复用桌面 `showDialog`）→ 补齐，或从 `docs/SPEC.md:144-157` 删除对应条目。**二选一，不允许文档写 9 个而代码只有 8 个。**
- **P2-05**：`design_tokens.css` 与 `app/lib/design_system/tokens.dart` 亮/暗 6 处色值不符、圆角刻度互不覆盖、阴影全不同、Dart 缺 `convex`/`pressed` 与内白高光 → 建立单一事实源（以 `design_tokens.css` 或新建 `tokens.json` 为源，脚本生成 `tokens.dart`），CI 加一致性校验。验收：校验脚本能检测出人工注入的一处色值差异。
- **P2-07 / P2-08**：Web 原型「播放」是 `OscillatorNode` 合成音（`index.html:1665-1836`、`mobile.html:1359-1523`），`public/audio/track1-4.mp3` 全仓零引用 → 要么接真实 `<audio>` + 这 4 个文件，要么移除「高保真/无损/Hi-Res」全部文案（阶段 0 已做部分）。双端数据抽成共享 `data.js`（`mobile.html` 有 210 行与 `index.html` 逐字重复，是「周杰伦粉丝数 1,290万 vs 3280万 同时通过测试」的根因）。

**涉及文件**：`app/lib/data/**`、`app/lib/core/sources/online_music_service.dart`、`app/lib/core/error/app_failure.dart`（新增）、`app/lib/design_system/mellow_image.dart`、`app/lib/views/**`、`app/lib/main.dart`、`design_tokens.css`、`app/lib/design_system/tokens.dart`、`index.html`、`mobile.html`、`data.js`（新增）。
**工作量**：5~10 人日（强依赖「是否已有可用数据源」这一前置决策；若走自建代理需额外 2~3 人日后端工作量）。
**风险**：**本阶段不确定性最高**。若 10 天内拿不到合法数据源，正确做法是**只做 3.4（错误反馈）+ 3.1~3.3 的空态化**，把真实数据接入整体延后，而不是继续编造数据。

---

### 阶段 4（功能决策：同步与音源）— 3~5 人日 或 0.5 人日（删除）

**目标**：给两个「重实现但零接线」的模块一个明确结论。**阶段 4 结束时必须二选一，不允许继续悬空。**

#### 4.1 多端同步（P0-03 + P0-04）

**A1 接线已有实现（3~4 人日）**：`main.dart:12-17` 的 `MultiProvider` 注册 `WebDavSyncService` 与 `LanSyncService`（当前只注册 3 个 provider，两个同步服务在 `app/lib` 内 import 数均为 0）；`desktop_views.dart:1409-1455` 的 `DesktopSyncView` 改为真实调用——配置弹窗（服务器地址/账号/应用密码/远端目录）→ `testConnection()`（真 `PROPFIND`，`webdav_sync_service.dart:194-245`）→ `uploadSnapshot()`/`downloadSnapshot()`/`sync()`（真 PUT/GET + LWW，`:265/300/334-405`，该算法已在 `sync_services_test.dart` 中被验证有效）；密码用 `flutter_secure_storage`（`WebDavConfig.password` 当前是明文字段，且以 `base64(user:pass)` 放 Authorization 头——base64 不是加密，`webdav_sync_service.dart:117-123`）；「服务就绪」绿标绑定真实连接状态；`startAutoSync`（`:375-394`，当前无调用方）接上开关。LAN 侧：启动 `LanSyncService.startServer()`；**修弱随机数**——`lan_sync_service.dart:256-266` 用 `DateTime.now().millisecondsSinceEpoch` 作 LCG 种子生成 6 位密钥（约 30 bit 熵、可预测）→ 改用 `Random.secure()` 生成 ≥128 bit 密钥；配对改为一次性令牌 + 用户比对短码；`/sync/push` 加请求体大小上限与速率限制；`HttpServer.bind` 与 CORS 收敛。
**A2 整页删除（0.5 人日）**：删除 `app/lib/core/sync/` 三个文件（401+509+573 = 1483 行不可达代码）、`DesktopSyncView`（`desktop_views.dart:1400-1833`）与导航项 `case 'sync'`（`desktop_scaffold.dart:358-359`）、`sync_services_test.dart`，以及 `desktop_toplist_and_sync_test.dart:106-123` 中把假同步当契约的用例。LWW 算法是资产，可先抽到独立文件保留，其余从 git 历史取回。
**验收标准（可测）**：A1——两台设备（或真 WebDAV 账号 + 一台设备）完成「上传 → 换设备恢复」，收藏/歌单/历史一致；断网显示真实错误而非「同步成功」。A2——`app/lib` 内 `WebDavSyncService`/`LanSyncService`/`jianguoyun` 命中 0，同步页面与入口不存在，`flutter test` 仍全绿。

#### 4.2 LX 音源引擎（P0-07）

**B1 真跑脚本（3~5 人日）**：引入 `flutter_js`（QuickJS），在 `main.dart` 注册 `LxSourceEngine`（`lx_script_sandbox.dart` 1204 行 + `lx_source_model.dart` 632 行在 `app/lib` 内 import 数 0，仅测试引用）；按 `docs/SPEC.md` 第 5 章实现 `globalThis.lx` 注入（`lx.request` / `lx.utils.buffer` / `lx.utils.crypto` 的 md5/aes/rsa；当前只有 `lx_script_sandbox.dart:601-604` 一个 Dart 侧 `md5Hash()`，无 AES/RSA）；`LxCustomScriptDriver`（`:555-724`）当前不解析 JS（`initialize()` 只做字符串包含检查 `:580-586`、`search()` 返回 1 首硬编码 mock `:616-636`、`getMusicUrl()` 返回假域名 `https://custom-cdn.<id>.com/stream/...` `:646`）必须替换为真实 JS 执行；**清理生产代码里的测试开关** `lx_script_sandbox.dart:354` 的 `final List<LxSongInfo> _mockDatabase;` 与 `:355` 的 `final bool simulateFailure;`；接线 `desktop_views.dart:1357` 导入按钮与 `:1391` 开关，并把 `resolveMusicUrlWithFallback`（`:1040-1119` 算法真实但无调用方）接上播放链路。
**B2 删除（0.5 人日）**：删除 `app/lib/core/sources/`（1836 行）、`DesktopSourceManagerView`（`desktop_views.dart:1331-1398`）与导航项（`desktop_scaffold.dart:356-357`）、`lx_source_engine_test.dart`（25 个用例，多条断言 mock 自身字符串）；从 `docs/SPEC.md` 第 5 章与 `ROADMAP.md` 移除或标注「未实现」。
**验收标准（可测）**：B1——导入真实 LX 脚本后搜索能返回该脚本定义的真实曲目并**可播放**；`app/lib` 内 `simulateFailure`/`_mockDatabase` 命中 0。B2——`app/lib` 内 `lx_` 命中 0，音源页面与入口不存在，删除后 `flutter analyze` 无未使用引用。

**涉及文件**：`app/lib/main.dart`、`app/lib/core/sync/**`、`app/lib/core/sources/**`、`app/lib/views/desktop/desktop_views.dart`、`app/lib/navigation/desktop_scaffold.dart`、`app/test/**`、`docs/SPEC.md`、`docs/ROADMAP.md`、`app/pubspec.yaml`。
**工作量**：3~5 人日（接线）或合计约 1 人日（两项都删除）。
**风险**：A1/B1 都会把「从未被生产验证过的 1483 / 1836 行代码」暴露到用户路径，缺陷率不可低估 → 建议放在功能开关后灰度。`flutter_js` 在 Windows 上的构建链较长，需提前验证。

---

### 阶段 5（桌面体验与性能）— 5~8 人日

**目标**：把「桌面端」从「一个会自适应成移动端的窗口」变成真正的桌面应用。

#### 5.1 P1-17 go_router + 路由栈 + PageStorageKey

**动作**：`app/pubspec.yaml:39` 已声明 `go_router` 但 `app/lib` 内 `GoRouter/GoRoute` 命中 0；导航是 `desktop_scaffold.dart:25` 的 `String _activeView` + `:332-363` 的 `switch`（移动端同理 `mobile_scaffold.dart:423-438`）→ 改为 `go_router` 的 `StatefulShellRoute`（`adaptive_scaffold.dart:12-21` 的单断点策略可原样保留，只把「当前页」从 String 换成路由状态）；修 `desktop_scaffold.dart:153` 的前进按钮 `onTap: () {}`（当前 `:145` 的后退永远跳 discover）→ 真实 `pop()` 与 forward；列表页加 `PageStorageKey`（切页丢滚动与内部 state 是实测问题，SPEC:115 也声称要它）。
**验收标准（可测）**：发现 → 榜单 → 歌手详情 → 按后退回到**榜单**（当前跳回 discover）；榜单页滚到中部 → 切设置 → 切回，滚动位置保持；前进按钮在可前进时可用、不可前进时禁用。

#### 5.2 P0-09 快捷键系统

**根因（已核实）**：`app/lib` 内 `LogicalKeyboardKey`/`Shortcuts`/`RawKeyboard` 命中 0，但 UI 写着「Ctrl K」（`desktop_scaffold.dart:186`）与「按 ESC 退出」（`modals.dart:567`）；实测 ESC 与 Ctrl+K 均无反应。
**动作**：在 `MaterialApp` 外层包 `Shortcuts` + `Actions`（声明式、可测）：

```dart
// app/lib/navigation/app_shortcuts.dart
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final player = context.read<AudioPlayerService>();
    final router = GoRouter.of(context);
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): _TogglePlayIntent(),
        SingleActivator(LogicalKeyboardKey.keyM): _ToggleMuteIntent(),
        SingleActivator(LogicalKeyboardKey.keyL): _ToggleLyricsIntent(),
        SingleActivator(LogicalKeyboardKey.keyQ): _ToggleQueueIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekBackIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _SeekForwardIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true): _SearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePlayIntent: CallbackAction<_TogglePlayIntent>(
            onInvoke: (_) { player.togglePlay(); return null; },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(onInvoke: (_) {
            showDialog(context: context, builder: (_) => const QuickSearchOverlay());
            return null;
          }),
          _DismissIntent: CallbackAction<_DismissIntent>(onInvoke: (_) {
            if (router.canPop()) router.pop();
            return null;
          }),
          // M / L / Q / ArrowLeft / ArrowRight 同理
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
```

注意：`Space` 与方向键在搜索框聚焦时应放行给 `TextField`（靠 `Focus` 层级自然实现，**不要**用全局 `RawKeyboardListener` 抢键）；macOS 上 Ctrl+K 与 Cmd+K 都要支持。
**验收标准（可测）**：Space 播放/暂停、M 静音、L 全屏歌词、Q 队列、ESC 关弹窗/退出歌词、左右键 seek ±5s、Ctrl+K（macOS ⌘K）开搜索；在搜索框内输入空格**不触发播放**（焦点隔离）；新增 `app/test/shortcuts_test.dart` 用 `tester.sendKeyEvent` 逐键断言状态变化。

#### 5.3 P1-10 窗口最小尺寸 | 5.4 P2-03 无边框窗口

- **P1-10**：窗口无最小尺寸约束（`app/windows/runner/win32_window.cpp` 无 `WM_GETMINMAXINFO`），`<1024px` 时由 `adaptive_scaffold.dart:12-21` 退化为移动壳填满窗口；实测 420×420 迷你播放胶囊遮挡内容、220×200 布局严重重叠（截图 `docs/evidence/pc-e2e/15-tiny-window-layout-broken.png`）。动作：引入 `window_manager`，`await windowManager.ensureInitialized();` 后 `waitUntilReadyToShow(WindowOptions(size: Size(1440, 900), minimumSize: Size(1024, 640), center: true))`；`app/windows/runner/main.cpp:29` 的 `Win32Window::Size size(1280, 720)` 改为 `(1440, 900)`（页面与测试都按 1440×900 设计，如 `desktop_toplist_and_sync_test.dart:35`）。验收：把窗口拖到最小停在 1024×640 且布局不破；1024×640 与 1440×900 下迷你胶囊不遮挡内容。
- **P2-03**：Flutter 侧已有 56px 自绘标题栏（`desktop_scaffold.dart:102-267`），但 Windows 仍是 stock `WS_OVERLAPPEDWINDOW`（`win32_window.cpp:137-138`）→ **双标题栏**且自绘栏不可拖动、无最小化/最大化/关闭。动作：`window_manager.setAsFrameless()` + `TitleBarStyle.hidden`，用 `DragToMoveArea` 包裹自绘标题栏并补三个窗口按钮（接 `windowManager.minimize()/maximize()/close()`）；Linux 侧同步处理 `app/linux/runner/my_application.cc:50` 的 GTK HeaderBar。验收：Windows 上只有一个标题栏，拖动空白区可移动窗口，三按钮功能正常。

#### 5.5 P2-01 列表虚拟化

**动作**：所有主视图用 `ListView(children: [...])`（`desktop_views.dart:23/281/389/618/683/1107/1154/1218/1339/1466` 等），内部网格用 `GridView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`（`:137-142/310-318/417-425/623-631`）→ 改为 `CustomScrollView` + `SliverList/SliverGrid`（去掉 `shrinkWrap`），至少改 `ListView.builder`。当前 6 条 mock 数据无感，接真实曲库（数千首）会立刻 OOM/卡死。
**验收标准（可测）**：导入 3000 首后滚动列表帧率 ≥ 50fps、内存不随滚动持续增长；DevTools 确认非可见区域 item 未被构建。

#### 5.6 P1-18 可访问性 | 5.7 P2-11 / P2-02 细节

- **P1-18**：`app/lib` 内 `Semantics`/`semanticLabel` 命中 0 → 为所有 `IconButton`/`GestureDetector` 加 `tooltip` 或 `Semantics(label:, button: true)`；裸 `GestureDetector`（播放按钮 `desktop_scaffold.dart:494-516`、静音开关 `:603-616`、5 个强调色圆点 `:225-240`、顶栏搜索条 `:162-193`）换成 `InkWell`/`IconButton` 以获得焦点与语义。验收：widget 测试断言 `meetsGuideline(labeledTapTargetGuideline)` 与 `textContrastGuideline`；Windows 讲述人能读出「播放/暂停/上一首/下一首/搜索」。
- **P2-11**：`desktop_views.dart:1071` 的 `tracks.take(5)` 使 200 首歌单只能看前 5 首（实测封面 URL 加载失败，截图 `13-real-import-worked-cover-missing.png`）→ 懒加载全量列表 + 封面兜底占位。验收：导入 200 首歌单能滚到第 200 首。
- **P2-02**：`LyricLine.translation`（`track_model.dart:5/10`）被解析但 UI 从不渲染（`fullscreen_lyrics_view.dart:260` 只用 `line.text`）→ 在歌词行 `Column` 中渲染 translation（次行、更小字号、`textSecondary`）；统一 EQ 预设数口径（SPEC:451 写「9 款」、枚举实际 6 个，`equalizer_manager.dart:4-14`）。验收：双语歌词显示两行；预设数与文档一致。

**涉及文件**：`app/lib/navigation/**`、`app/lib/navigation/app_shortcuts.dart`（新增）、`app/lib/main.dart`、`app/lib/views/**`、`app/pubspec.yaml`、`app/windows/runner/main.cpp`、`app/linux/runner/my_application.cc`、`docs/SPEC.md`。
**工作量**：5~8 人日。
**风险**：`go_router` 迁移会触及所有导航调用点（`onNavigate` 回调散布在 14 个视图构造参数里）→ 建议先加适配层（保留 `onNavigate` 签名，内部转 `context.go`）降低单次改动面。`window_manager` 无边框模式在 Windows 上需自行处理贴靠（Snap）与 DPI 缩放。

---

### 阶段 6（质量门禁）— 3~5 人日

**目标**：让 CI 的红/绿真正代表质量，而不是「截图脚本没抛异常」。

#### 6.1 P1-13 flutter_e2e_verify.mjs 重写为真断言

**根因（已核实）**：该脚本全文无 `assert`/`expect`；`:135-137`/`:143-145`/`:151-153`/`:159-161`/`:185-187` 均是无条件 `console.log('✅ [PASS] ...')`；`:121-126` 与 `:176-181` 用 `catch (_) {}` 吞掉 30s 等待失败；`:48-58` 在 `app/build/web` 不存在时返回 404 纯文本页，脚本照样截图并报「100% 通过」；`:141/149/157` 用硬编码坐标点击。
**动作**：① 启动前断言 `app/build/web/index.html` 存在，否则 `console.error` + `process.exit(1)` 并提示先执行 `flutter build web`；② 删除两处 `catch (_) {}`，捕获后计入 `failures`；③ 每次导航后断言 HTTP 200、`<title>` 非空、`flutter-view`/`flt-glass-pane` 存在、关键文案可见（用 `page.getByText` 或 Flutter 语义树 `flt-semantics` 定位，**替代坐标点击**）；④ 把 `desktopErrors`/`mobileErrors`（当前被收集后**从未断言**，`:114-115`/`:170-171`）纳入最终判定，并监听 `console` error、`requestfailed`、非 2xx `response`；⑤ 结束时不打印「恭喜通过」，而是打印「断言数 / 通过数 / 失败数」，任一失败即 `process.exit(1)`。

```js
// 骨架：替换 flutter_e2e_verify.mjs:104-205
const failures = [];
function assert(cond, name, detail = '') {
  if (cond) { console.log('  [ok] ' + name); return true; }
  failures.push(name + (detail ? ' :: ' + detail : ''));
  console.error('  [FAIL] ' + name + (detail ? ' :: ' + detail : ''));
  return false;
}
if (!fs.existsSync(path.join(WEB_DIR, 'index.html'))) {
  console.error('[Flutter E2E] app/build/web/index.html not found. Run: cd app && flutter build web --release');
  process.exit(1);
}
// ... 打开页面后：
assert(pageErrors.length === 0, 'desktop: 0 uncaught page errors', pageErrors.join(' | '));
assert((await page.title()).length > 0, 'desktop: non-empty title');
assert(await page.$('flutter-view, flt-glass-pane') !== null, 'desktop: flutter view mounted');
assert((await page.$$('flt-semantics')).length > 0, 'desktop: semantics tree present');
const ok = await clickBySemantics(page, '巅峰榜单');
assert(ok && (await page.getByText('飙升榜')) !== null, 'desktop: toplist view switched');
```

**验收标准（可测）**：① 不执行 `flutter build web` 就运行脚本 → 退出码 1；② 把 `app/build/web/index.html` 内容替换为 `Not Found` → 退出码 1；③ 把侧边栏某一项文案改掉 → 对应断言变红；④ 正常构建下退出码 0 且打印断言计数。

#### 6.2 P1-13 / P1-16 CI：固定 Flutter 版本、纳入 83 项 E2E、analyze 显式严格

**动作**：① `.github/workflows/ci.yml:20` 与 `release.yml:26/65/108/152/186` 的 `channel: 'stable'` 全部改为 `flutter-version: 3.47.x`（与 `app/pubspec.lock:622` 的 `flutter: ">=3.47.0"` 对齐），并加 `.fvmrc`/`.tool-versions` 同步——当前用漂移的 stable 去匹配一个硬下限，在 3.47 发布前 `flutter pub get` 会直接失败；② `ci.yml:29` 的 `flutter analyze` 改为 `flutter analyze --fatal-infos`（步骤名已叫「0 Issues Gate」，命令却未显式开启 info 级失败）；③ `ci.yml:33` 的 `flutter test` 后补一步 `flutter test integration_test`（当前 `app/integration_test/app_client_e2e_test.dart` 默认不被 `flutter test` 执行，8 个用例从未在 CI 中跑过）；④ `ci.yml:47-48` 之后新增「起服务 + 跑原型 E2E」：`npm ci || npm install` → 后台 `node server.cjs` → 健康检查轮询 → `node e2e_test.js` → 退出码作为门禁（当前 83 项套件**从不**在 CI 运行，README:5 的 83/83 badge 无门禁保护）；⑤ `release.yml` 的 `build-android`（`:136-171`）与 `build-web`（`:176-205`）当前**未跑** `flutter test`（其余 3 个 job 跑了）→ 补齐，门禁一致。
**验收标准（可测）**：① 把 flutter-version 改成 `3.46.0` 能观察到 `pub get` 失败（证明版本锚点生效）；② 人为让 `e2e_test.js` 的一个断言失败 → workflow 变红；③ CI 日志中能看到 77 + 8 个 Dart 用例与 83 个原型断言都被执行。

#### 6.3 P1-14 清理假测试与重复文件

**动作**：① 删除重复文件：`app/test/client_e2e_user_journey_test.dart` 与 `app/integration_test/app_client_e2e_test.dart` **逐字节完全相同**（本轮实测均 279 行、MD5 均为 `9C6CE41ED0`）→ 保留 `integration_test` 那一份（真正的设备级 E2E），删除 `test/` 下的副本；② 删除所有条件断言，如 `desktop_modals_and_lyrics_test.dart:53-58` 的 `if (bassPreset.evaluate().isNotEmpty) {...}`（找不到就整段跳过、测试仍绿）→ 改为先断言存在再操作；③ 删除断言 mock 自身的用例：`lx_source_engine_test.dart:169-176`（断言 mock 拼接出的 URL 含「128k」）、`:257`（域名由 mock 自己生成）、`client_e2e_user_journey_test.dart:260-261`（断言构造函数默认值与刚传入的值）→ 改为对注入的 fake `http.Client` 的**请求与响应**做断言（`sync_services_test.dart` 用 `MockClient` 的做法应推广到 `OnlineMusicService`）；④ 删除把假功能写成契约的用例：`desktop_toplist_and_sync_test.dart:106-123`（断言假同步的 900ms 延迟 + 假 SnackBar + 假设备名）；⑤ 修正命名误导：`client_e2e_user_journey_test.dart:113-190/264-283` 的 E2E-03/04/06/08 是纯 ChangeNotifier 单元断言，却用 `testWidgets` 且命名为「客户端原生端到端真实用户全链路」→ 改名或降级为 `test()`；⑥ 更新 `docs/PROGRESS.md` 的测试数字为真实值（`test(` 44 + `testWidgets(` 33 = 77，其中 8 个在 `integration_test/`），并声明 CI 实际执行范围。
**验收标准（可测）**：① 仓库内不存在内容相同的两个测试文件（对全部测试文件做 MD5 去重后数量不变）；② `app/test` 与 `app/integration_test` 内 `if (find` 命中 0；③ 逐个删除/注释被测生产代码，**每个用例都必须变红**（可抽样 20% 做变异测试验证）。

#### 6.4 P1-15 依赖清理与字体

**动作**：`app/pubspec.yaml:30-46` 的 11 个依赖中 8 个未使用（`cupertino_icons`/`google_fonts`/`go_router`/`intl`/`shared_preferences`/`dio`/`path_provider`/`path`；`crypto` 仅死代码用）→ 按阶段 1/2/5 的实际需要重新引入并删除其余；`main.dart:42` 与 `:52` 声明 `fontFamily: 'PingFang SC'` 但 `pubspec.yaml:65-101` 的 flutter 段**完全没有 fonts 配置**（Windows/Linux/Web 上不存在该字体，静默回退）→ 改为随包分发的 `NotoSansSC`（放 `assets/fonts/` 并在 pubspec 声明 `fonts:`），或改用 `google_fonts` 的 `GoogleFonts.notoSansSc()` 并预下载。
**验收标准（可测）**：`pubspec.yaml` 的 dependencies 每一项都能在 `app/lib` 里找到 import；Windows 构建产物中文字体与设计稿一致（截图比对）。

#### 6.5 P1-20 / P2-12 版本单一来源、日志与错误上报、工程卫生

**动作**：① 引入 `package_info_plus`，UI 上所有版本号（`desktop_views.dart:1383` 的 v2.1.0、`:1766` 的 Mellow v2.1.0 等）改为运行时读取；`docs/SPEC.md:3`/`PROGRESS.md:3` 与 `pubspec.yaml:19` 对齐；② 接 Sentry/Crashlytics（或自建上报端点），把阶段 3.4 的 `AppLogger` 与 `runZonedGuarded` 串起来，满足 `docs/SPEC.md:415-435` 的「未捕获异常必须为 0」红线；③ `app/analysis_options.yaml:12-20` 当前把 `android/ios/windows/macos/web/linux` 全部 exclude（平台代码零静态检查），且 `:33-35` 的 rules 全是注释 → 开启 `strict-casts`/`strict-raw-types`/`strict-inference`，逐步收窄 exclude。
**验收标准（可测）**：改 `pubspec.yaml:19` 的版本号后设置页「关于」同步变化（唯一来源）；人为抛未捕获异常能在上报后台看到；`flutter analyze --fatal-infos` 为 0 issue。

**涉及文件**：`flutter_e2e_verify.mjs`、`.github/workflows/ci.yml`、`.github/workflows/release.yml`、`app/test/**`、`app/integration_test/**`、`app/pubspec.yaml`、`app/analysis_options.yaml`、`app/lib/main.dart`、`app/lib/views/**`、`docs/PROGRESS.md`。
**工作量**：3~5 人日。
**风险**：变异测试（6.3 验收③）会暴露大量「假绿」用例，工作量可能超预期——建议按模块分批。

---

### 阶段 7（平台与发布）— 3~5 人日

**目标**：让产物在系统各处显示为「Mellow Music · 润音」，且发版链路可复现。

#### 7.1 P1-11 品牌化（六端产物名/标题/图标/版本信息）

**动作**（逐处已核实）：

| 位置 | 当前值 | 目标值 |
| :--- | :--- | :--- |
| `app/windows/CMakeLists.txt:3` | `project(app LANGUAGES CXX)` | `project(mellow_music LANGUAGES CXX)` |
| `app/windows/CMakeLists.txt:7` | `set(BINARY_NAME "app")` | `set(BINARY_NAME "mellow_music")`（Windows 文件名避免空格） |
| `app/windows/runner/main.cpp:30` | `window.Create(L"app", ...)` | `window.Create(L"Mellow Music", ...)` |
| `app/windows/runner/Runner.rc:93/95/97/98` | FileDescription/InternalName/OriginalFilename/ProductName = app | `Mellow Music` / `mellow_music` / `mellow_music.exe` / `Mellow Music · 润音` |
| `app/windows/runner/Runner.rc:92` | `CompanyName = com.mellow.music` | 可读品牌名 |
| `app/windows/runner/Runner.rc:96` | `Copyright (C) 2026` | 当前年份（2026 为未来年份） |
| `app/macos/Runner/Configs/AppInfo.xcconfig:8` | `PRODUCT_NAME = app` | `Mellow Music` |
| `app/macos/Runner/Configs/AppInfo.xcconfig:14` | `Copyright © 2026` | 当前年份 |
| `app/android/app/src/main/AndroidManifest.xml:3` | `android:label="app"` | `android:label="Mellow Music"` |
| `app/ios/Runner/Info.plist` | `CFBundleDisplayName = App` / `CFBundleName = app` | `Mellow Music` |
| `app/linux/runner/my_application.cc:52` | `gtk_window_set_title(window, "mellow_music")` | `Mellow Music` |
| `app/web/manifest.json` | `name/short_name = mellow_music`、`description = A new Flutter project.`、`background_color/theme_color = #0175C2` | 品牌名 + 与 `tokens.dart` 一致的 `#F5F7FB`/`#3B82F6` |
| `app/web/index.html:21/26/32` | `A new Flutter project.` / `mellow_music` | 品牌名与描述 |
| 各平台图标 | Flutter 默认蓝图标（android `ic_launcher.png` 实测 442~1443 字节，明显为模板资产） | 品牌图标（各分辨率齐备） |

**验收标准（可测）**：① 双击 Windows 产物，任务栏与窗口标题显示 `Mellow Music`，属性面板显示 `mellow_music.exe`；② 安装 APK 后桌面图标名为 `Mellow Music`；③ 属性/字符串中不再出现裸 `app`；④ 六端图标均非 Flutter 默认蓝；⑤ 版权年份为当前年份。

#### 7.2 P1-12 macOS 打包、7.3 P1-20 鸿蒙、7.4 iOS 缺口

- **P1-12**：见阶段 0.4（阶段 0 先改对名字，阶段 7 改为动态查找 + 真 Universal 或改名）。验收：推测试 tag 后 6 个 job 全绿，Release 页 5 个附件齐全。
- **P1-20 鸿蒙**：`app/harmonyos/` 下**只有一个 `README.md`**（本轮实测），README 中「文档所列配置文件全不存在」→ 二选一：① 用 `flutter create --platforms ohos`（或 DevEco Studio）补齐真实工程并在 `release.yml` 加 `build-hap` job；② 从 `docs/SPEC.md:5`、`docs/ROADMAP.md:160`、`README.md` 中移除 HarmonyOS 支持声称，并在 `app/harmonyos/README.md` 顶部标注「规划中，无工程文件」。**不允许保留现状。**
- **7.4 iOS 缺口**：`release.yml` 无 iOS job，而 `README.md:145` 声称平台覆盖含 iOS → 要么加 `build-ios` job（需 macOS runner + 证书，成本较高），要么在文档中把 iOS 标为「已适配脚手架、未纳入发版」。

**涉及文件**：`app/windows/**`、`app/macos/Runner/Configs/AppInfo.xcconfig`、`app/android/app/src/main/AndroidManifest.xml`、`app/ios/Runner/Info.plist`、`app/linux/runner/my_application.cc`、`app/web/manifest.json`、`app/web/index.html`、`app/harmonyos/**`、`.github/workflows/release.yml`、`docs/SPEC.md`、`docs/ROADMAP.md`、各平台图标资源目录。
**工作量**：3~5 人日。
**风险**：改 `BINARY_NAME` 会同时改变产物路径，`release.yml:44` 的 `app/build/windows/x64/runner/Release/*` 与仓库中既有的 `release_windows/app.exe` 都需同步（建议 release.yml 也改为动态查找）。图标建议用 `flutter_launcher_icons` 统一生成。

---

## 4. 发布前检查清单（Checklist）

> 用法：每个候选发布版本复制一份，逐项勾选并附证据（命令输出/截图路径）。任何一项未勾选 = 不发版。

### A. 功能真实性
- [ ] 点击播放**能听到声音**，且与系统音量合成器/媒体控制面板状态一致（P0-01）
- [ ] 进度条来自真实播放位置：播放 30 秒后与秒表误差 < 300ms；seek 有效（P0-01）
- [ ] 系统媒体控制（SMTC / MediaSession / 锁屏）显示正确曲目并可控制（P0-01）
- [ ] 后台播放、音频焦点、耳机拔出暂停、播放中不熄屏均生效（P0-01/P2-12）
- [ ] 收藏/历史/歌单/主题/EQ **杀进程重启后保持**（P0-02）
- [ ] 首次安装时收藏为 0 首、历史为空（P1-04/P1-05）
- [ ] 本地文件夹扫描与拖拽导入可用，导入数量与磁盘实际文件数一致（P0-08）
- [ ] 键盘快捷键（Space/M/L/Q/ESC/Ctrl+K/方向键）逐个实测有效（P0-09）
- [ ] 窗口存在最小尺寸约束；拖到最小布局不破（P1-10）
- [ ] 桌面端只有一个标题栏且可拖动（P2-03）

### B. 数据真实性
- [ ] 全仓检索 `libmpv`/`firequalizer`/`QuickJS`/`24bit/192kHz`/`已缓存 N 首`/`服务就绪`/`已同步` 等技术名词命中 0，或对应实现确实存在（P0-10）
- [ ] 4 个排行榜返回的曲目集合互不相同（P1-01）
- [ ] 同一歌手在不同页面的粉丝数一致，或不显示（P1-02）
- [ ] 同一张图片不再充当多个互不相关的实体（封面/头像去重）（P1-03/P2-10）
- [ ] 无任何 `onTap: () {}` / `onChanged: (_) {}` 空实现按钮（P0-07/P0-08）
- [ ] 无任何 `Future.delayed` 伪造的成功提示（P0-03）

### C. 安全
- [ ] `server.cjs` 六条 DoS payload 后进程存活；穿越读文件返回 403；监听 127.0.0.1（P0-12）
- [ ] 源码与 UI 中无明文账号/密码；凭据走 `flutter_secure_storage`（P1-19）
- [ ] LAN 配对密钥来自 `Random.secure()` 且 ≥128 bit（P1-19）
- [ ] `.gitignore` 已包含 `public/audio/`、`.qa/`、`release_windows/`，仓库不含大体积二进制与审计中间产物（P2-06）
- [ ] Android release APK 含 INTERNET 权限；macOS release 含 network.client（P0-05/P0-06）

### D. 构建与发布
- [ ] CI 全部 job 绿，且 Flutter 版本已固定（P1-13）
- [ ] `flutter analyze --fatal-infos` 为 0 issue（含开启 strict 后的结果）（P1-20）
- [ ] `flutter test` + `flutter test integration_test` 全绿，且用例数与 PROGRESS 文档一致（P1-14）
- [ ] `node e2e_test.js`（83 项）在 CI 中执行且为门禁（P1-13）
- [ ] 六个 job（含 `publish-release`）全绿，Release 页 5 个附件齐全（P1-12）
- [ ] 产物名/图标/版本信息已品牌化，六端显示一致（P1-11）

### E. 文档一致性
- [ ] `docs/PROGRESS.md` 的完成度、测试数字与代码事实一致（P1-14/P1-20）
- [ ] `docs/SPEC.md` 中每条「已实现」的技术栈，在 `pubspec.lock` 或 `app/lib` 中能找到（P1-20）
- [ ] `README.md` 引用的每张截图都存在（P2-06）
- [ ] README 的快速启动命令在干净环境可复现（P2-06）
- [ ] 版本号只有一个来源；SPEC/PROGRESS/UI/pubspec 四处一致（P1-20）
- [ ] HarmonyOS/iOS/Linux 等平台声称与 `.github/workflows/` 的实际 job 一致（P1-20）

---

## 5. 不建议做的事 / 避免过度工程

1. **不要把 6 首 mock 曲目扩到 30 首或 200 首。** 数据是假的，扩充只会掩盖问题、放大误导（当前 `desktop_views.dart:79` 声称「精选 30 首」而实际 6 首）。先接真数据源，数量自然增长。
2. **不要在阶段 1 之前做任何 EQ / 歌词动效 / 光晕取色的「优化」。** 没有音频时这些参数调优收益为零（`equalizer_manager.dart:82-92` 生成的 filter 字符串没有消费者）。
3. **不要为「9 款 EQ 预设」「SPEC 里的 34 个路由」这类文档-代码口径差去补代码。** 正确方向是改文档（6 款就写 6 款），除非产品明确需要。
4. **不要引入 BLoC / Riverpod 重写状态管理。** 当前只有 3 个 ChangeNotifier + provider，规模远未到需要重写的程度（`code-review.md` 附录 A 显示 `Bloc/Cubit` 命中 0）。阶段 2 的 Repository 抽象已足够。
5. **不要现在就上 desktop_multi_window 的透明穿透歌词窗口。** SPEC 有方案（SPEC:262-269）但依赖 Win32 `WS_EX_TRANSPARENT`/`WS_EX_LAYERED`，收益低、跨平台成本高。全屏歌词页（`fullscreen_lyrics_view.dart`）已足够。
6. **不要给 6 首 demo 写 FTS5 全文检索。** SPEC 第 7 章的毫秒级联想检索在曲库数千首、且已有真实本地曲库（阶段 2.4）之后才有意义。
7. **不要把 CI 的「0 issues」做成靠 `` ignore` 注释堆出来的绿。** `analysis_options.yaml:12-20` 已把 6 个平台目录整体 exclude；反向操作（加更多 ignore）会让门禁彻底失效。
8. **不要为了「跨端一致性」去重写 Web 原型层（`index.html`/`mobile.html`，各约 150 KB）。** 原型的定位是设计交付物；阶段 0 把文案降级、阶段 6 把它接入 CI 即可，不必按生产代码标准重构。
9. **不要在数据源未定的情况下先写「网易云 / QQ / 酷狗」多平台适配。** 当前只有网易云一个未鉴权旧接口能跑通（`fake-data.md` §4-1/4-2），多平台适配是典型的「先写一堆分支再发现全不可用」。
10. **不要为「已经写好但没人调用」的 3319 行代码无条件保命。** 死代码不是资产而是负债（无生产验证 = 缺陷率未知）。阶段 4 的二选一里，删除是合法且常常更优的选项。

---

## 6. 最小可用 MVP 定义（只做 10 天）

**目标产物**：一个「诚实的、可用的**本地**音乐播放器」——用户可以导入自己的音乐并正常播放，该有的状态记得住，不会看到任何假承诺。

**10 天安排（1 名熟练 Flutter 工程师，含 1 天缓冲）**：

| 天 | 内容 | 对应任务 |
| :--- | :--- | :--- |
| D1 | 阶段 0 全部（删假声明/假按钮/假状态栏；server.cjs 安全与崩溃修复；Android/macOS 权限；release.yml 产物名；README 修正） | 阶段 0 |
| D2~D5 | 接入 media_kit + audio_service；删除 50ms ticker；把仓库里已有的 `public/audio/track1-4.mp3` 移入 assets 作为演示曲目；真实进度/seek；系统媒体控制；wakelock | 阶段 1.1/1.2/1.4 |
| D6 | `file_picker` + 目录扫描 + 拖拽导入；本地曲库列表（真实格式/大小） | 阶段 2.4 |
| D7~D8 | shared_preferences 持久化（主题/强调色/光晕/EQ/播放模式/音量）+ 收藏与历史的真实增删（含单条移除/一键清空）+ 删除预置收藏与冷启动假历史 | 阶段 2.1/2.2 |
| D9 | Repository 抽象与 37 处 `mockPresetTracks` 收敛；本地曲库作为一等数据源；在线搜索接真实 Provider 或**移除在线入口**；错误提示（网络/超时/无结果可区分） | 阶段 2.3/3.4/3.6 |
| D10 | CI 真断言 + 测试清理 + 版本单一来源；缓冲 | 阶段 6.1/6.3/6.5 |

**MVP 明确不包含**（并据此改文档）：云端同步与 LAN P2P（整页删除或标注未实现）、LX 音源脚本引擎（删除核心目录与入口）、在线榜单/歌手/歌单的真实数据（改为空态）、go_router 路由栈与快捷键（第二阶段）、Windows 无边框窗口与托盘、鸿蒙与 iOS 发版。

**MVP 的验收定义**（可测）：① 导入一个含 10 个音频文件的文件夹，列表显示 10 条且格式/大小正确；② 点第 3 首能播放并听到声音，暂停/继续/切歌/seek 均正常；③ 锁屏或系统媒体面板显示当前曲目；④ 红心 2 首、播放 3 首后杀进程重启，收藏仍是 2 首、历史仍是 3 首；⑤ 首次安装时为 0 收藏 0 历史；⑥ 全仓检索无 `libmpv`/`QuickJS`/`无损`/`已同步`/`服务就绪` 等未落地名词；⑦ 断网时搜索给出明确的网络错误提示；⑧ CI 绿灯且其中至少包含一条「改坏生产代码就会红」的断言。

---

## 7. 工作量汇总表

| 阶段 | 内容摘要 | 人日 | 优先级 | 可并行性 | 前置依赖 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 阶段 0 | 止血：删假声明/假按钮/假状态栏、server.cjs 安全与崩溃修复、Android+macOS 权限、release.yml 产物名、README 修正 | 1~2 | **P0（立即）** | 与后续全部并行 | 无 |
| 阶段 1 | 播放底座：media_kit + audio_service、真实进度流、系统媒体控制、EQ 接线或降级、细分通知消除 20Hz 全树重建 | 5~8 | **P0（最高）** | 与阶段 2 部分并行 | 阶段 0 完成 |
| 阶段 2 | 持久化与数据层：shared_preferences → drift、Repository 抽象、删除预置收藏/假历史、本地导入真实现、设置补齐 | 4~6 | **P0** | 与阶段 1 部分并行 | 阶段 1 |
| 阶段 3 | 真实数据接入：榜单/歌手/歌单/电台/搜索 + 错误与降级策略 + 封面兜底缓存 + 第三方接口治理 | 5~10 | P1 | 与阶段 5 并行 | 阶段 2 的 Repository |
| 阶段 4 | 功能决策：同步接线或删除（3~4 / 0.5）；LX 音源真跑或删除（3~5 / 0.5） | 3~5 **或 1** | P1 | 独立 | 阶段 1（同步需能同步真实数据） |
| 阶段 5 | 桌面体验与性能：go_router + PageStorageKey、快捷键、窗口最小尺寸与无边框、列表虚拟化、可访问性、导入全量展示 | 5~8 | P1 | 与阶段 3 并行 | 阶段 1/2 |
| 阶段 6 | 质量门禁：E2E 真断言、清理假测试、固定 Flutter 版本、83 项原型 E2E 入 CI、依赖清理、错误上报、版本单一来源 | 3~5 | P1 | 可全程并行推进 | 与各阶段同步 |
| 阶段 7 | 平台与发布：品牌化、macOS 打包修正、鸿蒙补齐或移除、iOS 决策、发布清单 | 3~5 | P2 | 独立 | 阶段 0 的 0.4 |
| **合计（路线 B 全量）** | — | **29~49** | — | — | — |
| **合计（路线 A 仅止损）** | 阶段 0 + 阶段 4 删除 + 阶段 6/7 的文档与发布修正 | **3~4** | — | — | — |
| **合计（第 6 章 10 天 MVP）** | 阶段 0 + 1（核心）+ 2（核心）+ 3（错误反馈）+ 6（核心） | **10** | — | — | — |

**建议排期**：1 名工程师先做阶段 0（1~2 天，单独一个 PR），然后按「阶段 1 → 阶段 2 → 阶段 6.1/6.3」的纵向切片推进 MVP（10 天）；MVP 交付后再由 2 人分别推进阶段 3（数据）与阶段 5（体验）。阶段 4 的决策放在 MVP 复盘会上定（届时才知道是否真的需要跨端同步）。

**三个最高优先级动作**（若只能做三件事）：
1. **修 server.js 的 DoS + 目录穿越（P0-12）** —— 半天，消除真实的未认证远程漏洞。
2. **删掉所有假成功与假能力文案（P0-03/04/07/08/10/11 的 UI 侧）** —— 半天，消除对用户的欺骗。
3. **接入 media_kit 让播放真的出声（P0-01）** —— 3~4 天，这是「音乐播放器」之所以成立的前提。

---

## 附录 A：本轮核对说明与口径

1. **行号来源**：本文所有 `file:line` 均来自本轮逐行读取当前工作区快照。与 `docs/audit/*.md` 标注存在的 ±1 行差异（审计报告已说明其口径为逐行读取），本文以自身读取结果为准。
2. **问题清单不在本文重复**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md` **在本仓库不存在**（本轮已确认），问题编号体系直接沿用验收方给定的 P0-01~P2-12。问题的事实描述见 `docs/audit/` 四份报告，本文只回答「怎么修」。
3. **本轮实测确认的关键数字**（可作为验收基线）：
   - Dart 测试用例：`app/test` 8 文件 + `app/integration_test` 1 文件 = **77** 个（`test(` 44 + `testWidgets(` 33）；（`docs/PROGRESS.md:5` 声称 47）。
   - `app/test/client_e2e_user_journey_test.dart` 与 `app/integration_test/app_client_e2e_test.dart` **完全相同**：均 279 行，MD5 均为 `9C6CE41ED0`。
   - `app/pubspec.lock:622` 解析出 `flutter: ">=3.47.0"`，而全部 workflow 用 `channel: 'stable'` 且未固定版本。
   - `app/android/app/src/main/AndroidManifest.xml` 共 45 行，**无任何 uses-permission**。
   - `app/macos/Runner/Release.entitlements` 共 8 行，**仅 app-sandbox**。
   - `app/harmonyos/` 下**仅 README.md 一个文件**。
   - `app/windows/CMakeLists.txt:3` `project(app)`、`:7` `BINARY_NAME "app"`、`main.cpp:30` `Create(L"app", ...)`；`release_windows/app.exe` 实测存在（90624 字节）——证实产物名确为 app。
   - `app/web/manifest.json` 仍为模板：`name/short_name = mellow_music`、`description = "A new Flutter project."`、`background_color/theme_color = #0175C2`。
   - `app/pubspec.yaml` 的 flutter 段**无 fonts 配置**（第 65-101 行全为注释），而 `main.dart:42/52` 声明 `fontFamily: 'PingFang SC'`。
   - `public/audio/` 下 4 个 mp3 合计约 33.6 MB；`.gitignore` 未包含 `public/audio/` 与 `.qa/`。
4. **未验证项（不装作已验证）**：本机无 Flutter/Dart 工具链，凡涉及 `flutter analyze`/`flutter test`/`flutter build`/`flutter pub get` 的结果均标注为「需在装好工具链的机器上执行」。
5. **本文的可执行性要求**：每个任务的验收标准都应能写成一条命令、一条测试断言或一段固定操作流程。若实施时发现某条验收标准无法自动化，应在实施 PR 中补充人工验证截图，而不是降低标准。

---

*本修复建议书基于当前工作区快照与四份审计报告编写；所有代码位置均已逐行复核。建议按阶段 0 → MVP 的顺序推进，不接受「先做界面优化、后补播放底座」的排期。*
