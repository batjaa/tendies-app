import Foundation

struct TendiesConfig: Codable {
    let brokerURL: String?
    let brokerClientID: String?

    enum CodingKeys: String, CodingKey {
        case brokerURL = "broker_url"
        case brokerClientID = "broker_client_id"
    }

    static let defaultBrokerURL = "https://tendies.batjaa.site"

    static func load() -> TendiesConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".tendies/config.json")

        guard let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(TendiesConfig.self, from: data)
        else {
            return TendiesConfig(brokerURL: nil, brokerClientID: nil)
        }
        return config
    }

    var resolvedBrokerURL: String {
        let url = brokerURL ?? Self.defaultBrokerURL
        // Strip trailing slash to match Go CLI behavior.
        if url.hasSuffix("/") {
            return String(url.dropLast())
        }
        return url
    }
}
