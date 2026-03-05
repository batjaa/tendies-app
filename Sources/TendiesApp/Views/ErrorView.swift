import SwiftUI
import AppKit

struct ErrorView: View {
    let error: AppError

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("⚠")
                Text(errorTitle)
                    .font(.system(size: 12.5, weight: .medium))
            }

            Text(errorBody)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let command = errorCommand {
                VStack(spacing: 6) {
                    Text(command)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy Command")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if let helpText = errorHelp {
                Text(helpText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var errorTitle: String {
        switch error {
        case .authExpired: return "Authentication expired"
        case .schwabTokenExpired: return "Schwab session expired"
        case .binaryNotFound: return "tendies CLI not found"
        case .timeout: return "CLI timed out"
        case .generic: return "Something went wrong"
        }
    }

    private var errorBody: String {
        switch error {
        case .authExpired:
            return "Run in Terminal:"
        case .schwabTokenExpired:
            return "Your Schwab token has expired.\nRe-authenticate in Terminal:"
        case .binaryNotFound:
            return "Install via Homebrew:"
        case .timeout:
            return "The CLI took too long to respond. Try refreshing."
        case .generic(let msg):
            return msg
        }
    }

    private var errorCommand: String? {
        switch error {
        case .authExpired, .schwabTokenExpired:
            return "tendies auth login"
        case .binaryNotFound:
            return "brew install batjaa/tools/tendies"
        default:
            return nil
        }
    }

    private var errorHelp: String? {
        switch error {
        case .authExpired:
            return "After logging in, click refresh to reload your data."
        case .binaryNotFound:
            return "Then click refresh to load your P&L data."
        default:
            return nil
        }
    }
}
