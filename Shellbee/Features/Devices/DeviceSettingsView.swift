import SwiftUI

struct DeviceSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let device: Device

    @State private var throttle: Int = 0
    @State private var retention: Int = 0
    @State private var debounce: Int = 0
    @State private var haName: String = ""
    @State private var showRename = false
    @FocusState private var haNameFocused: Bool

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var currentDevice: Device {
        scope.store.devices.first { $0.ieeeAddress == device.ieeeAddress } ?? device
    }

    /// Real Z2M ships per-device option values via `bridge/info.config.devices[ieee]`,
    /// not on the device entry in `bridge/devices`. Read both for compatibility
    /// (the docker seeder mirrors options onto the device entry too).
    private var optionValues: [String: JSONValue] {
        var merged = currentDevice.options ?? [:]
        if let cfg = scope.store.bridgeInfo?.config?.deviceConfig(for: currentDevice) {
            for (k, v) in cfg.raw { merged[k] = v }
        }
        return merged
    }

    private var deviceOptions: [Expose] {
        (currentDevice.definition?.options ?? []).flattenedLeaves
    }

    var body: some View {
        List {
            Section {
                Button {
                    showRename = true
                } label: {
                    Label("Rename Device", systemImage: "pencil")
                }
            }

            // Each device-specific option gets its own Section so the
            // description renders as a proper iOS-style footer beneath a
            // standard-height row — matches Settings > General etc.
            ForEach(Array(deviceOptions.enumerated()), id: \.offset) { index, expose in
                let key = expose.property ?? expose.name ?? ""
                Section {
                    DeviceOptionRow(
                        expose: expose,
                        currentValue: optionValues[key],
                        onChange: { sendOption(key, value: $0) }
                    )
                } header: {
                    if index == 0 { Text("Device Options") }
                } footer: {
                    if let desc = expose.description, !desc.isEmpty {
                        Text(desc)
                    }
                }
            }

            Section {
                Toggle("Retain", isOn: Binding(
                    get: { optionValues["retain"]?.boolValue ?? false },
                    set: { sendOption("retain", value: .bool($0)) }
                ))
                Picker("QoS", selection: Binding(
                    get: { optionValues["qos"]?.intValue ?? -1 },
                    set: { sendOption("qos", value: $0 < 0 ? .null : .int($0)) }
                )) {
                    Text("Default").tag(-1)
                    Text("QoS 0 — At most once").tag(0)
                    Text("QoS 1 — At least once").tag(1)
                    Text("QoS 2 — Exactly once").tag(2)
                }
                InlineIntField("Throttle", value: $throttle, unit: "s", range: 0...300, offLabel: "Off")
                    .onChange(of: throttle) { _, v in
                        sendOption("throttle", value: v == 0 ? .null : .int(v))
                    }
                InlineIntField("Retention", value: $retention, unit: "s", range: 0...86400, offLabel: "Off")
                    .onChange(of: retention) { _, v in
                        sendOption("retention", value: v == 0 ? .null : .int(v))
                    }
            } header: {
                Text("MQTT")
            } footer: {
                Text("Changes apply immediately.")
            }

            Section {
                Toggle("Optimistic", isOn: Binding(
                    get: { optionValues["optimistic"]?.boolValue ?? true },
                    set: { sendOption("optimistic", value: .bool($0)) }
                ))
                Toggle("Disabled", isOn: Binding(
                    get: { optionValues["disabled"]?.boolValue ?? currentDevice.disabled },
                    set: { sendOption("disabled", value: .bool($0)) }
                ))
                InlineIntField("Debounce", value: $debounce, unit: "s", range: 0...60, offLabel: "Off")
                    .onChange(of: debounce) { _, v in
                        sendOption("debounce", value: v == 0 ? .null : .int(v))
                    }
            } header: {
                Text("General")
            } footer: {
                Text("Disabled and Debounce require a Zigbee2MQTT restart.")
            }

            Section {
                LabeledContent("Device Name") {
                    TextField("Same as friendly name", text: $haName)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($haNameFocused)
                        .onChange(of: haNameFocused) { _, isFocused in
                            if !isFocused { sendHAName() }
                        }
                }
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Overrides the Home Assistant display name for this device.")
            }
        }
        .navigationTitle("Device Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncState() }
        .onChange(of: currentDevice.ieeeAddress) { _, _ in syncState() }
        .sheet(isPresented: $showRename) {
            RenameDeviceSheet(device: currentDevice) { newName, updateHA in
                environment.scope(for: bridgeID).renameDevice(
                    from: currentDevice.friendlyName,
                    to: newName,
                    homeassistantRename: updateHA
                )
            }
        }
    }

    private func syncState() {
        throttle = optionValues["throttle"]?.intValue ?? 0
        retention = optionValues["retention"]?.intValue ?? 0
        debounce = optionValues["debounce"]?.intValue ?? 0
        haName = optionValues["homeassistant"]?.object?["name"]?.stringValue ?? ""
    }

    private func sendHAName() {
        let value: JSONValue = haName.isEmpty ? .null : .object(["name": .string(haName)])
        sendOption("homeassistant", value: value)
    }

    private func sendOption(_ key: String, value: JSONValue) {
        // Use ieee_address as the canonical id (Z2M accepts both, but ieee
        // survives a friendly-name rename mid-flight).
        scope.send(
            topic: Z2MTopics.Request.deviceOptions,
            payload: .object([
                "id": .string(currentDevice.ieeeAddress),
                "options": .object([key: value])
            ])
        )
    }

}

// MARK: - Row for one definition.options entry

private struct DeviceOptionRow: View {
    let expose: Expose
    let currentValue: JSONValue?
    let onChange: (JSONValue) -> Void

    private var label: String {
        let base: String = {
            if let l = expose.label, !l.isEmpty { return l }
            let raw = expose.property ?? expose.name ?? ""
            return raw.replacingOccurrences(of: "_", with: " ")
        }()
        return Self.titleCase(base)
    }

    @ViewBuilder var body: some View {
        switch expose.type {
        case "binary":  BinaryOption(expose: expose, label: label, currentValue: currentValue, onChange: onChange)
        case "enum":    EnumOption(expose: expose, label: label, currentValue: currentValue, onChange: onChange)
        case "numeric": NumericOption(expose: expose, label: label, currentValue: currentValue, onChange: onChange)
        default:        textRow
        }
    }

    private var textRow: some View {
        LabeledContent(label) {
            Text(currentValue?.stringified ?? "—").foregroundStyle(.secondary)
        }
    }

    /// Title-case a label: "Hue native control" → "Hue Native Control".
    /// Preserves runs of uppercase (acronyms like "QoS", "RGB", "URL") so
    /// they don't get clobbered into "Qos" / "Rgb" / "Url".
    fileprivate static func titleCase(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: false).map { word -> String in
            guard let first = word.first else { return "" }
            // Word with multiple uppercase letters → leave as-is (RGB, QoS).
            let upperCount = word.filter { $0.isUppercase }.count
            if upperCount > 1 { return String(word) }
            return first.uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }
}

private let _knownUnitSeconds: Set<String> = [
    "transition", "throttle", "debounce", "retention",
]

// MARK: - Binary option (native Toggle; long-press to clear to default)

private struct BinaryOption: View {
    let expose: Expose
    let label: String
    let currentValue: JSONValue?
    let onChange: (JSONValue) -> Void

    @ViewBuilder
    var body: some View {
        let on = expose.valueOn ?? .bool(true)
        let off = expose.valueOff ?? .bool(false)
        let isOn = currentValue == on || (expose.valueOn == nil && currentValue?.boolValue == true)

        if !expose.isWritable {
            LabeledContent(label) {
                Text(isOn ? "On" : "Off").foregroundStyle(.secondary)
            }
        } else {
            Toggle(label, isOn: Binding(
                get: { isOn },
                set: { onChange($0 ? on : off) }
            ))
        }
    }
}

// MARK: - Enum option

private struct EnumOption: View {
    let expose: Expose
    let label: String
    let currentValue: JSONValue?
    let onChange: (JSONValue) -> Void

    var body: some View {
        let values = expose.values ?? []
        if expose.isWritable, !values.isEmpty {
            Picker(label, selection: Binding(
                get: { currentValue?.stringValue ?? "" },
                set: { newValue in
                    if newValue.isEmpty { onChange(.null) }
                    else { onChange(.string(newValue)) }
                }
            )) {
                Text("Default").tag("")
                ForEach(values, id: \.self) { v in
                    Text(displayValue(v)).tag(v)
                }
            }
        } else {
            LabeledContent(label) {
                Text(currentValue?.stringValue.map(displayValue) ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func displayValue(_ raw: String) -> String {
        DeviceOptionRow.titleCase(raw.replacingOccurrences(of: "_", with: " "))
    }
}

// MARK: - Numeric option (Double-aware, only writes on user commit)

private struct NumericOption: View {
    let expose: Expose
    let label: String
    let currentValue: JSONValue?
    let onChange: (JSONValue) -> Void

    @State private var text: String = ""
    @State private var didLoad: Bool = false
    @FocusState private var focused: Bool

    private var isFractional: Bool {
        if let step = expose.valueStep, step.truncatingRemainder(dividingBy: 1) != 0 { return true }
        return false
    }

    /// Resolve a unit to display alongside the value. The bridge sets
    /// `expose.unit` for most numerics, but generic options like `transition`
    /// ship without one even though their description says "in seconds".
    private var resolvedUnit: String? {
        if let u = expose.unit, !u.isEmpty { return u }
        let key = expose.property ?? expose.name ?? ""
        return _knownUnitSeconds.contains(key) ? "s" : nil
    }

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                TextField("Default", text: $text)
                    .keyboardType(isFractional ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .foregroundStyle(.secondary)
                if let unit = resolvedUnit {
                    Text(unit).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!expose.isWritable)
        .onAppear { if !didLoad { syncFromValue(); didLoad = true } }
        .onChange(of: currentValue) { _, _ in if !focused { syncFromValue() } }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }

    private func syncFromValue() {
        if let n = currentValue?.numberValue {
            text = formatNumber(n)
        } else {
            text = ""
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            onChange(.null)
            return
        }
        guard let parsed = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else {
            syncFromValue()
            return
        }
        var clamped = parsed
        if let lo = expose.valueMin { clamped = max(clamped, lo) }
        if let hi = expose.valueMax { clamped = min(clamped, hi) }
        onChange(.double(clamped))
        text = formatNumber(clamped)
    }

    private func formatNumber(_ n: Double) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(n))
            : String(n)
    }
}

#Preview {
    NavigationStack {
        DeviceSettingsView(bridgeID: UUID(), device: .preview)
            .environment(AppEnvironment())
    }
}
