import Foundation

public final class CodexUsageProvider: UsageProvider {
    public let kind: UsageProviderKind = .codex

    private let clients: [any CodexRateLimitClient]
    private let parser: RateLimitParser

    public init(
        clients: [any CodexRateLimitClient] = [CodexBrowserSessionClient(), CodexAppServerClient()],
        parser: RateLimitParser = RateLimitParser()
    ) {
        self.clients = clients
        self.parser = parser
    }

    public func fetchSnapshot() async throws -> UsageSnapshot {
        let result = try await readRateLimits()
        var snapshot = parser.parse(result: result)

        if snapshot.weekly == nil && snapshot.fiveHour == nil {
            snapshot.errorMessage = "Codex 没有返回本周或 5 小时剩余用量。请点刷新再试一次。"
        }

        return snapshot
    }

    private func readRateLimits() async throws -> [String: Any] {
        var lastError: Error?
        var browserSessionError: Error?

        for client in clients {
            do {
                return try await client.readRateLimits()
            } catch {
                lastError = error
                if error is CodexBrowserSessionClientError {
                    browserSessionError = error
                }
            }
        }

        throw browserSessionError ?? lastError ?? CodexBrowserSessionClientError.noUsableBrowserSession
    }
}
