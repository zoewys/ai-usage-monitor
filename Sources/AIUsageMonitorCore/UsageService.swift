import Foundation

public final class UsageService {
    private let providers: [UsageProvider]

    public init(providers: [UsageProvider] = [CodexUsageProvider()]) {
        self.providers = providers
    }

    public func fetchSnapshots() async throws -> [UsageSnapshot] {
        var snapshots: [UsageSnapshot] = []

        for provider in providers {
            snapshots.append(try await provider.fetchSnapshot())
        }

        return snapshots
    }

    public func fetchCodexSnapshot() async throws -> UsageSnapshot {
        guard let provider = providers.first(where: { $0.kind == .codex }) else {
            return UsageSnapshot(
                provider: .codex,
                refreshedAt: Date(),
                errorMessage: "Codex 读取源未配置。"
            )
        }

        return try await provider.fetchSnapshot()
    }
}
