# MacPleco 界面标准（UI Standard）

> 版本 2.0 · 2026-09-08 · 取代 v1.0，**并已全部实施**。
> v1.0 做了扎实的全量盘点与实测，本版保留它的骨架与大部分数值，修正 3 处方向性判断，补充 4 块它没覆盖的内容。
> 依据：`Design/Theme.swift`、`Design/Components.swift`、`Design/Glass.swift`、README 的产品原则，以及 v1.0 的实测数据（引用为现状证据）。
>
> **实施状态：** §9 的 21 项验收数字已全部量到（见 §11）；§10 的三个未决问题已定；实施中发现并修复了本标准自己的一处对比度错误（§11.2）。
> 规则由 `scripts/check-ui-standard.sh` 在 CI 里拦截。

---

## 0. 怎么用这份文档

- **每个页面都从骨架继承**（§5）：报头行 → 副标题 → 说明行 → 页签 → 内容块。顺序、缩进、间距不由页面决定。
- **需要一个控件时先查档位表**（§3.3）：只允许 24 / 28 / 36 / 44 四种高度，**28 是默认档**。
- **需要一段文字时先查角色表**（§3.5）：页面代码不允许自己拼字号、字重、字体设计。
- **需要一个动作时先查意图表**（§4）：调用方声明"这个动作意味着什么"，形态与颜色由意图推导，**不选颜色**。
- **需要一块颜色时先查语义表**（§3.4）。
- 页面里出现了表里没有的东西，先在 `Design/` 里加组件或角色，再在页面里使用。**页面不产生新样式。**

---

## 1. 对 v1.0 的审阅

### 1.1 保留

| 项 | 说明 |
|---|---|
| "一行一档"原则 | 同一行的控件必须同档 |
| 报头行（Masthead） | 侧栏与内容列共享一条带子 |
| `Badge` 收成一个组件 | 吞掉现有九种写法 |
| 动效时长收成五档 | 取代现有 13 种 |
| 行高与圆角数值 | 56 / 40 / 48 / 64 · 16 / 12 / 22 |
| `CapacityBar` 只留两种高度 | 4 与 6 |
| CI grep 拦截 + 验收数字表 | "可量才算改完" |
| 全量盘点与问题清单 P1–P14 | 作为现状证据引用 |

### 1.2 修正三处

| # | 议题 | v1.0 | 本标准 | 为什么 |
|---|---|---|---|---|
| M1 | 对齐基准 | 文字框中心 y 相等 | **共享基线** + 品牌字标降级 | 中英混排下，把两个不同字号的文字框垂直居中，框齐了字仍不齐——中文字身满格、拉丁有升降部，光学重心不在框中心 |
| M2 | 默认控件高度 | 24（三档 24/32/44 中没有默认档） | **28**（四档 24/28/36/44） | 13pt 中文在 24 高胶囊里上下只剩 5.5pt，中文字身满格会顶边；28 = macOS 26 `.controlSize(.large)`，系统控件能直接对上。另：44 是 iOS 触控尺寸，不是 macOS 控件档 |
| M3 | 破坏性动作 | 降到 32 高，**仍允许** `PrimaryButtonStyle(tint: .danger)` 实心 | **禁止实心**；实心 danger 只在确认界面 | README 第一段承诺"破坏性按钮不是最显眼的那个"，代码却让它成为最显眼的那个。另：白字压 `danger` 12% 玻璃 tint 只有约 2.6:1，不到 4.5:1 |

### 1.3 补充四块

| # | 内容 | 为什么 v1.0 需要它 |
|---|---|---|
| A1 | **数字排版规范**（§6.6） | 这是一个量东西的 App，数字就是内容。v1.0 补了 `*Numeric` 角色，但没定单位、精度、对齐、列宽 |
| A2 | **玻璃控件最小可辨度**（§4.4） | 浅色"深水"地上，`.ultraThinMaterial` + 0.5pt hairline 几乎没有边界。截图里"看看有哪些"的边缘基本消失 |
| A3 | **可逆性的视觉语法**（§4） | 把 README 的"Reversible by default"变成可执行规则，而不是只写在 README 里 |
| A4 | **中英混排规则**（§3.6） | 中文字身满格，行高、字重上限、内边距下限都不能照抄拉丁 |

### 1.4 顺手修掉的第四个问题

用户反馈了三条，盘点中还有一条同类：**页签**（"已安装 / 开机启动"）是**导航**，不是页面级控件。v1.0 把它留在报头插槽里，于是插槽要同时容纳 24 高的分段与 32 高的幽灵按钮，高度只能随内容变（它自己的 P10）。

本标准：**报头插槽只放一个控件，且永不放导航**；页签下沉到内容列左边线，作为内容的一部分——它切换的是下面那张列表，就该长在列表上面。插槽因此恒为 28 高，说明行不再忽高忽低。

---

## 2. 原则

1. **容器定尺寸，页面不定。** 一致性不来自令牌，来自容器。`SearchField` 已经是全 App 唯一实现，它照样比邻居高 7pt——因为没有东西规定它跟谁并排。筛选行、选择条、行卡、报头都是容器，高度与字号由容器**施加**给子项；子项不接受尺寸参数。
2. **一行一档，一行一字号。** 同一条水平线上的控件必须同高、同字号。
3. **基线优先于框。** 两段不同字号的文字要看起来在一条线上，对齐的是基线，不是框中心。
4. **响度对应后果。** 越不可逆的动作，视觉越安静。最响的实心色块留给"让用户变好的那件事"，不给"拿走东西的那件事"。
5. **数字是内容。** 数字排版是正文排版：等宽数位、数值与单位分离、列右对齐、精度分档。
6. **可以量。** 每条规则都有数字，改完用探针量，量不到就不算改完。

---

## 3. 令牌

### 3.1 间距 `Space`

保留八级：`2 / 4 / 8 / 12 / 16 / 24 / 32 / 48`。

- **禁止算术**：`Space.sm + 2`、`Space.lg + Space.xs`（现有 6 处）。
- 固定用途：块间距 16 · 列表行距 8 · 栅格列距 12 · 卡内元素 8 / 12 · 内容列四周 32。

### 3.2 圆角 `Radius`

| 令牌 | 值 | 用途 |
|---|---|---|
| `pill` | 999 | 按钮、搜索框、徽章 |
| `panel` | 22 | 页面级大卡：英雄卡、摘要卡、地图卡、类别卡 |
| `card` | 16 | 统计卡、**所有行卡**（应用、登录项、大文件、前 12、**任务卡改 16**）、横幅 |
| `row` | 12 | 条形容器：选择条、面包屑栏、侧栏底栏、菜单栏面板内的井 |
| `chip` | 8 | 图标盒 28 / 32、行内悬停底、小井、**树图瓦片（7 → 8）** |
| `control` ✚ | 4 | 复选框、图例方块、核心条 |

同心律：子圆角 = 父圆角 − 父内边距（22 内 12 → 8）。**删除源码中所有圆角字面量**（现有 9 / 7 / 6 / 5 / 2 / 1.5 / 1）。

### 3.3 控件档位 `Control` ✚

四档，一个主力。

| 档 | 高 | 文字 | 左右内边距 | 图标 | 用途 |
|---|---|---|---|---|---|
| `compact` | 24 | `label` 12 medium | 12 | `Glyph.control` 12 | 行内动作、图标按钮命中区、紧凑表格行内的一切 |
| **`standard`** | **28** | `body` 13 | 14 | `Glyph.control` 13 | **筛选行、报头插槽、页签、选择条动作、Sheet 页脚。90% 的控件是这一档** |
| `emphasis` | 36 | `subhead` 15 semibold | 20 | `Glyph.row` 15 | 卡内主动作：权限卡、完成卡、菜单栏面板 |
| `hero` | 44 | `subhead` 15 semibold | 24 | `Glyph.row` 15 | 每页最多一**组**：概览英雄卡、清理摘要卡。**永不用于破坏性动作** |

规则：

- 同一组按钮必须同档（概览两颗都是 `hero`，Sheet 页脚两颗都是 `standard`）。
- 一个页面最多一组 `hero`，最多一个实心色块。
- 系统 `.bordered.mini`（16 高）**停用**。
- 系统控件通过 `controlSize` 对齐：`.large` = 28，`.small` = 24；开关本体 18（`.small`）居中于 28。
- 禁用：整体 **0.4** 不透明度，不改颜色，**永不隐藏**（现有 0.5 / 0.45 / 0.4 三种）。
- 按下：全部 **0.8**（macOS 15 回退分支加 0.975 缩放）。
- 忙碌：小菊花替换前置图标，文案换成进度，**尺寸不变**。

#### 为什么 24 不能当默认档

中文字身没有升降部，占满整个字高。13pt 中文在 24 高胶囊里上下各剩 5.5pt，视觉上顶边；同样的胶囊放拉丁文字反而宽松。**照抄拉丁界面的控件高度，是中文 App 最常见的一类别扭。** 控件内垂直余量的下限是 7pt，所以 13pt 文字的控件最低 28 高。

### 3.4 语义色 `Palette`

色值不动（"深水"调色板已经很好），改的是**谁能用哪种颜色**。

| 颜色 | 意义 | 允许出现的地方 |
|---|---|---|
| `ink` | 主文字 | 标题、行标题、数值。**✚ 也是可逆删除动作的颜色**（移到废纸篓） |
| `inkSecondary` 62% | 支持句 | 副标题、说明句、说明行、**品牌字标** |
| `inkTertiary` 42% | 标签与元数据 | `SectionLabel`、统计卡标签、时间、版本、**单位**、弱文字按钮 |
| `inkFaint` 26% | 存在即可 | 路径、PID、占位、未选中描边 |
| `aqua` | 品牌 + 安全 + 选中 + 正向 | `Primary` 唯一允许的实心填充色；`safe` 芯片；选中态；进度默认色 |
| `flow` | **可以点的文字**，仅此一种含义 | `Tertiary` 按钮、链接、面包屑、活动表头、行内"访达"图标 |
| `caution` | 需要看一眼 | `review` 芯片；"开机即启动"；半年未用；温度异常；磁盘 >90% |
| `danger` | **✚ 只给不可逆** | 卸载、永久删除、结束进程、`careful` 芯片。**列表中永不实心** |
| `positive` | 已完成的好结果 | 优化成功行、权限已授予、温度正常徽章 |
| `chart*` / `folderTones` / `fileTone` / `tailTone` | 只在图表与图例里 | 监控、空间 |

**✚ 按钮文字禁止用 `inkSecondary` 及以下。** 截图里"看看有哪些"的文字偏淡，是这条缺失的直接结果。

填充不透明度只有五档：**井 5%（`wellFill`）· 悬停 6% · 选中 8% · 徽章与图标盒 14% · 卡片 tint 12%（仅 `GlassCard`）**。

### 3.5 文字角色 `Typo`

11 级不变。改三件事：**(a)** `Typo.Step` 收回 `Design/` 内部，页面不能再自行拼字重（现有 108 处、40 种组合）；**(b)** 补齐 4 个 `*Numeric` 角色；**(c)** 每个场景指定唯一角色。

| 角色 | 字号 / 字重 / 设计 | 唯一用途 |
|---|---|---|
| `hero` | 44 bold rounded | 清理摘要数字、水位环读数。**一页最多一个** |
| `feature` | 30 bold rounded | 概览标题句 |
| `metric` | 24 bold rounded | 统计卡值、完成卡"释放了 …"。**比页面标题大，故意的** |
| `pageTitle` | 20 bold rounded | 页面标题，仅 `Masthead` |
| `cardTitle` | 17 semibold rounded | Sheet 标题、空态标题 |
| `subhead` | 15 semibold | 分组行标题（类别名）、`emphasis` / `hero` 档按钮、**✚ 品牌字标（配 `inkSecondary`）** |
| `subheadNumeric` ✚ | 15 semibold rounded · 等宽数字 | 类别选中大小、大文件大小、侧栏与菜单栏的可用空间 |
| `subheadPlain` | 15 regular | 侧栏导航项（medium 例外，系统绘制） |
| `body` | 13 regular | 页面副标题、卡内说明句、**✚ 所有 `standard` 档控件文字（含开关标签）** |
| `bodyStrong` | 13 semibold | 标准行标题：应用名、任务名、大文件名、前 12 名、横幅标题 |
| `bodyNumeric` ✚ | 13 semibold rounded · 等宽数字 | 选择条计数与合计、Sheet 页脚合计 |
| `label` | 12 medium | `compact` 档按钮、文字按钮、紧凑行标题（进程名、登录项名）、统计卡标签、面包屑 |
| `labelPlain` | 12 regular | 行内次要正文、空态正文 |
| `labelNumeric` | 12 semibold rounded · 等宽数字 | 行内大小、"当前 xx" |
| `caption` | 11 regular | 元数据、说明行、状态、脚注、时间、**单位** |
| `captionStrong` | 11 medium | 井里的标签（"可用空间"） |
| `captionNumeric` ✚ | 11 regular rounded · 等宽数字 | 进程内存 / CPU / 时长、份额百分比、图例读数 |
| `overline` | 10 semibold（大写时加 0.6 字距） | `SectionLabel`、表头、徽章文字、图例标签 |
| `tag` ✚ | 9 semibold | 紧凑徽章（进程"系统"）、结果行、警告行 |
| `micro` | 9 regular | 排序箭头、坐标轴 |
| `microMono` | 9 monospaced | 路径、PID |

规则：

- 数字一律用 `*Numeric` 角色 + `.monospacedDigit()`；会变的数字加 `.contentTransition(.numericText())`。
- 强调只能升一级字重，不能换字号。
- 页面文件中不得出现 `.font(.system(size:`（CI 拦截）。

### 3.6 中英混排规则 ✚

- **行高**：中文正文 **1.7**，拉丁 1.5；单行控件文字 `line-height: 1`，由容器垂直居中。
- **字重上限**：中文最重到 **semibold**；`bold` 只给 rounded 数字与页面标题（`PingFang` 的 bold 在小字号下糊成一团）。
- 禁止中文用 `light` / `thin`；禁止中文加 `letter-spacing`；tracking 只给全大写拉丁 `overline`。
- **控件内垂直余量 ≥ 7pt** ⇒ 13pt 文字的控件最低 28 高。
- 所有 `frame(width:)` 的文字列**按中文量**（中文比英文宽约 15%）。

### 3.7 字形与图标盒 `Glyph` ✚

| 名 | 值 | 用途 |
|---|---|---|
| `badge` | 9 | 徽章内、排序箭头、结果行 |
| `caption` | 11 | 说明行、统计卡头、图标按钮 |
| `control` | 13 | `standard` 档按钮内、搜索 |
| `row` | 15 | 行主图标、`emphasis` / `hero` 档按钮内 |
| `card` | 17 | 扫描卡、战绩条 |
| `title` | 20 | 权限卡、Sheet 头 |
| `feature` | 30 | 空态、不可读态 |

图标盒（有底色的方形）只有四种，尺寸与圆角**成对，不可拆开**：

| 名 | 尺寸 / 圆角 | 归属 |
|---|---|---|
| `small` | 24 / 6 | 菜单栏品牌 |
| `masthead` ✚ | 28 / 8 | 报头品牌（= 报头带高） |
| `medium` | 32 / 8 | 类别、占用横幅、行内应用图标 |
| `large` | 44 / 12 | Sheet 头部 |

现状是 44 / 34 / 32 / 30 / 22 配圆角 12 / 9 / 8 / 8 / 6——五种尺寸五种圆角，没有对应关系。收成四种后，**圆角 ≈ 盒宽 ÷ 3.6**，新增尺寸时不用再猜。

### 3.8 动效 `Motion`

| 名 | 曲线 · 时长 | 用途 |
|---|---|---|
| `press` | snappy 0.16 | 按下 |
| `hover` | smooth 0.20 | 悬停底、图标显隐 |
| `state` | smooth 0.25 | 选中、展开、数值变化 |
| `reveal` | smooth 0.30 | 结果行、横幅出现、页面切换 |
| `settle` | smooth 0.50 | 图表与进度条随数据变化 |
| `enter` | smooth 0.55 · 阶梯 0.06 | 页面入场 |

`accessibilityReduceMotion` 时：入场无位移、图表无动画、遮罩与水位环静止（已实现，保持）。

---

## 4. 破坏性与可逆性的视觉语法 ✚

这是 v1.0 完全没有的一节，也是本标准最重要的一节。README 第一段承诺了"破坏性按钮不是最显眼的那个"，但 `PrimaryButtonStyle(tint: .danger)` 让它成为了最显眼的那个。规则要能兑现承诺。

### 4.1 两条硬规则

**规则一 · 实心只给"可逆的好事"。** 实心填充是页面上最响的东西，只用于让用户变好、且做错了能撤回的动作——"开始清理"（东西进废纸篓）、"移到废纸篓"（可还原）。**列表与工具条里的破坏性动作永远是描边**：`danger` 描边 1pt + `danger` 文字 + `danger` 6% 底。

**规则二 · 实心 `danger` 只活在确认里。** 唯一允许实心 `danger` 的地方是确认 Sheet / Alert 的确认键——此时用户已明确表达意图，并且那个界面里没有别的实心块与它竞争。**一个界面最多一个实心色块。**

### 4.2 四种形态

| 意图 | 形态 | 档位 | 例 | 对比度 |
|---|---|---|---|---|
| **可逆 · 好事** | 实心 `goFill`，配 `onAccent` | `hero` 44 | 开始清理、清理页"移到废纸篓" | 4.64:1 浅 / 5.68:1 深 ✓ |
| **可逆 · 中性** | 描边 `ink` | `standard` 28 / `compact` 24 | 大文件"移到废纸篓"、条目行 | ink / 浅底 ✓ |
| **不可逆 · 提议** | 描边 `danger` + 6% 底 | `standard` 28 / `compact` 24 | 卸载、卸载所选、移除登录项 | danger / 浅底 = 5.1:1 ✓ |
| **不可逆 · 确认** | 实心 `dangerSolid`（浅 `#C0342F` / 深 `#8F2C28`），白字 | `standard` 28 | Sheet / Alert 确认键 | 5.57:1 浅 / 8.21:1 深 ✓ |

对照现状：白字压 `danger` 12% 玻璃 tint = 约 **2.6:1**，不达标。实心确认键必须用 `danger` 的**深值**，不是玻璃 tint——玻璃 tint 是那颗粉红按钮对比度不足的直接原因。

**关于「可逆 · 好事」这一行：本标准最初写的是「实心 `aquaSweep`，白字，白 / aqua = 4.9:1」，那是错的。**
用 `Theme.swift` 的实际色值算，白字压 `aquaSweep` 浅色 2.62:1、深色 1.40:1——比它要修的那颗粉红按钮
（1.39:1）好不了多少。渐变承载不了文字。上表已按代码实际实现修正，原委见 §11.2。

### 4.3 可逆的删除不该染红

现状里"移到废纸篓"用的是 `danger`。本标准改成中性 `ink` 描边。**把可还原的动作染成红色，等于教用户忽略红色**——真正不可逆的地方就没有词可用了。同理，它应该**常显**，不该藏在悬停里。

### 4.4 玻璃控件的最小可辨度 ✚

在浅色"深水"地上，`.ultraThinMaterial` + 0.5pt hairline 几乎看不出边界。

**任何可点的玻璃控件必须同时具备：足够不透明的填充底 · 描边 ≥ 16% · 文字不低于 `ink`。**

「足够不透明」在两种外观下是两个方向的要求：浅色地上要往白里加，深色地上要往亮里加。
代码实现（`Palette.controlFill` / `controlStroke`，由 `GlassLevel.interactive` 统一施加）：

| 外观 | 填充 | 描边 | 描边宽度 |
|---|---|---|---|
| 浅色 | 白 **72%**（下限 66%） | 黑 **20%**（下限 16%） | 1pt |
| 深色 | `#E8F2FA` **14%** | 白 **24%** | 1pt |

深色下不能照搬 66%：那会把控件刷成近白。规则的实质是「控件必须比它所在的地面更实，
且边界画得出来」，两个方向各取各的值。非交互面板仍用 0.5pt `hairlineStrong`。

- 非交互的玻璃面板可以更透（卡片 55%），可点的不行。
- 玻璃控件不得直接压在 aurora 色场最亮处；英雄卡内例外（卡本身已是一层玻璃）。
- macOS 15 回退分支与 26 的 `glassEffect` 都要满足这条——现状只有回退分支画了 hairline。

---

## 5. 布局

### 5.1 窗口

最小 980×660，默认 1200×800，标题栏 52，内容列最大 1140、左右各 32。不变。

### 5.2 报头行 `Masthead`

侧栏与内容列共享**同一条 28 高的带子**，从标题栏下缘起 12pt。**带内所有文字按基线对齐，基线落在带底 −7（= 标题栏下缘 +33）。**

| 列 | 内容 | 角色 | 位置（标题栏下缘 = 0） |
|---|---|---|---|
| 侧栏 | 图标盒 28（r8）+ "MacPleco" | `subhead` 15 semibold · `inkSecondary` | x 24 · 基线 +33 |
| 内容列 | 页面标题 | `pageTitle` 20 bold · `ink` | x 284 · 基线 +33 |
| 内容列右 | 插槽：**恰好一个控件，永不放导航** | `standard` 28 Secondary | y 12–40 · 恒 28 高 |
| 内容列 | 副标题 | `body` 13 · `inkSecondary` | 带下 8 → y 48 |
| 内容列 | 说明行 `PageNote`（可选） | `caption` 11 · 图标 11 | 副标题下 8 · **恒 16 高** |
| 内容列 | 页签（可选）✚ | `standard` 28 分段 | 左边线 284 · 上距 16 |
| 内容列 | 第一个内容块 | — | 标题组下 24 |

落到代码：`Page` 上边距 24 → **12**；标题与字标各自外包 `.frame(height: 28, alignment: .bottom)` 并用 `.alignmentGuide(.firstTextBaseline)` 锚定；侧栏品牌行左右内边距 20 → **24**（与导航项标签同一条左边线，修 P11）；品牌图标 30 → **28**。

### 5.3 侧栏

- 品牌行、导航项、底栏的左边线都是 **24**。
- 导航项由系统绘制，不动。
- 底栏"井"：`wellFill`、r12、内边距 12、左右外边距 12、下 12。可用空间数值改 `subheadNumeric`。

### 5.4 内容块

- 块间距 16；块内行距 8；栅格列距 12。
- 统计卡网格统一最小宽 **224**（现有 224 / 236 两种）。**内容列 ≤ 908 时四卡 2×2，≥ 920 时 4×1**——默认 1200 窗口是 2×2，这是预期行为，写进文档。

### 5.5 页面模板

| 模板 | 页面 | 块序 |
|---|---|---|
| 仪表页 | 概览、监控 | 报头 → [英雄卡 或 仪表网格] → 统计网格 / 信息条 → 列表卡 → 脚注 |
| 列表页 | 清理、应用、优化、空间·大文件 | 报头 → (说明行) → (页签 28) → 筛选行 28 → 选择条 48 → 行列表 → (脚注) |
| 地图页 | 空间·地图 | 报头 → 说明行 → 面包屑栏 40 → 地图卡 → 卡片栅格 → (脚注) |

清理页的摘要卡是列表页的"英雄卡"变体：它占据筛选行与选择条的位置，内含该页唯一的 `hero` 档按钮。

---

## 6. 组件

### 6.1 按钮

三角色 × 四档。角色决定形态，档位决定尺寸，**意图决定颜色**（§4）。

| 角色 | 形态 | 可用档位 |
|---|---|---|
| `Primary` | 实心 `goFill` + `onAccent`（`confirm` 意图在确认界面内用 `dangerSolid` + 白字） | 28 / 36 / 44 |
| `Secondary` | 玻璃胶囊 + 描边，字色 = 意图语义色 | 24 / 28 / 36 / 44 |
| `Tertiary` | 纯文字，`flow` 或 `inkTertiary` | 随所在文字行 |
| 图标按钮 | 无容器，命中区 24×24，`Glyph.caption` 11 | 24 |

### 6.2 `FilterRow` ✚

无容器，高 28。子项**不接受尺寸参数**——高度与字号由行施加。

- 搜索最大宽 260；状态文字靠右；行内元素间距 12。
- 系统控件 `.controlSize(.large)`；开关本体 18（`.small`）居中于 28。
- **标签一律 `body` 13**，包括开关标签。

### 6.3 `SelectionBar`

高 **48**，r12，上下 8 左右 12，动作区放 `standard` 28。

- 常显，不因未选中而隐藏。
- 复选框 **16×16 r4**，三态，描边 1pt `inkFaint`。
- 计数用 `bodyNumeric` + `.contentTransition(.numericText())`。
- ✚ 增加"将影响多少"的合计（如 `18.4 GB`）——批量动作前应该先看到量。

### 6.4 行 · 四种，没有第五种

| 类型 | 高 | 圆角 | 内边距 | 主文字 | 次文字 | 动作 | 用于 |
|---|---|---|---|---|---|---|---|
| 标准行卡 | 56（路径两行 72） | 16 | 12 | `bodyStrong` 13 | `caption` 11 | `compact` 24 | 应用、登录项、大文件、空间前 12 |
| 分组行头 | 64 | 22（卡本身） | 16 | `subhead` 15 | `caption` 11 | 复选框 + 展开 | 清理类别 |
| 紧凑表格行 | 40 | 8（悬停底） | 上下 8 · 左右 8 | `label` 12 | `microMono` 9 | 图标按钮 | 清理条目、监控进程、Sheet 残留 |
| 条 | 40（纯文字）/ 48（含 `standard` 按钮） | 12 | 上下 8 · 左右 12 | `label` 12 | `captionNumeric` 11 | 图标按钮 / `standard` | 面包屑栏、选择条 |

规则：

- 行间距 8；行内元素间距 12；前置图标区 **32**。
- **行标题左边线 = 复选框 16 + 12 + 图标区 32 + 12 = 距行内边缘 72，所有列表页一致。**
- 数值列右对齐、固定宽 **80**（中文量）；动作区固定宽 **96**，右对齐。
- 悬停才出现的动作只能是次要图标按钮；**行的主动作永远可见**（包括"移到废纸篓"）。
- 骨架占位高度必须等于真实行高（现状空间页骨架 76 比真卡 65 高）。

### 6.5 `Badge`

一个组件，两档两样式。吞掉现有九种写法（字号 9/10/11、内边距 1.5/2/2.5/3、字重 medium/semibold/bold、填充 14%/`wellFill`、胶囊/圆）。

| 档 | 高 | 文字 | 左右内边距 | 图标 | 用途 |
|---|---|---|---|---|---|
| 标准 | 18 | `overline` 10 semibold | 8 | `Glyph.badge` 9 | 安全芯片、统计卡徽章、散热徽章、"开机即启动"、"系统自带"、文件夹标签 |
| 紧凑 | 16 | `tag` 9 semibold | 6 | 无（仅图标时 16×16） | 进程"系统"、条目行安全芯片 |

样式两种：**着色**（tint 14% 底 + tint 字）与**中性**（`wellFill` 底 + `inkTertiary` 字）。`CountPill` 归入 `Badge.count`（18 高、`captionNumeric` 11 bold 白字、tint 渐变底）。排名圆标保留 20 圆、字 `overline`。

### 6.6 数字排版 ✚

- **数值与单位分离**：单位降到 `caption` + `inkTertiary`，中间 4pt。"4.31 GB"不是一个词，是一个量和一把尺。
- **一律等宽数位** `.monospacedDigit()`；会变的数字加 `.contentTransition(.numericText())`。
- **精度分档**：< 10 保留两位（4.31）· 10–99 保留一位（18.4）· ≥ 100 取整（612）。同一列精度一致。
- **十进制单位**，与访达一致（README 已承诺）；不做千分位分隔。
- **列右对齐、固定宽 80**（中文量）；不可用的量写"不可用"，不估算。
- 大号读数（`hero` / `metric`）的单位与数值**基线对齐**，不居中。

### 6.7 进度与图表

- `CapacityBar` 只剩两种高度：**4**（卡内、行内）与 **6**（侧栏、菜单栏、扫描卡）。现状五种（3/4/5/6/7）。
- `SegmentedBar` 6。
- 树图瓦片 r8（`chip`），内缩 2。

### 6.8 状态

| 状态 | 规则 |
|---|---|
| 悬停 | 行卡 / 表格行：`aqua` 6% 底；统计卡与英雄卡：`hoverLift`；按钮：系统玻璃自带 |
| 选中 | `aqua` 8% 底 + 1.5pt 描边 `aqua` 50%，圆角同容器 |
| 按下 | 0.8 |
| 禁用 | 0.4，不改颜色，不隐藏 |
| 忙碌 | 小菊花替换图标；行级忙碌用 `.breathing` |
| 空 | `RestfulState`；文案肯定而不道歉 |
| 加载 | 骨架（有形状可预期时）或小菊花 + `caption` |
| 焦点 | 系统焦点环，不自绘 |

### 6.9 设置窗口 / 菜单栏面板 / Sheet

不再另起炉灶，复用主窗口令牌：

- **设置窗口**：`SectionLabel` + 28 系统控件 + `body` 13 标签；关于区品牌图标盒 32；按钮 `emphasis` 36。
- **菜单栏面板**：品牌图标盒 24 + `subhead` 15；井里数值 `subheadNumeric`；三项体征用 `Badge` 中性档 + `bodyNumeric`；"去清理" `emphasis` wide；底部两个 `Tertiary`。
- **Sheet**：头部图标盒 44；标题 `cardTitle`；列表用紧凑表格行 40；页脚两键 `standard`，确认键实心（§4）；`LeftoverRow` 的 4 个字面量改 `label` / `caption` / `microMono`。

---

## 7. 逐页套用清单

| 页 | 改什么 |
|---|---|
| 全部 | 报头行（28 带 · 基线对齐 · 字标降级）；`Page` 上边距 12；插槽只放一个 `standard` 控件；说明行恒 16 高 |
| 侧栏 | 图标盒 28（r8）；左边线统一 24；可用空间改 `subheadNumeric` |
| 概览 | 两颗按钮同为 `hero`；"看看有哪些"满足玻璃可辨度；信任句 `caption`；统计网格最小宽 224；权限卡按钮 `emphasis` |
| 清理 | 摘要卡 `hero` 保留（可逆，实心 aqua）；**"跳过废纸篓"开启后主按钮改文案「永久删除」并要求二次确认 Sheet**；快选 `Tertiary`；类别头 64 + `subhead`；安全芯片改 `Badge`；条目行改紧凑表格行 40，"访达"改图标按钮；完成卡两键 `emphasis` |
| 应用 · 已安装 | 页签下沉；筛选行 28 / 全 13pt；选择条 48 + `standard`；**"卸载所选"改 danger 描边**；行 56、数值列 80、动作区 96；"系统自带"改 `Badge` 中性；卸载 Sheet 页脚两键 `standard`，确认键实心 `#C0342F` |
| 应用 · 开机启动 | 说明行按钮移入插槽（页面只剩一个页面级控件）；排序分段 28；行 56；"移除" danger 描边 `compact`；"开机即启动"改 `Badge` caution |
| 空间 | 页签下沉；面包屑栏 40；插槽"重新查找" `standard`；前 12 卡改标准行卡 56（骨架同高）；大文件行 56 / 72；**"移到废纸篓"改中性描边、常显** |
| 优化 | 任务卡 r22 → 16、高 56（带警告 72）；"执行" `compact`；"执行选中项" `standard`；结果行改 `tag` 9；选择条 48 |
| 监控 | 控件行全部 28（搜索 + 两个分段）；进程行 40；"系统"改 `Badge` 紧凑；散热徽章改 `Badge`；"结束进程"图标按钮 danger + Alert；`CapacityBar` 统一 4 |
| 设置 / 菜单栏 / Sheet | §6.9 |

---

## 8. 落地

### 8.1 新增令牌（`Design/Theme.swift`）

```swift
/// 可点对象的高度。只有这四个值。
public enum Control {
    public static let compact: CGFloat  = 24  // 行内、图标按钮
    public static let standard: CGFloat = 28  // 默认档 —— 90% 的控件
    public static let emphasis: CGFloat = 36  // 卡内主动作
    public static let hero: CGFloat     = 44  // 每页最多一组

    /// 系统控件对齐。
    public static func size(for height: CGFloat) -> ControlSize {
        height >= emphasis ? .extraLarge : (height >= standard ? .large : .small)
    }

    /// 档位决定字号与内边距，调用方传不了。
    public static func actionFont(for height: CGFloat) -> Font { … }
    public static func horizontalPadding(for height: CGFloat) -> CGFloat { … }
}

/// SF Symbol 的点尺寸。不再借用 Typo.Step。
public enum Glyph {
    public static let badge: CGFloat   = 9
    public static let caption: CGFloat = 11
    public static let control: CGFloat = 13
    public static let row: CGFloat     = 15
    public static let card: CGFloat    = 17
    public static let title: CGFloat   = 20
    public static let feature: CGFloat = 30
}

/// 有底色的方形图标容器。尺寸与圆角成对，不可拆开。
public enum IconBox {
    case small, masthead, medium, large

    public var side: CGFloat { switch self {
        case .small: 24; case .masthead: 28; case .medium: 32; case .large: 44 } }
    public var radius: CGFloat { switch self {
        case .small: 6; case .masthead, .medium: 8; case .large: 12 } }
}

/// 动效五档 + 入场。取代现有 13 种时长。
public enum Motion {
    public static let press  = Animation.snappy(duration: 0.16)
    public static let hover  = Animation.smooth(duration: 0.20)
    public static let state  = Animation.smooth(duration: 0.25)
    public static let reveal = Animation.smooth(duration: 0.30)
    public static let settle = Animation.smooth(duration: 0.50)
    public static let enter  = Animation.smooth(duration: 0.55)
    public static let enterStagger: Double = 0.06
}

extension Radius {
    /// 小方块：复选框、图例、核心条。
    public static let control: CGFloat = 4
}
```

### 8.2 把破坏性语法编进类型（`Design/Actions.swift`）

与 v1.0 最大的实现差异。v1.0 给 `PrimaryButtonStyle` 加一个 `size:` 参数，`tint:` 仍然自由——于是"实心 danger"照样写得出来。这里让调用方声明**意图**，形态由意图推导。

```swift
/// 这个动作对用户意味着什么。形态与颜色由它推导，调用方不选颜色。
public enum ActionIntent {
    case neutral        // 中性：打开、刷新、取消
    case go             // 让用户变好，且可撤回 —— 唯一可实心的意图
    case reversible     // 可逆的删除：移到废纸篓
    case destructive    // 不可逆的提议：卸载、永久删除、结束进程
    case confirm        // 不可逆的确认 —— 仅确认界面
}

public struct ActionButtonStyle: ButtonStyle {
    var intent: ActionIntent = .neutral
    var height: CGFloat = Control.standard
    var wide: Bool = false

    /// 由 confirmationSurface() 注入。confirm 只在它为 true 时才画实心。
    @Environment(\.isConfirmationSurface) private var inConfirmation

    public func makeBody(configuration: Configuration) -> some View {
        // 形态由 intent 决定，调用方无法覆盖：
        //   .go      → goFill 实心，onAccent 字
        //   .confirm → dangerSolid 实心，白字（仅 inConfirmation；否则退化成描边）
        //   其余     → 玻璃胶囊 + 描边（见 §4.4 的可辨度下限），字色 = intent 语义色
        // 字号与内边距由 height 查表，不接受单独传参。
        //
        // assert(intent != .confirm || inConfirmation)
        // assert(!(intent == .destructive && height == Control.hero))
        …
    }
}

extension View {
    /// 确认界面（Sheet / Alert）用它包住内容，才解锁 .confirm 的实心形态。
    public func confirmationSurface() -> some View {
        environment(\.isConfirmationSurface, true)
    }
}
```

### 8.3 容器施加尺寸（`Design/Containers.swift`）

原则一的实现：子项从环境读高度，不从调用点读。页面写不出"三个不同高度并排"。

```swift
/// 一行筛选控件。高度与字号由行施加给所有子项。
public struct FilterRow<Content: View>: View {
    @ViewBuilder var content: Content
    public var body: some View {
        HStack(spacing: Space.md) { content }
            .frame(height: Control.standard)
            .font(Typo.body)                    // 全行一个字号
            .controlSize(.large)                // 系统控件对上 28
            .environment(\.rowControlHeight, Control.standard)
    }
}

/// 报头行。侧栏与内容列各调一次，共享同一条基线。
public struct Masthead<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing         // 恰好一个 standard 档控件

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.lg) {
            Text(title).font(Typo.pageTitle).foregroundStyle(Palette.ink)
            Spacer(minLength: Space.md)
            trailing
                .frame(height: Control.standard)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 7 }
        }
        .frame(height: Control.standard, alignment: .bottom)
        .padding(.top, Space.md)                // 标题栏下缘 +12
    }
}

/// 页签。不再进报头插槽 —— 它切换的是下面的列表。
public struct PageTabs<S: Hashable>: View { … }  // 28 高，内容列左边线
```

### 8.4 CI 拦截（`scripts/check-ui-standard.sh`，七条）

```bash
P=Sources/MacPlecoKit
F="$P/Features $P/App"

# 1 页面里不得拼字号
grep -rn '\.font(\.system(size:' $F && exit 1
# 2 不得有圆角字面量
grep -rnE 'cornerRadius: [0-9]' $P --include='*.swift' | grep -v Design/ && exit 1
# 3 不得对间距做算术
grep -rnE 'Space\.[a-z]+ [+-] ' $P && exit 1
# 4 ✚ 页面不得自己写高度（高度只能来自 Control）
grep -rnE '\.frame\((height|minHeight): [0-9]' $F && exit 1
# 5 ✚ 页面不得引用原始字号阶梯
grep -rn 'Typo\.Step' $F && exit 1
# 6 ✚ 旧按钮样式不得回流
grep -rn 'PrimaryButtonStyle\|GhostButtonStyle' $P && exit 1
# 7 ✚ 调用方不得选颜色
grep -rnE 'ActionButtonStyle\([^)]*tint:' $P && exit 1
# 另外：每个用了 .confirm 的文件里必须出现 confirmationSurface()
```

脚本会跳过注释行——本文件与设计系统的注释都点名引用了被禁的旧 API。

### 8.5 顺序

1. **令牌**：`Control`、`Glyph`、`IconBox`、`Motion`、`Radius.control`；`Typo` 补 4 个 `*Numeric`，`Typo.Step` 收回内部。
2. **语义层**：`ActionIntent` + `ActionButtonStyle` + `confirmationSurface()`。单独一个 PR——它改变的是界面的语气，不是尺寸。
3. **容器**：`Masthead`、`FilterRow`、`PageTabs`、`Badge`、`IconButton`；`SelectionBar` → 48、`SearchField` → 28、`TriStateBox` → 16、`CapacityBar` 只留 4 / 6。
4. **页面**：报头（全部，一次改完最见效）→ 应用 → 清理 → 空间 → 优化 → 监控 → 设置 / 菜单栏 / Sheet。
5. **拦截与验收**：`scripts/check-ui-standard.sh` 进 CI 第一步；探针量到 §9 的全部数字。

---

## 9. 验收数字（1200×800 · 中文）

| 测点 | 目标 |
|---|---|
| 品牌字标基线 / 页面标题基线 | 相等（标题栏下缘 +33） |
| 侧栏品牌 x / 导航项 x | 24 / 24 |
| 页面标题 x / 内容块 x | 284 / 284 |
| 报头插槽高（每一页） | 28 |
| 说明行高 / 带按钮时 | 16 / 16 |
| 筛选行高 / 其中每个控件 | 28 / 28 |
| 筛选行内每个标签字号 | 13（全部） |
| 选择条高 / 其中按钮 | 48 / 28 |
| 标准行卡 / 紧凑表格行 | 56 / 40 |
| 行标题左边线（距行内边缘） | 72（全站） |
| 数值列宽 / 动作区宽 | 80 / 96 |
| 徽章高（标准 / 紧凑）· 复选框 | 18 / 16 · 16 |
| 页内 `hero` 档按钮组 / 实心色块 | ≤ 1 / ≤ 1 |
| **实心 `danger` 出现次数（主窗口）** | **0** |
| `check-ui-standard.sh` 七条 | 全部 0 命中 |

---

## 10. 三个悬而未决的问题，以及它们的结论

本节原是「还没定的三件事」。三件都已定，实现照此。

### 10.1 深色模式的实心 `danger`

**结论：不走描边，用一个双外观都够深的填充。**

原本倾向「深色下确认键也走描边」，理由是更一致。没有采纳：那会让同一个确认动作在浅色下是实心、
在深色下是描边，而在这套语法里**形态本身承载语义**——实心意味着「这是本界面唯一的、你已经确认过的动作」。
让它随外观改变，等于让语义随外观改变。

原来的反对意见（"深色下 `danger` 是 `#FF7A72`，实心配白字只有 2.1:1"）针对的是直接拿 `danger` 当填充。
专门的填充令牌不受这个限制：

| 外观 | `dangerSolid` | 白字对比度 |
|---|---|---|
| 浅色 | `#C0342F` | 5.57:1 |
| 深色 | `#8F2C28` | 8.21:1 |

同一处思路也解决了 `.go`：见 §4.2 与 §11.2。

### 10.2 监控页四张仪表卡的最小宽

**结论：统一到 224，接受中文图例在窄窗口下换成两行形态。**

采纳原倾向。给仪表卡开一个 236 的例外，等于让两个页面的同一种卡在不同宽度换行，
而 `LegendRow` 的四段降级本来就是为这件事写的（见 §6.4 与组件注释）。
代价是默认 1200 窗口下内存卡的图例是两行——这是设计过的形态，不是溢出。

### 10.3 「跳过废纸篓」开关的位置

**结论：开关留在摘要卡里，但那颗按钮随开关改变意图。**

采纳 §7 的写法而不是「移进设置窗口」的激进版。移走开关会让一个真实存在的能力更难找到，
而问题从来不是开关在哪，是**同一次点击在两种状态下后果不同却长得一样**。

开关打开后，那颗按钮同时改四样东西：

| | 关（可逆） | 开（不可逆） |
|---|---|---|
| 文案 | 移到废纸篓 22.2 GB | 永久删除 22.2 GB |
| 意图 | `.go` | `.destructive` |
| 档位 | `hero` 44 实心 | `emphasis` 36 描边 |
| 行为 | 直接执行 | 先弹确认 Sheet（唯一的实心 danger 在那里） |

主界面因此仍然只有可逆动作会被直接执行。

---

## 11. 实施记录（2026-09-08）

本节记录标准落地后的实际情况：量到的数字、三个未决问题的结论，以及实施中发现的一处标准本身的错误。

### 11.1 §9 验收：21 / 21 通过

用附录的探针方案量的（31 个测点，1200×800，中文，真实 `NSHostingView` 窗口）。

| 测点 | 目标 | 实测 |
|---|---|---|
| 品牌字标基线 / 页面标题基线 | 相等（标题栏下缘 +33） | **两者都是 85.0**（52 + 33） |
| 侧栏品牌 x / 导航项 x | 24 / 24 | 24 / 24 |
| 页面标题 x / 内容块 x | 284 / 284 | 284 / 284 |
| 报头插槽高（每一页） | 28 | 28 |
| 说明行高 / 带按钮时 | 16 / 16 | 16（按钮已移入插槽） |
| 筛选行高 / 其中每个控件 | 28 / 28 | 28 / 28（搜索、下拉、分段、开关） |
| 页签高 | 28 | 28 |
| 选择条高 / 其中按钮 | 48 / 28 | 48 / 28 |
| 面包屑（纯文字条） | 40 | 40 |
| 标准行卡 / 带警告 | 56 / 72 | 56 / 72 |
| 紧凑表格行 / 分组行头 | 40 / 64 | 40 / 64 |
| 行标题左边线（距行内边缘） | 72 | 72 |
| 徽章高（标准 / 紧凑）· 复选框 | 18 / 16 · 16 | 18 / 16 · 16 |
| 图标按钮命中区 | 24 | 24 |
| 页内实心色块 | ≤ 1 | 概览 1、清理 1，其余 0 |
| **实心 `danger` 出现次数（主窗口）** | **0** | **0** |
| `check-ui-standard.sh` 七条 | 全部 0 命中 | 0 |

两处在第一轮量出来不对，改了：

- **侧栏品牌 x = 32，不是 24。** 侧栏面板本身被系统内缩了 8，所以 24 的内边距把品牌推到了 32，而导航项在 24。改成 16。
- **行标题左边线 = 80，不是 72。** 复选框的命中区是 24 宽，把后面所有东西推了 8。改成横向 16（纵向仍是一个控件档），并给没有勾选的列表（开机项、大文件、前 12）补一个同宽的占位列——否则同一页两个页签之间标题会横跳 28。

### 11.2 标准自己的一处错误：填充按钮的对比度

§4.2 写着"可逆 · 好事 → 实心 `aquaSweep`，白字，白 / aqua = 4.9:1 ✓"。用 `Theme.swift` 里的实际色值算，这一行是错的：

| 组合 | 实测对比度 |
|---|---|
| 白字 / `aquaBright` #11B3A4（浅色渐变起点） | **2.62:1** |
| 白字 / `aqua` #0B8F84（浅色中点） | 3.98:1 |
| 白字 / `aquaBright` #62F0DA（深色起点） | **1.40:1** |
| 白字 / `aqua` #38D9C4（深色中点） | 1.77:1 |
| 对照：白字 / 12% `danger` 玻璃 tint（本标准要废掉的那颗粉红按钮） | 1.39:1 |

也就是说「开始清理」——全 App 最响、最该被看清的那颗按钮——比标准专门写来修的那颗还难读，深色模式下尤其糟。渐变不能承载文字，这一点标准没查。

**改法**：`aquaSweep` 降级为纯装饰（水位环、容量条、树图），另立一组承载文字的令牌：

- `goFill`：浅色走深（#0A8378 → #077268 → #055C54），深色保持亮薄荷（#62F0DA → #38D9C4 → #1B9C93）。
- `onAccent`：浅色白、深色近黑（#061018）。这一个令牌覆盖 `aqua` / `caution` / `flow` / `positive` / 图表色的全部场合——这套调色板的所有强调色在浅色下都偏深、在深色下都偏亮，所以「压在强调色上的字」的颜色是跟着外观翻转的。

实测：`goFill` + `onAccent` 最低 **4.64:1**（浅色）与 **5.68:1**（深色）。`dangerSolid` 保持白字，5.57:1（浅色）/ 8.21:1（深色）。

同一处修正也套用在：品牌图标（白鱼压亮薄荷）、计数徽章、复选框的勾——它们此前都是白字压强调色渐变。

### 11.3 §10 三个未决问题

三个都已定，结论连同理由写在 §10 里，不在这里重复。摘要：深色确认键仍是实心（换用双外观都够深的
`dangerSolid`），仪表卡统一 224 并接受两行图例，「跳过废纸篓」开关留在原处但让按钮随之改变意图。

### 11.4 落地清单

| 层 | 内容 |
|---|---|
| 令牌 | `Control`（24/28/36/44）、`Glyph`、`IconBox`、`Motion`、`Layout`、`Radius.control`；`Typo` 补 `subheadNumeric` / `bodyNumeric` / `captionNumeric` / `tag` / `sidebarItem`，`Typo.Step` 收为 internal；`goFill` / `onAccent` / `dangerSolid` / `controlFill` / `controlStroke` |
| 语义层 | `ActionIntent`（neutral / go / reversible / destructive / confirm）、`ActionButtonStyle`、`TextButtonStyle`、`IconButton`、`confirmationSurface()`、`actionEnabled(_:)` |
| 容器 | `Masthead` / `BrandMasthead` / `MastheadBand`、`FilterRow`、`PageTabs`、`SegmentedChoice` / `MenuChoice` / `ChoiceToggle`、`IconTile`、`Badge`、`Reading`、`RowLeadingSpacer`、`rowSelection(_:hovering:)` |
| 玻璃 | `GlassLevel.interactive` 现在自带可辨度下限（填充 + ≥16% 描边），macOS 26 与回退分支都画 |
| 页面 | 六个页面、设置窗口、菜单栏面板、两个卸载 Sheet 全部改完；新增清理页的永久删除确认 Sheet |
| 拦截 | `scripts/check-ui-standard.sh`（7 条规则），在 CI 里第一步跑 |
| 测试 | `ReadingTests`：数值与单位的切分——"M5 Max" 和 "5 小时 3 分" 不是测量值，不能被拆 |

### 11.5 已知的偏差

- **紧凑表格行不遵守 72 的标题左边线。** 进程、清理条目、Sheet 残留用的是 8pt 内缩的紧凑几何，与标准行卡不是同一种行；§6.4 也是分开定义的。
- **默认窗口下统计卡仍是 2×2。** 内容列 ≤ 908 时四卡两行，这是网格的既定行为，标准 §5.4 已写明，不是回归。
- **视觉核对已经做过，但设置窗口截不到。** 主窗口六个页面在浅色与深色下都逐页看过：意图切换（打开「跳过废纸篓」后按钮改文案、降档、改描边、弹确认）、深色下 `goFill` 配 `onAccent` 的实际观感、以及各行高与徽章。设置窗口的截图始终失败，所以深色模式是改 `com.macpleco.appearance` 偏好后重启验证的。`screencapture` 仍然不可用；computer-use 的 `app_screenshot` 对主窗口可用。

---

## 附录 · 怎么量

沿用 v1.0 的探针方案：复制模块到临时目录，在要量的视图上加 `measure("名字")`（`onGeometryChange` 读 `.global` 坐标），用一个 `@main` 探针把 `RootView().environment(AppModel())` 装进 `NSHostingView`（`sceneBridgingOptions = [.all]` 才有系统工具栏），逐页切 `model.destination`，等数据到了再打印。要点：

- 在真实窗口里量，不要另搭裸组件——内容（尤其中文）才是把布局撑坏的东西。
- `.rises()` 的入场位移会让同一个视图出现两个坐标，取小的那个。
- 网格列数依赖容器宽，1200 和 1600 各量一次。
- **本版新增：基线要量 `.firstTextBaseline` 的全局 y，不是 frame 的中心 y。**

---
