import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(["Day", "Week", "Month"], id: \.self) { label in
                HStack(spacing: 0) {
                    Text("◌")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)

                    Text(label)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)

                    Spacer()

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.04))
                        .frame(width: 70, height: 12)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.04))
                        .frame(width: 50, height: 10)
                        .padding(.leading, 10)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
        }
    }
}
