# Mellow Music · 润音 · 项目研发里程碑与进度跟踪看板

> **当前版本**：v0.2.0 (Prototype & Architecture Finalized)  
> **更新时间**：2026-09-22  
> **当前状态**：原型阶段与架构规范 100% 验收完毕，正式进入跨平台工程化实现阶段。

---

## 📊 里程碑整体进度看板 (Milestone Dashboard)

| 里程碑 | 目标与交付物 | 计划周期 | 状态 | 交付物/参考文档 |
| :--- | :--- | :---: | :---: | :--- |
| **Phase 0** | **Modern Soft UI 双端高保真原型与 E2E 验收** | 已完成 | 🟢 **100%** | `index.html`、`mobile.html`、`e2e_test.js` (83/83 通过) |
| **Phase 0.5** | **技术方案与零遗漏全页面矩阵规划** | 已完成 | 🟢 **100%** | `docs/ROADMAP.md`、`mellow_music_app_blueprint.md` |
| **Phase 1** | **核心播放底座与 Modern Soft UI 组件库** | 进行中 | 🟡 **进行中** | `app/lib/design_system/`、`media_kit`、`audio_service` |
| **Phase 2** | **QuickJS 音源脚本引擎与全网搜索** | 待启动 | ⚪ 待开始 | `flutter_js` 沙箱、LX 六音脚本导入与解析 |
| **Phase 3** | **桌面端 12 视图 + 移动端 13 页面 1:1 落地** | 待启动 | ⚪ 待开始 | `app/lib/views/desktop/`、`app/lib/views/mobile/` |
| **Phase 4** | **双模动效歌词系统与声学 10 频段 EQ** | 待启动 | ⚪ 待开始 | Apple Music 级大幕、独立透明桌面歌词、libmpv EQ |
| **Phase 5** | **多端云同步、外部歌单导入与 CI/CD** | 待启动 | ⚪ 待开始 | WebDAV、LAN 扫码直连、网易/QQ 歌单解析、多平台打包 |

---

## 📝 详细进度日志 (Changelog & Progress Log)

### 2026-09-22
- **[Completed] Phase 0 原型与自动化测试验收**：
  - 完成桌面端 1440x900 Modern Soft UI 工作台开发，包含 Bento Grid、无边框标题栏、悬浮播放底栏、全屏巨幕动效歌词。
  - 完成移动端 390x844 原生 4-Tab 框架与金刚区 5 大二级页面（日推、歌单广场、排行榜、电台、私人 FM）。
  - 对齐移动端与桌面端能力：补充歌手详情页、本地与离线下载专区、声学 10 频段 EQ 弹窗、睡眠定时器、触觉音量调节器。
  - 编写并执行 83 项全流程 Puppeteer E2E 自动化测试用例，100% 成功通过。
- **[Completed] 品牌重塑与代码仓库建立**：
  - 将项目正式命名为 **Mellow Music · 润音**。
  - 创建 GitHub 仓库 `https://github.com/Kline-x/mellow-music-player`，完成初始代码库提交与远端推送。
- **[Completed] 深度集成规划 (AlgerMusicPlayer & LX-Music)**：
  - 制定基于 Flutter + `media_kit` + `flutter_js` + `Drift` 的全平台工程技术方案。
  - 建立 1:1 零遗漏全页面矩阵：确认桌面端 12 大视图 + 4 弹窗抽屉、移动端 13 大页面 + 5 底部抽屉全量实现规范。
  - 纳入 LX 音源脚本沙箱、网易云/QQ 歌单链接解析导入、WebDAV / 局域网直连同步、桌面透明穿透歌词 4 大拓展特性。
  - 形成 `docs/ROADMAP.md` 与 `docs/PROGRESS.md`，固化进代码版本库。
- **[Completed] `/grill-with-docs` 架构深水区考问与硬核决议落地**：
  - 1. **音源引擎**：通过 Dart 原生 Polyfill 注入 QuickJS，直接支持 `lx.request`、`Buffer` 与 `Crypto`。
  - 2. **音频与系统通信**：确立分级双流架构，UI 直连 60Hz 高刷流，系统媒体广播实施 1 秒防抖节流。
  - 3. **独立悬浮歌词**：采用 `desktop_multi_window` 多窗口独立渲染 + Win32/macOS 鼠标透明穿透。
  - 4. **局域网同步**：100% 原生兼容 LX-Music 同步协议（端口 23332），支持与现有 LX-Music 双向扫码互通。
  - 5. **本地存储**：全面采纳工业级响应式数据库 `Drift` (SQLite3 FTS5)，杜绝跨平台编译冲突。

---

## 🎯 即将执行的下一个任务 (Next Step: Phase 1)

1. **环境准备与工程脚手架**：在项目子目录 `app/` 初始化 Flutter 多平台工程。
2. **设计系统组件库落地**：
   - 提取 `design_tokens.css` 中的全套色彩、阴影、圆角、光晕参数至 Dart 代码；
   - 封装 `SoftCard`、`SoftButton`、`RecessedWell`、`AcousticMeshGlow` 原子组件。
3. **音频播放器核心底座**：
   - 配置 `media_kit` 音频流式解码与硬件级声学滤镜；
   - 对接 `audio_service` 系统媒体通知通道。
