import SwiftUI

/// Small inline pill that surfaces which bridge a row originated from. Shows
/// only when the user has more than one connected bridge — single-bridge users
/// never see attribution clutter. Drop it into Device rows, Log rows, etc.
struct BridgeBadge: View {
    let bridgeName: String
    let isFocused: Bool

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.registry.sessions.values.filter(\.isConnected).count >= 2 {
            HStack(spacing: 3) {
                Circle()
                    .fill(isFocused ? Color.green : Color.secondary)
                    .frame(width: 5, height: 5)
                Text(bridgeName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(isFocused ? Color.green.opacity(0.12) : Color(.systemGray5))
            )
            .foregroundStyle(isFocused ? Color.green : Color.secondary)
            .accessibilityLabel("Bridge: \(bridgeName)")
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        BridgeBadge(bridgeName: "Main", isFocused: true)
        BridgeBadge(bridgeName: "Lab", isFocused: false)
    }
    .padding()
    .environment(AppEnvironment())
}
