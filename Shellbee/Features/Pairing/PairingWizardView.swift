import SwiftUI

struct PairingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var model = PairingWizardModel()
    @State private var showCancelConfirm = false
    @State private var deviceToRename: Device?
    @State private var deviceToRemove: Device?
    @State private var deviceForGroupPicker: Device?

    private var isPermitOpen: Bool {
        environment.store.bridgeInfo?.permitJoin ?? false
    }

    private var sessionDevices: [Device] {
        model.sessionDevices(in: environment.store)
    }

    var body: some View {
        NavigationStack {
            Form {
                permitJoinSection
                if !sessionDevices.isEmpty {
                    devicesSection
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
            }
            .confirmationDialog(
                "Network is still open",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Keep Open", role: .cancel) { dismiss() }
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
            .sheet(item: $deviceForGroupPicker) { device in
                PairingAddToGroupSheet(device: device)
            }
        }
    }

    // MARK: - Permit join section

    @ViewBuilder
    private var permitJoinSection: some View {
        if isPermitOpen {
            Section {
                NetworkOpenRow(permitEnd: environment.store.bridgeInfo?.permitJoinEnd)
                Button(role: .destructive) {
                    sendPermitJoin(duration: 0, deviceName: nil)
                } label: {
                    Label("Disable Join", systemImage: "stop.circle")
                }
            } footer: {
                Text(sessionDevices.isEmpty
                     ? "Put the device into pairing mode now. New devices appear below as they join."
                     : "More devices can still join. Close the network when you're done.")
            }
        } else {
            PermitJoinControls(onStart: { duration, target in
                sendPermitJoin(duration: duration, deviceName: target)
            })
        }
    }

    // MARK: - Devices section

    @ViewBuilder
    private var devicesSection: some View {
        ForEach(sessionDevices, id: \.ieeeAddress) { device in
            Section {
                DeviceJoinedHeader(device: device, status: model.interviewStatus(for: device))
                deviceActions(for: device)
            }
        }
    }

    @ViewBuilder
    private func deviceActions(for device: Device) -> some View {
        let status = model.interviewStatus(for: device)
        let interviewing = status == .running

        if device.supportsIdentify {
            Button {
                environment.identifyDevice(device.friendlyName)
            } label: {
                let identifying = environment.store.identifyInProgress.contains(device.friendlyName)
                actionRow(
                    title: identifying ? "Identifying" : "Identify",
                    systemImage: identifying ? "wave.3.right" : "wave.3.right.circle",
                    tint: .teal
                )
            }
            .disabled(interviewing || environment.store.identifyInProgress.contains(device.friendlyName))
        }

        Button {
            deviceToRename = device
        } label: {
            actionRow(title: "Rename", systemImage: "pencil", tint: .orange)
        }
        .disabled(interviewing)

        if !environment.store.groups.isEmpty {
            Button {
                deviceForGroupPicker = device
            } label: {
                actionRow(title: "Add to Group", systemImage: "rectangle.3.group", tint: .blue)
            }
            .disabled(interviewing)
        }

        if device.definition?.supportsOTA == true {
            Button {
                environment.store.startOTACheck(for: device.friendlyName)
                environment.send(
                    topic: Z2MTopics.Request.deviceOTACheck,
                    payload: .object(["id": .string(device.friendlyName)])
                )
            } label: {
                actionRow(title: "Check for Update", systemImage: "arrow.trianglehead.2.clockwise", tint: .indigo)
            }
            .disabled(interviewing)
        }

        Button(role: .destructive) {
            deviceToRemove = device
        } label: {
            actionRow(title: "Remove", systemImage: "trash", tint: .red)
        }
        .disabled(interviewing)
    }

    private func actionRow(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                .background(tint, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
        }
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

// MARK: - Per-device header

private struct DeviceJoinedHeader: View {
    let device: Device
    let status: PairingWizardModel.InterviewStatus

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: status.systemImage)
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                .background(statusColor, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
                .symbolEffect(.pulse, options: .repeating, isActive: status == .running)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.friendlyName)
                    .font(.headline)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var detailLine: String {
        let model = device.definition?.model ?? device.modelId ?? device.ieeeAddress
        return "\(model) · \(status.label)"
    }

    private var statusColor: Color {
        switch status {
        case .completed: .green
        case .running:   .orange
        case .pending:   .gray
        }
    }
}

// MARK: - Add-to-group sheet

private struct PairingAddToGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let device: Device

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if environment.store.groups.isEmpty {
                        Text("No groups defined yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(environment.store.groups, id: \.id) { group in
                            Button {
                                add(to: group)
                            } label: {
                                HStack {
                                    Text(group.friendlyName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(group.members.count)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Adds \(device.friendlyName) to the selected group. Group commands sent to that group will then include this device.")
                }
            }
            .navigationTitle("Add to Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add(to group: Group) {
        environment.send(topic: Z2MTopics.Request.groupMembersAdd, payload: .object([
            "group": .string(group.friendlyName),
            "device": .string(device.friendlyName)
        ]))
        dismiss()
    }
}

#Preview {
    PairingWizardView()
        .environment(AppEnvironment())
}
