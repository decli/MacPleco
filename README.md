<div align="center">
  <h1>MacPleco</h1>
  <p><strong>A calm, native Mac cleaner built on Liquid Glass.</strong></p>
  <p><strong>一款安静、原生、遵循液态玻璃设计的 Mac 清理工具。</strong></p>
  <p>
    <a href="https://github.com/decli/MacPleco/releases/latest"><img src="https://img.shields.io/github/v/release/decli/MacPleco?style=flat-square&label=download" alt="Download"></a>
    <img src="https://img.shields.io/badge/macOS-15%2B-black?style=flat-square" alt="macOS 15+">
    <img src="https://img.shields.io/badge/Swift-6-orange?style=flat-square" alt="Swift 6">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square" alt="GPL-3.0"></a>
  </p>
</div>

---

The pleco is the fish that quietly keeps an aquarium clear. MacPleco does the
same for a Mac — and it is built for the person who does *not* want to learn
what `~/Library/Caches` means.

清道夫鱼安安静静地把鱼缸打理干净。MacPleco 对 Mac 做同样的事 —— 而且是为
**不想搞懂 `~/Library/Caches` 是什么**的人做的。

## Why another cleaner · 为什么再做一个

Most Mac cleaners are built to alarm you. They colour everything red, count
your "problems", and make the destructive button the obvious one. MacPleco is
built on the opposite instinct.

大部分 Mac 清理工具是靠制造焦虑活着的：满屏飘红、给你数「问题」、把最危险的按钮
做得最显眼。MacPleco 反着来。

| | |
|---|---|
| **Reversible by default**<br>**默认可撤销** | Everything goes to the Trash, so a wrong tick costs a trip to the Trash, not a restore from backup. Permanent deletion is a separate, deliberate switch that resets after every run.<br>所有内容先进废纸篓。选错了就去废纸篓「放回原处」，不用翻备份。「跳过废纸篓」是一个单独的开关，每次执行后自动复位。 |
| **Plain language, paths on demand**<br>**说人话，路径按需展开** | Rows say "Chrome browser cache", not `~/Library/Caches/com.google.Chrome`. Every category states what happens afterwards *before* you are asked to tick anything.<br>列表里写的是「Chrome 浏览器缓存」而不是一串路径。每个分类都在你勾选之前，先说清楚清理完会发生什么。 |
| **Risky things stay unchecked**<br>**危险的默认不选** | Chat app caches hold photos and videos that may not be downloadable again, so MacPleco never selects them for you. Neither are Xcode archives, Maven repositories, or anything an app is holding open right now.<br>聊天软件缓存里是可能再也下不回来的图片和视频，所以永远不会替你勾上。Xcode 归档、Maven 仓库、正在被运行中的应用占用的目录，同理。 |
| **Honest numbers**<br>**数字不注水** | Sizes are decimal, matching Finder. Finding nothing to clean is reported as good news, not as an empty result.<br>体积用十进制，和访达一致。没找到可清理的内容会被当成好消息，而不是一个空列表。 |
| **No admin password**<br>**不要管理员密码** | Cleaning stays inside your own account. The space it would buy elsewhere is small next to the risk it carries.<br>清理只在你自己的账户范围内进行。去动系统目录能多腾出的那点空间，不值得那份风险。 |

## What's inside · 有什么

**Overview · 概览** — One screen with the whole picture: how full the disk is,
how much MacPleco can give back, and one button. A non-technical user can stop
here and have done the right thing.
一屏看完全部：磁盘多满、能回收多少、一个按钮。不懂技术的人看到这里就可以停下了。

**Clean · 清理** — Caches, logs, browser data, developer build output, AI tool
caches, cloud sync caches, window state, uninstalled-app leftovers, old
installers and the Trash. Apps holding a cache open are surfaced with the bytes
they are sitting on, so you know what quitting Chrome would buy you.
缓存、日志、浏览器数据、开发构建产物、AI 工具缓存、云盘缓存、窗口状态、卸载残留、
旧安装包和废纸篓。正在占用缓存的应用会单独列出来，告诉你退出它们能多清多少。

**Apps · 应用** — Every installed app with its size and when you last opened
it. Uninstalling shows the full plan first: the bundle plus every preference,
container and cache it left elsewhere, each with a size and each declinable.
Plus the launch agents that start with your Mac.
所有已安装应用，带体积和上次打开时间。卸载前会先列出完整清单：应用本体，加上它散落
在各处的偏好设置、沙盒容器和缓存，每一项都有体积，每一项都可以不删。另外还有开机启动项。

**Space · 空间** — A squarified treemap of where the space actually went, one
folder at a time — sizes stream in as they're measured, colour depth tracks
size. Plus a large-file radar: everything over 100 MB in your everyday folders.
用矩阵树图看空间到底去哪了：测完一个显示一个，颜色越深占得越多。还有大文件雷达，
把常用文件夹里超过 100 MB 的文件按大小排给你。

**Tune-Up · 优化** — Eight repairs for specific symptoms: a broken Open With
menu, blank preview thumbnails, tofu boxes instead of text, stale DNS, white
page icons, `.DS_Store` littering shared drives, off-screen windows, a stuck
Finder. Nothing is pre-selected.
八个针对具体毛病的小修小补：「打开方式」菜单错乱、预览图空白、字体显示成方块、DNS
过期、图标变白纸、往共享盘里写 `.DS_Store`、窗口跑到屏幕外、访达卡死。默认一个都不选。

**Monitor · 监控** — Live CPU with per-core bars, memory in honest binary
units, network, and the busiest processes with their real icons. Sampling stops
when you leave the section.
实时 CPU（含每核心负载条）、二进制单位的内存、网络、带真实图标的进程列表。
离开这个页面就停止采样。

**Menu bar · 菜单栏** — A small fish that answers "how full is my disk?" at a
glance, with live vitals and one click into cleaning.
菜单栏小鱼随时告诉你磁盘还剩多少，一键进入清理。

## Install · 安装

Download the `.dmg` from [Releases](https://github.com/decli/MacPleco/releases/latest)
and drag MacPleco into Applications.

从 [Releases](https://github.com/decli/MacPleco/releases/latest) 下载 `.dmg`，
把 MacPleco 拖进「应用程序」。

MacPleco is open source and is not signed with a paid Apple Developer ID, so
macOS will say the developer cannot be verified. Open **System Settings →
Privacy & Security**, scroll to the bottom and click **Open Anyway** — or run
this once:

本项目开源，没有购买 Apple 开发者证书，所以 macOS 会提示「无法验证开发者」。打开
「系统设置 → 隐私与安全性」，滑到底部点「仍要打开」；或者在终端执行一次：

```bash
xattr -dr com.apple.quarantine /Applications/MacPleco.app
```

Then grant **Full Disk Access** when the app asks. macOS keeps every app out of
other apps' cache folders by default, and MacPleco cannot measure anything
without it.

然后按应用内引导授予「完全磁盘访问权限」。macOS 默认不让任何应用读取其他应用的缓存
目录，没有这个权限 MacPleco 什么都算不出来。

Requires **macOS 15 or later**. Liquid Glass renders on macOS 26; earlier
versions fall back to system materials.
需要 **macOS 15 或更高版本**。液态玻璃效果在 macOS 26 上呈现，更早的系统回退到系统材质。

## Safety · 安全设计

Removal is guarded in two independent places. The catalog declines to offer
certain paths, and `SafePath` refuses them again at the moment of deletion — so
a mistake in a rule cannot become a mistake on disk.

删除有两道独立的闸门：规则目录不会把某些路径拿出来，`SafePath` 在真正执行删除时再拒绝
一次 —— 规则写错不会变成磁盘上的错误。

There are three removal policies with genuinely different reach, so the
automated sweep cannot inherit the uninstaller's or the space map's privileges:

三种删除策略的权限范围完全不同，自动清理拿不到卸载器和空间地图的权限：

| Policy | Reach |
|---|---|
| `sweep` | Automated cleaning. A narrow allowlist of cache and log roots inside your home folder — nothing else. |
| `uninstall` | Adds application bundles in `/Applications`, and only those. |
| `userSelected` | A path you located and right-clicked yourself in the space map. |

Model weights (`.gguf`, `.safetensors`, anything under a `models/` directory or
an Ollama blob store) are refused everywhere — they are enormous and slow to
fetch, and no cleaner should treat them as junk.

模型权重文件（`.gguf`、`.safetensors`、`models/` 目录下的内容、Ollama 的 blob 存储）
在任何情况下都不会被删 —— 它们又大又难下载，不该被当成垃圾。

Read [`SafePath.swift`](Sources/MacPlecoKit/Core/SafePath.swift) and its
[tests](Tests/MacPlecoKitTests/SafePathTests.swift) — that is the whole policy.

## Build · 自己编译

No Xcode project, no third-party dependencies.

没有 Xcode 工程文件，没有第三方依赖。

```bash
git clone https://github.com/decli/MacPleco.git
cd MacPleco
swift test                          # run the safety tests
./scripts/build-app.sh 1.0.0        # -> dist/MacPleco.app (universal)
./scripts/make-dmg.sh 1.0.0         # -> dist/MacPleco-1.0.0.dmg
```

The app icon is generated by `scripts/make-icon.py` using nothing but the
Python standard library.

## Credits · 致谢

MacPleco is a from-scratch native app, but it stands on the domain knowledge of
[**Mole**](https://github.com/tw93/Mole) by [tw93](https://github.com/tw93) — an
excellent terminal-first Mac maintenance toolkit. If you live in a terminal, use
Mole.

MacPleco 是完全重写的原生应用，但它建立在 [tw93](https://github.com/tw93) 的
[**Mole**](https://github.com/tw93/Mole) 积累的领域知识之上 —— 那是一个非常优秀的
命令行 Mac 维护工具。如果你习惯用终端，请直接用 Mole。

## License · 许可

[GPL-3.0](LICENSE), the same license as Mole.
