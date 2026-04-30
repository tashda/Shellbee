import SwiftUI

struct PairingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var model = PairingWizardModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(model.step.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        nextButton
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .permitJoin:
            PairingPermitJoinStep()
        case .discovery:
            PairingDiscoveryStep(model: model)
        case .actions:
            PairingActionsStep(model: model)
        }
    }

    @ViewBuilder
    private var nextButton: some View {
        switch model.step {
        case .permitJoin:
            Button("Next") { model.step = .discovery }
        case .discovery:
            let count = model.sessionDevices(in: environment.store).count
            Button(count == 0 ? "Skip" : "Continue") { model.step = .actions }
        case .actions:
            Button("Done") { dismiss() }
        }
    }
}

// MARK: - Step 1: Permit Join

private struct PairingPermitJoinStep: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var duration: Int = 254
    @State private var targetName: String?

    private var isPermitOpen: Bool {
        environment.store.bridgeInfo?.permitJoin ?? false
    }

    private var permitEnd: Int? {
        environment.store.bridgeInfo?.permitJoinEnd
    }

    var body: some View {
        Form {
            if isPermitOpen {
                Section {
                    activeStatusRow
                    Button(role: .destructive) {
                        sendPermitJoin(duration: 0, deviceName: nil)
                    } label: {
                        Label("Disable Join", systemImage: "stop.circle")
                    }
                } footer: {
                    Text("Put the device into pairing mode now. New devices will appear on the next step as they join.")
                }
            } else {
                Section {
                    Picker("Duration", selection: $duration) {
                        Text("1 min").tag(60)
                        Text("2 min").tag(120)
                        Text("3 min").tag(180)
                        Text("~4 min").tag(254)
                    }
                    Picker("Via", selection: $targetName) {
                        Text("All devices").tag(String?.none)
                        ForEach(routerTargets) { device in
                            Text(device.friendlyName).tag(String?.some(device.friendlyName))
                        }
                    }
                } header: {
                    Text("Open the network")
                } footer: {
                    Text("Zigbee networks support a maximum of 254 seconds per session. Routers can extend coverage to corners the coordinator can't reach.")
                }

                Section {
                    Button {
                        sendPermitJoin(duration: duration, deviceName: targetName)
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
        }
    }

    @ViewBuilder
    private var activeStatusRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = remainingSeconds(at: ctx.date)
            HStack {
                Image(systemName: "dot.radiowaves.up.forward")
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Network is open")
                        .font(.headline)
                    if let remaining {
                        Text(String(format: "%d:%02d remaining", remaining / 60, remaining % 60))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }

    private var routerTargets: [Device] {
        environment.store.devices
            .filter { $0.type == .router }
            .sorted { $0.friendlyName.localizedCompare($1.friendlyName) == .orderedAscending }
    }

    private func remainingSeconds(at date: Date) -> Int? {
        guard let end = permitEnd else { return nil }
        let now = Int(date.timeIntervalSince1970 * 1000)
        return max((end - now) / 1000, 0)
    }

    private func sendPermitJoin(duration: Int, deviceName: String?) {
        var payload: [String: JSONValue] = ["time": .int(duration), "value": .bool(duration > 0)]
        if let deviceName, !deviceName.isEmpty { payload["device"] = .string(deviceName) }
        environment.send(topic: Z2MTopics.Request.permitJoin, payload: .object(payload))
    }
}

// MARK: - Step 2: Discovery

private struct PairingDiscoveryStep: View {
    @Environment(AppEnvironment.self) private var environment
    let model: PairingWizardModel

    var body: some View {
        let devices = model.sessionDevices(in: environment.store)

        Form {
            Section {
                LabeledContent("Found") {
                    Text("\(devices.count) device\(devices.count == 1 ? "" : "s")")
                        .contentTransition(.numericText())
                        .monospacedDigit()
                }
            } footer: {
                Text(devices.isEmpty
                     ? "Devices that join during this session will appear here. If nothing shows up, make sure the device is in pairing mode and re-open the network on the previous step."
                     : "These devices joined during this pairing session. Continue to set them up.")
            }

            if !devices.isEmpty {
                Section("Joined") {
                    ForEach(devices, id: \.ieeeAddress) { device in
                        joinedRow(for: device)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func joinedRow(for device: Device) -> some View {
        let status = model.interviewStatus(for: device)
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: status.systemImage)
                .foregroundStyle(status == .completed ? .green : .secondary)
                .symbolEffect(.pulse, options: .repeating, isActive: status == .running)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(device.friendlyName)
                    .font(.headline)
                Text(device.modelId ?? device.definition?.model ?? device.ieeeAddress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Step 3: Actions

private struct PairingActionsStep: View {
    @Environment(AppEnvironment.self) private var environment
    let model: PairingWizardModel
    @State private var deviceToRename: Device?
    @State private var deviceToAddToGroup: Device?

    var body: some View {
        let devices = model.sessionDevices(in: environment.store)

        Form {
            if devices.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No new devices",
                        systemImage: "tray",
                        description: Text("No devices joined during this session. You can close the wizard or go back to open the network again.")
                    )
                }
            } else {
                ForEach(devices, id: \.ieeeAddress) { device in
                    deviceSection(for: device)
                }
            }
        }
        .sheet(item: $deviceToRename) { device in
            RenameDeviceSheet(device: device) { newName, updateHA in
                environment.renameDevice(from: device.friendlyName, to: newName, homeassistantRename: updateHA)
            }
        }
        .sheet(item: $deviceToAddToGroup) { device in
            PairingAddToGroupSheet(device: device)
        }
    }

    @ViewBuilder
    private func deviceSection(for device: Device) -> some View {
        Section {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(device.friendlyName)
                    .font(.headline)
                Text(device.modelId ?? device.definition?.model ?? device.ieeeAddress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, DesignTokens.Spacing.xs)

            if device.supportsIdentify {
                Button {
                    environment.identifyDevice(device.friendlyName)
                } label: {
                    let identifying = environment.store.identifyInProgress.contains(device.friendlyName)
                    Label(identifying ? "Identifying" : "Identify",
                          systemImage: identifying ? "wave.3.right" : "wave.3.right.circle")
                }
                .disabled(environment.store.identifyInProgress.contains(device.friendlyName))
            }

            Button {
                deviceToRename = device
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            if !environment.store.groups.isEmpty {
                Button {
                    deviceToAddToGroup = device
                } label: {
                    Label("Add to Group", systemImage: "rectangle.3.group")
                }
            }
        }
    }
}

// MARK: - Add to Group sheet

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
