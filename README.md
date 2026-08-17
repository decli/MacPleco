<div align="center">
  <h1>MacPleco</h1>
  <p><em>A calm, native Mac cleaner built on Liquid Glass.</em></p>
  <p><em>一款安静、原生、遵循液态玻璃设计的 Mac 清理工具。</em></p>
</div>

---

The pleco is the fish that quietly keeps an aquarium clear. MacPleco does the
same for a Mac: it finds what is safe to remove, explains it in plain language,
and puts things in the Trash rather than destroying them.

清道夫鱼安安静静地把鱼缸打理干净。MacPleco 对 Mac 做同样的事：找出可以安全删除的东西，
用人话解释清楚，然后放进废纸篓 —— 而不是直接销毁。

## Why another cleaner

Most Mac cleaners are built to alarm you. They colour everything red, count
your "problems", and make the destructive button the obvious one. MacPleco is
built on the opposite instinct:

- **Reversible by default.** Everything goes to the Trash. Permanent deletion
  is a deliberate, separate choice.
- **Plain language, paths on demand.** Rows say "Chrome browser cache", not
  `~/Library/Caches/com.google.Chrome`. The path is one click away when you
  want it.
- **Honest numbers.** Sizes match Finder. Nothing is inflated to look
  impressive, and finding nothing to clean is reported as good news.
- **Risky things stay unchecked.** Chat app caches hold photos and videos you
  may not be able to re-download, so MacPleco never selects them for you.

## Status

In active development. Built with SwiftUI against the macOS 26 SDK.

## Credits

MacPleco is a from-scratch native app, but it stands on the domain knowledge of
[Mole](https://github.com/tw93/Mole) by [tw93](https://github.com/tw93) — an
excellent terminal-first Mac maintenance toolkit. If you live in a terminal,
use Mole.

## License

[GPL-3.0](LICENSE), the same license as Mole.
