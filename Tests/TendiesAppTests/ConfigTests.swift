import Foundation
import Testing
@testable import TendiesApp

@Suite("TendiesConfig")
struct ConfigTests {

    @Test func resolvedBrokerURL_default() {
        let config = TendiesConfig(brokerURL: nil, brokerClientID: nil)
        #expect(config.resolvedBrokerURL == "https://tendies.batjaa.site")
    }

    @Test func resolvedBrokerURL_trailingSlash() {
        let config = TendiesConfig(brokerURL: "https://example.com/", brokerClientID: nil)
        #expect(config.resolvedBrokerURL == "https://example.com")
    }

    @Test func resolvedBrokerURL_custom() {
        let config = TendiesConfig(brokerURL: "https://custom.dev", brokerClientID: nil)
        #expect(config.resolvedBrokerURL == "https://custom.dev")
    }

    @Test func jsonDecoding() throws {
        let json = """
        {"broker_url": "https://test.com", "broker_client_id": "abc123"}
        """
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(TendiesConfig.self, from: data)

        #expect(config.brokerURL == "https://test.com")
        #expect(config.brokerClientID == "abc123")
    }

    @Test func jsonDecodingMissingFields() throws {
        let json = "{}"
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(TendiesConfig.self, from: data)

        #expect(config.brokerURL == nil)
        #expect(config.brokerClientID == nil)
    }
}
