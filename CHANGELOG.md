# Changelog · 更新日志

All notable MacPleco changes are recorded here. Release artifacts and complete
release notes are available on the [Releases](https://github.com/decli/MacPleco/releases)
page.

这里记录 MacPleco 的主要变化。安装制品与完整双语说明请见
[Releases](https://github.com/decli/MacPleco/releases) 页面。

## [0.4.0] - 2026-09-08

### Changed · 改进

- The interface is rebuilt on the v2.0 UI standard (`docs/ui-standard.md`).
  Four control heights instead of a dozen — 24 for row actions, **28 as the
  default**, 36 for a card's own action, 44 for the one thing a page wants you
  to do. 28 rather than 24 because a Han glyph fills its em box: 13pt Chinese
  in a 24pt capsule leaves 5.5pt of air and reads as if it is touching the
  edges, where the same capsule looks roomy around Latin text.
- The sidebar and the page share one masthead band, and everything in it sits
  on **one baseline** 33pt below the title bar. Aligning frame centres is not
  enough across two type sizes in Chinese; aligning baselines is. Measured, the
  wordmark and the page title now both land at y=85 on all six pages.
- Tabs came out of the masthead slot and sank to the content, above the list
  they switch. The slot holds exactly one page-scoped control, so it is 28pt
  tall on every page and the note under it no longer moves.
- Containers impose size; controls no longer accept it. `SearchField` was the
  app's single search control and still stood 7pt taller than the popup beside
  it, because nothing said the two were neighbours. `FilterRow` now sets the
  height, the type size and the system control size for everything on the row.
- **A destructive action is never the loudest thing on the screen** — the
  README's first promise, which the code had been breaking. A call site now
  declares an `ActionIntent` and cannot choose a colour: `go` is the only
  filled intent, `destructive` is always outlined, and a filled danger button
  exists only inside a sheet marked `confirmationSurface()`. "Uninstall
  selected" is an outlined proposal; "Skip the Trash" turns the clean button
  into an outlined `永久删除` that routes through a confirmation instead of
  acting.
- Fixed the contrast of the app's loudest button. White on `aquaSweep`
  measured 2.62:1 in light appearance and 1.40:1 in dark — worse than the pink
  Uninstall button. Filled controls now use a `goFill` that goes deep in light
  and stays bright in dark, paired with an `onAccent` foreground that flips
  with it: 4.64:1 and 5.68:1. The sweep stays where it belongs, on the depth
  ring and the capacity bars, which carry no text.
- Clickable glass carries a legibility floor — an opaque-enough fill and a
  stroke of at least 16%, in both the macOS 26 and the fallback path. The
  Overview's secondary button previously had no visible edge on the pale
  ground.
- One badge replaces nine, one row geometry replaces eight, six motion
  durations replace thirteen, and readings set the unit apart from the
  quantity. `scripts/check-ui-standard.sh` runs first in CI so none of it
  drifts back.
- The standard ships with the app: `docs/ui-standard.md` is the rulebook and
  `docs/ui-standard.html` draws every size at one pixel per point, so a table
  of measurements can be checked against a screenshot instead of trusted.

- 界面按 v2.0 界面标准（`docs/ui-standard.md`）重建。控件高度收成四档——行内 24、
  **默认 28**、卡内主动作 36、每页唯一的号召动作 44。默认档是 28 而不是 24：中文字身
  满格，13pt 中文在 24 高胶囊里上下只剩 5.5pt，看着顶边，而同样的胶囊配拉丁文字反而
  宽松。
- 侧栏与页面共享同一条报头带，带内所有文字落在标题栏下方 33pt 的**同一条基线**上。
  中英混排下把两个不同字号的文字框居中对齐是不够的，对齐基线才够。实测六个页面的
  字标与页面标题都在 y=85。
- 页签从报头插槽下沉到内容区，长在它所切换的列表上方。插槽只放一个页面级控件，因此
  每页恒为 28 高，下面的说明行不再忽高忽低。
- 尺寸由容器施加，控件不再接受尺寸参数。`SearchField` 一直是全 App 唯一的搜索实现，
  却仍比邻座的下拉高 7pt——因为没有东西规定它跟谁并排。`FilterRow` 现在为整行统一
  高度、字号与系统控件尺寸。
- **破坏性动作不再是屏幕上最显眼的那个**——README 第一段的承诺，此前一直没兑现。
  调用方现在声明 `ActionIntent`，选不了颜色：只有 `go` 能实心，`destructive` 一律
  描边，实心 danger 只存在于标了 `confirmationSurface()` 的确认界面里。「卸载所选」
  变成描边提议；打开「跳过废纸篓」后，清理按钮改文案、改形态，并改为先弹确认。
- 修复了全 App 最响那颗按钮的对比度。白字压 `aquaSweep` 实测浅色 2.62:1、深色
  1.40:1——比那颗被拿来当反面教材的粉红按钮还差。实心控件改用 `goFill`（浅色走深、
  深色保持亮），配一个跟着外观翻转的 `onAccent` 前景色：4.64:1 与 5.68:1。渐变回到
  它该待的地方——不承载文字的水位环与容量条。
- 可点的玻璃有了可辨度下限：足够不透明的填充加至少 16% 的描边，macOS 26 与回退分支
  都画。此前「看看有哪些」在浅色地上根本看不出边界。
- 一个徽章取代九种写法，一套行几何取代八种行高，六档动效取代十三种时长，数值与单位
  分开排。`scripts/check-ui-standard.sh` 在 CI 第一步拦截回流。
- 标准随应用一起发布：`docs/ui-standard.md` 是规则正文，`docs/ui-standard.html` 把每个
  尺寸按 1 像素 = 1 点画出来，尺寸表可以直接跟截图比对，而不必选择相信它。

## [0.3.6] - 2026-09-07

### Changed · 改进

- One page header, in the content, on all six pages. It used to be the
  system's `navigationTitle`/`navigationSubtitle`, which AppKit draws at about
  14pt and 10.5pt in the title bar — the page's own name rendered smaller than
  half the labels below it, and no styling could reach it. The header is now
  a real element on the content's own left edge: 20pt for the name, 13pt for
  the sentence that says what the page does. Measured at the minimum window
  width in both languages, the title starts at x=284 and the subtitle at
  x=284 on every page.
- Page-scoped controls have one home. The mode switch was a toolbar item on
  Apps and Space, "Rescan" was a toolbar item on Clean, and Space's identical
  "Look again" was a ghost button buried in a card halfway down the content.
  All four now sit in the header's trailing slot, right-aligned to the content
  column rather than to the window: measured, every page's control ends at the
  same x.
- Three cards that each re-explained their own page — Tune's intro, Apps'
  login-items intro, Space's large-files header — are one `PageNote` line
  under the header, at one size, with one hanging indent. Space's "click a
  tile to open it" hint moved with them, from the bottom of the page to above
  the map it describes.
- One type ramp. The app used 27 distinct point sizes, eight of them between
  9 and 13.5pt, and `SelectionBar` set four adjacent labels in a single row at
  12, 11.5, 12.5 and 11pt. Every size now comes from an eleven-step ramp with
  named roles, and no raw font size literal remains in the source.
- The content column is one width. Space's map used 1240pt while every other
  page used 1140, so the content's right edge moved when you changed page.
- One search control. Monitor had copied `SearchField`'s twenty-two lines
  rather than importing it, and the two copies had drifted to 300pt and 260pt
  wide; the component now owns its width and lives in the design system.

- 六个页面共用同一个页面标题，且放回内容区。此前用的是系统的
  `navigationTitle`/`navigationSubtitle`，由 AppKit 以约 14pt 和 10.5pt 绘制在标题
  栏里——页面自己的名字比下方一半的标签还小，而且样式完全够不着。现在它是内容区
  里真正的元素，与内容同一条左边线：名称 20pt，说明这一页做什么的句子 13pt。在最小
  窗口宽度下实测，中英文六个页面的标题与副标题都从 x=284 开始。
- 页面级控件只有一个位置。模式切换此前在「应用」和「空间」的工具栏里，「重新扫描」在
  「清理」的工具栏里，而「空间」里作用完全相同的「重新查找」却是内容中段某张卡片里的
  一个次要按钮。四者现在都在标题栏右侧插槽中，对齐内容列的右边线而不是窗口右边线：
  实测每个页面的控件都终止于同一个 x。
- 三张各自重复解释本页的卡片——「优化」的说明、「应用」的开机项说明、「空间」的大文件
  说明——合并为标题下方的一行 `PageNote`，同一字号、同一悬挂缩进。「空间」的「单击进入
  文件夹」提示也随之从页面底部移到了它所描述的地图上方。
- 统一字号阶梯。此前全应用使用 27 种字号，其中 8 种挤在 9 到 13.5pt 之间，`SelectionBar`
  更是在同一行里用了 12、11.5、12.5、11pt 四种。现在所有字号都来自一套十一级、带语义
  命名的阶梯，源码中不再有任何字号字面量。
- 内容列只有一个宽度。「空间」的地图此前用 1240pt，其余页面用 1140pt，换页时内容的右
  边线会移动。
- 只有一个搜索控件。「监控」此前是把 `SearchField` 的二十二行代码抄了一份而不是引用它，
  两份副本已经漂移成 300pt 和 260pt 两种宽度；该组件现在自己决定宽度，并归入设计系统。

### Fixed · 修复

- `~/.cache` is no longer treated as one undifferentiated pile of junk. The
  catch-all rule labelled every directory under it "Safe to remove" and ticked
  it, which on a developer's Mac meant offering `~/.cache/huggingface`
  alongside a hash table. The rules that really are caches — pip, uv,
  go-build, pre-commit — are named individually and stay pre-selected; the
  sweep that catches everything else is listed for review and never ticked for
  you. Playwright and Puppeteer browser downloads are review-only wherever
  they landed, matching the treatment `~/Library/Caches/ms-playwright` already
  had.
- Model downloads and working environments under `~/.cache` are never offered.
  A rule is matched at its top level, so the existing weight heuristics —
  which look for `/models/`, `.gguf` and friends *in the matched path* — never
  saw inside `~/.cache/huggingface`; those stores are now named. Poetry is the
  subtler case: removal takes the whole matched directory, so offering
  `~/.cache/pypoetry` at all would have taken `virtualenvs` with it. The
  directory itself is refused as an exact match while `~/.cache/pypoetry/
  artifacts` and `~/.cache/pypoetry/cache` stay reclaimable on their own.
- A test now asserts that no catalog rule is shadowed by an earlier one. A
  specific rule written after a sweep that covers it can never fire, and its
  category, label and safety are lost silently — which is exactly the failure
  the two fixes above depend on not happening.
- A clean now re-reads which apps are running at the moment you press the
  button, not at the moment of the scan. Scanning, going off to use Chrome and
  coming back would delete Chrome's cache out from under it on an answer that
  was minutes old. Anything skipped this way is named in the result, with the
  bytes it left behind — a low number that says why beats a number that is
  quietly wrong.
- The Space map explains why the folder sizes cannot add up to the used space,
  when there is something to explain: Time Machine local snapshots pin the
  blocks of files that have since been deleted or rewritten, those blocks
  belong to no folder, and the free-space figure already counts them as
  reclaimable. Shown with the snapshot count, and only when the count is
  non-zero.

- `~/.cache` 不再被当成一堆无差别的垃圾。此前的通配规则把它下面的每个目录都标成
  「随时可删」并默认勾选——在开发者的 Mac 上，这意味着 `~/.cache/huggingface` 跟一张
  哈希表被一视同仁。真正是缓存的那些——pip、uv、go-build、pre-commit——现在逐个列名并
  保持默认勾选；兜底的通配规则会列出来供你确认，但绝不替你勾上。Playwright 和 Puppeteer
  下载的浏览器无论落在哪个目录，都只列出不勾选，与 `~/Library/Caches/ms-playwright`
  早就有的待遇一致。
- `~/.cache` 下的模型下载和工作环境完全不再出现。规则是在顶层匹配的，所以原有的权重
  启发式——它们在**被匹配的那个路径**里找 `/models/`、`.gguf` 之类——根本看不到
  `~/.cache/huggingface` 内部；这些仓库现在按名字列出。Poetry 是更微妙的一例：删除拿走
  的是整个被匹配的目录，所以只要 `~/.cache/pypoetry` 被列出来，`virtualenvs` 就会跟着
  一起走。现在该目录本身按精确匹配拒绝，而 `~/.cache/pypoetry/artifacts` 和
  `~/.cache/pypoetry/cache` 仍可单独回收。
- 新增测试断言：没有任何规则会被更早的规则遮蔽。写在通配规则之后的具体规则永远不会生效，
  它的分类、名称和安全等级会悄无声息地丢失——而上面两条修复恰恰依赖这件事不发生。
- 清理时会重新读取「此刻」哪些应用在运行，而不是沿用扫描当时的答案。先扫描、去用一会儿
  Chrome、回来再点清理，此前会依据几分钟前的旧答案把 Chrome 的缓存从它脚下删掉。被跳过
  的项会在结果里点名，并列出留在原处的字节数——一个说明了原因的偏小数字，好过一个悄无
  声息的错误数字。
- 空间地图会解释「为什么文件夹加起来对不上已用空间」——在确实有东西要解释的时候：
  Time Machine 本地快照占住了已删除或已改写文件的磁盘块，这些块不属于任何文件夹，而可用
  空间那个数字已经把它们算作可回收。会同时显示快照数量，且仅在数量不为零时出现。

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
