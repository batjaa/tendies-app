import Foundation
import os
import Security

private let logger = Logger(subsystem: "site.batjaa.tendies-app", category: "Keychain")

struct KeychainToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiry: Date

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiry
    }
}

enum KeychainService {
    private static let service = "tendies"
    private static let account = "broker_token"
    private static let goKeyringPrefix = "go-keyring-base64:"

    /// In-memory cache to avoid repeated Keychain prompts.
    private static var cachedToken: KeychainToken?
    private static var cacheLoaded = false

    static func loadToken() -> KeychainToken? {
        if cacheLoaded { return cachedToken }
        cachedToken = loadTokenFromKeychain()
        cacheLoaded = true
        return cachedToken
    }

    /// Force-reload from Keychain (e.g. after login or token refresh).
    static func reloadToken() {
        cachedToken = loadTokenFromKeychain()
        cacheLoaded = true
    }

    private static func loadTokenFromKeychain() -> KeychainToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                logger.warning("Keychain read failed: \(status)")
            }
            return nil
        }

        guard let raw = String(data: data, encoding: .utf8) else {
            logger.error("Keychain data is not valid UTF-8")
            return nil
        }

        let json: String
        if raw.hasPrefix(goKeyringPrefix) {
            let b64 = String(raw.dropFirst(goKeyringPrefix.count))
            guard let decoded = Data(base64Encoded: b64) else {
                logger.error("Failed to base64 decode keychain value")
                return nil
            }
            guard let decodedStr = String(data: decoded, encoding: .utf8) else {
                logger.error("Decoded keychain data is not valid UTF-8")
                return nil
            }
            json = decodedStr
        } else {
            json = raw
        }

        guard let jsonData = json.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Go's time.Time marshals as RFC 3339 with fractional seconds.
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: str) { return date }
            // Fallback without fractional seconds.
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }

        do {
            return try decoder.decode(KeychainToken.self, from: jsonData)
        } catch {
            logger.error("Failed to decode keychain token JSON: \(error.localizedDescription)")
            return nil
        }
    }

    static func saveToken(_ token: KeychainToken) throws {
        cachedToken = token
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }

        let jsonData = try encoder.encode(token)
        let b64 = jsonData.base64EncodedString()
        let value = goKeyringPrefix + b64

        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Try update first; if not found, add.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: valueData,
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = valueData
            status = SecItemAdd(newItem as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            logger.error("Keychain save failed: \(status)")
            throw KeychainError.saveFailed(status)
        }

        logger.info("Saved broker token to keychain")
    }

    static func deleteToken() {
        cachedToken = nil
        cacheLoaded = false
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.warning("Keychain delete failed: \(status)")
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode token for keychain"
        case .saveFailed(let status): return "Keychain save failed (OSStatus \(status))"
        }
    }
}
