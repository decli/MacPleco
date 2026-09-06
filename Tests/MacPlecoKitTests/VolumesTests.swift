import XCTest
@testable import MacPlecoKit

/// Time Machine local snapshots are why a folder walk can never add up to the
/// used space. The count comes from `tmutil`, so the parsing is checked here
/// rather than on whichever Mac happens to have snapshots today.
final class VolumesTests: XCTestCase {

    func testNoOutputCountsZero() {
        XCTAssertEqual(StorageModel.countSnapshotLines(""), 0)
    }

    /// The header wording has changed between macOS releases, so the parser
    /// matches the reverse-DNS prefix rather than counting "every line but
    /// the first".
    func testHeaderAloneCountsZero() {
        XCTAssertEqual(StorageModel.countSnapshotLines("Snapshots for disk /:\n"), 0)
        XCTAssertEqual(
            StorageModel.countSnapshotLines("Snapshots for volume group containing disk /:\n"),
            0
        )
    }

    func testCountsSnapshotLines() {
        let output = """
        Snapshots for disk /:
        com.apple.TimeMachine.2026-09-05-013000.local
        com.apple.TimeMachine.2026-09-06-013000.local
        com.apple.TimeMachine.2026-09-07-013000.local
        """
        XCTAssertEqual(StorageModel.countSnapshotLines(output), 3)
    }

    func testToleratesMissingTrailingNewlineAndBlankLines() {
        XCTAssertEqual(
            StorageModel.countSnapshotLines(
                "Snapshots for disk /:\ncom.apple.TimeMachine.2026-09-07-013000.local"
            ),
            1
        )
        XCTAssertEqual(
            StorageModel.countSnapshotLines(
                "Snapshots for disk /:\n\ncom.apple.TimeMachine.2026-09-07-013000.local\n\n"
            ),
            1
        )
    }

    func testIgnoresUnrelatedLines() {
        XCTAssertEqual(
            StorageModel.countSnapshotLines("Snapshots for disk /:\nsomething else entirely\n"),
            0
        )
    }
}
