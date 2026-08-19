# Changelog · 更新日志

All notable MacPleco changes are recorded here. Release artifacts and complete
release notes are available on the [Releases](https://github.com/decli/MacPleco/releases)
page.

这里记录 MacPleco 的主要变化。安装制品与完整双语说明请见
[Releases](https://github.com/decli/MacPleco/releases) 页面。

## [0.3.5] - 2026-08-20

### Fixed · 修复

- A stat card can no longer be widened by its own contents. The memory card's
  three-part legend wanted 245pt inside a card that had 217pt, so the card grew
  past its column and pushed into both neighbouring gutters — which is why the
  gap before the last card looked bigger than the rest. Measured across window
  sizes, all four cards are now identical in width with identical gaps.
- Legends give way instead: normal gutters, then tight gutters, then swatch and
  reading only, whichever is the widest that fits.
- The space map's readout is now derived from where the pointer actually is,
  rather than from whichever tile last saw a hover event. Tiles that re-lay out
  under a still cursor — a folder finishing its measurement, or drilling into
  the next level — can no longer leave the header naming one item while the
  cursor rests on another.

- 指标卡片不会再被自身内容撑宽。内存卡片的三段图例需要 245pt，而卡片只有 217pt，于是
  卡片越出所在列、挤进两侧的间距——这正是最后一张卡片间距看起来更大的原因。多种窗口
  宽度下实测：四张卡片现在宽度一致、间距一致。
- 图例改为逐级让步：正常间距 → 紧凑间距 → 只保留色块与数值，取能放下的最宽一种。
- 空间地图的读数改为由指针位置实时判定，不再依赖“哪个色块最后收到过悬停事件”。指针
  不动而色块重排时（某个文件夹刚测量完成，或进入下一层），标题栏不会再显示指针并未
  指向的项目。

## [0.3.4] - 2026-08-20

### Added · 新增

- Batch uninstall: tick several apps and review one sheet listing every bundle
  and every leftover, each still individually declinable.
- A permanently visible uninstall button on every app row, and a permanently
  visible Run button on every Tune-Up repair, plus select-all bars on both.
- Login items can be sorted by name, by scope, or by which ones run at login,
  and searched.
- Process table: search by name, path or pid; filter to apps or system
  processes; sort by name, memory, start time or CPU in either direction;
  reveal in Finder; and quit or force quit a process.
- Whole-device GPU utilisation, read from the IORegistry.

- 批量卸载：勾选多个应用后在一张清单里查看每个本体与每一处残留，仍可逐项取消。
- 应用行常驻“卸载”按钮，优化项常驻“执行”按钮，两个页面都新增全选栏。
- 开机启动项支持按名称、范围或“开机即启动”排序，并支持搜索。
- 进程表支持按名称/路径/PID 搜索、区分应用与系统进程、按名称/内存/启动时间/CPU 正反序
  排序、在访达中定位，以及请求退出或强制结束。
- 新增整机 GPU 使用率，数据来自 IORegistry。

### Changed · 改进

- Folder measurement now uses `getattrlistbulk` and a work-stealing pool, so
  the whole machine finishes the one enormous folder instead of leaving it to a
  single thread. A 417 GB home folder drops from 17.9s to 3.1s and `~/Library`
  from 17.8s to 2.5s, reporting the same totals as before.
- Overview and Monitor share one stat card whose slots are reserved whether or
  not they are filled, so a row of cards is equal-height by construction.
- CPU, memory, GPU and network each plot their components in distinct colours
  with a legend, rather than blending two or three quantities into one line.
- Per-core bars and the machine's static details moved out of the metric grid
  into their own strip.
- The four monitor gauges now carry parallel readings — cores, installed
  memory, video memory in use, peak rate — in place of two subtitles that
  explained how their own chart was drawn.
- Space map tiles are coloured by identity rather than by size rank. Area
  already says how big something is; ten muted folder hues say which folder it
  is, files keep one warm tone of their own, and the grouped tail stays grey.

- 文件夹体积测量改用 `getattrlistbulk` 与工作窃取线程池，整台机器一起完成最大的那个
  文件夹，而不是留给单线程。417 GB 的个人文件夹从 17.9 秒降到 3.1 秒，`~/Library`
  从 17.8 秒降到 2.5 秒，统计结果与此前一致。
- 概览页与监控页共用同一种指标卡片，未使用的插槽也会占位，因此同一行卡片天然等高。
- CPU、内存、GPU、网络各自用不同颜色绘制其组成部分并配图例，不再把两三个量混成一根线。
- 每核心负载条与机器静态信息移出指标网格，独立成条。
- 监控页四张卡片的副标题统一为同类读数——核心数、内存容量、显存占用、峰值速率，
  不再用两句话解释自己的曲线是怎么画的。
- 空间地图的色彩改为表示“是哪一项”，不再表示大小：面积已经说明了大小，十种低饱和
  文件夹色负责区分身份，文件保留自己的暖色，合并的其他项保持中性灰。

### Fixed · 修复

- Cards on the Overview and Monitor pages no longer render at different heights
  and sit centred against one another.
- The always-empty per-process GPU column is gone; the space now carries process
  start time, which is a number that exists.
- Four stat cards no longer break as a row of three with one card stranded
  underneath, and no longer stop short of the right edge. The grid counts its
  cards instead of filling the container with as many columns as fit.
- The space map no longer keeps a tile highlighted, and reading it out in the
  header, after the pointer has left the map or moved into another folder.

- 概览页与监控页的卡片不再高度不一、互相居中错位。
- 移除永远为空的“每进程 GPU”列，该位置改为显示确实存在的进程启动时间。
- 四张指标卡片不再出现“上排三张、下面孤零零一张”的换行，也不再在右侧留出一整列空白：
  网格按卡片数量分列，而不是按容器能塞下多少列。
- 指针移出空间地图或进入下一层文件夹后，地图不再保留高亮，标题栏也不再继续读出
  一个指针并未指向的项目。

## [0.3.3] - 2026-08-19

### Added · 新增

- CPU, GPU and memory column selectors for the busiest-process table.
- Live-reordering and fixed-position refresh modes.
- Hover-linked Top 12 cards below the space map.
- Absolute paths, always-visible Finder buttons and context-menu path copying
  for large files.
- Separate English and Simplified Chinese README documents with language links.

- “最占资源的进程”支持选择 CPU、GPU、内存排序。
- 新增“实时排序”与“固定位置刷新”模式。
- 空间地图下方新增悬停联动的 Top 12 卡片。
- 大文件新增绝对路径、常驻访达按钮和右键复制路径。
- README 拆分为可切换的英文版与简体中文版。

### Changed · 改进

- Rebuilt the space map as a full-width, fixed-height visualisation with larger
  adaptive labels, percentages, a legend, breadcrumbs and long-tail grouping.
- Standardised the four monitor summary cards to equal dimensions.
- Increased process refresh cadence from roughly 4.5 seconds to 3 seconds.

- 空间地图改为全宽、稳定高度布局，提供更大的自适应文字、占比、图例、面包屑和长尾合并。
- 监控页顶部四张摘要卡片统一尺寸。
- 进程刷新间隔由约 4.5 秒缩短至 3 秒。

### Fixed · 修复

- Fixed the treemap origin bug that created a large blank area and pushed tiles
  beyond the right and bottom edges.
- Removed visual row jumping when fixed-position monitoring is selected.
- GPU unavailability is now explicit; no CPU or energy proxy is presented as a
  GPU percentage.

- 修复矩阵树图原点错误造成的大片空白与右侧、底部溢出。
- 选择“固定位置”后，数据刷新不再导致进程行跳动。
- GPU 数据不可用时明确显示原因，不再存在用 CPU 或能耗冒充 GPU 百分比的风险。

## [0.3.2] - 2026-08-18

- Added full paths, Finder buttons and right-click actions to every cleanup
  target, and removed the hidden 80-row display limit.
- 清理项新增完整路径、访达按钮和右键操作，并移除隐藏的 80 行显示上限。

## [0.3.1] - 2026-08-18

- Fixed the launch beach-ball caused by menu-bar scene invalidation and adopted
  native Liquid Glass APIs on macOS 26.
- 修复菜单栏场景反复失效造成的启动卡死，并在 macOS 26 使用原生液态玻璃 API。

## [0.3.0] - 2026-08-18

- Introduced the native SwiftUI application, safety policies, cleanup, apps,
  space, tune-up, monitor and menu-bar experiences.
- 发布原生 SwiftUI 应用，以及安全策略、清理、应用、空间、优化、监控和菜单栏功能。

[0.3.3]: https://github.com/decli/MacPleco/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/decli/MacPleco/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/decli/MacPleco/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/decli/MacPleco/releases/tag/v0.3.0
