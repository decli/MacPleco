import Foundation
import AppKit

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
        allowAppBundles: Bool = false
    ) async -> Outcome {
        var outcome = Outcome()

        let permitted = urls.filter { url in
            if SafePath.isRemovable(url) { return true }
            if allowAppBundles, SafePath.isRemovableAppBundle(url) { return true }
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
