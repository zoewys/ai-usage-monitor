import Foundation

public enum CodexAppServerClientError: Error, CustomStringConvertible {
    case launchFailed(String)
    case timeout(method: String)
    case authenticationExpired
    case serverError(String)
    case missingResult

    public var description: String {
        switch self {
        case .launchFailed(let message):
            return "无法启动 codex app-server：\(message)"
        case .timeout(let method):
            return "读取 \(method) 超时。"
        case .authenticationExpired:
            return "Codex CLI token 已过期，无法读取剩余用量。"
        case .serverError(let message):
            return message
        case .missingResult:
            return "Codex app-server 没有返回结果。"
        }
    }
}

public protocol CodexRateLimitClient {
    func readRateLimits() async throws -> [String: Any]
}

public final class CodexAppServerClient: CodexRateLimitClient {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    public func readRateLimits() async throws -> [String: Any] {
        try await Task.detached(priority: .utility) {
            try Self(timeout: self.timeout).readRateLimitsSync()
        }.value
    }

    private func readRateLimitsSync() throws -> [String: Any] {
        let session = try AppServerSession()
        defer {
            session.close()
        }

        _ = try session.request(
            id: 0,
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "ai_usage_monitor",
                    "title": "AI 剩余用量监控",
                    "version": "0.1.0"
                ],
                "capabilities": [
                    "experimentalApi": true
                ]
            ],
            timeout: timeout
        )

        try session.notify(method: "initialized", params: [:])

        _ = try session.request(
            id: 1,
            method: "account/read",
            params: ["refreshToken": true],
            timeout: timeout
        )

        return try session.request(
            id: 2,
            method: "account/rateLimits/read",
            params: [:],
            timeout: timeout
        )
    }
}

private final class AppServerSession {
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private let stateQueue = DispatchQueue(label: "ai-usage-monitor.app-server.state")
    private let responseSemaphore = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var responses: [Int: Result<[String: Any], Error>] = [:]
    private var stderrBuffer = Data()

    init() throws {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "app-server"]
        process.environment = Self.environment()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            self?.appendOutput(data)
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            self?.stateQueue.async {
                self?.stderrBuffer.append(data)
            }
        }

        do {
            try process.run()
        } catch {
            throw CodexAppServerClientError.launchFailed(error.localizedDescription)
        }
    }

    func request(id: Int, method: String, params: [String: Any], timeout: TimeInterval) throws -> [String: Any] {
        try write([
            "method": method,
            "id": id,
            "params": params
        ])

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let response = stateQueue.sync(execute: { responses.removeValue(forKey: id) }) {
                let result = try response.get()
                guard let payload = result["result"] as? [String: Any] else {
                    throw CodexAppServerClientError.missingResult
                }
                return payload
            }

            _ = responseSemaphore.wait(timeout: .now() + 0.1)
        }

        throw CodexAppServerClientError.timeout(method: method)
    }

    func notify(method: String, params: [String: Any]) throws {
        try write([
            "method": method,
            "params": params
        ])
    }

    func close() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        try? inputPipe.fileHandleForWriting.close()

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }

    private func write(_ message: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: message, options: [])
        var line = Data(data)
        line.append(0x0A)
        inputPipe.fileHandleForWriting.write(line)
    }

    private func appendOutput(_ data: Data) {
        stateQueue.async {
            self.buffer.append(data)

            while let newline = self.buffer.firstIndex(of: 0x0A) {
                let line = self.buffer[..<newline]
                self.buffer.removeSubrange(...newline)
                self.handleLine(Data(line))
            }
        }
    }

    private func handleLine(_ line: Data) {
        guard !line.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let id = object["id"] as? Int else {
            return
        }

        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Codex app-server 返回错误。"
            if message.contains("401 Unauthorized") || message.contains("token_expired") {
                responses[id] = .failure(CodexAppServerClientError.authenticationExpired)
            } else {
                responses[id] = .failure(CodexAppServerClientError.serverError(message))
            }
        } else {
            responses[id] = .success(object)
        }

        responseSemaphore.signal()
    }

    private static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let commonPaths = [
            "/Users/siyuan/.npm-global/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = ([existingPath] + commonPaths).filter { !$0.isEmpty }.joined(separator: ":")
        return env
    }
}
