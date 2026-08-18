MacPleco 0.3.1 — the launch-freeze fix, verified.

MacPleco 0.3.1 —— 经实机验证的启动卡死修复。

### Fixed: Overview no longer beach-balls · 修复：首页不再卡死

Version 0.3.0 removed an expensive animated background, but a second and more
fundamental launch bug remained on macOS 26: binding
`MenuBarExtra(isInserted:)` directly to `@AppStorage` could create a SwiftUI
scene and main-menu invalidation loop. The main thread rebuilt the application
menu continuously, pinning a CPU core while memory climbed until the window
stopped responding.

0.3.0 虽然移除了高开销的动态背景，但 macOS 26 上还藏着第二个、更根本的启动问题：
把 `MenuBarExtra(isInserted:)` 直接绑定到 `@AppStorage`，可能触发 SwiftUI 场景与
主菜单的无限失效循环。主线程会不停重建应用菜单，占满一个 CPU 核心，内存持续增长，
最终让首页完全失去响应。

The menu-bar preference now lives in ordinary SwiftUI state. Persistence is
performed only when that state changes, so the setting still survives relaunch
without participating in scene invalidation. On macOS 26.5.2, the same launch
that previously reached 100% CPU and more than 800 MB now settles at 0% CPU,
about 82 MB, with the main thread asleep in the normal event loop.

菜单栏开关现在由普通 SwiftUI 状态管理，只在状态改变时写入偏好设置。因此它仍能跨启动
保存，却不会再参与场景失效循环。实测同一台 macOS 26.5.2：修复前 CPU 约 100%、内存
超过 800 MB；修复后空闲 CPU 为 0%，内存约 82 MB，主线程正常休眠等待事件。

### Truly idle when idle · 静止时真正静止

The Overview depth ring no longer keeps a 10 fps `TimelineView` alive at rest.
It renders one static frame while idle and animates only during an active scan.
This lets the entire glass hierarchy stop compositing when there is no work.

概览页的水位环不再在静止时维持 10 fps 的 `TimelineView`。空闲时只绘制一帧，仅在扫描
期间播放动画，让整套玻璃界面在无任务时真正停止重合成。

### More native Liquid Glass · 更原生的液态玻璃

- Sidebar selection, hover and focus are handled by the native macOS sidebar
  `List` instead of a hand-painted gradient row.
- Primary actions call the macOS 26 Liquid Glass API directly with
  `glassEffect(.regular.tint(...).interactive())`.
- Navigation remains a system `NavigationSplitView`, with native navigation
  titles, toolbar placement, window dragging, zoom and full-screen behaviour.
- macOS 15–25 continue to use the existing system-material fallback.

- 侧栏选择、悬停与焦点改由 macOS 原生侧栏 `List` 处理，不再覆盖手绘渐变选中条。
- 主要操作按钮在 macOS 26 上直接调用系统液态玻璃 API：
  `glassEffect(.regular.tint(...).interactive())`。
- 导航继续使用系统 `NavigationSplitView`，标题、工具栏、窗口拖动、缩放和全屏都由系统
  接管。
- macOS 15–25 继续使用原有系统材质回退。

### Install · 安装

Drag MacPleco into Applications. On first launch, use System Settings →
Privacy & Security → Open Anyway if macOS asks, then grant Full Disk Access
for cache measurement. Requires macOS 15 or later; native Liquid Glass renders
on macOS 26.

把 MacPleco 拖入「应用程序」。首次启动如遇提示，请前往「系统设置 → 隐私与安全性」
选择「仍要打开」，然后授予完全磁盘访问权限以测量缓存。需要 macOS 15 或更高版本；
原生液态玻璃效果在 macOS 26 上呈现。

---

Feedback → https://github.com/decli/MacPleco/issues · Inspired by
[Mole](https://github.com/tw93/Mole) · GPL-3.0
