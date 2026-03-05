import SwiftUI

struct HeaderView: View {
    let isLoading: Bool
    let onRefresh: () -> Void
    let onSettings: () -> Void

    @State private var isSpinning = false

    var body: some View {
        HStack {
            Text("Tendies")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: {
                onRefresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .onChange(of: isLoading) { _, loading in
                if loading {
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                        isSpinning = true
                    }
                } else {
                    withAnimation(.default) {
                        isSpinning = false
                    }
                }
            }
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
