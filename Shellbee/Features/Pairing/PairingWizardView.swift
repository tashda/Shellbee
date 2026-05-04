import SwiftUI

struct PairingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var model = PairingWizardModel()
    @State private var showCancelConfirm = false
    @State private var deviceToRename: Device?
    @State private var deviceToRemove: Device?
    @State private var pendingDeviceAlert: PendingDeviceAlert?
    /// Phase 2 multi-bridge: target bridge for the pairing session. Nil =
    /// focused bridge (single-bridge fallback). The picker auto-selects the
    /// first connected bridge on appear.
    @State private var bridgeID: UUID?

    /// Resolve picker selection or fall back to the selected bridge in the
    /// switcher. The wizard always operates on exactly one bridge; resolution
    /// is at the view boundary so all child reads/writes go through one scope.
    private var resolvedBridgeID: UUID? {
        bridgeID ?? environment.registry.primaryBridgeID
    }
    private var scope: BridgeScope {
        environment.scope(for: resolvedBridgeID ?? UUID())
    }
    private var store: AppStore { scope.store }

    private var isPermitOpen: Bool {
        store.bridgeInfo?.permitJoin ?? false
    }

    private var sessionDevices: [Device] {
        model.sessionDevices(in: store)
    }

    var body: some View {
        NavigationStack {
            List {
                bridgeSection
                permitJoinSection
                if !sessionDevices.isEmpty {
                    Section {
                        ForEach(sessionDevices, id: \.ieeeAddress) { device in
                            wizardRow(for: device)
                        }
                    } header: {
                        Text("New Devices")
                    } footer: {
                        Text("Swipe a device left or right for actions, or long-press for more options.")
                    }
                }
            }
            .navigationTitle("Add Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isPermitOpen {
                            showCancelConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                }
                if !sessionDevices.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Network is still open", isPresented: $showCancelConfirm) {
                Button("Keep Open") { dismiss() }
                Button("Close Network", role: .destructive) {
                    sendPermitJoin(duration: 0, deviceName: nil)
                    dismiss()
                }
            } message: {
                Text("Devices can still join until the timer runs out. Close it now or leave it open in the background?")
            }
            .sheet(item: $deviceToRename) { device in
                RenameDeviceSheet(device: device) { newName, updateHA in
                    sendDeviceRename(from: device.friendlyName, to: newName, homeassistantRename: updateHA)
                }
            }
            .sheet(item: $deviceToRemove) { device in
                RemoveDeviceSheet(device: device) { force, block in
                    scope.send(topic: Z2MTopics.Request.deviceRemove, payload: .object([
                        "id": .string(device.friendlyName),
                        "force": .bool(force),
                        "block": .bool(block)
                    ]))
                }
            }
            .alert(
                pendingDeviceAlert?.title ?? "",
                isPresented: Binding(
                    get: { pendingDeviceAlert != nil },
                    set: { if !$0 { pendingDeviceAlert = nil } }
                ),
                presenting: pendingDeviceAlert
            ) { alert in
                Button(alert.confirmTitle, role: alert.role) {
                    switch alert {
                    case .reconfigure(let device):
                        scope.send(topic: Z2MTopics.Request.deviceConfigure,
                                   payload: .object(["id": .string(device.friendlyName)]))
                    case .interview(let device):
                        scope.send(topic: Z2MTopics.Request.deviceInterview,
                                   payload: .object(["id": .string(device.friendlyName)]))
                    }
                    pendingDeviceAlert = nil
                }
                Button("Cancel", role: .cancel) { pendingDeviceAlert = nil }
            } message: { alert in
                Text(alert.message)
            }
        }
    }

    // MARK: - Bridge picker (multi-bridge only)

    @ViewBuilder
    private var bridgeSection: some View {
        let connected = environment.registry.orderedSessions.filter(\.isConnected)
        if connected.count >= 2 {
            Section {
                BridgePicker(selection: $bridgeID)
            } header: {
                Text("Add to")
            } footer: {
                Text("New devices join the selected bridge's network only.")
            }
        }
    }

    // MARK: - Permit join section

    @ViewBuilder
    private var permitJoinSection: some View {
        if isPermitOpen {
            Section {
                NetworkOpenRow(
                    permitEnd: store.bridgeInfo?.permitJoinEnd,
                    target: store.bridgeInfo?.permitJoinTarget
                )
            } footer: {
                if sessionDevices.isEmpty {
                    networkOpenHint
                }
            }
        } else {
            PermitJoinControls(scope: scope, onStart: { duration, target in
                sendPermitJoin(duration: duration, deviceName: target)
            })
        }
    }

    private var networkOpenHint: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Put your device into pairing mode now. New devices appear below as they join.")
            NavigationLink {
                DocBrowserView()
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "books.vertical")
                    Text("Not sure how? Browse the device library")
                }
                .font(.footnote)
            }
            .padding(.top, DesignTokens.Spacing.xs)
        }
    }

    // MARK: - Per-device row (reuses the live device list row)

    @ViewBuilder
    private func wizardRow(for device: Device) -> some View {
        let state = store.state(for: device.friendlyName)
        let isAvailable = store.isAvailable(device.friendlyName)
        let otaStatus = store.otaStatus(for: device.friendlyName)
        DeviceListRow(
            device: device,
            state: state,
            isAvailable: isAvailable,
            otaStatus: otaStatus,
            checkResult: store.deviceCheckResults[device.friendlyName],
            isDeleting: store.pendingRemovals.contains(device.friendlyName),
            isIdentifying: store.identifyInProgress.contains(device.friendlyName),
            navigates: false,
            onRename: { deviceToRename = device },
            onRemove: { deviceToRemove = device },
            onReconfigure: { pendingDeviceAlert = .reconfigure(device) },
            onInterview: { pendingDeviceAlert = .interview(device) },
            onIdentify: { identifyDevice(device.friendlyName) },
            onUpdate: state.hasUpdateAvailable
                ? {
                    store.startOTAUpdate(for: device.friendlyName)
                    scope.send(topic: Z2MTopics.Request.deviceOTAUpdate,
                               payload: .object(["id": .string(device.friendlyName)]))
                }
                : nil,
            onCheckUpdate: {
                store.startOTACheck(for: device.friendlyName)
                scope.send(topic: Z2MTopics.Request.deviceOTACheck,
                           payload: .object(["id": .string(device.friendlyName)]))
            },
            onSchedule: state.hasUpdateAvailable
                ? {
                    store.startOTASchedule(for: device.friendlyName)
                    scope.send(topic: Z2MTopics.Request.deviceOTASchedule,
                               payload: .object(["id": .string(device.friendlyName)]))
                }
                : nil,
            onUnschedule: {
                store.cancelOTASchedule(for: device.friendlyName)
                scope.send(topic: Z2MTopics.Request.deviceOTAUnschedule,
                           payload: .object(["id": .string(device.friendlyName)]))
            }
        )
    }

    private func identifyDevice(_ friendlyName: String) {
        guard !store.identifyInProgress.contains(friendlyName) else { return }
        store.identifyInProgress.insert(friendlyName)
        scope.send(
            topic: Z2MTopics.deviceSet(friendlyName),
            payload: .object(["identify": .string("identify")])
        )
        Task { [weak store] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { _ = store?.identifyInProgress.remove(friendlyName) }
        }
    }

    private func sendDeviceRename(from: String, to: String, homeassistantRename: Bool) {
        let trimmed = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != from else { return }
        store.optimisticRename(from: from, to: trimmed)
        scope.send(topic: Z2MTopics.Request.deviceRename, payload: .object([
            "from": .string(from),
            "to": .string(trimmed),
            "homeassistant_rename": .bool(homeassistantRename)
        ]))
    }

    private func sendPermitJoin(duration: Int, deviceName: String?) {
        var payload: [String: JSONValue] = ["time": .int(duration), "value": .bool(duration > 0)]
        if let deviceName, !deviceName.isEmpty { payload["device"] = .string(deviceName) }
        scope.send(topic: Z2MTopics.Request.permitJoin, payload: .object(payload))

        // Optimistically reflect the request in this bridge's bridgeInfo so
        // the wizard updates the moment the user taps — the bridge's
        // `permit_join` event will overwrite shortly.
        if let info = store.bridgeInfo {
            store.bridgeInfo = info.copyUpdatingPermitJoin(
                enabled: duration > 0,
                timeout: duration > 0 ? duration : nil,
                target: duration > 0 ? deviceName : nil
            )
        }
    }
}

// MARK: - Permit-join controls (network closed)

private struct PermitJoinControls: View {
    let scope: BridgeScope
    @State private var duration: Int = 254
    @State private var targetName: String?
    let onStart: (Int, String?) -> Void

    var body: some View {
        Section {
            Picker("Via", selection: $targetName) {
                Text("All devices").tag(String?.none)
                ForEach(routerTargets, id: \.ieeeAddress) { device in
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
        } footer: {
            Text("Put the device into pairing mode after you start. Routers can extend coverage to corners the coordinator can't reach.")
        }

        Section {
            Button {
                onStart(duration, targetName)
            } label: {
                Label("Start Permit Join", systemImage: "dot.radiowaves.up.forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var routerTargets: [Device] {
        scope.store.devices
            .filter { $0.type == .router }
            .sorted { $0.friendlyName.localizedCompare($1.friendlyName) == .orderedAscending }
    }
}

// MARK: - Network-open status row

private struct NetworkOpenRow: View {
    let permitEnd: Int?
    let target: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = remainingSeconds(at: ctx.date)
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "dot.radiowaves.up.forward")
                    .foregroundStyle(.white)
                    .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                    .background(.green, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 2) {
                    if let target, !target.isEmpty {
                        Text("Network is open via \(target)")
                            .foregroundStyle(.primary)
                    } else {
                        Text("Network is open")
                            .foregroundStyle(.primary)
                    }
                    if let remaining {
                        Text(String(format: "%d:%02d remaining", remaining / 60, remaining % 60))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                }
                Spacer()
            }
        }
    }

    private func remainingSeconds(at date: Date) -> Int? {
        guard let end = permitEnd else { return nil }
        let now = Int(date.timeIntervalSince1970 * 1000)
        return max((end - now) / 1000, 0)
    }
}

#Preview {
    PairingWizardView()
        .environment(AppEnvironment())
}
