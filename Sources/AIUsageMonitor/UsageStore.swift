import AIUsageMonitorCore
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot(provider: .codex)
    @Published private(set) var isRefreshing = false

    private let service: UsageService
    private var timer: Timer?

    init(service: UsageService = UsageService()) {
        self.service = service
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true

        Task {
            do {
                snapshot = try await service.fetchCodexSnapshot()
            } catch {
                snapshot = UsageSnapshot(
                    provider: .codex,
                    refreshedAt: Date(),
                    errorMessage: Self.userFacingErrorMessage(for: error)
                )
            }

            isRefreshing = false
        }
    }

    private static func userFacingErrorMessage(for error: Error) -> String {
        let message = String(describing: error)
        let lowercased = message.lowercased()

        if lowercased.contains("chatgpt browser session")
            || lowercased.contains("browser cookie")
            || lowercased.contains("access token")
            || lowercased.contains("keychain")
            || lowercased.contains("curl failed while reading chatgpt usage") {
            return "没有读到可用的本机 ChatGPT 会话。请打开已登录 ChatGPT 的 Brave/Chrome/Edge，然后点刷新。"
        }

        if lowercased.contains("401")
            || lowercased.contains("unauthorized")
            || lowercased.contains("token_expired")
            || lowercased.contains("authentication")
            || lowercased.contains("登录已过期") {
            return "Codex CLI token 已过期；会优先使用本机浏览器会话。请打开已登录 ChatGPT 的 Brave/Chrome/Edge，然后点刷新。"
        }

        return message
    }
}
