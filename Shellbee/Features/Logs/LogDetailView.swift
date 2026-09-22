import SwiftUI

struct LogDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewMode: ViewMode = .parsed
    /// Phase 1 multi-bridge: source bridge for this log entry. Threaded
    /// through from the navigation route so device/group references inside
    /// the entry resolve against the right store.
    let bridgeID: UUID
    let entry: LogEntry

    enum ViewMode { case parsed, json }

    init(bridgeID: UUID, entry: LogEntry) {
        self.bridgeID = bridgeID
        self.entry = entry
    }

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var displayDevices: [(ref: LogContext.DeviceRef, device: Device)] {
        let refs: [LogContext.DeviceRef]
        if let ctx = entry.context, !ctx.devices.isEmpty {
            refs = ctx.devices
        } else {
            let name = entry.deviceName ?? {
                if case .mqttPublish(let d, _, _) = entry.parsedMessageKind { return d }
                return nil
            }()
            refs = name.map { [LogContext.DeviceRef(friendlyName: $0, role: nil)] } ?? []
        }
        return refs.compactMap { ref in
            scope.store.device(named: ref.friendlyName).map { (ref, $0) }
        }
    }

    private var resolvedGroup: Group? {
        let candidate: String?
        if let ctx = entry.context, !ctx.devices.isEmpty {
            candidate = ctx.devices.first?.friendlyName
        } else if let n = entry.deviceName {
            candidate = n
        } else if case .mqttPublish(let d, _, _) = entry.parsedMessageKind {
            candidate = d
        } else {
            candidate = nil
        }
        guard let name = candidate else { return nil }
        // Only resolve as group when no real device exists with that name
        if scope.store.device(named: name) != nil { return nil }
        return scope.store.group(named: name)
    }

    var body: some View {
        List {
            if let group = resolvedGroup {
                singleGroupSection(group)
            } else if displayDevices.count == 1, let (_, device) = displayDevices.first {
                singleDeviceSection(device)
            } else if displayDevices.count > 1 {
                LogDetailDevicesSection(bridgeID: bridgeID, devices: displayDevices)
            }

            if viewMode == .parsed {
                parsedBody
            } else {
                jsonSection
            }

        }
        .contentMargins(.top, DesignTokens.Spacing.sm, for: .scrollContent)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                OpenInNewWindowButton(destination: .log(
                    bridgeID: bridgeID,
                    entryID: entry.id
                ))
            }
            ToolbarItem(placement: .topBarTrailing) {
                formatButton
            }
        }
    }

    private var formatButton: some View {
        Button {
            viewMode = viewMode == .json ? .parsed : .json
        } label: {
            Image(systemName: "curlybraces")
        }
        .tint(viewMode == .json ? .accentColor : .secondary)
        .accessibilityLabel(viewMode == .json ? "Show formatted activity" : "Show raw message")
    }

    /// The group as one native row that opens Group detail.
    private func singleGroupSection(_ group: Group) -> some View {
        let members = scope.store.memberDevices(of: group)
        return Section {
            NavigationLink {
                GroupDetailView(bridgeID: bridgeID, group: group)
            } label: {
                GroupCard(
                    group: group,
                    memberDevices: members,
                    state: [:],
                    bridgeID: bridgeID,
                    bridgeName: environment.attributionBridgeName(for: bridgeID),
                    displayMode: .compact
                )
            }
        }
    }

    /// The device as one native row that opens Device detail. Closure-based
    /// push, so it doesn't mix with the value-based path that got us here.
    private func singleDeviceSection(_ device: Device) -> some View {
        Section {
            NavigationLink {
                DeviceDetailView(bridgeID: bridgeID, device: device)
            } label: {
                DeviceCard(
                    device: device,
                    state: scope.store.state(for: device.friendlyName),
                    isAvailable: scope.store.isAvailable(device.friendlyName),
                    otaStatus: scope.store.otaStatus(for: device.friendlyName),
                    bridgeID: bridgeID,
                    bridgeName: environment.attributionBridgeName(for: bridgeID),
                    displayMode: .compact
                )
            }
        }
    }

    /// Title for the navigation bar. The user tapped a row about a
    /// specific subject — Apple's pattern is to make the subject the page
    /// title (Mail puts the sender, Messages puts the contact). For
    /// non-device events we fall back to a quiet category label.
    private var navTitle: String {
        if let group = resolvedGroup { return group.friendlyName }
        if displayDevices.count == 1, let (_, device) = displayDevices.first {
            return device.friendlyName
        }
        if displayDevices.count > 1 { return "Activity" }
        switch entry.category {
        case .deviceJoined, .deviceAnnounce, .deviceLeave, .interview, .availability:
            return entry.deviceName ?? entry.category.label
        case .stateChange: return "Activity"
        case .bridgeState: return "Bridge"
        case .bridgeActivity: return entry.bridgeTopicDisplay?.title ?? "Bridge"
        case .permitJoin: return "Pairing"
        case .general:
            switch entry.level {
            case .error: return "Error"
            case .warning: return "Warning"
            default: return "Activity"
            }
        }
    }

    private var timestampSubtitle: String {
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(entry.timestamp) {
            day = "Today"
        } else if cal.isDateInYesterday(entry.timestamp) {
            day = "Yesterday"
        } else {
            day = entry.timestamp.formatted(.dateTime.month(.abbreviated).day())
        }
        let time = entry.timestamp.formatted(.dateTime.hour().minute().second())
        return "\(day) at \(time)"
    }

    private var jsonSection: some View {
        Section("Raw Message") {
            Text(entry.message)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }

    @ViewBuilder
    private var parsedBody: some View {
        let changes = entry.context?.stateChanges ?? []
        let payload: [String: JSONValue] = {
            if case .mqttPublish(_, _, let p) = entry.parsedMessageKind { return p }
            return [:]
        }()
        let topic: String? = {
            if case .mqttPublish(_, let t, _) = entry.parsedMessageKind { return t }
            return nil
        }()

        // bridge/health gets a dedicated detail renderer that maps the
        // `devices` IEEE map to per-device cards instead of dumping
        // "0X000…1234: 4 properties" rows the user can't decipher.
        // `hasSuffix` because Z2M prepends the configurable MQTT base
        // (default `zigbee2mqtt/`) to the topic; we want to match the
        // canonical sub-topic regardless of how the user has it set.
        if topic?.hasSuffix("bridge/health") == true {
            LogHealthDetailSections(payload: payload, store: scope.store)
        } else {
            payloadBody(changes: changes, payload: payload)
        }
    }

    @ViewBuilder
    private func payloadBody(
        changes: [LogContext.StateChange],
        payload: [String: JSONValue]
    ) -> some View {
        if !changes.isEmpty {
            let rows = LogChangeRows.rows(for: changes, payload: entry.context?.payload)
            Section("Changes") {
                LabeledContent("Changed") {
                    Text(timestampSubtitle)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if rows.isEmpty {
                    Text("Reported again with the same values")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { LogChangeRowView(row: $0) }
                }
            }
        } else if !payload.isEmpty && entry.category != .stateChange {
            // PayloadSectionsView produces its own Sections — render at
            // the top level so each section gets a real header (Status,
            // Data, Firmware, etc.) the way iOS Settings detail screens
            // do. Wrapping it in another Section would nest sections,
            // which SwiftUI silently drops.
            PayloadSectionsView(payload: payload, device: displayDevices.first?.device)
        } else if let structure = LogMessageParser.structure(for: entry.message) {
            // Structured message: top-level summary sits in its own
            // section under the event header; structured fields/groups
            // get their own real sections beneath.
            Section {
                Text(structure.summary)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.vertical, DesignTokens.Spacing.xs)
            } header: {
                eventHeader
            }
            ForEach(structure.fields) { field in
                Section { CopyableRow(label: field.label, value: field.value) }
            }
            ForEach(structure.groups) { group in
                Section(group.title) {
                    ForEach(group.fields) { field in
                        CopyableRow(label: field.label, value: field.value)
                    }
                }
            }
        } else {
            Section {
                let (summary, detail) = parsedMessage
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(summary)
                        .font(.callout)
                        .textSelection(.enabled)
                    if let detail {
                        Text(detail)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            } header: {
                eventHeader
            }
        }
    }

    /// Body section header. Plain noun in the iOS Settings idiom —
    /// "Signal", "Humidity", "Battery", "Interview". The verb lives in
    /// the diff rows beneath; the timestamp lives in the nav-bar subtitle
    /// at the top of the screen.
    private var eventHeader: some View {
        Text(entry.bodyHeader)
    }

    private var parsedMessage: (summary: String, detail: String?) {
        let cleaned = stripNamespace(entry.message)

        if case .publishFailure(let command) = entry.context?.action {
            let summary = "Command '\(command)' failed"
            return (summary, errorDetail(from: cleaned) ?? cleaned)
        }

        if let colon = cleaned.range(of: ": "),
           cleaned[colon.upperBound...].contains("'") {
            let head = String(cleaned[..<colon.lowerBound])
            let tail = String(cleaned[colon.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "' "))
            if !tail.isEmpty { return (head, tail) }
        }

        return (cleaned, nil)
    }

    private func stripNamespace(_ text: String) -> String {
        guard text.hasPrefix("z2m:") else { return text }
        if let sp = text.range(of: " ") {
            return String(text[sp.upperBound...])
        }
        return text
    }

    private func errorDetail(from text: String) -> String? {
        guard let colon = text.range(of: ": ") else { return nil }
        let tail = String(text[colon.upperBound...])
        return tail.trimmingCharacters(in: CharacterSet(charactersIn: "' "))
    }
}

#Preview {
    NavigationStack {
        LogDetailView(bridgeID: UUID(), entry: LogEntry.previewEntries[3])
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
