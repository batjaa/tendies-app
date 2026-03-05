import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    let onBack: () -> Void

    @State private var pendingSymbols: String = ""
    private let allTimeframes = ["Day", "Week", "Month"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                applySymbolFilter()
                onBack()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)

            // DISPLAY section
            sectionTitle("Display")

            HStack {
                Text("Timeframes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(allTimeframes, id: \.self) { tf in
                        let isEnabled = appState.enabledTimeframes.contains(tf)
                        Button(action: { toggleTimeframe(tf) }) {
                            HStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(isEnabled ? Color.green : Color.primary.opacity(0.25), lineWidth: 1.5)
                                        .frame(width: 14, height: 14)
                                        .background(
                                            isEnabled ? Color.green : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 3)
                                        )
                                    if isEnabled {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                Text(tf)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(isEnabled ? .primary : .secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                isEnabled
                                    ? Color.green.opacity(0.1)
                                    : Color.primary.opacity(0.02)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(
                                        isEnabled
                                            ? Color.green.opacity(0.25)
                                            : Color.primary.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 12)

            // FILTER section
            sectionTitle("Filter")

            HStack {
                Text("Symbols")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("e.g. AAPL, TSLA", text: $pendingSymbols)
                    .font(.system(size: 11.5, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .frame(maxWidth: 150)
                    .onSubmit { applySymbolFilter() }
                    .onAppear { pendingSymbols = appState.symbols }
            }
            .padding(.bottom, 4)

            if !pendingSymbols.isEmpty {
                HStack {
                    Spacer()
                    Button(action: {
                        pendingSymbols = ""
                        applySymbolFilter()
                    }) {
                        Text("Clear filter")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func applySymbolFilter() {
        let trimmed = pendingSymbols.trimmingCharacters(in: .whitespaces)
        guard trimmed != appState.symbols else { return }
        appState.symbols = trimmed
        Task { await appState.refresh() }
    }

    private func toggleTimeframe(_ tf: String) {
        if appState.enabledTimeframes.contains(tf) {
            guard appState.enabledTimeframes.count > 1 else { return }
            appState.enabledTimeframes.removeAll { $0 == tf }
        } else {
            appState.enabledTimeframes.append(tf)
            appState.enabledTimeframes.sort { allTimeframes.firstIndex(of: $0)! < allTimeframes.firstIndex(of: $1)! }
        }
        Task { await appState.refresh() }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(1)
            .padding(.bottom, 6)
    }
}
