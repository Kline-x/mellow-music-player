# Mellow Music · 润音 · 鸿蒙 (HarmonyOS / OpenHarmony) 跨端适配工程规范

本项目基于 Flutter for OpenHarmony (flutter-ohos) 标准 Stage 架构设计，支持在 HarmonyOS NEXT 与 OpenHarmony 4.0+ 跨端运行。

## 1. 架构声明
- **运行时环境**：ArkUI + Node-API (NAPI) + Flutter Engine for OpenHarmony
- **宿主模型**：Stage 模式 (`EntryAbility`)
- **API 版本**：API 10+ (HarmonyOS NEXT 兼容)
- **图形后端**：OpenGLES 3.0 / Vulkan

## 2. 核心配置文件说明
- `AppScope/app.json5`：声明应用包名 `com.mellow.music`、版本号 `1.0.0`、图标及国际化标签；
- `entry/src/main/module.json5`：声明音频后台播放能力 (`backgroundModes: ["audioPlayback"]`)、网络访问权限 (`ohos.permission.INTERNET`) 及局域网广播权限 (`ohos.permission.DISTRIBUTED_DATASYNC`)；
- `entry/src/main/ets/entryability/EntryAbility.ets`：FlutterAbility 派生入口，接管生命周期与分布式流转事件。

## 3. 构建与打包流程
使用 OpenHarmony SDK 与 `hvigor` 工具链进行交叉构建：
```bash
# 切换至鸿蒙环境并执行编译
flutter build hap --release
```
编译产物输出至：`entry/build/default/outputs/default/entry-default-signed.hap`
