# E2E 验收缺陷账本 (Defect Ledger) — 统一格式与工作规则

> 本文件定义「真实使用者视角 E2E 验收」所有缺陷记录的**唯一格式**与**取证规则**。
> 目标：任何一条记录，都能被第三人按同样的步骤复现，并能据此判断"是否真的修好了"。
> 所有子任务产出的账本文件必须使用本格式，编号连续、不重号、不占位。

## 1. 文件分工

| 文件 | 负责人 | 覆盖范围 |
| :--- | :--- | :--- |
| `docs/e2e/ledger-desktop.md` | 子 Agent A | 桌面端全部视图 / 弹窗 / 抽屉 / 快捷键 / 播放栏 / 歌词 |
| `docs/e2e/ledger-mobile.md` | 子 Agent B | 移动端 4 主 Tab + 全部二级页 + 底部抽屉/浮层 |
| `docs/e2e/ledger-data.md` | 子 Agent C | 全项目数据真实性（假数据 / 死链 / 编造元数据 / 断线模块） |
| `docs/e2e/ledger-fixplan-progress.md` | 子 Agent D | `docs/PC_E2E_FIX_PLAN.md` 阶段 0~7 与 44 条缺陷的落地核对 |

## 2. 每条记录的强制格式

```markdown
### [ID] 一句话标题

- **编号**：DESK-001 / MOB-001 / DATA-001 / PLAN-001（前缀与文件对应，三位数字递增）
- **严重度**：P0 阻断可用性 | P1 明显不符合预期 | P2 打磨项
- **类别**：功能缺失 / 数据造假 / 交互缺陷 / 视觉缺陷 / 手感(动效) / 文案不诚实 / 工程卫生 / 与文档不符
- **用户可见现象**：（用户看到什么、点了什么、期待什么、实际发生什么）
- **复现步骤**：1. … 2. … 3. …
- **代码证据**：`app/lib/...dart:行号` （必须贴出真实行号与关键代码片段，禁止凭记忆）
- **数据真实性**：该链路的数据来自哪里（真实网络 / 内置示例 / 硬编码编造 / 死链），是本项目第一优先级判定项
- **原型/文档依据**：（如与 `index.html`、`mobile.html`、`docs/SPEC.md`、`docs/ROADMAP.md` 约定不符，写出具体文件与差异）
- **建议修复**：（具体到文件与做法，不接受"优化体验"这类无法验收的描述）
- **可验收标准**：（一条命令 / 一条测试断言 / 一段固定操作流程，必须能判定通过与否）
- **状态**：待修复 | 修复中 | 已修复(附验证证据) | 已确认不修(附理由)
```

## 3. 取证规则（必须遵守）

1. **禁止凭记忆写行号。** 每条 `代码证据` 必须来自本轮实际读取的文件内容；行号必须与当前工作区一致。
2. **禁止条件断言式验证。** 不允许用 `if (find.xxx.isNotEmpty) { expect(...) }` 这类"找不到就跳过"的写法冒充验证。
3. **必须区分「能渲染」和「能用」。** 一个页面能画出来 ≠ 功能可用。判定"可用"要求：真实数据进入、真实副作用发生（落盘有键值 / 有真实 HTTP 请求 / 有真实音频播放）、失败时有诚实反馈。
4. **数据真实性优先于观感。** 只要展示的是编造的曲目/歌手/设备/账号/统计数字，即使 UI 再精致，也按 P0 或 P1 记录。
5. **不确定就标注"未验证"**，并写清需要什么条件才能验证（例如"需真机 Windows 产物"），不要编造结论。
6. **只记录缺陷，不修改生产代码。** 子 Agent 的职责是取证与记录；代码修改由主 Agent 统一排期执行，避免并发改同一文件冲突。

## 4. 已确认的当前基线（避免重复劳动）

以下事实经主 Agent 本轮实测确认，可直接引用，无需重新验证：

- `flutter analyze` → `No issues found!`；`flutter test` → 90/90 通过；`flutter build macos --debug` → 成功。
- 物理音频驱动真实存在：`app/lib/core/audio/player_backend.dart:22`（audioplayers），进度来自 `onPositionChanged` 流。
- 本地持久化真实存在：`app/lib/core/storage/storage_service.dart` + `app/lib/core/audio/audio_player_service.dart:113 _loadFromStorage()`。
- 内置曲库共 33 首，全部指向 `soundhelix.com` 的 **16 个演示 mp3**（`app/lib/core/audio/track_model.dart`），标题/歌手为编造元数据。
- `app/lib/core/sources/lx_script_sandbox.dart` 生成的音频直链为**不存在的域名**，且该文件在整个 `app/lib` 中**无生产代码调用**（仅被测试引用）。
- `app/lib/core/sync/webdav_sync_service.dart` 与 `lan_sync_service.dart` 实现为真实 HTTP 代码，但**未被任何 UI 或 service 引用**。
- 网易云 `music.163.com/song/media/outer/url?id=` 实测返回 302 → 404。
- `release_windows/` 被 gitignore，仓库内无 Windows 产物；`docs/PC_E2E_FIX_PLAN.md:929-941` 的基线数字（"无 Flutter 工具链"等）已过期。
