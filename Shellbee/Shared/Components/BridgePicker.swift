import SwiftUI

/// Form-row bridge picker used in create-style flows (Permit Join, Pairing
/// Wizard, Add Group, MQTT Inspector). Auto-hides when fewer than 2 bridges
/// are connected — single-bridge users never see it. The selection drives the
/// `bridgeID` that the host view threads into its action calls.
///
/// Use as a `Section` row inside a Form / List, or stand-alone above a sheet's
/// content. The binding can start as nil; on appear the picker auto-selects
/// the first connected bridge if a default is needed.
struct BridgePicker: View {
    @Binding var selection: UUID?
    /// `true` collapses the picker to nothing entirely when only one bridge is
    /// connected. Set this to false if the host view wants to render the
    /// picker even in single-bridge mode (e.g., for explicitness).
    var hideWhenSingle: Bool = true

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let connectedSessions = environment.registry.orderedSessions.filter(\.isConnected)
        if hideWhenSingle && connectedSessions.count < 2 {
            EmptyView()
        } else if connectedSessions.isEmpty {
            HStack {
                Text("Bridge")
                Spacer()
                Text("No bridge connected")
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker(selection: pickerBinding(connected: connectedSessions)) {
                ForEach(connectedSessions, id: \.bridgeID) { session in
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Circle()
                            .fill(BridgeColor.color(for: session.bridgeID))
                            .frame(width: 8, height: 8)
                        Text(session.displayName)
                    }
                    .tag(session.bridgeID as UUID?)
                }
            } label: {
                Text("Bridge")
            }
            .onAppear {
                // Default to the first connected bridge when the host view
                // didn't pre-select one. Keeps the picker valid before the
                // user opens it.
                if selection == nil || connectedSessions.first(where: { $0.bridgeID == selection }) == nil {
                    selection = connectedSessions.first?.bridgeID
                }
            }
        }
    }

    private func pickerBinding(connected: [BridgeSession]) -> Binding<UUID?> {
        Binding(
            get: { selection ?? connected.first?.bridgeID },
            set: { selection = $0 }
        )
    }
}

extension View {
    /// Convenience helper for sheet headers that want a one-line bridge label
    /// when only one bridge is connected ("Adding to Lab") rather than a
    /// picker. Pass through to `BridgePicker` when 2+ are connected.
    @ViewBuilder
    func bridgeContextHeader(bridgeID: UUID?, environment: AppEnvironment) -> some View {
        let connected = environment.registry.orderedSessions.filter(\.isConnected)
        if connected.count == 1, let session = connected.first {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Circle()
                    .fill(BridgeColor.color(for: session.bridgeID))
                    .frame(width: 8, height: 8)
                Text("On \(session.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
