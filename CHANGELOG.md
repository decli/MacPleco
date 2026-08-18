# Changelog · 更新日志

All notable MacPleco changes are recorded here. Release artifacts and complete
release notes are available on the [Releases](https://github.com/decli/MacPleco/releases)
page.

这里记录 MacPleco 的主要变化。安装制品与完整双语说明请见
[Releases](https://github.com/decli/MacPleco/releases) 页面。

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
