MacPleco
========

安装 / Install
--------------
把 MacPleco 拖到 Applications 文件夹即可。
Drag MacPleco into the Applications folder.


第一次打开 / First launch
-------------------------
MacPleco 是免费开源软件，没有购买 Apple 开发者证书（每年 $99），
所以 macOS 会提示「无法打开，因为无法验证开发者」。这是正常的。

打开方法：
  1. 双击 MacPleco，看到提示后点「完成」。
  2. 打开「系统设置」→「隐私与安全性」。
  3. 滑到底部，点击「仍要打开」。

或者在「终端」里执行一次：
  xattr -dr com.apple.quarantine /Applications/MacPleco.app

---

MacPleco is free and open source and is not signed with a paid Apple
Developer ID, so macOS will say the developer cannot be verified.
That is expected.

To open it:
  1. Double-click MacPleco, then dismiss the warning.
  2. Open System Settings > Privacy & Security.
  3. Scroll to the bottom and click "Open Anyway".

Or run this once in Terminal:
  xattr -dr com.apple.quarantine /Applications/MacPleco.app


完全磁盘访问权限 / Full Disk Access
-----------------------------------
要统计和清理缓存，MacPleco 需要「完全磁盘访问权限」。
App 内会引导你开启，也可以手动设置：
「系统设置」→「隐私与安全性」→「完全磁盘访问权限」→ 添加 MacPleco。

To measure and clear caches, MacPleco needs Full Disk Access. The app will
walk you through it, or set it manually in System Settings > Privacy &
Security > Full Disk Access.


源码与问题反馈 / Source and issues
----------------------------------
https://github.com/decli/MacPleco

MacPleco is licensed under the GNU General Public License v3.0.
Inspired by Mole (https://github.com/tw93/Mole).
