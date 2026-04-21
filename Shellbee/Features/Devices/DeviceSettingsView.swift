import SwiftUI

struct DeviceSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device

    @State private var throttle: Int = 0
    @State private var retention: Int = 0

    private var currentDevice: Device {
        environment.store.devices.first { $0.ieeeAddress == device.ieeeAddress } ?? device
    }

    private var deviceOptions: [Expose] {
        flatten(currentDevice.definition?.options ?? [])
    }

    var body: some View {
        List {
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
                Toggle("Optimistic", isOn: Binding(
                    get: { currentDevice.options?["optimistic"]?.boolValue ?? true },
                    set: { sendOption("optimistic", value: .bool($0)) }
                ))
                Toggle("Retain Messages", isOn: Binding(
                    get: { currentDevice.options?["retain"]?.boolValue ?? false },
                    set: { sendOption("retain", value: .bool($0)) }
                ))
                Picker("Quality of Service", selection: Binding(
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
                Text("General")
            } footer: {
                Text("Changes apply immediately.")
            }
        }
        .navigationTitle("Device Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            throttle = currentDevice.options?["throttle"]?.intValue ?? 0
            retention = currentDevice.options?["retention"]?.intValue ?? 0
        }
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

    private func flatten(_ exposes: [Expose]) -> [Expose] {
        exposes.flatMap { e in (e.features?.isEmpty == false) ? flatten(e.features ?? []) : [e] }
    }
}

private struct DeviceOptionRow: View {
    let expose: Expose
    let currentValue: JSONValue?
    let onChange: (JSONValue) -> Void

    @State private var numericDraft: Double = 0

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
        let unit = expose.unit.map { " \($0)" } ?? ""
        LabeledContent(label) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("\(Int(numericDraft))\(unit)").foregroundStyle(.secondary).monospacedDigit()
                Stepper("", value: Binding(
                    get: { numericDraft },
                    set: { numericDraft = $0; onChange(.double($0)) }
                ), in: (expose.valueMin ?? 0)...(expose.valueMax ?? 100), step: expose.valueStep ?? 1)
                .labelsHidden()
            }
        }
        .onAppear { numericDraft = currentValue?.numberValue ?? expose.valueMin ?? 0 }
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
