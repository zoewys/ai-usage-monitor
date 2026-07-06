import CommonCrypto
import Foundation
import SQLite3

public enum CodexBrowserSessionClientError: Error, CustomStringConvertible {
    case noUsableBrowserSession
    case missingAccessToken
    case commandFailed(String)
    case invalidResponse(String)

    public var description: String {
        switch self {
        case .noUsableBrowserSession:
            return "没有在 Brave、Chrome 或 Edge 里找到可用的 ChatGPT 会话。"
        case .missingAccessToken:
            return "本机 ChatGPT 会话没有返回可用 token。"
        case .commandFailed(let message):
            return message
        case .invalidResponse(let message):
            return message
        }
    }
}

public final class CodexBrowserSessionClient: CodexRateLimitClient {
    private let profiles: [BrowserProfile]

    public init() {
        self.profiles = BrowserProfile.discover()
    }

    init(profiles: [BrowserProfile]) {
        self.profiles = profiles
    }

    public func readRateLimits() async throws -> [String: Any] {
        try await Task.detached(priority: .utility) {
            try self.readRateLimitsSync()
        }.value
    }

    private func readRateLimitsSync() throws -> [String: Any] {
        var lastError: Error?

        for profile in profiles {
            do {
                let cookieHeader = try cookieHeader(for: profile)
                let session = try curlJSON(
                    url: "https://chatgpt.com/api/auth/session",
                    headers: browserHeaders(cookieHeader: cookieHeader)
                )

                guard let accessToken = session["accessToken"] as? String,
                      !accessToken.isEmpty else {
                    throw CodexBrowserSessionClientError.missingAccessToken
                }

                return try curlJSON(
                    url: "https://chatgpt.com/backend-api/wham/usage",
                    headers: [
                        "Authorization: Bearer \(accessToken)"
                    ] + browserHeaders(cookieHeader: cookieHeader)
                )
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? CodexBrowserSessionClientError.noUsableBrowserSession
    }

    private func cookieHeader(for profile: BrowserProfile) throws -> String {
        let password = try keychainPassword(service: profile.safeStorageService, account: profile.safeStorageAccount)
        let rows = try readCookieRows(at: profile.cookieDatabasePath)
        var cookies: [String] = []

        for row in rows {
            let value: String
            if let plainValue = row.value, !plainValue.isEmpty {
                value = plainValue
            } else {
                value = try decryptCookie(row.encryptedValue, hostKey: row.hostKey, password: password)
            }

            guard !value.isEmpty else {
                continue
            }

            cookies.append("\(row.name)=\(value)")
        }

        guard cookies.contains(where: { $0.hasPrefix("__Secure-next-auth.session-token") }) else {
            throw CodexBrowserSessionClientError.noUsableBrowserSession
        }

        return cookies.joined(separator: "; ")
    }

    private func browserHeaders(cookieHeader: String) -> [String] {
        [
            "Cookie: \(cookieHeader)",
            "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36",
            "Accept: application/json, text/plain, */*",
            "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8",
            "Referer: https://chatgpt.com/",
            "Origin: https://chatgpt.com"
        ]
    }

    private func curlJSON(url: String, headers: [String]) throws -> [String: Any] {
        var config = """
        silent
        show-error
        fail-with-body
        location
        http1.1
        max-time = 20
        url = "\(escapeCurlConfig(url))"

        """

        for header in headers {
            config += "header = \"\(escapeCurlConfig(header))\"\n"
        }

        let result = try runCommand(
            executable: "/usr/bin/curl",
            arguments: ["-K", "-"],
            standardInput: Data(config.utf8)
        )

        guard result.exitCode == 0 else {
            throw CodexBrowserSessionClientError.commandFailed("读取 ChatGPT 剩余用量失败。")
        }

        guard let object = try JSONSerialization.jsonObject(with: result.stdout) as? [String: Any] else {
            throw CodexBrowserSessionClientError.invalidResponse("ChatGPT 剩余用量返回格式不正确。")
        }

        return object
    }

    private func escapeCurlConfig(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func keychainPassword(service: String, account: String) throws -> Data {
        let result = try runCommand(
            executable: "/usr/bin/security",
            arguments: ["find-generic-password", "-s", service, "-a", account, "-w"]
        )

        guard result.exitCode == 0 else {
            throw CodexBrowserSessionClientError.commandFailed("无法从钥匙串读取 \(service)。")
        }

        var data = result.stdout
        while data.last == 0x0A || data.last == 0x0D {
            data.removeLast()
        }
        return data
    }

    private func readCookieRows(at path: String) throws -> [CookieRow] {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(path, &database, flags, nil) == SQLITE_OK, let database else {
            throw CodexBrowserSessionClientError.invalidResponse("无法打开浏览器 cookie 数据库。")
        }
        defer {
            sqlite3_close(database)
        }

        sqlite3_busy_timeout(database, 1_000)

        let query = """
        SELECT host_key, name, value, encrypted_value
        FROM cookies
        WHERE host_key IN ('chatgpt.com', '.chatgpt.com')
        ORDER BY path DESC, creation_utc
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CodexBrowserSessionClientError.invalidResponse("无法读取浏览器 cookie。")
        }
        defer {
            sqlite3_finalize(statement)
        }

        var rows: [CookieRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let hostKey = String(cString: sqlite3_column_text(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            let value = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let encryptedBytes = sqlite3_column_blob(statement, 3)
            let encryptedLength = Int(sqlite3_column_bytes(statement, 3))
            let encryptedValue: Data
            if let encryptedBytes, encryptedLength > 0 {
                encryptedValue = Data(bytes: encryptedBytes, count: encryptedLength)
            } else {
                encryptedValue = Data()
            }

            rows.append(CookieRow(hostKey: hostKey, name: name, value: value, encryptedValue: encryptedValue))
        }

        return rows
    }

    private func decryptCookie(_ encryptedValue: Data, hostKey: String, password: Data) throws -> String {
        guard !encryptedValue.isEmpty else {
            return ""
        }

        var ciphertext = encryptedValue
        if ciphertext.starts(with: Data("v10".utf8)) || ciphertext.starts(with: Data("v11".utf8)) {
            ciphertext.removeFirst(3)
        }

        let key = try deriveChromeKey(password: password)
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        let outputCapacity = ciphertext.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0

        let status = output.withUnsafeMutableBytes { outputBytes in
            ciphertext.withUnsafeBytes { ciphertextBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            ciphertextBytes.baseAddress,
                            ciphertext.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw CodexBrowserSessionClientError.invalidResponse("无法解密浏览器 cookie。")
        }

        output.removeSubrange(outputLength..<output.count)

        let hostDigest = sha256(Data(hostKey.utf8))
        if output.starts(with: hostDigest) {
            output.removeFirst(hostDigest.count)
        }

        guard let value = String(data: output, encoding: .utf8) else {
            throw CodexBrowserSessionClientError.invalidResponse("浏览器 cookie 不是 UTF-8 格式。")
        }

        return value
    }

    private func deriveChromeKey(password: Data) throws -> Data {
        let salt = Data("saltysalt".utf8)
        let keyLength = kCCKeySizeAES128
        var key = Data(count: keyLength)

        let status = key.withUnsafeMutableBytes { keyBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        1_003,
                        keyBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw CodexBrowserSessionClientError.invalidResponse("无法生成浏览器 cookie 解密密钥。")
        }

        return key
    }

    private func sha256(_ data: Data) -> Data {
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes { digestBytes in
            data.withUnsafeBytes { dataBytes in
                _ = CC_SHA256(dataBytes.baseAddress, CC_LONG(data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return digest
    }

    private func runCommand(
        executable: String,
        arguments: [String],
        standardInput: Data? = nil
    ) throws -> CommandResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        if standardInput != nil {
            process.standardInput = stdin
        }

        try process.run()

        if let standardInput {
            stdin.fileHandleForWriting.write(standardInput)
            try? stdin.fileHandleForWriting.close()
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        _ = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return CommandResult(exitCode: process.terminationStatus, stdout: outputData)
    }
}

struct BrowserProfile {
    var cookieDatabasePath: String
    var safeStorageService: String
    var safeStorageAccount: String

    static func discover() -> [BrowserProfile] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [(base: String, service: String, account: String)] = [
            (
                "\(home)/Library/Application Support/BraveSoftware/Brave-Browser",
                "Brave Safe Storage",
                "Brave"
            ),
            (
                "\(home)/Library/Application Support/Google/Chrome",
                "Chrome Safe Storage",
                "Chrome"
            ),
            (
                "\(home)/Library/Application Support/Microsoft Edge",
                "Microsoft Edge Safe Storage",
                "Microsoft Edge"
            )
        ]

        return candidates.flatMap { candidate in
            cookieDatabases(in: candidate.base).map {
                BrowserProfile(
                    cookieDatabasePath: $0,
                    safeStorageService: candidate.service,
                    safeStorageAccount: candidate.account
                )
            }
        }
    }

    private static func cookieDatabases(in basePath: String) -> [String] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: basePath) else {
            return []
        }

        let profileNames = entries
            .filter { $0 == "Default" || $0.hasPrefix("Profile ") }
            .sorted { left, right in
                if left == "Default" {
                    return true
                }
                if right == "Default" {
                    return false
                }
                return left.localizedStandardCompare(right) == .orderedAscending
            }

        return profileNames
            .map { "\(basePath)/\($0)/Cookies" }
            .filter { fileManager.fileExists(atPath: $0) }
    }
}

private struct CookieRow {
    var hostKey: String
    var name: String
    var value: String?
    var encryptedValue: Data
}

private struct CommandResult {
    var exitCode: Int32
    var stdout: Data
}
