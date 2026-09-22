# Mellow Music · 润音 (Flutter Client)

> 基于 Flutter 的 Modern Soft UI 原生跨平台音乐客户端，支持 Desktop (Windows, macOS, Linux) 与 Mobile (iOS, Android)。

## 环境要求与运行

- **Flutter SDK**: `>= 3.47.0` (Dart `>= 3.13.3`)
- **Node.js**: `>= 18.0.0` (用于 Web 静态服务与 E2E 验证)

### 开发与测试命令

```bash
# 依赖拉取
flutter pub get

# 代码静态分析 (要求 0 错误 0 警告)
flutter analyze

# 单元与组件集成测试
flutter test

# 桌面端与移动端调试运行
flutter run -d macos    # macOS 桌面端
flutter run -d windows  # Windows 桌面端
flutter run -d chrome   # Web 浏览器端
```

## 已知状态与修复规划

本项目正处于从高保真原型向生产级音乐播放器演进的阶段：
- **详见根目录验收报告**：`../docs/PC_E2E_ACCEPTANCE_ISSUES.md`
- **分阶段修复实施计划**：`../docs/PC_E2E_FIX_PLAN.md`
