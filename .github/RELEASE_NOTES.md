MacPleco 0.3.3 — a monitor that can hold still, a space map that uses its space,
and exact paths before you remove a large file.

MacPleco 0.3.3 —— 监控数据可以动、位置可以不动；空间地图真正铺满空间；清理大文件前
先看清准确路径。

### Sortable process monitor · 可排序的进程监控

- Click the CPU, GPU or Memory column to choose the ranking metric.
- **Live order** continuously moves rows as usage changes; **Fixed positions**
  keeps existing processes in place while their values refresh, filling a row
  only when its process exits.
- CPU, memory, network and Mac information cards now share the same dimensions
  and information slots.
- macOS does not expose other processes' live GPU percentage through a public,
  unprivileged API. The GPU column therefore reports an honest “—” with an
  explanation instead of substituting CPU or energy data, using a private API,
  or asking for administrator access.

- 单击 CPU、GPU 或内存列即可选择排序指标。
- “实时排序”会随占用变化移动行；“固定位置”只刷新数值，原进程退出后才补入新进程。
- CPU、内存、网络和 Mac 信息卡片采用相同尺寸与信息槽位，不再高低不一。
- macOS 没有向普通 App 公开其他进程的实时 GPU 百分比，因此 GPU 列会明确显示“—”和
  原因，不用 CPU 或能耗冒充，也不调用私有接口、不索要管理员权限。

### A space map that fills its canvas · 真正铺满画布的空间地图

- Fixed the coordinate-origin bug that shifted the whole treemap right, leaving
  a blank left half and pushing tiles beyond the window edge.
- The map is now a stable full-width visualisation with adaptive, larger labels,
  percentages, folder/file legends and breadcrumbs.
- The largest 12 items appear in responsive cards below the map. Hovering a card
  and its tile refers to the same item, and every card includes its exact path
  and a Finder button.
- Small items are consolidated into one honest “Other items” tile instead of
  becoming a field of unreadable slivers.

- 修复了坐标原点错误：旧版会把整张矩阵树图向右二次居中，造成左侧大片空白、右侧越界。
- 地图改为稳定的全宽布局，提供更大的自适应字号、占比、文件夹/文件图例和面包屑导航。
- 地图下方新增响应式 Top 12 卡片；卡片和区块悬停联动，并显示准确路径与访达按钮。
- 小项目会合并成诚实的“其他项目”区块，不再挤成无法阅读、无法点击的碎片。

### Safer large-file review · 更安全的大文件确认

- Every large-file row now shows its absolute path directly under the name.
- An always-visible Finder button reveals and selects the exact file before any
  cleanup decision.
- Right-click adds **Show in Finder**, **Copy Full Path** and the reversible
  **Move to Trash** action.

- 每个大文件都会在名称下方显示绝对路径。
- 常驻的“访达”按钮会打开所在目录并选中准确文件，方便清理前核对。
- 右键菜单新增“在访达中显示”“复制完整路径”和可撤销的“移到废纸篓”。

### Real language switching · 真正的语言切换

The interleaved bilingual README has been replaced by a focused English
`README.md` and Simplified Chinese `README.zh-CN.md`, linked at the top of both
documents. A cumulative `CHANGELOG.md` is included in the repository.

原先逐段中英对照的 README 已拆成专注的英文 `README.md` 和简体中文
`README.zh-CN.md`，两份文档顶部均可一键切换；仓库同时新增累计更新日志
`CHANGELOG.md`。

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
