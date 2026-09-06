MacPleco 0.3.6 — one heading, one type scale, one place a page's control
goes. Plus three cleaning fixes, one of which was found by taking the same
problem apart twice.

MacPleco 0.3.6 —— 统一的页面标题、统一的字号阶梯、页面级控件只有一个位置。另有三处
清理逻辑的修复，其中一处是同一个问题被拆解了两遍才发现的。

### A heading the app actually controls · 应用自己说了算的标题

Every page opened with the system's `navigationTitle` and `navigationSubtitle`,
drawn by AppKit in the title bar at roughly 14pt and 10.5pt. The page's own
name was rendering smaller than half the labels in the content below it, and no
styling could reach it. It also sat outside the content column, which meant a
page's control had to be pinned to the right edge of the *window* rather than
to the content it acts on — drifting further away the wider the window got.

The heading is now a real element in the content, on the content's own left
edge: 20pt for the name, 13pt for the sentence saying what the page does.
Measured at the minimum window width in both languages, all six pages put the
title at x=284 and the subtitle at x=284, and every page-scoped control ends at
the same x=931.

此前每个页面用的都是系统的 `navigationTitle` 与 `navigationSubtitle`，由 AppKit 以
约 14pt 和 10.5pt 绘制在标题栏里。页面自己的名字比下方一半的标签还要小，而且样式
完全够不着。它还位于内容列之外，于是页面控件只能钉在**窗口**右边缘，而不是它所作用
的内容的右边缘——窗口越宽，两者离得越远。

现在标题是内容区里真正的元素，与内容同一条左边线：名称 20pt，说明这一页做什么的句子
13pt。在最小窗口宽度下实测，中英文六个页面的标题与副标题都从 x=284 开始，每个页面级
控件都终止于同一个 x=931。

### One type scale, eleven steps · 十一级字号阶梯

The app used 27 distinct point sizes, eight of them packed between 9 and
13.5pt — a range where half a point reads as sloppiness rather than hierarchy.
One row of `SelectionBar` set four adjacent labels at 12, 11.5, 12.5 and 11pt.

Every size now comes from an eleven-step ramp whose roles fix size, weight and
typeface together, and no raw font-size literal remains anywhere in the source.
The ordering claim it makes: a page title (20pt) sits *below* a stat card's
value (24pt), because the sidebar already says which page you are on and the
number is what you came for.

此前全应用使用 27 种字号，其中 8 种挤在 9 到 13.5pt 之间——在这个区间里，半个点读
不出层级，只读得出随意。`SelectionBar` 一行里就用了 12、11.5、12.5、11pt 四种。

现在所有字号都来自一套十一级阶梯，每个角色同时固定字号、字重与字形，源码中不再有任何
字号字面量。它给出的层级判断是：页面标题（20pt）**低于**指标卡片的数值（24pt）——侧栏
已经告诉你在哪一页，而你来看的是那个数字。

### One place a page's control goes · 页面控件只有一个位置

The mode switch was a toolbar item on Apps and Space, "Rescan" was a toolbar
item on Clean, and Space's identical "Look again" was a quiet button buried in
a card halfway down the content. Three cards — on Tune-Up, on Apps' login items
and on Space's large files — each re-explained their own page one line below
the subtitle that had just said the same thing.

All four controls now sit in the heading's trailing slot. The three cards are
one line of guidance under the heading, at one size, with one hanging indent.
Space's "click a tile to open it" hint moved with them, from the bottom of the
page to above the map it describes.

模式切换此前在「应用」和「空间」的工具栏里，「重新扫描」在「清理」的工具栏里，而
「空间」里作用完全相同的「重新查找」却是内容中段某张卡片里一个不起眼的按钮。另有三张
卡片——「优化」、「应用」的开机项、「空间」的大文件——各自在副标题下方一行的位置，把
副标题刚说过的话再说一遍。

四个控件现在都在标题栏右侧插槽中。三张卡片合并为标题下方的一行说明，同一字号、同一悬挂
缩进。「空间」的「单击进入文件夹」提示也随之从页面底部移到了它所描述的地图上方。

### `~/.cache` is not one pile of junk · `~/.cache` 不是一堆无差别的垃圾

A catch-all rule labelled every directory under `~/.cache` "Safe to remove" and
ticked it. On a developer's Mac that meant offering `~/.cache/huggingface`
alongside a hash table. The existing model-weight guards look for `/models/`,
`.gguf` and friends *in the matched path*, and a rule is matched at its top
level, so they never saw inside the store.

The directories that really are caches — pip, uv, go-build, pre-commit — are
named individually and stay pre-selected. Model stores are named and never
offered. Poetry is the subtler case: removal takes the whole matched directory,
so offering `~/.cache/pypoetry` at all would have taken `virtualenvs` with it;
the directory is now refused as an exact match while `~/.cache/pypoetry/
artifacts` and `~/.cache/pypoetry/cache` stay reclaimable on their own. Browser
downloads are review-only wherever they landed. A test now asserts that no
catalog rule can be shadowed by an earlier one, which is what all of the above
depends on.

此前的通配规则把 `~/.cache` 下的每个目录都标成「随时可删」并默认勾选。在开发者的 Mac
上，这意味着 `~/.cache/huggingface` 和一张哈希表被一视同仁。原有的模型权重防护是在
**被匹配的那个路径**里找 `/models/`、`.gguf` 之类，而规则是在顶层匹配的，所以它们根本
看不到仓库内部。

真正是缓存的目录——pip、uv、go-build、pre-commit——逐个列名并保持默认勾选。模型仓库
按名字列出，完全不再出现。Poetry 是更微妙的一例：删除拿走的是整个被匹配的目录，只要
`~/.cache/pypoetry` 被列出来，`virtualenvs` 就会跟着一起走；现在该目录按精确匹配拒绝，
而 `~/.cache/pypoetry/artifacts` 和 `~/.cache/pypoetry/cache` 仍可单独回收。下载的
浏览器无论落在哪个目录都只列出不勾选。新增测试断言：没有任何规则会被更早的规则遮蔽——
上面每一条都依赖这件事。

### Checked when you press the button · 按下按钮那一刻才检查

Whether an app was running was decided during the scan, and a scan can be
minutes old. Scanning, going off to use Chrome and coming back would clear
Chrome's cache out from under it on an answer that had already expired.

The running-app list is now re-read at the moment of the click. Anything
skipped that way is named in the result with the bytes it left behind: a low
number that says why beats a number that is quietly wrong.

「某个应用是否在运行」此前是扫描时决定的，而一次扫描可能是几分钟前的。先扫描、去用一会儿
Chrome、回来再点清理，就会依据一个已经过期的答案，把 Chrome 的缓存从它脚下清掉。

现在会在点击的那一刻重新读取运行中的应用列表。被跳过的项会在结果里点名，并列出留在原处
的字节数：一个说明了原因的偏小数字，好过一个悄无声息的错误数字。

### Why the folders never add up · 为什么文件夹永远加不齐

The Space map now explains the gap between the folder totals and the used
space, when there is one: Time Machine local snapshots pin the disk blocks of
files you have since deleted or rewritten, those blocks belong to no folder any
more, and the free-space figure already counts them as reclaimable. Shown with
the snapshot count, and only when it is non-zero.

空间地图现在会解释文件夹统计与已用空间之间的差额——在确实存在差额的时候：Time Machine
本地快照占住了已删除或已改写文件的磁盘块，这些块不再属于任何文件夹，而可用空间那个数字
已经把它们算作可回收。会同时显示快照数量，且仅在数量不为零时出现。

### Known · 已知

The six screenshots in the README still show 0.3.5's chrome, with the title in
the title bar. They will be retaken.

README 里的六张截图仍是 0.3.5 的界面，标题还在标题栏里。稍后会重新拍摄。

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
