import SwiftUI

struct FooterView: View {
    let lastUpdated: Date?
    let isLoading: Bool
    var isAuthenticated: Bool = false
    var onLogout: (() -> Void)?

    var body: some View {
        HStack {
            if isLoading, lastUpdated != nil {
                Text("Updating...")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else if let lastUpdated {
                Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isAuthenticated, let onLogout {
                Button("Log out") {
                    onLogout()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
