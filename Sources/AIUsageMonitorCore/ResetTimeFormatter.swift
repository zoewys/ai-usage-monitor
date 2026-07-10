import Foundation

public enum ResetTimeFormatter {
    public static func label(
        for date: Date?,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let date else {
            return "--"
        }

        let components = calendar.dateComponents(
            [.month, .day, .weekday, .hour, .minute],
            from: date
        )
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let time = String(format: "%02d:%02d", hour, minute)

        let startOfToday = calendar.startOfDay(for: now)
        let startOfResetDay = calendar.startOfDay(for: date)
        let dayDifference = calendar.dateComponents(
            [.day],
            from: startOfToday,
            to: startOfResetDay
        ).day

        switch dayDifference {
        case 0:
            return "今天 \(time)"
        case 1:
            return "明天 \(time)"
        default:
            let month = components.month ?? 0
            let day = components.day ?? 0
            let weekday = weekdayLabel(for: components.weekday)
            return "\(month)月\(day)日 \(weekday) \(time)"
        }
    }

    private static func weekdayLabel(for weekday: Int?) -> String {
        let labels = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        guard let weekday, labels.indices.contains(weekday - 1) else {
            return ""
        }
        return labels[weekday - 1]
    }
}
