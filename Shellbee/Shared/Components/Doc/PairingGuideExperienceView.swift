import SwiftUI

/// The How to pair sheet: a checklist of the documented steps with a glass
/// bar that opens the network on one bridge. A device that joins while the
/// guide is open appears at the top with its interview state, and the
/// checklist ticks itself off once it's paired.
struct PairingGuideExperienceView: View {
    let device: Device
    let identity: DeviceDocIdentity
    let pairing: DevicePairingGuide?
    let sourcePath: String?
    /// The bridge the live bar pairs on. Nil hides the bar.
    let bridgeID: UUID?

    @Environment(AppEnvironment.self) private var environment
    @State private var session = PairingWizardModel()
    @State private var checked: Set<String> = []
    @State private var deviceToRename: Device?

    private var scope: BridgeScope? {
        guard let bridgeID else { return nil }
        let scope = environment.scope(for: bridgeID)
        return scope.isConnected ? scope : nil
    }

    private var sessionDevices: [Device] {
        scope.map { session.sessionDevices(in: $0.store) } ?? []
    }

    var body: some View {
        if let pairing {
            guide(pairing)
        } else {
            ContentUnavailableView(
                "No Pairing Guide",
                systemImage: "personalhotspot.slash",
                description: Text("Pairing instructions aren't documented for \(identity.displayName).")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shellbeeThemedCanvas()
        }
    }

    private func guide(_ pairing: DevicePairingGuide) -> some View {
        List {
            SwiftUI.Group {
                Section {
                    identityRow
                } footer: {
                    if !pairing.summary.isEmpty {
                        DocInlineTextView(spans: pairing.summary, sourcePath: sourcePath)
                    }
                }
                joinedSection
                checklist("Before you start", items: pairing.prerequisites, key: "pre", numbered: false)
                checklist("Steps", items: pairing.primarySteps.map(\.spans), key: "step", numbered: true)
                spansSection("It worked when", items: pairing.successCues, systemImage: "checkmark.circle")
                spansSection("If it didn't work", items: pairing.troubleshooting, systemImage: "questionmark.circle")
                if !pairing.alternatives.isEmpty {
                    PairingAlternativesSection(methods: pairing.alternatives, sourcePath: sourcePath, bridgeID: bridgeID)
                }
                if !pairing.additionalNotes.isEmpty {
                    Section("Notes") {
                        ForEach(Array(pairing.additionalNotes.enumerated()), id: \.offset) { _, block in
                            DocBlockView(block: block, sourcePath: sourcePath)
                        }
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if let scope {
                PairingLiveBar(bridgeID: scope.bridgeID, sessionDevices: sessionDevices) { deviceToRename = $0 }
            }
        }
        .shellbeeThemedCanvas()
        .onChange(of: sessionDevices.contains { $0.interviewCompleted }) { _, paired in
            guard paired else { return }
            withAnimation(.snappy) { checked = allKeys(pairing) }
        }
        .sheet(item: $deviceToRename) { device in
            RenameDeviceSheet(device: device) { newName, updateHA in
                scope?.renameDevice(from: device.friendlyName, to: newName, homeassistantRename: updateHA)
            }
        }
    }

    // MARK: - Sections

    private var identityRow: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DeviceImageView(device: device, isAvailable: true, showsAvailabilityIndicator: false)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(identity.displayName)
                    .font(.headline)
                Text(identity.vendorAndModel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var joinedSection: some View {
        if let scope, !sessionDevices.isEmpty {
            Section("Joined") {
                ForEach(sessionDevices, id: \.ieeeAddress) { joined in
                    NavigationLink {
                        DeviceDetailView(bridgeID: scope.bridgeID, device: joined)
                    } label: {
                        JoinedDeviceRow(device: joined, status: session.interviewStatus(for: joined))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func checklist(_ title: String, items: [[InlineSpan]], key: String, numbered: Bool) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, spans in
                    let id = "\(key)-\(index)"
                    let isChecked = checked.contains(id)
                    Button {
                        withAnimation(.snappy) { toggle(id) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                            DocStepNumber(number: numbered ? index + 1 : nil, isChecked: isChecked)
                            DocInlineTextView(spans: spans, sourcePath: sourcePath)
                                .foregroundStyle(isChecked ? .secondary : .primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isChecked ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private func spansSection(_ title: String, items: [[InlineSpan]], systemImage: String) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, spans in
                    Label {
                        DocInlineTextView(spans: spans, sourcePath: sourcePath)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: systemImage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Checklist state

    private func toggle(_ id: String) {
        if checked.contains(id) { checked.remove(id) } else { checked.insert(id) }
    }

    private func allKeys(_ pairing: DevicePairingGuide) -> Set<String> {
        Set(pairing.prerequisites.indices.map { "pre-\($0)" } + pairing.primarySteps.indices.map { "step-\($0)" })
    }
}

private struct JoinedDeviceRow: View {
    let device: Device
    let status: PairingWizardModel.InterviewStatus

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DeviceImageView(device: device, isAvailable: true, showsAvailabilityIndicator: false)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(device.friendlyName)
                    .lineLimit(1)
                Text(device.cardSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            statusView
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if device.interviewState == .failed {
            Text("Interview failed")
                .font(.subheadline)
                .foregroundStyle(.themedStatus(.orange))
        } else if status == .running {
            ProgressView()
        } else {
            Text(status.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
