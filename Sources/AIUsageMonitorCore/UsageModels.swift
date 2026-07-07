import Foundation

public enum UsageProviderKind: String, Equatable, Sendable {
    case codex
}

public struct UsageSnapshot: Equatable, Sendable {
    public var provider: UsageProviderKind
    public var weekly: UsageBucket?
    public var fiveHour: UsageBucket?
    public var planType: String?
    public var refreshedAt: Date
    public var errorMessage: String?

    public init(
        provider: UsageProviderKind,
        weekly: UsageBucket? = nil,
        fiveHour: UsageBucket? = nil,
        planType: String? = nil,
        refreshedAt: Date = Date(),
        errorMessage: String? = nil
    ) {
        self.provider = provider
        self.weekly = weekly
        self.fiveHour = fiveHour
        self.planType = planType
        self.refreshedAt = refreshedAt
        self.errorMessage = errorMessage
    }

    public var headlineRemainingPercent: Double? {
        let values = [weekly?.remainingPercent, fiveHour?.remainingPercent].compactMap { $0 }
        return values.min()
    }

    public var headlineBucket: UsageBucket? {
        switch (weekly, fiveHour) {
        case let (w?, f?):
            return w.remainingPercent <= f.remainingPercent ? w : f
        case let (w?, nil):
            return w
        case let (nil, f?):
            return f
        default:
            return nil
        }
    }
}

public struct UsageBucket: Equatable, Sendable {
    public var id: String
    public var name: String
    public var usedPercent: Double
    public var remainingPercent: Double
    public var windowDurationMins: Int?
    public var resetsAt: Date?

    public init(
        id: String,
        name: String,
        usedPercent: Double,
        remainingPercent: Double,
        windowDurationMins: Int? = nil,
        resetsAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public enum UsageLevel: Equatable, Sendable {
    case normal
    case warning
    case critical
    case unknown
}

public func usageLevel(for remaining: Double?) -> UsageLevel {
    guard let remaining else {
        return .unknown
    }

    if remaining < 20 {
        return .critical
    }

    if remaining < 50 {
        return .warning
    }

    return .normal
}

public protocol UsageProvider {
    var kind: UsageProviderKind { get }
    func fetchSnapshot() async throws -> UsageSnapshot
}
