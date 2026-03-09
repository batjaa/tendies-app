import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    let onBack: () -> Void

    @State private var pendingSymbols: String = ""
    @State private var isBackHovered = false
    @State private var isEditingCLIPath = false
    @State private var pendingCLIPath: String = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let allTimeframes = ["Day", "Week", "Month"]
    private let refreshIntervals = [1, 2, 5, 10, 30]

    var body: some View {
        ScrollView {
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
                .foregroundStyle(isBackHovered ? .primary : .secondary)
                .onHover { hovering in isBackHovered = hovering }
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
                .padding(.bottom, 8)

                settingRow("Menu Bar") {
                    Picker("", selection: Binding(
                        get: { appState.menuBarTimeframe },
                        set: { newValue in
                            appState.menuBarTimeframe = newValue
                            appState.persistSettings()
                        }
                    )) {
                        ForEach(appState.enabledTimeframes, id: \.self) { tf in
                            Text(tf).tag(tf)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 90)
                }
                .padding(.bottom, 8)

                settingRow("Ticker Sort") {
                    Picker("", selection: Binding(
                        get: { appState.tickerSort },
                        set: { newValue in
                            appState.tickerSort = newValue
                            appState.persistSettings()
                        }
                    )) {
                        Text("A-Z").tag("az")
                        Text("P&L").tag("pnl")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 100)
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
                        .onChange(of: pendingSymbols) { _, newValue in
                            let uppercased = newValue.uppercased()
                            if uppercased != newValue { pendingSymbols = uppercased }
                        }
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

                Spacer().frame(height: 12)

                // REFRESH section
                sectionTitle("Refresh")

                settingRow("Interval") {
                    Picker("", selection: Binding(
                        get: { appState.refreshMinutes },
                        set: { newValue in
                            appState.refreshMinutes = newValue
                            appState.persistSettings()
                            appState.restartTimer()
                        }
                    )) {
                        ForEach(refreshIntervals, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 90)
                }
                .padding(.bottom, 12)

                // GENERAL section
                sectionTitle("General")

                HStack {
                    Text("CLI Path")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isEditingCLIPath {
                        TextField("custom path", text: $pendingCLIPath)
                            .font(.system(size: 11, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .frame(maxWidth: 150)
                            .onSubmit {
                                let trimmed = pendingCLIPath.trimmingCharacters(in: .whitespaces)
                                appState.cliPath = trimmed.isEmpty ? nil : trimmed
                                appState.persistSettings()
                                isEditingCLIPath = false
                            }
                    } else {
                        Button(action: {
                            pendingCLIPath = appState.cliPath ?? ""
                            isEditingCLIPath = true
                        }) {
                            Text(appState.resolvedCLIPath ?? "not found")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(appState.resolvedCLIPath != nil ? Color.primary : Color.red)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)

                settingRow("Mode") {
                    Picker("", selection: Binding(
                        get: { appState.direct },
                        set: { newValue in
                            appState.direct = newValue
                            appState.persistSettings()
                            Task { await appState.refresh() }
                        }
                    )) {
                        Text("Broker").tag(false)
                        Text("Direct").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 130)
                }
                .padding(.bottom, 8)

                settingRow("Logs") {
                    Button(action: openLogs) {
                        Text("Open in Console")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .padding(.bottom, 8)

                settingRow("Launch at Login") {
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                                launchAtLogin = newValue
                            } catch {
                                // Registration failed — revert toggle state.
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func settingRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }

    private func applySymbolFilter() {
        let trimmed = pendingSymbols.trimmingCharacters(in: .whitespaces)
        guard trimmed != appState.symbols else { return }
        appState.symbols = trimmed
        appState.persistSettings()
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
        // Ensure menuBarTimeframe is still valid.
        if !appState.enabledTimeframes.contains(appState.menuBarTimeframe) {
            appState.menuBarTimeframe = appState.enabledTimeframes.first ?? "Day"
        }
        appState.persistSettings()
        Task { await appState.refresh() }
    }

    private func openLogs() {
        // Open Console.app filtered to our subsystem.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Console"]
        try? proc.run()
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
