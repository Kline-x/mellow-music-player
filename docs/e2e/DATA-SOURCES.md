# 真实数据源决议（Real Data Source Decision）

> 本文件回答目标第 3 条「不能有假数据，全部要求有真实数据」的**可行方案**。
> 所有结论均由本轮真实网络探测得出，探测命令与观测结果一并记录，可复现。
> 探测时间：2026-09-22。网络端点可能随时间变化。

---

## 1. 候选数据源连通性与可用性实测

| 数据源 | 用途 | 实测结果 | 可播放 | 结论 |
| :--- | :--- | :--- | :---: | :--- |
| **iTunes Search API** `itunes.apple.com/search` | 歌曲/专辑/歌手检索 | ✅ HTTP 200，真实元数据（曲名/歌手/专辑/时长/流派/高清封面/发行信息） | ✅ | **采用** |
| **iTunes 30 秒试听直链** `audio-ssl.itunes.apple.com/.../mzaf_*.m4a` | 音频播放 | ✅ HTTP 200，下载 1,049,662 B，`file` 识别为 `ISO Media, Apple iTunes ALAC/AAC-LC (.M4A)`，Range 请求 206 | ✅ | **采用（30 秒合法试听）** |
| 网易云 `api/search/get/web` | 在线搜索列表 | ✅ HTTP 200，真实 JSON | — | **采用（默认内置音源）**，与 iTunes 聚合 |
| 网易云 `api/song/lyric` | 真实 LRC 歌词 | ✅ HTTP 200，返回真实 `lrc.lyric` | — | **采用（歌词）** |
| 网易云 `song/media/outer/url?id=` | 音频播放 | ❌ HTTP 302 → `music.163.com/404` | ❌ | **弃用（已死，已从代码删除）** |
| 网易云 `api/song/enhance/player/url` | 音频播放 | ⚠️ 多数 `url: null`（`code:-110` 版权限制），但抽样存在可播曲目（`1330348068` 等返回真实 `*.music.126.net` mp3，320k/192k/128k 三档均可用） | ⚠️ 部分 | **采用**：真实取流 + 按 320k→192k→128k 降级；无版权时如实返回 null 并提示，绝不伪造直链 |
| `stream.mellowmusic.io`（LX 沙箱生成） | 音频播放 | ❌ 无法连接（curl code 000） | ❌ | **必须删除的假域名** |
| `cdn.<x>.music.net`（LX 沙箱生成） | 音频播放 | ❌ `NXDOMAIN` | ❌ | **必须删除的假域名** |
| `custom-cdn.<x>.com`（LX 沙箱生成） | 音频播放 | ❌ 域名不存在 | ❌ | **必须删除的假域名** |
| **soundhelix.com 演示 mp3** | 内置曲库 | ✅ HTTP 200，可播放 | ✅ | 可播但**必须标注为示例音频**，不得配编造曲名/歌手 |
| `images.unsplash.com` 图床 | 封面/头像 | ✅ HTTP 200 | — | **必须停止用于冒充歌手/专辑封面** |
| archive.org `download/...` | 公共领域音乐 | ❌ HTTP 503（服务端不可用） | ❌ | 暂不采用 |
| `public/audio/track{1..4}.mp3`（仓库自带） | 内置音频 | ✅ 文件存在（7.8~10.2 MB × 4） | ✅ | **可作为内置示例曲库的真实音频** |

### 1.1 关键探测证据

```bash
# iTunes 搜索（真实元数据）
curl -s -m 15 'https://itunes.apple.com/search?term=jack+johnson&entity=song&limit=1'

# iTunes 试听直链真实可下载（约 1 MB，M4A）
curl -s -o /tmp/preview_test.m4a '<previewUrl>'
file /tmp/preview_test.m4a   # → ISO Media, Apple iTunes ALAC/AAC-LC (.M4A) Audio

# 网易云播放直链已死
curl -sI -m 10 'https://music.163.com/song/media/outer/url?id=347230.mp3'   # → 302, location: .../404

# 网易云新播放接口受版权限制
curl -s -m 15 -H 'Referer: https://music.163.com/' 'https://music.163.com/api/song/enhance/player/url?id=347230&ids=%5B347230%5D&br=320000'
# → {"data":[{"id":347230,"url":null,"code":-110,...}]}
```

---

## 2. 数据源决议

### 2.1 采用：iTunes Search API 作为唯一的「真实在线音乐」来源

- **检索**：`https://itunes.apple.com/search?term=<关键词>&entity=song|album|musicArtist&limit=<n>&country=<cc>`
- **详情/歌手作品**：`https://itunes.apple.com/lookup?id=<artistId>&entity=song&limit=<n>`
- **可播放音频**：结果中的 `previewUrl`（30 秒官方试听，M4A，真实可播）
- **真实封面**：`artworkUrl100`，替换尺寸段（`100x100bb` → `600x600bb`）得高清封面
- **优点**：官方公开 API、无需鉴权、元数据完整、直链真实可播、封面真实对应。
- **限制（必须如实告知用户）**：每次仅 30 秒试听；中文曲库覆盖不全（实测 `term=周杰伦&entity=song&country=cn` 返回 0 条，需用英文名或 `musicArtist` 检索）。

### 2.2 采用：本地文件导入作为唯一的「完整曲目」来源

- 走 `localPath` + `DeviceFileSource` 链路，播放用户自己的完整音频文件（基础设施已具备，需补齐文件选择与落盘）。
- 这是唯一能提供「完整歌曲 + 真实元数据」的路径。

### 2.3 采用：网易云官方歌词接口作为真实歌词来源

- `https://music.163.com/api/song/lyric?os=pc&id=<id>&lv=-1&kv=-1&tv=-1`（实测可用）。
- 仅对能拿到真实网易云 `id` 的曲目生效；无歌词时必须显示诚实的「暂无歌词」，禁止编造 LRC。

### 2.4 必须删除 / 改造

| 对象 | 处理 |
| :--- | :--- |
| `lx_script_sandbox.dart` 中 3 处假 CDN 域名 | 删除该方法或改为明确抛「未接入真实音源」；不得返回假直链 |
| `lx_script_sandbox.dart` 中硬编码假 LRC（`[00:08.00]清风拂过绿水...`） | 删除，改为真实歌词接口或空 |
| `track_model.dart` 中 33 首「假曲名 + SoundHelix 音频」 | 改为「真实曲名 + iTunes 真实试听」，否则改为诚实的「示例音频 1..N」 |
| unsplash 歌手头像与粉丝数/bio（`track_model.dart` 等） | 改用 iTunes 真实 `artworkUrl` 与真实字段；拿不到就显示占位并明确标注 |
| 四榜单的「名次/热度/官方」 | 无真实榜单源；改为「iTunes 搜索结果（按 Apple 返回顺序）」并标注来源，或改为明确空状态 |
| 电台/播客的假单集与假时长 | 无真实数据源；改为明确空状态或删除入口 |
| `online_music_service.dart` 的 `song/media/outer/url` 直链 | 替换为 iTunes `previewUrl` 或删除该字段 |

### 2.5 无法真实化的部分（必须诚实降级）

| 能力 | 处置 |
| :--- | :--- |
| 各平台「官方排行榜」 | 无公开合法接口 → 改为「按 Apple 返回顺序的搜索热榜」，UI 明确标注来源与非官方性质 |
| 「粉丝数 / 播放量 / 热度」 | iTunes 不提供 → **删除这些数字**，不显示任何编造统计 |
| 声音电台 / 播客单集 | 无数据源 → 空状态 + 「暂无可用内容」，或移除入口 |
| 多端同步的「在线设备列表」 | 无真实实现 → 保持当前「未发现设备 / 接入中」的诚实状态 |
| EQ 实时音效 | audioplayers 不支持音频效果 → UI 明确标注「当前引擎不支持实时音效」，或换引擎后再启用 |

---

## 3. 实施顺序（供后续并行改造使用）

1. 新建 `app/lib/core/sources/itunes_music_service.dart`：真实检索 + 真实详情 + 真实直链，带超时与错误类型。
2. 改造 `track_model.dart`：用真实数据源替换 `mockPresetTracks` 等编造数组；保留的示例音频重命名为「示例音频 N」且不配假曲名。
3. 改造 `online_music_service.dart`：播放直链改用 iTunes `previewUrl`；网易云仅保留歌词。
4. 改造桌面端/移动端视图：所有列表、歌手页、搜索、播放改为真实数据源驱动；无数据源处显示诚实空状态。
5. 删除或诚实化 `lx_script_sandbox.dart`（假域名 + 假歌词 + 死代码）与 `equalizer_manager.dart` 的超额文案。
6. 每条改动都必须补/改测试，且测试必须在生产代码被改坏时变红。

---

## 4. 合规与版权提示

- iTunes 试听直链是 Apple 官方对外提供的 30 秒预览，仅应用于检索/试听场景；不得用于下载分发、缓存再分发或绕过试听限制。
- 网易云歌词接口属非官方公开接口，稳定性无保证；商用前需评估合规风险。
- 内置示例音频（soundhelix / 仓库 `public/audio/`）必须明确标注为示例，不得冒充具体商业歌曲。
- 任何情况下都不得展示编造的歌手数据、粉丝数、播放量——这属于对用户的欺骗，而非数据不完整。