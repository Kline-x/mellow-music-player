> # ⚠️ 接手/修复本项目前，请先读验收文档（2026-09-22 校准）
>
> **本 README、`docs/SPEC.md`、`docs/PROGRESS.md` 描述的是「目标设计」，不是已交付的实现。**
> 2026-09-22 对 Windows 端产物（`release_windows/app.exe`）做了真实用户视角 E2E 验收，**结论：不通过** —— 共 **44 条缺陷（P0×12 / P1×20 / P2×12）**，其中三条致命：
> **① 点播放永远无声**（进程 85 个模块中音频模块 0 个，进度是 50ms 定时器伪造）｜**② 关掉就忘**（零持久化，重启后收藏/历史/主题/强调色全部归零）｜**③ 会用「已成功备份到云端」欺骗用户**（实为 `Future.delayed(900ms)`）。
>
> **先读这两份，再动手改代码：**
> - 📋 [`docs/PC_E2E_ACCEPTANCE_ISSUES.md`](docs/PC_E2E_ACCEPTANCE_ISSUES.md) —— **验收问题清单（44 条）**，每条含用户可见现象 / 复现步骤 / 代码证据 / 对应文档声称 / 影响
> - 🔧 [`docs/PC_E2E_FIX_PLAN.md`](docs/PC_E2E_FIX_PLAN.md) —— **修复建议**：阶段 0~7 分阶段计划（到"改哪一行"级别）、发布前检查清单、10 天 MVP、工作量 29~49 人日
> - 📁 `docs/audit/` —— 4 份原始审计报告（代码 28 条 / 文档差距 80 条 / 假数据 174 条 / Web+服务端 48 条）
> - 🖼️ `docs/evidence/pc-e2e/` —— 20 张实测截图存证 ｜ 🛠️ `docs/tools/pc_gui_driver.py` —— 可复用的复验工具
>
> **修复完成前，请勿对外演示或发布** —— 界面会告诉用户数据已备份，而用户录入的数据一定会丢。
>
> ---

# Mellow Music · 润音 (Modern Soft UI 现代柔和微质感版)

> 专为全平台高保真体验打造的 **Modern Soft UI（现代柔和微质感 / Soft Depth & Tactility / Calm Tech）** 原生双端音乐播放器交互系统与原型。

[![E2E Tests](https://img.shields.io/badge/E2E%20Tests-83%2F83%20Passed%20(100%25)-emerald?style=flat-square&logo=puppeteer)](e2e_test.js)
[![UI Style](https://img.shields.io/badge/Design%20System-Modern%20Soft%20UI-pink?style=flat-square)](design_tokens.css)
[![Audio Engine](https://img.shields.io/badge/Audio-Web%20Audio%20API%20Synthesizer-blue?style=flat-square)](#-web-audio-api-声学生态引擎)
[![Platform](https://img.shields.io/badge/Platform-Desktop%20%26%20Mobile-purple?style=flat-square)](#-运行与体验指南)
[![License](https://img.shields.io/badge/License-MIT-slate?style=flat-square)](LICENSE)

---

## 📸 界面预览 (UI Gallery)

### 🖥️ 桌面端沉浸工作台 (Desktop 1440x900)
| 浅色温润白瓷模式 | 深色石墨夜间模式 |
| :---: | :---: |
| ![Desktop Light](public/e2e_desktop_verified.png) | ![Desktop Dark](public/showcase_desktop_dark.png) |

| 沉浸式动效大幕歌词与旋转唱片 | 声学校准均衡器 EQ 模态框 |
| :---: | :---: |
| ![Desktop Lyrics](public/showcase_desktop_lyrics.png) | ![Desktop EQ](public/showcase_mobile_eq.png) |

### 📱 移动端原生全景 (Mobile 390x844)
| 原生 4-Tab 发现主页 | 私人漫游 FM 沉浸模式 | 歌手详情页 (对齐桌面端) | 本地与离线下载专区 |
| :---: | :---: | :---: | :---: |
| ![Mobile Home](public/e2e_mobile_verified.png) | ![Mobile FM](public/showcase_mobile_fm.png) | ![Mobile Artist](public/showcase_mobile_artist.png) | ![Mobile Local](public/showcase_mobile_local.png) |

---

## 🌟 Modern Soft UI 设计系统核心规范

Modern Soft UI（现代柔和微质感）结合了 Calm Tech、新拟态（Neumorphism）的情感触觉以及现代扁平设计的清爽洗练：

1. **温润瓷质画布 (Porcelain & Calm Tech Canvas)**：
   - 浅色模式采用温润冷灰微蓝画布（`#F5F7FB`）搭配纯白柔和微浮卡片（`#FFFFFF`），彻底消除刺眼纯白；
   - 深色模式采用深石墨微浮雕质感（`#0D1117` / `#1C2128`），无割裂死黑，视觉轻盈透气。
2. **三层漫散射柔性景深 (Layered Soft Depth)**：
   - 摒弃生硬粗大的死黑投影与早期拟物的脏阴影，采用 3 级高扩散、低浓度（4%~10%）的环境光漫反射柔阴影；
   - 顶部搭配超细微白高光内边（`inset 0 1px 0 rgba(255,255,255,0.9)`），如精雕细琢的陶瓷器具。
3. **触感微交互 (Tactile Micro-Interactions)**：
   - 按钮具备按压物理下潜（`active:scale-[0.97]`）与凹凸质感切换；
   - 滑块与进度条采用内凹沉槽（Recessed Wells）与发光胶囊游标；
   - 窗口、卡片全面采用连续曲率圆角（Squircle `22px~28px`）。
4. **动态声学弥散光晕 (Dynamic Acoustic Mesh Glow)**：
   - 随当前播放曲目唱片封面色彩，实时提取并驱动背景 3 处高斯弥散多色光晕（`filter: blur(80px)`）平滑流转；
   - 支持实时浓度调节与随专辑封面自适应取色。

---

## 🚀 完整功能矩阵 (Feature Matrix)

### 🖥️ 桌面端完整工作台 (`index.html`)
- **无边框拟物标题栏**：Mac 交通灯控制、即时搜索框（带 `⌘ K` 快捷徽标）、深浅色切换、桌面/移动视图快速跳转。
- **悬浮胶囊侧边栏**：分组管理（在线发现、歌单广场、排行榜、热门歌手、播客 / 我的喜欢、本地与下载），平滑胶囊指示器。
- **Bento Grid 发现工作台**：今日雷达私人漫游 Hero 席位、推荐歌单卡片流、歌手推荐环。
- **歌单详情视图**：超大 Squircle 封面、动态光晕、一键播放全部、交互式曲目列表。
- **签名级悬浮播放底栏 (Pill Dock Player)**：旋转黑胶缩略图、三态循环切换、触控音量条、跳动声波均衡条。
- **全屏动效歌词大幕 (MusicFull)**：双栏布局，左侧凹槽黑胶唱机与唱臂，右侧 Apple Music 级别动效歌词，支持点击行瞬间跳播。
- **硬件级声学均衡器 EQ**：Flat / Bass Boost / Clear Vocal / Warm Jazz / Spatial 3D 5 大滤波预设。
- **睡眠定时器**：15/30/45/60 分钟倒计时，常驻绿色呼吸脉冲灯，平滑淡出休眠。
- **全局键盘快捷键系统**：`Space` (播放/暂停)、`M` (静音)、`L` (歌词)、`Q` (队列)、`Escape` (安全退出)、`Arrow` (调音/快进)。

### 📱 移动端原生 App 体系 (`mobile.html`)
- **零系统滚动条设计**：原生 iOS/Android 沉浸式触控滚动，`scrollbar-width: none`，无任何突兀滚动条。
- **原生 4-Tab 底部触控 Dock**：发现音乐、探索全库、我的资料库、个人中心。
- **5 大快捷金刚区二级全功能页面**：
  - `每日推荐`：拟物日历卡片，动态公历日/星期显示，6 首日推清单，一键播放全部。
  - `歌单广场`：全部/流行/电子/摇滚/Lo-Fi/古典多风格胶囊过滤。
  - `巅峰排行榜`：飙升、热歌、新歌、原创榜，前三名冠亚季军排位着色，一键播放整榜。
  - `声音电台`：治愈、助眠、故事、科技 4 大播客分类，热门单集轻量收听。
  - `私人漫游 FM`：沉浸式黑胶旋转大碟，切歌漫游（Next），红心喜欢双向交互，垃圾桶屏蔽。
- **深度对齐桌面端高阶能力**：
  - `热门歌手与歌手详情主页`：歌手海报、认证徽章、粉丝数量、关注本地持久化、代表作点播。
  - `本地与离线下载专区`：微凹导入区，本地音频文件导入，已缓存曲目试听。
  - `声学均衡器 EQ 弹窗`：全屏置顶弹窗，5 组 Web Audio Biquad 滤波器实时调音。
  - `睡眠定时器`：多档倒计时，全屏顶栏常驻呼吸指示光点。
  - `触觉音量调节滑块`：全屏滑动音量控制，一键静音与原音量记忆恢复。

---

## 🔊 Web Audio API 声学生态引擎

本项目内置自研的无外部依赖物理声学引擎（`ModernSoftMobileAudioEngine` 与桌面端对应引擎）：
- **全真实声音合成**：通过 Web Audio API `AudioContext` 实时生成 440Hz 纯净旋律与柔和和弦打击音效，在不依赖外网 MP3 资源下依然能进行真实声学发声与测试。
- **BiquadFilter 频响调谐**：
  - `bass`: `lowshelf` 120Hz (+6dB) 超重低音增强
  - `vocal`: `peaking` 2500Hz (+4.5dB) 人声穿透力增强
  - `jazz`: `peaking` 500Hz (+3dB) 温润黑胶质感
  - `spatial`: `highshelf` 8000Hz (+5dB) 空间声场拓宽
- **淡出算法**：定时器归零时通过 `linearRampToValueAtTime` 平滑淡出休眠。

---

## 🤖 83 项全功能 E2E 自动化测试

项目内嵌完整的 Puppeteer 端到端测试套件，全面覆盖桌面端与移动端核心用户路径：

```bash
# 执行自动化 E2E 交互审计
npm run test:e2e
```

**测试通过情况**：
```text
======================================================
📊 FINAL E2E INTERACTIVE VERIFICATION REPORT
======================================================
Total Scenarios Tested : 83
Passed Scenarios       : 83 / 83 (100%)
Failed Scenarios       : 0

🎉 ALL E2E USER INTERACTION TESTS PASSED WITH 100% SUCCESS RATE!
Prototype meets the full Deliverable Production Standard (交付标准).
```

---

## 💻 运行与体验指南

### 前置环境
- Node.js >= 16.x
- Google Chrome（用于 E2E 测试）

### 快速启动
```bash
# 1. 克隆代码库
git clone https://github.com/Kline-x/mellow-music-player.git
cd mellow-music-player

# 2. 安装测试依赖
npm install

# 3. 启动本地流媒体预览服务
npm start
```
服务启动后，在浏览器访问：
- **🖥️ 桌面端完整工作台**：`http://localhost:8088/index.html`
- **📱 移动端原生应用视图**：`http://localhost:8088/mobile.html`（建议在浏览器 F12 切换为 iPhone/Android 触屏视口体验）

---

## 🗺️ 工程化落地架构与进度跟踪 (Roadmap & Progress)

本项目正基于已验收的原型与设计规范，统一通过 **Flutter 跨平台单一代码库**（Windows、macOS、Android、iOS）进行生产级客户端落地开发，深度融合 **AlgerMusicPlayer** 的视觉动效美学与 **LX-Music** 的强大音源生态与多端同步能力。

- 📘 **完整架构蓝图与零遗漏页面对齐矩阵**：请查阅 [docs/ROADMAP.md](docs/ROADMAP.md)
  - 桌面端 12 大核心主视图 + 4 大抽屉弹窗
  - 移动端 4 大主 Tab + 9 大二级跳转页 + 5 大底部抽屉/浮层
  - QuickJS 音源脚本沙箱、外部歌单链接解析、WebDAV/局域网扫码直连同步、透明穿透桌面歌词
- 📋 **系统技术规格说明书 (System Specification)**：请查阅 [docs/SPEC.md](docs/SPEC.md)
  - Modern Soft UI 设计 Token、双端 34 个路由交互规范
  - media_kit 双流节流通信、QuickJS Dart Polyfill 注入协议、Drift 5 张核心表模型与 LX-Sync 报文定义
- 📊 **研发里程碑与实时进度看板**：请查阅 [docs/PROGRESS.md](docs/PROGRESS.md)
  - Phase 0: Web 双端高保真原型与 83 项 E2E 自动化验收 (100% 完成)
  - Phase 0.5: 零遗漏全页面矩阵规划与技术规格书编制 (100% 完成)
  - Phase 1: 核心播放底座与 Modern Soft UI 设计系统组件库 (进行中)
  - Phase 2 ~ 5: 音源引擎、全页面构建、动效歌词/EQ、多端同步 (排期中)

---

## 📄 开源许可证 (License)

本项目基于 [MIT License](LICENSE) 开源发布。
原 AlgerMusicPlayer 项目致谢：[algerkong/AlgerMusicPlayer](https://github.com/algerkong/AlgerMusicPlayer)
