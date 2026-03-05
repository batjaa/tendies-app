import SwiftUI

struct AccountBarView: View {
    let accounts: [String]
    let selected: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text("Acct")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(accounts, id: \.self) { account in
                        let isSelected = selected.contains(account)
                        Button(action: { onToggle(account) }) {
                            Text(account)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(isSelected ? .primary : .tertiary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(isSelected ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.primary.opacity(isSelected ? 0.14 : 0.06), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
