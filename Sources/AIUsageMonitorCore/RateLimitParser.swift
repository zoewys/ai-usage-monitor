import Foundation

public struct RateLimitParser {
    public init() {}

    public func parse(result: [String: Any], refreshedAt: Date = Date()) -> UsageSnapshot {
        let candidates = collectCandidates(from: result)
        let weekly = candidates
            .first(where: { $0.bucket.windowDurationMins == 10_080 })?.bucket
            ?? candidates.first(where: { isWeekly(id: $0.id, name: $0.bucket.name) })?.bucket
        let fiveHour = candidates
            .first(where: { $0.bucket.windowDurationMins == 300 })?.bucket
            ?? candidates.first(where: { isFiveHour(id: $0.id, name: $0.bucket.name) })?.bucket
        let planType = stringValue(result["planType"])
            ?? stringValue(result["plan_type"])
            ?? candidates.compactMap { stringValue($0.raw["planType"]) }.first

        return UsageSnapshot(
            provider: .codex,
            weekly: weekly,
            fiveHour: fiveHour,
            planType: planType,
            refreshedAt: refreshedAt
        )
    }

    private func collectCandidates(from result: [String: Any]) -> [(id: String, raw: [String: Any], bucket: UsageBucket)] {
        var candidates: [(id: String, raw: [String: Any], bucket: UsageBucket)] = []

        if let rateLimit = result["rate_limit"] as? [String: Any] {
            if let primary = rateLimit["primary_window"] as? [String: Any],
               let bucket = bucket(from: primary, fallbackId: "codex_5h", fallbackName: "Codex 5 小时剩余") {
                candidates.append((id: "codex_5h", raw: primary, bucket: bucket))
            }

            if let secondary = rateLimit["secondary_window"] as? [String: Any],
               let bucket = bucket(from: secondary, fallbackId: "codex_week", fallbackName: "Codex 本周剩余") {
                candidates.append((id: "codex_week", raw: secondary, bucket: bucket))
            }
        }

        if let byLimitId = result["rateLimitsByLimitId"] as? [String: Any] {
            for (id, rawValue) in byLimitId {
                if let raw = rawValue as? [String: Any],
                   let bucket = bucket(from: raw, fallbackId: id) {
                    candidates.append((id: id, raw: raw, bucket: bucket))
                }
            }
        }

        if let rateLimits = result["rateLimits"] as? [String: Any],
           let bucket = bucket(from: rateLimits, fallbackId: "rateLimits") {
            candidates.append((id: "rateLimits", raw: rateLimits, bucket: bucket))
        }

        if let rateLimitsArray = result["rateLimits"] as? [[String: Any]] {
            for (index, raw) in rateLimitsArray.enumerated() {
                let fallbackId = stringValue(raw["limitId"]) ?? "rateLimits[\(index)]"
                if let bucket = bucket(from: raw, fallbackId: fallbackId) {
                    candidates.append((id: fallbackId, raw: raw, bucket: bucket))
                }
            }
        }

        return candidates
    }

    private func bucket(from raw: [String: Any], fallbackId: String, fallbackName: String? = nil) -> UsageBucket? {
        guard let usedPercent = doubleValue(raw["usedPercent"]) ?? doubleValue(raw["used_percent"]) else {
            return nil
        }

        let id = stringValue(raw["limitId"]) ?? fallbackId
        let name = stringValue(raw["limitName"])
            ?? stringValue(raw["name"])
            ?? stringValue(raw["label"])
            ?? fallbackName
            ?? id
        let windowDurationMins = intValue(raw["windowDurationMins"])
            ?? intValue(raw["limit_window_seconds"]).map { $0 / 60 }
        let resetsAt = dateValue(raw["resetsAt"])
            ?? dateValue(raw["reset_at"])
            ?? intValue(raw["reset_after_seconds"]).map {
                Date(timeIntervalSinceNow: TimeInterval($0))
            }
        let remainingPercent = max(0, min(100, 100 - usedPercent))

        return UsageBucket(
            id: id,
            name: name,
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            windowDurationMins: windowDurationMins,
            resetsAt: resetsAt
        )
    }

    private func isWeekly(id: String, name: String) -> Bool {
        let text = "\(id) \(name)".lowercased()
        return text.contains("weekly") || text.contains("week")
    }

    private func isFiveHour(id: String, name: String) -> Bool {
        let text = "\(id) \(name)".lowercased()
        return text.contains("5h")
            || text.contains("5 h")
            || text.contains("5-hour")
            || text.contains("5 hour")
            || text.contains("five hour")
    }
}

private func stringValue(_ value: Any?) -> String? {
    switch value {
    case let string as String:
        return string
    case let number as NSNumber:
        return number.stringValue
    default:
        return nil
    }
}

private func doubleValue(_ value: Any?) -> Double? {
    switch value {
    case let double as Double:
        return double
    case let int as Int:
        return Double(int)
    case let number as NSNumber:
        return number.doubleValue
    case let string as String:
        return Double(string)
    default:
        return nil
    }
}

private func intValue(_ value: Any?) -> Int? {
    switch value {
    case let int as Int:
        return int
    case let double as Double:
        return Int(double)
    case let number as NSNumber:
        return number.intValue
    case let string as String:
        return Int(string)
    default:
        return nil
    }
}

private func dateValue(_ value: Any?) -> Date? {
    switch value {
    case let int as Int:
        return Date(timeIntervalSince1970: TimeInterval(int))
    case let double as Double:
        return Date(timeIntervalSince1970: double)
    case let number as NSNumber:
        return Date(timeIntervalSince1970: number.doubleValue)
    case let string as String:
        if let seconds = Double(string) {
            return Date(timeIntervalSince1970: seconds)
        }
        return ISO8601DateFormatter().date(from: string)
    default:
        return nil
    }
}
