MacPleco 0.3.2 — inspect every cleanup target before it moves.

MacPleco 0.3.2 —— 每个清理目标都能先核对，再移动。

### Full paths for every item · 每一项都显示完整路径

Every file or directory listed in Clean now shows its absolute path directly
under its name. Status messages such as “the app is running” or “the app is no
longer installed” remain visible between the title and path, so safety context
is not lost. Long paths can use two lines, keep their identifying beginning and
end visible, and expose the complete value in the pointer help.

清理页面里的每个文件或目录，现在都会在名称下方直接显示绝对路径。诸如“应用正在运行”
或“应用已经卸载”的状态说明仍保留在名称与路径之间，不会因为显示路径而丢失风险信息。
较长路径可以显示两行，并保留最有辨识度的开头与结尾；悬停时还能查看完整值。

### Reveal in Finder, including right-click · 行内与右键均可在访达定位

- A compact, always-visible Finder button sits next to each item's size.
- Right-clicking any row offers **Show in Finder** and **Copy Full Path**.
- Files and directories use Finder's native reveal operation, which opens the
  containing location and selects the exact cleanup target.
- Buttons include localized help and accessibility labels.

- 每项大小旁新增常驻的紧凑“访达”按钮。
- 右键任意一行可选择“在访达中显示”或“复制完整路径”。
- 文件与目录统一调用访达原生定位操作，打开所在位置并选中准确的清理目标。
- 按钮包含中英文帮助文本与辅助功能标签。

### Nothing included is hidden · 不再隐藏已计入清理的项目

Expanded categories previously displayed only their first 80 entries while
silently including the remainder in selection and totals. That cap is gone.
The list remains lazy for performance, but every item included in a cleanup can
now be inspected, revealed and individually deselected before anything moves.

展开分类过去只显示前 80 项，后面的内容却仍会被计入选择和总大小。这个上限现已移除。
列表继续按需创建行以控制性能，但凡是会参与清理的项目，现在都能在执行前逐项查看、
在访达定位或取消选择。

### Install · 安装

Drag MacPleco into Applications. On first launch, use System Settings →
Privacy & Security → Open Anyway if macOS asks, then grant Full Disk Access
for cache measurement. Requires macOS 15 or later; native Liquid Glass renders
on macOS 26.

把 MacPleco 拖入「应用程序」。首次启动如遇提示，请前往「系统设置 → 隐私与安全性」
选择「仍要打开」，然后授予完全磁盘访问权限以测量缓存。需要 macOS 15 或更高版本；
原生液态玻璃效果在 macOS 26 上呈现。

---

Feedback → https://github.com/decli/MacPleco/issues · Inspired by
[Mole](https://github.com/tw93/Mole) · GPL-3.0
