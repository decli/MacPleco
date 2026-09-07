MacPleco 0.4.0 — the interface rebuilt on a written standard. Four control
heights instead of a dozen, one baseline shared by the sidebar and the page,
and a destructive button that is no longer the loudest thing on the screen.

MacPleco 0.4.0 —— 界面按一份成文的标准重建。控件高度收成四档，侧栏与页面共享同一条
基线，破坏性按钮不再是屏幕上最显眼的那个。

### Three things that looked wrong, and what was under them · 三个看着不对的地方

The report was specific: the app name and the page title were not on the same
line; the search field, the sort menu and the toggle beside them were three
different sizes; and "Uninstall selected" was bigger than everything around it.
Measured, all three were symptoms of one cause — nothing in the code said which
elements were neighbours, so each one picked its own size.

反馈很具体：应用名和页面标题不在一条线上；搜索框、排序下拉、开关三个控件大小不一；
「卸载所选」比周围一切都大。量下来，三者是同一个原因的三种症状——代码里没有任何东西
规定哪些元素是邻居，于是每个元素各自决定自己的尺寸。

### Containers impose size · 尺寸由容器施加

`SearchField` was already the app's single search control, and it still stood
7pt taller than the popup menu beside it, because a shared implementation does
not make two controls neighbours. `FilterRow` now sets the height, the type
size and the system control size for its whole row, and the controls inside it
take no size parameter at all. Measured: the filter row is 28pt and so is every
control on it, at one type size, on all three pages that have one.

`SearchField` 本来就是全 App 唯一的搜索实现，它照样比邻座的下拉高 7pt——共用一份实现
并不能让两个控件成为邻居。现在 `FilterRow` 为整行统一高度、字号与系统控件尺寸，行内
控件根本不接受尺寸参数。实测：三个有筛选行的页面，行高 28，行内每个控件也是 28，
字号统一。

### 28, not 24 · 默认档是 28

Control heights are 24 for a row's own action, **28 as the default**, 36 for a
card's main action, and 44 for the one thing a page wants you to do. 28 rather
than 24 because a Han glyph has no ascender or descender and fills the whole em
box: 13pt Chinese in a 24pt capsule leaves 5.5pt of air and reads as if it is
touching the edges, where the same capsule looks roomy around Latin text.
Copying Latin control heights is the most common way a Chinese interface ends
up feeling cramped.

控件高度：行内动作 24、**默认 28**、卡内主动作 36、每页唯一的号召动作 44。默认档是
28 而不是 24，因为中文字身没有升降部、占满整个字高：13pt 中文在 24 高胶囊里上下只剩
5.5pt，看着顶边，而同样的胶囊配拉丁文字反而宽松。照抄拉丁界面的控件高度，是中文
App 最常见的一类别扭。

### One baseline, not two boxes · 对齐基线，而不是两个框

The sidebar and the content column now draw one 28pt band starting 12pt below
the title bar, and every piece of text in either column sits on one baseline.
Aligning the frames' centres is not enough across two type sizes in Chinese —
the boxes line up and the characters still do not. Measured, the wordmark and
the page title both land at y=85 on all six pages, and the brand mark now
shares the destinations' left edge at x=24.

侧栏与内容列现在共用一条从标题栏下缘起 12pt、高 28pt 的带子，两列里所有文字落在同一条
基线上。中英混排下把两个不同字号的文字框居中对齐是不够的——框齐了字仍然不齐。实测六个
页面的字标与页面标题都在 y=85，品牌图标也回到了与导航项相同的左边线 x=24。

Tabs left that band for the content above the list they switch. Navigation is
not a page-scoped control, and keeping it in the header slot is why the slot had
to hold both a 24pt segmented control and a 32pt button — and why the note under
it was 14pt tall on one page and 32pt on another.

页签从报头带下沉到它所切换的列表上方。导航不是页面级控件，把它留在插槽里正是插槽既要
装 24 高的分段控件、又要装 32 高的按钮的原因，也是下面那行说明在一个页面 14 高、在另一个
页面 32 高的原因。

### The destructive button is no longer the loudest · 破坏性按钮不再最响

The README opens by promising that the destructive button is not the loudest
thing on the screen. The code did the opposite. A call site now declares an
`ActionIntent` and **cannot choose a colour**: `go` is the only filled intent,
`destructive` is always outlined, and a filled danger button exists only inside
a sheet that has opted in as a confirmation surface. This is a property of the
type, not a convention to remember.

README 第一段承诺「破坏性按钮不是最显眼的那个」，代码做的正相反。现在调用方声明
`ActionIntent`，**选不了颜色**：只有 `go` 能实心，`destructive` 一律描边，实心的
危险按钮只存在于明确标记为确认界面的 Sheet 里。这是类型的性质，不是需要记住的约定。

"Uninstall selected" is an outlined proposal that opens a list of everything it
would remove. Turning on "Skip the Trash" no longer just changes what the same
click does: the button renames itself to Erase, drops a tier, becomes an
outlined destructive action, and routes through a confirmation instead of acting
in place. Moving a file to the Trash is no longer painted red at all — colouring
a recoverable action red teaches people to ignore red, and then there is no word
left for the operations that really cannot be undone.

「卸载所选」是一个描边的提议，点开会先列出它将删除的全部内容。打开「跳过废纸篓」不再
只是悄悄改变同一次点击的后果：按钮改名为「永久删除」、降一档、变成描边的破坏性动作，
并且改为先弹确认而不是就地执行。「移到废纸篓」则完全不再染红——把可还原的动作染成红色，
等于教用户忽略红色，真正不可逆的地方就没有词可用了。

### A contrast bug in the app's loudest button · 最响那颗按钮的对比度

Found while measuring, and it predates this release. White text on the aqua
sweep measures **2.62:1** in light appearance and **1.40:1** in dark. "Start
cleaning" — the button the whole interface is arranged around — was less
readable than the pink Uninstall button this work set out to fix (1.39:1).
Gradients cannot carry text.

这是量的时候发现的，而且早于本次发布。白字压青色渐变，浅色实测 **2.62:1**，深色
**1.40:1**。「开始清理」——整个界面围着转的那颗按钮——比这次工作要修的那颗粉红按钮
（1.39:1）还难读。渐变承载不了文字。

Filled controls now use a fill that goes deep in light appearance and stays
bright in dark, paired with a foreground that flips with it: white on the dark
fills, near-black on the bright ones. Measured 4.64:1 and 5.68:1. The sweep
stays where it belongs — the depth ring, the capacity bars and the treemap,
none of which carry text. Clickable glass also gained a legibility floor, so
the Overview's secondary button has a visible edge on the pale ground for the
first time.

实心控件改用一个浅色走深、深色保持亮的填充，配一个跟着外观翻转的前景色：深底配白字，
亮底配近黑。实测 4.64:1 与 5.68:1。渐变回到它该待的地方——不承载文字的水位环、容量条
和树图。可点的玻璃也有了可辨度下限，「看看有哪些」在浅色地上第一次有了看得见的边界。

### The standard ships with the app · 标准随应用一起发布

`docs/ui-standard.md` is the rulebook — tokens, the action grammar, the
per-page checklist, and the acceptance numbers — and it states what the code
actually does rather than what was proposed. All 21 acceptance numbers measure
correct, verified with a layout probe compiled into the module and run at
1200×800 in Chinese, and `scripts/check-ui-standard.sh` runs first in CI so
none of it drifts back.

`docs/ui-standard.md` 是规则正文——令牌、动作语法、逐页清单和验收数字，而且写的是代码
实际的做法，不是当初的提案。21 项验收数字全部量到，用的是编进模块的布局探针，1200×800
中文窗口。`scripts/check-ui-standard.sh` 在 CI 第一步拦截回流。

### Also · 其他

- One badge component replaces nine implementations that used three point
  sizes, four vertical insets, three weights, two fills and two shapes.
- Four row geometries replace eight ad-hoc heights, and a row title starts at
  the same left edge on every list — including lists with no selection, which
  reserve the checkbox column so titles do not shift when you switch tabs.
- Six motion durations replace thirteen, several of which differed by a
  hundredth of a second.
- Readings set the unit apart from the quantity, and only where the tail is
  actually a unit: "M5 Max" and "5 小时 3 分" stay whole, with tests to keep
  them that way.

- 一个徽章组件取代九种写法——此前用了三种字号、四种内边距、三种字重、两种填充、两种形状。
- 四种行几何取代八种随手定的行高；行标题在每个列表都从同一条左边线开始，包括没有勾选的
  列表——它们补一个占位列，这样切换页签时标题不会横跳。
- 六档动效时长取代十三种，其中若干只差百分之一秒。
- 数值与单位分开排，且只在结尾确实是单位时才拆：「M5 Max」和「5 小时 3 分」保持完整，
  有测试保证。

---

**Requires macOS 15 or later.** Unsigned build: after moving MacPleco to
Applications, right-click the app and choose Open the first time, or run
`xattr -dr com.apple.quarantine /Applications/MacPleco.app`.

**需要 macOS 15 或更高版本。** 本构建未使用开发者证书签名：把 MacPleco 拖进「应用程序」
后，首次打开请右键选择「打开」，或执行
`xattr -dr com.apple.quarantine /Applications/MacPleco.app`。
