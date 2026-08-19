MacPleco 0.3.5 — the two things 0.3.4 did not actually fix, fixed with the
cause measured rather than guessed.

MacPleco 0.3.5 —— 0.3.4 没能真正修好的两个问题，这次先量出原因再修。

### Cards that are actually the same width · 真正等宽的卡片

The gap before the last gauge really was bigger than the others, and the grid
was not the reason. The memory card's three-part legend wants 245pt in Chinese,
and a quarter of the window leaves the card 217pt; a card sized to its contents
grew past its column and overlapped both neighbouring gutters, leaving only the
final gap at its true width. Measured in a hosted copy of the real page, the
four cards were 249 / 292.5 / 249 / 249pt with gaps of −9.75, −9.75 and 12.

A card's reserved slots are now laid out so that nothing inside one can widen
it, and a legend gives way instead — normal gutters, tight gutters, then swatch
and reading without the key, whichever is the widest that fits. At every window
size from the minimum to full screen, all four cards now measure identical
widths with identical gaps.

最后一张卡片的间距确实比其它的大，但原因不在网格。内存卡片的三段图例在中文下需要
245pt，而窗口四分之一只给卡片 217pt；卡片被自身内容撑宽后越出所在列，挤进两侧的
间距，于是只有最后一处间距还是原本的宽度。在真实页面的宿主副本中实测：四张卡片为
249 / 292.5 / 249 / 249pt，间距为 −9.75、−9.75、12。

现在卡片的预留槽位不会被内部内容撑宽，图例改为逐级让步：正常间距 → 紧凑间距 →
只保留色块与数值。从最小窗口到全屏，四张卡片实测宽度一致、间距一致。

### A readout that follows the pointer · 跟着指针走的读数

The space map's header could name one folder while the cursor rested on
another. A tile only hears about the pointer when the pointer crosses its own
edge, so anything that moved tiles under a still cursor — a folder finishing
its measurement, drilling into the next level — left the previous tile holding
the highlight.

The readout is no longer remembered. It is worked out from where the pointer
is, against the tiles as they are laid out at that moment, so the name in the
header and the tile under the cursor are now the same answer rather than two
values updated separately.

空间地图的标题栏可能显示 A，而指针其实停在 B 上。色块只有在指针跨过它自己的边界时
才会收到通知，因此任何在指针不动时让色块重排的事情——某个文件夹刚测量完成、进入下
一层——都会让上一个色块继续持有高亮。

现在读数不再被“记住”，而是根据指针位置与当前布局实时判定：标题栏里的名称和指针下
的色块是同一个答案，不再是两个各自更新的值。

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
