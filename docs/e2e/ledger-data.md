# E2E 数据真实性缺陷账本 (Data Authenticity Ledger)

> **修复进度汇总请见 [`docs/e2e/STATUS.md`](STATUS.md)**（2026-09-23 校准：哪些已修、哪些未修、证据是什么）。


> 覆盖范围：`app/lib/**`（28 个 Dart 文件） + `server.cjs` + 顶层 `index.html` / `mobile.html` / `e2e_test.js`
> 格式依据：`docs/e2e/FORMAT.md`（编号 DATA-001 起，三位递增）
> 取证轮次：本轮（工作区快照）。**所有行号均来自本轮逐行读取，未引用记忆或历史审计报告的行号。**
> 已实测确认的基线（引用 `docs/e2e/FORMAT.md` §4，本轮未重复验证）：`flutter analyze` 0 issue；`flutter test` 90/90；`flutter build macos --debug` 成功；实体音频驱动存在（`app/lib/core/audio/player_backend.dart:22`）；本地 `shared_preferences` 落盘真实存在。

**严重度统计**：P0 = 6 条（DATA-001~006），P1 = 8 条（DATA-007~014，其中 DATA-010 的**当前态**为 P1、若被接入则为 P0），P2 = 5 条（DATA-015~019），**合计 19 条**。
**类别分布**：数据造假 9 / 文案不诚实 2 / 工程卫生 5 / 与文档不符 3（DATA-010、DATA-011 属跨类项，按主类别各计一次）。

---

## 一、读前必读：本轮新增的两条「一票否决」事实

这两条决定了本轮其余全部数据链路在此仓库当前状态下的**实际可达性**，因此放在最前。

1. **所有 macOS Debug 产物在操作系统层面被禁止出网。** 本轮 `open app/build/macos/Build/Products/Debug/app.app` 后读取统一日志，内核明确记录：`kernel: (Sandbox) Sandbox: app(21002) deny(1) network-outbound remote:*:443`（并伴随 `13 duplicate reports`）。即：**用于 E2E 验收的 Debug 产物，其 Unsplash 封面、SoundHelix 音频、网易云搜索/歌词/歌单请求全部在 OS 层被拒绝**，与代码写得好不好无关。见 DATA-001。
2. **`stream.mellowmusic.io` / `cdn.<x>.music.net` / `custom-cdn.<x>.com` 是彻底不存在的域名。** 本机 resolver 被 fake-IP 代理劫持（`host`/`dig` 均返回 `198.18.0.x`，该网段是 Clash/Surge 类工具的 fake-IP 保留段），因此**不能**用本机 resolver 判真假；本轮改用 Cloudflare DoH 权威解析，三者均 `Status: 3`（NXDOMAIN），且父域 `mellowmusic.io` 本身 NXDOMAIN。对照组 `unsplash.com` → Status 0 + 真实 A 记录。见 DATA-010。

---

## 二、缺陷条目

### [DATA-001] macOS Debug 产物缺少 network.client 沙箱豁免，全部真实数据链路在 OS 层被拒绝

- **编号**：DATA-001
- **严重度**：P0
- **类别**：数据造假（真实数据无法进入）
- **用户可见现象**：在 macOS Debug 产物（= 本仓库所有 E2E 验收脚本实际运行的那一个产物）中，所有封面显示为灰色音符占位块，点击任意内置曲目不出声且不做任何网络请求，快捷搜索永远只回内置示例曲目，导入真实网易云歌单永远失败。用户看到的现象与「离线」完全一致，但状态栏/文案没有任何「无网络权限」的提示。
- **复现步骤**：
  1. `codesign -d --entitlements - app/build/macos/Build/Products/Debug/app.app`，输出仅含 `app-sandbox` / `cs.allow-jit` / `get-task-allow` / `network.server`，**无 network.client**。
  2. `open app/build/macos/Build/Products/Debug/app.app`，等待 8 秒。
  3. `log show --last 1m --predicate 'eventMessage CONTAINS "network-outbound"'` → 得到 `kernel: (Sandbox) Sandbox: app(<pid>) deny(1) network-outbound remote:*:443`（本轮实测 PID 20348 与 21002 两次启动均复现，每进程至少 13 条重复报告）。
- **代码证据**：
  - `app/macos/Runner/DebugProfile.entitlements:1-12` — 全文 12 行，键只有 `:5 app-sandbox`、`:7 cs.allow-jit`、`:9 network.server`：
    `<key>com.apple.security.app-sandbox</key><true/>` / `<key>com.apple.security.cs.allow-jit</key><true/>` / `<key>com.apple.security.network.server</key><true/>`
  - `app/macos/Runner/Release.entitlements:5-10` — Release 已补 `network.client`(7-8) 与 `network.server`(9-10)，说明「Release 要联网」是已知结论，但 Debug 被遗漏。
  - 对照 `docs/PC_E2E_FIX_PLAN.md:844`：`- [ ] Android release APK 含 INTERNET 权限；macOS release 含 network.client（P0-05/P0-06）` —— 该条**只覆盖 release**，Debug 的缺失未被任何清单覆盖。
  - `docs/PC_E2E_FIX_PLAN.md:934` 附录 A 的口径本身就是错的：`app/macos/Runner/Release.entitlements 共 8 行，仅 app-sandbox`，本轮实测该文件为 **12 行且已含 network.client**（改动后附录未同步）。
- **真实/内置/编造**：真实网络链路（本应真实）在 Debug 产物中被 OS 阻断 → 功能上等价于「死链」，且**无任何诚实失败反馈**。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:820-823`（发布前检查清单 A 要求「点击播放能听到声音」「后台播放生效」）与 `docs/SPEC.md:460-503`（要求以真实产物执行 8 大链路闭环）在此产物上均无法达成。
- **建议修复**：`app/macos/Runner/DebugProfile.entitlements` 增加 `<key>com.apple.security.network.client</key><true/>`（与 Release 对齐）。若不希望 Debug 联网，则必须在 Dart 侧捕获 `SocketException`/`ClientException` 并在 UI 上给出「当前构建未授予网络权限」的明确提示，禁止静默回落。
- **可验收标准**：① `codesign -d --entitlements - app/build/macos/Build/Products/Debug/app.app | grep -c network.client` → `1`；② 启动 Debug 产物后 `log show --last 30s --predicate 'eventMessage CONTAINS "network-outbound"' | grep -c 'deny'` → `0`；③ 断网/联网两种情况下，封面均能在 3 秒内从占位块变为真实图片。
- **状态**：待修复

---

### [DATA-002] 内置 33 首曲目的标题/歌手/专辑/时长为编造元数据，音频全部指向 SoundHelix 的 16 个演示 mp3，33 条曲目共用 16 个音频

- **编号**：DATA-002
- **严重度**：P0
- **类别**：数据造假
- **用户可见现象**：曲库、发现页、榜单、歌手页、电台、歌单广场里看到的每一首歌都以真实艺人名义出现（巫娜《云水禅心》、周杰伦《夜的第七章》、Beyond《海阔天空》……），但实际播放的是完全无关的 SoundHelix 程序生成 MIDI 演示曲；并且不同曲目会播放出**同一段音频**（33 条曲目只有 16 个音频文件）。
- **复现步骤**：
  1. 对 `app/lib/core/audio/track_model.dart` 统计：`grep -c 'SoundHelix-Song-'` → **33**；去重后 `SoundHelix-Song-1..16` → **16**（本轮 python 正则统计）。
  2. 播放 `track-1`（《云水禅心 / 巫娜》）与 `artist-by-4`（《巡光之旅 / 伯远》）——两者 `audioUrl` 分属 Song-2 与 Song-1；再播放 `artist-by-3`（《冬日之光 / 伯远》）→ 又回到 Song-1。
  3. 对比 `artist-jay-2`《晴天》(Song-7) 与 `chart-new-1`《瞬》(Song-7)：不同歌曲、同一文件。
- **代码证据**：
  - `app/lib/core/audio/track_model.dart:110-111`：`/// 预置高保真曲目池 (与原型 83 项 E2E 验证曲目 100% 对齐)` / `final List<Track> mockPresetTracks = [`
  - `:114-120`：`title: '云水禅心', artist: '巫娜', album: '天禅 · 琴筝和鸣', ... source: 'preset-flac', audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'`
  - `:141-142`（晚风告白/Song-2）、`:159-162`（海阔天空/Song-3）、`:179-184`（夜的第七章/Song-4）、`:199-204`（City of Stars/Song-5）、`:217-222`（起风了/Song-6）
  - `:256-310`（mockJayChouTracks：晴天 Song-7、花海 Song-8、爱在西元前 Song-9）、`:313-367`（mockBeyondTracks：Song-10/11/12）、`:370-419`（mockWuNaTracks：Song-13/14/15）、`:422-470`（mockBoYuanTracks：Song-16/1/2）
  - `:525-725`（四大榜单 15 首，Song-3..Song-13 复用）、`:769-863`（4 个电台节目，Song-14/15/16/1 复用）
  - `:67`：`this.source = 'lx-mock'`（默认音源标识本身就是 mock 命名）
- **真实/内置/编造**：音频字节来自**真实可访问**的第三方演示文件（见三节探测 #1/#2：HTTP 200 / content-type audio/mpeg / 8,945,229 bytes）；但**曲目元数据 100% 编造**，且「一条元数据 ↔ 一个音频」的对应关系是虚构的。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:866` 明确写「不要把 6 首 mock 曲目扩到 30 首或 200 首……数据是假的，扩充只会掩盖问题」。当前已扩到 33 首，**该建议未被遵守**。`docs/ROADMAP.md:9` 声明「页面能渲染不等于能用，以 `docs/e2e/` 账本为唯一权威」，与 UI 上的具体呈现冲突。
- **建议修复**：三选一，**必须显式落地其中之一**：
  (a) 把 33 条元数据全部改为中立化命名（`演示音轨 01`…`演示音轨 16`），UI 顶部标注「内置示例音轨（SoundHelix 演示曲）」，并在「关于」页给出署名（见 DATA-003）；
  (b) 保留曲名但把 `source` 改为 `'demo'`、`coverUrl` 换成同色系程序生成占位图，禁止挂真实艺人名；
  (c) 只保留 4 首并把仓库中已有的 `public/audio/track1-4.mp3`（真实音频，见 DATA-017）移入 `app/assets/audio/`。
- **可验收标准**：`grep -rn "soundhelix" app/lib | wc -l` → `0`；且 `grep -rnE "artist: '(巫娜|周杰伦|Beyond|伯远)'" app/lib | wc -l` → `0`（即在元数据层彻底切断「真实艺人名 + 无关音频」的组合）。
- **状态**：待修复

---

### [DATA-003] 使用 SoundHelix 演示音频未满足其署名要求，且把音频错误归属给真实艺人（版权/合规风险）

- **编号**：DATA-003
- **严重度**：P0
- **类别**：与文档不符（合规）
- **用户可见现象**：用户点开《海阔天空》听到的是一段程序生成的 MIDI 演示曲，而界面标注歌手为 Beyond、专辑为《乐与怒》、来源标签为 `preset-flac`（无损）；「关于」页、设置页、README 全文检索不到任何 SoundHelix 署名。这既是内容欺骗，也是许可违约。
- **复现步骤**：
  1. `curl -sS https://www.soundhelix.com/audio-examples` → 页面原文：`You may use these audio examples in any way you like, but you must give credit to SoundHelix and the artist of the respective song.`
  2. `grep -rin 'soundhelix' --include='*.dart' --include='*.html' --include='*.md' --include='*.yaml' .`（排除 track_model.dart 的 URL 与 docs 审计报告）→ 生产 UI/README/设置页 **0 处署名**。
  3. 对照 `track_model.dart:141` 的 `source: 'preset-flac'` 与 `:162` 的 `audioUrl`，二者在 UI 上被当作「无损音源」与「Beyond 的作品」呈现。
- **代码证据**：
  - `app/lib/core/audio/track_model.dart:159-162`（`title: '海阔天空', artist: 'Beyond', album: '乐与怒', source: 'preset-flac', audioUrl: '.../SoundHelix-Song-3.mp3'`）
  - `app/lib/core/audio/track_model.dart:119-120`、`:141-142`、`:161-162`、`:183-184`、`:203-204`、`:221-222`（6 组「真实艺人名 / 专辑名 + preset-flac/preset-320k 标签 + SoundHelix URL」）
  - `app/lib/core/audio/track_model.dart:122-132`、`:144-152`、`:164-174`、`:186-194`、`:206-212`、`:224-232`（33 首共 100+ 行手写歌词，其中《云水禅心》为器乐曲本无词，仍编了 9 行带时间戳的「歌词」）
- **真实/内置/编造**：音频源真实且许可允许商用/任意用途，**但附条件（必须署名）**；代码满足了「使用」，未满足「署名」，同时附加了错误归属 → 双重合规问题。
- **原型/文档依据**：根 `README.md` 与 `app/README.md` 均未出现 SoundHelix；`docs/PC_E2E_FIX_PLAN.md:888` 建议「把仓库里已有的 `public/audio/track1-4.mp3` 移入 assets 作为演示曲目」—— 该路径可在**不引入第三方署名义务**的前提下解决本问题，但未执行。
- **建议修复**：① 优先改为 DATA-002 的方案 (c)：改用仓库内自带、无署名义务的 `public/audio/track1-4.mp3`。② 若坚持保留 SoundHelix，则必须在「设置 → 关于」与 README 增加 `音频示例来源：SoundHelix (https://www.soundhelix.com/)，遵循其许可要求署名`，并把曲名/歌手改为中立名称（不得再挂 Beyond/周杰伦/巫娜/伯远）。③ 在仓库根增加 `THIRD_PARTY_NOTICES.md`，逐条列出 Unsplash / SoundHelix 的来源与许可。④ 法务口径：**不得**把第三方演示音频标注为「无损母带」「高保真」并冠以他人作品名。
- **可验收标准**：`test -f THIRD_PARTY_NOTICES.md && grep -qi soundhelix THIRD_PARTY_NOTICES.md` 为真（方案 a 时改为断言 `public/audio/track1-4.mp3` 的字节被 `app/assets/` 引用）；且 `grep -rn "SoundHelix" app/lib | grep -v 'audioUrl'` 在方案 a 后为 0。
- **状态**：待修复

---

### [DATA-004] 四大榜单 / 歌手粉丝数 / 歌单播放量 / 电台在听人数 / 更新频率全部为硬编码编造常量

- **编号**：DATA-004
- **严重度**：P0
- **类别**：数据造假
- **用户可见现象**：榜单卡片写着「每日09:00更新 · 100首」「每周四更新 · 200首」「全平台亿级收听总榜单」，歌手卡片写着「周杰伦 粉丝 3890.2万」「Beyond 1240.8万」，歌单卡片写着「184.2万」播放，电台写着「24.8万在听」。这些数字没有任何数据源，且与实际内容量严重不符（每榜实际 5 首，声称 100/200/50）。
- **复现步骤**：
  1. 打开桌面端「官方巅峰排行榜」→ 4 张卡片显示的更新频率与曲目数：`每日09:00更新 · 100首` / `每周四更新 · 200首` / `每日更新 · 100首` / `每周五更新 · 50首`；点进去每榜实际 5 首。
  2. 打开「热门歌手库」→ 4 张卡片的粉丝数；再点进任一歌手详情 → 粉丝数换成了另一个值（见 `track_model.dart:515` 的 `orElse` 分支 `fans: '128.5万'`）。
  3. 打开「声音电台专区」→ 4 个节目的 `24.8万在听` / `58.2万在听` / `36.5万在听` / `19.4万在听`。
  4. 对应代码全部是方法体内 `final charts = [...]` 局部常量数组，无任何 HTTP 调用。
- **代码证据**：
  - 榜单：`app/lib/views/desktop/desktop_views.dart:414-447`（`'update': '每日09:00更新 · 100首'`(418)、`'desc': '近24小时全网播放量暴涨'`(417)、`'desc': '全平台亿级收听总榜单'`(425)、`'每周四更新 · 200首'`(426)、`'每周五更新 · 50首'`(442)）；移动端同源 `app/lib/views/mobile/mobile_pages.dart:335`
  - 榜单兜底：`desktop_views.dart:493` `final chartTracks = toplistTracksMap[chartTitle] ?? mockPresetTracks;`、`mobile_pages.dart:335` `?? mockPresetTracks`（榜单缺数据时把内置示例当榜单展示）
  - 粉丝数：`app/lib/core/audio/track_model.dart:477`（'86.4万'）、`:485`（'3890.2万'）、`:493`（'1240.8万'）、`:501`（'512.6万'）、`:515`（'128.5万'）；渲染于 `desktop_views.dart:711`、`mobile_pages.dart:478`
  - 歌手简介里的统计：`track_model.dart:478`（'累计播放量突破 3000 万'）、`:486`（'累计播放量破 100 亿 · 金曲奖历史大满贯得主'）、`:494`、`:516`（'累计播放破亿'）
  - 歌单播放量：`track_model.dart:894/903/912/921/930/939/951`（184.2万/92.6万/63.8万/78.5万/45.1万/31.2万/52.7万）
  - 电台在听：`track_model.dart:775/799/822/845`
  - 推荐歌单网格的**另一套**播放量：`desktop_views.dart:152`（'48.6万播放 · 巫娜 / 常静'）、`:159`（'129.4万播放'）、`:166`（'98.2万播放'）、`:173`（'45.1万播放'）—— 与 `mockSquarePlaylists` 里的数字**不一致**（同一「华语经典」歌单在两处分别是 129.4万 与 184.2万）。
- **真实/内置/编造**：纯硬编码编造。无 HTTP、无本地统计、无落盘计数来源。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:827`（C-02）已把「更新文案」判为假；`docs/PC_E2E_FIX_PLAN.md:833-835` 检查项要求「同一歌手在不同页面的粉丝数一致，或不显示」「4 个排行榜返回的曲目集合互不相同」。**本轮对 4 个榜单的 id 集合做了核对：4 组 id 互不相交（P1-01 已成立）**，但粉丝数不一致与播放量不一致**仍然存在**。`docs/ROADMAP.md:65-96` 把上述页面标为「✅ 1:1 对齐」，与数据真实性无关，属误导性状态标记。
- **建议修复**：① 立即删除所有无来源的「更新频率 / 曲目数 / 粉丝数 / 播放量 / 在听数」字符串，改为不显示或显示可解释的真实值（如「本榜共 5 首（内置示例）」）；② 若保留榜单，把 `update` 文本改为由真实数据计算或整块删除；③ 统一 `desktop_views.dart:152-173` 与 `mockSquarePlaylists.playCount` 的单一数据源，禁止两套数字；④ 歌手 `fans` 字段在无来源时应从模型里删除（`ArtistProfile.fans` 强制必填是这类编造的温床）。
- **可验收标准**：`grep -rnE "(\d+(\.\d+)?万|亿|TOP100|每日09:00|每周[四五六])" app/lib/views app/lib/core/audio/track_model.dart | grep -v 'LyricLine' | wc -l` → `0`。
- **状态**：待修复

---

### [DATA-005] 15 张 Unsplash 图被复用于 76 处，且单张图同时充当互不相关的曲目封面、歌单封面、艺人头像与「用户本人头像」

- **编号**：DATA-005
- **严重度**：P0
- **类别**：数据造假
- **用户可见现象**：打开 App，右上角「我的头像」是一位蓝紫打光的年轻女性；点进歌手「巫娜（古琴演奏家）」看到的是**同一张**女性照片；《云水禅心》的封面是一座**欧洲城堡**（带护城河）；《海阔天空》《光辉岁月》《十年》《安和桥》《米店》以及电台《音乐背后的人文故事》的封面是**同一个紫色 DJ 混音台**。同一张图在不同页面代表完全不同的实体。
- **复现步骤**：
  1. 本轮实测图片内容（下载后用 image 工具直接查看）：`photo-1518709268805-4e9042af9f23` → 400x605 欧洲城堡照；`photo-1534528741775-53994a69daeb` → 400x500 蓝紫打光女性肖像；`photo-1470225620780-dba8ba36b745` → 400x267 紫色 DJ 打碟台特写。
  2. 复用计数（`grep -rho 'images.unsplash.com/photo-[0-9a-z-]*' app/lib index.html mobile.html | sort | uniq -c | sort -rn`）：`photo-1511671782779…` ×23、`photo-1514525253161…` ×22、`photo-1470225620780…` ×21、`photo-1518709268805…` ×15、`photo-1534528741775…` ×10。
  3. 在 `app/lib` 内 `unsplash` 命中 76 处，去重后 `track_model.dart` 只用了 15 张不同的照片。
- **代码证据**：
  - 城堡照被当作《云水禅心》封面：`app/lib/core/audio/track_model.dart:117`；同一 URL 又出现在 `:377`（《七弦清音》）、`:714`（《南山南》）、`:774` 与 `:781`（电台《深夜治愈故事馆》封面 + 单集封面）、`:911`（歌单「空山新雨 · 禅意清音集」）、`app/lib/views/desktop/desktop_views.dart:116`（发现页 Hero 大图）、`:153`（推荐歌单卡）。
  - 女性肖像同时充当**用户头像**与**艺人头像兜底**：`app/lib/views/mobile/mobile_tabs.dart:134` 与 `:960`（`MellowAvatar` 用户头像）、`app/lib/core/audio/track_model.dart:517`（`getArtistProfileByName` 的 `orElse` 兜底头像）。
  - DJ 台照被当作摇滚/民谣/电台封面：`track_model.dart:159`（海阔天空）、`:320`（光辉岁月）、`:589`（十年）、`:681`（安和桥）、`:821`（电台 3）、`:902`（歌单「不朽摇滚」）。
  - 在线搜索无封面时的兜底也是 Unsplash：`app/lib/core/sources/online_music_service.dart:60-61`、`:114-115`。
- **真实/内置/编造**：图片本身**真实可达**（探测 #16/#17：`HTTP 200`、`content-type: image/jpeg`、20–28 KB），但其**语义与所代表的实体完全无关**，且大面积复用 → 属「真假混杂」中的假（元数据造假）。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:801`（A-03）与 `:815-816`（B-02/B-03）已确认同一结论；`docs/PC_E2E_FIX_PLAN.md:835` 检查项「同一张图片不再充当多个互不相关的实体（封面/头像去重）」**未达成**。
- **建议修复**：① 艺人头像与用户头像必须区分：用户头像在未登录时应显示「默认字母/几何图形」而非他人照片；② 用**真实数据源自带的封面**替换 Unsplash：网易云搜索/歌单接口返回的 `album.picUrl` / `img1v1Url` 字段（实测搜索 JSON 中存在 `picId` 与 `img1v1Url`；`online_music_service.dart:60` 已优先使用 `"album.picUrl"`，应把兜底也换成程序生成的确定性占位图（按 `track.id` 哈希取色 + 首字），而不是随机 Unsplash 照片）；③ 内置示例曲目统一使用一张明确标注「示例封面」的中性图；④ 若继续使用 Unsplash，须遵守其许可并避免把图用于暗示人物身份（把真人照片标注为特定艺人是肖像权风险）。
- **可验收标准**：① 断言「同一个 `coverUrl` 最多被 1 个 `Track` 使用」；② 断言「`mockArtistsProfiles[*].avatarUrl` 与任何用户头像 URL 不相等」；③ `grep -rho 'images.unsplash.com/photo-[0-9a-z-]*' app/lib | sort | uniq -c | awk '$1>1' | wc -l` → `0`。
- **状态**：待修复

---
### [DATA-006] 网易云在线播放直链对多数曲目返回 302→404（HTML 错误页），但代码静默吞掉异常且无失败提示

- **编号**：DATA-006
- **严重度**：P0
- **类别**：数据造假（链路不可用 + 静默降级）
- **用户可见现象**：在搜索浮层输入「周杰伦」，列表能**真实**返回网易云搜索结果（有「在线音源」标签），点第 1 首后：进度条与歌词正常（歌词是真实的），但**没有声音**；只有播放器底层抛出异常时才弹一次「音频资源加载失败」。多数情况下用户只会看到「点了、在放、但没声」，无从判断原因。导入真实歌单后同样：列表名称全部真实，点进去多数曲目无法发声。
- **复现步骤**（本轮实测，含对照组）：
  1. `curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' 'https://music.163.com/song/media/outer/url?id=347230.mp3'` → `302 http://music.163.com/404`。
  2. 加 `-L` 跟随 → `HTTP 200`，但 `size_download=107191` 且为 HTML 错误页（**不是音频**）。去掉 `.mp3` 后缀同样 `302→404`，证明与后缀无关。
  3. 抽样 6 个 id：`347230 / 186016 / 299174 / 165470 / 1901371647` → 全部 `302 → http://music.163.com/404`；`1330348068` → `302` 到真实 `m701.music.126.net/.../xxx.mp3`（对照组，证明该通道**并非全死**，而是受版权/会员限制）。
  4. 带 `Origin: http://localhost:8088` 请求 `/api/search/get/web` → 响应头中**无 `access-control-allow-origin`**（Flutter Web 构建下请求必被浏览器拦截）。
- **代码证据**：
  - 直链拼接：`app/lib/core/sources/online_music_service.dart:63` `final audioUrl = 'https://music.163.com/song/media/outer/url?id=$id.mp3';`；同样写法在 `:132`。
  - 静默吞错：`:80-83` `} catch (_) { // 网络波动或超时，静默返回空，由上层触发本地降级逻辑 } return [];`；`:157-159`、`:182` 同样 `catch (_) {}`。
  - 伪造请求头：`:37-40 / :104-107 / :170-173` `'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ...'`、`'Referer': 'https://music.163.com/'`（绕过防盗链，属未授权抓取私有接口）。
  - 上层唯一提示：`app/lib/core/audio/audio_player_service.dart:293-297` `catch (e) { ... _playbackNotice = '歌曲「${track.title}」音频资源加载失败，可能需要专属授权或网络受限'; }` —— 这是全项目**唯一**一处播放失败诚实反馈，但它只在 `_backend.play()` 抛异常时触发；HTTP 302→200(HTML) 是否抛异常取决于 audio 后端实现，**未验证**。
- **真实/内置/编造**：搜索 / 歌词 / 歌单详情 API **真实且实测 HTTP 200 返回真实 JSON**；播放直链为**部分死链**（受版权限制），失败被静默吞掉。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:216`、`:611-615` 与 `docs/audit/code-review.md:434-447` 均记录过同一事实；`docs/PC_E2E_FIX_PLAN.md:596` 要求对 `online_music_service.dart:35/103/...` 做治理，**本轮核对未见治理落地**（文件内容与审计时一致）。`docs/PC_E2E_FIX_PLAN.md:896` MVP 验收⑦要求「断网时搜索给出明确的网络错误提示」，**未达成**。
- **建议修复**：① 立即消除静默：把 `catch (_)` 改为捕获后设置一个 `onlineSearchError` 状态，UI 显示「在线搜索失败：网络不可用 / 接口不可用（已回退到内置示例）」；② 播放前做一次轻量可达性判定（HEAD 或首次 GET 校验 `content-type` 是否以 `audio/` 开头），非音频则**不进入播放态**并提示「该曲目在当前音源下无授权，请使用官方客户端」；③ 移除伪造 UA/Referer，改为显式的「未授权公开接口」风险评估或整体替换为官方/授权来源（见第六节方案）；④ Flutter Web 构建下应在编译期或启动时对该能力做**显式禁用**，避免「能搜不能放」的半坏状态。
- **可验收标准**：① 构造一个返回 302→HTML 的 id，断言 UI 出现文本包含「无授权」或「加载失败」的提示且不进入 `isPlaying == true`；② 断网运行，断言搜索浮层出现网络错误文案（不是空列表，也不是内置数据）；③ 断言 `grep -c 'catch (_) {}' app/lib/core/sources/online_music_service.dart` → `0`。
- **状态**：待修复

---

### [DATA-007] 「共解析成功 N 首高保真曲目」是对不可播放结果的虚假成功宣称

- **编号**：DATA-007
- **严重度**：P1
- **类别**：文案不诚实
- **用户可见现象**：粘贴真实歌单 ID（如 3778678）后，弹窗显示「共解析成功 200 首高保真曲目」并提供「存入资料库」，用户得到一个 200 首的歌单——其中绝大多数在 DATA-006 的 302→404 通道下**无法播放**，且「高保真」这一宣称与任何实测比特率无关（接口返回的 `fee`/`rtype` 字段未被检查）。
- **复现步骤**：
  1. 打开「导入外部歌单」→ 粘贴 `3778678` → 点击解析 → 出现「共解析成功 200 首高保真曲目」。
  2. 点「存入资料库」→ 播放第 1 首 → 无声（见 DATA-006）。
  3. `grep -n '高保真' app/lib/views/common/modals.dart` → `:973`。
- **代码证据**：
  - `app/lib/views/common/modals.dart:973` `'共解析成功 ${_imported!.trackCount} 首高保真曲目',`
  - `app/lib/core/sources/online_music_service.dart:129-132`：`durationMs` 缺省写作 `240000`（4:00 兜底常量）、`audioUrl` 直接拼 `outer/url`，未校验任何可用性；`:56` 同样 `?? 240000`。
  - 无任何 `fee`/`privilege`/`playable` 字段检查：`grep -n 'fee\|privilege\|playable' app/lib/core/sources/online_music_service.dart` → 0 命中。
- **真实/内置/编造**：曲目列表真实（HTTP 200 真实 JSON），**成功文案与音质宣称编造**。
- **原型/文档依据**：`docs/PC_E2E_ACCEPTANCE_ISSUES.md:776`（S13）记录了「导入成功、写明包含 200 首完整音轨」，与本轮一致；`docs/PC_E2E_FIX_PLAN.md:826` 要求「导入数量与磁盘实际文件数一致」（对应本地导入），此处对在线导入同样适用。
- **建议修复**：把文案改为可验证的表述：`已解析 200 首曲目（其中 N 首当前可播放）`，其中 N 通过逐个 HEAD/首字节探测得到（成本高，可先只显示「可播放性未校验」）；「高保真」一词在未取得真实比特率前**必须删除**；`durationMs` 为空的曲目显示 `--:--` 而不是伪造的 4:00。
- **可验收标准**：`grep -c '高保真' app/lib/views/common/modals.dart` → `0`；且导入结果卡片必须包含「可播放」或「未校验」字样（widget 测试断言文本存在）。
- **状态**：待修复

---

### [DATA-008] 「搜索全网歌曲」实际以 6 首内置示例为底库，热搜标签本地不存在，网络失败时静默回落且无错误提示

- **编号**：DATA-008
- **严重度**：P1
- **类别**：文案不诚实
- **用户可见现象**：`Ctrl+K` 打开搜索浮层，未输入时列表里已经有 6 首歌（内置示例），热搜标签给出「周杰伦 / 告五人 / 落日飞车 / 陈奕迅 / 轻音乐 / 粤语经典」；点「告五人」或「落日飞车」→ 结果为空（底库里没有这两位），而此时**没有任何「未找到」或「网络失败」的区分**；输入关键词断网时，UI 静默停留在本地匹配结果，用户以为「全网就这些」。占位文案却写着「搜索全网歌曲、歌手、专辑」。
- **复现步骤**：
  1. `Ctrl+K` → 观察初始列表非空（6 条内置示例）。
  2. 点击热搜标签「告五人」→ 列表为空；点击「落日飞车」→ 同样为空。
  3. 断开网络后输入「周杰伦」→ 结果只剩本地匹配（0 条，因为内置曲库里没有周杰伦），无任何错误提示。
- **代码证据**：
  - 初始列表 = 内置示例：`app/lib/views/common/modals.dart:511` `_results = mockPresetTracks;`；空查询同样 `:528`。
  - 热搜标签常量：`:506` `final List<String> _hotTags = ['周杰伦', '告五人', '落日飞车', '陈奕迅', '轻音乐', '粤语经典'];`
  - 本地匹配只查内置曲库：`:534-539` `mockPresetTracks.where(...)`
  - 在线结果为空时**不做任何状态变更**（既不报错也不清空/标注）：`:548-563` —— `if (onlineSongs.isNotEmpty) { ... _results = combined; }` 没有 `else` 分支。
  - 宣称文案：`:598` `hintText: '搜索全网歌曲、歌手、专辑 (按 ESC 退出)...'`
- **真实/内置/编造**：在线搜索链路真实（网络可用时确实会返回真实结果并合并）；但**初始态与失败态用内置编造数据填充**，且不区分「无结果」与「网络失败」。
- **原型/文档依据**：`docs/SPEC.md:465`（E2E-02）声称「聚合 6 大音源结果并发返回，列表去重，关键词高亮」——实际只有 1 个网易云源（见 DATA-010 的六维音源死代码）；`docs/PC_E2E_FIX_PLAN.md:896` MVP 验收⑦「断网时搜索给出明确的网络错误提示」未达成。
- **建议修复**：① 初始列表改为**空态 + 明确文案**（「输入关键词开始搜索；离线时将只检索本地曲库」，并可显示「本地曲库 0 首」）；② 保留热搜标签时，标签应来自真实热榜接口或直接删除；③ `searchOnlineTracks` 返回值改为可区分三类结果（成功有结果 / 成功无结果 / 请求失败），UI 分别呈现「无匹配」「网络不可用（已降级为本地搜索）」；④ 把提示文案改为与实现一致的表述。
- **可验收标准**：① 断网时断言出现「网络」相关错误文案（widget 测试注入失败 backend）；② 断言初始 `_results` 为空（不被 `mockPresetTracks` 预填）；③ 断言 `_hotTags` 中每个标签都能在底库或在线结果里命中，否则不展示。
- **状态**：待修复

---

### [DATA-009] 首次启动即预置 4 首「已收藏」，伪造用户数据

- **编号**：DATA-009
- **严重度**：P1
- **类别**：数据造假
- **用户可见现象**：全新安装、从未点过任何红心的用户，打开「我的收藏」看到 4 首歌（《云水禅心》《海阔天空》《City of Stars》《起风了》）已被点亮红心；同时启动即拥有一个 6 首的播放队列。用户可能误以为这是自己的数据或账号同步来的数据。
- **复现步骤**：
  1. 删除 App 的 `shared_preferences` 存储（macOS：`~/Library/Containers/<bundle-id>/Data/Library/Preferences/`）后启动。
  2. 打开「我的收藏」→ 4 首已在列表中且红心为实心。
  3. 对应代码未读取任何远端账号，`_loadFromStorage()` 在无存档时直接保留硬编码初值。
- **代码证据**：
  - `app/lib/core/audio/audio_player_service.dart:29` `final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};`
  - `:27` `final List<Track> _playlist = List.from(mockPresetTracks);`
  - `:136-140`：仅当存档存在时才 `_favoriteIds.clear()`，无存档时保留硬编码 4 个。
  - 对照组（历史为空）：`:28` `final List<Track> _playHistory = [];` —— 历史这一项**是**空的。
- **真实/内置/编造**：纯硬编码编造的用户数据。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:825` `- [ ] 首次安装时收藏为 0 首、历史为空（P1-04/P1-05）` —— **未达成**；`docs/PC_E2E_FIX_PLAN.md:890`（D7）明确要求「删除预置收藏与冷启动假历史」。
- **建议修复**：`_favoriteIds` 初始化为 `{}`，`_playlist` 初始化为 `[]`（或在无存档时才用内置示例，并在 UI 上标注「内置示例队列」）。注意 `_playlist` 为空会影响 `currentTrack == null` 的若干 UI 分支（`desktop_scaffold.dart:510`、`mobile_scaffold.dart:97/193`、`fullscreen_lyrics_view.dart:60`、`mobile_sheets.dart:67`、`mobile_pages.dart:157` 目前都用 `currentTrack ?? mockPresetTracks[0]` 兜底），需要一并改为空态分支，否则会从「预置收藏」变成「空态崩溃」。
- **可验收标准**：`app/test/persistence_restart_test.dart` 中新增断言：全新 `SharedPreferences` 下 `player.favoriteTracks.isEmpty == true` 且 `player.playHistory.isEmpty == true`（现有测试文件已存在，属可执行断言）。
- **状态**：待修复

---

### [DATA-010] LX 音源沙箱生成 3 个不存在的域名直链，且整个 lx_script_sandbox.dart 在 app/lib 中 0 生产引用

- **编号**：DATA-010
- **严重度**：P0（若被接入）/ P1（当前，纯死代码）
- **类别**：数据造假 + 工程卫生
- **用户可见现象**：桌面端「自定义音源管理」页写着「支持扩展音源解析脚本（功能接入中）」，另一张卡片写「网易云在线开放音源 (Built-in) / 支持在线搜索与公开歌单导入解析」，但点击「在线导入音源」只弹 `自定义音源在线导入功能接入中...`。用户看不到的地方：若该引擎被接入，它解析出的音频直链全部指向不存在的域名。
- **复现步骤**：
  1. 域名真实性（**必须用外部权威解析，本机 resolver 被 fake-IP 劫持**）：
     `curl -sS -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=stream.mellowmusic.io&type=A'` → `{"Status":3, ...}`（NXDOMAIN，SOA 来自 .io TLD）；`cdn.kw.music.net` → Status 3；`custom-cdn.demo.com` → Status 3；`mellowmusic.io` → Status 3。对照组 `unsplash.com` → Status 0 + 4 条真实 A 记录。
  2. 本机 `host stream.mellowmusic.io` 会先打印 `has address 198.18.0.113` 再打印 `NXDOMAIN`——这是本地 fake-IP DNS 代理（Clash/Surge 类）的行为，**不可作为真假判据**。
  3. 生产引用：`grep -rn 'lx_script_sandbox' app/lib` → 0 命中；`grep -rn 'LxSourceEngine' app/lib` 仅命中定义处 `:727/:735`；`PlatformPresetSourceDriver`/`LxCustomScriptDriver`/`MellowPresetSourceDriver` 在 `app/lib` 内除自文件外 0 命中。唯一引用方是 `app/test/lx_source_engine_test.dart`(12 处)、`app/test/client_e2e_user_journey_test.dart`(2 处)、`app/integration_test/app_client_e2e_test.dart`(2 处)。
- **代码证据**：
  - `app/lib/core/sources/lx_script_sandbox.dart:203-205`：`// 格式化输出标准化高保真直链` / `final qTag = quality.value;` / `return 'https://stream.mellowmusic.io/${song.source}/${song.songMid}/audio_$qTag.flac';`
  - `:452`：`return 'https://cdn.$platformId.music.net/media/${targetSong.songMid}_${quality.value}.mp3';`
  - `:646`：`return 'https://custom-cdn.${metadata.id}.com/stream/${song.songMid}/${quality.value}.mp3';`
  - 编造的歌单/榜单元数据：`:241-275`（「Mellow 飙升巅峰榜 / 每日 06:00 更新 / total: 100」）、`:525-534`（`creator: '资深乐评人', playCount: 660000` —— 该播放量常量与 DATA-004 的 UI 数字又互不相同）、`:681-689`（`title: '榜首热歌', artist: '独立唱作人'` 的 dummy song）、`:616-626`（把用户**查询词本身**当曲名，`artist: '${metadata.name} 精选'`，`duration` 固定 3:45）。
  - 与 UI 的宣称矛盾：`app/lib/views/desktop/desktop_views.dart:1499` 写「支持扩展音源解析脚本（功能接入中）」，而 `:1530-1532` 的卡片把「网易云在线开放音源 (Built-in)」描述为「支持在线搜索与公开歌单导入解析」——后者确实由 `OnlineMusicService` 实现（见 DATA-006），前者则完全未接线。
- **真实/内置/编造**：**死链 + 断线死代码**。所有 URL 生成逻辑均为字符串拼接的编造域名；引擎本身不可达。
- **原型/文档依据**：`docs/SPEC.md:8` 已自我更正：`flutter_js QuickJS 音源沙箱 | ❌ 未采用；app/lib/core/sources/ 为纯 Dart 模拟实现，且无生产代码调用`；但 `docs/SPEC.md:56/57`（架构图仍列 SourceBloc/SyncBloc）、`:221-241` 仍在描述 QuickJS 沙箱规范、`docs/ROADMAP.md:128` 仍写「`getMusicUrl(songInfo, quality)`：按音质等级动态解析真实播放直链」。`docs/ROADMAP.md:74` 把音源管理页标为「✅ 深度集成」。**SPEC 内部自相矛盾**应予修正或删除对应章节。
- **建议修复**：**二选一，不要维持现状**：
  (a) **删除**：移除 `app/lib/core/sources/lx_script_sandbox.dart` 与 `lx_source_model.dart`，同步删除 `lx_source_engine_test.dart` 中依赖它的用例（约 12 处），并从 `pubspec.yaml` 移除仅供其使用的 `crypto`（见 DATA-013）。成本约 0.5 人日。
  (b) **真跑**：引入真实 JS 运行时（`flutter_js`/QuickJS），把 `getMusicUrl` 接到用户自备音源脚本；但必须先明确「脚本来源与版权责任由用户承担」并在 UI 明示，且需为每个音源实现真实域名解析。成本 3~5 人日，且**在没有合法音源的前提下不建议做**。
  **同时**：把 3 处域名生成函数标注 `@visibleForTesting` 或删除；UI 侧「在线导入音源」按钮要么接线要么从页面移除（当前是纯 SnackBar 占位）。
- **可验收标准**：方案 (a)：`test ! -f app/lib/core/sources/lx_script_sandbox.dart && grep -rn 'mellowmusic.io\|music.net/\|custom-cdn' app/lib | wc -l` → `0`。方案 (b)：新增集成测试，调用 `engine.getMusicUrl(song, AudioQuality.flac)` 后对返回 URL 执行真实 http.head 并断言 `statusCode == 200` 且 `content-type` 以 `audio/` 开头。
- **状态**：待修复

---

### [DATA-011] WebDAV 与 LAN 同步为断线死代码；同步页是占位 + 弹窗提示（半诚实）

- **编号**：DATA-011
- **严重度**：P1
- **类别**：工程卫生 + 与文档不符
- **用户可见现象**：桌面端「多端协同与云端同步中心」显示「云端端点: 未配置端点 (例如 https://dav.jianguoyun.com/dav/)」「绑定账号: 未绑定账号」「状态: 未配置」，点「从云端恢复」/上传 → 弹 `云端同步功能尚未完整接入，请勿依赖此页面备份数据`。**这一处文案是本轮发现的、全项目最诚实的降级提示之一**。但「局域网近场设备协同」区块写「局域网近场 P2P 互联功能接入中，支持设备自动发现与歌曲互传」并永远显示空态——而其背后的 `LanSyncService` 已实现真实 HTTP 扫描/投送代码，只是无任何调用方。
- **复现步骤**：
  1. 生产引用核对：`grep -rn 'WebDavSyncService' app/lib` → 仅自身定义 `webdav_sync_service.dart:160/171`；`grep -rn 'LanSyncService' app/lib` → 仅自身 `lan_sync_service.dart:411/418`；`grep -rn 'webdav_sync_service' app/lib` → **0 命中**（连 import 都没有）；`grep -rn 'sync_data_model' app/lib` → 只被上述两个死文件 import（`lan_sync_service.dart:6`、`webdav_sync_service.dart:5`）。
  2. 唯一引用方：`app/test/sync_services_test.dart`(8 处)、`app/test/client_e2e_user_journey_test.dart`(3 处)、`app/integration_test/app_client_e2e_test.dart`(3 处)。
  3. 打开同步页 → 两个区块的表现如上。
- **代码证据**：
  - `app/lib/views/desktop/desktop_views.dart:1554-1556`：`final String _syncStatusText = '未配置';` / `final String _serverUrl = '未配置端点 (例如 https://dav.jianguoyun.com/dav/)';` / `final String _username = '未绑定账号';`（三个字段都是 `final` 常量，页面永不变化 —— 但同时也没有伪造成功态，属可接受）
  - `:1558-1570`：`_triggerUpload()` / `_triggerRestore()` 只 showSnackBar，文案明确写「尚未完整接入」「请勿依赖此页面备份数据」
  - `:1807-1808`：`'局域网近场设备协同 (LAN P2P)'` / `'同一 Wi-Fi 下设备近场流转与歌单互传（功能接入中）'`
  - `:1830-1832`：`'当前未发现局域网配对设备'` / `'局域网近场 P2P 互联功能接入中...'`
  - 死代码内的**明文凭据风险残留**：`app/lib/core/sync/webdav_sync_service.dart:231` 有 `'WebDAV 账号或应用密码错误 (401)'`；`docs/PC_E2E_FIX_PLAN.md:596` 提到 `webdav_sync_service.dart:25` 的明文 `password` 字段需改为 `flutter_secure_storage` —— 本轮未在 `app/lib` 内 grep 到明文密码常量（`desktop_views.dart` 的明文账号已按阶段 0 移除，改为 `:1556` 的 `'未绑定账号'`），但**该文件仍是死代码，接线时必须先解决凭据存储**。
- **真实/内置/编造**：死代码（实现真实但无消费者）+ UI 占位（且有诚实提示）。
- **原型/文档依据**：`docs/SPEC.md:469`（E2E-06）声称「PROPFIND/PUT 全链路通畅，执行毫秒级 LWW 冲突解决，歌单数据零丢失」；`docs/SPEC.md:355` 描述「LX-Sync 100% 原生兼容」；`docs/SPEC.md:75` 声称「内置轻量 WebSocket/HTTP 同步服务器（监听 23332 端口）」。**实际：0 生产引用，端口 23332 在 app/lib 内 0 命中**。`docs/PC_E2E_FIX_PLAN.md:875` 明确给出二选一指引：「不要为已经写好但没人调用的 3319 行代码无条件保命……删除是合法且常常更优的选项」。
- **建议修复**：**二选一**：
  (a) **删除**（推荐，0.5 人日）：删除 `core/sync/` 三个文件与 `sync_services_test.dart`；把同步页与导航项移除，或改为明确的「规划中」只读说明（不含假按钮）。
  (b) **接线**（3~4 人日）：在 `StorageService` 之上增加 Repository 快照导出/导入；WebDAV 凭据改走 `flutter_secure_storage`；把 `_syncStatusText/_serverUrl/_username` 从 `final` 常量改为真实状态机字段；`LanSyncService.scanSubnet` 必须在真实 Wi-Fi 网段上产出真实设备或诚实空态。
  **无论哪条路**，都必须处理 `docs/SPEC.md:469` 的「零丢失」承诺——在未接线前该承诺必须删除，否则是发布级误导。
- **可验收标准**：方案 (a)：`test ! -d app/lib/core/sync` 为真，且 `grep -rn 'WebDAV\|LAN P2P\|LX-Sync' app/lib | wc -l` → `0`。方案 (b)：新增集成测试，把快照 PUT 到真实 WebDAV 后重新 GET 并断言字段逐一相等（禁止条件断言 `if (result != null) expect(...)`）；LAN 部分断言「在无同网段设备时返回空列表且 UI 显示『未发现设备』」。
- **状态**：待修复

---

### [DATA-012] 均衡器是纯 UI 假动作：toLibmpvFilterString() 无生产消费者，音频后端不支持滤波

- **编号**：DATA-012
- **严重度**：P1
- **类别**：数据造假（能力宣称不实）
- **用户可见现象**：设置里打开「声学 10 频段硬件均衡器」，拖动 31Hz–16kHz 十个滑杆、切换「澎湃低音 / 通透人声 / 温润爵士 / 全景声场」，界面即时反馈、值也落盘，但**声音完全不变**。用户会怀疑自己的耳机或音量。
- **复现步骤**：
  1. 播放任意内置曲目（在有网络的机器上）→ 打开 EQ → 把 31Hz 拉到 +12dB → 听感无任何变化。
  2. `grep -rn 'toLibmpvFilterString' app` → 生产代码 0 命中，仅 `app/test/mellow_music_comprehensive_test.dart:130`、`app/test/client_e2e_user_journey_test.dart:156`、`app/integration_test/app_client_e2e_test.dart:156` 三处测试调用。
  3. `grep -rn 'firequalizer' app/lib` → 仅 `equalizer_manager.dart:81/84`（字符串构造处）。
- **代码证据**：
  - `app/lib/core/audio/equalizer_manager.dart:16` `/// 声学 10 频段硬件均衡器管理服务`
  - `:81-92` `/// 生成 libmpv firequalizer 滤镜参数字符串` + `String toLibmpvFilterString()`，返回形如 `firequalizer=gain='gain_interpolate(31,7.0)+...'` 的字符串 —— 该字符串在全项目**没有任何消费方**。
  - 物理音频后端为 `audioplayers`（`app/lib/core/audio/player_backend.dart:4/22`），其 API 不提供 EQ 滤镜通道；`player_backend.dart:7-19` 的抽象接口也没有任何 EQ/filter 方法。
  - UI 只写内存与通知：`app/lib/views/common/modals.dart:244` `onTap: () => eq.applyPreset(preset)`、`:274` `final gain = eq.bandGains[index]`。
- **真实/内置/编造**：UI 状态真实（ChangeNotifier + 真实 render），**音频副作用为零** → 「能用」判定为不成立。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:867` 明确写「`equalizer_manager.dart:82-92` 生成的 filter 字符串没有消费者」，并禁止在此之前做 EQ 优化。`docs/PC_E2E_FIX_PLAN.md:868` 提到「SPEC 里的 9 款 EQ 预设」与实际的 6 款存在口径差 —— 本轮核对 `equalizer_manager.dart:4-14` 确为 **6 款**（flat/bassBoost/clearVocal/warmJazz/spatial3d/custom），文档侧应改。
- **建议修复**：**二选一**：
  (a) 把 EQ 面板整体标注为「未接入音频引擎（敬请期待）」并置灰滑杆；删除 `toLibmpvFilterString` 或标注 `visibleForTesting`。成本 0.2 人日。
  (b) 真正接线：换用支持滤波的音频后端（`media_kit`（libmpv）或 `just_audio` + 平台 EQ），把 `toLibmpvFilterString()` 的输出交给播放器；这属于 `docs/PC_E2E_FIX_PLAN.md` 阶段 1 的一部分，成本含在 5~8 人日内。
- **可验收标准**：方案 (a)：`grep -rn '硬件均衡器' app/lib | wc -l` → `0` 且滑杆 `onChanged` 为 null（widget 测试断言 `Slider.onChanged == null`）。方案 (b)：新增集成测试 —— 对同一段音频分别以 flat 与 bassBoost 播放并用 `ffmpeg` 录音/频谱对比，断言 31Hz 频段能量差 > 3dB（这是「真实副作用」的硬证据）。
- **状态**：待修复

---
### [DATA-013] pubspec.yaml 12 个依赖中 7 个在 app/lib 内 0 引用；main.dart 声明的字体在 pubspec 无声明

- **编号**：DATA-013
- **严重度**：P1
- **类别**：工程卫生
- **用户可见现象**：界面文字在 macOS 上是「苹方」，在 Windows / Android / Web 上会**静默降级**为系统默认字体（因为 pubspec 未声明任何字体，也没有真正的 `google_fonts` 调用），字形与设计稿不一致；同时包体无谓增大（`dio`/`go_router`/`intl`/`path_provider`/`path`/`cupertino_icons`/`google_fonts` 均被拉入但未使用）。
- **复现步骤**：
  1. 逐个 grep（路径 `app/lib`）：
     `cupertino_icons` → 0；`google_fonts` → 0；`GoogleFonts` → 0；`go_router` → 0；`package:intl` → 0；`package:dio` → 0；`path_provider` → 0；`package:path/` → 0。
     （`package:provider` → 13 个文件，`shared_preferences` → 1，`package:http` → 3，`package:crypto` → 1（仅 `lx_script_sandbox.dart:3`，即死代码），`audioplayers` → 1（`player_backend.dart:4`）。）
  2. 在 `app/test` 与 `app/integration_test` 内再次 grep 上述 8 个包 → **全部 0 命中**，排除「只在测试里用」。
  3. 字体：`grep -n 'fontFamily' app/lib/main.dart` → `:44` 与 `:54` 均为 `'PingFang SC'`；而 `app/pubspec.yaml:66-102` 的 `flutter:` 段中 `fonts:` 全部是注释（`:84-99`），`uses-material-design: true`（`:71`）是唯一生效项。
  4. 无网络时的降级行为：**Flutter 端不存在 `google_fonts` 的任何调用**，因此「google_fonts 无网络降级」在此项目里没有发生路径；真实行为是「未知 fontFamily（PingFang SC）→ 平台默认字体」，无报错、无日志。原型端另见 DATA-019。
- **代码证据**：
  - `app/pubspec.yaml:36-47`：`cupertino_icons: ^1.0.8`, `google_fonts: ^8.2.1`, `provider: ^6.1.5+1`, `go_router: ^18.0.1`, `intl: ^0.20.3`, `shared_preferences: ^2.5.5`, `http: ^1.6.0`, `dio: ^5.11.1`, `crypto: ^3.0.7`, `path_provider: ^2.1.6`, `path: ^1.9.1`, `audioplayers: ^6.8.1`
  - `app/pubspec.yaml:71` `uses-material-design: true`；`:73-76` `# assets:` 全为注释；`:84-99` `# fonts:` 全为注释
  - `app/lib/main.dart:44`（theme）与 `:54`（darkTheme）`fontFamily: 'PingFang SC'`
  - 仅被死代码使用的依赖：`app/lib/core/sources/lx_script_sandbox.dart:3 import 'package:crypto/crypto.dart';` —— 该文件 0 生产引用（DATA-010），故 `crypto` 在生产代码中实际零使用。
- **真实/内置/编造**：真实（依赖清单与引用计数属实）。
- **原型/文档依据**：`app/pubspec.yaml:37` 声明 `google_fonts`，而 `docs/PC_E2E_FIX_PLAN.md:856`（E 组）要求「SPEC.md 中每条『已实现』的技术栈，在 pubspec.lock 或 app/lib 中能找到」——反向也成立：pubspec 里声明但代码不用的依赖应清理。`docs/PC_E2E_FIX_PLAN.md:938` 附录 A 已指出「pubspec 的 flutter 段无 fonts 配置，而 main.dart 声明 fontFamily: 'PingFang SC'」，**本轮核对该问题仍然存在**。
- **建议修复**：① 从 `dependencies` 删除 `cupertino_icons` / `google_fonts` / `go_router` / `intl` / `dio` / `path_provider` / `path`（若确认后续无计划；若有计划则分别在 SPEC 里写明落地阶段），并删除仅死代码使用的 `crypto`（与 DATA-010 联动）；② 字体二选一：在 pubspec 声明并打包开源中文字体（如 Noto Sans SC，注意体积约 10MB+），或把 `fontFamily` 改为 `null` 并使用平台默认（macOS/Windows 上都能正确显示中文），**不要**保留一个只在 Apple 平台存在的字体名；③ 若确实要用 `google_fonts`，必须在有网时下载、无网时回退，且需处理中文字体缺失（google_fonts 不含完整中文字形）。
- **可验收标准**：新增检查脚本：对 `app/pubspec.yaml` 的每个顶层 dependency 执行 `grep -rq "package:<name>/" app/lib`，全部有命中；否则列出未使用项并返回非零退出码。字体：在 Windows 产物上截图比对，断言中文字形非豆腐块（需真机 Windows 产物，本轮**未验证**）。
- **状态**：待修复

---

### [DATA-014] 平台工程配置仍为模板/占位：web/manifest.json、windows/CMakeLists.txt、harmonyos/ 均未品牌化，harmonyos 的 README 描述了不存在的工程结构

- **编号**：DATA-014
- **严重度**：P1
- **类别**：与文档不符 + 工程卫生
- **用户可见现象**：① 把 Web 构建安装为 PWA，应用名显示 `mellow_music`，主题色是 Flutter 默认蓝 `#0175C2`，描述是 `A new Flutter project.`；② Windows 产物可执行文件与进程名是 `app.exe` / `app`，与「Mellow Music」无关联；③ 打开 `app/harmonyos/`，README 详细描述了 `AppScope/app.json5`、`entry/src/main/module.json5`、`entry/src/main/ets/entryability/EntryAbility.ets` 与 `flutter build hap --release` 产物路径，但该目录下**只有 README.md 一个文件**，按文档执行必然失败。
- **复现步骤**：
  1. `cat app/web/manifest.json` → 35 行，`"name": "mellow_music"`, `"short_name": "mellow_music"`, `"background_color": "#0175C2"`, `"theme_color": "#0175C2"`, `"description": "A new Flutter project."`
  2. `sed -n '1,10p' app/windows/CMakeLists.txt` → `project(app LANGUAGES CXX)`、`set(BINARY_NAME "app")`
  3. `ls -R app/harmonyos` → 只有 `README.md`
  4. 权限侧（作为对照，确认哪些已修）：`app/android/app/src/main/AndroidManifest.xml:2-6` 已有 `INTERNET`/`ACCESS_NETWORK_STATE`/`WAKE_LOCK`/`FOREGROUND_SERVICE`/`FOREGROUND_SERVICE_MEDIA_PLAYBACK` —— **已修**；`app/macos/Runner/Release.entitlements:7-8` 已有 `network.client` —— **已修**。
- **代码证据**：
  - `app/web/manifest.json:2`、`:3`、`:6`、`:7`、`:8`
  - `app/web/index.html:21` `<meta name="description" content="A new Flutter project.">`；`:26` `apple-mobile-web-app-title = mellow_music`；`:32` `<title>mellow_music</title>`
  - `app/windows/CMakeLists.txt:3`、`:7`
  - `app/harmonyos/README.md:12`（`AppScope/app.json5`）、`:13`（`entry/src/main/module.json5`）、`:14`（`entry/src/main/ets/entryability/EntryAbility.ets`）、`:20-21`（`flutter build hap --release` 与产物路径）
  - 与附录 A 清单的逐项对照见本文第五节。
- **真实/内置/编造**：模板占位（真实存在但未品牌化）+ 虚假工程描述（harmonyos README）。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:937` 附录 A：`app/web/manifest.json 仍为模板：name/short_name = mellow_music、description = "A new Flutter project."、background_color/theme_color = #0175C2` —— **本轮核对完全一致，未修**；`:936` `project(app)` / `BINARY_NAME "app"` —— **未修**；`:935` `app/harmonyos/ 下仅 README.md 一个文件` —— **本轮 `ls -R` 确认仍是仅 README.md**，但 README 内容却是「工程规范」级别描述 → 该 README 本身就是编造。`docs/PC_E2E_FIX_PLAN.md:852` 要求「产物名/图标/版本信息已品牌化，六端显示一致」。
- **建议修复**：① `app/web/manifest.json`：name/short_name 改 `Mellow Music · 润音`/`Mellow Music`，description 改为真实一句话，theme_color 改为设计系统主色（`design_tokens.css` 中的强调色），`orientation` 按产品决定；`app/web/index.html:21/26/32` 同步；② `app/windows/CMakeLists.txt:3/7` 与 `app/windows/runner/main.cpp` 的窗口标题改为 `Mellow Music`（注意与 release.yml 的产物名一致）；③ `app/harmonyos/`：要么补齐真实工程（`AppScope/app.json5`、`entry/...`、`hvigorfile.ts`）并在 CI 加 `flutter build hap`，要么把 README 改为「当前未实现，仅平台规划」，删除具体文件路径与构建命令。成本：① 0.2 人日；② 0.2 人日；③ 删除改写 0.2 人日 / 真补齐 3~5 人日。
- **可验收标准**：`grep -c 'A new Flutter project' app/web/manifest.json app/web/index.html` → `0`；`grep -c '0175C2' app/web/manifest.json` → `0`；`grep -rn 'app.json5\|EntryAbility.ets' app/harmonyos/README.md | wc -l` → `0`（除非对应文件真实存在，断言可改为 `test -f app/harmonyos/AppScope/app.json5`）。
- **状态**：待修复

---

### [DATA-015] 原型 E2E 套件 e2e_test.js 硬编码 Windows 浏览器路径，在本机（macOS）与 CI（ubuntu）均不可运行，且不是质量门禁

- **编号**：DATA-015
- **严重度**：P2
- **类别**：工程卫生
- **用户可见现象**：`npm test` 在 macOS 上会去 `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe` 找浏览器而失败（本机两个路径的 `fs.existsSync` 均返回 false）。`package.json:7-8` 把 `test`/`test:e2e` 指向该文件，但 `.github/workflows/ci.yml` 实际执行的是 `flutter_e2e_verify.mjs`（后者有跨平台探测：`:70-87` 依次尝试 `CHROME_PATH`/`PUPPETEER_EXECUTABLE_PATH`/`/usr/bin/google-chrome`/Windows 路径）。
- **复现步骤**：
  1. `node -e "const fs=require('fs');console.log(fs.existsSync('C:/Program Files/Google/Chrome/Application/chrome.exe'), fs.existsSync('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'))"` → `false false`。
  2. `grep -n 'CHROME_PATH\|EDGE_PATH' e2e_test.js` → `:5`、`:6`、`:8`（`const browserPath = fs.existsSync(CHROME_PATH) ? CHROME_PATH : EDGE_PATH;`）。
  3. `grep -n 'e2e_test.js' .github/workflows/ci.yml .github/workflows/release.yml package.json` → 仅 `package.json` 引用；CI 两个 workflow 都只跑 `flutter_e2e_verify.mjs`。
- **代码证据**：`e2e_test.js:5-8`；`package.json:7-8`；`.github/workflows/ci.yml:44-45`（`run: node flutter_e2e_verify.mjs`）。
- **真实/内置/编造**：真实测试代码，但**环境耦合导致在本机与 CI 都不可执行**。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:850` 检查项「`node e2e_test.js`（83 项）在 CI 中执行且为门禁（P1-13）」—— **未达成**。`docs/audit/web-layer.md:18` 已记录「#11 CI 从不执行 83 项套件；#12 硬编码浏览器绝对路径」。
- **建议修复**：把 `e2e_test.js:5-8` 的浏览器探测替换为与 `flutter_e2e_verify.mjs:70-87` 相同的跨平台探测（或直接复用其导出），并在 CI 增加一个 `node e2e_test.js` step；或者明确废弃该文件并在 `package.json` 中移除 `test` 脚本，避免给出无法执行的命令。成本 0.5 人日。
- **可验收标准**：`grep -c 'C:\\\\Program Files' e2e_test.js` → `0`；且 CI 中 `node e2e_test.js` 返回 0 且输出 83 项 PASS。
- **状态**：待修复

---

### [DATA-016] 原型 (index.html / mobile.html) 的编造数据与 Flutter 端互相矛盾，且用 localStorage 预置假收藏与假历史

- **编号**：DATA-016
- **严重度**：P2
- **类别**：数据造假
- **用户可见现象**：原型发现页显示「周杰伦 1,290万 粉丝」，移动端原型歌手详情显示「3280 万 关注者」，而 Flutter 端显示「3890.2万」——同一艺人在三处三个数字；原型内置 Taylor Swift / The Weeknd / M83 / ODESza / Daft Punk / 梁静茹 / 告五人 等 Flutter 端完全没有的艺人；原型「本地与离线」页列出 6 个**用户磁盘上不存在**的文件（`晴天 (无损离线版).flac · 32.4 MB` 等）；原型首次打开即有 3 首已喜欢与 1 条播放历史（时间为 `刚刚`）。
- **复现步骤**：
  1. `grep -n 'fans:' index.html` → `:1654` 周杰伦 `1,290万`、`:1655` Taylor Swift、`:1656` 告五人、`:1657` The Weeknd、`:1658` 梁静茹、`:1659` M83；`grep -n 'followers:' mobile.html` → `:2514` 周杰伦 `3280 万`、`:2523/2532/2541/2550/2559`；Flutter 端 `track_model.dart:485` 为 `3890.2万`。
  2. `grep -n 'localSongList' -A 8 mobile.html` → `:2660-2667` 6 条不存在的本地文件与体积（`32.4 MB` 等）。
  3. `grep -n 'localStorage.getItem' index.html` → `:1848`(volume 默认 0.7)、`:1862`(`alger_liked_songs` 默认 `[0, 2, 4]`)、`:1870`(`alger_history` 默认 `[{"songId":0,"time":"刚刚"}]`)；`mobile.html:1542` 同样默认 `[0, 2, 4]`。
  4. `e2e_test.js:747` 断言 `artDetailFans.includes('3280 万')` —— 测试**锁死了**移动端编造值。
- **代码证据**：`index.html:1653-1660`、`:1848-1873`、`:2111-2118`（6 个播客节目的 `98.2万/142万/64.5万/210万/43.1万/88.9万`）、`:2754`（兜底 `fans: "360万 粉丝"`）；`mobile.html:757`（`128万人在听`）、`:882`（`3280 万 关注者 · 热门音乐人认证`）、`:2510-2565`、`:2660-2667`；`e2e_test.js:747`。
- **真实/内置/编造**：硬编码编造（原型定位为设计交付物，但 `package.json:4` 的 description 与 README 的「high-fidelity」措辞会把原型当成产品能力）。
- **原型/文档依据**：`docs/PC_E2E_FIX_PLAN.md:604` 已指出「`mobile.html` 有 210 行与 `index.html` 逐字重复，是『周杰伦粉丝数 1,290万 vs 3280万 同时通过测试』的根因」，并建议抽成共享 `data.js`；**本轮核对双端仍未抽取**（`index.html` 1484 行起的 SONGS 与 `mobile.html` 1249 行起的数据各自独立复制）。`docs/ROADMAP.md:9` 声明账本为唯一权威。
- **建议修复**：① 双端数据抽成单一 `public/data.js`，并在文件头加注释 `// 原型示例数据，非真实数据源`；② 删除 `localStorage` 的假默认值（初始为空数组）；③ 假本地文件列表改为「未扫描到本地文件」（或保留但整块标注 `示例`）；④ 修正 `e2e_test.js:747` 的断言，使其断言「粉丝数字段存在且格式合法」而不是具体编造值。成本 1 人日。
- **可验收标准**：`mobile.html` 与 `index.html` 中不再出现字面量 `万 粉丝`/`followers: "`；且 `e2e_test.js` 不再出现具体数字断言。
- **状态**：待修复

---
### [DATA-017] 仓库里已有 4 个真实音频（33.6 MB）零引用，且未被 .gitignore 覆盖

- **编号**：DATA-017
- **严重度**：P2
- **类别**：工程卫生
- **用户可见现象**：无直接用户可见现象（属资产/仓库卫生）。但它是**最容易拿到的真实数据源**：`public/audio/track1-4.mp3` 是真实音频文件（8,945,229 / 10,222,911 / 8,258,104 / 7,807,352 字节，合计 35,233,596 字节 ≈ 33.6 MiB），已被 git 跟踪（`git ls-files public/audio/` 返回 4 条），却没有任何代码引用（`grep -rn 'public/audio\|track1.mp3' --include='*.js' --include='*.html' --include='*.cjs' --include='*.mjs' .` 仅命中 `docs/` 下的审计文档）。
- **复现步骤**：
  1. `ls -la public/audio/` → 4 个 mp3。
  2. `git ls-files public/audio/` → 4 条（已入库）；`git check-ignore -v public/audio/track1.mp3` → 无输出（**未被忽略**）。
  3. `grep -rn 'track1.mp3' --include='*.html' --include='*.js' --include='*.dart' .` → 0 命中（生产/原型代码中）。
- **代码证据**：`.gitignore:1-20`（全文 20 行，含 `node_modules/`、`scratch/`、`test_*.png`、`.system_generated/`、`release_windows/`、`verify_windows_app.ps1`，**不含 `public/audio/` 与 `.qa/`**）；`docs/PC_E2E_FIX_PLAN.md:148`、`:843`、`:939` 均要求处理；`docs/PC_E2E_FIX_PLAN.md:888` 建议移入 `app/assets/audio/` 作为演示曲目。
- **真实/内置/编造**：真实音频文件（**本轮未对其做内容/版权溯源**，仅确认文件真实存在且被识别为 mp3）。属「死文件」。
- **原型/文档依据**：`docs/audit/web-layer.md:65`（#31）已确认；`docs/PROGRESS.md` 未提及。
- **建议修复**：① 短期按 `docs/PC_E2E_FIX_PLAN.md:148` 加入 `.gitignore`；② **更优**：把它真正用起来——移入 `app/assets/audio/`、在 `pubspec.yaml` 声明 `assets:`、并把 DATA-002 的 4 首演示曲目绑到这些文件（这样「播放能出声」与「无第三方署名义务」同时解决）；③ 若采用 ②，必须先确认这 4 个文件自身的授权与来源（当前仓库无任何来源说明），否则会引入新的版权风险。
- **可验收标准**：方案 ②：`test -d app/assets/audio && grep -q 'assets:' app/pubspec.yaml`，且集成测试断言 `player.playTrack(演示曲目)` 后 `backend.position > Duration.zero`（真实解码前进）。方案 ①：`git check-ignore -v public/audio/track1.mp3` 返回非空。
- **状态**：待修复

---

### [DATA-018] 测试套件把编造数据固化为期望值，且图片渲染在测试态被强制短路，导致「假数据/死链」永远不会被测试发现

- **编号**：DATA-018
- **严重度**：P2
- **类别**：工程卫生
- **用户可见现象**：无直接用户可见现象，但这是本项目 `flutter analyze` 0 issue / `flutter test` 90/90 全绿，却仍然满屏假数据的直接原因：**测试把假数据当作正确值来断言**，并且**任何网络图片在测试里都不发请求**。
- **复现步骤**：
  1. `grep -n '24.8万在听' app/test/batch3_playlist_podcast_test.dart` → `:147` `expect(find.text('24.8万在听'), findsOneWidget);` —— 这是编造的电台在听人数（`track_model.dart:775`），修掉假数据会让测试变红。
  2. `grep -n 'mockPresetTracks' app/test/*.dart app/integration_test/*.dart` → 8 处（`user_e2e_14_issues_test.dart:65/80/81`、`batch4_discover_and_recommend_test.dart:107`、`client_e2e_user_journey_test.dart:168`、`integration_test/app_client_e2e_test.dart:168` 等）。
  3. `app/lib/design_system/mellow_image.dart:7` `static bool isInTest = false;`，`:26-27` `final bool usePlaceholder = isInTest || WidgetsBinding.instance.runtimeType.toString().contains('Test');`，`:48-58`：测试态直接 `img = placeholder`，**根本不构造 `Image.network`**。
- **代码证据**：`app/lib/design_system/mellow_image.dart:7`、`:26-27`、`:48-58`、`:88-93`（`MellowAvatar` 亦走同一路径）；`app/test/batch3_playlist_podcast_test.dart:147`；`app/test/batch4_discover_and_recommend_test.dart:107`（`expect(audioPlayerService.playlist.length, equals(mockPresetTracks.length));`）。
- **真实/内置/编造**：测试基础设施真实，但**覆盖方向反了**：它保护假数据、屏蔽真实网络路径。
- **原型/文档依据**：`docs/e2e/FORMAT.md:37` 明确禁止「找不到就跳过」的条件断言，并要求「必须区分能渲染和能用」；`docs/PC_E2E_FIX_PLAN.md:896` MVP 验收⑧要求「CI 绿灯且其中至少包含一条『改坏生产代码就会红』的断言」。
- **建议修复**：① 删除 `batch3_playlist_podcast_test.dart:147` 对编造数字的断言，改为断言「在听数字段存在且非空」或直接删除该字段（与 DATA-004 联动）；② 把 `batch4_discover_and_recommend_test.dart:107` 的 `equals(mockPresetTracks.length)` 改为断言「playlist 来自真实数据源」的 Repository 接口契约；③ `MellowImage` 保持占位短路（合理），但必须**另加**一个不依赖 widget 层的断言：对 `mockPresetTracks` / `mockArtistsProfiles` 的每个 URL 做一次真实 HTTP 冒烟测试（可标注 `@Tags(['network'])`，在 CI 的联网 runner 上跑）；④ 新增断言「首次启动 0 收藏 0 历史」（见 DATA-009）。
- **可验收标准**：① `grep -c "24.8万" app/test/batch3_playlist_podcast_test.dart` → `0`；② 新增的 URL 冒烟测试在联网环境下对全部 `coverUrl`/`audioUrl` 断言 2xx 且 `content-type` 匹配（本机离线时应 skip 且**打印跳过数量**，禁止静默通过）。
- **状态**：待修复

---

### [DATA-019] 原型强依赖 3 个外部 CDN，其中 Tailwind 为运行时 JIT —— 离线时整个原型丢失全部样式（字体有回退，样式没有）

- **编号**：DATA-019
- **严重度**：P2
- **类别**：工程卫生（离线降级不诚实）
- **用户可见现象**：断网打开 `index.html` / `mobile.html`：字体正常回退（`font-family: 'Plus Jakarta Sans', -apple-system, sans-serif`），图标全部变成方框或空白（remixicon 来自 jsDelivr），**整个页面退化为无样式的裸 HTML**——因为 Tailwind 是通过 `<script src="https://cdn.tailwindcss.com">` 在浏览器里运行时编译所有 class 的，本地没有任何编译产物或回退样式。而 `docs/PROGRESS.md` 把这两份原型描述为「设计交付物」，离线不可用会直接影响设计评审与本地 E2E。
- **复现步骤**：
  1. `grep -n 'cdn.tailwindcss.com\|cdn.jsdelivr.net\|fonts.googleapis.com' index.html mobile.html` → `index.html:9/11/13/15`、`mobile.html:9/11/13/15`。
  2. `ls public/` → 无 `tailwind.css`、无 remixicon 本地副本；`grep -rn 'tailwind' --include='*.css' .` → 不存在；`design_tokens.css` 文件存在但未被引用（`grep -n 'design_tokens.css' index.html mobile.html` → 0 命中）。
  3. 字体回退存在：`mobile.html:46` `font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;`；`index.html` 未见同类自定义 font-family 声明（依赖 Tailwind 默认 font-sans）。
- **代码证据**：`index.html:9`、`:11`、`:13`、`:15`；`mobile.html:9`、`:11`、`:13`、`:15`、`:46`。
- **真实/内置/编造**：真实外部依赖（本轮实测 `fonts.googleapis.com` → HTTP 200 `text/css`），但**无本地降级**。
- **原型/文档依据**：`docs/audit/web-layer.md:66`（#32）已记录「原型并非自包含，强依赖 4 个外部 CDN（且 Tailwind 是运行时 JIT）」；`docs/PC_E2E_FIX_PLAN.md:873` 明确「不要为了跨端一致性去重写 Web 原型层……阶段 0 把文案降级、阶段 6 把它接入 CI 即可」，因此**修复口径应是最小化**（本地化 CDN 或显式声明「原型需联网」），而不是重构。`index.html:13-15` 与 `mobile.html:13-15` 的 Google Fonts 引用也说明 Flutter 端 `google_fonts` 依赖（DATA-013）与原型字体是两套完全无关的东西。
- **建议修复**：① 用 `tailwindcss` CLI 预编译出静态 CSS 并本地引用（去掉运行时 JIT 与 CDN 依赖）；② remixicon 字体文件下载到 `public/fonts/`；③ 或在两份 HTML 顶部与 README 明确标注「本原型需联网，离线仅供查看结构」。成本 0.5 人日。
- **可验收标准**：在断网（或 `--host-resolver-rules` 屏蔽 CDN）条件下加载 `index.html`，页面视觉与联网时**一致**（截图逐像素比对通过）；或项目内存在显式声明「需联网」的文案且 E2E 断言该文案存在。
- **状态**：待修复

---
## 三、外部数据源真实连通性探测记录（本轮实测，命令与结果原样保留）

> 环境：macOS，本机 resolver 处于 fake-IP 代理模式（见注）。curl 8.x，`UA=Mozilla/5.0 (Macintosh; ...) Chrome/120.0 Safari/537.36`。
> 注：**凡涉及域名是否存在，必须用 Cloudflare DoH 复核**；本机 `host`/`dig` 会返回 `198.18.0.x` 的合成地址（Clash/Surge fake-IP 保留段），把 NXDOMAIN 伪装成可解析。

| # | 目标 | 实测命令（要点） | 实测结果 | 真实性结论 |
| :-: | :--- | :--- | :--- | :--- |
| 1 | `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3` | `curl -sSI` | `HTTP/2 200`；`content-type: audio/mpeg`；`content-length: 8945229`；`last-modified: Sat, 05 Mar 2011`；`accept-ranges: bytes` | **真实可达**（真实音频字节） |
| 2 | 同上，`Range: bytes=0-1000`，`Song-1/7/16/17` | `curl -r 0-1000 -o /dev/null -w '%{http_code}'` | 4 个均 `206` | **真实可达**；注意 `Song-17` 也存在 → 「16 个演示 mp3」的口径不完整 |
| 3 | `https://music.163.com/song/media/outer/url?id=347230.mp3` | `curl -w '%{http_code} %{redirect_url}'` | `302` → `http://music.163.com/404` | **死链**（对应该曲无免费授权） |
| 4 | 同 #3 加 `-L` | `curl -L -o /dev/null -w '%{http_code} %{size_download}'` | `HTTP 200`，但 `size=107191` 且为 HTML 错误页 | **伪 200**：跟随重定向得到错误页而非音频，**任何只判 `statusCode == 200` 的逻辑都会被骗过** |
| 5 | 同 #3 去掉 `.mp3`（`?id=347230`） | 同上 | 同样 `302` → `.../404` | 证明失败**与后缀无关**，不是拼接 bug |
| 6 | 抽样 6 个 id：`347230 / 186016 / 299174 / 165470 / 1901371647 / 1330348068` | 同 #3 | 前 5 个 `302→/404`；`1330348068` → `302` 到真实 `m701.music.126.net/.../….mp3`（带 `vuutv` 签名） | **部分可用**：通道未死，受版权/会员限制；「全部不可播」与「全部可播」都不准确 |
| 7 | `https://music.163.com/api/search/get/web?s=zhoujielun&type=1&limit=3`（带 Referer） | `curl` | `HTTP 200`，真实 JSON：`result.songs[0]` 为宋祖英/周杰伦合作曲目，含真实 `id`/`duration`/`artists[].img1v1Url`/`album.picId` | **真实网络**（未授权的私有接口） |
| 8 | `https://music.163.com/api/song/lyric?os=pc&id=347230&lv=-1` | `curl` | `HTTP 200`，真实 LRC：`[00:00.000] 作词 : 黄家驹`、`[00:18.466]今天我 寒夜里看雪飘过` | **真实网络**；且与 `track_model.dart:164-174` 的手写歌词**不完全一致**（真实首句在 18.466s，手写版在 18s 且后续文本行数与内容不同） |
| 9 | `https://music.163.com/api/playlist/detail?id=3778678` | `curl` | `HTTP 200`，真实歌单（creator 为「网易云音乐」官方账号，含 `coverImgUrl`/`description`/`tracks`） | **真实网络** |
| 10 | #7 加 `Origin: http://localhost:8088` 看 CORS | `curl -I ... \| grep -i access-control` | **无任何 `access-control-allow-origin` 响应头** | `flutter build web` 产物下必被浏览器拦截；桌面端不受影响 → Web 端「能显示封面（img 标签）但不能搜索（XHR）」的半坏状态 |
| 11 | `stream.mellowmusic.io`（`lx_script_sandbox.dart:205`） | 本机 `host` vs Cloudflare DoH | 本机：`has address 198.18.0.113` + `NXDOMAIN`（fake-IP 干扰）；**DoH：`{"Status":3}`（NXDOMAIN，SOA 来自 .io TLD）** | **域名不存在（死链）** |
| 12 | `cdn.<platformId>.music.net`（`:452`，实测 `cdn.kw.music.net`） | DoH | `{"Status":3}`，SOA `music.net` ← awsdns | **域名不存在（死链）** |
| 13 | `custom-cdn.<metadata.id>.com`（`:646`，实测 `custom-cdn.demo.com`） | DoH | `{"Status":3}`，SOA `demo.com` ← cloudflare | **域名不存在（死链）** |
| 14 | `mellowmusic.io`（父域，验证是否只是子域没配） | DoH | `{"Status":3}`，SOA 来自 .io TLD `a0.nic.io` | **整个 `mellowmusic.io` 域未注册/不存在** |
| 15 | 对照组 `unsplash.com` | DoH | `{"Status":0}` + 4 条 A 记录（151.101.x.181） | 证明 DoH 方法有效，非工具问题 |
| 16 | `images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&q=80` | `curl -L -o file -w '%{http_code} %{content_type}'` | `HTTP 200`，`image/jpeg`，`size=20335` | **真实可达**（图片字节真实；**内容与曲目无关**，见 DATA-005） |
| 17 | `images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400` | 同上 | `HTTP 200`，`image/jpeg`，`size=28355` | **真实可达** |
| 18 | 另下载 3 张并肉眼核验内容 | image 工具直接查看 | `photo-1518709268805`=欧洲城堡(400x605)；`photo-1534528741775`=蓝紫打光女性肖像(400x500)；`photo-1470225620780`=紫色 DJ 打碟台(400x267) | 图片真实，**语义编造** |
| 19 | `https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap` | `curl -L -o /dev/null -w '%{http_code} %{content_type}'` | `HTTP 200`，`text/css; charset=utf-8` | **真实可达**；但 **Flutter 端 `google_fonts` 0 引用**，此探测只对原型 `<link>` 有意义 |
| 20 | macOS Debug 产物的网络能力 | `codesign -d --entitlements -` + `open` + `log show` | 无 `network.client`；`kernel: (Sandbox) Sandbox: app(21002) deny(1) network-outbound remote:*:443`（13 duplicate reports） | **OS 层阻断**：上表 #1~#19 的真实性结论在 Debug 产物中全部无法兑现（见 DATA-001） |
| 21 | SoundHelix 许可条款 | `curl https://www.soundhelix.com/audio-examples` 后去标签 grep | 原文：`You may use these audio examples in any way you like, but you must give credit to SoundHelix and the artist of the respective song.` | **允许使用但强制署名** → 当前实现违约（见 DATA-003） |

**关于「google_fonts 在无网络时的降级行为」的结论**（本项被明确问到）：
1. **Flutter 客户端：不存在该链路。** `google_fonts` 在 `app/lib` 与 `app/test`/`app/integration_test` 中 grep 命中 **0**（DATA-013）。因此「无网络时 google_fonts 如何降级」在当前代码里没有发生路径；真实字体行为是 `main.dart:44/54` 声明 `fontFamily: 'PingFang SC'`（macOS 系统字体），在 pubspec 无 `fonts:` 声明的情况下，非 Apple 平台会静默回退到平台默认字体，**无日志、无提示**。
2. **Web 原型：字体有回退，样式没有。** `mobile.html:46` 的 `font-family: 'Plus Jakarta Sans', -apple-system, sans-serif` 保证断网时字体可读；但 `index.html:9`/`mobile.html:9` 的 `cdn.tailwindcss.com` 是**运行时 JIT**，断网时整站样式全丢（DATA-019）。`index.html` 未声明自定义 `font-family`，完全依赖 Tailwind 的 `font-sans`，断网后连字体回退都失效。
3. **未验证项**：`google_fonts` 在「联网首次下载 + 断网二次启动」下的真实缓存行为本轮**未实测**（因为代码里根本没有调用点，无可测对象）。若后续接入，必须实测其 `GoogleFonts.config.allowRuntimeFetching` 与缓存目录行为。

---

## 四、链路分类总表（真实网络 / 内置示例 / 硬编码编造 / 死链 / 断线死代码）

| 链路 | 位置 | 分类 | 关键证据 | 对应条目 |
| :--- | :--- | :--- | :--- | :--- |
| SoundHelix 演示音频下载 | `track_model.dart:120…854`（33 处） | **真实网络**（HTTP 200 / audio/mpeg / 8.9 MB） | 探测 #1/#2 | DATA-002/003 |
| Unsplash 封面加载 | `app/lib` 76 处；`track_model.dart` 15 张去重 | **真实网络**（HTTP 200 / image/jpeg）但**语义编造 + 大面积复用** | 探测 #16/#17/#18 | DATA-005 |
| 网易云在线搜索 | `online_music_service.dart:29-84` | **真实网络**（HTTP 200 真实 JSON） | 探测 #7 | DATA-006 |
| 网易云歌词 | `online_music_service.dart:164-184` | **真实网络**（HTTP 200 真实 LRC） | 探测 #8 | DATA-006 |
| 网易云歌单详情 | `online_music_service.dart:87-161` | **真实网络**（HTTP 200 真实 JSON） | 探测 #9 | DATA-007 |
| 网易云播放直链 | `online_music_service.dart:63/132` | **部分死链**（抽样 6 个 id 中 5 个 302→404；1 个拿到真实 mp3）+ 跟随重定向得到伪 200 HTML | 探测 #3~#6 | DATA-006 |
| 内置曲库（33 首 / 16 音频） | `track_model.dart:111-234 / 256-470 / 525-725 / 769-863 / 887-957` | **内置示例 + 硬编码编造元数据** | 本轮统计 33 引用 / 16 唯一 | DATA-002/004 |
| 榜单 / 歌手 / 电台 / 歌单广场 | `track_model.dart` + `desktop_views.dart:414-447` | **硬编码编造**（含粉丝数/播放量/在听数/更新频率） | 见 DATA-004 全部行号 | DATA-004 |
| LX 六维音源直链 | `lx_script_sandbox.dart:205/452/646` | **死链 + 断线死代码**（DoH NXDOMAIN ×4；app/lib 0 引用） | 探测 #11~#14；grep 计数 0 | DATA-010 |
| 推荐歌单 / Hero 大图 | `desktop_views.dart:116/153/160/167/174` | **硬编码编造**（标题 + `48.6万播放` 等字符串直接写在 `_buildPlaylistCard` 调用处） | DATA-004 行号 | DATA-004/005 |
| 移动端雷达卡 / 专辑卡 | `mobile_tabs.dart:332/354/370/390/404/637/643/649/655` | **硬编码编造**（`午夜霓虹/M83`、`Golden Hour/JVKE`、`Hurry Up, Dreaming/2011` 等，其中 M83/JVKE 在底库中不存在） | 行号如上 | DATA-004 |
| 移动端本地曲库页 | `mobile_pages.dart:639-660` | **内置示例**（明确标注 `演示曲目`，诚实）；但被放在「本地与离线曲库」标题下，语义混淆 | 读取 `:639/641/646/659` | DATA-002（P2 部分） |
| 桌面端本地音乐页 | `desktop_views.dart:1254-1283` | **断线死代码 / 占位**，但**文案诚实**（`功能正在接入中`、`本地曲库暂无内容`、SnackBar `本地文件与目录扫描功能正在接入中...`） | 读取 `:1265/1268/1274/1282`；`grep -c 'file_picker\|FilePicker\|DragTarget' app/lib` → `0` | DATA-014 附注 |
| WebDAV 同步 | `webdav_sync_service.dart` | **断线死代码**（app/lib 内 0 处 import） | grep：仅自身 `:160/171` | DATA-011 |
| LAN P2P 同步 | `lan_sync_service.dart` | **断线死代码**（app/lib 内 0 处 import） | grep：仅自身 `:411/418` | DATA-011 |
| `sync_data_model.dart` | `core/sync/` | **传递性死代码**（唯一 import 方是两个死文件） | `lan_sync_service.dart:6`、`webdav_sync_service.dart:5` | DATA-011 |
| EQ 滤波 | `equalizer_manager.dart:81-92` | **断线死代码**（`toLibmpvFilterString` 生产 0 调用；后端 audioplayers 无滤波能力） | grep：仅 3 处测试 | DATA-012 |
| 音频播放（物理） | `player_backend.dart:22-71`（audioplayers） | **真实**（基线已确认；且 `audio_player_service.dart:295` 有诚实失败提示） | FORMAT §4 基线 | — |
| 本地落盘持久化 | `storage_service.dart` + `audio_player_service.dart:113-161` | **真实**（SharedPreferences 真实键值） | FORMAT §4 基线 | — |
| `server.cjs` | 顶层 | **真实静态托管，0 假数据**（172 行，仅 Range 静态文件服务；无任何 API/数据接口） | 全文读取 | — |
| 原型「播放」 | `index.html:1663-1836`、`mobile.html:1359-1523` | **内置示例（Web Audio 振荡器合成，非音频文件）** | 引用 `docs/audit/web-layer.md:63/147`；本轮未复跑浏览器 | DATA-019（关联） |
| `public/audio/track1-4.mp3` | `public/audio/` | **真实音频但零引用（死文件）** | `git ls-files` + `ls -la` + grep 0 命中 | DATA-017 |

---
## 五、docs/PC_E2E_FIX_PLAN.md 附录 A 清单逐项核对（已修 / 未修）

> 附录 A 原文位于 `docs/PC_E2E_FIX_PLAN.md:925-941`。逐条与本轮实测对照。

| 附录 A 条目（原文） | 本轮实测 | 结论 |
| :--- | :--- | :--- |
| `:930` Dart 测试用例 77 个（`test(` 44 + `testWidgets(` 33） | `docs/e2e/FORMAT.md:47` 已更新为 `flutter test` 90/90 通过（主 Agent 本轮实测） | **数字已过期**，以 FORMAT §4 为准 |
| `:931` `client_e2e_user_journey_test.dart` 与 `integration_test/app_client_e2e_test.dart` 完全相同（279 行，MD5 均 9C6CE41ED0） | 本轮 grep 显示两者引用同一批符号（`online_music_service`、`lan_sync_service`、`toLibmpvFilterString` 等）且行号一致（`:146/147/148/152/153/156/161/162/163/168/230`）→ 高度疑似仍为同一份文件的拷贝 | 未复核 MD5 与行数（**未验证**）；建议 Sub-Agent D 用 `md5 app/test/client_e2e_user_journey_test.dart app/integration_test/app_client_e2e_test.dart` 复核 |
| `:932` `pubspec.lock` 解析出 `flutter: ">=3.47.0"`，workflow 用 `channel: 'stable'` 未固定 | `.github/workflows/ci.yml:17-20` 与 `release.yml` 仍为 `channel: 'stable'`；本机 Flutter 为 3.47.4 | **未修**（版本未固定） |
| `:933` `AndroidManifest.xml` 共 45 行，无任何 uses-permission | 实测 **51 行**，`:2-6` 已有 5 条权限（INTERNET / ACCESS_NETWORK_STATE / WAKE_LOCK / FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK） | **已修**（P0-05 已落地，附录 A 描述过期） |
| `:934` `macos/Runner/Release.entitlements` 共 8 行，仅 app-sandbox | 实测 **12 行**，`:7-8` 已有 `network.client`、`:9-10` 有 `network.server` | **已修**（P0-06 已落地）；但**新增发现**：`DebugProfile.entitlements` 仍缺 `network.client` → 见 DATA-001 |
| `:935` `app/harmonyos/` 下仅 README.md 一个文件 | `ls -R app/harmonyos` → 仅 `README.md` | **未修**；且该 README 描述了不存在的文件（`AppScope/app.json5` 等）→ DATA-014 |
| `:936` Windows `project(app)` / `BINARY_NAME "app"` / `Create(L"app", ...)` | `app/windows/CMakeLists.txt:3` `project(app LANGUAGES CXX)`、`:7` `set(BINARY_NAME "app")` | **未修**（`main.cpp:30` 本轮未读取，**未验证**）→ DATA-014 |
| `:937` `web/manifest.json` 仍为模板（mellow_music / A new Flutter project. / #0175C2） | `app/web/manifest.json:2/3/6/7/8` 完全一致；`app/web/index.html:21/26/32` 同 | **未修** → DATA-014 |
| `:938` `pubspec.yaml` flutter 段无 fonts 配置（65-101 全为注释），而 `main.dart:42/52` 声明 `fontFamily: 'PingFang SC'` | 实测 `pubspec.yaml:73-76`（assets）与 `:84-99`（fonts）全为注释；`main.dart:44` 与 `:54` 为 `fontFamily: 'PingFang SC'`（行号与附录差 2） | **未修** → DATA-013 |
| `:939` `public/audio/` 4 个 mp3 合计约 33.6 MB；`.gitignore` 未包含 `public/audio/` 与 `.qa/` | 实测 `ls -la public/audio` → 8945229+10222911+8258104+7807352 = 35,233,596 B ≈ 33.6 MiB；`.gitignore` 全文 20 行，无 `public/audio/` 与 `.qa/`；`git check-ignore` 无输出 | **未修** → DATA-017 |
| `:940` 未验证项：本机无 Flutter/Dart 工具链 | 本机 `flutter --version` → Flutter 3.47.4 / Dart 3.13.3（`/opt/homebrew/bin/flutter`）；`docs/PROGRESS.md:22` 已声明该前提过期 | **前提已过期**（附录 A 自身过期） |

**补充对照（正文其他关键承诺）**：
- `docs/PC_E2E_FIX_PLAN.md:866`「不要把 6 首 mock 曲目扩到 30 首或 200 首」→ 实际已 **33 首**，**未遵守**（DATA-002）。
- `docs/PC_E2E_FIX_PLAN.md:825`「首次安装时收藏为 0 首、历史为空」→ 收藏仍有 4 个硬编码，**未达成**（DATA-009）。
- `docs/PC_E2E_FIX_PLAN.md:833`「4 个排行榜返回的曲目集合互不相同」→ 本轮核对 4 组 id **互不相交，已达成**。
- `docs/PC_E2E_FIX_PLAN.md:834`「同一歌手在不同页面的粉丝数一致，或不显示」→ **未达成**（歌单播放量两处不一致；歌手详情有 `orElse` 兜底 `128.5万`）。
- `docs/PC_E2E_FIX_PLAN.md:835`「同一张图片不再充当多个互不相关的实体」→ **未达成**（DATA-005）。
- `docs/PC_E2E_FIX_PLAN.md:837`「无任何 `Future.delayed` 伪造的成功提示」→ `grep -c 'Future.delayed' app/lib` → **0 命中**，**已达成**。
- `docs/PC_E2E_FIX_PLAN.md:843`「`.gitignore` 已包含 `public/audio/`、`.qa/`」→ **未达成**（DATA-017）。
- `docs/PC_E2E_FIX_PLAN.md:850`「`node e2e_test.js`（83 项）在 CI 中执行且为门禁」→ **未达成**（DATA-015）。

---

## 六、可执行修复方案（每条链路：接什么真实来源 / 成本 / 无法接时的诚实降级 / 版权与合规风险）

> 排序原则：先让「能播」和「不撒谎」同时成立，再谈内容量。成本单位：熟练 Flutter 工程师人日。

### 6.1 内置曲库与音频（最高优先，因为「音乐播放器」的前提）

| 方案 | 做法 | 成本 | 诚实降级 | 版权/合规风险 |
| :--- | :--- | :--- | :--- | :--- |
| **A（推荐）复用仓库自带真实音频** | 把 `public/audio/track1-4.mp3`（33.6 MB，已在库，零引用）移入 `app/assets/audio/`，`pubspec.yaml` 声明 `assets:`，把 4 首演示曲目指向它们；其余 29 首内置曲目全部删除或标注为「不可播放示例」 | 1~1.5 | 未打包 asset 时（Web/未声明）显示「演示音频未打包」并置灰播放键 | **必须先溯源这 4 个 mp3 的来源与授权**（当前仓库无任何出处说明）。若来源不明，不得随包分发；此时退回方案 B |
| **B 中立化内置示例** | 保留 SoundHelix 16 个演示 mp3，把 33 条元数据改为 `演示音轨 01…16`、artist `SoundHelix (演示)`；「设置 → 关于」与 `THIRD_PARTY_NOTICES.md` 增加署名；删除所有真实艺人名与「无损/母带/高保真」标签 | 0.5~1 | 直接可行，无降级需要 | SoundHelix 许可要求署名，方案 B 满足；同时消除「挂真实艺人名」的著作权/邻接权与名誉风险 |
| **C 接入 CC0/CC-BY 曲库** | 接入 Free Music Archive（CC0/CC-BY）、Incompetech、ccMixter 等；把 `audioUrl` 指向其稳定直链，并同步其 `license`/`attribution` 字段到 UI | 2~3 | 直链失效时回落到方案 B 的本地演示音轨 | CC-BY 需在 UI 内展示作者与许可；**不得**接入版权音乐（网易云/QQ 的音频直链均属未授权分发） |
| **D 只做本地播放器（MVP 口径）** | 按 `docs/PC_E2E_FIX_PLAN.md:881-896` 的 10 天 MVP：`file_picker` + 目录扫描，删除全部内置在线/榜单/音源入口 | 见计划 D6~D9 | 曲库为空时显示「尚未导入音乐，点击选择文件夹」 | **零版权风险**（用户自己的文件） |

### 6.2 封面与头像
- **接什么**：在线曲目用接口返回的真实封面字段（网易云 `album.picUrl` / `img1v1Url`，本轮 JSON 中确认存在 `picId` 与 `img1v1Url`，`album.picUrl` 的有无**未最终确认**）；内置演示曲目用**程序生成的确定性占位图**（按 `track.id` 哈希取色 + 曲名首字）。
- **诚实降级**：`MellowImage` 已有 `errorBuilder` → placeholder（`mellow_image.dart:56`），这是正确的；应把 placeholder 改为「带首字的确定性色块」，比灰色音符更能说明「这是占位」。
- **成本**：0.5~1 人日。
- **合规风险**：Unsplash 许可允许免费使用但**禁止**用他人照片暗示特定人物的身份/代言（本项目把女性肖像当作「巫娜/用户本人」即属此类风险）；继续使用须遵守 Unsplash License 与 API 的 hotlink 要求，且应在 `THIRD_PARTY_NOTICES.md` 列出。

### 6.3 在线搜索 / 歌词 / 歌单（网易云私有接口）
- **接什么**：三选一 ——
  1. **官方/授权 API**：QQ 音乐开放平台、Spotify Web API、Apple Music API（均需申请与 OAuth）。成本 3~5 人日，合规。
  2. **保留现状但显式标注风险**：UI 与 README 写明「使用未授权的第三方公开接口，仅供个人学习，随时可能失效」，并把失败态做诚实（见下）。成本 0.5 人日。**风险：接口变更、封禁、ToS 违约**。
  3. **移除在线入口**，只保留本地曲库。成本 0.2 人日，风险为零。
- **诚实降级**：无论哪条路，都必须区分「无结果 / 网络不可用 / 接口不可用 / 曲目无授权」四种状态并分别提示（见 DATA-006/007/008 的验收标准）。播放前用 `content-type` 前缀判定（`audio/`）过滤不可播曲目，或在列表上直接标注「无授权，需在官方客户端播放」。
- **版权风险（必须写进 README）**：网易云 `/api/...` 为未授权私有接口，`song/media/outer/url` 属绕开官方客户端的取流通道；用它取流并播放受版权保护的曲目可能构成侵权。**不得**在发布版中把它作为「音乐播放」的主能力，也不得宣传「高保真/无损」。

### 6.4 榜单 / 歌手 / 歌单广场 / 电台
- **接什么**：与 6.3 同源。**关键约束**：所有计数类字段（粉丝、播放量、在听数、更新频率）只有在来源真实时才显示，否则**整字段删除**（不要显示 `--` 也不要用占位数字）。
- **成本**：若走网易云：1.5~2 人日（含错误态）；走官方 API：+2 人日申请与联调。
- **诚实降级**：空态文案「榜单数据源不可用，请稍后重试」「该歌单共 N 首（其中可播放 M 首）」。**禁止**用 `?? mockPresetTracks` 兜底（`desktop_views.dart:493`、`mobile_pages.dart:335`）。
- **合规风险**：同 6.3；此外榜单排名的真实性涉及「虚假宣传」，编造排名在应用商店审核与广告法语境下均有风险。

### 6.5 LX 音源沙箱
- **接什么**：删除（推荐，0.5 人日）或接 `flutter_js` + 用户自备脚本（3~5 人日）。
- **诚实降级**：删除后同步删除 `desktop_views.dart:1503-1511` 的「在线导入音源」按钮（当前是纯 SnackBar 占位）与 `:1499` 的「（功能接入中）」文案；或整块改为「音源扩展：规划中」。**当前状态最差：页面存在、按钮存在、能力不存在、域名还不存在**。
- **合规风险**：自定义音源脚本通常用于绕开版权限制，**强烈不建议**在产品内提供；若做，必须在 UI 明示责任由用户承担，并在商店说明中披露。

### 6.6 WebDAV / LAN 同步
- **接什么**：删除（0.5 人日）或接线（3~4 人日，用 `flutter_secure_storage` 存凭据）。
- **诚实降级**：当前 `desktop_views.dart:1561` 的 `'云端同步功能尚未完整接入，请勿依赖此页面备份数据'` 已经很好，**保留这种口径**；LAN 区块的「支持设备自动发现与歌曲互传」应删掉（因为不成立）。
- **合规风险**：低（但 WebDAV 明文密码是安全风险，见 P1-19）。

### 6.7 平台配置与依赖
- 与 DATA-013/014/015/017/019 一一对应，总成本约 **2 人日**：manifest/CMakeLists 品牌化 0.4；harmonyos 删除改写 0.2；pubspec 依赖清理 + fonts 决策 0.5；`.gitignore` + public/audio 决策 0.3；e2e_test.js 跨平台化 0.5；原型 CDN 本地化或声明 0.5。
- **诚实降级**：不打算做的平台（HarmonyOS/iOS/Linux）从 README、SPEC、ROADMAP 与 CI 中**移除**，或明确标注「未实现」。

### 6.8 建议排期（数据真实性视角的 Top 5）
1. **修 `DebugProfile.entitlements` 的 `network.client`**（0.1 人日）——它让其他所有「接入真实数据」的工作在验收产物上可见，性价比最高。
2. **决定演示音频路线（6.1 A/B/D）并执行**（0.5~1.5 人日）——同时解决 DATA-002/003/017。
3. **删除/中立化所有无来源统计数字与真实艺人名绑定**（0.5 人日）——DATA-002/004。
4. **在线链路的四态错误反馈 + 播放前 `content-type` 判定**（1 人日）——DATA-006/007/008。
5. **删除死代码（LX 音源 + sync + EQ 字符串）或明确标注「未接入」**（0.5~1 人日）——DATA-010/011/012。

---

## 七、本轮未验证 / 不确定事项（不装作已验证）

1. **`backend.play()` 对「HTTP 200 + text/html」的响应行为未实测。** `audio_player_service.dart:293-297` 的诚实提示只在异常路径触发；audioplayers 在拿到 HTML 时是抛异常还是静默失败，本轮未构造用例验证。需要：在 Debug 产物（修好 network.client 后）对 `id=347230` 播放并观察 `_playbackNotice` 是否出现。
2. **`app/test/client_e2e_user_journey_test.dart` 与 `app/integration_test/app_client_e2e_test.dart` 是否仍逐字节相同未复核**（附录 A 称 MD5 相同）。需要 `md5` + `wc -l` 复核。
3. **`public/audio/track1-4.mp3` 的来源、授权与内容未溯源**。本轮只确认文件真实存在、被 git 跟踪、零引用；`file` 识别为 mp3。是否有版权、是否可分发，**未验证**。
4. **`app/windows/runner/main.cpp:30` 的 `Create(L"app", ...)` 未读取**（附录 A 引用该行）；Windows 产物名与窗口标题的实际情况**未验证**（`release_windows/` 被 gitignore，仓库内无产物）。
5. **Windows / Android / HarmonyOS / iOS 上的字体回退与网络行为未实测**（需真机产物）；本文关于 `PingFang SC` 在非 Apple 平台降级的判断是**基于代码推断**（pubspec 无 fonts 声明 + 平台字体名），未在 Windows 上截图确认。
6. **`google_fonts` 的实际降级行为未测**（代码中 0 调用点，无可测对象）。原型的 Google Fonts 回退行为由 `mobile.html:46` 的 CSS `font-family` 列表推断，未做断网抓图验证。
7. **原型「播放 = Web Audio 振荡器合成」的结论引用自 `docs/audit/web-layer.md:63/147`，本轮未在浏览器中复跑**（本机无可用 GUI 显示，`screencapture` 报 `could not create image from display`）。
8. **带 `Origin` 头的 CORS 探测只做了搜索接口**；歌词与歌单接口是否同样无 CORS 头**未逐一验证**（推断一致）。
9. **`equalizer_manager` 是否曾被其他音频后端使用**无法从当前代码判断；本轮仅确认当前 audioplayers 后端无滤波接口、`toLibmpvFilterString` 生产 0 调用。
10. **`app/macos` 的 `Release.entitlements` 是否真的被 Release 构建使用未实测**（本轮验证的是 Debug 产物的实际 entitlements）；Release 构建成功与签名流程**未验证**。
11. **内置曲目的 `Duration`（如 `Duration(minutes: 4, seconds: 28)`）与真实音频长度的对应关系未测**；未读取 SoundHelix mp3 的真实时长，因此无法断言「时长也是编造」。`InMemoryAudioPlayerBackend._duration` 硬编码 3:30（`player_backend.dart:81`）是测试后端，不算造假。
12. **`docs/e2e/ledger-desktop.md` / `ledger-mobile.md` / `ledger-fixplan-progress.md` 本轮不存在**（`ls docs/e2e/` 仅 `FORMAT.md`），因此无法交叉核对桌面/移动端条目是否重复记录同一缺陷。建议主 Agent 在汇总时去重（尤其 DATA-004/005 与各端 UI 条目的重叠）。

---

## 八、附录：本轮实测为真 / 已达成项（用于避免误伤，不作为缺陷）

- `server.cjs`（172 行）**是唯一无假数据的服务端链路**：只做静态托管 + 正确实现的 Range（`:124-160` 严格正则、`Number.isInteger` 校验、416 分支、`stream.on('error')`、进程级 `uncaughtException`），且仅监听 `127.0.0.1`（`:169`）。`docs/PC_E2E_FIX_PLAN.md:919` 的 P0-12 在本文件上**已修**（对照 `docs/audit/web-layer.md:35` 描述的旧 `server.js` 漏洞）。
- `audio_player_service.dart:295` 的播放失败提示、`desktop_views.dart:1561/1568` 的同步未接入提示、`:1265/1274/1282` 的本地导入未接入提示、`mobile_pages.dart:641` 的扫描未接入提示 —— **全项目共 5 处诚实降级**，是本轮唯一的正面发现，修复其它条目时应保留此风格。
- 四个榜单的曲目 id 集合**互不相交**（`toplistSurgeTracks`/`toplistHotTracks`/`toplistNewTracks`/`toplistOriginTracks`，`track_model.dart:525/579/604/657`），`docs/PC_E2E_FIX_PLAN.md:833` 的要求**已达成**。
- `grep -c 'Future.delayed' app/lib` → **0**；`grep -c 'TODO\|FIXME' app/lib` → **0**。附录 A 检查项「无 `Future.delayed` 伪造成功提示」**已达成**。
- 真实落盘：`storage_service.dart:32-40` 定义 9 个真实 KV 键，`:105-111` 真实写入与清除历史，`audio_player_service.dart:366-367/377/407/474` 在收藏/音量/模式/历史变更时真实落盘。
- 图片加载失败有 `errorBuilder` 兜底（`mellow_image.dart:56`），不会因死链抛错崩溃。
