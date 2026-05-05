import SwiftUI

struct LogDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewMode: ViewMode = .beautiful
    /// Phase 1 multi-bridge: source bridge for this log entry. Threaded
    /// through from the navigation route so device/group references inside
    /// the entry resolve against the right store.
    let bridgeID: UUID
    let entry: LogEntry
    private let doneAction: (() -> Void)?

    enum ViewMode { case beautiful, json }

    init(bridgeID: UUID, entry: LogEntry, doneAction: (() -> Void)? = nil) {
        self.bridgeID = bridgeID
        self.entry = entry
        self.doneAction = doneAction
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
        if entry.category == .stateChange {
            // Prefer the full state captured at log time when available — the
            // diff alone drops every unchanged field, which collapses the
            // Light Card to a single property even when the payload had
            // brightness/color_temp/color present. Fall back to the diff
            // for older entries that don't carry a payload.
            if let payload = entry.context?.payload, !payload.isEmpty {
                return payload
            }
            if let changes = entry.context?.stateChanges {
                var state: [String: JSONValue] = [:]
                for change in changes where !Self.stateMetadataKeys.contains(change.property) {
                    state[change.property] = change.to
                }
                return state.isEmpty ? nil : state
            }
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

            if viewMode == .beautiful {
                beautifulBody
            } else {
                jsonSection
            }
        }
        .contentMargins(.top, DesignTokens.Spacing.sm, for: .scrollContent)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Inline two-line title: subject on top, timestamp
                // beneath. Same pattern Apple Calendar uses for event
                // detail headers and Mail uses for thread headers.
                // Cleaner than the previous treatment: no info-icon, no
                // alert-banner styling — just title and quiet metadata.
                VStack(spacing: 1) {
                    Text(navTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(timestampSubtitle)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(navTitle), \(timestampSubtitle)")
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
        let members = scope.store.memberDevices(of: group)
        let groupState = members.reduce(into: [String: JSONValue]()) { acc, d in
            for (k, v) in scope.store.state(for: d.friendlyName) where acc[k] == nil {
                acc[k] = v
            }
        }
        Section {
            // ZStack + closure-based NavigationLink overlay — same pattern
            // as singleDeviceSection. Card's internal chevron is the only
            // disclosure indicator; List doesn't auto-add its own.
            ZStack {
                GroupCard(
                    group: group,
                    memberDevices: members,
                    state: groupState,
                    bridgeID: bridgeID,
                    bridgeName: environment.registry.session(for: bridgeID)?.displayName,
                    displayMode: .compact
                )
                NavigationLink {
                    GroupDetailView(bridgeID: bridgeID, group: group)
                } label: { EmptyView() }
                .opacity(0)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        if let (member, snapshotState) = lightLikeMemberAndState(in: members) {
            Section {
                ExposeCardView(device: member, state: snapshotState, mode: .snapshot)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    /// For a group log entry whose payload looks like a light state
    /// (`state` plus at least one of brightness/color_temp/color), pick a
    /// light member device to drive the snapshot Light Card. Returns nil
    /// when the payload isn't light-shaped or no light member exists —
    /// callers fall through to the generic field breakdown.
    private func lightLikeMemberAndState(in members: [Device]) -> (Device, [String: JSONValue])? {
        guard let payload = logTimeState else { return nil }
        let lightKeys: Set<String> = ["brightness", "color_temp", "color", "color_xy", "color_hs"]
        let hasLightShape = payload["state"] != nil && payload.keys.contains(where: { lightKeys.contains($0) })
        guard hasLightShape else { return nil }
        guard let member = members.first(where: { $0.category == .light }) else { return nil }
        return (member, payload)
    }

    @ViewBuilder
    private func singleDeviceSection(_ device: Device) -> some View {
        Section {
            // ZStack with a closure-based NavigationLink overlay: the card's
            // internal chevron is the only disclosure indicator (the List
            // doesn't auto-add its own because the row's primary content is
            // the card, not the link). Closure-based push avoids the
            // value-based path mixing that previously re-fired the row's
            // own NavigationLink.
            ZStack {
                DeviceCard(
                    device: device,
                    state: scope.store.state(for: device.friendlyName),
                    isAvailable: scope.store.isAvailable(device.friendlyName),
                    otaStatus: scope.store.otaStatus(for: device.friendlyName),
                    bridgeID: bridgeID,
                    bridgeName: environment.registry.session(for: bridgeID)?.displayName,
                    lastSeenEnabled: (scope.store.bridgeInfo?.config?.advanced?.lastSeen ?? "disable") != "disable",
                    displayMode: .compact
                )
                NavigationLink {
                    DeviceDetailView(bridgeID: bridgeID, device: device)
                } label: { EmptyView() }
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
        // Use `flattened` (every node, parents + leaves) rather than
        // `flattenedLeaves`. Z2M publishes nested features (notably the
        // `color_xy` / `color_hs` parents whose `property` resolves to
        // `"color"`) as a single object under the parent key — not as
        // separate top-level `x` / `y` keys. Filtering by leaves alone
        // dropped the entire color object, which is why the snapshot
        // Light Card never rendered the color surface even when the
        // payload carried a perfectly valid `color: {x, y}`.
        let exposeProps: Set<String> = Set(
            (device.definition?.exposes ?? []).flattened.compactMap {
                $0.property ?? $0.name
            }
        )
        let scoped = state.filter { exposeProps.contains($0.key) }
        return scoped.isEmpty ? nil : scoped
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
    private var beautifulBody: some View {
        let changes = entry.context?.stateChanges ?? []
        let payload: [String: JSONValue] = {
            if case .mqttPublish(_, _, let p) = entry.parsedMessageKind { return p }
            return [:]
        }()

        Section {
            if !changes.isEmpty {
                ForEach(changes) { change in
                    diffRow(for: change)
                }
            } else if !payload.isEmpty && entry.category != .stateChange {
                BeautifulPayloadView(payload: payload, device: displayDevices.first?.device)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } else if let structure = LogMessageParser.structure(for: entry.message) {
                Text(structure.summary)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.vertical, DesignTokens.Spacing.xs)
            } else {
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
            }
        } header: {
            eventHeader
        }

        // Structured-message extra groups (kept as standalone sections so
        // each labeled group of fields keeps its own header).
        if changes.isEmpty, payload.isEmpty,
           let structure = LogMessageParser.structure(for: entry.message) {
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
        }
    }

    /// Single uniform `key: prev → next` row used for every diff entry —
    /// matches the bottom-row pattern the issue called out as the right
    /// baseline. No special-case "IDLE card" or thermometer block: a value
    /// without a `from` simply renders without the prev half, same shape.
    @ViewBuilder
    private func diffRow(for change: LogContext.StateChange) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(change.displayLabel)
                .font(.subheadline)
            Spacer()
            if let from = change.displayFrom {
                Text(from)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(change.displayTo)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(diffColor(for: change))
        }
    }

    private func diffColor(for change: LogContext.StateChange) -> Color {
        switch change.to {
        case .string(let s) where s == "ON": return .green
        case .string(let s) where s == "OFF": return .red
        case .bool(true): return .green
        case .bool(false): return .red
        default: return .primary
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
}
