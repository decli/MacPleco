import XCTest
@testable import MacPlecoKit

/// What a clean run will actually touch.
///
/// `blockedBy` is decided during the scan, and a scan can be minutes old — so
/// the check that matters is the one made when the button is pressed. These
/// exist because that check cannot be exercised through `clean()` without
/// letting it delete something.
final class CleanPlanTests: XCTestCase {

    private func item(
        _ name: String,
        bundleID: String?,
        size: Int64,
        selected: Bool = true
    ) -> CleanItem {
        CleanItem(
            id: "/tmp/\(name)",
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            title: name,
            bundleID: bundleID,
            note: nil,
            safety: .safe,
            size: size,
            isSelected: selected,
            blockedBy: nil
        )
    }

    private var categories: [CleanCategory] {
        [
            CleanCategory(id: .appCache, items: [
                item("chrome-cache", bundleID: "com.google.Chrome", size: 900),
                item("slack-cache", bundleID: "com.tinyspeck.slackmacgap", size: 500),
                item("orphan", bundleID: nil, size: 100),
                item("unticked", bundleID: "com.example.x", size: 999, selected: false)
            ]),
            CleanCategory(id: .trash, items: [
                item("trash-thing", bundleID: nil, size: 700)
            ])
        ]
    }

    private func names(_ urls: [URL]) -> Set<String> {
        Set(urls.map(\.lastPathComponent))
    }

    // MARK: - Baseline

    func testNothingRunningQueuesEverySelectedItem() {
        let plan = CleanModel.partition(
            categories: categories,
            permanentDelete: false,
            runningNow: [:]
        )
        XCTAssertEqual(names(plan.recyclable), ["chrome-cache", "slack-cache", "orphan"])
        XCTAssertTrue(plan.skipped.isEmpty)
    }

    func testTrashIsErasedEvenWithoutPermanentDelete() {
        let plan = CleanModel.partition(
            categories: categories,
            permanentDelete: false,
            runningNow: [:]
        )
        XCTAssertEqual(names(plan.erasable), ["trash-thing"])
    }

    func testUntickedItemsAreNeverQueued() {
        let plan = CleanModel.partition(
            categories: categories,
            permanentDelete: false,
            runningNow: [:]
        )
        XCTAssertFalse(names(plan.recyclable + plan.erasable).contains("unticked"))
        XCTAssertNil(plan.sizes[URL(fileURLWithPath: "/tmp/unticked")])
    }

    // MARK: - An app that started up after the scan

    func testCacheOfAnAppRunningNowIsLeftAlone() {
        let plan = CleanModel.partition(
            categories: categories,
            permanentDelete: false,
            runningNow: ["com.google.Chrome": "Google Chrome"]
        )
        XCTAssertFalse(names(plan.recyclable + plan.erasable).contains("chrome-cache"))
        XCTAssertEqual(plan.skipped.map(\.name), ["Google Chrome"])
        XCTAssertEqual(plan.skipped.first?.bytes, 900)
    }

    func testSkippingOneAppDoesNotStopTheRest() {
        let plan = CleanModel.partition(
            categories: categories,
            permanentDelete: false,
            runningNow: ["com.google.Chrome": "Google Chrome"]
        )
        XCTAssertEqual(names(plan.recyclable), ["slack-cache", "orphan"])
        XCTAssertEqual(names(plan.erasable), ["trash-thing"])
    }

    func testSkippedAppsAreReportedLargestFirst() {
        let plan = CleanModel.partition(
            categories: categories,
            permanentDelete: false,
            runningNow: [
                "com.google.Chrome": "Google Chrome",
                "com.tinyspeck.slackmacgap": "Slack"
            ]
        )
        XCTAssertEqual(plan.skipped.map(\.name), ["Google Chrome", "Slack"])
        XCTAssertEqual(plan.skipped.map(\.bytes), [900, 500])
    }

    func testPermanentDeleteStillRespectsARunningApp() {
        let plan = CleanModel.partition(
            categories: categories,
            permanentDelete: true,
            runningNow: ["com.google.Chrome": "Google Chrome"]
        )
        XCTAssertTrue(plan.recyclable.isEmpty)
        XCTAssertEqual(names(plan.erasable), ["slack-cache", "orphan", "trash-thing"])
        XCTAssertEqual(plan.skipped.map(\.name), ["Google Chrome"])
    }

    /// An item with no inferred bundle id must never collide with a running
    /// app, including one whose identifier is somehow empty.
    func testItemWithoutABundleIDIsNeverSkipped() {
        let plan = CleanModel.partition(
            categories: [CleanCategory(id: .appCache, items: [
                item("orphan", bundleID: nil, size: 1)
            ])],
            permanentDelete: false,
            runningNow: ["": "Nameless"]
        )
        XCTAssertTrue(plan.skipped.isEmpty)
        XCTAssertEqual(names(plan.recyclable), ["orphan"])
    }
}
