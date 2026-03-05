@preconcurrency import AuthenticationServices
import CryptoKit
import Foundation
import os

private let logger = Logger(subsystem: "site.batjaa.tendies-app", category: "Auth")

enum AuthError: Error, LocalizedError {
    case notAuthenticated
    case missingClientID
    case loginCancelled
    case stateMismatch
    case missingCode
    case tokenExchangeFailed(String)
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated"
        case .missingClientID: return "broker_client_id not set in ~/.tendies/config.json"
        case .loginCancelled: return "Login was cancelled"
        case .stateMismatch: return "OAuth state mismatch"
        case .missingCode: return "No authorization code in callback"
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        case .refreshFailed(let msg): return "Token refresh failed: \(msg)"
        }
    }
}

@Observable
final class AuthService {
    var isLoggingIn = false

    private let session = URLSession.shared

    func login() async throws {
        let config = TendiesConfig.load()
        guard let clientID = config.brokerClientID, !clientID.isEmpty else {
            throw AuthError.missingClientID
        }
        let brokerURL = config.resolvedBrokerURL

        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(verifier: verifier)
        let state = generateState()
        let redirectURI = "tendies://callback"

        var components = URLComponents(string: "\(brokerURL)/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        guard let authorizeURL = components.url else {
            throw AuthError.tokenExchangeFailed("Invalid authorize URL")
        }

        isLoggingIn = true
        defer { isLoggingIn = false }

        logger.notice("Starting OAuth login")

        let callbackURL = try await startAuthSession(url: authorizeURL, scheme: "tendies")

        guard let cbComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw AuthError.missingCode
        }

        let returnedState = cbComponents.queryItems?.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            logger.error("State mismatch: expected=\(state), got=\(returnedState ?? "nil")")
            throw AuthError.stateMismatch
        }

        guard let code = cbComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.missingCode
        }

        let token = try await exchangeCode(
            code: code,
            verifier: verifier,
            redirectURI: redirectURI,
            clientID: clientID,
            brokerURL: brokerURL
        )

        try KeychainService.saveToken(token)
        logger.notice("Login complete, token saved to keychain")
    }

    func refreshToken() async throws {
        guard let current = KeychainService.loadToken() else {
            throw AuthError.notAuthenticated
        }

        let config = TendiesConfig.load()
        guard let clientID = config.brokerClientID, !clientID.isEmpty else {
            throw AuthError.missingClientID
        }
        let brokerURL = config.resolvedBrokerURL

        let body = [
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": current.refreshToken,
        ]

        var request = URLRequest(url: URL(string: "\(brokerURL)/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(body).data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Token refresh failed: \(msg)")
            throw AuthError.refreshFailed(msg)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let newToken = KeychainToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? current.refreshToken,
            expiry: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )

        try KeychainService.saveToken(newToken)
        logger.info("Token refreshed successfully")
    }

    /// Ensures a valid token exists. Returns silently if OK, throws if not authenticated.
    func ensureValidToken() async throws {
        guard let token = KeychainService.loadToken() else {
            throw AuthError.notAuthenticated
        }

        // If token expires within 30 seconds, refresh it.
        if token.expiry.timeIntervalSinceNow < 30 {
            try await refreshToken()
        }
    }

    // MARK: - Private

    private func startAuthSession(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.loginCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.missingCode)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            authSession.presentationContextProvider = AuthPresentationContext.shared
            authSession.prefersEphemeralWebBrowserSession = false

            DispatchQueue.main.async {
                authSession.start()
            }
        }
    }

    private func exchangeCode(
        code: String,
        verifier: String,
        redirectURI: String,
        clientID: String,
        brokerURL: String
    ) async throws -> KeychainToken {
        let body = [
            "grant_type": "authorization_code",
            "client_id": clientID,
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier,
        ]

        var request = URLRequest(url: URL(string: "\(brokerURL)/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(body).data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.tokenExchangeFailed(msg)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return KeychainToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? "",
            expiry: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }

    // MARK: - PKCE (matches Go CLI's generatePKCE)

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private func generateCodeChallenge(verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }

    private func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func formEncode(_ params: [String: String]) -> String {
        params.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
}

// MARK: - Token response

private struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

// MARK: - Base64 URL encoding

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation context for ASWebAuthenticationSession

private final class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    nonisolated static let shared = AuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return any available window; for menu bar apps there may not be a key window.
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
