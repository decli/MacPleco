import XCTest
@testable import MacPlecoKit

/// The guard that stands between a bad rule and a bad delete. If any of these
/// ever go red, the app is not safe to ship.
final class SafePathTests: XCTestCase {

    private var home: String { NSHomeDirectory() }

    private func url(_ path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    // MARK: - Things that must never be removable

    func testSystemRootsAreRefused() {
        for path in ["/", "/System", "/Library", "/usr", "/bin", "/etc", "/var", "/Applications", "/Users"] {
            XCTAssertFalse(
                SafePath.isRemovable(url(path)),
                "\(path) must never be removable"
            )
        }
    }

    func testHomeAndItsTopLevelFoldersAreRefused() {
        for path in [
            home,
            "\(home)/Library",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Music",
            "\(home)/Movies"
        ] {
            XCTAssertFalse(
                SafePath.isRemovable(url(path)),
                "\(path) must never be removable"
            )
        }
    }

    func testAllowedRootsAreThemselvesRefused() {
        // We clear things *inside* ~/Library/Caches, never the folder itself.
        for root in SafePath.allowedRoots {
            XCTAssertFalse(
                SafePath.isRemovable(url(root)),
                "\(root) is a scan root and must not be removable"
            )
        }
    }

    func testIrreplaceableDataIsRefusedEvenInsideAnAllowedRoot() {
        for path in [
            "\(home)/Library/Application Support/MobileSync/Backup",
            "\(home)/Library/Keychains/login.keychain-db",
            "\(home)/Library/Application Support/AddressBook/Contacts.abbdb"
        ] {
            XCTAssertFalse(
                SafePath.isRemovable(url(path)),
                "\(path) must never be removable"
            )
        }
    }

    /// Regression: protected locations were once matched by exact path only, so
    /// listing `~/Library/Application Support/AddressBook` guarded the folder
    /// while leaving the contacts database inside it removable. Protection has
    /// to cover the subtree.
    func testProtectingAFolderAlsoProtectsWhatIsInsideIt() {
        for path in [
            "\(home)/Library/Application Support/AddressBook/Contacts.abbdb",
            "\(home)/Library/Application Support/MobileSync/Backup/0001/Info.plist",
            "\(home)/Library/Application Support/iCloud/Accounts/account.plist",
            "\(home)/Library/Mobile Documents/com~apple~CloudDocs/thesis.pdf",
            "\(home)/Library/Keychains/login.keychain-db",
            "\(home)/Library/Mail/V10/inbox.mbox",
            "\(home)/.ssh/id_ed25519"
        ] {
            XCTAssertFalse(
                SafePath.isRemovable(url(path)),
                "sweep must not reach \(path)"
            )
            XCTAssertFalse(
                SafePath.isUserDeletable(url(path)),
                "even a hand-picked removal must not reach \(path)"
            )
        }
    }

    /// The counterpart: pinning a directory must not sterilise everything in
    /// it, or the app would be unable to clear a single cache.
    func testPinningAFolderLeavesItsContentsRemovable() {
        XCTAssertTrue(SafePath.isRemovable(url("\(home)/Library/Caches/com.example.App")))
        XCTAssertTrue(SafePath.isUserDeletable(url("\(home)/Documents/old-export.zip")))
        XCTAssertTrue(SafePath.isUserDeletable(url("\(home)/Desktop/screenshot.png")))
    }

    func testPathsOutsideEveryAllowedRootAreRefused() {
        for path in [
            "\(home)/Projects/important",
            "\(home)/Documents/taxes.pdf",
            "/opt/homebrew/bin/brew",
            "/tmp/scratch"
        ] {
            XCTAssertFalse(
                SafePath.isRemovable(url(path)),
                "\(path) is outside the allowlist and must be refused"
            )
        }
    }

    func testTraversalCannotEscapeAnAllowedRoot() {
        XCTAssertFalse(
            SafePath.isRemovable(url("\(home)/Library/Caches/../../Documents")),
            "`..` must not be a way out of the allowlist"
        )
    }

    // MARK: - Things that must be removable

    func testCacheContentsAreRemovable() {
        for path in [
            "\(home)/Library/Caches/com.example.App",
            "\(home)/Library/Logs/SomeApp/today.log",
            "\(home)/Library/Saved Application State/com.example.App.savedState",
            "\(home)/.Trash/old-file.zip",
            "\(home)/.npm/_cacache"
        ] {
            XCTAssertTrue(
                SafePath.isRemovable(url(path)),
                "\(path) should be removable"
            )
        }
    }

    // MARK: - App bundles

    func testAppBundlePolicyAcceptsOnlyRealApplications() {
        XCTAssertTrue(SafePath.isRemovableAppBundle(url("/Applications/Example.app")))
        XCTAssertTrue(SafePath.isRemovableAppBundle(url("\(home)/Applications/Example.app")))

        XCTAssertFalse(SafePath.isRemovableAppBundle(url("/System/Applications/Mail.app")))
        XCTAssertFalse(SafePath.isRemovableAppBundle(url("/Applications")))
        XCTAssertFalse(SafePath.isRemovableAppBundle(url("/Applications/NotAnApp.txt")))
        XCTAssertFalse(SafePath.isRemovableAppBundle(url("\(home)/Documents/Example.app")))
    }

    func testCleaningPolicyCannotReachApplications() {
        // The sweep must not acquire the uninstaller's reach.
        XCTAssertFalse(RemovalPolicy.sweep.permits(url("/Applications/Example.app")))
        XCTAssertTrue(RemovalPolicy.uninstall.permits(url("/Applications/Example.app")))
    }

    // MARK: - User-selected policy

    func testUserSelectedPolicyReachesPersonalFilesButNotSystemOnes() {
        XCTAssertTrue(SafePath.isUserDeletable(url("\(home)/Movies/holiday/clip.mov")))
        XCTAssertTrue(SafePath.isUserDeletable(url("\(home)/Downloads/big.iso")))

        XCTAssertFalse(SafePath.isUserDeletable(url(home)))
        XCTAssertFalse(SafePath.isUserDeletable(url("\(home)/Documents")))
        XCTAssertFalse(SafePath.isUserDeletable(url("/Library/Preferences")))
        XCTAssertFalse(SafePath.isUserDeletable(url("/System/Library")))
    }

    func testSweepPolicyIsNarrowerThanUserSelected() {
        // A file the user can point at in the space map is not automatically
        // something an automated sweep may touch.
        let personal = url("\(home)/Movies/holiday/clip.mov")
        XCTAssertTrue(SafePath.isUserDeletable(personal))
        XCTAssertFalse(SafePath.isRemovable(personal))
    }

    // MARK: - Catalog blocks

    func testModelWeightsAreNeverOffered() {
        for path in [
            "\(home)/.ollama/models/blobs/sha256-abc",
            "\(home)/Library/Caches/whatever/llama-7b.gguf",
            "\(home)/Library/Caches/x/model.safetensors"
        ] {
            XCTAssertTrue(
                CleanCatalog.isBlocked(url(path)),
                "\(path) holds model weights and must never be offered"
            )
        }
    }

    func testOrdinaryCachesAreNotBlocked() {
        XCTAssertFalse(CleanCatalog.isBlocked(url("\(home)/Library/Caches/com.example.App")))
    }

    func testModelDownloadsUnderDotCacheAreNeverOffered() {
        // The weight heuristic only sees the path a rule matched, and these are
        // matched at their top level, so blocking has to name them.
        for path in [
            "\(home)/.cache/huggingface",
            "\(home)/.cache/huggingface/hub/models--meta-llama",
            "\(home)/.cache/torch",
            "\(home)/.cache/lm-studio"
        ] {
            XCTAssertTrue(
                CleanCatalog.isBlocked(url(path)),
                "\(path) holds model downloads and must never be offered"
            )
        }
    }

    func testPoetryIsOfferedByCacheButNeverWhole() {
        // Removal takes the whole matched directory, so offering ~/.cache/pypoetry
        // would take the virtual environments with it.
        XCTAssertTrue(CleanCatalog.isBlocked(url("\(home)/.cache/pypoetry")))
        XCTAssertFalse(CleanCatalog.isBlocked(url("\(home)/.cache/pypoetry/artifacts")))
        XCTAssertFalse(CleanCatalog.isBlocked(url("\(home)/.cache/pypoetry/cache")))
    }

    // MARK: - Catalog rules

    /// What the scanner does: expand in order, keep the first rule to reach a
    /// path. `pattern` matches a path of the same depth, `*` matching any one
    /// component.
    private func rule(claiming path: String) -> CleanRule? {
        CleanCatalog.rules.first { rule in
            let pattern = NSString(string: rule.pattern).expandingTildeInPath
                .split(separator: "/")
            let components = path.split(separator: "/")
            guard pattern.count == components.count else { return false }
            return !zip(pattern, components).contains { $0 != "*" && $0 != $1 }
        }
    }

    private func handling(_ path: String) -> (safety: Safety, selected: Bool)? {
        guard let rule = rule(claiming: path) else { return nil }
        let policy = CleanCatalog.policy(for: rule.category)
        return (rule.safety ?? policy.safety, rule.selectedByDefault ?? policy.selected)
    }

    func testNoRuleIsShadowedByAnEarlierOne() {
        // A rule written after a sweep that covers it can never fire: the
        // scanner has already claimed every path it would match, so its
        // category, label and safety are silently lost.
        let patterns = CleanCatalog.rules.map {
            NSString(string: $0.pattern).expandingTildeInPath.split(separator: "/").map(String.init)
        }
        for (index, mine) in patterns.enumerated() {
            for earlier in patterns[0..<index] {
                guard earlier.count == mine.count else { continue }
                let covered = !zip(earlier, mine).contains { $0 != $1 && $0 != "*" }
                XCTAssertFalse(
                    covered,
                    "\(CleanCatalog.rules[index].pattern) can never fire: "
                        + "\(earlier.joined(separator: "/")) claims every path it matches"
                )
            }
        }
    }

    func testUnknownDotCacheEntriesAreOfferedForReviewOnly() {
        // ~/.cache is a shared drawer, not one tool's cache: whatever the sweep
        // finds there has not been vouched for by name.
        let handling = handling("\(home)/.cache/some-unknown-tool")
        XCTAssertEqual(handling?.safety, .review)
        XCTAssertEqual(handling?.selected, false)
    }

    func testNamedDotCacheEntriesAreSafeToRemove() {
        for path in ["pip", "uv", "go-build", "pre-commit"] {
            let handling = handling("\(home)/.cache/\(path)")
            XCTAssertEqual(handling?.safety, .safe, "~/.cache/\(path) is a rebuildable cache")
            XCTAssertEqual(handling?.selected, true)
        }
    }

    func testBrowserDownloadsAreTreatedTheSameInEitherCacheLocation() {
        // Same browsers, same slow re-download, whichever directory the tool
        // happened to put them in.
        for path in ["\(home)/.cache/ms-playwright", "\(home)/Library/Caches/ms-playwright"] {
            XCTAssertEqual(handling(path)?.safety, .review, path)
            XCTAssertEqual(handling(path)?.selected, false, path)
        }
    }

    /// Naming a store must match on a path boundary, not a string prefix.
    /// `hasPrefix` on the bare path would swallow `~/.cachehuggingface` and
    /// `~/.cache/huggingface-notes` along with the store itself.
    func testNamedStoresMatchOnAPathBoundary() {
        for path in [
            "\(home)/.cache/huggingface-notes",
            "\(home)/.cachehuggingface",
            "\(home)/.cache/torch-utils",
            "\(home)/.cache/pypoetry-old"
        ] {
            XCTAssertFalse(
                CleanCatalog.isBlocked(url(path)),
                "\(path) is not the store it resembles and must stay offerable"
            )
        }
    }
}
