MacPleco is a native macOS app for reclaiming disk space, uninstalling apps
cleanly, and seeing what your Mac is doing — built around Apple's Liquid Glass
design language.

### Install

1. Open the `.dmg` and drag **MacPleco** into **Applications**.
2. MacPleco is open source and is not signed with a paid Apple Developer ID,
   so macOS will say the developer cannot be verified. Open
   **System Settings → Privacy & Security**, scroll down, and click
   **Open Anyway**. Or run once in Terminal:
   ```
   xattr -dr com.apple.quarantine /Applications/MacPleco.app
   ```
3. Grant **Full Disk Access** when the app asks — it cannot measure or clear
   caches without it.

Requires macOS 15 or later. Liquid Glass renders on macOS 26; earlier versions
fall back to system materials.

---

MacPleco 是一款原生 macOS 应用，用来回收磁盘空间、干净地卸载应用、查看系统状态，
界面遵循 Apple 的液态玻璃设计语言。

### 安装

1. 打开 `.dmg`，把 **MacPleco** 拖进 **应用程序**。
2. 本项目开源且未购买 Apple 开发者证书，macOS 会提示「无法验证开发者」。
   打开「系统设置 → 隐私与安全性」，滑到底部点「仍要打开」。或在终端执行一次：
   ```
   xattr -dr com.apple.quarantine /Applications/MacPleco.app
   ```
3. 按应用内引导授予「完全磁盘访问权限」，否则无法统计和清理缓存。

需要 macOS 15 或更高版本。液态玻璃效果在 macOS 26 上呈现，更早的系统会回退到系统材质。
