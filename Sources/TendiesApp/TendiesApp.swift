import SwiftUI

@main
struct TendiesApp: App {
    var body: some Scene {
        MenuBarExtra("Tendies", systemImage: "chart.line.uptrend.xyaxis") {
            Text("▲ +$1,234").font(.headline)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
