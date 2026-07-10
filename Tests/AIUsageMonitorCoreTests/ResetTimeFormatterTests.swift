import AIUsageMonitorCore
import XCTest

final class ResetTimeFormatterTests: XCTestCase {
    func testTodayResetIncludesExactTime() throws {
        let now = try date(year: 2026, month: 7, day: 10, hour: 16, minute: 24)
        let reset = try date(year: 2026, month: 7, day: 10, hour: 21, minute: 20)

        XCTAssertEqual(
            ResetTimeFormatter.label(for: reset, relativeTo: now, calendar: calendar),
            "今天 21:20"
        )
    }

    func testTomorrowResetUsesTomorrowLabel() throws {
        let now = try date(year: 2026, month: 7, day: 10, hour: 23, minute: 30)
        let reset = try date(year: 2026, month: 7, day: 11, hour: 8, minute: 5)

        XCTAssertEqual(
            ResetTimeFormatter.label(for: reset, relativeTo: now, calendar: calendar),
            "明天 08:05"
        )
    }

    func testFutureResetIncludesDateWeekdayAndExactTime() throws {
        let now = try date(year: 2026, month: 7, day: 10, hour: 16, minute: 24)
        let reset = try date(year: 2026, month: 7, day: 17, hour: 10, minute: 24)

        XCTAssertEqual(
            ResetTimeFormatter.label(for: reset, relativeTo: now, calendar: calendar),
            "7月17日 周五 10:24"
        )
    }

    func testMissingResetReturnsPlaceholder() throws {
        let now = try date(year: 2026, month: 7, day: 10, hour: 16, minute: 24)

        XCTAssertEqual(
            ResetTimeFormatter.label(for: nil, relativeTo: now, calendar: calendar),
            "--"
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }
}
