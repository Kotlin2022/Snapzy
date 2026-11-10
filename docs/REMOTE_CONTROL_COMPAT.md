# 远程控制兼容（UU 远程 / ToDesk / …）

## 现象

开启 UU 远程（或同类远程工具）时，区域截图可能表现为：

- 选区准星不跟随鼠标
- 系统光标消失
- 整个遮罩像卡住，但 Esc 仍可取消

另外，**本机重签/重装**后可能出现：系统设置里「屏幕录制 / 辅助功能」已打开，
但 Snapzy 权限页仍显示「授予访问权限」——菜单项变灰，截图全屏发灰。

## 原因

### 1. Live Passthrough 事件拦截

无冻结背景的截图模式会安装「吞掉」鼠标事件的 `CGEvent` tap，并隐藏系统光标。
远程工具也在同一条输入链路上注入指针事件，两边冲突后选区无法移动、光标不可见。

**处理：** 检测到已知远程助手进程（`UURemote.app/`、ToDesk、向日葵、RustDesk，
见 `LivePassthroughRemoteControlConflict`）时，跳过 Live Passthrough，改用窗口事件 /
指针轮询。

### 2. 区域标注藏光标 + SwiftUI 悬停

区域标注会冻结画面、隐藏系统光标，并用 SwiftUI 的 `onContinuousHover` / `DragGesture`
绘制准星。远程注入经常只改系统指针位置、不投递这些 AppKit/SwiftUI 事件，导致
准星冻住且真光标被藏起。

**处理：** 同一冲突检测下，保留系统光标，并以约 60fps 轮询 `NSEvent.mouseLocation` /
`pressedMouseButtons` 驱动准星与选区（`InlineAreaAnnotateSession`）。

### 3. 本机安装签名与 TCC

Ad-hoc 重签会改变 code directory hash。系统设置里旧身份的「屏幕录制」可能仍显示开启，
但新二进制上 `CGPreflightScreenCaptureAccess()` 为 false，应用侧判定无权限。

**本机安装注意：**

1. 尽量用稳定的 Apple Development 证书签名（不要用 ad-hoc）。
2. 替换 App 后执行：`tccutil reset ScreenCapture com.local.snapzy`（以及 Accessibility）。
3. 退出 Snapzy → 删掉系统设置里残留的 Snapzy 条目 → 再启动 → 重新授权 → 再退出一次，
   让授权绑定到当前运行的二进制。

## 代码位置

| 模块 | 作用 |
|------|------|
| `LivePassthroughRemoteControlConflict` | 通过 `proc_pidpath` 检测远程助手 |
| `LivePassthroughInputLogic.shouldUseLivePassthroughInput` | 是否启用 Live tap |
| `AreaSelectionController` 远程兼容轮询 | 普通区域选区 |
| `InlineAreaAnnotateSession` 远程兼容轮询 | 区域标注选择阶段 |

## 验证

在 UU 远程的 Daemon/Service 运行时触发区域截图 / 区域标注，日志中应出现：

```text
Live passthrough skipped: remote-control agent conflict …
Inline area annotate: remote-control agent conflict — keeping system cursor, polling pointer
Area selection remote-compat pointer polling active
```
