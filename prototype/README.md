# Mellow Music · 原型设计专区 (Design Prototypes)

本目录归档了 Mellow Music 在产品初期探索与交互设计的核心 Web 原型及视觉规范资产。

## 目录结构

- `index.html`：桌面端沉浸工作台原型 (1440x900 响应式设计，涵盖发现、搜索、排行榜、歌词巨幕、均衡器等)
- `mobile.html`：移动端原生原型 (390x844 响应式设计，涵盖 4-Tab 导航、私人漫游 FM、胶囊播放条等)
- `design_tokens.css`：Modern Soft UI 设计系统 Token 规范 (阴影景深、圆角、调色板、声学光晕)
- `server.cjs`：基于 Node.js 原生的轻量本地静态服务
- `audio/`：原型内置的基础演示音轨

## 本地预览方式

```bash
# 1. 进入原型目录
cd prototype

# 2. 启动本地轻量预览服务 (无需构建工具)
npm start

# 或直接使用 Node 启动
node server.cjs
```

启动后在浏览器中访问：
- 桌面端原型：`http://localhost:3000` 或 `http://localhost:3000/index.html`
- 移动端原型：`http://localhost:3000/mobile.html`
