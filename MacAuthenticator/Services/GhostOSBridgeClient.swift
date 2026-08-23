import Foundation

enum GhostOSBridgeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rejected(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Paste the complete http://localhost GhostOS URL, including its setup code."
        case .invalidResponse:
            return "GhostOS returned an invalid response."
        case .rejected(let message):
            return message.isEmpty ? "GhostOS rejected the request." : message
        case .timedOut:
            return "GhostOS did not provide a login challenge in time."
        }
    }
}

struct GhostOSBridgeState: Decodable, Equatable {
    let mode: String
    let challenge: String
    let error: String
}

private final class GhostOSNoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class GhostOSBridgeClient {
    let origin: URL

    private let token: String
    private let session: URLSession

    init(connectionURL value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "http",
              components.host?.lowercased() == "localhost",
              let port = components.port,
              (1...65_535).contains(port),
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let items = components.queryItems,
              items.count == 1,
              items[0].name == "code",
              let code = items[0].value,
              !code.isEmpty,
              code.count <= 256,
              code.unicodeScalars.allSatisfy({ $0.isASCII && !$0.properties.isWhitespace }) else {
            throw GhostOSBridgeError.invalidURL
        }

        guard let origin = URL(string: "http://localhost:\(port)") else {
            throw GhostOSBridgeError.invalidURL
        }
        self.origin = origin
        self.token = code

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(
            configuration: configuration,
            delegate: GhostOSNoRedirectDelegate(),
            delegateQueue: nil
        )
    }

    func state() async throws -> GhostOSBridgeState {
        let data = try await request(path: "/api/state", method: "GET")
        guard let state = try? JSONDecoder().decode(GhostOSBridgeState.self, from: data) else {
            throw GhostOSBridgeError.invalidResponse
        }
        return state
    }

    func enroll(username: String, coseKey: Data) async throws {
        let body = "\(percentEncode(username))\n\(coseKey.lowercaseHexString)"
        _ = try await request(path: "/api/enroll", method: "POST", body: Data(body.utf8))
    }

    func startLogin(username: String) async throws {
        _ = try await request(
            path: "/api/login/start",
            method: "POST",
            body: Data(percentEncode(username).utf8)
        )
    }

    func completeLogin(assertion: Data) async throws {
        _ = try await request(
            path: "/api/login/complete",
            method: "POST",
            body: Data(assertion.lowercaseHexString.utf8)
        )
    }

    func waitForChallenge() async throws -> String {
        for _ in 0..<240 {
            try Task.checkCancellation()
            let current = try await state()
            if current.challenge.count == GhostOSAssertion.challengeHexLength {
                _ = try GhostOSAssertion.challengeBytes(fromHex: current.challenge)
                return current.challenge
            }
            if !current.error.isEmpty { throw GhostOSBridgeError.rejected(current.error) }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        throw GhostOSBridgeError.timedOut
    }

    private func request(path: String, method: String, body: Data? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: origin)?.absoluteURL else {
            throw GhostOSBridgeError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(token, forHTTPHeaderField: "X-GhostOS-Code")
        if body != nil { request.setValue("text/plain", forHTTPHeaderField: "Content-Type") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.url?.scheme == origin.scheme,
              http.url?.host?.lowercased() == origin.host,
              http.url?.port == origin.port else {
            throw GhostOSBridgeError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data.prefix(512), encoding: .utf8) ?? ""
            throw GhostOSBridgeError.rejected(message)
        }
        return data
    }

    private func percentEncode(_ value: String) -> String {
        value.utf8.map { byte in
            if byte.isASCIIAlphaNumeric || [45, 46, 95, 126].contains(byte) {
                return String(UnicodeScalar(byte))
            }
            return String(format: "%%%02X", byte)
        }.joined()
    }
}

private extension UInt8 {
    var isASCIIAlphaNumeric: Bool {
        (48...57).contains(self) || (65...90).contains(self) || (97...122).contains(self)
    }
}
