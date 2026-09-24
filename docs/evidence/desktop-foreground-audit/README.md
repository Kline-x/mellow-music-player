# 桌面端前台交互证据目录 (Desktop Foreground Audit Evidence)

## ✅ 当前有效的证据

| 文件 | 说明 |
| :--- | :--- |
| `modal_evidence_01_top.png` | 音源切换弹窗顶部（Windows 原生前台实拍） |
| `modal_evidence_02_scrolled.png` | 弹窗垂直滚动后（多尺寸高度自适应） |
| `modal_evidence_03_switched_netease.png` | 点击切换至「网易云音乐」后的生效态与顶部通知 |
| `modal_evidence_04_open_820x700.png` | 820×700 紧凑分屏窗口下的弹窗完整展示 |

以上 4 张为**真实 GPU 合成像素**，可证明 Phase 9「主动换源弹窗 + 6 平台音源切换」在 Windows 物理客户端前台可用。

## ❌ 已删除的无效证据（2026-09-24 清理）

原目录下 24 张 `*_foreground_*.png` / `live_*.png`（1440×900）**全部为空白白屏帧**：

- 24 个文件的 md5 只有 **3 个唯一值**，说明并非 24 个不同交互状态；
- 逐张查验确认：仅渲染出 DWM 绘制的标题栏，Flutter 客户端区域**全白**，不含任何 UI 内容。

**根因**：截图驱动使用桌面 DC `BitBlt(SRCCOPY|CAPTUREBLT)`。Flutter 在 Windows 上经
ANGLE/D3D 渲染到 DWM 合成表面，桌面 DC 位块传输无法读取该表面，因而返回白屏。

**修复**：`run_pc_physical_e2e.py` 的 `capture_window()` 已改为优先
`PrintWindow(hwnd, memDC, PW_RENDERFULLCONTENT)`，并新增空白帧检测——
一旦捕获到均匀色帧，脚本会打印 `[WARN]` 并以**非 0 退出码失败**，杜绝再次产出伪证据。

> 由于本机为 macOS，无法执行 Windows 物理 E2E。**待有 Windows 环境后**，重新运行
> `python run_pc_physical_e2e.py` 生成真实前台证据，再更新 `docs/PROGRESS.md` 的物理验收结论。
