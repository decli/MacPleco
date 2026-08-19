MacPleco 0.3.4 — uninstall in batches, a monitor that reports the machine
instead of describing itself, and folder measurement three to seven times
faster.

MacPleco 0.3.4 —— 批量卸载、监控页只报数据不解释自己，文件夹体积测量快 3–7 倍。

### Batch uninstall · 批量卸载

- Tick several apps and remove them together. One review sheet lists every
  bundle and every leftover it found, and each line can still be declined
  individually before anything moves.
- Every app row carries a visible **Uninstall** button, and every Tune-Up
  repair a visible **Run** button, instead of revealing them on hover.
- Login items can be sorted by name, by scope or by what actually runs at
  login, and searched.

- 勾选多个应用即可一起卸载。清单里逐条列出每个本体与每一处残留，动手之前仍可逐项取消。
- 应用行常驻“卸载”按钮，优化项常驻“执行”按钮，不再需要悬停才出现。
- 开机启动项支持按名称、范围或“开机即启动”排序，并支持搜索。

### Folder measurement, 3–7× faster · 文件夹测量快 3–7 倍

Sizes are now read with `getattrlistbulk` — a whole batch of directory entries
and their allocated sizes in one syscall — and the walk is shared across a
work-stealing pool, so the whole machine finishes the one enormous folder
instead of leaving it to a single thread. A 417 GB home folder drops from 17.9s
to 3.1s and `~/Library` from 17.8s to 2.5s, reporting the same byte totals as
before.

体积测量改用 `getattrlistbulk`：一次系统调用即可取回一批目录项及其占用大小；遍历
交给工作窃取线程池，整台机器一起完成最大的那个文件夹，而不是留给单线程。417 GB
的个人文件夹从 17.9 秒降到 3.1 秒，`~/Library` 从 17.8 秒降到 2.5 秒，字节总数与
此前完全一致。

### A monitor that reports · 只报数据的监控页

- Whole-device GPU utilisation, read from the IORegistry.
- The process table can be searched by name, path or pid, filtered to apps or
  system processes, sorted by name, memory, start time or CPU in either
  direction, revealed in Finder, and asked to quit — or forced to.
- CPU, memory, GPU and network each plot their components in distinct colours
  with a legend, rather than blending two or three quantities into one line.
- All four gauges now carry the same kind of subtitle — cores, installed
  memory, video memory in use, peak rate — instead of two of them explaining
  how their own chart was drawn.

- 新增整机 GPU 使用率，数据来自 IORegistry。
- 进程表支持按名称/路径/PID 搜索，区分应用与系统进程，按名称/内存/启动时间/CPU 正反序
  排序，在访达中定位，以及请求退出或强制结束。
- CPU、内存、GPU、网络各自用不同颜色绘制其组成部分并配图例，不再把两三个量混成一根线。
- 四张卡片的副标题统一为同类读数——核心数、内存容量、显存占用、峰值速率，不再有两张
  卡片在解释自己的曲线是怎么画的。

### Cards that line up, tiles that mean something · 对齐的卡片与有含义的色块

- A row of four stat cards no longer breaks as three with one stranded
  underneath, and no longer stops short of the right edge. The grid counts its
  cards rather than filling the container with as many columns as fit, so the
  cards either share one row or split evenly across two.
- Space map tiles are coloured by identity, not by size rank: the area of a
  tile already says how big it is. Ten muted folder hues say which folder it
  is, loose files keep one warm tone of their own so “one huge file” never
  looks like “a folder of many things”, and the grouped tail stays neutral
  grey.
- The map no longer keeps a tile lit, and reading it out in the header, after
  the pointer has left the map or moved into another folder.

- 四张指标卡片不再出现“上排三张、下面孤零零一张”的换行，也不再在右侧留出一整列空白：
  网格按卡片数量分列，因此四张卡片要么同处一行，要么均分两行。
- 空间地图的色彩表示“是哪一项”，不再表示大小——面积已经说明了大小。十种低饱和文件夹色
  负责区分身份，散落的文件保留自己的暖色，“一个超大文件”不会看起来像“一个装满东西的
  文件夹”，合并的其他项保持中性灰。
- 指针移出地图或进入下一层文件夹后，地图不再保留高亮，标题栏也不再继续读出一个指针
  并未指向的项目。

### Install · 安装

Drag MacPleco into Applications. On first launch, use System Settings →
Privacy & Security → Open Anyway if macOS asks, then grant Full Disk Access for
cache measurement. Requires macOS 15 or later; native Liquid Glass renders on
macOS 26.

把 MacPleco 拖入“应用程序”。首次启动如遇提示，请前往“系统设置 → 隐私与安全性”
选择“仍要打开”，然后授予完全磁盘访问权限以测量缓存。需要 macOS 15 或更高版本；
原生液态玻璃效果在 macOS 26 上呈现。

---

Feedback → https://github.com/decli/MacPleco/issues · Inspired by
[Mole](https://github.com/tw93/Mole) · GPL-3.0
