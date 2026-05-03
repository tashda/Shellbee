import SwiftUI

struct PermitJoinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment

    /// Phase 2 multi-bridge: target bridge for permit-join. Nil = focused
    /// bridge (single-bridge fallback). The picker auto-selects on appear
    /// when more than one bridge is connected.
    @State private var bridgeID: UUID?
    @State private var targetName: String?
    @State private var durationChoice = DurationChoice.max
    @State private var customDuration = 120

    let onConfirm: (_ duration: Int, _ target: String?, _ bridgeID: UUID?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                bridgeSection
                durationSection
                targetSection
            }
            .navigationTitle("Permit Join")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { actionBar }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var bridgeSection: some View {
        let connected = environment.registry.orderedSessions.filter(\.isConnected)
        if connected.count >= 2 {
            Section {
                BridgePicker(selection: $bridgeID)
            } footer: {
                Text("Permit Join opens this bridge's network only. Other bridges remain closed.")
            }
        }
    }

    private var durationSection: some View {
        Section {
            Picker("Preset", selection: $durationChoice) {
                ForEach(DurationChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            if durationChoice == .custom {
                InlineIntField("Custom", value: $customDuration, unit: "s", range: 1...254)
            }
        } header: {
            Text("Duration")
        } footer: {
            Text("Zigbee networks support a maximum of 254 seconds per session.")
        }
    }

    private var targetSection: some View {
        Section {
            Picker("Target", selection: $targetName) {
                Text("All devices").tag(String?.none)
                ForEach(joinTargets) { device in
                    Text(device.friendlyName).tag(String?.some(device.friendlyName))
                }
            }
        } header: {
            Text("Via")
        } footer: {
            Text("The coordinator and any router can allow new devices to join your network.")
        }
        .onChange(of: bridgeID) { _, _ in
            // Reset the via-target when the user picks a different bridge —
            // the prior bridge's router list isn't valid anymore.
            targetName = nil
        }
    }

    private var actionBar: some View {
        Button {
            onConfirm(selectedDuration, targetName, bridgeID)
            dismiss()
        } label: {
            Text("Start Permit Join")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.xl)
        .background(.ultraThinMaterial)
    }

    /// Routers + coordinator from the selected bridge's store. Falls back to
    /// the focused bridge when `bridgeID` is nil.
    private var joinTargets: [Device] {
        let store: AppStore
        if let bridgeID, let session = environment.registry.session(for: bridgeID) {
            store = session.store
        } else {
            store = environment.store
        }
        return store.devices
            .filter { $0.type == .coordinator || $0.type == .router }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type { return lhs.type == .coordinator }
                return lhs.friendlyName.localizedCompare(rhs.friendlyName) == .orderedAscending
            }
    }

    private var selectedDuration: Int {
        durationChoice == .custom ? customDuration : durationChoice.seconds
    }

    private enum DurationChoice: String, CaseIterable, Identifiable {
        case oneMin, twoMin, threeMin, max, custom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .oneMin:  return "1 min"
            case .twoMin:  return "2 min"
            case .threeMin: return "3 min"
            case .max:     return "~4 min"
            case .custom:  return "Custom"
            }
        }

        var seconds: Int {
            switch self {
            case .oneMin:  return 60
            case .twoMin:  return 120
            case .threeMin: return 180
            case .max:     return 254
            case .custom:  return 120
            }
        }
    }
}

#Preview {
    PermitJoinSheet { _, _, _ in }
        .environment(AppEnvironment())
}
