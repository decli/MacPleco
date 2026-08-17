import Foundation
import AppKit

/// Which safety guard applies to a removal.
///
/// The three callers have genuinely different reach, and encoding that as a
/// policy rather than a set of flags keeps it impossible for the automated
/// sweep to acquire the uninstaller's or the space map's privileges by
/// accident.
public enum RemovalPolicy: Sendable {
    /// Automated cleaning. The narrow cache allowlist, and nothing else.
    case sweep
    /// The uninstaller, which additionally reaches application bundles.
    case uninstall
    /// A path the user located and picked by hand in the space map.
    case userSelected

    public func permits(_ url: URL) -> Bool {
        switch self {
        case .sweep:
            return SafePath.isRemovable(url)
        case .uninstall:
            return SafePath.isRemovable(url) || SafePath.isRemovableAppBundle(url)
        case .userSelected:
            return SafePath.isUserDeletable(url)
        }
    }
}

/// Removal, and the record of what was removed.
public enum Removal {

    public struct Outcome: Sendable {
        public var removed: [URL] = []
        public var refused: [URL] = []
        public var failed: [URL] = []
        public var bytes: Int64 = 0

        public var isCompleteSuccess: Bool { refused.isEmpty && failed.isEmpty }
    }

    /// Moves paths to the Trash.
    ///
    /// This is the app's default and the reason it can be handed to someone
    /// non-technical: the Finder keeps a Put Back entry for every item, so a
    /// wrong selection costs a trip to the Trash rather than a restore from
    /// backup.
    @MainActor
    public static func trash(
        _ urls: [URL],
        sizes: [URL: Int64] = [:],
        policy: RemovalPolicy = .sweep
    ) async -> Outcome {
        var outcome = Outcome()

        let permitted = urls.filter { url in
            if policy.permits(url) { return true }
            outcome.refused.append(url)
            return false
        }
        guard !permitted.isEmpty else { return outcome }

        let recycled: [URL: URL] = await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle(permitted) { newURLs, _ in
                continuation.resume(returning: newURLs)
            }
        }

        for url in permitted {
            if recycled[url] != nil {
                outcome.removed.append(url)
                outcome.bytes += sizes[url] ?? 0
            } else {
                outcome.failed.append(url)
            }
        }
        return outcome
    }

    /// Deletes paths outright. Only ever reached through an explicit opt-in.
    public static func deletePermanently(_ urls: [URL], sizes: [URL: Int64] = [:]) -> Outcome {
        var outcome = Outcome()
        let fm = FileManager()

        for url in urls {
            guard SafePath.isRemovable(url) else {
                outcome.refused.append(url)
                continue
            }
            do {
                try fm.removeItem(at: url)
                outcome.removed.append(url)
                outcome.bytes += sizes[url] ?? 0
            } catch {
                outcome.failed.append(url)
            }
        }
        return outcome
    }

    /// Reveals a path in the Finder — the escape hatch offered next to anything
    /// the user might want to inspect before agreeing to remove it.
    @MainActor
    public static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
