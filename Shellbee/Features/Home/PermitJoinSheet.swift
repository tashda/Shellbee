import SwiftUI

struct PermitJoinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment

    /// Phase 2 multi-bridge: target bridge for permit-join. Nil = focused
    /// bridge (single-bridge fallback). The picker auto-selects on appear
    /// when more than one bridge is connected.
    @State private var bridgeID: UUID?
    @State private var targetName: String?
    @State private var duration: Int = 254

    let onStart: (_ duration: Int, _ target: String?, _ bridgeID: UUID?) -> Void
    let onStop: (_ bridgeID: UUID?) -> Void

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if isSelectedBridgePermitJoinOpen {
                    activeContent
                } else {
                    Form {
                        bridgeSection
                        permitJoinSection
                    }
                    .safeAreaInset(edge: .bottom) { actionBar }
                }
            }
            .navigationTitle("Permit Join")
            .navigationBarTitleDisplayMode(.inline)
        }
        .configuredTopScrollEdgeEffect()
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

    @ViewBuilder
    private var permitJoinSection: some View {
        Section {
            Picker("Via", selection: $targetName) {
                Text("All devices").tag(String?.none)
                ForEach(joinTargets) { device in
                    Text(device.friendlyName).tag(String?.some(device.friendlyName))
                }
            }
            Picker("Duration", selection: $duration) {
                Text("1 min").tag(60)
                Text("2 min").tag(120)
                Text("3 min").tag(180)
                Text("~4 min").tag(254)
            }
        } header: {
            Text("Open the network")
        }
    }

    private var activeContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(spacing: DesignTokens.Spacing.lg) {
                Spacer()
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(DesignTokens.Typography.permitJoinSymbol)
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
                    .accessibilityHidden(true)

                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Network is open")
                        .font(.title2.weight(.semibold))
                    Text(activeDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let remaining = remainingSeconds(at: ctx.date) {
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(DesignTokens.Typography.permitJoinCountdown.monospacedDigit())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("\(remaining / 60) minutes and \(remaining % 60) seconds remaining")
                }

                Spacer()
                actionBar
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.sm)
        }
    }

    private var activeDetail: String {
        if let target = selectedBridgeInfo?.permitJoinTarget, !target.isEmpty {
            return "Pairing through \(target)"
        }
        return "New devices can join this network"
    }

    private var actionBar: some View {
        Button {
            if isSelectedBridgePermitJoinOpen {
                onStop(resolvedBridgeID)
            } else {
                onStart(duration, targetName, resolvedBridgeID)
            }
            dismiss()
        } label: {
            Text(isSelectedBridgePermitJoinOpen ? "Stop Permit Join" : "Start Permit Join")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelectedBridgePermitJoinOpen ? .red : nil)
        .controlSize(.large)
    }

    private var resolvedBridgeID: UUID? {
        bridgeID ?? environment.registry.primaryBridgeID
    }

    private var selectedBridgeInfo: BridgeInfo? {
        guard let resolvedBridgeID,
              let session = environment.registry.session(for: resolvedBridgeID) else { return nil }
        return session.store.bridgeInfo
    }

    private var isSelectedBridgePermitJoinOpen: Bool {
        selectedBridgeInfo?.permitJoin ?? false
    }

    /// Routers + coordinator from the selected bridge's store. When `bridgeID`
    /// is nil (single-bridge mode before the picker is shown) falls back to
    /// the user-selected bridge in the picker.
    private var joinTargets: [Device] {
        let store = resolvedBridgeID.flatMap { environment.registry.session(for: $0)?.store }
        return (store?.devices ?? [])
            .filter { $0.type == .coordinator || $0.type == .router }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type { return lhs.type == .coordinator }
                return lhs.friendlyName.localizedCompare(rhs.friendlyName) == .orderedAscending
            }
    }

    private func remainingSeconds(at date: Date) -> Int? {
        guard let permitEnd = selectedBridgeInfo?.permitJoinEnd else { return nil }
        let nowMS = Int(date.timeIntervalSince1970 * 1000)
        return max((permitEnd - nowMS) / 1000, 0)
    }
}

#Preview {
    PermitJoinSheet(onStart: { _, _, _ in }, onStop: { _ in })
        .environment(AppEnvironment())
}
