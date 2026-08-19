import XCTest
@testable import MacPlecoKit

/// The walker reads raw `getattrlistbulk` buffers, so these tests pin the two
/// things that could silently go wrong: the byte totals, and the promise that
/// a symlink is never followed into another tree.
final class DirectoryWalkerTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("macpleco-walker-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ bytes: Int, to path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    /// The reference implementation this replaced, kept here so the two are
    /// compared against each other rather than against a hand-written number.
    private func enumeratorSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
        ]
        guard let enumerator = FileManager().enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    func testMatchesEnumeratorOnNestedTree() throws {
        try write(4_000, to: "a.bin")
        try write(80_000, to: "nested/b.bin")
        try write(12_000, to: "nested/deeper/c.bin")
        try write(1, to: "nested/deeper/empty.bin")
        try write(250_000, to: ".hidden/d.bin")

        XCTAssertEqual(Sizer.size(of: root), enumeratorSize(of: root))
    }

    func testCountsAtLeastTheBytesWritten() throws {
        try write(100_000, to: "one.bin")
        try write(100_000, to: "two/three.bin")

        // Allocated size rounds up to whole blocks, so it is never smaller
        // than the logical content.
        XCTAssertGreaterThanOrEqual(Sizer.size(of: root), 200_000)
    }

    func testDoesNotFollowSymbolicLinks() throws {
        let outside = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("macpleco-outside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        try Data(repeating: 0x42, count: 500_000)
            .write(to: outside.appendingPathComponent("big.bin"))

        try write(4_000, to: "small.bin")
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("link"),
            withDestinationURL: outside
        )

        // The linked-to 500 KB must not be counted here.
        XCTAssertLessThan(Sizer.size(of: root), 200_000)
    }

    func testSizeOfSingleFile() throws {
        try write(9_000, to: "solo.bin")
        let file = root.appendingPathComponent("solo.bin")
        XCTAssertGreaterThanOrEqual(Sizer.size(of: file), 9_000)
    }

    func testMissingPathIsZero() {
        XCTAssertEqual(Sizer.size(of: root.appendingPathComponent("nope")), 0)
    }

    /// The fan-out shares one worker pool between roots, so the risk is bytes
    /// being credited to the wrong root. Sizes are staggered to make any
    /// mix-up show up as a mismatch rather than a wash.
    func testFanoutAttributesEachRootSeparately() async throws {
        var expected: [Int64] = []
        var roots: [URL] = []
        for index in 1...6 {
            let name = "root\(index)"
            try write(index * 30_000, to: "\(name)/file.bin")
            try write(index * 10_000, to: "\(name)/sub/deep.bin")
            let url = root.appendingPathComponent(name)
            roots.append(url)
            expected.append(enumeratorSize(of: url))
        }

        let measured = await Sizer.sizes(of: roots)
        XCTAssertEqual(measured, expected)
    }

    func testFanoutReportsEveryRootExactlyOnce() async throws {
        var roots: [URL] = []
        for index in 1...5 {
            try write(10_000, to: "many\(index)/file.bin")
            roots.append(root.appendingPathComponent("many\(index)"))
        }
        // A missing path and a plain file alongside the directories: both must
        // still be reported, or the caller would wait forever.
        try write(7_000, to: "loose.bin")
        roots.append(root.appendingPathComponent("loose.bin"))
        roots.append(root.appendingPathComponent("does-not-exist"))

        let sizes = await Sizer.sizes(of: roots)
        XCTAssertEqual(sizes.count, 7)
        XCTAssertTrue(sizes.prefix(5).allSatisfy { $0 >= 10_000 })
        XCTAssertGreaterThanOrEqual(sizes[5], 7_000)
        XCTAssertEqual(sizes[6], 0)
    }

    func testCancelledScanStopsEarly() async throws {
        for index in 1...20 {
            try write(5_000, to: "cancel/\(index)/file.bin")
        }
        let token = ScanToken()
        token.cancel()
        let sizes = await Sizer.sizes(
            of: [root.appendingPathComponent("cancel")],
            token: token
        )
        XCTAssertEqual(sizes.count, 1)
    }
}
