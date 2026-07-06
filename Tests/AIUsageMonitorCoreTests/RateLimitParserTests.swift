import XCTest
@testable import AIUsageMonitorCore

final class RateLimitParserTests: XCTestCase {
    func testParsesWeeklyAndFiveHourBucketsByWindowDuration() {
        let parser = RateLimitParser()
        let result: [String: Any] = [
            "rateLimitsByLimitId": [
                "codex-week": [
                    "limitId": "codex-week",
                    "limitName": "Codex weekly",
                    "usedPercent": 30.0,
                    "windowDurationMins": 10_080,
                    "resetsAt": 1_800_000_000
                ],
                "codex-5h": [
                    "limitId": "codex-5h",
                    "limitName": "Codex 5h",
                    "usedPercent": 65.0,
                    "windowDurationMins": 300,
                    "resetsAt": 1_800_001_000
                ]
            ],
            "planType": "pro"
        ]

        let snapshot = parser.parse(result: result)

        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertEqual(snapshot.planType, "pro")
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 70)
        XCTAssertEqual(snapshot.weekly?.resetsAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 35)
        XCTAssertEqual(snapshot.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_800_001_000))
        XCTAssertEqual(snapshot.headlineRemainingPercent, 35)
    }

    func testFallsBackToLimitLabelsWhenWindowDurationIsMissing() {
        let parser = RateLimitParser()
        let result: [String: Any] = [
            "rateLimitsByLimitId": [
                "weekly": [
                    "limitName": "Week limit",
                    "usedPercent": "20"
                ],
                "short": [
                    "limitName": "5 hour limit",
                    "usedPercent": "40"
                ]
            ]
        ]

        let snapshot = parser.parse(result: result)

        XCTAssertEqual(snapshot.weekly?.remainingPercent, 80)
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 60)
    }

    func testParsesWhamUsageWindows() {
        let parser = RateLimitParser()
        let result: [String: Any] = [
            "plan_type": "plus",
            "rate_limit": [
                "primary_window": [
                    "used_percent": 60,
                    "limit_window_seconds": 18_000,
                    "reset_at": 1_800_001_000
                ],
                "secondary_window": [
                    "used_percent": 61,
                    "limit_window_seconds": 604_800,
                    "reset_at": 1_800_010_000
                ]
            ]
        ]

        let snapshot = parser.parse(result: result)

        XCTAssertEqual(snapshot.planType, "plus")
        XCTAssertEqual(snapshot.fiveHour?.name, "Codex 5 小时剩余")
        XCTAssertEqual(snapshot.fiveHour?.windowDurationMins, 300)
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 40)
        XCTAssertEqual(snapshot.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_800_001_000))
        XCTAssertEqual(snapshot.weekly?.name, "Codex 本周剩余")
        XCTAssertEqual(snapshot.weekly?.windowDurationMins, 10_080)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 39)
        XCTAssertEqual(snapshot.weekly?.resetsAt, Date(timeIntervalSince1970: 1_800_010_000))
    }

    func testMissingBucketsDoNotCrash() {
        let parser = RateLimitParser()
        let result: [String: Any] = [
            "rateLimitsByLimitId": [
                "unknown": [
                    "limitName": "Other limit",
                    "usedPercent": 10
                ]
            ]
        ]

        let snapshot = parser.parse(result: result)

        XCTAssertNil(snapshot.weekly)
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertNil(snapshot.headlineRemainingPercent)
    }

    func testParsesBackwardCompatibleSingleBucket() {
        let parser = RateLimitParser()
        let result: [String: Any] = [
            "rateLimits": [
                "limitName": "Codex weekly",
                "usedPercent": 82,
                "windowDurationMins": 10_080
            ]
        ]

        let snapshot = parser.parse(result: result)

        XCTAssertEqual(snapshot.weekly?.remainingPercent, 18)
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertEqual(snapshot.headlineRemainingPercent, 18)
    }
}
