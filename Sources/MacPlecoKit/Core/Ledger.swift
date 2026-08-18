import Foundation
import Observation

public struct CleanRecord: Codable, Identifiable, Sendable, Equatable {
    public var id: Date { date }
    public let date: Date
    public let bytes: Int64
    public let items: Int

    public init(date: Date, bytes: Int64, items: Int) {
        self.date = date
        self.bytes = bytes
        self.items = items
    }
}

/// The running record of what MacPleco has done for this Mac.
///
/// A cleaner's work is invisible thirty seconds after it finishes; the ledger
/// is what turns that into something felt — "MacPleco has freed 84 GB for you
/// since March" is the sentence that makes the app worth keeping around.
@Observable
@MainActor
public final class LedgerModel {
    public private(set) var records: [CleanRecord] = []

    private let defaultsKey: String
    private let defaults: UserDefaults
    private static let cap = 200

    public init(defaults: UserDefaults = .standard, key: String = "com.macpleco.ledger") {
        self.defaults = defaults
        self.defaultsKey = key
        load()
    }

    public var totalBytes: Int64 { records.reduce(0) { $0 + $1.bytes } }
    public var totalRuns: Int { records.count }
    public var lastRecord: CleanRecord? { records.last }

    public func add(bytes: Int64, items: Int) {
        guard bytes > 0 || items > 0 else { return }
        records.append(CleanRecord(date: Date(), bytes: bytes, items: items))
        if records.count > Self.cap {
            records.removeFirst(records.count - Self.cap)
        }
        save()
    }

    public func reset() {
        records = []
        defaults.removeObject(forKey: defaultsKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([CleanRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
