import SwiftUI

struct PermitJoinToolbarButton: View {
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ShellbeeSymbol.permitJoin.image
                .imageScale(.large)
                .foregroundStyle(isActive ? Color.green : Color.primary)
                .symbolEffect(.pulse, isActive: isActive)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(isActive ? "Permit Join Active" : "Start Permit Join")
    }
}

#Preview("Inactive") {
    NavigationStack {
        Color.clear
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PermitJoinToolbarButton(isActive: false) {}
                }
            }
    }
    .configuredTopScrollEdgeEffect()
}

#Preview("Active") {
    NavigationStack {
        Color.clear
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PermitJoinToolbarButton(isActive: true) {}
                }
            }
    }
    .configuredTopScrollEdgeEffect()
}
