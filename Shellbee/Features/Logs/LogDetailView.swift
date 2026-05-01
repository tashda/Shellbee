import SwiftUI

struct LogDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewMode: ViewMode = .beautiful
    let entry: LogEntry
    private let doneAction: (() -> Void)?

    enum ViewMode { case beautiful, json }

    init(entry: LogEntry, doneAction: (() -> Void)? = nil) {
        self.entry = entry
        self.doneAction = doneAction
    }

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
            environment.store.device(named: ref.friendlyName).map { (ref, $0) }
        }
    }

    private var payloadLinkQuality: Int? {
        guard case .mqttPublish(_, _, let payload) = entry.parsedMessageKind else { return nil }
        return payload.linkQuality
    }

    private static let stateMetadataKeys: Set<String> = [
        "linkquality", "last_seen", "update", "update_available", "device", "elapsed"
    ]

    private var logTimeState: [String: JSONValue]? {
        if case .mqttPublish(_, _, let payload) = entry.parsedMessageKind {
            return payload.isEmpty ? nil : payload
        }
        if entry.category == .stateChange, let changes = entry.context?.stateChanges {
            var state: [String: JSONValue] = [:]
            for change in changes where !Self.stateMetadataKeys.contains(change.property) {
                state[change.property] = change.to
            }
            return state.isEmpty ? nil : state
        }
        return nil
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
        if environment.store.device(named: name) != nil { return nil }
        return environment.store.group(named: name)
    }

    var body: some View {
        List {
            if let group = resolvedGroup {
                singleGroupSection(group)
            } else if displayDevices.count == 1, let (_, device) = displayDevices.first {
                singleDeviceSection(device)
            } else if displayDevices.count > 1 {
                LogDetailDevicesSection(devices: displayDevices)
            }

            if viewMode == .beautiful {
                beautifulBody
            } else {
                jsonSection
            }
        }
        .contentMargins(.top, DesignTokens.Spacing.sm, for: .scrollContent)
        .navigationTitle(headerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(headerTitle)
                        .font(.headline)
                    Text(timestampSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(headerTitle), \(timestampSubtitle)")
            }
            if let doneAction {
                if entry.category != .stateChange {
                    ToolbarItem(placement: .topBarTrailing) {
                        formatButton
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: doneAction)
                        .fontWeight(.semibold)
                }
            } else if entry.category != .stateChange {
                ToolbarItem(placement: .topBarTrailing) {
                    formatButton
                }
            }
        }
    }

    private var formatButton: some View {
        Button {
            viewMode = viewMode == .json ? .beautiful : .json
        } label: {
            Image(systemName: "curlybraces")
        }
        .tint(viewMode == .json ? .accentColor : .secondary)
        .accessibilityLabel("Format")
    }

    @ViewBuilder
    private func singleGroupSection(_ group: Group) -> some View {
        let members = environment.store.memberDevices(of: group)
        let groupState = members.reduce(into: [String: JSONValue]()) { acc, d in
            for (k, v) in environment.store.state(for: d.friendlyName) where acc[k] == nil {
                acc[k] = v
            }
        }
        Section {
            ZStack {
                GroupCard(
                    group: group,
                    memberDevices: members,
                    state: groupState,
                    displayMode: .compact
                )
                NavigationLink(destination: GroupDetailView(group: group)) { EmptyView() }
                    .opacity(0)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func singleDeviceSection(_ device: Device) -> some View {
        Section {
            ZStack {
                DeviceCard(
                    device: device,
                    state: environment.store.state(for: device.friendlyName),
                    isAvailable: environment.store.isAvailable(device.friendlyName),
                    otaStatus: environment.store.otaStatus(for: device.friendlyName),
                    lastSeenEnabled: (environment.store.bridgeInfo?.config?.advanced?.lastSeen ?? "disable") != "disable",
                    displayMode: .compact
                )
                NavigationLink(destination: DeviceDetailView(device: device)) { EmptyView() }
                    .opacity(0)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        if let state = exposesScopedState(for: device) {
            Section {
                ExposeCardView(device: device, state: state, mode: .snapshot)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    /// Filter `logTimeState` to only the keys that are actual exposes of this
    /// device. For bridge responses (payload `{data, error, status}`), nothing
    /// matches and we return nil — so the device section just shows the hero
    /// card. For real state publishes / state-change diffs, the payload keys
    /// match exposes and we render the relevant control card with those values.
    private func exposesScopedState(for device: Device) -> [String: JSONValue]? {
        guard let state = logTimeState else { return nil }
        let exposeProps: Set<String> = Set(
            (device.definition?.exposes ?? []).flattenedLeaves.compactMap {
                $0.property ?? $0.name
            }
        )
        let scoped = state.filter { exposeProps.contains($0.key) }
        return scoped.isEmpty ? nil : scoped
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

    private var headerTitle: String {
        entry.category == .general ? entry.level.label : entry.category.label
    }

    @ViewBuilder
    private var beautifulBody: some View {
        let changes = entry.context?.stateChanges ?? []
        let payload: [String: JSONValue] = {
            if case .mqttPublish(_, _, let p) = entry.parsedMessageKind { return p }
            return [:]
        }()

        if !changes.isEmpty {
            LogDetailChangesSection(changes: changes)
        }
        // Skip the full-payload snapshot for state-change events — the diff is
        // what actually happened, the rest is noise.
        if !payload.isEmpty && entry.category != .stateChange {
            BeautifulPayloadView(payload: payload, device: displayDevices.first?.device)
        }
        if changes.isEmpty && payload.isEmpty {
            messageSection
        }
    }

    private var messageSection: some View {
        let (summary, detail) = parsedMessage
        return Section(sectionTitle) {
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
        }
    }

    private var sectionTitle: String {
        switch entry.level {
        case .error: "Error"
        case .warning: "Warning"
        default: "Message"
        }
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
        LogDetailView(entry: LogEntry.previewEntries[3])
            .environment(AppEnvironment())
    }
}
