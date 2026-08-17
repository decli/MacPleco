import Foundation

/// A launch agent or daemon that starts something automatically.
public struct LoginItem: Identifiable, Sendable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let label: String
    public let program: String
    /// User agents live in the home folder and can be removed without
    /// authorisation; system ones are shown for information only.
    public let isUserScope: Bool
    public let runsAtLoad: Bool

    public var displayName: String {
        // Labels are reverse-DNS by convention, and the tail is usually the
        // most recognisable part.
        let tail = label.split(separator: ".").last.map(String.init) ?? label
        return tail.isEmpty ? label : tail
    }

    public var displayPath: String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

public enum LoginItems {

    private static var searchRoots: [(path: String, userScope: Bool)] {
        [
            ("\(NSHomeDirectory())/Library/LaunchAgents", true),
            ("/Library/LaunchAgents", false),
            ("/Library/LaunchDaemons", false)
        ]
    }

    public static func load() async -> [LoginItem] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager()
            var results: [LoginItem] = []

            for root in searchRoots {
                guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
                for name in names where name.hasSuffix(".plist") {
                    let url = URL(fileURLWithPath: "\(root.path)/\(name)")
                    guard let data = try? Data(contentsOf: url),
                          let plist = try? PropertyListSerialization.propertyList(
                            from: data, options: [], format: nil
                          ) as? [String: Any]
                    else { continue }

                    let label = (plist["Label"] as? String)
                        ?? url.deletingPathExtension().lastPathComponent

                    var program = plist["Program"] as? String ?? ""
                    if program.isEmpty, let arguments = plist["ProgramArguments"] as? [String] {
                        program = arguments.first ?? ""
                    }

                    results.append(
                        LoginItem(
                            url: url,
                            label: label,
                            program: program,
                            isUserScope: root.userScope,
                            runsAtLoad: (plist["RunAtLoad"] as? Bool) ?? false
                        )
                    )
                }
            }

            return results.sorted { lhs, rhs in
                if lhs.isUserScope != rhs.isUserScope { return lhs.isUserScope }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
        }.value
    }

    @MainActor
    public static func remove(_ item: LoginItem) async -> Bool {
        guard item.isUserScope else { return false }
        let outcome = await Removal.trash([item.url])
        return outcome.removed.contains(item.url)
    }
}
