<div align="center">
  <h1>MacPleco</h1>
  <p><strong>A calm, native Mac cleaner built on Liquid Glass.</strong></p>
  <p>
    <a href="README.md"><strong>English</strong></a> ·
    <a href="README.zh-CN.md">简体中文</a>
  </p>
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

## Why another cleaner

Most Mac cleaners are built to alarm you. They colour everything red, count
your “problems”, and make the destructive button the obvious one. MacPleco is
built on the opposite instinct.

| Principle | What it means |
|---|---|
| **Reversible by default** | Everything goes to the Trash, so a wrong tick costs a trip to the Trash, not a restore from backup. Permanent deletion is a separate, deliberate switch that resets after every run. |
| **Plain language, exact paths** | Rows say “Chrome browser cache”, not just `~/Library/Caches/com.google.Chrome`, while still showing the absolute path and a Finder button before you select anything. |
| **Risky things stay unchecked** | Chat app caches may hold photos and videos that cannot be downloaded again, so MacPleco never selects them for you. The same applies to Xcode archives, Maven repositories, model weights, and data held open by a running app. |
| **Honest numbers** | Storage sizes are decimal, matching Finder. Finding nothing to clean is good news, not an empty failure state. Unsupported metrics are shown as unavailable rather than estimated. |
| **No admin password** | Cleaning stays inside your own account. The small amount of extra system space is not worth broad privileges or private APIs. |

## What's inside

**Overview** — One screen with the whole picture: how full the disk is, how much
MacPleco can give back, and one button. A non-technical user can stop here and
still have done the right thing.

**Clean** — Caches, logs, browser data, developer build output, AI tool caches,
cloud-sync caches, window state, uninstalled-app leftovers, old installers and
the Trash. Apps holding a cache open are surfaced with the bytes they occupy.
Every item shows its full path and can be revealed in Finder from its row or
context menu before it is selected.

**Apps** — Every installed app with its size and last-opened date. Uninstalling
first shows the complete plan: the bundle plus every preference, container and
cache it left elsewhere, each sized and individually declinable. Tick several
apps and the batch keeps the same promise — one sheet listing every bundle and
every leftover, any of which can still be unticked before the single
confirmation. Login items are included too, sortable by name, by scope, or by
which of them actually run at login.

**Space** — A full-width squarified map with legible adaptive labels, hover-
linked ranking cards, breadcrumbs and long-tail consolidation. Drill into a
folder with one click. Folders are measured with `getattrlistbulk` and a
work-stealing pool, so the machine attacks the one enormous folder together
instead of leaving it to a single thread: a 417 GB home folder goes from 17.9s
to 3.1s, reporting the same total. The large-file view lists files over 100 MB
with their absolute paths, an always-visible Finder button, path copying and a
reversible Move to Trash action.

**Tune-Up** — Eight repairs for specific symptoms: a broken Open With menu,
blank preview thumbnails, tofu boxes instead of text, stale DNS, white page
icons, `.DS_Store` files on shared drives, off-screen windows and a stuck
Finder. Every one has a visible Run button of its own, and several can be ticked
and run together. Nothing is pre-selected.

**Monitor** — Live vitals in four equal cards: CPU split into app versus system
time, memory split into app, wired and compressed, whole-device GPU load, and
network split into download and upload. Every one of those is two or three
quantities, so each gets its own colour and a legend rather than a single
anonymous line. The process table can be searched by name, path or pid, filtered
to apps or system processes, and sorted by name, memory, start time or CPU in
either direction. Any row can be revealed in the Finder or asked to quit —
politely first, forcibly only if you say so. macOS exposes no per-process GPU
share to an unprivileged app, so that is reported for the device as a whole
instead of being faked per row. Sampling stops when you leave the section.

**Menu bar** — A small fish that answers “how full is my disk?” at a glance,
with live vitals and one click into cleaning.

## Install

Download the `.dmg` from [Releases](https://github.com/decli/MacPleco/releases/latest)
and drag MacPleco into Applications.

MacPleco is open source and is not signed with a paid Apple Developer ID, so
macOS will say the developer cannot be verified. Open **System Settings →
Privacy & Security**, scroll to the bottom and click **Open Anyway** — or run
this once:

```bash
xattr -dr com.apple.quarantine /Applications/MacPleco.app
```

Then grant **Full Disk Access** when the app asks. macOS keeps every app out of
other apps' cache folders by default, and MacPleco cannot measure them without
this permission.

Requires **macOS 15 or later**. Liquid Glass renders through Apple's system API
on macOS 26; earlier versions fall back to system materials.

## Safety

Removal is guarded in two independent places. The catalog declines to offer
certain paths, and `SafePath` refuses them again at the moment of deletion — so
a mistake in a rule cannot become a mistake on disk.

The three removal policies have genuinely different reach:

| Policy | Reach |
|---|---|
| `sweep` | Automated cleaning. A narrow allowlist of cache and log roots inside your home folder — nothing else. |
| `uninstall` | Adds application bundles in `/Applications`, and only those. |
| `userSelected` | A path you deliberately selected in the space map or large-file list. |

Model weights (`.gguf`, `.safetensors`, anything under a `models/` directory or
an Ollama blob store) are refused everywhere — they are enormous and slow to
fetch, and no cleaner should mistake them for junk.

Read [`SafePath.swift`](Sources/MacPlecoKit/Core/SafePath.swift) and its
[tests](Tests/MacPlecoKitTests/SafePathTests.swift) — that is the whole policy.

## Build

No Xcode project and no third-party dependencies.

```bash
git clone https://github.com/decli/MacPleco.git
cd MacPleco
swift test                          # run the safety tests
./scripts/build-app.sh 1.0.0        # -> dist/MacPleco.app (universal)
./scripts/make-dmg.sh 1.0.0         # -> dist/MacPleco-1.0.0.dmg
```

The app icon is generated by `scripts/make-icon.py` using only the Python
standard library.

## Credits

MacPleco is a from-scratch native app, but it stands on the domain knowledge of
[**Mole**](https://github.com/tw93/Mole) by [tw93](https://github.com/tw93) — an
excellent terminal-first Mac maintenance toolkit. If you live in a terminal,
use Mole.

## License

[GPL-3.0](LICENSE), the same license as Mole.
