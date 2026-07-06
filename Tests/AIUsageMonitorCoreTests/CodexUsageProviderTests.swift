import XCTest
@testable import AIUsageMonitorCore

final class CodexUsageProviderTests: XCTestCase {
    func testKeepsBrowserSessionErrorWhenCliFallbackIsExpired() async {
        let provider = CodexUsageProvider(
            clients: [
                StubRateLimitClient(result: .failure(CodexBrowserSessionClientError.noUsableBrowserSession)),
                StubRateLimitClient(result: .failure(CodexAppServerClientError.authenticationExpired))
            ]
        )

        do {
            _ = try await provider.fetchSnapshot()
            XCTFail("Expected fetchSnapshot to throw")
        } catch CodexBrowserSessionClientError.noUsableBrowserSession {
        } catch {
            XCTFail("Expected browser session error, got \(error)")
        }
    }
}

private struct StubRateLimitClient: CodexRateLimitClient {
    let result: Result<[String: Any], Error>

    func readRateLimits() async throws -> [String: Any] {
        try result.get()
    }
}
