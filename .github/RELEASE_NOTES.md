MacPleco 0.2.0 — the redesign release. Every change below came out of running
0.1.0 on a real Mac and treating what came back as a design review.

MacPleco 0.2.0 —— 重设计版本。以下所有改动都来自 0.1.0 在真机上的实测反馈。

### The glass is real now · 玻璃真的显形了

Liquid Glass is refraction — over a featureless background it looks like flat
paper, which is exactly what 0.1.0's light mode was. The window now sits on
slow-drifting ambient colour ("the tank"), so every panel visibly bends the
light behind it, in both appearances. The drift freezes under Reduce Motion.

液态玻璃靠折射显形，放在纯白背景上和白纸没有区别 —— 0.1.0 的浅色模式正是如此。
现在整个窗口坐在一层缓慢漂移的环境色（"水族箱"）上，浅色深色下每块玻璃都能折射到
背后的光。开启"减少动态效果"时完全静止。

### Interface · 界面

- Hand-built sidebar: brand-coloured sliding selection pill, larger type,
  ⌘1–6 section shortcuts. 自绘侧栏：品牌色滑动药丸、更大的字号、⌘1–6 快捷键。
- Title bar is transparent instead of hidden — window dragging, double-click
  zoom and full screen behave normally again. 标题栏改为透明而非隐藏，拖拽、双击
  缩放、全屏行为全部回归。
- Content sits in a centred column; big windows gain atmosphere, not blank
  space. 内容居中收束，大窗口边缘是氛围而不是空白。
- Cards rise in with staggered entrances and lift on hover; numbers tick.
  卡片错峰入场、悬停微升、数字滚动。
- Sections assemble with motion; the depth ring gained waves, bubbles and a
  sonar sweep while scanning. 深度环有了波浪、气泡和扫描声呐。
- Cleaning shows a bubbling veil while files travel, then a count-up success
  card with a particle burst. 清理过程有气泡上升的遮罩，完成后数字滚动 + 粒子绽放。

### Fixed from device testing · 真机实测修复

- **RAM units**: a 128 GB machine was reported as "137 GB". Memory now uses
  binary units like Activity Monitor; storage stays decimal like Finder.
  **内存单位**：128 GB 的机器显示成 137 GB，已改为与活动监视器一致的二进制单位。
- **Space page blank for ~10 s**: folder sizes now stream in as each finishes
  (the biggest walk no longer gates the first paint), levels are cached per
  session, and skeleton tiles shimmer while measuring.
  **空间页 10 秒空白**：测完一个显示一个，会话内缓存已测层级，测量期间骨架屏占位。
- The caution banner rendered as a solid amber slab (Glass.tint saturates
  whole panels); tint is now a subtle wash. 橙色横幅色块问题已修复。
- Clean categories no longer inherit the strictest item's colour — one
  cautious item was painting whole categories amber. 分类不再因个别谨慎项整体变黄。
- The font-cache repair icon rendered as CJK text (localised SF Symbol).
  字体缓存图标显示成汉字的问题已修复。
- Tune-Up's disabled Run button hid itself instead of sitting there pale.
  优化页的灰色"执行"死按钮改为无选中时隐藏。
- Space treemap colours now mean something: aqua depth tracks size rank,
  loose files surface warm. 矩阵图颜色有了含义：越大越深，文件是暖色。

### New · 新增

- **Menu bar fish**: free space at a glance, live CPU/memory/thermal, one
  click into cleaning. Toggle in Settings.
  **菜单栏小鱼**：常驻显示剩余空间和实时状态，一键进入清理。可在设置中关闭。
- **Large-file radar** in Space: everything over 100 MB in your everyday
  folders, with age, reveal and trash. Hidden folders stay Clean's job.
  **大文件雷达**：常用文件夹里超过 100 MB 的文件，带年龄标注，可显示或移到废纸篓。
- **Cleaning ledger**: "MacPleco has freed 84 GB on this Mac" — cumulative,
  persistent, resettable. **清理账本**：累计释放统计，可清零。
- **Appearance override** (system / light / dark) and per-core CPU bars plus
  real process icons in Monitor. **外观切换**与监控页每核心负载条、真实进程图标。

### Install · 安装

Same as before: drag to Applications, right-click → Open on first launch (or
`xattr -dr com.apple.quarantine /Applications/MacPleco.app`), grant Full Disk
Access when asked. macOS 15+; Liquid Glass renders on macOS 26.

安装方式不变：拖入应用程序，首次打开在「隐私与安全性」里点「仍要打开」，按引导授予
完全磁盘访问权限。需要 macOS 15+，液态玻璃在 macOS 26 上呈现。

---

Feedback → https://github.com/decli/MacPleco/issues · Inspired by
[Mole](https://github.com/tw93/Mole) · GPL-3.0
