import Foundation
import AppKit
import Observation

/// Full Disk Access detection and the path to granting it.
///
/// macOS offers no API to ask whether an app holds Full Disk Access, so the
/// check is a read against a location only a permitted app can open. The
/// probe is deliberately biased toward assuming access: nagging a user who has
/// already granted it is worse than showing a prompt one launch late.
@Observable
@MainActor
public final class PermissionsModel {
    public private(set) var hasFullDiskAccess = true

    public init() {}

    /// The probe opens a file the sandbox may block; do that off the main
    /// thread and land the answer back here.
    public func refresh() {
        Task.detached(priority: .userInitiated) {
            let granted = Self.probe()
            await MainActor.run { [weak self] in
                self?.hasFullDiskAccess = granted
            }
        }
    }

    nonisolated static func probe() -> Bool {
        let home = NSHomeDirectory()
        let probes = [
            "\(home)/Library/Application Support/com.apple.TCC/TCC.db",
            "/Library/Application Support/com.apple.TCC/TCC.db"
        ]

        var sawProbeFile = false
        for path in probes where FileManager.default.fileExists(atPath: path) {
            sawProbeFile = true
            if let handle = FileHandle(forReadingAtPath: path) {
                try? handle.close()
                return true
            }
        }

        // If neither probe file exists we cannot tell, so assume access rather
        // than block the user behind a prompt they cannot satisfy.
        return !sawProbeFile
    }

    /// Opens the exact pane rather than the top of System Settings — the
    /// difference between a request a user completes and one they abandon.
    public func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
