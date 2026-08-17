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
}
