import Foundation

/// The last line of defence before anything is removed.
///
/// The scanner should never produce a dangerous path in the first place, but
/// rules are data and data drifts. Every removal in the app goes through this
/// file regardless of how the path was obtained, so a mistake in a rule cannot
/// become a mistake on disk.
///
/// Three lists do the work, and the distinction between them matters:
///
/// - `allowedRoots` — removal is permitted *underneath* these.
/// - `pinnedDirectories` — refused as exact matches, contents still removable.
///   `~/Library/Caches` belongs here: we clear things inside it, never it.
/// - `vaults` — refused along with everything beneath them, for every policy.
///   `~/Library/Application Support/AddressBook` belongs here: listing only the
///   folder would leave the contacts database inside it removable.
public enum SafePath {

    /// Roots underneath which removal is permitted.
    ///
    /// Deliberately confined to the user's own domain. Touching `/Library` or
    /// `/System` would require an authorised helper tool, and the space that
    /// buys is small next to the risk it carries.
    public static var allowedRoots: [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/Library/Caches",
            "\(home)/Library/Logs",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/Application Support",
            "\(home)/Library/Developer",
            "\(home)/Library/Application Scripts",
            "\(home)/Library/WebKit",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/Preferences",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Cookies",
            "\(home)/.Trash",
            "\(home)/.cache",
            "\(home)/.npm",
            "\(home)/.yarn",
            "\(home)/.pnpm-store",
            "\(home)/.cargo",
            "\(home)/.gradle",
            "\(home)/.m2",
            "\(home)/.cocoapods",
            "\(home)/.gem",
            "\(home)/.bundle",
            "\(home)/.docker",
            "\(home)/.electron",
            "\(home)/.nvm",
            "\(home)/.rustup",
            "\(home)/.pyenv",
            "\(home)/.conda",
            "\(home)/Downloads"
        ]
    }

    /// Refused along with everything inside them, under every policy.
    ///
    /// These hold data that cannot be regenerated and in several cases cannot
    /// even be re-downloaded: keychains, mail, messages, photo libraries,
    /// device backups, iCloud Drive, and credentials for other systems.
    public static var vaults: [String] {
        let home = NSHomeDirectory()
        return [
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/etc",
            "\(home)/Library/Keychains",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Library/Photos",
            "\(home)/Library/CloudStorage",
            "\(home)/Library/Mobile Documents",
            "\(home)/Library/Application Support/MobileSync",
            "\(home)/Library/Application Support/AddressBook",
            "\(home)/Library/Application Support/CallHistoryDB",
            "\(home)/Library/Application Support/CallHistoryTransactions",
            "\(home)/Library/Application Support/Knowledge",
            "\(home)/Library/Application Support/com.apple.sharedfilelist",
            "\(home)/Library/Application Support/Dock",
            "\(home)/Library/Application Support/iCloud",
            "\(home)/Library/Application Support/Ubiquity",
            "\(home)/Library/Application Support/FileProvider",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.kube",
            "\(home)/.config/gh"
        ]
    }

    /// Refused as exact matches only — their contents may still be removable.
    ///
    /// Every allowed root is pinned: we clear things *inside* `~/Library/Caches`
    /// and never the folder itself.
    public static var pinnedDirectories: Set<String> {
        let home = NSHomeDirectory()
        var pinned: Set<String> = [
            "/",
            "/Users",
            "/Volumes",
            "/Applications",
            "/Library",
            "/opt",
            "/var",
            "/private",
            home,
            "\(home)/Library",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Music",
            "\(home)/Movies",
            "\(home)/Public",
            "\(home)/Applications"
        ]
        for root in allowedRoots {
            pinned.insert(root)
        }
        return pinned
    }

    /// Directory names that must never be removed wherever they appear.
    /// Redundant with `vaults` for the common locations, and deliberately so —
    /// these also catch the same data sitting somewhere unexpected.
    private static let forbiddenComponents: Set<String> = [
        "Keychains",
        "MobileSync",
        "Photos Library.photoslibrary",
        "Messages",
        "Mail Data"
    ]

    private static func isInsideVault(_ path: String) -> Bool {
        vaults.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    /// Shared checks: standardises the path and applies the rules that hold
    /// under every policy.
    private static func vet(_ url: URL) -> String? {
        // `standardized` collapses "." and ".." without touching the disk;
        // resolving symlinks as well stops a link inside an allowed root from
        // pointing the deletion at, say, ~/Documents.
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        var path = resolved.path

        guard path.hasPrefix("/") else { return nil }
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }

        if pinnedDirectories.contains(path) { return nil }
        if isInsideVault(path) { return nil }

        let components = resolved.pathComponents.filter { $0 != "/" }
        // "/a/b/c" is the shallowest thing worth considering; anything
        // shallower is a system or home root by definition.
        guard components.count >= 3 else { return nil }

        for component in components where forbiddenComponents.contains(component) {
            return nil
        }

        return path
    }

    /// Decides whether `url` may be cleared by an automated sweep.
    public static func isRemovable(_ url: URL) -> Bool {
        guard let path = vet(url) else { return false }

        // Must live strictly underneath an allowed root.
        let roots = allowedRoots.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
        return roots.contains { path.hasPrefix($0 + "/") }
    }

    /// Filters a batch, dropping anything the policy refuses.
    public static func removable(_ urls: [URL]) -> [URL] {
        urls.filter(isRemovable)
    }

    /// The space map explores the whole home folder, so the narrow cleaning
    /// allowlist would refuse almost everything a user finds there — including
    /// the 40 GB of old video they went looking for.
    ///
    /// This is the policy for things the user has personally located and
    /// selected: anything of their own, anywhere under the home folder or an
    /// external volume, minus the vaults and the pinned directories. It is
    /// never used by an automated sweep, only by an explicit right-click.
    public static func isUserDeletable(_ url: URL) -> Bool {
        guard let path = vet(url) else { return false }

        let home = NSHomeDirectory()
        if path.hasPrefix(home + "/") { return true }
        if path.hasPrefix("/Volumes/") {
            // /Volumes/<disk>/<something> — never the volume itself.
            return path.split(separator: "/").count >= 3
        }
        return false
    }

    /// Application bundles sit outside `allowedRoots` on purpose — nothing in
    /// the cleaning path should ever be able to reach `/Applications`. The
    /// uninstaller opts in through this separate, narrower check.
    public static func isRemovableAppBundle(_ url: URL) -> Bool {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        let path = resolved.path

        guard path.hasSuffix(".app") else { return false }

        // System applications are managed by macOS and are not the user's to
        // remove; attempting it fails noisily on a sealed volume anyway.
        guard !path.hasPrefix("/System/") else { return false }

        // Never offer to uninstall the running copy of MacPleco.
        let ownBundle = Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path
        guard path != ownBundle else { return false }

        let home = NSHomeDirectory()
        let roots = ["/Applications", "\(home)/Applications"]
        return roots.contains { path.hasPrefix($0 + "/") }
    }
}
