import SwiftUI
import AppKit

struct ErrorView: View {
    let error: AppError
    var appState: AppState?

    @State private var isLoadingCheckout = false
    @State private var checkoutError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("\u{26A0}")
                Text(errorTitle)
                    .font(.system(size: 12.5, weight: .medium))
            }

            Text(errorBody)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .subscriptionRequired = error, let appState {
                subscribeButtons(appState: appState)
            } else if let command = errorCommand {
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

    @ViewBuilder
    private func subscribeButtons(appState: AppState) -> some View {
        VStack(spacing: 6) {
            Button(action: { startCheckout(appState: appState, plan: "monthly") }) {
                HStack(spacing: 6) {
                    if isLoadingCheckout {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Subscribe ($5/mo)")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingCheckout)

            if let checkoutError {
                Text(checkoutError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func startCheckout(appState: AppState, plan: String) {
        isLoadingCheckout = true
        checkoutError = nil
        Task {
            defer { isLoadingCheckout = false }
            do {
                let urlString = try await appState.getCheckoutURL(plan: plan)
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                } else {
                    checkoutError = "Invalid checkout URL"
                }
            } catch {
                checkoutError = error.localizedDescription
            }
        }
    }

    private var errorTitle: String {
        switch error {
        case .authExpired: return "Authentication expired"
        case .schwabTokenExpired: return "Schwab session expired"
        case .subscriptionRequired: return "Subscription required"
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
        case .subscriptionRequired(let msg):
            return msg
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
            return "tendies account link"
        case .binaryNotFound:
            return "brew install batjaa/tap/tendies"
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
        case .subscriptionRequired:
            return "After subscribing, click refresh to reload your data."
        default:
            return nil
        }
    }
}
