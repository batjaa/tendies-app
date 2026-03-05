import Foundation
import Testing
@testable import TendiesApp

@Suite("CLIRunner.parseResult")
struct CLIRunnerTests {

    private func validJSON() -> Data {
        let json = """
        {
            "timeframes": [{"label":"Day","gains":100,"losses":0,"net":100,"trade_count":1,"tickers":[]}],
            "accounts": [],
            "account_ids": [],
            "warnings": [],
            "updated_at": "2024-03-04T15:00:00Z"
        }
        """
        return Data(json.utf8)
    }

    // MARK: - Success cases

    @Test func status0ValidJSON() throws {
        let result = CLIRunner.parseResult(
            status: 0, reason: .exit, stdout: validJSON(), stderr: Data()
        )
        let output = try result.get()
        #expect(output.timeframes.count == 1)
        #expect(output.timeframes[0].label == "Day")
    }

    @Test func status0InvalidJSON() {
        let result = CLIRunner.parseResult(
            status: 0, reason: .exit, stdout: Data("not json".utf8), stderr: Data()
        )
        switch result {
        case .success:
            Issue.record("Expected failure for invalid JSON")
        case .failure(let err):
            #expect(err.errorDescription?.contains("parse") == true)
        }
    }

    // MARK: - Timeout

    @Test func uncaughtSignalIsTimeout() {
        let result = CLIRunner.parseResult(
            status: 9, reason: .uncaughtSignal, stdout: Data(), stderr: Data()
        )
        switch result {
        case .success:
            Issue.record("Expected timeout failure")
        case .failure(let err):
            if case .timeout = err {
                // expected
            } else {
                Issue.record("Expected .timeout, got \(err)")
            }
        }
    }

    // MARK: - Typed error JSON on stderr

    @Test func authExpiredError() {
        let stderr = Data(#"{"error":"auth_expired","message":"Token expired"}"#.utf8)
        let result = CLIRunner.parseResult(
            status: 1, reason: .exit, stdout: Data(), stderr: stderr
        )
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let err):
            if case .authExpired(let msg) = err {
                #expect(msg == "Token expired")
            } else {
                Issue.record("Expected .authExpired, got \(err)")
            }
        }
    }

    @Test func subscriptionRequiredError() {
        let stderr = Data(#"{"error":"subscription_required","message":"Subscribe now"}"#.utf8)
        let result = CLIRunner.parseResult(
            status: 1, reason: .exit, stdout: Data(), stderr: stderr
        )
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let err):
            if case .subscriptionRequired(let msg) = err {
                #expect(msg == "Subscribe now")
            } else {
                Issue.record("Expected .subscriptionRequired, got \(err)")
            }
        }
    }

    @Test func schwabTokenExpiredError() {
        let stderr = Data(#"{"error":"schwab_token_expired","message":"Re-login required"}"#.utf8)
        let result = CLIRunner.parseResult(
            status: 1, reason: .exit, stdout: Data(), stderr: stderr
        )
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let err):
            if case .schwabTokenExpired(let msg) = err {
                #expect(msg == "Re-login required")
            } else {
                Issue.record("Expected .schwabTokenExpired, got \(err)")
            }
        }
    }

    // MARK: - Plain stderr fallback

    @Test func plainStderrGenericError() {
        let stderr = Data("something went wrong\n".utf8)
        let result = CLIRunner.parseResult(
            status: 1, reason: .exit, stdout: Data(), stderr: stderr
        )
        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let err):
            if case .generic(let msg) = err {
                #expect(msg == "something went wrong")
            } else {
                Issue.record("Expected .generic, got \(err)")
            }
        }
    }
}
