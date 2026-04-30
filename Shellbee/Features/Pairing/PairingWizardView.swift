import SwiftUI

struct PairingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var model = PairingWizardModel()
    @State private var showCancelConfirm = false
    @State private var deviceToRename: Device?
    @State private var deviceToRemove: Device?
    @State private var pendingDeviceAlert: PendingDeviceAlert?

    private var isPermitOpen: Bool {
        environment.store.bridgeInfo?.permitJoin ?? false
    }

    private var sessionDevices: [Device] {
        model.sessionDevices(in: environment.store)
    }

    var body: some View {
        NavigationStack {
            List {
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
                    environment.renameDevice(from: device.friendlyName, to: newName, homeassistantRename: updateHA)
                }
            }
            .sheet(item: $deviceToRemove) { device in
                RemoveDeviceSheet(device: device) { force, block in
                    environment.send(topic: Z2MTopics.Request.deviceRemove, payload: .object([
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
                        environment.send(topic: Z2MTopics.Request.deviceConfigure,
                                         payload: .object(["id": .string(device.friendlyName)]))
                    case .interview(let device):
                        environment.send(topic: Z2MTopics.Request.deviceInterview,
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

    // MARK: - Permit join section

    @ViewBuilder
    private var permitJoinSection: some View {
        if isPermitOpen {
            Section {
                NetworkOpenRow(permitEnd: environment.store.bridgeInfo?.permitJoinEnd)
            } footer: {
                if sessionDevices.isEmpty {
                    networkOpenHint
                }
            }
        } else {
            PermitJoinControls(onStart: { duration, target in
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
        let state = environment.store.state(for: device.friendlyName)
        let isAvailable = environment.store.isAvailable(device.friendlyName)
        let otaStatus = environment.store.otaStatus(for: device.friendlyName)
        DeviceListRow(
            device: device,
            state: state,
            isAvailable: isAvailable,
            otaStatus: otaStatus,
            checkResult: environment.store.deviceCheckResults[device.friendlyName],
            isDeleting: environment.store.pendingRemovals.contains(device.friendlyName),
            isIdentifying: environment.store.identifyInProgress.contains(device.friendlyName),
            navigates: false,
            onRename: { deviceToRename = device },
            onRemove: { deviceToRemove = device },
            onReconfigure: { pendingDeviceAlert = .reconfigure(device) },
            onInterview: { pendingDeviceAlert = .interview(device) },
            onIdentify: { environment.identifyDevice(device.friendlyName) },
            onUpdate: state.hasUpdateAvailable
                ? {
                    environment.store.startOTAUpdate(for: device.friendlyName)
                    environment.send(topic: Z2MTopics.Request.deviceOTAUpdate,
                                     payload: .object(["id": .string(device.friendlyName)]))
                }
                : nil,
            onCheckUpdate: {
                environment.store.startOTACheck(for: device.friendlyName)
                environment.send(topic: Z2MTopics.Request.deviceOTACheck,
                                 payload: .object(["id": .string(device.friendlyName)]))
            },
            onSchedule: state.hasUpdateAvailable
                ? {
                    environment.store.startOTASchedule(for: device.friendlyName)
                    environment.send(topic: Z2MTopics.Request.deviceOTASchedule,
                                     payload: .object(["id": .string(device.friendlyName)]))
                }
                : nil,
            onUnschedule: {
                environment.store.cancelOTASchedule(for: device.friendlyName)
                environment.send(topic: Z2MTopics.Request.deviceOTAUnschedule,
                                 payload: .object(["id": .string(device.friendlyName)]))
            }
        )
    }

    private func sendPermitJoin(duration: Int, deviceName: String?) {
        var payload: [String: JSONValue] = ["time": .int(duration), "value": .bool(duration > 0)]
        if let deviceName, !deviceName.isEmpty { payload["device"] = .string(deviceName) }
        environment.send(topic: Z2MTopics.Request.permitJoin, payload: .object(payload))
    }
}

// MARK: - Permit-join controls (network closed)

private struct PermitJoinControls: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var duration: Int = 254
    @State private var targetName: String?
    let onStart: (Int, String?) -> Void

    var body: some View {
        Section {
            Picker("Duration", selection: $duration) {
                Text("1 min").tag(60)
                Text("2 min").tag(120)
                Text("3 min").tag(180)
                Text("~4 min").tag(254)
            }
            Picker("Via", selection: $targetName) {
                Text("All devices").tag(String?.none)
                ForEach(routerTargets, id: \.ieeeAddress) { device in
                    Text(device.friendlyName).tag(String?.some(device.friendlyName))
                }
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
        environment.store.devices
            .filter { $0.type == .router }
            .sorted { $0.friendlyName.localizedCompare($1.friendlyName) == .orderedAscending }
    }
}

// MARK: - Network-open status row

private struct NetworkOpenRow: View {
    let permitEnd: Int?

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
                    Text("Network is open")
                        .foregroundStyle(.primary)
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
