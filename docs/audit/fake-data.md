# Mellow Music Player · 假数据 / 硬编码 / 与真实用户数据无关内容 全量审计报告

- **审计对象**：`E:\code\AI\vibCoding\mellow-music-player`
- **审计范围**：Flutter 客户端 `app/lib/**`、Web 原型 `index.html` / `mobile.html`、服务端脚本 `server.js`、依赖清单 `app/pubspec.yaml` / `app/pubspec.lock`
- **审计方法**：全文检索 + 逐行阅读关键文件 + 对关键 URL **实际下载取样并查看图片内容**（见 §5）+ 依赖与调用点交叉验证（grep 调用方，确认某模块是否真的被 UI 使用）
- **审计基准**：当前工作区代码快照
- **证据规范**：所有行号均为 `文件:行号`，可直接跳转核对。读不到的项在 §6 明确写"未找到"，不做推测。

---

## 0. 结论摘要

| 维度 | 结论 |
|---|---|
| 主表条目总数 | **174 条**（A–L 共 174 行，均为可逐条核查的独立事实） |
| ├ 判定为"假"（纯编造 / 纯装饰 / 死代码） | **143 条** |
| │　├ 纯编造或纯装饰 | 130 条 |
| │　├ 假(未接线)：有实现但 0 处调用 / onTap 为空函数 | 7 条 |
| │　└ 其它假（Web 合成器 2 / 静默降级 1 / 命名遗留 1 / 兜底常量 1 / 兜底文案 1） | 6 条 |
| ├ 真假混杂（名称真实，但封面/歌词/音源/端口等被编造） | 11 条 |
| └ 部分真 | 1 条 |
| 判定为"真"（真实实现 / 真实 I/O） | **19 条**，可归并为 **8 条可用链路**（详见 §4） |
| 分组条目数 | A 曲库 18 · B 歌手 11 · C 排行 10 · D 歌单 18 · E 同步 15 · F 收藏历史 8 · G 本地下载 13 · H 音源 19 · I 移动端 UI 12 · J 搜索 11 · K Web 原型 19 · L 其它硬编码 20 |
| 最严重问题 | **整个播放器没有任何音频解码/播放依赖，也没有任何音频播放调用**——"播放"只是 50ms 定时器推进进度条的模拟；所有封面/头像均为 Unsplash 无关照片 |

---

## 1. 主表（可核查清单）

> **"真实/假"列取值**：`假` = 纯编造或纯装饰；`真假混杂` = 名称真实但元数据/资源被编造；`假(未接线)` = 代码写了但从未被任何 UI 调用，等于死代码/装饰。

### A. 曲库底座 `mockPresetTracks`

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| A1 | app/lib/core/audio/track_model.dart:110-111 | 全局曲目池"预置高保真曲目池"，注释自称与"原型 83 项 E2E 验证曲目 100% 对齐" | 假 | `/// 预置高保真曲目池 (与原型 83 项 E2E 验证曲目 100% 对齐)`<br>`final List<Track> mockPresetTracks = [` | 整个 App 的"曲库"就是一个 6 元素常量数组，与应用内任何真实扫描/网络结果无关 |
| A2 | track_model.dart:67-68 | 每首 track 默认 `source = 'lx-mock'`、`audioUrl` 为 null | 假 | `this.source = 'lx-mock',` `this.audioUrl,`（默认 null） | 6 首预置曲目 `audioUrl` 全为 null，即"无音频地址"，不可能真的播出声 |
| A3 | track_model.dart:119 / 140 / 159 / 180 / 199 / 216 | 每首的 `source` 标签：`preset-flac` / `preset-320k` | 假 | `source: 'preset-flac',` `source: 'preset-320k',` | 伪造"无损音源"来源标识，UI 会据此显示"无损"话术 |
| A4 | track_model.dart:113-118 | 曲目 1：`云水禅心 / 巫娜 / 天禅 · 琴筝和鸣 / 4:28` | 真假混杂 | `id: 'track-1', title: '云水禅心', artist: '巫娜', album: '天禅 · 琴筝和鸣', duration: const Duration(minutes: 4, seconds: 28),` | 曲名+演奏者真实存在（古琴曲），但专辑名/时长/来源标签为手写 |
| A5 | track_model.dart:121-131 | 曲目 1 的 9 行"歌词"（"古筝幽弦，流水静淌"等） | 假 | `LyricLine(time: const Duration(seconds: 12), text: '古筝幽弦，流水静淌'),` | 《云水禅心》是**器乐曲、本就无词**，此处 9 行全部为手写文案；时间戳 0/12/24/38/52/68/88/110/135 秒为人工凑数，非任何平台 LRC |
| A6 | track_model.dart:133-151 | 曲目 2：`晚风告白 / 伯远 / 晚风拂过告白季 / 3:45` + 7 行歌词 | 假 | `title: '晚风告白', artist: '伯远', album: '晚风拂过告白季',` | 专辑名"晚风拂过告白季"为编造；歌词 7 行手写（10/22/35/48/62/78 秒） |
| A7 | track_model.dart:152-172 | 曲目 3：`海阔天空 / Beyond / 乐与怒 / 5:24` + 9 行歌词 | 真假混杂 | `title: '海阔天空', artist: 'Beyond', album: '乐与怒',` | 曲名/乐队/专辑真实；封面为 Unsplash 无关照片；歌词为手写录入，无版权来源 |
| A8 | track_model.dart:173-191 | 曲目 4：`夜的第七章 / 周杰伦 / 依然范特西 / 4:36` + 7 行歌词 | 真假混杂 | `title: '夜的第七章', artist: '周杰伦', album: '依然范特西',` | 同上：人名专辑真实，封面/歌词/音源全为手写 |
| A9 | track_model.dart:192-208 | 曲目 5：`City of Stars / Ryan Gosling & Emma Stone / La La Land OST / 2:58` | 真假混杂 | `title: 'City of Stars', artist: 'Ryan Gosling & Emma Stone',` | 同上 |
| A10 | track_model.dart:209-227 | 曲目 6：`起风了 / 买辣椒也用券 / 起风了 / 5:12` + 7 行歌词 | 真假混杂 | `title: '起风了', artist: '买辣椒也用券',` | 同上 |
| A11 | track_model.dart:117/138/157/178/197/214 | 6 首封面全部为 `images.unsplash.com` 照片 | 假 | `coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',` | 与歌曲/专辑**无任何对应关系**，是随机风景/人像照片 |
| A12 | track_model.dart:120/160/200/217 | 4 首曲目在**模型里直接写死** `isFavorite: true` | 假 | `source: 'preset-flac', isFavorite: true,` | 常量级"已收藏"，与用户行为无关 |
| A13 | app/lib/core/audio/audio_player_service.dart:19 | 播放队列初值 = 6 首 mock 曲目 | 假 | `final List<Track> _playlist = List.from(mockPresetTracks);` | 应用启动即"有"一个 6 首歌单 |
| A14 | audio_player_service.dart:21 | "我喜欢的音乐"默认 4 首（track-1/3/5/6） | 假 | `final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};` | 用户从未红心，收藏页已显示"共收藏 4 首心动单曲" |
| A15 | audio_player_service.dart:76-80 | 冷启动"播放历史"里已有一条记录 | 假 | `AudioPlayerService() { if (_playlist.isNotEmpty) { _recordHistory(_playlist[0]); } }` | 用户没播过任何歌，播放历史页已显示 1 条 |
| A16 | audio_player_service.dart:305-329 | 播放进度条会走、歌词会滚 | 假 | `_positionTicker = Timer.periodic(const Duration(milliseconds: 50), (timer) { ... _position = nextPos; });` | 注释自称"60fps 高刷进度驱动"，实为**纯计时器模拟**，与音频解码无关 |
| A17 | app/pubspec.yaml:30-46 + pubspec.lock | 应用支持"播放音乐" | 假 | pubspec 依赖仅 `http / dio / provider / go_router / intl / shared_preferences / crypto / path_provider / path`；grep `audioplayers|just_audio|media_kit|audio_service` 在 pubspec.lock 中 **0 命中** | **没有音频播放依赖**，无论 mock 还是在线曲目都不可能发声 |
| A18 | grep `audioUrl` 全仓 | 在线曲目带有真实播放地址 | 假(未接线) | `audioUrl` 只出现在 `track_model` / `sync_data_model` / `lx_source_model` / `online_music_service` 的**赋值与序列化**中（track_model.dart:55/68/82/95、online_music_service.dart:63/73/132/142 等），无任何读取方用于播放 | 字段是"装饰性"的，没有任何消费方 |

### B. "歌手"数据（热门歌手页 / 歌手详情页）

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| B1 | desktop_views.dart:611-616 | 4 位歌手列表 + 粉丝数 | 假 | `final artists = [ {'name': '巫娜', 'fans': '86.4万', ...}, {'name': '周杰伦', 'fans': '3890.2万', ...}, {'name': 'Beyond', 'fans': '1240.8万', ...}, {'name': '伯远', 'fans': '512.6万', ...} ];` | 粉丝数为手写字符串常量，无任何 API 来源 |
| B2 | mobile_pages.dart:431-436 | 移动端同一份列表（同名同粉丝数） | 假 | `{'name': '巫娜', 'fans': '86.4万', 'img': '...unsplash...'},` | 同一份编造数据在两处各复制一份 |
| B3 | desktop_views.dart:185-188 | 发现页"热门入驻与关注歌手"头像环 | 假 | `_buildArtistAvatar(context, '巫娜', '古琴演奏家', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80', ...)` | 头像为 Unsplash 陌生模特照 |
| B4 | 取证见 §5 | 上述 4 张"艺人头像"的实际画面 | 假 | 下载 `photo-1534528741775` 得**蓝紫打光的年轻女性肖像**；`photo-1507003211169` 为白人男性微笑照；`photo-1500648767791` 为白人男性肖像；`photo-1492562080023` 为户外年轻男性 | 与"巫娜（中国古琴演奏家）/ 周杰伦 / Beyond（4 人乐队）/ 伯远"**无任何一人对应** |
| B5 | desktop_views.dart:612-615 | 歌手身份标签："古琴演奏家 / 音乐制作人""华语流行音乐天王""传奇殿堂级摇滚乐队""流行歌手 / 唱跳创作人" | 部分真 | `'role': '华语流行音乐天王',` | 称号来源于常识，非数据 |
| B6 | desktop_views.dart:643-649 | 每位歌手名字后跟一个"认证"蓝勾 `Icons.verified_rounded` | 假 | `Icon(Icons.verified_rounded, size: 16, color: theme.accentColor),` | 无条件渲染，无任何认证接口 |
| B7 | desktop_views.dart:719 | 歌手详情页副标题"官方认证音乐人 · 粉丝量 189.4万 · 单曲播放突破 1.2 亿" | 假 | `Text('官方认证音乐人 · 粉丝量 189.4万 · 单曲播放突破 1.2 亿', ...)` | **对所有歌手都一样**（页面收到的 `artistName` 只用于标题），189.4万/1.2亿 纯编造；与列表页 86.4万 自相矛盾 |
| B8 | mobile_pages.dart:536 | 移动端歌手详情"官方认证音乐人 · 粉丝量 189.4万" | 假 | `Text('官方认证音乐人 · 粉丝量 189.4万', ...)` | 同上 |
| B9 | desktop_views.dart:702-705 / mobile_pages.dart:525-528 | 歌手详情页头像 | 假 | `const MellowAvatar(radius: 60, url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&q=80')` | **无论点进哪位歌手，头像都是同一张图**（且该图还同时被当作产品页"用户头像"） |
| B10 | desktop_views.dart:751-776 / mobile_pages.dart:554-571 | 歌手详情页"代表作列表" | 假 | `...mockPresetTracks.map((t) => SoftCard(...))` | **不论哪位歌手的详情页，代表作都是同样 6 首 mock 曲目** |
| B11 | desktop_views.dart:676 / mobile_pages.dart:499 | 进入详情页默认"已关注" | 假 | `bool _isFollowing = true;` | 用户从未关注任何歌手，按钮初始即"已关注" |

### C. 排行榜（巅峰榜）

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| C1 | desktop_views.dart:354-387 | 4 个榜单卡片（飙升榜/热歌榜/新歌榜/原创榜） | 假 | `final charts = [ {'title': '飙升榜', 'desc': '近24小时全网播放量暴涨', ...}, {'title': '热歌榜', ...}, {'title': '新歌榜', ...}, {'title': '原创榜', ...} ];` | 榜单为方法内局部常量数组 |
| C2 | desktop_views.dart:358 / 366 / 374 / 382 | "每日09:00更新 · 100首" / "每周四更新 · 200首" / "每日更新 · 100首" / "每周五更新 · 50首" | 假 | `'update': '每日09:00更新 · 100首',` | 静态文案，**没有任何定时任务/接口**；条数 100/200/100/50 与实际返回的 6 首完全不符 |
| C3 | desktop_views.dart:530-532 | 每个榜单卡片右侧展示"Top 5" | 假 | `final trackIndex = (idx * 3 + i) % mockPresetTracks.length;` | 用**取模公式**从同 6 首池子里错位取 5 首，制造"不同榜单"的错觉 |
| C4 | desktop_views.dart:408-412 | "播放全部榜单"按钮 | 假 | `if (mockPresetTracks.isNotEmpty) { player.playPlaylist(mockPresetTracks); }` | 4 个榜单点进去播的都是同一套 6 首 |
| C5 | desktop_views.dart:435-439 | 点榜单卡片播放 | 假 | `player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);` | 同上 |
| C6 | mobile_pages.dart:304 | 移动端榜单名数组 | 假 | `final charts = ['飙升榜', '热歌榜', '新歌榜', '原创榜'];` | 仅剩 4 个字符串 |
| C7 | mobile_pages.dart:340-348 | 移动端每个榜单展示 3 首 | 假 | `final t = mockPresetTracks[(idx + i) % mockPresetTracks.length];` | 同为取模复用 |
| C8 | mobile_pages.dart:326-328 / 396-398 | 播放行为 | 假 | `player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);` | 同 C5 |
| C9 | lx_script_sandbox.dart:241-275 | 真实音源引擎里的榜单 | 假 | `LxLeaderboard(id: 'mellow_top_rise', name: 'Mellow 飙升巅峰榜', ... updateTime: '每日 06:00 更新', total: 100,)` | 与 UI 文案**互相矛盾**（06:00 vs 09:00），且 `getLeaderboardDetail` 返回 `songs: _presetSongs`（5 首） |
| C10 | lx_script_sandbox.dart:279-295 / 500-517 | 榜单详情 | 假 | `return LxLeaderboardDetail(board: board, songs: _presetSongs, page: page, limit: limit);` | 4 个榜单详情返回**完全相同**的 5 首；`limit` 参数被接收但不生效 |

### D. 歌单广场 / 推荐歌单

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| D1 | desktop_views.dart:144-172 | 4 张"甄选歌单"卡片 + 播放量 | 假 | `_buildPlaylistCard(context, '东方禅境 · 幽篁古筝琴韵精选', '48.6万播放 · 巫娜 / 常静', ...)` / `'129.4万播放 · 周杰伦 / 伯远'` / `'98.2万播放 · Beyond / 张国荣'` / `'34.1万播放 · La La Land OST'` | 播放量为手写常量，无数据源 |
| D2 | desktop_views.dart:149/156/163/170 | 4 张卡片点击播放 | 假 | `() => player.playTrack(mockPresetTracks[0])` … `mockPresetTracks[4]` | 点"歌单"实际只播单曲，歌单内容并不存在 |
| D3 | desktop_views.dart:273-274 | 歌单广场 7 个分类标签（精选推荐/华语流行/沉静治愈/古风雅乐/经典粤语/深夜爵士/纯音乐） | 假 | `final List<String> _tags = ['精选推荐', '华语流行', '沉静治愈', ...];` | 切换分类只改高亮（`:303` `onTap: () => setState(() => _activeTag = tag)`），**不过滤数据** |
| D4 | desktop_views.dart:310-338 | 歌单广场网格 | 假 | `itemCount: mockPresetTracks.length, ... final t = mockPresetTracks[idx];` | 所谓"歌单"就是 6 张单曲卡片 |
| D5 | desktop_views.dart:992 | 栏目文案"支持网易云音乐、QQ音乐分享链接与 ID 一键秒级抓取导入" | 假 | `Text('支持网易云音乐、QQ音乐分享链接与 ID 一键秒级抓取导入', ...)` | 实际只有网易云一个未鉴权的旧接口（见 §4-1/4-2），QQ 音乐从未实现 |
| D6 | lx_script_sandbox.dart:303-331 | 音源引擎里的 3 个歌单 + 播放量 1289000 / 893000 / 2450000 | 假 | `playCount: 1289000,` … `title: '高燃流行电音：赛博都市漫游指南',` | 播放量为编造整数 |
| D7 | lx_script_sandbox.dart:334-342 | 歌单详情 | 假 | `return LxPlaylistDetail(playlist: pl, songs: _presetSongs);` | 3 个歌单详情返回同一批 5 首 |
| D8 | lx_script_sandbox.dart:519-545 | 各平台"精选高分歌单" | 假 | `title: '$platformName 精选高分歌单', ... playCount: 660000,` | 5 个平台共享同一个"资深乐评人"和 66 万播放量 |
| D9 | index.html:1602-1651 | Web 原型 6 个歌单 + plays | 假 | `plays: "2,410,920",` / `"892,100"` / `"5,302,400"` / `"643,800"` / `"312,500"` / `"4,120,000"` | 全部硬编码 |
| D10 | index.html:2112-2117 | Web 原型"发现"页 6 个歌单 + "98.2万 / 142万 / 64.5万 / 210万 / 43.1万 / 88.9万播放" | 假 | `{ title: "深夜治愈所 · 晚安白噪音", tag: "助眠", plays: "98.2万", cover: "...unsplash..." }` | 全部硬编码 |
| D11 | mobile.html:2273-2280 | 移动端原型歌单广场 6 项 | 假 | `{ id: 0, title: "流行热歌速递 · 华语榜首", curator: "Mellow 精选", count: "38 首", ... }` | curator/曲目数为编造 |
| D12 | mobile.html:2422-2425 | 播客列表 + `plays` | 假 | `{ title: "Vol.128 深夜爵士与威士忌的低语", author: "Mellow Radio", duration: "42:15", plays: "48.2万", ... }` | 播客名称/作者/播放量全部硬编码 |
| D13 | desktop_views.dart:792-797 | "声音电台"4 个节目 | 假 | `{'title': '深夜治愈故事馆', 'sub': '伴你入眠的温暖声音', 'img': '...unsplash...'}, ...` | 节目为文案常量；点击播的是 mock 曲目 |
| D14 | desktop_views.dart:818-821 | 电台卡片点击 | 假 | `player.playTrack(mockPresetTracks[idx % mockPresetTracks.length]);` | 电台并非音频 |
| D15 | mobile_pages.dart:369-374 | 移动端电台 4 项 | 假 | `{'title': '深夜治愈故事馆', 'sub': '温暖伴眠精选'}, ...` | 硬编码 |
| D16 | mobile_tabs.dart:632-657 | "新碟与精选专栏"4 张专辑卡 | 假 | `{'title': 'Hurry Up, Dreaming', 'artist': 'M83', 'year': '2011 · 电子梦幻', 'cover': '...'}` | 专辑名有拼写错误（M83 专辑实为 *Hurry Up, We're Dreaming*），年份/风格为手写 |
| D17 | mobile_tabs.dart:677-688 | "全部 48 专" | 假 | `Text('全部 48 专', ...)` | 实际只有 4 张卡片 |
| D18 | mobile_tabs.dart:894 | "4 位入驻音乐人" | 假 | `Text('4 位入驻音乐人', ...)` | 与写死的 4 条艺人常量对应 |

### E. 同步中心（WebDAV + 局域网）

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| E1 | desktop_views.dart:1414-1415 | "云端端点: https://dav.jianguoyun.com/dav/" + "绑定账号: gaore@mellow.music" | 假 | `final String _serverUrl = 'https://dav.jianguoyun.com/dav/';` `final String _username = 'gaore@mellow.music';` | 端点是**坚果云公共地址**（非用户私有），账号是编造的演示邮箱，且页面**没有任何输入框可修改**，也没有密码字段 |
| E2 | desktop_views.dart:1417-1435 | 点"立即云端备份" → 转圈 900ms → "同步成功！已热备全量数据" + SnackBar"已成功将本地播放数据、收藏及歌单备份至 WebDAV 云端！" | 假 | `await Future.delayed(const Duration(milliseconds: 900)); ... _syncStatusText = '同步成功！已热备全量数据';` | **完全没有网络请求**，是定时器伪造的成功态 |
| E3 | desktop_views.dart:1437-1455 | 点"从云端恢复" → 900ms → "拉取完成！数据已合并" + SnackBar | 假 | `await Future.delayed(const Duration(milliseconds: 900)); ... _syncStatusText = '拉取完成！数据已合并';` | 同上，文案里的 "LWW合并" 是假的 |
| E4 | desktop_views.dart:1412 | 状态初始值"就绪 · 待同步" | 假 | `String _syncStatusText = '就绪 · 待同步';` | 常量初始值 |
| E5 | desktop_views.dart:1627-1632 | 绿色徽标"服务就绪" | 假 | `const Row(children: [Icon(Icons.check_circle_rounded, size: 14, color: Colors.green), SizedBox(width: 4), Text('服务就绪', ...)])` | 无条件渲染，与 E2/E3 的假动作相互背书 |
| E6 | desktop_views.dart:1525-1526 | 指标卡"4 首 / 已同步红心收藏" | 假 | `Text('$favCount 首', ...)` + `Text('已同步红心收藏', ...)` | 数字来自 A14 的硬编码收藏集合，"已同步"是假的（从未同步） |
| E7 | desktop_views.dart:1684-1689 | "后台自动定时同步 (每 30 分钟)" 开关 | 假 | `Switch.adaptive(value: _isAutoSync, ... onChanged: (v) => setState(() => _isAutoSync = v))` | 只切换本地 bool，**从未启动任何定时器**（`WebDavSyncService.startAutoSync` 无人调用） |
| E8 | desktop_views.dart:1733 | "本机端口: 18585 监听中" | 假 | `Text('本机端口: 18585 监听中', style: ...)` | 与代码实际端口不符：`lan_sync_service.dart:112` `int _port = 23332;`，默认参数处处为 23332（`:130` `int port = 23332,`、`:285`、`:327`、`:352`、`:379`）。且 LAN 服务**从未被启动**（见 E14） |
| E9 | desktop_views.dart:1755 | 设备"Gaore 的 iPhone 15 Pro" | 假 | `Text('Gaore 的 iPhone 15 Pro', ...)` | 硬编码字符串，非扫描结果 |
| E10 | desktop_views.dart:1766 | "IP: 192.168.1.103 · iOS 17.5 · Mellow v2.1.0" | 假 | `Text('IP: 192.168.1.103 · iOS 17.5 · Mellow v2.1.0', ...)` | IP/系统版本/App 版本全为常量；且 pubspec.yaml:19 真实版本是 `1.0.0+1` |
| E11 | desktop_views.dart:1757-1763 / 1801-1807 | 设备前绿色圆点 + "在线" | 假 | `decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),` `Text('在线', ...)` | 无条件渲染 |
| E12 | desktop_views.dart:1770-1779 | "投送当前播放列表" → SnackBar"已向 Gaore 的 iPhone 15 Pro 成功投送当前播放列表！" | 假 | `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已向 Gaore 的 iPhone 15 Pro 成功投送当前播放列表！')));` | 无任何网络投送，仅弹提示；目标设备本身不存在 |
| E13 | desktop_views.dart:1799 / 1810 / 1814-1822 | "客厅立体声音响 (HomePod)" + "IP: 192.168.1.108 · 无损立体声流媒体投送" + "无线音频接力" → "已接力音频流至客厅立体声音响！" | 假 | `Text('IP: 192.168.1.108 · 无损立体声流媒体投送', ...)` `const SnackBar(content: Text('已接力音频流至客厅立体声音响！'))` | 第二个假设备 + 假投送提示 |
| E14 | grep `LanSyncService|LanSyncServer|startServer` | 局域网 P2P 能力 | 假(未接线) | 命中全部位于 `lan_sync_service.dart` 自身（`:110`、`:411`、`:433` 等），`main.dart:12-17` 只注册 `ThemeProvider / AudioPlayerService / EqualizerManager`；UI 中无任何引用 | 整个 LAN 同步模块是**从未启动的死代码** |
| E15 | grep `WebDavSyncService|WebDavConfig` | WebDAV 真实同步能力 | 假(未接线) | 命中全部在 `webdav_sync_service.dart` 自身（`:22`、`:160`、`:171` 等）；`desktop_views.dart` 的同步页**完全不引用**该服务 | 真实实现被绕过，用户看到的是 E2/E3 的假动作 |

### F. 播放历史 / 收藏

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| F1 | audio_player_service.dart:76-80 | 历史页启动即有 1 条"云水禅心" | 假 | `AudioPlayerService() { if (_playlist.isNotEmpty) { _recordHistory(_playlist[0]); } }` | 用户零操作即产生历史 |
| F2 | desktop_views.dart:1113-1138 | "播放足迹历史"列表 | 真假混杂 | `...player.playHistory.map((t) => SoftCard(...))` | 渲染逻辑真实，但初值来自 F1 的假记录 |
| F3 | audio_player_service.dart:296-302 | 历史容量上限 50 条 | 真 | `if (_playHistory.length > 50) { _playHistory.removeLast(); }` | 去重 + 截断逻辑真实 |
| F4 | audio_player_service.dart:21 / 53-67 | "我喜欢的音乐"共 4 首 | 假 | `final Set<String> _favoriteIds = {'track-1', 'track-3', 'track-5', 'track-6'};` | 默认 4 首收藏；其中 track-1/3/5/6 = 云水禅心/海阔天空/City of Stars/起风了 |
| F5 | desktop_views.dart:891 | "共收藏 4 首心动单曲 · 实时云端同步" | 假 | `Text('共收藏 $favTracks.length 首心动单曲 · 实时云端同步', ...)` | 数字真、后缀"实时云端同步"为假（无同步） |
| F6 | mobile_tabs.dart:857-928 | 移动端"已收藏 N 首心动单曲" | 真假混杂 | `final favCount = player.playlist.where((t) => player.isFavorite(t.id)).length;` | 计数来自同一假集合 |
| F7 | audio_player_service.dart:207-218 | 红心收藏功能本身 | 真 | `void toggleFavorite([String? trackId]) { ... _favoriteIds.add(id); }` | **会话内**可正常增删（但不持久化，无 SharedPreferences 调用） |
| F8 | grep `SharedPreferences` → app/lib **0 命中** | 收藏/历史会被保存 | 假 | pubspec.yaml:41 声明了 `shared_preferences: ^2.5.5`，但代码中**从未 import 或调用** | 重启即全部还原为 A14/F1 的硬编码初始值 |

### G. 本地与下载

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| G1 | desktop_views.dart:1170-1175 | 按钮"选择本地文件夹扫描" | 假(未接线) | `SoftButton(label: '选择本地文件夹扫描', icon: Icons.folder_open_rounded, isPill: true, onTap: () {},)` | **onTap 是空函数**，点击无任何反应 |
| G2 | grep `file_picker|FilePicker|Directory(|dart:io` → app/lib | 本地文件系统扫描能力 | 假 | `dart:io` 仅在 `lan_sync_service.dart:3` 出现（用于 HTTP Server）；`pubspec.yaml` 中**无 file_picker / file_selector**，也无任何文件遍历调用 | 没有任何文件选择/遍历能力 |
| G3 | desktop_views.dart:1166 | "拖拽音频文件或文件夹至此，或点击导入" | 假 | `Text('拖拽音频文件或文件夹至此，或点击导入', ...)` | 桌面端**未实现任何 DragTarget / DropTarget**（grep `DragTarget` 在 app/lib **0 命中**） |
| G4 | desktop_views.dart:1168 | "支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式" | 假 | `Text('支持 FLAC, APE, WAV, MP3, OGG, DSD 无损音频格式', ...)` | 无解码器，格式列表无意义 |
| G5 | desktop_views.dart:1180-1202 | "已解析本地曲目"列表 | 假 | `...mockPresetTracks.map((t) => SoftCard(...))` | 列表内容 = A 组的 6 首 mock 曲目，从未解析过任何本地文件 |
| G6 | desktop_views.dart:1195 | 每行副标题"FLAC 24bit/96kHz · 42.8 MB" | 假 | `Text('FLAC 24bit/96kHz · 42.8 MB', style: ...)` | **6 行全部同一串常量**，不随曲目变化 |
| G7 | mobile_pages.dart:611 | "已缓存 6 首无损音频 · 占用空间 182 MB" | 假 | `Text('已缓存 6 首无损音频 · 占用空间 182 MB', ...)` | 编造容量；与 G6 的 42.8MB×6=256.8MB 也自相矛盾 |
| G8 | mobile_pages.dart:629 | 每行"FLAC 24bit · 42.8 MB" | 假 | `Text('FLAC 24bit · 42.8 MB', ...)` | 同上，全行同一常量 |
| G9 | desktop_views.dart:1159-1178 | "拖拽导入"凹槽 | 假 | `RecessedWell(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.file_upload_outlined, ...)` | 纯装饰容器 |
| G10 | index.html:3032 | Web 原型"已导入本地曲目"列表 | 假 | `const displayList = localSongs.length > 0 ? localSongs : SONGS.slice(0, 6);` | 无本地文件时，直接把在线歌单前 6 首当作"本地曲目"展示 |
| G11 | index.html:3055-3058 | 点"扫描本地曲库" → toast"本地磁盘扫描完成，已同步 6 首无损曲目" | 假 | `function scanLocalDemoFiles() { showToast('本地磁盘扫描完成，已同步 6 首无损曲目', ...); renderLocalSongs(); }` | 函数名自带 **Demo**，不扫描任何磁盘 |
| G12 | index.html:1057 / 2998-3027 | Web 原型确实有 `<input type="file">` + 拖拽处理 | 真（但播放仍假） | `<input type="file" id="localAudioFileInput" accept="audio/*" multiple onchange="handleLocalFiles(this.files)" class="hidden">` / `const url = URL.createObjectURL(file);` | 能取到文件名并生成 blob URL，**但 `fileUrl` 全程无消费方**（grep `fileUrl` 仅 `index.html:3013` 一处赋值，从不读取），播放仍走合成器 |
| G13 | mobile.html:2660-2667 | 移动端原型本地曲目 6 条 | 假 | `{ id: 101, title: "晴天 (无损离线版).flac", artist: "周杰伦", size: "32.4 MB", time: "04:29", idx: 0 }` | 全部硬编码，无文件选择入口 |

### H. 音源管理（LX / QuickJS）

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| H1 | desktop_views.dart:1348-1349 | 标题"自定义音源管理 (QuickJS)" / "原生兼容 LX-Music 六音脚本生态规范" | 假 | `Text('自定义音源管理 (QuickJS)', ...)` `Text('原生兼容 LX-Music 六音脚本生态规范', ...)` | **无 QuickJS 依赖**（pubspec 无 flutter_js / quickjs / jscore / flutter_qjs），不存在 JS 引擎 |
| H2 | desktop_views.dart:1352-1358 | 按钮"在线导入音源链接" | 假(未接线) | `SoftButton(label: '在线导入音源链接', icon: Icons.add_link_rounded, isActive: true, isPill: true, onTap: () {},)` | **onTap 空函数** |
| H3 | desktop_views.dart:1378-1383 | "内置综合聚合音源 (Built-in)" + 徽标"v2.1.0 · 运行中" | 假 | `Text('内置综合聚合音源 (Built-in)', ...)` `child: Text('v2.1.0 · 运行中', ...)` | 版本号取自 `lx_script_sandbox.dart:375` `version: version ?? '2.1.0'` 的默认值；"运行中"是写死文本 |
| H4 | desktop_views.dart:1391 | 音源启用开关（显示为"开"） | 假(未接线) | `Switch.adaptive(value: true, activeTrackColor: theme.accentColor, onChanged: (_) {})` | value 恒为 true，onChanged 空实现，**开关不可用** |
| H5 | desktop_views.dart:1331-1397 | 整个音源管理页 | 假 | 组件内只有 `context.watch<ThemeProvider>()`，**没有任何音源引擎/Provider 引用** | 页面展示的 1 个音源卡片与 `LxSourceEngine` 注册的 6 个音源完全无关 |
| H6 | grep `LxSourceEngine|resolveMusicUrlWithFallback|getMusicUrl` | 音源解析能力 | 假(未接线) | 命中全部在 `lx_script_sandbox.dart` 自身（`:727` 类定义、`:1040` 方法定义、`:20/:189/:425/:640` 接口与实现），**无任何 UI/服务调用** | 38KB 的音源引擎是死代码 |
| H7 | lx_script_sandbox.dart:354 | 各平台"曲库" | 假 | `final List<LxSongInfo> _mockDatabase;` | 字段名直接叫 mock |
| H8 | lx_script_sandbox.dart:355-356 / 392-399 / 426-433 | 搜索/换源"网络故障"与"延迟" | 假 | `final bool simulateFailure; // 是否刻意模拟网络故障用于测试容错` `final Duration latency; // 模拟网络延迟` `throw LxSourceException('$platformName 模拟搜索网络故障 (503 Service Unavailable)', ...)` | 故障是**刻意模拟**的，不是真实网络 |
| H9 | lx_script_sandbox.dart:57-135 | "润音官方高保真源"曲库 | 假 | `LxSongInfo(id: 'mellow_001', title: '云水禅心', artist: '古筝佛音', album: '禅茶一味', ...)` | 5 首虚构曲目（"古筝佛音""江南笛韵""夜曲漫步者""橘子海浪""霓虹波浪"均为编造艺人名） |
| H10 | lx_script_sandbox.dart:204-205 | 无损直链 | 假 | `return 'https://stream.mellowmusic.io/${song.source}/${song.songMid}/audio_$qTag.flac';` | 域名 `stream.mellowmusic.io` 为编造，无真实 CDN |
| H11 | lx_script_sandbox.dart:210-231 | 歌词 | 假 | `[00:02.00]词/曲：Mellow 官方声学工坊` `[00:04.50]编曲：Modern Soft Sound Studio` | 模板化假歌词 + 假词曲作者 |
| H12 | lx_script_sandbox.dart:452 | 各平台换源直链 | 假 | `return 'https://cdn.$platformId.music.net/media/${targetSong.songMid}_${quality.value}.mp3';` | `cdn.kw.music.net` 等域名不存在 |
| H13 | lx_script_sandbox.dart:465-473 | 各平台歌词 | 假 | `lyric: '[00:00.00]${target.title} - ${target.artist} ($platformName 版)\n' '[00:05.00]流光溢彩，微风轻抚过耳际\n'` | 对所有歌曲返回同一段模板歌词 |
| H14 | lx_script_sandbox.dart:616-637 | 自定义脚本搜索结果 | 假 | `final mockSong = LxSongInfo(id: '${metadata.id}_${md5Hash(query).substring(0, 8)}', ... artist: '${metadata.name} 精选', album: '${metadata.name} 专属专辑', ...);` | 用 query 的 MD5 前 8 位**现编**一个歌名/歌手/专辑，冒充脚本解析结果 |
| H15 | lx_script_sandbox.dart:646 | 自定义脚本音源直链 | 假 | `return 'https://custom-cdn.${metadata.id}.com/stream/${song.songMid}/${quality.value}.mp3';` | 编造域名 |
| H16 | lx_script_sandbox.dart:653 | 自定义脚本歌词 | 假 | `lyric: '[00:00.00]${song.title} - ${song.artist}\n[00:04.00]由自定义音源脚本 [${metadata.name}] 解析提供'` | 模板文本 |
| H17 | lx_script_sandbox.dart:681-695 | 自定义脚本榜单 | 假 | `title: '榜首热歌', artist: '独立唱作人', album: '年度精选',` | 编造占位曲目 |
| H18 | lx_script_sandbox.dart:574-599 | 脚本"安全检查" | 假 | `if (metadata.scriptContent!.contains('eval(') && metadata.scriptContent!.contains('process.exit')) { throw const LxSourceException('脚本存在不安全的操作标识', ...); }` | 用字符串 contains 做"风控"，**任何脚本都不会被执行**（无 JS 运行时），校验形同虚设 |
| H19 | lx_script_sandbox.dart:846-963 | "初始化官方六大音源维度" | 假 | `// 1. 官方无损源 (mellow) registerDriver(MellowPresetSourceDriver()); ... mockSongs: sampleSongs.map((s) => s.copyWith(source: LxPlatformId.kw)).toList(),` | 同一批 5 首 sampleSongs 被 `copyWith(source:)` 复制成 5 个平台的"曲库"（曲名完全相同） |

### I. 移动端 UI 装饰

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| I1 | mobile_scaffold.dart:104-113 | 顶部状态栏时钟 **10:09** | 假 | `Text('10:09', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: theme.textPrimary, letterSpacing: -0.2,))` | 完全写死，不读系统时间、无 Timer；与真实系统时间不符 |
| I2 | mobile_scaffold.dart:174-183 | 信号 / WiFi / 充电电池图标 | 假 | `Icon(Icons.signal_cellular_alt_rounded, size: 15, ...), Icon(Icons.wifi_rounded, size: 15, ...), Icon(Icons.battery_charging_full_rounded, size: 17, ...)` | 三个图标为恒定装饰，不读取任何设备状态 |
| I3 | mobile_tabs.dart:72-90 | "发现音乐"旁的 "Mobile" 浅蓝胶囊 | 假 | `child: const Text('Mobile', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w700))` | 常量角标（`const`），用于标识原型而非真实平台信息 |
| I4 | mobile_tabs.dart:124-139 / 950-962 | 用户头像为 Unsplash 图 | 假 | `url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80'` | 与 B 组"艺人头像"**是同一张图**，同时充当用户头像 |
| I5 | mobile_tabs.dart:969-977 | 用户名"Mellow 音乐探索家" + "PRO" 徽章 | 假 | `Text('Mellow 音乐探索家', ...)` `child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))` | 硬编码用户名与会员等级，无登录体系 |
| I6 | mobile_scaffold.dart:52-63 | 顶部自绘"灵动岛"状态栏 | 假 | `_buildDynamicIslandHeader(context),` | 伪状态栏，与系统状态栏无关联 |
| I7 | mobile_tabs.dart:308-315 | "更新于 06:00" | 假 | `Text('更新于 06:00', ...)` | 常量 |
| I8 | mobile_pages.dart:64-66 | "专属声学日推 · 每日 06:00 更新" / "今日契合度 99.4% · 已匹配 6 首温润曲目" | 假 | `Text('今日契合度 99.4% · 已匹配 6 首温润曲目', ...)` | 99.4% 为编造；注：日历卡 `now.month`/`now.day`（mobile_pages.dart:22/:54-55）倒是真的系统时间 |
| I9 | mobile_pages.dart:78 | 按钮"播放全部 (6首)" | 真假混杂 | `label: '播放全部 (6首)',` | "6" 恰好等于 mockPresetTracks.length，是巧合式硬编码 |
| I10 | mobile_tabs.dart:331 | 雷达大卡副标题"周杰伦 / 告五人 / M83" | 假 | `subtitle: '周杰伦 / 告五人 / M83',` | 常量，与卡片实际播放内容（playlist[0]）无关 |
| I11 | mobile_tabs.dart:350-411 | 4 张小卡"午夜霓虹 M83 / 慢冷治愈 梁静茹 / Golden Hour JVKE / 爱在西元前 周杰伦" | 假 | `title: 'Golden Hour', artist: 'JVKE', coverUrl: '...unsplash...'` | 曲名歌手写死；点击播放的是 playlist[1..3]（完全不同的歌） |
| I12 | mobile_tabs.dart:355-361 | "午夜霓虹"点击逻辑 | 假 | `final t = player.playlist.firstWhere((x) => x.title.contains('Midnight') || x.artist.contains('M83'), orElse: () => mockPresetTracks[0]);` | 曲库中根本没有 M83/Midnight，**必然 fallback 到云水禅心**（起风了等 6 首中无匹配） |

### J. 搜索

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| J1 | modals.dart:475 | 热搜标签"周杰伦 / 告五人 / 落日飞车 / 陈奕迅 / 轻音乐 / 粤语经典" | 假 | `final List<String> _hotTags = ['周杰伦', '告五人', '落日飞车', '陈奕迅', '轻音乐', '粤语经典'];` | 写死标签，非热搜榜 |
| J2 | modals.dart:478-481 | 打开搜索即显示"结果" | 假 | `void initState() { super.initState(); _results = mockPresetTracks; }` | 未输入任何关键词就列出 6 首 mock 曲目 |
| J3 | modals.dart:495-501 | 清空输入框后恢复 | 假 | `if (clean.isEmpty) { setState(() { _results = mockPresetTracks; _isLoading = false; }); return; }` | 同 J2 |
| J4 | modals.dart:503-508 | 本地即时匹配 | 真（但底库是假） | `final localMatches = mockPresetTracks.where((t) => t.title.toLowerCase().contains(clean.toLowerCase()) || t.artist.toLowerCase().contains(...) || t.album.toLowerCase().contains(...)).toList();` | 匹配算法真的可用，只是可匹配集合只有 6 首假数据 |
| J5 | modals.dart:516-533 | 350ms 防抖后"全网检索" | 真（网络真，降级静默） | `_debounce = Timer(const Duration(milliseconds: 350), () async { final onlineSongs = await OnlineMusicService.searchOnlineTracks(clean); ...` | 真的会发 HTTP（见 §4-1） |
| J6 | modals.dart:519-532 | 在线搜索失败时 | 假(静默降级) | `setState(() { _isLoading = false; if (onlineSongs.isNotEmpty) { ...合并... } });` —— `if` **无 else**：失败/空结果时保持 `_results = localMatches` | 用户看到的是"本地 mock 结果"，UI 不提示网络失败；若本地命中 0 则显示"无匹配结果"，**不会伪造新数据**（此点比 E2/E3 诚实） |
| J7 | modals.dart:650 / 686-703 | 在线结果的"在线音源"徽章 | 真 | `final isOnline = track.source.startsWith('netease');` | 依据真实 source 前缀判断，逻辑正确 |
| J8 | online_music_service.dart:60-61 | 无封面时回落到 Unsplash | 假 | `final coverUrl = item['album']?['picUrl']?.toString() ?? 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80';` | 真实数据缺失时混入占位图 |
| J9 | online_music_service.dart:78-84 | 请求失败/超时 | 真（静默但不伪造） | `} catch (_) { // 网络波动或超时，静默返回空，由上层触发本地降级逻辑 } return [];` | 返回空数组，不伪造数据 |
| J10 | modals.dart:744-748 | "快速体验"预设：官方热歌榜 3778678 / 飙升巅峰榜 19723756 / 新歌推荐榜 3779629 | 真 | `{'title': '官方热歌榜', 'id': '3778678'},` | 这三个是**真实的网易云公开歌单 ID** |
| J11 | modals.dart:770-774 | 导入失败提示 | 真 | `_errorMsg = '解析失败，请检查歌单ID或网络连接';` | 失败时如实报错（见 §4-2） |

### K. Web 原型（index.html / mobile.html）

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| K1 | index.html:1475-1600 | 6 首歌曲（晴天/Midnight City/慢冷/Golden Hour/爱在西元前/Starboy） | 假 | `// Mock Song Catalog (Reflecting AlgerMusicPlayer Real Playlists)` `const SONGS = [ { id: 1, title: "晴天 (Sunny Day)", artist: "周杰伦", album: "叶惠美", duration: "04:29", durationSec: 269, cover: "...unsplash...", ... }` | 注释直接自认 Mock；曲目/时长/封面全部硬编码 |
| K2 | index.html:1486-1500 等 | 每首的"歌词" | 假 | `lyrics: [ { time: 0, text: "故事的小黄花 从出生那年就飘着" }, { time: 5, text: "童年的荡秋千 随记忆一直晃到现在" }, ... ]` | 手写歌词（部分接近原词，无来源） |
| K3 | index.html:1653-1660 | 6 位歌手 + 粉丝数 | 假 | `{ name: "周杰伦", fans: "1,290万 粉丝", img: "...unsplash..." }, { name: "Taylor Swift", fans: "3,890万 粉丝", ... }, { name: "告五人", fans: "450万 粉丝", ... }` | 粉丝数编造；头像为 Unsplash |
| K4 | index.html:1663-1836 | "播放"行为 | **假（合成器）** | `class ModernSoftAudioEngine { ... this.chords = [ [261.63, 329.63, 392.00, 493.88], // CMaj7 [220.00, 261.63, 329.63, 392.00], // Am7 ... ] ... triggerChord() { ... const osc = this.ctx.createOscillator(); ... } }` | **不是播放歌曲，而是用 Web Audio 振荡器循环演奏 6 个爵士和弦（每 2500ms 换一个，index.html:1827-1835）**；点任何歌听到的都是同一段和弦进行 |
| K5 | index.html:1774-1791 | 操作时的"叮"声 | 假 | `triggerChime() { ... [523.25, 659.25, 783.99].forEach((freq, i) => { const osc = this.ctx.createOscillator(); osc.type = 'sine'; ... }); }` | 3 音上行蜂鸣音效，非音乐 |
| K6 | index.html:1780 / 1807 | 振荡器 | 假 | `const osc = this.ctx.createOscillator();` | 无 `<audio>` / `new Audio()`（全文件 0 命中，grep 证据见 §8） |
| K7 | grep `fetch(|XMLHttpRequest|axios`（两 HTML） | 网络请求 | 假 | **两文件均 0 命中** | Web 原型**完全不联网**，所有内容一次写死在 HTML/JS 里 |
| K8 | index.html:1862 / 1870 | 默认"已收藏"和"播放历史" | 假 | `likedSongIds = JSON.parse(localStorage.getItem('alger_liked_songs') || '[0, 2, 4]');` `playHistory = JSON.parse(localStorage.getItem('alger_history') || '[{"songId":0,"time":"刚刚"}]');` | 首次打开即预置 3 首收藏 + 1 条"刚刚"的历史 |
| K9 | index.html:1848 / 2587 / 3075 / 3115 | 音量/主题/主色持久化 | 真 | `localStorage.setItem('alger_volume', currentVolume.toString());` `localStorage.setItem('alger_accent', color);` | 这三项是真持久化 |
| K10 | index.html:1848 / 1923-1925 | localStorage key 前缀 | 假(命名遗留) | `localStorage.getItem('alger_volume')` `localStorage.getItem('alger_theme')` `localStorage.getItem('alger_accent')` | 借用 "AlgerMusicPlayer" 的 key，暴露原型来源 |
| K11 | mobile.html:256 | 顶部时钟 10:09 | 假 | `<span class="text-[13px] font-bold tracking-tight text-slate-800 dark:text-slate-200">10:09</span>` | 写死 |
| K12 | mobile.html:2660-2667 | 本地 6 首 | 假 | `let localSongList = [ { id: 101, title: "晴天 (无损离线版).flac", artist: "周杰伦", size: "32.4 MB", time: "04:29", idx: 0 }, ... ];` | 列表含 `size` 字段但无对应文件 |
| K13 | mobile.html:2347-2372 | 4 个榜单 + 更新文案 | 假 | `{ name: "🚀 飙升排行榜 (Daily Surge)", tag: "每日 10:00 更新", color: "from-emerald-500/20 to-teal-500/5", songs: [0, 4, 1] }, ...` | 榜单直接由索引数组 `songs: [0,4,1]` 从同一个 SONGS 里取，4 个榜单共用 6 首歌 |
| K14 | mobile.html:2354-2371 | "热歌榜 (Mellow Hot 500)" / "每周独立策展" | 假 | `name: "🔥 热歌榜 (Mellow Hot 500)", tag: "全网播放 TOP"` | "Hot 500" 与实际 6 首数据矛盾 |
| K15 | mobile.html:2273-2280 | 歌单广场 6 项 | 假 | `{ id: 0, title: "流行热歌速递 · 华语榜首", curator: "Mellow 精选", count: "38 首", tag: "流行" }` | 硬编码 |
| K16 | mobile.html:2422-2425 | 播客 4 期 + 播放量 | 假 | `plays: "48.2万" / "92.6万" / "33.1万" / "120.4万"` | 编造 |
| K17 | mobile.html:1382-1392 / 1468-1495 | 移动端"播放" | **假（合成器）** | `this.ctx = new AudioContext();` … `const osc = this.ctx.createOscillator();` | 同 K4，Web Audio 合成 |
| K18 | mobile.html:2512 | 歌手数据 | 假 | `{ name: "周杰伦", ... }` | 与 index.html 同源的硬编码艺人数据 |
| K19 | index.html:1057 / 3167-3188 | Web 原型真实文件选择与拖拽 | 真 | `dropzone.addEventListener('drop', (e) => { e.preventDefault(); ... if (e.dataTransfer && e.dataTransfer.files.length > 0) { handleLocalFiles(e.dataTransfer.files); } });` | 文件读入是真的（见 G12）；但读入后不播放 |

### L. 其它硬编码（版本 / 端口 / URL / 时间 / 文案）

| # | 位置(文件:行) | 用户看到的内容 | 真实/假 | 证据（代码片段） | 影响 |
|---|---|---|---|---|---|
| L1 | desktop_views.dart:1383 与 pubspec.yaml:19 | 音源版本 "v2.1.0" vs 应用真实版本 `1.0.0+1` | 假 | `version: 1.0.0+1`（pubspec.yaml）/ `child: Text('v2.1.0 · 运行中', ...)` | 版本号多处互相矛盾（desktop_views.dart:1383 v2.1.0、:1766 "Mellow v2.1.0"、pubspec 1.0.0+1；另有 lx_script_sandbox.dart:143 `'2.0.0'`） |
| L2 | lx_script_sandbox.dart:143 vs :375 | 官方源版本 2.0.0，平台源版本 2.1.0 | 假 | `version: '2.0.0',` / `version: version ?? '2.1.0',` | 两套版本号并存 |
| L3 | desktop_views.dart:1733 vs lan_sync_service.dart:112 | 端口 18585 vs 23332 | 假 | `Text('本机端口: 18585 监听中', ...)` / `int _port = 23332;` | UI 展示端口与代码默认端口**不一致**；且服务未启动 |
| L4 | server.js:5 / :88-89 | 服务端端口 8088 | 真 | `const PORT = 8088;` `server.listen(PORT, '0.0.0.0', () => { ... })`（server.js:88-90，回调内打印监听地址） | 静态服务器真实可用（与 18585/23332 用途不同，但对外宣传易混淆） |
| L5 | lan_sync_service.dart:114-115 | 设备名"Mellow Desktop" / ID `mellow-server` | 真(默认值) | `String _deviceName = 'Mellow Desktop';` `String _deviceId = 'mellow-server';` | 默认值，可通过参数覆盖 |
| L6 | lan_sync_service.dart:256-266 | 6 位配对码生成 | 真（但非密码学安全） | `var seed = DateTime.now().millisecondsSinceEpoch; ... seed = (seed * 1103515245 + 12345) & 0x7fffffff;` | 线性同余伪随机，可预测；非假数据但安全性弱 |
| L7 | webdav_sync_service.dart:35-37 | 默认远程目录 `/mellow_music/`、文件名 `mellow_sync_snapshot.json`、间隔 30 分钟 | 真(默认值) | `this.remoteDirectory = '/mellow_music/',` `this.backupFileName = 'mellow_sync_snapshot.json',` `this.autoSyncInterval = const Duration(minutes: 30),` | 默认值真实 |
| L8 | modals.dart:206-208 | EQ 弹窗副标题"基于 libmpv firequalizer 高保真声学校准" | 假 | `Text('基于 libmpv firequalizer 高保真声学校准', ...)` | 无 mpv 依赖；`EqualizerManager.toLibmpvFilterString()`（equalizer_manager.dart:82）**全仓只有定义、0 处调用** |
| L9 | equalizer_manager.dart:17-79 | 10 段 EQ 可调、有 5 种预设 | 真假混杂 | `void applyPreset(EqualizerPreset preset) { ... _bandGains = [7.0, 5.5, 3.0, 1.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.5]; }` | 状态管理是真的，但**没有任何音频链路消费它**，调了不改变声音 |
| L10 | desktop_scaffold.dart:127-135 | 品牌名"Mellow Music · 润音" | 真 | `Text('Mellow Music · 润音', ...)` | 产品名常量，非假数据 |
| L11 | desktop_scaffold.dart:179-189 | 快捷键提示"Ctrl K" | 真假混杂 | `child: Text('Ctrl K', style: ...)` | 文案存在，但 grep `LogicalKeyboardKey|Shortcuts|RawKeyboard|Actions` 在 app/lib 无命中（见 §6），**快捷键未实现** |
| L12 | desktop_views.dart:78-81 | "精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出，实时声学生态律动" | 假 | `Text('精选 30 首私人流媒体高保真曲目，支持 24bit/192kHz 无损直出，实时声学生态律动', ...)` | "30 首"与实际 6 首矛盾；"24bit/192kHz 无损直出"无解码器支撑 |
| L13 | desktop_views.dart:61-64 | "根据您常听的古风与经典流行智能漫游" | 假 | `Text('根据您常听的古风与经典流行智能漫游', ...)` | 无任何听歌画像/推荐算法 |
| L14 | desktop_views.dart:398-401 | "汇聚全网多源权威数据，实时追踪流行脉搏" | 假 | `Text('汇聚全网多源权威数据，实时追踪流行脉搏', ...)` | 数据源只有 6 首本地常量 |
| L15 | desktop_views.dart:1018 | "粘贴网易云公开歌单（如官方热歌榜 3778678）" | 真 | `Text('点击上方"导入新歌单"，粘贴网易云公开歌单（如官方热歌榜 3778678）即可完整同步！', ...)` | 3778678 是真实歌单 ID |
| L16 | mobile_scaffold.dart:436 / desktop_scaffold.dart:34 / :343 | 默认歌手参数 `'巫娜'` | 假(兜底常量) | `_artistDetailParam = extra ?? '巫娜';` / `artistName: _subPageParam ?? '巫娜'` | 参数缺失时静默显示巫娜页面 |
| L17 | online_music_service.dart:26 | 搜索超时 6 秒 | 真 | `static const Duration _timeout = Duration(seconds: 6);` | 真实网络参数 |
| L18 | online_music_service.dart:37-40 / 104-107 | 伪造 User-Agent 抓取网易云 | 真假混杂 | `'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://music.163.com/',` | 真实请求（非假数据），但属未授权抓取，随时可能失效 |
| L19 | online_music_service.dart:116 | 歌单无描述时的默认文案 | 假(兜底) | `result['description']?.toString() ?? '来自网易云音乐公开歌单',` | 兜底文案，非伪造事实，可接受 |
| L20 | server.js:51-55 | 404 响应 | 真 | `res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); res.end('404 Not Found');` | 真实行为 |

---

## 2. 附：mockPresetTracks 六首明细

| id | title | artist | album | coverUrl | duration | lyrics | 判定 |
|---|---|---|---|---|---|---|---|
| track-1 | 云水禅心 | 巫娜 | 天禅 · 琴筝和鸣 | unsplash `photo-1518709268805`（**城堡照**，见 §5） | 4:28 | 9 行手写（器乐曲本无词） | 假 |
| track-2 | 晚风告白 | 伯远 | 晚风拂过告白季 | unsplash `photo-1511671782779` | 3:45 | 7 行手写 | 假 |
| track-3 | 海阔天空 | Beyond | 乐与怒 | unsplash `photo-1470225620780` | 5:24 | 9 行手写 | 真假混杂 |
| track-4 | 夜的第七章 | 周杰伦 | 依然范特西 | unsplash `photo-1465847899084` | 4:36 | 7 行手写 | 真假混杂 |
| track-5 | City of Stars | Ryan Gosling & Emma Stone | La La Land OST | unsplash `photo-1514525253161` | 2:58 | 5 行手写 | 真假混杂 |
| track-6 | 起风了 | 买辣椒也用券 | 起风了 | unsplash `photo-1493225457124` | 5:12 | 7 行手写 | 真假混杂 |

**六首共同点（全部为假）**：`audioUrl` 均为 null；`source` 均标注为 `preset-flac`/`preset-320k`；封面全部为 Unsplash 无关照片；歌词时间戳均为整秒人工凑数（12/24/35/38/48/52/62/68/78/88/90/102/110/135 秒）。

## 3. 附：Unsplash 图片复用矩阵

### 3.1 `photo-1518709268805-4e9042af9f23`（**同一张城堡照**，共 10 处）

| 用在哪 | 位置 |
|---|---|
| 歌曲 track-1《云水禅心》封面 | app/lib/core/audio/track_model.dart:117 |
| 发现页 Hero 大图 | app/lib/views/desktop/desktop_views.dart:112 |
| 歌单"东方禅境 · 幽篁古筝琴韵精选"封面 | desktop_views.dart:148 |
| 电台"深夜治愈故事馆"封面 | desktop_views.dart:793 |
| 音源曲库 mellow_001 封面 | app/lib/core/sources/lx_script_sandbox.dart:66 |
| 音源默认封面兜底 | lx_script_sandbox.dart:237 |
| Web 原型歌曲《Golden Hour》封面 | index.html:1551 |
| Web 原型歌单"落日飞车 · 慢摇海岸线"封面 | index.html:1631 |
| Web 原型歌单"深夜治愈所 · 晚安白噪音"封面 | index.html:2112 |
| 移动端原型：每日推荐卡 / 歌曲封面 / 歌单"千禧年华语黄金岁月" / 某艺人头像 | mobile.html:398 / 1303 / 2278 / 2560 |

> 即：**一张城堡风景照同时充当"古琴曲封面""华语流行歌单封面""助眠电台封面""艺人头像"**。

### 3.2 `photo-1534528741775-53994a69daeb`（**同一张年轻女性肖像**，共 7 处）

| 用在哪 | 位置 |
|---|---|
| 艺人"巫娜"头像（发现页头像环） | desktop_views.dart:185 |
| 艺人"周杰伦"头像（发现页头像环） | desktop_views.dart:186 |
| 艺人"巫娜"头像（歌手列表） | desktop_views.dart:612 |
| 歌手详情页头像（**所有歌手共用**） | desktop_views.dart:704 |
| 移动端艺人"巫娜/周杰伦"头像 | mobile_pages.dart:432 / :433 |
| 移动端歌手详情页头像 | mobile_pages.dart:527 |
| 移动端用户头像 / 我的页头像 | mobile_tabs.dart:134 / :960 |
| Web 原型艺人头像（"周杰伦"） | index.html:1654 |

### 3.3 其余高频复用

| 图片 | 复用位置 | 说明 |
|---|---|---|
| `photo-1514525253161-7a46d19cd819` | track_model.dart:197（City of Stars 封面）、desktop_views.dart:169（爵士歌单）、desktop_views.dart:796（科技播客）、lx_script_sandbox.dart:82 / :479 / :659、online_music_service.dart:61、mobile_tabs.dart:354 / :637、mobile.html:1323 等 | 同时是"爵士歌单""科技播客""赛博朋克专辑""在线搜索兜底封面" |
| `photo-1511671782779-c97d3d27a1d4` | track_model.dart:138、desktop_views.dart:155 / :794、lx_script_sandbox.dart:98 / :624、online_music_service.dart:115、mobile_tabs.dart:655、mobile.html:1303 等 | 同时是"华语流行歌单""白噪音电台""自定义脚本封面""在线歌单兜底封面" |
| `photo-1470225620780-dba8ba36b745` | track_model.dart:157（Beyond《海阔天空》）、desktop_views.dart:162（粤语经典歌单）、:795（人文播客）、lx_script_sandbox.dart:113 / :479、mobile_tabs.dart:370 / :643、mobile.html:1323 等 | 同上 |

---

## 4. 哪些数据链路是**真的可用**（附代码证据）

> 说明：以下链路确实会发生真实 I/O / 逻辑运算。它们可以工作，但**部分没有被 UI 正确接线**。

### 4-1. 网易云在线搜索（真实 HTTP，结果不稳定）✅ 真

- **代码**：`app/lib/core/sources/online_music_service.dart:29-84`
- **证据**：
  ```dart
  final uri = Uri.parse(
    'https://music.163.com/api/search/get/web?s=${Uri.encodeComponent(cleanQuery)}&type=1&offset=0&total=true&limit=$limit',
  );
  final resp = await http.get(uri, headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Referer': 'https://music.163.com/',
  }).timeout(_timeout);
  if (resp.statusCode == 200) { final data = jsonDecode(utf8.decode(resp.bodyBytes)); final songs = data['result']?['songs'] as List?; ... }
  ```
- **调用链（已接线）**：`QuickSearchOverlay._onSearch`（modals.dart:516-533）→ `OnlineMusicService.searchOnlineTracks` → `http.get`
- **可用性**：真实发起网络请求，返回真实 `netease_<id>` 曲目并渲染（"在线音源"徽章依据真实 source 前缀，modals.dart:650）。**失败时静默降级为本地 mock 结果，不伪造**（modals.dart:519-532；online_music_service.dart:80-83）。
- **限制**：无鉴权、依赖非公开接口；返回的 `audioUrl`（online_music_service.dart:63）**没有任何播放器消费**。

### 4-2. 网易云歌单导入（真实 HTTP + 真实错误提示）✅ 真

- **代码**：`online_music_service.dart:87-161`；UI：`modals.dart:756-776`
- **证据**：
  ```dart
  final uri = Uri.parse('https://music.163.com/api/playlist/detail?id=$playlistId');
  final resp = await http.get(uri, headers: {...}).timeout(_timeout);
  if (resp.statusCode == 200) { ... return ImportedPlaylist(id: playlistId, title: title, coverUrl: coverUrl, description: description, trackCount: parsedTracks.length, tracks: parsedTracks); }
  ```
  失败时：`modals.dart:772-774` `_errorMsg = '解析失败，请检查歌单ID或网络连接';`
- **可用性**：ID 正则提取（online_music_service.dart:93-98）支持纯数字与 `id=` 链接；成功后 `player.addImportedPlaylist` 真实入库（`audio_player_service.dart:83-92`），UI 在 `DesktopImportedPlaylistsView`（desktop_views.dart:970-1095）真实渲染。

### 4-3. 单曲 LRC 歌词拉取（真实 HTTP，触发条件狭窄）✅ 真

- **代码**：`online_music_service.dart:164-184`；触发点：`audio_player_service.dart:106-118`
- **证据**：
  ```dart
  static Future<List<LyricLine>> fetchTrackLyric(String trackId) async {
    final pureId = trackId.replaceAll('netease_', '');
    final uri = Uri.parse('https://music.163.com/api/song/lyric?os=pc&id=$pureId&lv=-1&kv=-1&tv=-1');
    ... if (lrcStr != null && lrcStr.isNotEmpty) { return LyricLine.parseLrc(lrcStr); }
  ```
- **触发条件**：仅当 `track.lyrics.isEmpty && track.id.startsWith('netease_')`（audio_player_service.dart:107）。因此**对 6 首 mock 曲目永不触发**（它们 `lyrics` 非空）。
- **LRC 解析器本身是真的**：`track_model.dart:14-43`（正则 `RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)')`，含排序）。

### 4-4. WebDAV 协议实现（真实完整实现，但**未被 UI 使用**）⚠️ 真代码 / 假表现

- **代码**：`app/lib/core/sync/webdav_sync_service.dart`
- **真实部分**：
  - `testConnection()` 真发 `PROPFIND`（:199-203），失败退回 `HEAD`（:212-214），正确处理 401/404（:226-239）
  - `_ensureRemoteDirectory()` 真发 `MKCOL`（:250-251）
  - `uploadSnapshot()` 真发 `PUT`（:272-281）
  - `downloadSnapshot()` 真发 `GET`（:304-309）
  - `sync()` 真实执行 拉取 → `localSnapshot.merge(remoteSnapshot)`（LWW）→ 上传（:334-372）
  - `SyncSnapshot` / `SyncFavoriteItem` 的 JSON 序列化与 `updatedAt` 时间戳比较是真的（`sync_data_model.dart:96-120`）
- **为什么用户看到的仍是假的**：`DesktopSyncView`（desktop_views.dart:1409-1455）**完全不引用 `WebDavSyncService`**，只用 `Future.delayed(900ms)` 伪造成功。

### 4-5. 局域网同步服务端/客户端（真实 HTTP Server，但**从未启动**）⚠️ 真代码 / 假表现

- **代码**：`app/lib/core/sync/lan_sync_service.dart`
- **真实部分**：
  - `HttpServer.bind(InternetAddress.anyIPv4, 23332)`（:141-145）会真的监听
  - 路由 `/sync/hello` GET（:171-183）、`/sync/pair` POST 校验 `_authKey`（:184-201）、`/sync/push` POST 校验 `x-auth-key`（:202-234）
  - 客户端 `pingDevice`（:284-296）、`pair`（:299-317）、`pushSnapshot`（:320-346）、`scanSubnet` 真的并发扫 254 个 IP（:378-401）
- **为什么用户看到的仍是假的**：全仓无 `LanSyncService()` 实例化、无 `startServer()` 调用；端口默认 23332 与 UI 显示的 18585 矛盾（L3）。

### 4-6. 本地状态管理（真逻辑 / 会话内有效，不持久化）✅ 真（范围有限）

- 播放模式切换（`audio_player_service.dart:225-243`）、随机播放（:158-160，真 `Random()`）、队列增删（:246-266）、睡眠定时器（:269-294，真 `Timer.periodic`）、音量（:220-223）、EQ 状态（`equalizer_manager.dart:40-79`）、主题/强调色/光晕（`design_system/theme_provider.dart`，被 UI 真实调用，如 mobile_tabs.dart:1006/1015/1038）均**逻辑真实**。
- **但均不持久化**：`pubspec.yaml:41` 声明了 `shared_preferences`，全仓 **0 处调用** → 重启即回到 A14/F1 的硬编码初值。

### 4-7. 服务端静态文件服务（真实可用）✅ 真

- **代码**：`server.js:24-90`
- **证据**：真实 `http.createServer`、MIME 表（:8-22）、HTTP Range 支持（:62-76，206 + `Content-Range`）、404 处理（:51-55）、`server.listen(PORT, '0.0.0.0')`（:88）。
- **注**：这是**唯一一个真实可用的服务端链路**；它只做静态托管，不含任何数据接口，也不含假数据。

### 4-8. Web 原型的浏览器本地存储 ✅ 真（范围有限）

- `index.html:1848 / 2587` 音量、`index.html:1923-1925 / 3075 / 3115` 主题与强调色、`mobile.html:1572-1576 / 1824 / 2914` 主题与强调色，均为真实 `localStorage` 读写。

---

## 5. 图片内容取证（本次实测）

为验证"艺人头像是否真是对应艺人""那张图是否是城堡"，本次审计**实际下载并查看了图片原始内容**（用图像读取工具肉眼核对）：

| 文件 | 来源 URL | 代码引用位置 | 实际画面 |
|---|---|---|---|
| `.qa/_audit_imgs/castle.jpg` | `photo-1518709268805-4e9042af9f23` | track_model.dart:117 等 10 处 | **一座晨雾中的欧洲城堡（带护城河倒影）** —— 与"云水禅心（古琴曲）""助眠电台""华语歌单"均无关联 |
| `.qa/_audit_imgs/avatar_wuna_jay.jpg` | `photo-1534528741775-53994a69daeb` | desktop_views.dart:185/:186/:612/:704、mobile_tabs.dart:134/:960 等 | **蓝紫色打光的年轻女性肖像** —— 既非巫娜（中国古琴演奏家），也非周杰伦，却被同时用作这两人头像、歌手详情页通用头像、以及 App 用户头像 |
| `.qa/_audit_imgs/avatar2.jpg` | `photo-1507003211169-0a1dd7228f2d` | desktop_views.dart:186（周杰伦）/ :613 / mobile_pages.dart:433 | **白人男性微笑肖像** —— 非周杰伦 |
| `.qa/_audit_imgs/avatar3.jpg` | `photo-1500648767791-00dcc994a43e` | desktop_views.dart:187（Beyond）/ :614 / mobile_pages.dart:434 | **白人男性肖像** —— 非 Beyond 乐队成员 |
| `.qa/_audit_imgs/avatar4.jpg` | `photo-1492562080023-ab3db95bfbce` | desktop_views.dart:188（伯远）/ :615 / mobile_pages.dart:435 | **户外年轻男性** —— 非伯远 |

> 取证文件保留在 `.qa/_audit_imgs/`，可自行打开核对。

---

## 6. 明确"未找到"的项（不编造）

| 待查项 | 结论 |
|---|---|
| QuickJS / JS 引擎依赖 | **未找到**。`app/pubspec.yaml:30-46` 无 flutter_js / quickjs / jscore / flutter_qjs 等任何 JS 运行时；全文 grep `QuickJS` 仅命中 `desktop_views.dart:1348` 的一处标题文案。所谓"第三方 LX 脚本沙箱"从未执行任何 JS。 |
| 音频解码/播放依赖 | **未找到**。pubspec.lock 中 `audioplayers` / `just_audio` / `media_kit` / `audio_service` 均 0 命中。 |
| `file_picker` 等本地文件选择依赖 | **未找到**。pubspec 无 `file_picker` / `file_selector` / `flutter_file_dialog`。 |
| 桌面端拖拽导入实现 | **未找到**。`app/lib/**` 中 grep `DragTarget` / `DropTarget` / `onDragDone` 无命中。 |
| Ctrl+K 快捷键实现 | **未找到**。grep `LogicalKeyboardKey` / `Shortcuts` / `RawKeyboardListener` / `Actions` 在 `app/lib/**` 无命中；只有 `desktop_scaffold.dart:186` 的 "Ctrl K" 文案。 |
| 任何持久化（SharedPreferences 调用） | **未找到**。尽管 `pubspec.yaml:41` 已声明依赖。 |
| 定时同步任务（WebDAV autoSync） | **未找到调用方**。`webdav_sync_service.dart:375-394` 定义了 `startAutoSync`，全仓无调用。 |
| 局域网扫描结果落库 | **未找到调用方**。`lan_sync_service.dart:469-491` `scanNetwork` 无调用；UI 中的"已探测到的同一局域网在线设备"（desktop_views.dart:1738）是纯静态两个卡片。 |
| 移动端"多端同步中心"页面 | **未找到**。`mobile_scaffold.dart:421-442` 的二级页分发中不存在 sync 页；grep `WebDAV` / `jianguoyun` 在 `mobile.html` 与 `mobile_tabs.dart` 均 0 命中。同步中心**只有桌面端有**。 |
| 真实的"每日 09:00 更新"定时任务 | **未找到**。全仓无 cron / Timer 与榜单更新相关。 |
| `.qa/` 下是否存在更早的同类审计报告 | 仅存在截图（`.qa/shots/*.png`，共 70+ 张）与 Python 脚本（`qa.py` / `scan.py` / `diag.py` 等），**未找到**已有的 fake-data 报告（本文件为第一份）。 |

---

## 7. 按严重程度排序的 TOP 5

1. **整个应用没有任何音频播放能力，"播放"是假的** —— `app/pubspec.yaml:30-46` 无任何音频依赖；`audio_player_service.dart:305-329` 用 50ms `Timer.periodic` 推进进度条；6 首 mock 曲目 `audioUrl` 全为 null（`track_model.dart:68`）；`audioUrl` 全仓无读取方。**用户点"播放"永远不会有声音。**
2. **WebDAV 同步中心是定时器伪造的成功态** —— `desktop_views.dart:1414-1455`：硬编码坚果云公共端点 + 编造账号 `gaore@mellow.music` + `Future.delayed(900ms)` 后弹"已成功将本地播放数据、收藏及歌单备份至 WebDAV 云端"。真实实现 `webdav_sync_service.dart` 完整存在但**从未被引用**；"服务就绪"徽标（`:1632`）无条件渲染。
3. **局域网设备列表是两个虚构设备 + 假端口** —— `desktop_views.dart:1755/1766` "Gaore 的 iPhone 15 Pro / 192.168.1.103 / iOS 17.5"、`:1799/1810` "客厅立体声音响 (HomePod) / 192.168.1.108"，绿色"在线"圆点写死（`:1757-1763`）；UI 显示端口 **18585**（`:1733`）而代码默认端口是 **23332**（`lan_sync_service.dart:112`）；LAN 服务从未启动。
4. **全部封面/头像为 Unsplash 无关照片并大面积复用** —— 一张城堡照 10 处复用（`track_model.dart:117`、`desktop_views.dart:112/:148/:793` 等），一张蓝光女性肖像同时充当"巫娜""周杰伦"（列表页）、所有歌手的详情页头像、以及 App 用户头像（`desktop_views.dart:185/:186/:704`、`mobile_tabs.dart:134/:960`）；实测图片内容与声称的艺人均不匹配（§5）。
5. **"本地扫描 / 拖拽导入 / 音源管理"三个入口都是空函数或死代码** —— `desktop_views.dart:1174` 与 `:1357` 的 `onTap: () {}`；`:1391` 开关 `onChanged: (_) {}`；"已解析本地曲目"直接渲染 `mockPresetTracks`（`:1182`）且每行固定显示"FLAC 24bit/96kHz · 42.8 MB"（`:1195`）；38KB 的 `lx_script_sandbox.dart` 音源引擎无任何调用方。

---

## 8. 复现方式

```powershell
# 1. 确认没有任何音频依赖（应无输出）
Select-String -Path 'app/pubspec.lock' -Pattern 'audioplayers|just_audio|media_kit|file_picker|quickjs'

# 2. 确认 mock 池与硬编码收藏
Select-String -Path 'app/lib/core/audio/track_model.dart' -Pattern 'mockPresetTracks|unsplash'
Select-String -Path 'app/lib/core/audio/audio_player_service.dart' -Pattern '_favoriteIds|_recordHistory'

# 3. 确认同步页是假的
Select-String -Path 'app/lib/views/desktop/desktop_views.dart' -Pattern 'jianguoyun|gaore@mellow|192.168.1.|18585|Future.delayed'

# 4. 确认 Web 原型不联网、无 audio 元素（应无输出）
Select-String -Path 'index.html','mobile.html' -Pattern 'fetch\(|XMLHttpRequest|new Audio\(|<audio'
# 5. 确认 Web 原型用振荡器合成
Select-String -Path 'index.html','mobile.html' -Pattern 'createOscillator'
```

---

*报告结束。所有结论均来自上表可核查的代码行；对无法读取或无法确认的项已在 §6 标注"未找到"。*
