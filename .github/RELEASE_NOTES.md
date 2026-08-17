A native macOS app for reclaiming disk space, uninstalling apps cleanly, and
seeing what your Mac is doing — built around Apple's Liquid Glass design
language, and built for people who do not want to learn what `~/Library/Caches`
means.

一款原生 macOS 应用，用来回收磁盘空间、干净地卸载应用、查看系统状态。界面遵循 Apple
的液态玻璃设计语言，做给不想搞懂 `~/Library/Caches` 是什么的人用。

### What's in it · 有什么

- **Overview** — the whole picture on one screen, and one button.
- **Clean** — caches, logs, browsers, developer output, AI tools, cloud sync,
  window state, uninstalled-app leftovers, old installers, Trash. Apps holding
  a cache open are listed with the bytes they're sitting on.
- **Apps** — sizes and last-opened dates; uninstall shows the full plan
  (bundle + every leftover, each declinable) before anything moves. Plus
  launch agents.
- **Space** — a squarified treemap of where the space went.
- **Tune-Up** — eight repairs for specific symptoms, none pre-selected.
- **Monitor** — live CPU, memory, network, busiest processes.

Everything goes to the Trash by default. Permanent deletion is a separate
switch that resets after every run. Chat caches, Xcode archives and anything an
app is holding open are never pre-selected. No administrator password needed.

所有内容默认先进废纸篓；「跳过废纸篓」是单独开关且每次执行后复位。聊天软件缓存、
Xcode 归档、正在被占用的目录一律不默认勾选。全程不需要管理员密码。

### Install · 安装

1. Open the `.dmg` and drag **MacPleco** into **Applications**.
2. MacPleco is open source and is not signed with a paid Apple Developer ID, so
   macOS will say the developer cannot be verified. Open **System Settings →
   Privacy & Security**, scroll to the bottom, click **Open Anyway**. Or run
   once in Terminal:
   ```
   xattr -dr com.apple.quarantine /Applications/MacPleco.app
   ```
3. Grant **Full Disk Access** when asked — macOS keeps every app out of other
   apps' cache folders, and nothing can be measured without it.

打开 `.dmg` 把 MacPleco 拖进「应用程序」。首次打开时 macOS 会提示无法验证开发者，
去「系统设置 → 隐私与安全性」滑到底部点「仍要打开」，或执行上面那行命令。然后按引导
授予「完全磁盘访问权限」。

Requires macOS 15 or later. Liquid Glass renders on macOS 26; earlier versions
fall back to system materials. Universal binary (Apple silicon + Intel).

需要 macOS 15 或更高版本。通用二进制，Apple 芯片和 Intel 都支持。

### Please read before first use · 首次使用前请看

This is the first public build. It compiles cleanly, ships as a signed
universal binary, and its safety guard is covered by unit tests that run on
every commit — but it has not yet been exercised interactively on a physical
Mac. For a tool that deletes files, that is worth saying plainly.

So for this release: **look at what is selected before you press the button**,
and leave "Skip the Trash" off. Everything the app removes by default is
recoverable from the Trash, which is exactly the safety net to keep while a
release is this young.

这是第一个公开版本。它编译干净、以签名的通用二进制发布、安全闸门有单元测试在每次提交时
覆盖 —— 但还没有在真机上做过完整的交互测试。对一个会删文件的工具，这一点必须说清楚。

所以这一版：**按按钮之前先看一眼选中了什么**，并且不要打开「跳过废纸篓」。默认删除的
所有内容都能从废纸篓恢复，这个安全网在版本还这么新的时候值得留着。

Bug reports very welcome: https://github.com/decli/MacPleco/issues

---

Inspired by [Mole](https://github.com/tw93/Mole). GPL-3.0.
