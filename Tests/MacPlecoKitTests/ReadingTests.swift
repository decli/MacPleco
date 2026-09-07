import XCTest
@testable import MacPlecoKit

/// A reading is a quantity and the unit it is measured in, set apart from one
/// another. The risk in doing that automatically is over-eagerness: not every
/// value with a space in it is a measurement, and demoting the wrong half of
/// one reads as a typesetting error.
final class ReadingTests: XCTestCase {

    func testSizesSplitIntoQuantityAndUnit() {
        XCTAssertEqual(Reading.parts("1.53 TB").value, "1.53")
        XCTAssertEqual(Reading.parts("1.53 TB").unit, "TB")
        XCTAssertEqual(Reading.parts("999 B").unit, "B")
        XCTAssertEqual(Reading.parts("124 GB").unit, "GB")
    }

    func testRatesKeepTheirWholeUnit() {
        XCTAssertEqual(Reading.parts("3.38 KB/s").value, "3.38")
        XCTAssertEqual(Reading.parts("3.38 KB/s").unit, "KB/s")
    }

    func testNonMeasurementsAreLeftWhole() {
        // A chip name and a duration both contain spaces and neither has a
        // unit to demote. Splitting them would set "Max" and "小时 3 分" as
        // captions beside a 24pt number.
        XCTAssertEqual(Reading.parts("M5 Max").value, "M5 Max")
        XCTAssertEqual(Reading.parts("M5 Max").unit, "")
        XCTAssertEqual(Reading.parts("5 小时 3 分").value, "5 小时 3 分")
        XCTAssertEqual(Reading.parts("5 小时 3 分").unit, "")
        XCTAssertEqual(Reading.parts("macOS 26.5.2").unit, "")
    }

    func testValuesWithoutASpaceAreLeftWhole() {
        XCTAssertEqual(Reading.parts("63").value, "63")
        XCTAssertEqual(Reading.parts("63").unit, "")
        // A percentage is one token; there is nothing to set apart.
        XCTAssertEqual(Reading.parts("8%").value, "8%")
        XCTAssertEqual(Reading.parts("8%").unit, "")
    }

    func testEveryUnitBytesCanEmitIsRecognised() {
        for value in [Int64(0), 999, 1_000, 1_500_000, 2_000_000_000, 4_000_000_000_000] {
            let formatted = Bytes.format(value)
            XCTAssertFalse(
                Reading.parts(formatted).unit.isEmpty,
                "Bytes.format produced \(formatted), which Reading does not recognise as a measurement"
            )
        }
    }
}
