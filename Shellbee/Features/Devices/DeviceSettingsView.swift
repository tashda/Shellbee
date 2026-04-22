import SwiftUI

struct DeviceSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device

    @State private var throttle: Int = 0
    @State private var retention: Int = 0
    @State private var debounce: Int = 0
    @State private var haName: String = ""
    @State private var showRename = false
    @FocusState private var haNameFocused: Bool

    private var currentDevice: Device {
        environment.store.devices.first { $0.ieeeAddress == device.ieeeAddress } ?? device
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

            if !deviceOptions.isEmpty {
                Section("Device Options") {
                    ForEach(deviceOptions, id: \.property) { expose in
                        let key = expose.property ?? expose.name ?? ""
                        DeviceOptionRow(
                            expose: expose,
                            currentValue: currentDevice.options?[key],
                            onChange: { sendOption(key, value: $0) }
                        )
                    }
                }
            }

            Section {
                Toggle("Retain", isOn: Binding(
                    get: { currentDevice.options?["retain"]?.boolValue ?? false },
                    set: { sendOption("retain", value: .bool($0)) }
                ))
                Picker("QoS", selection: Binding(
                    get: { currentDevice.options?["qos"]?.intValue ?? -1 },
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
                    get: { currentDevice.options?["optimistic"]?.boolValue ?? true },
                    set: { sendOption("optimistic", value: .bool($0)) }
                ))
                Toggle("Disabled", isOn: Binding(
                    get: { currentDevice.options?["disabled"]?.boolValue ?? currentDevice.disabled },
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
                environment.send(topic: Z2MTopics.Request.deviceRename, payload: .object([
                    "from": .string(currentDevice.friendlyName),
                    "to": .string(newName),
                    "homeassistant_rename": .bool(updateHA)
                ]))
            }
        }
    }

    private func syncState() {
        throttle = currentDevice.options?["throttle"]?.intValue ?? 0
        retention = currentDevice.options?["retention"]?.intValue ?? 0
        debounce = currentDevice.options?["debounce"]?.intValue ?? 0
        haName = currentDevice.options?["homeassistant"]?.object?["name"]?.stringValue ?? ""
    }

    private func sendHAName() {
        let value: JSONValue = haName.isEmpty ? .null : .object(["name": .string(haName)])
        sendOption("homeassistant", value: value)
    }

    private func sendOption(_ key: String, value: JSONValue) {
        environment.send(
            topic: Z2MTopics.Request.deviceOptions,
            payload: .object([
                "id": .string(currentDevice.friendlyName),
                "options": .object([key: value])
            ])
        )
    }

}

private struct DeviceOptionRow: View {
    let expose: Expose
    let currentValue: JSONValue?
    let onChange: (JSONValue) -> Void

    @State private var numericInt: Int = 0

    private var label: String {
        let raw = expose.property ?? expose.name ?? ""
        return expose.label ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        switch expose.type {
        case "binary":  binaryRow
        case "enum":    enumRow
        case "numeric": numericRow
        default:        textRow
        }
    }

    @ViewBuilder private var binaryRow: some View {
        let isOn = currentValue == expose.valueOn || currentValue?.boolValue == true
        if expose.isWritable, let on = expose.valueOn, let off = expose.valueOff {
            Toggle(label, isOn: Binding(get: { isOn }, set: { onChange($0 ? on : off) }))
        } else {
            LabeledContent(label) { Text(isOn ? "On" : "Off").foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var enumRow: some View {
        let values = expose.values ?? []
        if expose.isWritable, !values.isEmpty {
            Picker(label, selection: Binding(
                get: { currentValue?.stringValue ?? values.first ?? "" },
                set: { onChange(.string($0)) }
            )) {
                ForEach(values, id: \.self) { v in
                    Text(v.replacingOccurrences(of: "_", with: " ").capitalized).tag(v)
                }
            }
        } else {
            LabeledContent(label) {
                Text(currentValue?.stringValue?.replacingOccurrences(of: "_", with: " ").capitalized ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var numericRow: some View {
        let range: ClosedRange<Int>? = {
            guard let lo = expose.valueMin, let hi = expose.valueMax else { return nil }
            return Int(lo)...Int(hi)
        }()
        InlineIntField(
            label,
            value: $numericInt,
            unit: expose.unit ?? "",
            range: range
        )
        .onAppear { numericInt = Int(currentValue?.numberValue ?? expose.valueMin ?? 0) }
        .onChange(of: numericInt) { _, v in onChange(.double(Double(v))) }
    }

    private var textRow: some View {
        LabeledContent(label) { Text(currentValue?.stringified ?? "—").foregroundStyle(.secondary) }
    }
}

#Preview {
    NavigationStack {
        DeviceSettingsView(device: .preview)
            .environment(AppEnvironment())
    }
}
