import Foundation
import os

private let logger = Logger(subsystem: "site.batjaa.tendies-app", category: "Subscription")

enum SubscriptionStatus: String, Codable {
    case trialing
    case active
    case pastDue = "past_due"
    case expired
}

struct SubscriptionInfo: Codable {
    let status: SubscriptionStatus
    let trialEndsAt: String?
    let proUntil: String?

    enum CodingKeys: String, CodingKey {
        case status
        case trialEndsAt = "trial_ends_at"
        case proUntil = "pro_until"
    }
}

enum SubscriptionService {
    private static let session = URLSession.shared

    static func fetchStatus(token: String, brokerURL: String) async throws -> SubscriptionInfo {
        let url = URL(string: "\(brokerURL)/api/v1/subscription")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Subscription status fetch failed: \(msg)")
            throw SubscriptionError.fetchFailed(msg)
        }

        let decoder = JSONDecoder()
        let info = try decoder.decode(SubscriptionInfo.self, from: data)
        logger.info("Subscription status: \(info.status.rawValue)")
        return info
    }

    static func getCheckoutURL(token: String, brokerURL: String, plan: String) async throws -> String {
        let url = URL(string: "\(brokerURL)/api/v1/subscription/checkout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = ["plan": plan]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Checkout URL fetch failed: \(msg)")
            throw SubscriptionError.checkoutFailed(msg)
        }

        struct CheckoutResponse: Codable {
            let checkoutUrl: String

            enum CodingKeys: String, CodingKey {
                case checkoutUrl = "checkout_url"
            }
        }

        let checkout = try JSONDecoder().decode(CheckoutResponse.self, from: data)
        logger.info("Got checkout URL for plan: \(plan)")
        return checkout.checkoutUrl
    }

    static func getPortalURL(token: String, brokerURL: String) async throws -> String {
        let url = URL(string: "\(brokerURL)/api/v1/subscription/portal")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Portal URL fetch failed: \(msg)")
            throw SubscriptionError.portalFailed(msg)
        }

        struct PortalResponse: Codable {
            let portalUrl: String

            enum CodingKeys: String, CodingKey {
                case portalUrl = "portal_url"
            }
        }

        let portal = try JSONDecoder().decode(PortalResponse.self, from: data)
        return portal.portalUrl
    }
}

enum SubscriptionError: Error, LocalizedError {
    case fetchFailed(String)
    case checkoutFailed(String)
    case portalFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let msg): return "Failed to check subscription: \(msg)"
        case .checkoutFailed(let msg): return "Failed to get checkout URL: \(msg)"
        case .portalFailed(let msg): return "Failed to open billing portal: \(msg)"
        }
    }
}
