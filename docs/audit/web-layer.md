# Web 原型层与测试/服务端基础设施审计报告

- **审计对象**：`index.html`、`mobile.html`、`design_tokens.css`、`server.js`、`e2e_test.js`、`flutter_e2e_verify.mjs`、`public/`、`.github/workflows/`
- **仓库**：`E:\code\AI\vibCoding\mellow-music-player`
- **审计时间**：2026-09-22
- **审计环境**：Windows / Node.js v24.14.1 / puppeteer-core 25.11.0 / Chrome `C:\Program Files\Google\Chrome\Application\chrome.exe`（存在）
- **审计方法**：静态阅读 + 全仓 grep + **实测**（真实启动静态服务并用原始 TCP socket 构造恶意 HTTP 请求；真实执行 `node e2e_test.js` 全量 E2E）

> 说明：报告中所有 `server.js` 结论均来自**实际执行**（见第 5 节"实测命令与原始输出"），非静态推断。所有临时探针文件与越权取证文件（`.probe_server.cjs`、`.probe_http*.mjs`、`qa_canary_secret.txt`）已在审计结束后删除；E2E 运行重新生成的 5 张 PNG 已 `git checkout` 还原，`git status` 仅剩本次新增的 `.qa/` 目录。

---

## 0. 结论摘要（按严重度）

| 级别 | 代表问题（详见第 1 节 48 条清单） |
| :--- | :--- |
| 🔴 严重 | #1~#7：**单请求即可让 `server.js` 进程崩溃**（实测 6 种 payload）、**路径穿越可读出工程根目录之外的文件**、`.git/config`/`node_modules`/测试源码可被下载且 CORS 全开、**绑定 0.0.0.0**；#10 `npm start` 直接崩溃；#13~#15 `flutter_e2e_verify.mjs` **零断言**却打印"100% 通过"，且在产物缺失/404 页面时同样报 PASS |
| 🟠 高 | #8/#9 Range 越界与多段处理错误；#11 CI 从不执行 83 项套件；#12 硬编码浏览器绝对路径；#16 硬编码坐标点击；#17/#19~#23 E2E 覆盖率无下限保护 + 弱断言/"元素存在即通过"；#29~#31 原型"播放"是振荡器合成而非 mp3、"本地导入"根本不出声、34.5 MB 真实音频全仓零引用；#35~#38 design tokens 与 Flutter 数值大面积不符 |
| 🟡 中 | #24~#28 E2E 硬编码文案/仅 headless Chrome/固定 sleep + `networkidle0`/不自起服务；#32 CDN 离线不可用；#33/#34 README 引用 2 张不存在的截图、截图无断言含金量；#40~#44 无缓存头、无 405/HEAD 语义、MIME 覆盖不全、TOCTOU；#45/#47 console 静默降级、音质 UI 纯装饰且 README EQ 参数与代码不符；#48 文档宣称不可复现 |
| 🔵 低 | #39 单文件膨胀（各约 150 KB）与 210 行双端逐字重复；#46 无 CSP/内联事件（此项同时确认 TODO/debugger 清理良好）；#43 缺 `charset`；`.qa/` 与 `public/audio` 未纳入 `.gitignore` |

**三项必须立刻修的问题**：
1. `server.js:62-76` 的 Range 分支 + `server.js:35` 的 `decodeURI` 无任何异常保护 → **单条 curl 即可打死服务**；
2. `server.js:40/44` 的 `path.join` 未做 `path.resolve` 白名单校验 → **可读取工程根目录外的任意文件**；
3. `package.json:5` `"type": "module"` 与 `server.js:1` `require()` 冲突 → **README 的"快速启动"第一步就失败**。

---

## 1. 主表：问题清单

> **位置**列格式：`文件:行号`。**证据**列中的 HTTP 输出均为实测原文（截断处标注）。

| # | 位置 | 问题 | 证据（含实测 HTTP 输出/代码片段） | 影响 | 建议 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `server.js:62-76`、`server.js:50` | **Range 请求可单条打死服务进程**。`parseInt` 结果未校验即传入 `fs.createReadStream({start,end})`，`start` 为 NaN 或 `start>end` 时 Node 同步抛 `ERR_OUT_OF_RANGE`；该 throw 发生在 `fs.stat` 的异步回调里，外层无 `try/catch`，直接变成 uncaught exception 终止进程 | 实测（原始 TCP）：`GET /public/audio/track1.mp3` + `Range: bytes=abc-` → 客户端 `[SOCKET ERROR] read ECONNRESET`，服务进程退出，stderr：`RangeError [ERR_OUT_OF_RANGE]: The value of "start" is out of range. It must be an integer. Received NaN`。同一方式命中 4 种 payload：`bytes=abc-`(NaN)、`bytes=-500`(后缀式)、`bytes=100-50`(start>end)、`bytes=99999999-`(start>EOF，报 `Received 99999999`，`at .probe_server.cjs:68:29` = `server.js:68`)。崩溃后再次请求 → `connect ECONNREFUSED 127.0.0.1:8088` | 未认证远程 DoS。任何浏览器/爬虫/恶意脚本一条请求即令本地服务与 E2E 全链路失效 | ① 用 try/catch 包住整个 `fs.stat` 回调；② Range 解析走严格正则 `/^bytes=(\d*)-(\d*)$/`，校验 `Number.isInteger`、`start<=end`、`start<totalSize`，非法即回 416 + `Content-Range: bytes */${totalSize}`；③ 给 `fileStream` 加 `on('error')`；④ 进程级 `process.on('uncaughtException')` 兜底 | 
| 2 | `server.js:40`、`server.js:44` | **路径穿越：可读取 BASE_DIR 之外的任意文件**。`path.join(BASE_DIR, reqPath)` 未做 `path.resolve` 前缀校验，`/..` 直接向上逃逸；Windows 下 `\` 也是分隔符，故 URL 编码反斜杠同样生效 | 取证：在**工程根目录之外**创建 `E:\code\AI\vibCoding\qa_canary_secret.txt`（内容 `TOP-SECRET-CANARY-OUTSIDE-PROJECT-ROOT`），实测：<br>`GET /../qa_canary_secret.txt` → `HTTP/1.1 200 OK`，`Content-Length: 39`，body=`TOP-SECRET-CANARY-OUTSIDE-PROJECT-ROOT`<br>`GET /..%5cqa_canary_secret.txt`（编码反斜杠）→ `200 OK` + 同一内容<br>`GET /%2e%2e/qa_canary_secret.txt`（编码点）→ `200 OK` + 同一内容<br>对照：`GET /..%2fqa_canary_secret.txt`（编码正斜杠）→ `404`（因 `decodeURI` 保留保留字符 `%2F`，见 #3） | 任意文件读取（配置、密钥、SSH key、同盘其他工程源码）。因 #2 与 #5 组合，可由任意网页远程读取后回传 | `const safe = path.resolve(BASE_DIR, '.' + reqPath); if (!safe.startsWith(path.resolve(BASE_DIR) + path.sep)) return 403;`。**必须**用 `path.resolve` 后再做前缀比对，仅靠 `path.join` 无效 |
| 3 | `server.js:35` | **`decodeURI` 抛 `URIError` 直接崩溃**（该调用在 request handler 顶层，无 try/catch） | 实测：`GET /%ZZ HTTP/1.1` → 客户端 `read ECONNRESET`，服务进程退出，stderr：`URIError: URI malformed`，`at .probe_server.cjs:35`（= `server.js:35`） | 未认证 DoS；畸形 URL（含被安全扫描器/爬虫误发的请求）即打死服务 | 用 `try { decodeURIComponent(...) } catch { return 400 }`；或改用 `new URL(req.url, 'http://x')` 的 `pathname`（不抛错、且会做一次规范化） |
| 4 | `server.js:43-44`、`server.js:50` | **空字节注入崩溃**。`decodeURI` 后 `%00` 变成 `\0`，`fs.existsSync` 抛 `ERR_INVALID_ARG_VALUE` | 实测：`GET /%00.html HTTP/1.1` → `read ECONNRESET`，stderr：`TypeError [ERR_INVALID_ARG_VALUE]: The argument 'path' must be a string, Uint8Array, or URL without null bytes. Received 'E:\code\AI\vibCoding\mellow-music-player\\x00.html'` | 未认证 DoS（`fs.existsSync` 在同步阶段抛出，位于 handler 顶层） | 解析后拦截 `\0`：`if (reqPath.includes('\0')) return 400;` |
| 5 | `server.js:25` | **CORS 全开 `Access-Control-Allow-Origin: *`，且对"敏感文件响应"同样生效** | 实测 `GET /.git/config` 响应头：`Access-Control-Allow-Origin: * \| Access-Control-Allow-Methods: GET, OPTIONS \| Access-Control-Allow-Headers: Range, Content-Type \| Content-Length: 309`；穿越成功的 `/../qa_canary_secret.txt` 响应同样带 `Access-Control-Allow-Origin: *` | 任意网站的 JS 可 `fetch()` 本服务并读取 `.git/config`、穿越读到的文件，形成"浏览器端任意文件读取 + 外传"。结合 #10（监听 0.0.0.0）可被局域网内任意页面利用 | 默认不发 CORS 头；确需跨域时用白名单校验 `Origin`，并对 `/`、`*.html`、`*.css`、`*.js`、`*.mp3`、图片等静态资源才允许 `*` |
| 6 | `server.js:88-89` | **绑定 `0.0.0.0`**，把本地原型服务暴露到整个局域网（含公共 WiFi） | `server.listen(PORT, '0.0.0.0', () => { console.log(\`Server running at http://0.0.0.0:${PORT}/\`); });` | 同网段任何设备可读取 #2/#7 中列出的敏感文件 | 改为 `server.listen(PORT, '127.0.0.1')`；确需局域网演示时显式提供环境变量开关并在 README 标注风险 |
| 7 | `server.js:40-48`（无隐藏文件/目录黑名单） | **隐藏文件与依赖目录可被直接下载**：`.git/`、`node_modules/`、`package.json`、`*.js` 源码、`e2e_test.js` | 实测：<br>`GET /.git/config` → `200 OK`，`Content-Length: 309`，body 含 `[remote "origin"] url = https://github.com/Kline-x/mellow-music-player.git`<br>`GET /node_modules/puppeteer-core/package.json` → `200 OK`，`Content-Length: 4068`<br>`GET /package.json` → `200 OK`，`Content-Length: 587`<br>`GET /e2e_test.js` → `200 OK`，`Content-Length: 45999`，body 起始 `import puppeteer from 'puppeteer-core';`（暴露 #12 的硬编码本机路径）<br>`GET /../../...Windows/win.ini` 类跨盘访问 → `404`（`path.join` 不改变盘符，无法从 E: 跳到 C:，此为唯一"幸免"点） | 源码/依赖/可读的 VCS 元数据全量外泄；本项目当前 `.git/config` 只含公开仓库 URL，但模式本身有泄露凭据的风险 | 加白名单后缀 + 黑名单目录：`.git`、`node_modules`、`.github`、`.qa`、`release_windows` 及所有 `.` 开头路径一律 403；或改为"只从 `public/` 与显式文件清单提供服务" |
| 8 | `server.js:64-67` | **Range 越界 `end > totalSize` 不裁剪** → 返回 `206` 但 `Content-Length` 大于文件实际长度，且 `Content-Range` 违法 | 实测 `Range: bytes=0-999999999`（文件 8,945,229 B）：<br>`HTTP/1.1 206 Partial Content`<br>`Content-Range: bytes 0-999999999/8945229`<br>`Content-Length: 1000000000`<br>（服务未崩，但随即流结束，客户端按 1,000,000,000 字节等待） | 播放器 seek 到尾部附近易卡死/报错；HTTP 协议违规，中间代理可能缓存错误区间 | `end = Math.min(end, totalSize - 1)`；`start > totalSize-1` → `416` |
| 9 | `server.js:64-66` | **多段 Range 被静默降级为单段，且不返回 multipart** | 实测 `Range: bytes=0-9,20-29`：`parseInt('10,20')`→`10`，响应 `206`、`Content-Range: bytes 0-9/8945229`、`Content-Length: 10` | 与 RFC 7233 不符；若客户端依赖多段响应会拿到错误数据 | 检测 `,` 即回 `200` 全量（或实现 `multipart/byteranges`）；至少不返回错误的单段 |
| 10 | `package.json:5` vs `server.js:1` | **`npm start` / `node server.js` 直接崩溃**：`"type": "module"` 使 `.js` 被当作 ESM，而 `server.js` 是 CommonJS | 实测 `node server.js`（exit code 1）：<br>`ReferenceError: require is not defined in ES module scope, you can use import instead`<br>`This file is being treated as an ES module because it has a '.js' extension and 'E:\...\package.json' contains "type": "module".` | README:126-136 的"快速启动"第 3 步即失败；`e2e_test.js` 依赖 `http://localhost:8088`（`e2e_test.js:11`）也就无从跑起。**83/83 的可复现流程在文档层面是断的** | 二选一：把 `server.js` 改成 ESM（`import http from 'node:http'`），或重命名为 `server.cjs` 并同步 `package.json` 的 `start` 脚本。另建议加 `pretest` 自动起服务 |
| 11 | `.github/workflows/ci.yml:47-48` | **CI 从不运行 `e2e_test.js`**（83 项套件），只跑零断言的 `flutter_e2e_verify.mjs` | `ci.yml:47-48`：`- name: Execute Real Product-level E2E Verification\n  run: node flutter_e2e_verify.mjs`；全 `ci.yml`/`release.yml` grep 无 `e2e_test.js` 调用 | README:5 的 `83/83 Passed` badge 是**静态文本**，无任何门禁保护；原型层（`index.html`/`mobile.html`）回归无人拦截 | CI 增加 `npm start &`（或 `node server.cjs &`）+ `node e2e_test.js` 步骤，并把退出码作为门禁；badge 改用 workflow status badge |
| 12 | `e2e_test.js:5-9` | **硬编码本机 Chrome/Edge 绝对路径**，无浏览器即启动失败 | `const CHROME_PATH = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";`<br>`const EDGE_PATH = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";`<br>`const browserPath = fs.existsSync(CHROME_PATH) ? CHROME_PATH : EDGE_PATH;`<br>本机实测：Chrome 存在→ 正常；`C:\Program Files\Microsoft\Edge\Application\msedge.exe`（64 位 Edge）实测 `Test-Path = False`，即 x64 且 Edge 装在非 x86 路径的机器会落到不存在的路径 | 非 Windows / 无 Chrome / 仅装 64 位 Edge 的机器（含 CI）`puppeteer.launch` 抛错 → 整个套件崩在场景 0，一条结果都没有 | 复用 `flutter_e2e_verify.mjs:69-84` 的多候选检索（含 `CHROME_PATH`/`PUPPETEER_EXECUTABLE_PATH` 环境变量），找不到时给出明确错误并 `exit 2`（"环境缺失"≠"测试失败"） |
| 13 | `flutter_e2e_verify.mjs:106-205` | **零断言的"E2E"**：全过程只有截图 + 无条件打印 PASS，`allPassed` 仅在 catch 中置 false | `:135-137` 截图后直接 `console.log('✅ [PASS] Desktop E2E verified!')`；`:143-145`/`:151-153`/`:159-161`/`:185-187` 同构；`:199-205` 只要没抛异常就打印 `🎉 恭喜！Flutter 真实客户端产物级 E2E 测试 100% 通过！`；全文无 `assert`/`expect`/状态比对 | CI 绿灯完全不反映功能正确性 —— 页面白屏、路由全坏、渲染崩溃（只要不抛 page error）都会"通过"。这是 README/CI 可信度最大的单点风险 | 至少断言：页面标题非空、`flutter-view` 存在、关键文案（AppBar 标题/菜单项）文本内容、点击后可见性变化；把 `console.error`/`pageerror` 计数纳入判定；用选择器或语义定位替代坐标 |
| 14 | `flutter_e2e_verify.mjs:121-126`、`:176-181` | **关键等待失败被 `catch (_) {}` 静默吞掉**，继续走"通过"路径 | `try { await desktopPage.waitForFunction(() => !!document.querySelector('flutter-view')..., { timeout: 30000 }); } catch (_) {}` —— 30s 内 Flutter 视图**完全没有挂载**也被吞掉，随后 `await new Promise(r => setTimeout(r, 4000))` 只等死 4 秒就截图并报 PASS | 构建产物损坏/WASM 加载失败 → 仍报 100% 通过 | 删掉空 catch；捕获后记录 `failed++` 并把错误计入最终判定 |
| 15 | `flutter_e2e_verify.mjs:48-58`、`:199-205` | **产物缺失也会"通过"**：SPA fallback 在 `app/build/web/index.html` 不存在时返回 `404 Not Found` 纯文本页，脚本照样截图并打印 PASS | `:50-57`：`const indexPath = path.join(WEB_DIR,'index.html'); if (fs.existsSync(indexPath)) {...} else { res.writeHead(404,...); res.end('Not Found'); }`；而 `:104-205` 对 404 页面无任何判别 | 忘记 `flutter build web`、构建失败、目录路径变更都会得到"100% 通过"和 5 张写着 "Not Found" 的存证截图 | 断言首页返回 200 且 `<title>`/`flutter-view` 存在；缺失 `app/build/web` 时直接 `exit 1` 并提示先构建 |
| 16 | `flutter_e2e_verify.mjs:139-141`、`:147-149`、`:155-157` | **硬编码坐标点击**，且不校验点击结果 | `await desktopPage.mouse.click(100, 200); // 巅峰榜单`<br>`await desktopPage.mouse.click(75, 630); // 多端同步中心`<br>`await desktopPage.mouse.click(75, 680); // LX 音源管理`<br>点击后仅 `setTimeout 2000` + 截图，无任何"视图已切换"断言 | 侧边栏项顺序/高度/字体/窗口尺寸任一处变动 → 点到别的控件，测试**照样 PASS** 但截图内容是错的；反之无法发现真实的导航回归 | 改用 `page.getByText('巅峰榜单')` / Flutter 语义树（`flt-semantics`）或 `data-*` 定位；断言切换后可见文案 |
| 17 | `e2e_test.js:32`、`:815-817` | **单一全局 `try/catch`，无 per-scenario 隔离**：任一场景抛错即中断其后全部场景，只补记 1 条 FAIL | `:32` `try {`（包住桌面 + 移动全部 83 个场景）… `:815-817` `} catch (err) { console.error(...); recordResult('E2E Execution Crash', false, err.message); }` | 崩溃在场景 40 → 场景 41-83 既不执行也不报告；`:829-836` 的汇总只输出 `Total Scenarios Tested : 41`，**没有"必须等于 83"的断言**，任何人只看 `Failed: 1` 都可能误判覆盖面 | 每场景包 `try/catch`（记录失败继续跑）；套件末尾断言 `testResults.length === 83`，不足即 exit 1；或改用 `node:test`/`vitest` 让 runner 负责隔离与计数 |
| 18 | `e2e_test.js:15-19`、`:829-836` | 静态计数核实：`recordResult(` 共 85 处匹配 = 1 处函数定义（`:15`）+ 1 处崩溃兜底（`:817`）+ **83 处真实断言调用**。实测运行输出 `Total Scenarios Tested : 83` / `83 / 83 (100%)` / exit 0 —— **"83"这个数字本身是真的、可复现的** | 实测末尾：`Total Scenarios Tested : 83\nPassed Scenarios : 83 / 83 (100%)\nFailed Scenarios : 0`；`✅ PASS` 行 74 条 + 多行断言的 9 条 = 83 | ——（非缺陷，但需明确它只是"83 个检查点"，不等于 83 个独立用户旅程；且 83 的成立依赖 #10/#12 两个外部前置条件被人工满足） | 在 README 中补上"需先 `node server.cjs` 且本机装有 Chrome"的前置说明，或按 #10/#11 改造后由 `npm test` 一键复现 |
| 19 | `e2e_test.js:65-66`、`:111`、`:181`、`:189-192`、`:198`、`:221`、`:239`、`:245`、`:294`、`:432`、`:497`、`:522`、`:775` | **弱断言（"元素存在即通过"）** —— 名称宣称验证行为，实际只查了 class 是否含 `hidden` / 元素数量 > 0 | 典型：`:65-66` `const eqBarsCount = await page.$$eval('.eq-bar', bars => bars.length); recordResult('EQ Bars Present & Animated', eqBarsCount > 0, ...)` —— **断言里没有任何"动画"证据**（未比对两帧的 `transform`/`height`/`animation-play-state`）<br>`:181` `recordResult('Sidebar Nav -> 我喜欢的音乐 (Favorite)', favoriteVisible, ...)` 仅判 `!classList.contains('hidden')`<br>`:189-192` `dropzoneExists/fileInputExists` 仅判元素存在<br>`:294`/`:432` 全屏歌词"打开"仅判 `!classList.contains('opacity-0')`/`!contains('translate-y-full')`<br>`:775` 跨端链接仅比对 `href === 'index.html'` | 视图渲染成空白、内容未填充、动效失效都会 PASS，覆盖率高但拦截率低 | 断言状态迁移的"前-后"差值（如暂停时 `data-playing` false→true→false 且 `vinyl-paused` class 同步）、断言渲染出的文本/数量与数据源一致、动效断言比对两帧计算样式（见 `:72-75` 已做对的正例，应推广） |
| 20 | `e2e_test.js:618-621` | **Lo-Fi 分类筛选断言存在假阳性**：点击筛选后只断言"卡片数 ≥ 1" | `await mobilePage.click('#mPlCatLofi'); ... const filteredCount = await mobilePage.$$eval('#mPlaylistSquareGrid > div', els => els.length); recordResult('歌单广场分类筛选 (Lo-Fi Filter)', filteredCount >= 1, ...)` —— 筛选逻辑完全坏掉（返回全部 6+ 张）时该断言**依然通过** | 分类筛选功能回归无法被发现 | 记录点击前的 `squareTotalCards`，断言 `filteredCount < squareTotalCards && filteredCount >= 1`，并抽样断言卡片文本属于 Lo-Fi 类目 |
| 21 | `e2e_test.js:695-699` | **"FM 漫游下一首"未验证歌曲真的变了** | `const nextFmTrack = await mobilePage.$eval('#mFmTitle', el => el.textContent.trim()); recordResult('私人FM 漫游下一首', nextFmTrack.length > 0, \`Roamed from "${initialFmTrack}" -> "${nextFmTrack}"\`)` —— 断言只看"非空"，连 `initialFmTrack !== nextFmTrack` 都没比。对照 `:84-87` 的 Desktop Next Track 断言（`initialSongTitle !== nextSongTitle`）是正确的，此处属漏写 | `nextFmSong()` 失效、每次都返回同一首都会 PASS，日志里却写着 "Roamed from A -> A" | 改为 `nextFmTrack.length > 0 && nextFmTrack !== initialFmTrack` |
| 22 | `e2e_test.js:297-301`、`:446-450` | **"点击歌词跳转"是条件式断言 + 弱判据**：(a) 元素找不到时静默跳过点击仍记 PASS；(b) 只判时间不是 `00:00`，而此前测试已让播放器计时，故该条件无需 seek 也会成立 | `:297-298` `const firstLyric = await page.$('#lyricsScrollContainer > div:nth-child(2)'); if (firstLyric) await firstLyric.click();` → `:300-301` `const seekTimeUpdated = await page.$eval('#currentTimeText', el => el.textContent.trim() !== '00:00'); recordResult('Interactive Lyrics Seeking on Click', seekTimeUpdated, ...)`<br>`:446-450` 同构 | 歌词跳播功能失效不会被发现；断言注释"Playback jumped from 00:00"与事实不符（`:298` 之前已播放过） | 断言点击前后 `#currentTimeText` 发生跳变（差值 > 若干秒）且与歌词 `time` 字段吻合；`if (el)` 改为 `if (!el) { recordResult(name, false, 'lyric row missing'); }` |
| 23 | `e2e_test.js:187-188`、`:675` | 冗余存在性表达式：`page.$eval(sel, el => !!el)` —— `$eval` 找不到元素本身就会抛错，`!!el` 恒为 true | `:187-188` `const dropzoneExists = await page.$eval('#localDropzone', el => !!el); const fileInputExists = await page.$eval('#localAudioFileInput', el => !!el);`；`:675` `const fmVinylExists = await page.$eval('#mFmVinyl', el => !!el);` | 语义误导（读者以为在做校验）；一旦元素缺失，抛错会触发 #17 的全局中断而非"本场景失败" | 改用 `await page.$(sel) !== null` 得到布尔值并显式记录失败，避免依赖异常中断 |
| 24 | `e2e_test.js:747` | **断言硬编码业务文案**，内容一改即红（脆性耦合） | `artDetailVisible && artDetailName === '周杰伦' && artDetailFans.includes('3280 万') && artDetailTracks >= 2` | 与"更新演示数据/多语言"直接冲突；且该数字与桌面端同一歌手的 1,290万 自相矛盾（见 #30） | 断言结构而非具体值（如"粉丝数字段非空且匹配 /\d+\s*万/"、"曲目数 == 数据源中该歌手的 songs 长度"）；跨端取同一 fixtures 文件 |
| 25 | `e2e_test.js:41`、`:48`、`:338` | **只监听 `pageerror`，无 `console`/`requestfailed` 监听；且只有第 1 个场景检查错误数** | `:41` `page.on('pageerror', err => desktopErrors.push(err.message));` → `:48` `recordResult('Desktop Page Initialized', hasSoftTitle && desktopErrors.length === 0, ...)`；此后 `desktopErrors` 再未被读取（移动端 `mobileErrors` 在 `:337` 收集后**从未被断言**） | 4xx/5xx 资源失败、CDN 中断、Promise rejection、控制台报错全部静默；两端各自只有"第 1 条"把错误纳入判定 | 加 `page.on('console')`（过滤 `error`）、`page.on('requestfailed')`、`page.on('response')` 统计非 2xx；在**汇总阶段**统一断言"全程 0 个未预期错误" |
| 26 | `e2e_test.js:43`、`:340` + 全文 `setTimeout` | **等待策略脆弱**：仅 `waitUntil: 'networkidle0'` + 97 处固定毫秒 sleep，全文 **0 处** `waitForSelector`/`waitForFunction` | `await page.goto(\`${BASE_URL}/\`, { waitUntil: 'networkidle0' });`（无 `timeout`，用默认 30s）；实测 grep：`waitForSelector\|waitForFunction\|waitForNavigation` 命中 0 条，`setTimeout(r, N)` 命中 97 条（如 `:53` 1000ms、`:82` 600ms、`:514` 300ms） | 页面依赖 4 个外部 CDN（见 #45），`networkidle0` 在慢网/离线时超时或长时间挂起；休眠时长在慢机器上不足即产生随机红灯（"flake"） | 用 `waitForSelector(sel, {visible:true})` / `waitForFunction` 替代固定 sleep；`goto` 显式设 `timeout` 并 `waitUntil: 'domcontentloaded'` + 关键元素等待；对 CDN 依赖做强本地化（见 #45） |
| 27 | `e2e_test.js:26-30` | **仅 headless Chrome 单内核**，无 Firefox/WebKit，也无 headed 冒烟 | `:26-30` `puppeteer.launch({ executablePath: browserPath, headless: true, args: ['--no-sandbox','--disable-setuid-sandbox','--autoplay-policy=no-user-gesture-required'] })` | 只能发现 Chromium 系问题；`--autoplay-policy=no-user-gesture-required` 使"点击才发声"的用户手势路径（真实浏览器的关键约束）**从未被测试** | 引入 Playwright，至少 Chromium + WebKit 双内核冒烟；去掉 autoplay 豁免并断言"未点击前不播放、点击后才播放" |
| 28 | `e2e_test.js:11`、全文无进程管理 | **测试套件不自起服务**，强依赖外部已在 8088 监听 | `const BASE_URL = 'http://localhost:8088';`；全文无 `child_process`/`spawn`；`package.json:9-10` `"test": "node e2e_test.js"` 无 `pretest` | 忘记先起服务（或如 #10 起不来）→ `goto` 抛 `ECONNREFUSED` → 只记 1 条 "E2E Execution Crash"；`npm test` 不能自证可运行 | `pretest` 脚本用 `start-server-and-test` 或直接 `spawn` 静态服务 + 健康检查轮询后再跑测试 |
| 29 | `index.html:1665-1836`、`mobile.html:1359-1523` | **"播放"根本不是音频文件播放，而是 Web Audio 振荡器合成**：`createOscillator` + 硬编码和弦数组，无任何 `<audio>`、`decodeAudioData`、`AudioBufferSourceNode` | `index.html:1676-1683`：`this.chords = [[261.63, 329.63, 392.00, 493.88], // CMaj7 ...]`；`:1807` `const osc = this.ctx.createOscillator();` `osc.type = idx % 2 === 0 ? 'triangle' : 'sine';`，每 2500ms 播一个和弦（`:1829-1834`）<br>`mobile.html:1369-1376` 同一份和弦表、`:1494` 同构 `createOscillator`<br>全仓 grep `new Audio`/`<audio`/`decodeAudioData` 在两端 HTML **命中 0**（仅 `index.html:1690`/`mobile.html:1383` 的 `new AudioContext()`、`:1703`/`:1391` 的两条 `console.log`） | 用户所听到的是"合成和弦循环"，不是所显示曲目的声音；进度条/时长与声音完全无关联（时长是写死的 `durationSec`）。**"高保真/无损/Hi-Res 母带"宣称与实现无关** | 若定位是"交互原型"，应在 UI/README 显著标注"音频为占位合成音"；若要保留"高保真"卖点，需真正接 `<audio src>` + `public/audio/track*.mp3`（见 #31）并把进度、时长、播放量绑定真实媒体事件 |
| 30 | `index.html:3013`、`mobile.html:2710-2727`、`index.html:3050-3053` | **"本地音频导入/磁盘扫描"是假功能，导入的文件永远不会发声** | 桌面：`:3003` `const url = URL.createObjectURL(file);` → `:3013` `fileUrl: url,` —— 但全文件 grep `fileUrl` **仅此 1 处命中**，无任何消费者（`playTrack` 在 `:2446` 也不读它），播放仍走振荡器引擎<br>移动：`:2716-2723` 把文件塞进列表，`idx: Math.floor(Math.random() * SONGS.length)` —— **随机指向内置曲目**，点击播放的是随机内置歌 + 合成音<br>`:3050-3053` `function scanLocalDemoFiles() { showToast('本地磁盘扫描完成，已同步 6 首无损曲目', ...); renderLocalSongs(); }` —— 无任何扫描逻辑，纯粹骗提示 | `index.html:1054/1073`、`mobile.html:927` 宣称"支持 FLAC/APE/WAV/DSD/OGG 拖拽即播 / 高解析无损回放"实际 100% 不成立；"已同步 6 首无损曲目"是硬编码 toast | 要么实现 `<audio src=fileUrl>` 的真实回放（并在 e2e 中断言 `audio.currentTime > 0`、`audio.src` 为 blob URL），要么从 UI 移除该入口并删除相关文案 |
| 31 | `public/audio/track1.mp3` ~ `track4.mp3`（8.9/10.2/8.3/7.8 MB，合计 **34.5 MB**） | **4 个真实音频文件是全仓死文件**，没有任何代码引用 | 全仓（排除 `node_modules`/`build`）grep `track1\|track2\|track3\|track4\|public/audio\|audio/track` → 除本次审计临时脚本外 **0 命中**；`app/pubspec.yaml:72-80` 的 `assets:` 段全被注释（Flutter 也未打包）；`server.js` 会正常提供它们（`audio/mpeg`），仅此而已 | 34.5 MB 二进制进版本库、拉取变慢、clone 变大；更关键的是它误导读者以为原型播放的是这些 mp3（见 #29） | 若走真实播放：在原型中引用它们并保留；否则从仓库删除并用 `.gitignore` 防止再入库，同时修正相关文案 |
| 32 | `index.html:9-15`、`mobile.html:9-15` | **原型并非自包含，强依赖 4 个外部 CDN**（且 Tailwind 是运行时 JIT） | 两端均含：`:9` `<script src="https://cdn.tailwindcss.com"></script>`（运行时编译全部样式）、`:11` `remixicon@4.3.0`（全部图标）、`:13-15` `fonts.googleapis.com`/`fonts.gstatic.com`；另全页封面/头像走 `images.unsplash.com`（index 命中 24+ 个不同图片 URL） | 离线/内网/被墙环境 → 页面裸奔成无样式无图标的 HTML；`e2e_test.js` 的 `networkidle0`（#26）与截图存证均受外网可用性影响，测试结果不可复现 | 本地化：Tailwind 走构建产物（或降级为手写 CSS）、图标字体与字体文件、封面图本地占位图；至少在 README 标注"需外网" |
| 33 | `README.md:18`、`README.md:22` | **README 引用了 2 张不存在的存证截图** | 遍历 README 中全部 `public/*.png` 引用并实测存在性：<br>`public/e2e_desktop_verified.png` exists=True<br>`public/e2e_mobile_verified.png` exists=True<br>**`public/showcase_desktop_dark.png` exists=False**（README:18 深色模式）<br>**`public/showcase_desktop_lyrics.png` exists=False**（README:22 歌词/EQ）<br>`public/showcase_mobile_artist.png` exists=True<br>`public/showcase_mobile_eq.png` exists=True<br>`public/showcase_mobile_fm.png` exists=True<br>`public/showcase_mobile_local.png` exists=True | GitHub README 上这两格显示为坏图；"界面预览"这一交付证据链断裂 | 补齐这两张（可由 `e2e_test.js` 增加两个场景生成，见 #34），或改用实际存在的文件 |
| 34 | `e2e_test.js:322-325`、`:778-811` | `e2e_test.js` **只生成 5 类截图，无法产出 README 引用的桌面暗色/歌词图**；且这些"存证"是在无内容断言下截的 | 生成清单：`:323-325` `public/e2e_desktop_verified.png`；`:778-779` `public/e2e_mobile_verified.png`；`:786` `showcase_mobile_fm.png`；`:795` `showcase_mobile_artist.png`；`:802` `showcase_mobile_local.png`；`:811` `showcase_mobile_eq.png`（无 desktop_dark / desktop_lyrics / mobile_home） | 存证与文档不同步；截图本身不能证明功能（见 #19） | 让 README 引用的每张图都有确定生成步骤（脚本内或 `docs/` 注释说明命令），并在 CI 里作为 artifact 上传以便比对 |
| 35 | `design_tokens.css:20/24/25` vs `app/lib/design_system/tokens.dart:26/29/30` | **亮色 token 数值不一致**（角色与数值双重错位） | `--soft-bg-recessed: #E8EEF5`（css:20） vs `recessedLight = Color(0xFFEBF0F8)`（dart:26）<br>`--soft-text-main: #1E293B`（css:24，注释 Slate 800） vs `textPrimaryLight = Color(0xFF0F172A)`（dart:29，Slate 900）<br>`--soft-text-secondary: #64748B`（css:25，Slate 500） vs `textSecondaryLight = Color(0xFF475569)`（dart:30，Slate 600）<br>（仅 canvas `#F5F7FB`、card `#FFFFFF`、muted `#94A3B8` 一致） | 同一设计系统在 Web 与 Flutter 呈现不同灰度层级，暗/亮对比度与"温润白瓷"观感漂移；两套规范无法互相校验 | 建立单一事实源（如 `tokens.json`/`design_tokens.css` 为源，用脚本生成 `tokens.dart`），并在 CI 加"token 一致性"校验脚本 |
| 36 | `design_tokens.css:91-95/109` vs `tokens.dart:34-39` | **暗色 token 数值不一致，且语义角色被调换** | css `--soft-bg-subtle: #161B22`(css:92) / `--soft-bg-surface: #1C2128`(css:93) / `--soft-bg-recessed: #13171E`(css:95) / `--soft-border-subtle: rgba(240,246,252,0.08)`(css:109)<br>dart `cardDark = 0xFF161B22`(dart:35) / `cardMutedDark = 0xFF1C2128`(dart:36) / `recessedDark = 0xFF0B0E14`(dart:37) / `borderDark = 0xFF30363D`(dart:38) / `borderSubtleDark = 0xFF21262D`(dart:39)<br>→ CSS 的 `bg-surface` 在 Dart 里成了 `cardMuted`；CSS 的 `bg-subtle` 成了 Dart 的 `card`；recessed 差 `#13171E`→`#0B0E14`；CSS 语义化半透明边框在 Dart 里成了实色 | 暗色模式两端观感不一致；命名相同含义不同，后续维护者极易改错 | 同上：统一源 + 生成；给 token 补充语义注释并对齐命名 |
| 37 | `design_tokens.css:150-157` vs `tokens.dart:57-75` | **圆角刻度不成体系，两套值域互不覆盖** | CSS：`pill 9999 / window 28 / card-lg 24 / card-md 18 / card-sm 12 / btn 14`<br>Dart：`r8 / r12 / r16 / r20 / r24 / r28 / r32 / pill`<br>→ CSS 独有 `18`、`14`；Dart 独有 `8`、`16`、`20`、`32` | "Squircle 22~28px"（README:44）这类规范无法在两端同时成立；组件圆角无法一一映射 | 定义一套刻度（如 8/12/16/20/24/28/9999）并删除两端的野值；`btn`/`card-md` 映射到刻度内的档位 |
| 38 | `design_tokens.css:45-75` vs `tokens.dart:78-165` | **阴影系统不一致**：(a) 颜色与几何完全不同；(b) Dart 缺失 `convex`/`pressed` 两级；(c) README 主打的"内白高光内边"在 Flutter 侧无法实现 | css `:45-48` flat=none→`0 2px 8px -1px rgba(112,144,176,.08)`，色相偏蓝灰 `#7090B0`；dart `:80-93` cardLight=`0 4px 20px -2px #0F172A@5%` + `0 2px 6px -1px #0F172A@3%`（色相 `#0F172A`，blur/offset 完全不同）<br>css `:51-54` raised / `:57-60` dock / `:63-66` recessed / `:68-71` convex / `:73-75` pressed（5 级 + 内阴影）；dart 只有 cardLight/cardDark(`:80-109`)、floatingPillLight/Dark(`:112-141`)、recessed(`:144-164`)，**无 convex/pressed**<br>README:40 宣称 `inset 0 1px 0 rgba(255,255,255,0.9)` 高光内边；Flutter `BoxShadow` 不支持 inset，`tokens.dart` 全文无等价实现（无 `foregroundDecoration`/`Gradient` 模拟） | 两端"柔性景深"观感差异明显；README 的设计规范在 Flutter 端不可达，后续 UI 验收标准失效 | 用 Flutter 的 `BoxDecoration(gradient:)`/`foregroundDecoration` 模拟内高光并固化到 `MellowShadows`；补齐 convex/pressed；把阴影也纳入单一事实源 |
| 39 | `index.html:3255` 行 / 157,153 B、`mobile.html:2926` 行 / 144,927 B | **单文件巨型化**（注意：是"每个约 150 KB、合计约 295 KB"，不是单文件 300 KB）；两端内嵌 `<style>` + 巨型 `<script>`，与数据、逻辑、DOM 全耦合 | `index.html`：`<style>` 块 48-482 行（435 行 CSS），`<script>` 于 `:19` 与 `:1474` 起（数据 `SONGS` `:1476`、`PLAYLISTS` `:1602`、`ARTISTS` `:1653`、`CHARTS` `:2031`、`PODCASTS` `:2111`，引擎 `:1665-1838`，业务 `:1843-3255`）<br>`mobile.html`：`<style>` 37-238 行（202 行 CSS），`SONGS` `:1243`、`CHARTS` `:2347`、`ARTISTS_DATA` `:2510`<br>对比 `server.js` 仅 90 行 | 无法 diff review、无法单测、无模块边界；两端 **210 行 >40 字符的代码逐字重复**（音频引擎、和弦表、`SONGS`、localStorage 逻辑、toast 等），改一处必漏另一处（这正是 #30 双端不一致的根因） | 拆分为 `tokens.css` / `app.css` / `data.js`（两端共享 fixtures）/ `audio-engine.js` / `desktop.js` / `mobile.js`；至少把重复的引擎与数据抽成共享文件，两端 `<script src>` 引入 |
| 40 | `server.js` 全部响应（无 `Cache-Control`/`ETag`/`Last-Modified`） | **无任何缓存机制**，157 KB 的 HTML 每次访问全量重传 | grep `server.js` 的 `setHeader\|Cache-Control\|ETag\|Last-Modified` → 仅 `:25-27` 三条 CORS 头；实测响应头也只有 `Content-Length/Content-Type/Accept-Ranges/Date/Connection` | 本地开发反复刷新与 E2E 每次导航都重新传输 ~150 KB HTML + 34.5 MB 音频；无 304 协商 | 静态资源加 `Cache-Control: no-cache`（开发）或按 `mtime` 生成 `ETag` + 处理 `If-None-Match` 回 304 |
| 41 | `server.js:29-33`、`:24` | **无方法白名单**：声明的 CORS 只含 `GET, OPTIONS`，但服务端对 POST/PUT/DELETE 一律按 GET 处理 | 实测 `POST / HTTP/1.1`（body 空）→ `HTTP/1.1 200 OK` + `Content-Length: 157153` + 完整 index.html | 语义混乱；将来若加入写接口会直接形成未授权写入口 | 在 handler 开头 `if (!['GET','HEAD'].includes(req.method)) { res.writeHead(405, {Allow:'GET, HEAD'}); return res.end(); }` |
| 42 | `server.js:77-84` | **HEAD 语义未实现**：`HEAD /` 返回完整 body | 实测 `HEAD / HTTP/1.1` → `HTTP/1.1 200 OK` + `Content-Length: 157153`，且响应体存在（原始 socket 收满 157 KB） | 浪费带宽；某些监控/预检工具行为异常 | 对 `HEAD` 只写头不 `pipe`（或用 `res.end()` 结束） |
| 43 | `server.js:8-22`、`:57-58` | **MIME 表覆盖不全**，且未知类型静默降级为 `application/octet-stream`；`.json` 无 `charset` | 表中无 `.md/.txt/.ico/.wasm/.ttf/.woff2/.map`；实测 `GET /.git/config` → `Content-Type: application/octet-stream`；`GET /../README.md` → `application/octet-stream`；`GET /package.json` → `Content-Type: application/json`（无 charset） | Markdown/纯文本在浏览器里变成下载；`flutter_e2e_verify.mjs:13-28` 那份表补了 `.wasm/.ttf/.woff2/.mjs`，两处表各自维护（又一处重复） | 抽一个共享 MIME 表并补全；`.json/.md/.txt` 加 `; charset=utf-8` |
| 44 | `server.js:43-50` | **`fs.existsSync` + `fs.stat` 双次同步 IO，存在 TOCTOU 且阻塞事件循环**；`public/` 回退分支的 `path.join(BASE_DIR,'public',reqPath)` 同样会被 `..` 抵消（`/../package.json` 最终命中工程根目录的 `package.json`） | 代码：`if (!fs.existsSync(filePath)) { const publicPath = path.join(BASE_DIR, 'public', reqPath); if (fs.existsSync(publicPath)) filePath = publicPath; }`；实测 `GET /../package.json` → `200`、`Content-Length: 587`（正是仓库自身 package.json，说明 `public` 被 `..` 抵消后回到根目录） | 同步 IO 在并发下阻塞；TOCTOU 在文件被删/换时产生 500 或崩溃；回退分支让"看似被拦住"的路径重新可用 | 单次 `fs.promises.stat` + `try/catch`；回退分支同样做 `path.resolve` 前缀校验 |
| 45 | `index.html:1703`、`mobile.html:1391` | `catch` 中**残留 `console.log`**（调试痕迹），且失败被静默降级 | `index.html:1702-1704` `} catch(e) { console.log("AudioContext not supported or blocked:", e); }`；`mobile.html:1390-1392` `} catch(e) { console.log("Web Audio API not supported or blocked:", e); }` | 真实用户环境音频初始化失败时，用户无任何提示（播放按钮亮了但没声音），问题无法被发现（E2E 也不监听 console，见 #25） | 改 `console.warn` + 向用户 toast"当前浏览器不支持音频"；E2E 把 console error/warn 纳入判定 |
| 46 | 全仓 `index.html`/`mobile.html` | TODO/FIXME/**debugger 清理情况良好**（此项为正面结论，避免误判） | grep 结果：`debugger` 命中 0；`TODO\|FIXME\|XXX\|HACK` 在 `index.html` 命中 0，`mobile.html` 唯一命中 `mobile.html:320: <i class="ri-calendar-todo-fill"></i>` 是 remixicon 类名**误报**；`console.` 仅 `index.html:1703`、`mobile.html:1391` 两处（见 #45） | —— | 保持；CI 加 `debugger`/裸 `console.log` 的 lint 规则即可长期保证 |
| 47 | `index.html:893/900`、`index.html:1073`、`mobile.html:927`、`README.md:86-90` | **音质切换 UI 是纯装饰，且 README 的 EQ 参数与代码不符** | 音质单选：`<input type="radio" name="audioQuality" checked ...>`（`:893`）与 `:900` 均**无 `onchange`/无 JS 读取**（全仓 grep 无 `audioQuality` 消费者）→ "Hi-Res 192kHz/24bit / SQ FLAC" 切换不产生任何行为<br>EQ 参数对照：README:87-90 宣称 bass `lowshelf 120Hz +6dB` / vocal `peaking 2500Hz +4.5dB` / jazz `peaking 500Hz +3dB` / spatial `highshelf 8000Hz +5dB`；桌面代码 `index.html:1712-1729` 实为 bass `120Hz +9dB`、vocal `2500Hz +7dB Q1.2`、jazz `600Hz +5dB Q0.8`、preset 名 `surround` `5000Hz +6dB`；移动代码 `mobile.html:1410-1431` 又是第三套：bass `200Hz +6.0dB`、vocal `1200Hz +5.0dB`、jazz `400Hz +3.5dB`、surround `3500Hz +5.0dB` | 文档不可信（参数无法复现）；两端 EQ 手感不同；E2E `:507-509` 还专门断言了移动端 `gain === 6`，把"移动端特例"固化成了正确标准 | 三处以代码为准修正 README（或反过来统一代码），并把 EQ 参数抽成共享常量；音质切换要么实现，要么移除 |
| 48 | `README.md:5`、`README.md:109-110`、`docs/PROGRESS.md:13/30`、`docs/SPEC.md:370` | 文档宣称 `83/83` 的可复现前提未被记录，且与"高保真/无损"等未实现宣称并列在"100% 完成" | `README.md:5` 静态 badge `E2E Tests-83/83 Passed (100%)`；`README.md:109-110` 贴出 `Total 83 / Passed 83 / Failed 0`；`PROGRESS.md:13` `index.html、mobile.html、e2e_test.js (83/83 通过)`；`SPEC.md:370` 称其"100% 验收通过"<br>但实测该结果需要：(a) 手工先起 8088（因为 #10 `npm start` 崩），(b) 本机存在硬编码路径的 Chrome（#12） | 读者按 README"快速启动"操作会先在 `npm start` 处失败（#10），无法复现 83/83；文档可信度受损 | README 补前置条件与"如何得到 83/83"的一键命令；修复 #10/#12 后把 `npm test` 纳入 CI（#11） |

---

## 2. 专项详述

### 2.1 `e2e_test.js` 的 83 个场景到底断言了什么（对应问题 1）

**数量核实（结论：83 是真的）**

```
$ Select-String -Path e2e_test.js -Pattern 'recordResult(' | Measure-Object   # 85 行命中
  - 1 处 = 函数定义（e2e_test.js:15）
  - 1 处 = 崩溃兜底（e2e_test.js:817）
  → 真实断言调用点 = 83
$ node e2e_test.js   （先手工启动静态服务）
Total Scenarios Tested : 83
Passed Scenarios       : 83 / 83 (100%)
Failed Scenarios       : 0
[exit code: 0]    # ✅ PASS 行 74 条（多行断言的场景其 PASS 行跨行）+ 9 条单行 = 83
```

**断言强度分层（抽样 15 个）**

| 场景 | 行号 | 强度 | 说明 |
| :--- | :--- | :--- | :--- |
| Desktop Play Triggered & Audio Synth Active | `:57-62` | ✅ 强 | 同时校验 `data-playing`、图标 class、`audioEngine.isPlaying` 三个独立状态 |
| EQ Bars & Turntable Paused State Synchronized | `:68-75` | ✅ 强 | 暂停前后状态对比，含 class 同步 |
| Next Track Switching | `:84-87` | ✅ 强 | 断言标题**变化** |
| Theme Switcher & LocalStorage Persistence | `:97-104` | ✅ 强 | DOM 属性 + localStorage 双写校验 |
| Accent Color Switcher | `:114-121` | ✅ 强 | CSS 变量 + localStorage 双校验 |
| Desktop Playback Mode Cycling | `:201-215` | ✅ 强 | 三态迁移序列完整 |
| Mobile EQ Web Audio Filter Preset (Bass) | `:500-510` | ✅ 强 | 直接读 `BiquadFilter.type/.gain.value`，真实音频图状态 |
| Mobile Tactile Volume Adjustment | `:546-554` | ✅ 强 | UI 百分比 + 引擎 volume 三方一致 |
| Mobile Queue Track Removal | `:482-485` | ✅ 强 | 数量严格 -1 |
| Mobile 歌手详情页 | `:740-749` | 🟠 强但脆 | 硬编码 `'周杰伦'`/`'3280 万'`（见 #24） |
| EQ Bars Present & Animated | `:65-66` | ❌ 弱 | 名字说"Animated"，只断言 `bars.length > 0`，无动画证据（#19） |
| Sidebar Nav -> 我喜欢的音乐 | `:178-181` | ❌ 弱 | 仅判 class 不含 `hidden`（#19） |
| 歌单广场分类筛选 (Lo-Fi Filter) | `:618-621` | ❌ 弱/假阳性 | 仅 `filteredCount >= 1`，筛选坏掉也通过（#20） |
| 私人FM 漫游下一首 | `:695-699` | ❌ 弱 | 仅 `nextFmTrack.length > 0`，未比对变化（#21） |
| Interactive Lyrics Seeking on Click | `:297-301` | ❌ 弱+条件式 | `if (firstLyric)` 静默跳过；判据 `!== '00:00'` 无需 seek 也成立（#22） |

**统计**：83 个断言中，**强状态校验约 40 个**（播放状态、localStorage、Web Audio 参数、数量增减、模式迁移序列），**"元素存在/可见即通过"约 30 个**，**明显弱断言或存在假阳性风险 13 个**（#19~#23 所列）。

**失败是否被静默吞掉？**
- **没有**把失败写成 PASS 的 `try/catch`。全文只有 1 处 try（`:32`）1 处 catch（`:815-817`），catch 里记的是 `recordResult('E2E Execution Crash', false, ...)`，即失败仍会 `exit 1`。这一点是好设计。
- **但有"吞掉覆盖面"的等价风险**（#17）：任一场景抛错 → 后续全部场景不执行不计入，且**没有 `testResults.length === 83` 的断言**，汇总会直接打印"Total 20 / Passed 19 / Failed 1"。
- `flutter_e2e_verify.mjs` 则**确实**用 `catch (_) {}` 把等待失败吞成了 PASS（#14）。

**硬编码坐标 / 等待时长 / 内核**
- `e2e_test.js` **无**硬编码坐标点击（全部用选择器，`mouse.click` 命中 0）——这是它优于 `flutter_e2e_verify.mjs` 的地方；但 `flutter_e2e_verify.mjs:139/149/157` 有 3 处写死坐标（#16）。
- 等待：97 处固定 `setTimeout`（300ms~4000ms），0 处 `waitForSelector/waitForFunction`，`goto` 用 `networkidle0` 且未设 timeout（#26）。
- 内核：仅 headless Chrome（`:28`），且在 `:29` 用 `--autoplay-policy=no-user-gesture-required` 绕过了真实浏览器最关键的用户手势约束（#27）。

### 2.2 浏览器依赖与 CI 行为（对应问题 2）

| 脚本 | 浏览器发现方式 | 无 Chrome 时 | CI 中的表现 |
| :--- | :--- | :--- | :--- |
| `e2e_test.js:5-9` | 死路径 Chrome → 死路径 x86 Edge | `puppeteer.launch` 抛错 → 单个 "E2E Execution Crash"，**0 个真实场景执行** | **CI 从不调用它**（#11），所以从未暴露 |
| `flutter_e2e_verify.mjs:69-84` | `CHROME_PATH`/`PUPPETEER_EXECUTABLE_PATH` 环境变量 → Linux `/usr/bin/google-chrome`、`chromium` → Windows Chrome/Edge → macOS | `browserPath` 为 undefined，**不传 `executablePath`**；因依赖是 `puppeteer-core@25`（`package.json:24`，**不含内置浏览器**），`launch()` 会以 "Could not find Chrome / no executablePath" 抛错 | ubuntu-latest runner 自带 `/usr/bin/google-chrome`，故通常能找到；但一旦找不到就在 `:97` 抛错 → `:191` catch → `allPassed=false` → `:204` `process.exit(1)`。**能"失败"，但那只是崩溃失败，不是断言失败** |

`ci.yml:44-48`：`npm ci || npm install` 后直接 `node flutter_e2e_verify.mjs`，**没有任何断言门禁**（#13/#15）。也就是说 CI 的"绿"只证明"Chrome 起来了、截图存了盘"。

### 2.3 原型"播放"真伪（对应问题 3）

**结论：两端都不是真实音频播放，是 Web Audio 振荡器合成音；`public/audio/track1-4.mp3` 完全未被使用。**

- 引擎类：`ModernSoftAudioEngine`（`index.html:1665-1836`）与 `ModernSoftMobileAudioEngine`（`mobile.html:1359-1523`）。
- 硬编码和弦表：`index.html:1676-1683` / `mobile.html:1369-1376`（CMaj7/Am7/Dm7/G7/FMaj7/Em7），每 2500ms 播一个（`:1829-1834` / `:1516-1521`）。
- 发声道：`index.html:1807` `this.ctx.createOscillator()`（`triangle`/`sine`）；`mobile.html:1494` 同构。
- 全仓 grep：`track1\|track2\|track3\|track4\|public/audio\|audio/track` → **0 命中**（仅本次审计临时脚本）；`new Audio`、`<audio`、`decodeAudioData`、`createBufferSource` 在两端 HTML → **0 命中**。
- "导入本地音频"也不出声：`index.html:3013` 写入的 `fileUrl` **全文件仅此 1 处**（无消费者）；`mobile.html:2722` 用 `Math.random()` 指向内置曲目。
- "扫描本地磁盘"是空函数：`index.html:3050-3053` 只弹 toast。

**因此以下宣称与实现不符**：
- `README.md:3` "专为全平台**高保真**体验打造"
- `index.html:893` "**Hi-Res 无损母带音频 (192kHz / 24bit)**"、`index.html:900` "SQ 超高清无损 (FLAC)"、`mobile.html:570/574` 同类，且 `index.html:893/900` 的单选**无 onchange**（纯装饰）
- `index.html:1054/1073` "高解析无损离线缓存，支持拖拽即播 / 支持 FLAC、APE、WAV、DSD、OGG 与 MP3 格式，即刻由 Web Audio 纯净声学引擎解析回放"
- `mobile.html:2661-2666` 列表里写着 `(无损离线版).flac` / `(录音室母带).flac`，但点击播放的是合成和弦
- `README.md:85` 自己描述的才是事实："通过 Web Audio API `AudioContext` 实时生成 440Hz 纯净旋律与柔和和弦打击音效"——**与 README:3/7 的"高保真"、UI 的"无损母带"直接冲突**

### 2.4 原型 vs Flutter 客户端一致性（对应问题 4）

> 说明：这里的"Flutter 客户端"指仓库当前阶段真正实现的部分。经查 `app/lib/views/` 下尚无与 Web 原型一一对应的曲库数据（无 `SONGS` 类 fixtures），因此**曲目/歌手/歌单/播放量的一致性无法与 Flutter 侧比对**；下面给出的是**两端 Web 原型之间**的偏差（这本身也是问题：`docs/ROADMAP.md`/`SPEC.md` 宣称的"零遗漏对齐矩阵"在数据层没有单一事实源）。

| 维度 | `index.html`（桌面） | `mobile.html`（移动） | 判定 |
| :--- | :--- | :--- | :--- |
| 曲名 | `Midnight City (午夜霓虹)`（`:1504`）、`慢冷 (Slow Cooling)`（`:1526`） | `Midnight City`（`:1267`）、`慢冷`（`:1284`） | ❌ 不一致 |
| 专辑 | `Golden Hour` 专辑 = `this is what ____ feels like`（`:1548`） | `Golden Hour` 专辑 = `Golden Hour`（`:1302`） | ❌ 不一致 |
| 歌词 | `晴天` 12 行，时间轴 0/5/12/19/27/35/42/49/56/65/73/82/90（`:1486-1500`） | `晴天` 9 行，时间轴 0/6/14/22/30/40/48/58/68（`:1253-1263`），且 `Re So So Si Do Si La So La Si Si Si Si La Si La So` 被截断为 `Re So So Si Do Si La So La Si` | ❌ 不一致 |
| 光晕 | `glow.c1/c2/c3` 三色（`:1485`） | 仅 `c1/c2` 两色（`:1252`） | ❌ 不一致 |
| 歌手阵容 | 周杰伦 / Taylor Swift / 告五人 / The Weeknd / 梁静茹 / M83（`:1653-1660`） | 周杰伦 / The Weeknd / M83 / ODEsza / Mellow / Daft Punk（`:2510-2563`） | ❌ 仅 3 人重合 |
| 歌手粉丝数 | 周杰伦 `1,290万 粉丝`（`:1654`）、The Weeknd `2,400万`（`:1657`）、M83 `320万`（`:1659`） | 周杰伦 `3280 万`（`:2513`）、The Weeknd `2840 万`（`:2522`）、M83 `890 万`（`:2531`） | ❌ **同一歌手两套数据**，且格式不一致（千分位+紧贴"万" vs 无千分位+空格） |
| 字段命名 | `fans` | `followers` | ❌ 命名不统一 |
| EQ 预设数值 | bass `120Hz +9dB`（`:1712-1715`） | bass `200Hz +6.0dB`（`:1410-1413`） | ❌ 两端音色不同（#47） |

**自相矛盾的实证**：`e2e_test.js:747` 断言移动端歌手详情为 `'3280 万'`，而桌面端同页面 `index.html:1123` 写死 `1,290万 粉丝 · 5,420,100 月度听众` —— 同一次 E2E 运行同时"验证通过"了两套互斥的数据。

### 2.5 `server.js` 安全验证：实测命令与原始输出（对应问题 5）

**被测服务与说明**：`server.js` 因 #10 无法直接运行，故**逐字节复制**为 `.probe_server.cjs`（内容与 `server.js` 完全相同，仅扩展名改为 `.cjs` 以强制 CommonJS；因此 `__dirname` 仍为工程根目录，行为与设计意图一致）。审计结束后已删除该文件。

```powershell
# 启动（等价于 server.js 的设计意图）
PS> Copy-Item server.js .probe_server.cjs -Force
PS> node .probe_server.cjs
Server running at http://0.0.0.0:8088/          # ← 输出即证明绑定 0.0.0.0（server.js:88）

# 对照组：文档命令本身是坏的
PS> node server.js
ReferenceError: require is not defined in ES module scope, you can use import instead
This file is being treated as an ES module because it has a '.js' extension and
'E:\code\AI\vibCoding\mellow-music-playerpackage.json' contains "type": "module".
[exit code: 1]
```

以下请求全部由**原始 TCP socket** 直接发送请求行（不经任何客户端 URL 规范化），每例都在**全新启动的服务进程**上执行，并随后用 `GET /index.html` 探测服务是否存活。

#### (a) 路径穿越 / 敏感文件（实测原始响应）

```
# 先在工程根目录之外放置取证文件：E:\code\AI\vibCoding\qa_canary_secret.txt
# 内容: TOP-SECRET-CANARY-OUTSIDE-PROJECT-ROOT

=== A. GET /../qa_canary_secret.txt  (dotdot 逃逸出工程根目录)
  RESP   : HTTP/1.1 200 OK
  HEADERS: Access-Control-Allow-Origin: * | Access-Control-Allow-Methods: GET, OPTIONS | Access-Control-Allow-Headers: Range, Content-Type | Content-Length: 39 | Content-Type: application/octet-stream | Accept-Ranges: bytes
  BODY   : TOP-SECRET-CANARY-OUTSIDE-PROJECT-ROOT
  SERVER ALIVE AFTER: true

=== C. GET /..%5cqa_canary_secret.txt  (URL 编码反斜杠; Windows 下  是分隔符)
  RESP   : HTTP/1.1 200 OK
  HEADERS: ... Content-Length: 39 | Content-Type: application/octet-stream ...
  BODY   : TOP-SECRET-CANARY-OUTSIDE-PROJECT-ROOT

=== D. GET /%2e%2e/qa_canary_secret.txt  (编码点)
  RESP   : HTTP/1.1 200 OK
  BODY   : TOP-SECRET-CANARY-OUTSIDE-PROJECT-ROOT

=== B. GET /..%2fqa_canary_secret.txt  (编码正斜杠)
  RESP   : HTTP/1.1 404 Not Found          # decodeURI 保留 %2F，故未解码；非安全性，属 #3 的连带现象

=== 2. GET /.git/config  (隐藏 VCS 文件)
  RESP   : HTTP/1.1 200 OK
  HEADERS: Access-Control-Allow-Origin: * | ... | Content-Length: 309 | Content-Type: application/octet-stream | ...
  BODY   : [core] / repositoryformatversion = 0 / filemode = false / bare = false / logallrefupdates = true / symlinks = false / ignorecase = true / [remote "origin"] / url = https://github.com/Kline-x/mellow-music-player.git

=== 17. GET /node_modules/puppeteer-core/package.json
  RESP   : HTTP/1.1 200 OK
  HEADERS: Content-Length: 4068 | Content-Type: application/json
  BODY   : { / "name": "puppeteer-core", / "version": "25.11.0", / "description": "A high-level API to control headless Chrome over

=== 19. GET /e2e_test.js  (测试源码)
  RESP   : HTTP/1.1 200 OK
  HEADERS: Content-Length: 45999 | Content-Type: application/javascript; charset=utf-8
  BODY   : import puppeteer from 'puppeteer-core'; / import path from 'path'; / import fs from 'fs'; / const CHROME_PATH = "C:\Program Program

=== 3. GET /package.json
  RESP   : HTTP/1.1 200 OK / HEADERS: Content-Length: 587 | Content-Type: application/json

=== 4. GET /../package.json  (raw dotdot)
  RESP   : HTTP/1.1 200 OK / HEADERS: Content-Length: 587
  # 说明：path.join(BASE_DIR,'/../package.json') 指向父目录（不存在），随即走 public/ 回退分支
  #       path.join(BASE_DIR,'public','/../package.json') 中 '..' 抵消了 'public'，最终命中工程根目录的 package.json。

=== 18. GET /../  (父目录)
  RESP   : HTTP/1.1 404 Not Found            # 无目录列表（stats.isFile() 为 false），此项无泄露
```

**结论**：`server.js` **不是**"仅能读 public/"的静态服务——它可读出工程根目录之外的任意同盘文件，且默认 CORS 全开。

#### (b) Range 处理（实测；★ = 服务进程被杀）

```
=== 10. Range: bytes=0-99  （正常）
  RESP   : HTTP/1.1 206 Partial Content
  HEADERS: Content-Range: bytes 0-99/8945229 | Content-Length: 100 | Content-Type: audio/mpeg | Accept-Ranges: bytes

=== 14. Range: bytes=0-999999999  （end 越界，未裁剪）
  RESP   : HTTP/1.1 206 Partial Content
  HEADERS: Content-Range: bytes 0-999999999/8945229 | Content-Length: 1000000000   ← 声称 10 亿字节，实际仅 8,945,229
  SERVER ALIVE AFTER: true

=== 15. Range: bytes=0-9,20-29  （多段被静默降级）
  RESP   : HTTP/1.1 206 Partial Content
  HEADERS: Content-Range: bytes 0-9/8945229 | Content-Length: 10            ← 忽略第二段，不返回 multipart

★ 11. Range: bytes=99999999-  （start > EOF）
  RESP   : [SOCKET ERROR] read ECONNRESET
  SERVER ALIVE AFTER: false
  CRASH  : RangeError [ERR_OUT_OF_RANGE]: The value of "start" is out of range.
           It must be <= "end" (here: 8945228). Received 99999999
               at new ReadStream (node:internal/fs/streams:220:13)
               at Object.createReadStream (node:fs:3178:10)
               at E:\code\AI\vibCoding\mellow-music-player.probe_server.cjs:68:29   ← = server.js:68

★ 12. Range: bytes=abc-  （parseInt → NaN）
  RESP   : [SOCKET ERROR] read ECONNRESET
  SERVER ALIVE AFTER: false
  CRASH  : RangeError [ERR_OUT_OF_RANGE]: The value of "start" is out of range.
           It must be an integer. Received NaN

★ 13. Range: bytes=-500  （标准后缀式，parseInt('') → NaN）
  RESP   : [SOCKET ERROR] read ECONNRESET
  SERVER ALIVE AFTER: false

★ 15b. Range: bytes=100-50  （start > end）
  RESP   : [SOCKET ERROR] read ECONNRESET
  SERVER ALIVE AFTER: false
  CRASH  : RangeError [ERR_OUT_OF_RANGE]  at node:internal/fs/streams:220
```

#### (c) 其他健壮性（实测）

```
★ 21. GET /%00.html  （空字节；decodeURI 后进入 fs）
  RESP   : [SOCKET ERROR] read ECONNRESET
  SERVER ALIVE AFTER: false
  CRASH  : TypeError [ERR_INVALID_ARG_VALUE]: The argument 'path' must be a string,
           Uint8Array, or URL without null bytes.
           Received 'E:\code\AI\vibCoding\mellow-music-player\\\x00.html'

★ 22. GET /%ZZ  （畸形百分号编码）
  RESP   : [SOCKET ERROR] read ECONNRESET
  SERVER ALIVE AFTER: false
  CRASH  : URIError: URI malformed
               at E:....probe_server.cjs:35        ← = server.js:35

=== 16. POST /   （方法未白名单）
  RESP   : HTTP/1.1 200 OK
  HEADERS: Content-Length: 157153 | Content-Type: text/html; charset=utf-8
  BODY   : <!DOCTYPE html> ...                    ← POST 被当作 GET，返回完整页面

=== 20. HEAD /
  RESP   : HTTP/1.1 200 OK
  HEADERS: Content-Length: 157153
  （原始 socket 收满 157153 字节的 body）           ← HEAD 语义未实现

=== 23. OPTIONS /  （CORS 预检）
  RESP   : HTTP/1.1 200 OK
  HEADERS: Access-Control-Allow-Origin: * | Access-Control-Allow-Methods: GET, OPTIONS |
           Access-Control-Allow-Headers: Range, Content-Type | Transfer-Encoding: chunked

=== 崩溃后再次请求
  RESP   : [SOCKET ERROR] connect ECONNREFUSED 127.0.0.1:8088
```

**`server.js` 健壮性总评**：`fs.stat` 回调内无 try/catch；`fileStream` 无 `'error'` 监听；handler 顶层（`decodeURI`、`fs.existsSync`）无保护；无 `process.on('uncaughtException')`。**共实测 6 条可直接终止进程的 payload**（Range×4、`%00`、`%ZZ`）。

### 2.6 代码质量（对应问题 6）

- **单文件体量（更正任务描述中的"300KB"）**：`index.html` = 3,255 行 / 157,153 B（≈153 KB），`mobile.html` = 2,926 行 / 144,927 B（≈142 KB），**两者合计 ≈295 KB**；不存在单个 300 KB 文件。相较之下 `server.js` 仅 90 行。
- **内嵌 asset**：`index.html` 的 `<style>` = 48-482 行（435 行）、`mobile.html` 的 `<style>` = 37-238 行（202 行）；`index.html` 有 2 个 `<script>`（`:19` 配置、`:1474` 主逻辑）。
- **双端重复**：`mobile.html` 中 **210 行长度 >40 字符的代码在 `index.html` 中逐字出现**（音频引擎整套、和弦表、`SONGS` 结构、localStorage 读写、toast 组件）。这是 #30（导入不出声）、#47（EQ 参数三套）等不一致的结构性根因。
- **缓存**：`server.js` 无 `Cache-Control/ETag/Last-Modified`（#40）；两端 150 KB HTML 无压缩、无指纹、无构建产物；Tailwind 走 CDN 运行时 JIT（#32），首屏存在 FOUC 风险。
- **console/调试/TODO**：`debugger` 0 处；真实 TODO/FIXME 0 处（`mobile.html:320` 是 remixicon 类名误报）；`console.*` 仅 2 处（`index.html:1703`、`mobile.html:1391`），但都在 `catch` 里静默降级（#45）。—**此项整体良好**。
- **其他**：无 CSP/无 `X-Content-Type-Options`；大量内联 `onclick="..."` 与字符串拼接 `innerHTML`（`index.html:2578-2586` 等，存在注入面，虽当前数据为本地常量）。

### 2.7 `public/` 存证与 README 引用一致性（对应问题 7）

```
$ 遍历 README.md 中所有 public/*.png 引用并实测 Test-Path
public/e2e_desktop_verified.png          exists=True
public/e2e_mobile_verified.png           exists=True
public/showcase_desktop_dark.png         exists=False   ← README:18 引用，缺失
public/showcase_desktop_lyrics.png       exists=False   ← README:22 引用，缺失
public/showcase_mobile_artist.png        exists=True
public/showcase_mobile_eq.png            exists=True
public/showcase_mobile_fm.png            exists=True
public/showcase_mobile_local.png         exists=True
```

- **README 引用但缺失**：`public/showcase_desktop_dark.png`（README:18）、`public/showcase_desktop_lyrics.png`（README:22）→ GitHub 上显示为坏图。
- **`public/` 实际内容**：11 张 PNG + `audio/track1-4.mp3`（34.5 MB，全仓零引用，#31）。
- **截图可生成性**：`e2e_test.js` 只生成 `e2e_desktop_verified.png`(`:325`)、`e2e_mobile_verified.png`(`:779`)、`showcase_mobile_fm.png`(`:786`)、`showcase_mobile_artist.png`(`:795`)、`showcase_mobile_local.png`(`:802`)、`showcase_mobile_eq.png`(`:811`)；**无法生成缺失的两张**（#34）。
- **存证含金量**：`e2e_flutter_desktop_*.png` 与 `e2e_flutter_mobile_verified.png` 5 张由**零断言**的 `flutter_e2e_verify.mjs` 产出（#13/#15），**即使在 404 页面上也会生成**，因此不能作为功能证据。
- **.qa/shots/** 下有 70+ 张历史 QA 截图与 `.qa/__pycache__/qa.cpython-36.pyc`（Python 3.6 字节码）被留在仓库中，未进 `.gitignore`。

### 2.8 `design_tokens.css` 与 `tokens.dart` 数值一致性（对应问题 8）

> `design_tokens.css` 被两端原型引用（`index.html:17`、`mobile.html:17`），`tokens.dart` 自述"映射 design_tokens.css"（`tokens.dart:20`）。

| Token 语义 | `design_tokens.css` | `app/lib/design_system/tokens.dart` | 一致 |
| :--- | :--- | :--- | :--- |
| 亮色画布 | `:16` `#F5F7FB` | `:23` `0xFFF5F7FB` | ✅ |
| 亮色卡片 | `:18` `#FFFFFF` | `:24` `0xFFFFFFFF` | ✅ |
| 亮色凹槽 | `:20` `#E8EEF5` | `:26` `0xFFEBF0F8` | ❌ |
| 亮色主文本 | `:24` `#1E293B`（Slate 800） | `:29` `0xFF0F172A`（Slate 900） | ❌ |
| 亮色次文本 | `:25` `#64748B`（Slate 500） | `:30` `0xFF475569`（Slate 600） | ❌ |
| 亮色弱文本 | `:26` `#94A3B8` | `:31` `0xFF94A3B8` | ✅ |
| 强调色 | `:30` `#10B981` | `:9` emerald `0xFF10B981` | ✅ |
| 暗色画布 | `:91` `#0D1117` | `:34` `0xFF0D1117` | ✅ |
| 暗色 subtle / surface | `:92` `#161B22` / `:93` `#1C2128` | `:35` `cardDark #161B22` / `:36` `cardMutedDark #1C2128` | ❌ 角色调换 |
| 暗色凹槽 | `:95` `#13171E` | `:37` `0xFF0B0E14` | ❌ |
| 暗色边框 | `:109` `rgba(240,246,252,0.08)` | `:38/39` `#30363D` / `#21262D`（实色） | ❌ |
| 圆角刻度 | `:151-156` `9999/28/24/18/12/14` | `:58-65` `8/12/16/20/24/28/32/9999` | ❌ 值域互不覆盖 |
| 阴影（亮） | `:45-48` `0 2px 8px -1px rgba(112,144,176,.08)` + `inset 0 1px 0 rgba(255,255,255,.9)` | `:80-93` `0 4px 20px -2px #0F172A@5%` + `0 2px 6px -1px #0F172A@3%`，无 inset | ❌ 颜色/几何/内高光全不同 |
| 阴影（暗） | `:113-116` `…rgba(0,0,0,.35/.2)` + inset | `:96-109` `…black@20%/12%`，无 inset | ❌ |
| 阴影层级 | 5 级（flat/raised/dock/recessed/convex/pressed，`:45-75`） | 3 类（card/floatingPill/recessed，`:80-164`），**无 convex/pressed** | ❌ |

**特别指出**：README:40 把"顶部搭配超细微白高光内边 `inset 0 1px 0 rgba(255,255,255,0.9)`"作为设计系统三大核心之一，但 Flutter 的 `BoxShadow` 不支持 inset，`tokens.dart` 也**没有任何等价实现**（无 `foregroundDecoration`/渐变模拟）——该规范在 Flutter 端目前不可达。

---

## 3. 修复优先级建议（给工程团队）

**P0（本周，安全 + 可用性）**
1. `server.js`：Range 严格解析 + 416；`try/catch` 包裹 `fs.stat` 回调、`decodeURI`、`existsSync`；fileStream 加 `'error'`；进程级兜底（#1/#3/#4）。
2. `server.js`：`path.resolve` 前缀白名单 + `.git`/`node_modules`/点文件黑名单（#2/#7）。
3. `server.js`：CORS 白名单化、监听改 `127.0.0.1`（#5/#6）。
4. `package.json`/`server.js`：修 `"type":"module"` 与 `require` 冲突，恢复"一键启动"（#10）。

**P1（两周，测试可信度）**
5. `flutter_e2e_verify.mjs`：删空 catch、加真实断言、404 页判失败、选择器替代坐标（#13/#14/#15/#16）。
6. `e2e_test.js`：per-scenario 隔离 + `length===83` 门禁 + 多候选浏览器发现 + `pretest` 自起服务 + 弱断言升级（#17/#19~#23/#26/#28）。
7. `ci.yml`：把 `e2e_test.js` 纳入门禁，badge 换 workflow status（#11）。

**P2（一个月，真实性 + 一致性）**
8. 明确"原型音频"定位：要么接真实 `<audio>`+`track*.mp3` 并让 `fileUrl` 真正播放，要么移除"无损/母带/Hi-Res"全部文案（#29/#30/#31/#47）。
9. 建立设计 token 单一事实源（`tokens.css` → 生成 `tokens.dart`），补 inset 高光与 convex/pressed（#35~#38）。
10. 抽共享 `data.js`（两端同一份 `SONGS/ARTISTS`）+ 拆 `index.html`/`mobile.html`（#39/#2.4）。
11. 补 `showcase_desktop_dark.png`/`showcase_desktop_lyrics.png`，`public/audio` 与 `.qa/` 纳入 `.gitignore`（#33/#34/#31）。
