import XCTest
@testable import AIUsageMonitorCore

final class UsageLevelTests: XCTestCase {
    func testUsageLevelThresholds() {
        XCTAssertEqual(usageLevel(for: nil), .unknown)
        XCTAssertEqual(usageLevel(for: 9.9), .critical)
        XCTAssertEqual(usageLevel(for: 10), .warning)
        XCTAssertEqual(usageLevel(for: 19.9), .warning)
        XCTAssertEqual(usageLevel(for: 20), .normal)
        XCTAssertEqual(usageLevel(for: 90), .normal)
    }
}
