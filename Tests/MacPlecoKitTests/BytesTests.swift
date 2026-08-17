import XCTest
@testable import MacPlecoKit

final class BytesTests: XCTestCase {

    func testBytesBelowOneKilobyteStayWhole() {
        XCTAssertEqual(Bytes.format(Int64(0)), "0 B")
        XCTAssertEqual(Bytes.format(Int64(1)), "1 B")
        XCTAssertEqual(Bytes.format(Int64(999)), "999 B")
    }

    func testDecimalUnitsMatchFinder() {
        // Finder counts 1 KB as 1000 bytes; a cleaner that disagreed with it
        // would look broken to the user regardless of which is more correct.
        XCTAssertEqual(Bytes.format(Int64(1_000)), "1.00 KB")
        XCTAssertEqual(Bytes.format(Int64(1_000_000)), "1.00 MB")
        XCTAssertEqual(Bytes.format(Int64(1_000_000_000)), "1.00 GB")
    }

    func testThreeSignificantDigits() {
        XCTAssertEqual(Bytes.format(Int64(4_610_000_000)), "4.61 GB")
        XCTAssertEqual(Bytes.format(Int64(21_500_000)), "21.5 MB")
        XCTAssertEqual(Bytes.format(Int64(275_000_000)), "275 MB")
        XCTAssertEqual(Bytes.format(Int64(152_000)), "152 KB")
    }

    func testNegativeValuesKeepTheirSign() {
        XCTAssertEqual(Bytes.format(Int64(-2_000_000)), "-2.00 MB")
    }

    func testSplitSeparatesNumberFromUnit() {
        let parts = Bytes.split(Int64(4_610_000_000))
        XCTAssertEqual(parts.number, "4.61")
        XCTAssertEqual(parts.unit, "GB")
    }

    func testSplitHandlesBareByteCounts() {
        let parts = Bytes.split(Int64(512))
        XCTAssertEqual(parts.number, "512")
        XCTAssertEqual(parts.unit, "B")
    }
}
