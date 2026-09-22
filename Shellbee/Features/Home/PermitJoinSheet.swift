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
    @State private var contentHeight: CGFloat = 0

    let onStart: (_ duration: Int, _ target: String?, _ bridgeID: UUID?) -> Void
    let onStop: (_ bridgeID: UUID?) -> Void

    var body: some View {
        SwiftUI.Group {
            if #available(iOS 18.0, *) {
                fittedPresentationContent
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
            } else {
                presentationContent.presentationDetents([.large])
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var presentationContent: some View {
        NavigationStack {
            SwiftUI.Group {
                if isSelectedBridgePermitJoinOpen {
                    activeContent
                } else {
                    VStack(spacing: 0) {
                        Form {
                            bridgeSection
                            permitJoinSection
                        }
                        actionBar
                    }
                }
            }
            .navigationTitle("Permit Join")
            .navigationBarTitleDisplayMode(.inline)
        }
        .configuredTopScrollEdgeEffect()
    }

    private var fittedPresentationContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Permit Join")
                .font(.headline)
                .frame(maxWidth: .infinity)

            if isSelectedBridgePermitJoinOpen {
                activeContent
            } else {
                fittedInactiveContent
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.top, DesignTokens.Spacing.xxl)
        .padding(.bottom, DesignTokens.Spacing.lg)
    }

    private var fittedInactiveContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            let connected = environment.registry.orderedSessions.filter(\.isConnected)
            if connected.count >= 2 {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text("Bridge")
                        Spacer()
                        BridgePicker(selection: $bridgeID)
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.secondary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card))
                    Text("Permit Join opens this bridge's network only. Other bridges remain closed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Open the network")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    HStack {
                        Text("Via")
                        Spacer()
                        Picker("Via", selection: $targetName) {
                            Text("All devices").tag(String?.none)
                            ForEach(joinTargets) { device in
                                Text(device.friendlyName).tag(String?.some(device.friendlyName))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)

                    Divider()

                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("Duration", selection: $duration) {
                            Text("1 min").tag(60)
                            Text("2 min").tag(120)
                            Text("3 min").tag(180)
                            Text("~4 min").tag(254)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card))
            }

            actionBar
        }
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
            VStack(spacing: 0) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Network is open")
                        .font(.title3.weight(.semibold))
                    if let remaining = remainingSeconds(at: ctx.date) {
                        Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                            .font(DesignTokens.Typography.permitJoinActiveCountdown.monospacedDigit())
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(countsDown: true))
                            .accessibilityLabel("\(remaining / 60) minutes and \(remaining % 60) seconds remaining")
                    }
                    if let target = selectedBridgeInfo?.permitJoinTarget, !target.isEmpty {
                        Text("Pairing through \(target)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.top, DesignTokens.Spacing.xl)
                actionBar
            }
        }
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
            Text(isSelectedBridgePermitJoinOpen ? "Close Network" : "Open Network")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelectedBridgePermitJoinOpen ? .red : nil)
        .controlSize(.large)
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.bottom, DesignTokens.Spacing.md)
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
