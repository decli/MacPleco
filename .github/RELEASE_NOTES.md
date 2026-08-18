MacPleco 0.3.0 — the hotfix that matters and the glass done right.

MacPleco 0.3.0 —— 关键修复 + 真正的原生玻璃。

### Fixed: the launch freeze · 修复：启动即卡死

0.2.0 could beach-ball permanently on the Overview page. The cause was the
ambient background: it re-rasterised the entire window on the main thread
twelve times a second (a TimelineView-driven Canvas behind a 90pt blur inside
`drawingGroup()`). The water is now drawn as static radial-gradient fields —
the glass refracts them just the same, and an adversarial review of the fix
pushed it one step further: even an animated drift would have kept every
piece of glass chrome re-compositing at display refresh forever, for motion
of 0.02pt per frame. A cleaner that burns GPU while idle is lying about its
purpose, so the window now idles completely. Apologies for the force-quits.

0.2.0 会在概览页永久风火轮。祸首是环境背景：TimelineView 驱动的 Canvas + 90pt
模糊 + drawingGroup，每秒在主线程上把整个窗口重新光栅化十二次。现在色场改为静态
径向渐变 —— 玻璃折射效果不变；而且对修复方案的对抗性评审又往前推了一步：哪怕改成
漂移动画，也会让所有玻璃件永远以刷新率重合成，只为每帧 0.02pt 的不可见位移。清理
工具自己空转烧 GPU 是自我背叛，所以现在窗口可以完全空闲。为强制退出致歉。

Also from the review: the large-files list no longer builds 120 rows (each
with a synchronous disk icon read) in one main-thread update; the depth
ring's resting swell drops to 10 fps; live sampling's lifetime is tied to
task cancellation so a flaky menu-bar callback can't leave it running
forever; and the disk-capacity query moved off the main thread.

评审还带来：大文件列表不再一次性在主线程构建 120 行（每行一次同步磁盘图标读取）；
深度环静息水波降到 10 fps；采样生命周期绑定任务取消，菜单栏回调丢失也不会永远空转；
磁盘容量查询移出主线程。

### Native Liquid Glass, for real this time · 这次是真的原生液态玻璃

You asked the right question: macOS does have a direct API for this — two,
in fact. `glassEffect()` for custom elements (we were using it), and the
system containers themselves, which get the unmistakable Tahoe chrome for
free. 0.2 hand-built the sidebar and title bar to control every pixel, which
is precisely why it stopped looking native. 0.3 returns the shell to the
system: a real `NavigationSplitView` sidebar (the OS's own floating glass),
real toolbar items in the system's glass capsules, real titles via the
navigation bar. Window dragging, double-click zoom and full screen are
untouched system behaviour. Our own glass is reserved for content cards,
where custom elements belong.

问得好：macOS 确实有直接的 API —— 其实是两层。自定义控件用 `glassEffect()`（我们
一直在用）；而系统容器本身在 macOS 26 上自动获得那种一眼认出的 Tahoe 玻璃。0.2 为
了控制每个像素自绘了侧栏和标题栏，恰恰因此失去了原生感。0.3 把外壳还给系统：真正的
NavigationSplitView 侧栏（系统自己的悬浮玻璃）、真正的工具栏胶囊、真正的导航标题。
窗口拖拽、双击缩放、全屏全部是未经改动的系统行为。自绘玻璃只留给内容卡片。

### Also · 顺带

- Full Disk Access probe moved off the main thread. 权限探测移出主线程。
- Live sampling is reference-counted, so closing the menu bar panel no longer
  freezes the Monitor page's charts. 采样引用计数化，关掉菜单栏面板不再冻结监控页。
- Page actions (rescan, tabs, run) live in the real toolbar. 页面操作进入原生工具栏。

### Install · 安装

Drag to Applications; first launch needs System Settings → Privacy & Security
→ Open Anyway (or `xattr -dr com.apple.quarantine /Applications/MacPleco.app`);
grant Full Disk Access when asked. macOS 15+; Liquid Glass renders on macOS 26.

拖入应用程序；首次打开在「隐私与安全性」点「仍要打开」；按引导授予完全磁盘访问权限。
需要 macOS 15+，液态玻璃在 macOS 26 上呈现。

---

Feedback → https://github.com/decli/MacPleco/issues · Inspired by
[Mole](https://github.com/tw93/Mole) · GPL-3.0
