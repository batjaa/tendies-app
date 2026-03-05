import Foundation
import os

private let logger = Logger(subsystem: "site.batjaa.tendies-app", category: "CLIRunner")

enum AppError: Error, LocalizedError {
    case authExpired(String)
    case schwabTokenExpired(String)
    case subscriptionRequired(String)
    case binaryNotFound
    case timeout
    case generic(String)

    var isSubscriptionRequired: Bool {
        if case .subscriptionRequired = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .authExpired(let msg): return msg
        case .schwabTokenExpired(let msg): return msg
        case .subscriptionRequired(let msg): return msg
        case .binaryNotFound: return "tendies CLI not found"
        case .timeout: return "CLI timed out after 30s"
        case .generic(let msg): return msg
        }
    }
}

struct CLIRunner {

    static func resolveBinary(customPath: String? = nil) -> String? {
        if let custom = customPath, !custom.isEmpty,
           FileManager.default.isExecutableFile(atPath: custom) {
            logger.info("Using custom CLI path: \(custom)")
            return custom
        }
        let knownPaths = [
            "/opt/homebrew/bin/tendies",
            "/usr/local/bin/tendies",
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                logger.info("Found CLI at: \(path)")
                return path
            }
        }
        if let path = whichTendies(), FileManager.default.isExecutableFile(atPath: path) {
            logger.info("Found CLI via PATH: \(path)")
            return path
        }
        logger.error("tendies binary not found")
        return nil
    }

    static func run(
        customPath: String? = nil,
        direct: Bool = false,
        symbols: String? = nil,
        account: String? = nil,
        timeframes: [String] = ["Day"]
    ) async -> Result<TendiesOutput, AppError> {
        guard let binaryPath = resolveBinary(customPath: customPath) else {
            return .failure(.binaryNotFound)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)

        var args = ["--json"]
        // Pass timeframe flag when a single timeframe is selected.
        if timeframes.count == 1 {
            let flag = "--\(timeframes[0].lowercased())"
            args.append(flag)
        }
        // When multiple or all are selected, no flag → CLI returns Day+Week+Month.
        if direct {
            args.append("--direct")
        }
        if let symbols, !symbols.isEmpty {
            args += ["--symbol", symbols]
        }
        if let account, !account.isEmpty {
            args += ["--account", account]
        }
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        logger.notice("Running: \(binaryPath) \(args.joined(separator: " "))")
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch: \(error.localizedDescription)")
            return .failure(.generic("Failed to launch tendies: \(error.localizedDescription)"))
        }

        // 30s timeout.
        let timeoutItem = DispatchWorkItem {
            if process.isRunning {
                logger.warning("Timeout — killing process")
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutItem)

        // Read both pipes concurrently on background threads to avoid pipe buffer
        // deadlock, then wait for the process to fully exit.
        let (stdoutData, stderrData) = await withCheckedContinuation {
            (continuation: CheckedContinuation<(Data, Data), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var stdout = Data()
                var stderr = Data()
                let group = DispatchGroup()

                group.enter()
                DispatchQueue.global().async {
                    stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.enter()
                DispatchQueue.global().async {
                    stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.wait()
                process.waitUntilExit()
                continuation.resume(returning: (stdout, stderr))
            }
        }

        timeoutItem.cancel()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.notice("Process exited with status \(process.terminationStatus) in \(String(format: "%.1f", elapsed))s (stdout=\(stdoutData.count)B, stderr=\(stderrData.count)B)")

        if stderrData.count > 0, let stderrStr = String(data: stderrData, encoding: .utf8) {
            logger.debug("stderr: \(stderrStr)")
        }

        return parseResult(
            status: process.terminationStatus,
            reason: process.terminationReason,
            stdout: stdoutData,
            stderr: stderrData
        )
    }

    // MARK: - Private

    static func parseResult(
        status: Int32,
        reason: Process.TerminationReason,
        stdout: Data,
        stderr: Data
    ) -> Result<TendiesOutput, AppError> {
        if status == 0 {
            do {
                let output = try JSONDecoder().decode(TendiesOutput.self, from: stdout)
                logger.info("Parsed \(output.timeframes.count) timeframes, \(output.accounts.count) accounts")
                return .success(output)
            } catch {
                logger.error("JSON parse failed: \(error.localizedDescription)")
                return .failure(.generic("Failed to parse CLI output: \(error.localizedDescription)"))
            }
        }

        if reason == .uncaughtSignal {
            return .failure(.timeout)
        }

        if let cliError = try? JSONDecoder().decode(TendiesError.self, from: stderr) {
            logger.warning("CLI error: \(cliError.error) — \(cliError.message)")
            switch cliError.error {
            case "auth_expired":
                return .failure(.authExpired(cliError.message))
            case "schwab_token_expired":
                return .failure(.schwabTokenExpired(cliError.message))
            case "subscription_required":
                return .failure(.subscriptionRequired(cliError.message))
            default:
                return .failure(.generic(cliError.message))
            }
        }

        let msg = String(data: stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
        logger.error("CLI failed (exit \(status)): \(msg)")
        return .failure(.generic(msg))
    }

    private static func whichTendies() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["tendies"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }
}
