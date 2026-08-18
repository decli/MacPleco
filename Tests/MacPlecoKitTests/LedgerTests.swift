import XCTest
@testable import MacPlecoKit

@MainActor
final class LedgerTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let name = "ledger-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testRecordsAccumulateAndPersist() {
        let defaults = makeDefaults()
        let ledger = LedgerModel(defaults: defaults, key: "test.ledger")

        ledger.add(bytes: 1_000, items: 3)
        ledger.add(bytes: 2_000, items: 2)

        XCTAssertEqual(ledger.totalBytes, 3_000)
        XCTAssertEqual(ledger.totalRuns, 2)

        // A second instance reading the same store sees the same history.
        let reloaded = LedgerModel(defaults: defaults, key: "test.ledger")
        XCTAssertEqual(reloaded.totalBytes, 3_000)
        XCTAssertEqual(reloaded.totalRuns, 2)
    }

    func testEmptyRunsAreNotRecorded() {
        let ledger = LedgerModel(defaults: makeDefaults(), key: "test.ledger")
        ledger.add(bytes: 0, items: 0)
        XCTAssertEqual(ledger.totalRuns, 0)
    }

    func testResetClearsEverything() {
        let defaults = makeDefaults()
        let ledger = LedgerModel(defaults: defaults, key: "test.ledger")
        ledger.add(bytes: 500, items: 1)
        ledger.reset()
        XCTAssertEqual(ledger.totalRuns, 0)
        XCTAssertEqual(LedgerModel(defaults: defaults, key: "test.ledger").totalRuns, 0)
    }
}
