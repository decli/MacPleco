import Foundation

/// The last line of defence before anything is removed.
///
/// The scanner should never produce a dangerous path in the first place, but
/// rules are data and data drifts. Every removal in the app goes through
/// `isRemovable` regardless of how the path was obtained, so a mistake in a
/// rule cannot become a mistake on disk.
///
/// The policy is allowlist-first: a path must sit underneath a known-disposable
/// root, must not *be* one of those roots, and must not match a protected
/// location. Anything the policy has no opinion about is refused.
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
            "\(home)/Downloads",
            "\(home)/Library/Mobile Documents"
        ]
    }

    /// Locations that must survive even though they sit inside an allowed root.
    ///
    /// `~/Library/Application Support` is the sharp edge here: it holds both
    /// throwaway caches and irreplaceable user data, so the whole directory is
    /// an allowed root while its data-bearing children are pinned shut.
    public static var protectedPaths: Set<String> {
        let home = NSHomeDirectory()
        var paths: Set<String> = [
            "/",
            "/System",
            "/Library",
            "/Applications",
            "/usr",
            "/bin",
            "/sbin",
            "/etc",
            "/var",
            "/private",
            "/opt",
            "/Users",
            "/Volumes",
            home,
            "\(home)/Library",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Music",
            "\(home)/Movies",
            "\(home)/Public",
            "\(home)/Applications",
            "\(home)/Library/Keychains",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Library/Photos",
            "\(home)/Library/CloudStorage",
            "\(home)/Library/Safari",
            "\(home)/Library/Mobile Documents",
            "\(home)/Library/Application Support/MobileSync",
            "\(home)/Library/Application Support/AddressBook",
            "\(home)/Library/Application Support/CallHistoryDB",
            "\(home)/Library/Application Support/Knowledge",
            "\(home)/Library/Application Support/com.apple.sharedfilelist",
            "\(home)/Library/Application Support/Dock",
            "\(home)/Library/Application Support/iCloud",
            "\(home)/Library/Application Support/Ubiquity"
        ]
        // Every allowed root is also protected from being removed itself: we
        // clear things *inside* ~/Library/Caches, never the folder.
        for root in allowedRoots {
            paths.insert(root)
        }
        return paths
    }

    /// Directory names that must never be removed wherever they appear, because
    /// their contents cannot be regenerated.
    private static let forbiddenComponents: Set<String> = [
        "Keychains",
        "MobileSync",
        "Photos Library.photoslibrary",
        "Messages",
        "Mail Data"
    ]

    /// Decides whether `url` may be deleted or trashed.
    public static func isRemovable(_ url: URL) -> Bool {
        // `standardized` collapses "." and ".." without touching the disk;
        // resolving symlinks as well stops a link inside an allowed root from
        // pointing the deletion at, say, ~/Documents.
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        let path = resolved.path

        guard path.hasPrefix("/") else { return false }
        guard !path.hasSuffix("/") || path == "/" else {
            return isRemovable(URL(fileURLWithPath: String(path.dropLast())))
        }

        if protectedPaths.contains(path) { return false }

        let components = resolved.pathComponents.filter { $0 != "/" }
        // "/a/b" is the shallowest thing worth considering; anything shallower
        // is a system root by definition.
        guard components.count >= 3 else { return false }

        for component in components where forbiddenComponents.contains(component) {
            return false
        }

        // Must live strictly underneath an allowed root.
        let roots = allowedRoots.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
        return roots.contains { root in
            path.hasPrefix(root + "/")
        }
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
    /// external volume, minus the protected set. It is never used by an
    /// automated sweep, only by an explicit right-click.
    public static func isUserDeletable(_ url: URL) -> Bool {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        let path = resolved.path

        if protectedPaths.contains(path) { return false }

        let components = resolved.pathComponents.filter { $0 != "/" }
        guard components.count >= 3 else { return false }

        for component in components where forbiddenComponents.contains(component) {
            return false
        }

        let home = NSHomeDirectory()
        if path.hasPrefix(home + "/") { return true }
        if path.hasPrefix("/Volumes/") { return components.count >= 3 }
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
