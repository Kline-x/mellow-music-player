# LX（落雪）自定义源机制对照参考

本文档回答三件事：

1. 官方 LX 的自定义源（user api）脚本机制到底是什么（以真实源码为准，不靠记忆）；
2. 我们 app/lib/core/sources/lx_*.dart 与之逐条对照后，哪些一致、哪些缺失、哪些是我们主动扩展；
3. 官方是否提供可捆绑的真实脚本（结论：没有，附证据与合规原因）。

本轮已按对照结果修复的**确定性缺失**见第 10 节；修复后 flutter analyze 为 No issues found，flutter test 全绿（详见第 13 节）。

## 1. 证据来源

| 仓库 | 本地克隆 | commit | 权威文件 |
| --- | --- | --- | --- |
| lyswhut/lx-music-desktop | /tmp/lx-desktop | ad95d5091c9ed689fa72b5e5c849df65f5a679ce (2026-09-19) | src/main/modules/userApi/**、FAQ.md 第 400-566 行 |
| lyswhut/lx-music-mobile | /tmp/lx-mobile | fb8480728d875fa5e0da25eebd3a26bb71723aae (2026-09-19) | android/app/src/main/assets/script/user-api-preload.js、src/core/init/userApi/index.ts |

桌面端脚本运行在 Electron 渲染进程（contextIsolation=true、nodeIntegration=false），由 src/main/modules/userApi/renderer/preload.js:192-347 用 contextBridge.exposeInMainWorld('lx', ...) 暴露 API；
移动端脚本运行在原生 JS 引擎，由 android/app/src/main/assets/script/user-api-preload.js:3 的 globalThis.lx_setup(key, id, name, description, version, author, homepage, rawScript) 注入并在 :446-525 组装 globalThis.lx。

官方行为文档：lx-music-desktop/FAQ.md:400-566（自定义源脚本编写说明、自定义源信息、window.lx.*）；移动端 FAQ.md:3 已把文档迁到 https://lyswhut.github.io/lx-music-doc/mobile/faq。

我们这边的实现文件：

- app/lib/core/sources/lx_script_engine.dart（JS 运行时、LxScriptContract 契约解析、LX Polyfill 引导脚本）
- app/lib/core/sources/lx_script_sandbox.dart（驱动、引擎、持久化、聚合、降级）
- app/lib/core/sources/lx_source_model.dart（元数据/曲目/结果模型）
- app/lib/core/sources/online_music_service.dart（三源聚合搜索接线）
- app/lib/core/audio/audio_player_service.dart（lx: 曲目真实取流接线）

## 2. 脚本加载方式对照

| 环节 | 官方 | 我们 | 判定 |
| --- | --- | --- | --- |
| 运行环境 | 桌面：Electron 渲染进程 + contextBridge；移动：原生引擎 + 预置 preload | flutter_js（macOS/iOS 走 JavaScriptCore，其余走 QuickJS），运行时懒加载（lx_script_engine.dart:1229 FlutterJsExecutor.start） | 一致（等价能力，不同运行时） |
| 注入方式 | 桌面 preload 先于脚本执行；移动 lx_setup 注入 | 先求值 buildLxBootstrap() 引导脚本，再求值用户脚本（lx_script_engine.dart:1270、:1280） | 一致 |
| 全局对象 | 桌面 window.lx；移动 globalThis.lx | globalThis.lx，并补 window/self 别名（lx_script_engine.dart:1812） | 本轮修复：原先只有 globalThis.lx，官方 FAQ 示例写的是 window.lx |
| console | 桌面/移动由引擎自带 | 统一转发给宿主（lx_script_engine.dart:1814-1840；宿主记录见 :1450 emitLog） | 本轮补齐（原先运行环境可能没有 console，脚本会直接抛错） |
| 脚本来源 | 本地文件 / 在线 URL，用户自行导入 | installFromFile(:510) / installFromUrl(:547)，与桌面对应 | 一致 |
| 在线导入上限 | 移动端 9MB（ScriptImportOnline.tsx:93-99） | 9MB（lx_script_sandbox.dart:567-573） | 本轮补齐 |
| 重复内容导入 | 拒绝（desktop src/main/modules/userApi/utils.ts:113-119） | 拒绝（lx_script_sandbox.dart:482-491） | 本轮补齐 |
| 订阅脚本压缩存储 | 桌面把脚本 gzip+base64 存为 gz_ 前缀（utils.ts:90-109） | 直接存原文 JSON（LxSourceStore :303-341） | 差异（不影响功能；桌面另有压缩存储实现） |

## 3. 脚本元数据字段对照

官方解析：desktop src/main/modules/userApi/utils.ts:53-89。要求文件**开头**是块注释（正则 /^\/\*[\S|\s]+?\*\//），字段行正则 /^\s?\*\s?@(\w+)\s(.+)$/，
支持字段与长度上限：name 24、description 36、author 56、homepage 1024、version 36，超长截断并以 ... 结尾（utils.ts:73-77）；name 缺失时用 user_api_<本地时间>。

我们：app/lib/core/sources/lx_source_model.dart:144 长度上限表、:163 fromScriptHeader。

| 项 | 官方 | 我们（修复后） | 判定 |
| --- | --- | --- | --- |
| 必须有开头注释块 | 是，否则报错「无效的自定义源文件」 | 是，否则抛 LxSourceException（lx_source_model.dart:166-171） | 本轮修复（原先在全文任意位置搜索 @name，会接受官方拒绝的 JS） |
| 字段行正则 | 逐行匹配开头注释块 | 同（:152） | 一致 |
| 长度上限/截断 | 24/36/56/1024/36 | 同（:144、:177-180） | 一致 |
| 支持字段 | name/description/author/homepage/version | 同（不再解析非官方的 @id） | 本轮对齐 |
| name 缺失兜底 | user_api_<本地时间> | user_api_<epoch 毫秒>（:183-185） | 一致语义（时间型兜底） |
| version/description/author 缺失 | 空字符串 | 空字符串（:193-195） | 本轮对齐（原先是 1.0.0/中文兜底文案） |
| currentScriptInfo | name/description/version/author/homepage/rawScript（preload.js:317-324；移动端由 lx_setup 参数传入） | 同，由 metadata 注入引导脚本（lx_script_engine.dart:1188-1196、:1229-1265、:2160） | 本轮修复（原先恒为 {}） |

注意：官方 FAQ.md:504-512 仍把 inited 载荷写成 {status, sources, openDevTools}，但当前 preload.js:128-167 已把 status 校验注释掉、总是按 sources 构建结果。我们同样不读 status（LxScriptContract.parseInited 只读 sources/openDevTools），与当前官方实现一致。

## 4. 事件契约对照

官方事件名（完全一致）：desktop rendererEvent/name.js:1-17 定义 IPC 名 userApi_init/initEnv/request/response/openDevTools/showUpdateAlert/getProxy/proxyUpdate；暴露给脚本的只有三个（preload.js:19-23，移动端 :143-147）：

~~~js
EVENT_NAMES = { request: 'request', inited: 'inited', updateAlert: 'updateAlert' }
~~~

| 事件 | 官方 | 我们 | 判定 |
| --- | --- | --- | --- |
| inited | 脚本初始化完成上报；载荷 sources[kw/kg/tx/wy/mg/local] = {type:'music', actions:[...], qualitys:[...]}（preload.js:128-167）；只允许一次，重复调用 Promise reject 'Script is inited'（:248） | 同（引导脚本 lxSend :2051-2078；被 LxScriptHost.emit 收集 :1457，LxScriptContract.parseInited :1137 解析） | 一致；重复调用拒绝为本轮补齐 |
| request | on(EVENT_NAMES.request, handler)，入参 {source, action, info}，handler **必须返回 Promise**（preload.js:72、FAQ.md:447-457、:511） | 同（dispatchRequest :2107-2119 传入 {source, action, info}；invoke 等待 Promise 落定 :1771） | 一致 |
| action 取值 | musicUrl / lyric / pic（preload.js:76-103；移动端 :223-250） | 同，另有 search/leaderboards/playlists 扩展（见第 9 节） | 一致 + 扩展 |
| musicUrl 返回 | 字符串 URL，必须匹配 /^https?:/ 且长度 <= 2048，否则判失败（preload.js:78） | parseMusicUrl 接受字符串或 {url, headers}（:986） | 一致 + 扩展；我们**未**强校验 https 前缀（脚本返回 http 也不会被拒） |
| lyric 返回 | {lyric, tlyric, rlyric, lxlyric}，lyric 必须是 string、长度 <= 51200，其余 <= 5120/8192，否则判失败（preload.js:57-66） | parseLyric 接受字符串或对象，字段为空则视为无歌词返回 null（:1005） | 语义一致，未做长度上限校验（宽松） |
| pic 返回 | 字符串 URL，/^https?:/ 且 <= 2048（preload.js:96） | parsePic 接受字符串或 {url}（:1039） | 一致（同样未强校验协议头） |
| updateAlert | 载荷 {log, updateUrl}，log 必填、<=1024，updateUrl <=1024 且必须是 http(s)，每次运行只允许一次（preload.js:253-256、:169-179） | 引导脚本同样只允许一次（:2065-2069），载荷原样经 LxScriptHost.updateAlert 记录（:1457） | 一致（未做 log 长度/URL 校验） |

官方支持的上游源与能力矩阵（preload.js:28-45，移动端 :152-169）：

- allSources = [kw, kg, tx, wy, mg, local]
- supportActions：kw/kg/tx/wy/mg = [musicUrl]；xm = [musicUrl]；local = [musicUrl, lyric, pic]
- supportQualitys：kw/kg/tx/wy/mg = [128k, 320k, flac, flac24bit]；local = []

我们对 inited 声明的源不做白名单过滤与能力收敛（LxScriptContract.parseInited 原样保留脚本声明），这是**有意的宽松**：官方会按上表裁剪 actions/qualitys，而我们希望把脚本真实声明如实呈现，并额外支持 search 扩展。此项已在第 11 节列出。

## 5. lx.on / lx.send 对照

| 方法 | 官方 | 我们 | 判定 |
| --- | --- | --- | --- |
| lx.on(eventName, handler) | 仅支持 request，其余 eventName 返回 Promise.reject('The event is not supported: ...')（preload.js:263-272） | 同（:2035-2049） | 本轮修复（原先任意事件名都接受、且返回同步函数） |
| lx.send(eventName, data) | 返回 Promise；inited 只能发一次（重复 reject 'Script is inited'），updateAlert 只能发一次，未知事件 reject（preload.js:243-262） | 同（:2051-2078） | 本轮修复（原先返回 true、无次数与未知事件校验） |
| on 回调返回值 | 必须是 Promise，官方 .then 链直接消费（preload.js:72） | invoke 等待 Promise 落定，非 Promise 值也按已完成处理（:2131-2144） | 一致（我们更宽松） |

## 6. lx.request 对照

官方签名与选项（FAQ.md:541-553；desktop preload.js:194-242；mobile :448-483）：

- lx.request(url, options, callback)，options 支持 method / headers / body / form / formData / timeout（移动端另有 binary）
- callback 入参为 (err, resp, body)；resp 含 statusCode / statusMessage / headers / bytes / raw / body（桌面），移动端无 bytes/raw
- 返回一个可调用的取消函数（调用即 abort）
- timeout 上限 60000ms，默认 60000ms

我们：LxHttpRequest.fromOptions (lx_script_engine.dart:64-140)、引导脚本 lxRequest (:2073-2090)、宿主 http 桥 (LxScriptHost.callAsync :1519-1540)。

| 选项 | 官方 | 我们 | 判定 |
| --- | --- | --- | --- |
| method | 有（默认 get） | 有（默认 GET，:60） | 一致 |
| headers | 有 | 有（:61-67） | 一致 |
| body | 有 | 有（:71-72） | 一致 |
| form | 有（urlencoded） | 有（:73-84，自动补 Content-Type） | 一致 |
| formData | 有（multipart/form-data） | 有，真实 RFC 2388 编码（:85-101、:128-166）；二进制值支持 {type:'Buffer',data:[...]} | 本轮修复（原先直接抛「暂不支持」） |
| timeout | 有，钳制到 <=60000，默认 60000 | 有，脚本值 >0 时采用，否则用宿主默认 15s（:103-107） | 差异：我们默认 15s 而非 60s，且未钳制到 60000 上限 |
| 取消 | 返回取消函数，真实 abort | 返回的取消函数只置 cancelled 标记，**不会真正中断在途请求**（:2087-2091） | 已知差异（第 11 节） |
| callback 三参 | callback.call(this, err, resp, body) | callback(null, resp, resp.body) / callback(err, null, null)（:2081-2086） | 一致（未绑定 this，脚本几乎不依赖） |
| resp 字段 | statusCode/statusMessage/headers/bytes/raw/body（body 尝试 JSON.parse） | statusCode/statusMessage/headers/body/raw（原始字节 LxBuffer），未做 JSON.parse（:224-239） | 差异：官方桌面会把 body 尝试 JSON 化；脚本普遍自己 JSON.parse(resp.body)，影响很小 |

## 7. lx.utils.* 能力清单对照

官方桌面（preload.js:273-316）与移动端（:351-425）的并集，及 FAQ.md:555-566 的公开承诺：

| 能力 | 官方桌面 | 官方移动 | 我们 | 判定 |
| --- | --- | --- | --- | --- |
| crypto.aesEncrypt(buffer, mode, key, iv) | 有（Node createCipheriv，支持 aes-128/192/256-cbc/ecb） | 有（仅 aes-128-cbc 与 aes-128-ecb） | 有（自实现 FIPS-197 AES，支持 128/192/256 的 cbc/ecb，lx_script_engine.dart:258-594） | 一致 + 扩展 |
| crypto.aesDecrypt | 无 | 无 | 有（lx_script_engine.dart:2004） | 扩展 |
| crypto.rsaEncrypt(buffer, key) | 有（publicEncrypt RSA_NO_PADDING，128 字节左补零） | 有（RSA/ECB/NoPadding） | 有，真实 BigInt modPow + PEM/DER 解析（LxRsaCipher :606-747，宿主桥 :1483-1488） | 本轮修复（原先直接抛「暂不支持」） |
| crypto.randomBytes(size) | 有（Node randomBytes，返回 Buffer） | 有（Math.random 填充 Uint8Array） | 有（宿主 :1646-1651、JS 侧 :1993-1999） | 一致（我们用密码学安全随机，更强） |
| crypto.md5(str) | 有，UTF-8 后 hex | 有（encodeURIComponent 后交原生） | 有（宿主 :1469-1473；JS 侧 md5 :1983、digestOf :1973-1980） | 一致 |
| crypto.sha1/sha256/hmac | 无 | 无 | 有（lx_script_engine.dart:1984-1996） | 扩展 |
| buffer.from(...) | 有 | 有（utf8/base64/hex/Array） | 有（lx_script_engine.dart:1941-1954，含 utf8/base64/hex/latin1/utf16le） | 一致 + 扩展 |
| buffer.bufToString(buf, format) | 有 | 有 | 有（lx_script_engine.dart:1955） | 一致 |
| Buffer.alloc/concat/byteLength/slice/subarray/equals/isBuffer | 无（脚本用 Node 全局 Buffer？不，桌面无 nodeIntegration） | 无 | 有（:1956-1971、LxBuffer 原型 :1910-1938） | 扩展 |
| zlib.inflate / zlib.deflate | 有（needle/zlib，返回 Promise） | **注释掉未实现**（:426-444） | 有（真实 dart:io zlib，JS 侧 :2023-2037、宿主 :1539-1544） | 与桌面一致 |
| currentScriptInfo | 有 | 有 | 有（:2160，本轮修复） | 本轮修复 |
| version | '2.0.0' | '2.0.0' | '2.0.0'（:2158，本轮由数字 2 修正） | 本轮修复 |
| env | 'desktop' | 'mobile' | 按平台推导 desktop/mobile（:1226、buildLxBootstrap :1786-1801） | 本轮修复（原先恒为 desktop） |

## 8. 启停持久化与可用性测试对照

| 项 | 官方 | 我们 | 判定 |
| --- | --- | --- | --- |
| 持久化介质 | 桌面 electron-store（STORE_NAMES.USER_API，utils.ts:9-16）；移动端本地存储（src/utils/data.ts:506-520） | SharedPreferences 键 mellow_lx_sources_v1（lx_script_sandbox.dart:303-341），StorageService 未初始化时退化为内存 | 一致（介质不同） |
| 启动恢复 | getUserApis 读取并做版本迁移（utils.ts:18-51） | loadInstalled 幂等恢复，不启动 JS 运行时（:590-607） | 一致（无迁移逻辑） |
| 启用/停用 | 官方是「单选当前源」（apiSource 值）+ 内置源 disabled 列表；用户源没有独立启用位 | 每个驱动有 enabled 并持久化（:453-468），支持多源并发聚合 | 扩展（官方单选无法支撑三源聚合） |
| 可用性测试 | 加载脚本 → 等 init 结果（preload handleInit → main 发 user_api_init/status），失败则 userApi.status=false + message='initing'（desktop src/renderer/core/apiSource.ts:14-40；mobile src/core/init/userApi/index.ts:74-191） | testSource(id) 真实执行一次加载+search 并输出 LxSourceTestReport（:838-871）；testSourceHealth(id) 只探活（:873-876） | 一致语义 + 扩展（我们额外区分「脚本未声明 search」而不是把它当失败，:841-843） |
| 失败可见性 | user_api_status 事件 + 错误弹窗 | LxSourceTestReport.error / 引擎 onEvent 流 | 一致 |

官方把脚本事件映射为宿主 API 的地方（可作为 action 语义的第二证据）：mobile src/core/init/userApi/index.ts:85-173（musicUrl/lyric/pic 的 info.musicInfo 与 type 构造）。

## 9. 我们相对官方的扩展（非缺失，需明确标注）

1. **search 事件**：官方自定义源协议没有 search（FAQ.md:511 明确「目前只有 musicUrl」）。我们额外支持 globalThis[action] 函数式派发与 request 事件回退（dispatchRequest :2107-2119、actionAliases :2092-2101），用于三源聚合搜索。若脚本未实现 search，testSource 会如实说明「未声明 search」而不是假成功（lx_script_sandbox.dart:841-843），聚合时该源只是不出结果。
2. **leaderboards / playlists 系列**：官方无对应 action，属我方扩展（actionAliases :2092-2101）。
3. **多源启用 + 并发聚合**：LxSourceEngine.searchAggregated（:634-686）按注册顺序稳定保留去重结果（本轮修正了并发完成顺序导致的非确定性）。
4. **aesDecrypt / sha1 / sha256 / hmac / Node Buffer 便捷方法**：官方未承诺，属超集。
5. **引擎内三源聚合接线**：OnlineMusicService.searchOnlineTracks（online_music_service.dart:87-127）并发网易云+iTunes+已启用 LX 脚本，LX 结果标注 lx:<脚本源标识>（:133-144），统一 dedupeByTitleArtist（:147-155）；未安装脚本时 hasInstalledSources 为 false，完全不调用 LX（:103-109），不报错不伪造。
6. **播放期真实取流**：audio_player_service.dart:643-700 对 source 以 lx: 开头的曲目调用 LxSourceEngine.resolveMusicUrlWithFallback 解析真实直链，成功才交给后端播放；失败走诚实提示且不播放。

## 10. 本轮修复的确定性缺失（含证据与测试）

| # | 缺失 | 修复位置 | 对照的官方坐标 | 测试 |
| --- | --- | --- | --- | --- |
| 1 | window.lx 不存在（官方 FAQ 示例写 window.lx） | lx_script_engine.dart:1812 补 window/self 别名 | FAQ.md:414、desktop preload.js:192 | lx_engine_test.dart 组 (d)：脚本改用 window.lx；probeApi.windowLxIsLx |
| 2 | lx.version 是数字 2，官方是 '2.0.0' | :1786-1801、:2158 | desktop preload.js:325；mobile :523 | 组 (d) probeApi.version；组 (e) bootstrap 文本 |
| 3 | lx.currentScriptInfo 恒为空对象 | :1188 LxJsExecutor.start 增加 metadata；:1229-1265 组装 scriptInfo；:2160 | desktop preload.js:317-324；mobile :515-522 | 组 (d) probeApi.scriptInfo（name/version/author/rawScript） |
| 4 | lx.env 恒为 desktop | :1226 按平台推导；:1786-1801 | desktop preload.js:326 'desktop'；mobile :524 'mobile' | 组 (d) probeApi.env == 'desktop'；组 (e) bootstrap 文本 mobile |
| 5 | crypto.rsaEncrypt 直接抛错 | LxRsaCipher :606-747、宿主桥 :1483-1488、JS 侧 :2012-2019 | desktop preload.js:279-282；mobile :364-370 | 组 (e) 与 openssl 实测向量逐字节一致；组 (d) 经真实 JS 运行时再验 |
| 6 | lx.request formData 直接抛「暂不支持」 | LxHttpRequest :85-166 真实 multipart 编码 + 传输层二进制体 | desktop preload.js:206-210；FAQ.md:548 | 组 (e) 编码与 MockClient 真实发送；组 (d) 本机 HTTP 服务端回显请求体 |
| 7 | 元数据头解析过于宽松（全文搜索 @name，无长度上限） | lx_source_model.dart:144-201 | desktop utils.ts:61-89 | 组 (e)：无注释块被拒、后置块注释被拒、长度截断、未知标签忽略 |
| 8 | lx.send 返回 true、可重复 inited、未知事件不报错 | :2051-2078 | desktop preload.js:243-262 | 组 (d) probeSendTwice / probeUnknownEvent |
| 9 | lx.on 接受任意事件名 | :2035-2049 | desktop preload.js:263-272 | 组 (d) probeOnUnknownEvent |
| 10 | 没有 console（运行环境缺 console 时脚本会抛错） | :1814-1840 JS 侧转发 + :1450 宿主记录 | 官方运行环境自带 console（脚本普遍使用） | 组 (d) 脚本内 console.log + host.receivedLogs 断言 |
| 11 | 重复导入相同内容未拒绝 | lx_script_sandbox.dart:482-491 | desktop utils.ts:113-119 | 组 (e) 第二次 installScript 抛错 |
| 12 | 订阅脚本无体积上限 | :567-573 | mobile ScriptImportOnline.tsx:93-99（9MB） | 组 (e) 9MB+ 被拒 |
| 13 | 聚合结果顺序取决于完成时序（非确定） | :634-660 按注册顺序占位 | 不适用（官方无聚合） | lx_search_aggregation_test.dart：慢源先注册仍被保留 |
| 14 | LxPlatformId.mellow「润音官方预设源」是自造音源标识 | lx_source_model.dart:62-92 删除，改用官方 local；空 source 显示为「未知音源」 | desktop preload.js:28 allSources | 全量测试回归 |

## 11. 尚未对齐 / 已知差异（诚实列出，未修）

1. **取消请求未真正 abort**：引导脚本的取消函数只置标记（:2087-2091）；官方返回 needle/AbortController 的真实取消。影响：取消后仍会占用连接，但不会产生错误结果。
2. **lx.request 默认超时 15s、未钳制 60000 上限**：官方默认 60000 且 Math.min(timeout, 60000)（preload.js:211）。
3. **resp.body 不做 JSON.parse**：官方桌面会把 body 尝试 JSON.parse（preload.js:219-223）；我们给脚本原始字符串 + raw LxBuffer。脚本普遍自行 JSON.parse，故未修。
4. **musicUrl/lyric/pic 返回值未做官方的长度/协议校验**：官方会拒绝非 http(s) 或超长返回值（preload.js:76-103），我们只在解析层取 URL/歌词。脚本返回非法值时我们会把错误留到播放阶段（诚实提示），而不是在事件层拒绝。
5. **inited 的 sources 不做能力收敛**：官方按 supportActions/supportQualitys 裁剪（preload.js:142-156），我们原样保留脚本声明。原因：需要如实呈现脚本声明并支持 search 扩展。
6. **updateAlert 载荷未做长度/URL 校验**。
7. **updateAlert 的 UI 呈现**：官方会弹窗引导更新；我们只记录载荷（LxScriptHost.updateAlert :1457），未接 UI。
8. **setTimeout/clearTimeout**：官方移动端在 preload 里覆盖（user-api-preload.js:527-528）并接入取消请求；我们依赖运行环境自带的实现，未做沙箱级替换。
9. **移动端脚本签名 lx_setup(...)**：官方移动端通过原生注入 7 个元数据参数；我们用统一的 buildLxBootstrap(scriptInfo:)。对脚本可见的 API 面一致，但宿主实现不同。
10. **脚本压缩存储**：桌面 gzip+base64（gz_ 前缀，utils.ts:90-109），我们存原文。
11. **xm 源**：官方 supportActions 里有 xm（preload.js:43）但 allSources 不含，属官方遗留；我们没有引入 xm 常量。

## 12. 官方是否提供可捆绑的真实脚本

**结论：没有。截至上表 commit，两个官方仓库都不包含任何可用的真实音源脚本，官方也不分发此类脚本。** 我们没有捆绑任何脚本，也没有自造脚本充数。证据：

| 证据 | 位置 | 说明 |
| --- | --- | --- |
| 桌面内置用户源列表为空 | src/main/modules/userApi/config/index.ts:2 | export const userApis: LX.UserApi.UserApiInfoFull[] = [] |
| 移动端用户源列表只读本地存储 | src/utils/data.ts:506-520 | getUserApiList = await getData(userApiPrefix) ?? []，没有任何内置默认项 |
| 内置音源实现全部注释停用 | src/renderer/utils/musicSdk/api-source.js:15-19 | allApi 为空对象，test_kw/test_tx 等全部被注释 |
| 官方只发布 API 说明与不可用示例 | FAQ.md:400-473 | 示例脚本请求的是 http://xxx，没有真实取流逻辑，无法作为可用源 |
| 导入入口只接受用户自备脚本 | 桌面 importApi（utils.ts:110-129）、移动 action.ts（ScriptImportOnline.tsx:86-99） | 全部是「用户给文件/URL」路径 |
| 官方合规立场 | README.md:127（第 1.2 条，桌面与移动同文） | 本项目自身没有获取任何音频数据的能力，音源来自用户选择的「自定义源」返回的在线链接 |

合规原因（如实说明）：

1. 官方明确把「是否/如何取得音频数据」交给用户自选的第三方源，自身不提供也不校验（README.md:127）；
2. 一个「真实可用」的 LX 脚本本质上是把第三方音乐平台的取流接口封装起来，随应用分发会直接触及这些平台的服务条款与著作权问题；
3. 因此官方仓库仅分发**协议实现**（preload.js）与**文档**（FAQ.md），不分发任何指向真实音源的脚本；我们采用同样的边界：只实现协议、只支持用户自行导入本地文件或订阅 URL（app/lib/core/sources/lx_script_sandbox.dart:510-577），仓库内不存在任何内置脚本、预设脚本 URL 或示例音源（已核对 lx_script_sandbox.dart 无 http(s) 常量、pubspec.yaml 未声明 lx 相关 assets）。

若后续要提供「可一键安装的源」，只能由用户自行提供 URL 或文件；应用侧不会内置、也不会代替用户下载来源不明的脚本。

## 13. 验证方式与结果

对照过程中可复现的命令（在 app/ 目录）：

~~~bash
cd app
flutter analyze                 # No issues found!
flutter test                    # 全绿
flutter test test/lx_engine_test.dart test/lx_search_aggregation_test.dart -r expanded
~~~

本轮相关测试文件：

- app/test/lx_engine_test.dart：组 (a) 空状态诚实性、(b) 契约解析与 AES 向量、(c) 网络失败真实传播、(d) 真实 flutter_js 端到端（window.lx / version / env / currentScriptInfo / console / RSA 向量 / multipart 上真机 HTTP / send+on 语义）、(e) 与官方对齐（bootstrap 文本、RSA 向量、formData 编码、导入行为、元数据头）。
- app/test/lx_search_aggregation_test.dart：未安装脚本静默跳过、lx:<源标识> 标注与原始曲目缓存、单源失败隔离、整体异常隔离、去重优先级、播放接线（成功播放 / 失败不播放走诚实提示）、聚合顺序确定性。
