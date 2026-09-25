# 桌面端控件“控制现实审计”（仅读 app/lib 代码，未运行 GUI，未改文件）

## A. 伪实现 / 空实现 / 缺失 / 半真实（优先）

| 控件/位置 | 文件:行 | 处理器做了什么 | 判定 | 备注 |
|---|---|---|---|---|
| 全局快捷搜索浮层 QuickSearchOverlay（整组件） | modals.dart:501,519,529 | 初值/空查询 `_results=mockPresetTracks`，仅本地 mock 匹配+在线合并 | 缺失（死代码） | 全库无任何实例化；Ctrl+K 实际跳 search 页 desktop_scaffold.dart:150 |
| EQ 预设/10 频段滑块/启用开关/恢复默认 | modals.dart:252,310,344,355 | 改 `_bandGains` 并落本地 | 伪实现 | `toLibmpvFilterString()`（equalizer_manager.dart:134）在 lib 零调用（仅测试调用），滤镜从不下发后端→无可听效果 |
| LX“设为主源” | desktop_views.dart:3748 | `engine.setActiveSource`+SnackBar | 伪实现 | activeSourceId 只喂 UI 文案；解析只用 `song.source`/显式 sourceId 且 enableSourceFallback:false（online_music_service.dart:445-559） |
| LX 音源 启用/停用 Switch | desktop_views.dart:3790 | `engine.setSourceEnabled` | 伪实现 | 仅进 fallback 候选（lx_script_sandbox.dart:1214），所有调用方传 enableSourceFallback:false |
| “导入自定义脚本”→“确认导入并挂载” | modals.dart:2555,2820; lx_script_sandbox.dart:966 | 正则查危险调用+注释头→注册元数据 | 伪实现 | 不执行 JS（lx_script_sandbox.dart:558-575）；`getMusicUrl` 返回凭空链 `custom-cdn.<id>.com`（:695） |
| 歌手详情“关注歌手” | desktop_views.dart:1467-1470 | 仅 `setState(_isFollowing=!)` | 伪实现 | 不入库、不请求，重进即复位 |
| 声音电台卡片 | desktop_views.dart:1654,1675 | `player.playTrack(r.track)` | 伪实现（硬编码数据） | `mockRadioStations` track_model.dart:901，标题/在听数静态 |
| 发现页 4 张甄选歌单卡 | desktop_views.dart:156-199 | `playPlaylist(pl.tracks)` | 伪实现（硬编码数据） | curatedPlaylists 与 mock*Tracks 全静态 |
| 发现页“开启漫游播放” | desktop_views.dart:107 | 队列非空则 `playTrack(playlist[0])` | 半真实 | 初始队列被 mock 填充（audio_player_service.dart:30） |
| 歌手详情作品数徽章 | desktop_views.dart:1432,1444 | 显示 50 / “1000+” 兜底 | 伪实现（装饰） | 接口未回时展示估算值 |
| 歌单广场 分类 chips/歌单卡 | desktop_views.dart:344,365 | 本地过滤+播放 | 半真实 | `getPlaylistsByTag`→`mockSquarePlaylists` track_model.dart:1019,1093 |
| 发现页 热门歌手头像环 | desktop_views.dart:216 | 跳 artist_detail | 半真实 | 数据 `mockArtistsProfiles` track_model.dart:503 |
| 悬浮歌词 toggle | desktop_scaffold.dart:1013 | `DesktopFloatingLyricService.toggleEnabled` | 半真实 | 非 Windows 只存偏好+应用内歌词条；Win32 原生窗口才真实（desktop_floating_lyric_service.dart:29,54,91） |
| 设置-关闭时最小化到托盘 | desktop_views.dart:3058 | `WindowsTrayService.setMinimizeToTray` | 半真实 | Windows-only 原生；其他平台仅落盘（windows_tray_service.dart:32,69） |
| 播放栏“音源徽章”主动换源 | modals.dart:3155→3164 | `player.switchSource`→`resolveUrlFromSpecificSource` | 半真实 | netease/kuwo(第三方代理)/kugou/itunes 真；QQ/咪咕/润音官方走 mock 驱动返回假链（lx_script_sandbox.dart:455） |
| 同步页 LAN 监听地址 | desktop_views.dart:4580 | 无 IP 时显示 127.0.0.1 | 伪实现（文案） | 底层 HttpServer 本身真实 |

## B. 真实（按视图）

| 控件/位置 | 文件:行 | 处理器做了什么 | 判定 | 备注 |
|---|---|---|---|---|
| 侧栏 11 个 nav 项 | desktop_scaffold.dart:531-549→580 | `_navigateTo(id)` | 真实 | :586-618 均有对应真实 view |
| 标题栏 后退/前进 | desktop_scaffold.dart:365,374 | `_goBack/_goForward` 真实历史栈 | 真实 | :92-133 |
| 全局搜索框 | desktop_scaffold.dart:388 | 跳转 search 视图 | 真实 | 搜索页真实请求 desktop_search_view.dart:104 |
| 导入歌单按钮 | desktop_scaffold.dart:438 | 打开 ImportPlaylistModal | 真实 | :795 `_doImport`→网易云真实接口 |
| 5 个强调色点 | desktop_scaffold.dart:464 | `theme.setAccentType` | 真实 | 5 色枚举 tokens.dart:4-9；落盘 theme_provider.dart:76 |
| 月亮主题切换 | desktop_scaffold.dart:492 | `theme.toggleTheme` | 真实 | theme_provider.dart:63 |
| 设置齿轮 | desktop_scaffold.dart:501 | 跳 settings | 真实 | — |
| EQ/睡眠/全屏歌词/悬浮歌词/队列 | desktop_scaffold.dart:976,985,1003,1013,1022 | 打开模态或切状态 | 真实 | EQ 有效果问题见 A |
| 静音/音量滑块 | desktop_scaffold.dart:1035,1055 | toggleMute/setVolume→后端+落盘 | 真实 | — |
| 进度条 seek | desktop_scaffold.dart:934-944 | 拖动防抖、onChangeEnd 才 seek | 真实 | — |
| 上一首/播放/下一首/循环模式 | desktop_scaffold.dart:848,856,862,897 | player 方法 | 真实 | — |
| 收藏/收录到歌单 | desktop_scaffold.dart:737,750 | toggleFavorite 落盘 / AddToPlaylistModal | 真实 | — |
| 快捷键映射 | desktop_scaffold.dart:146-197；硬件键 :64-89 | 见备注绑定 | 真实 | 空格播放、Ctrl/Cmd+K 搜索、←→快退进 5s、↑↓音量±5%、M 静音、L 全屏歌词、Q 队列、ESC 退出、Ctrl/Cmd+D 悬浮歌词、媒体键全套 |
| 查看完整推荐/查看全部 | desktop_views.dart:117,146 | 导航 playlists | 真实 | — |
| 巅峰榜单“播放全部榜单” | desktop_views.dart:621 | 聚合 live 榜单去重播放 | 真实 | 硬编码回退 track_model.dart:860 |
| 榜单分类 chips/榜单卡 | desktop_views.dart:872,911,668 | 真实 fetchAllToplists/fetchToplistTracks | 真实 | :461-482 |
| 热门歌手 分类/卡片 | desktop_views.dart:1105,1133 | 真实 fetchArtistList→跳详情 | 真实 | :1030 |
| 歌手详情 播放代表作/tabs/收藏/加载更多 | desktop_views.dart:1478,1508,1515,1597,1625 | playPlaylist/fetchArtistAllSongs/toggleFavorite | 真实 | — |
| 我喜欢 一键播放/导入更多/行内收藏 | desktop_views.dart:1775,1783,1897 | playPlaylist/ImportPlaylistModal/toggleFavorite | 真实 | — |
| 导入与自建 新建/心动导出/导入/立即体验导入 | desktop_views.dart:2224,2234,2247,2299 | createCustomPlaylist/exportFavorites/ImportPlaylistModal | 真实 | — |
| 播放历史 清空足迹/行内收藏 | desktop_views.dart:2522,1897 | clearPlayHistory 落盘 | 真实 | — |
| 本地 扫描目录/立即添加并扫描/行内操作 | desktop_views.dart:2675,2745,2606,2840,2855,2860 | LocalMusicService 真实遍历文件系统 | 真实 | local_music_service.dart:46 |
| 同步 立即备份/离线迁移/配置/云端恢复/导出/导入/扫描/配对/投送 | desktop_views.dart:4179,4186,4369,4441,4493,4498,4589,4596,4740 | WebDAV 真实 HTTP、SyncSnapshot、HttpServer 扫描、pushToTarget | 真实 | webdav_sync_service.dart:309,344；lan_sync_service.dart:143,532,571 |
| 模态确认：导入歌单 解析/存入/播放 | modals.dart:905,1003,1016 | 真解析+addImportedPlaylist+playPlaylist | 真实 | — |
| 模态确认：新建歌单 立即创建 | modals.dart:1225 | createCustomPlaylist | 真实 | :1058 |
| 模态确认：收录/移除收录 | modals.dart:1490,1459 | add/removeTrackFromPlaylist | 真实 | — |
| 模态确认：睡眠 15-90 分/播完当前曲停 | modals.dart:468,479 | startSleepTimer 真计时暂停 | 真实 | audio_player_service.dart:792 |
| 模态确认：WebDAV 保存配置/测试连接 | modals.dart:1821,1808 | saveWebDavConfig + PROPFIND/HEAD 真请求 | 真实 | webdav_sync_service.dart:238 |
| 模态确认：导出快照复制 JSON | modals.dart:1931 | Clipboard.setData | 真实 | — |
| 模态确认：导入快照 解析并合并 | modals.dart:2118 | SyncSnapshot.merge/applyToAppState | 真实 | :1981 |
| 模态确认：LAN 配对 无线投送/复制 URI | modals.dart:2434,2318 | pushToTarget/Clipboard | 真实 | :2171 |

## 结论（给父代理的行动要点）
1) 界面宣称与后端能力最大的三处偏差：EQ 滤镜从不生效；LX“主音源/启用开关”不影响解析；自定义脚本只登记元数据且给出假直链（代码注释已诚实标注）。2) QuickSearchOverlay 为死代码且用 mockPresetTracks。3) 数量可观的“内容型”控件（电台、歌单广场、发现页精选、发现页歌手环）播放的是 track_model.dart 内 mock* 常量；搜索/榜单/歌手库/本地/同步/WebDAV/LAN 是真实实现。4) 悬浮歌词与托盘为 Windows 原生限定，其他平台仅落盘偏好。