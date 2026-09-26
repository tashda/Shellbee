import SwiftUI

/// A remote as native List sections: its last press in words, when it was
/// pressed as the footer, and its battery voltage under Diagnostics. A
/// remote has nothing to control in the app, so it gets no card.
struct RemoteSections: View {
    let device: Device
    let state: [String: JSONValue]

    static let claimedProperties: Set<String> = ["action", "voltage"]

    private var lastAction: String? {
        guard let s = state["action"]?.stringValue, !s.isEmpty else { return nil }
        return s.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var voltage: Double? { state["voltage"]?.numberValue }

    private var voltageUnit: String {
        (device.definition?.exposes ?? []).flattened
            .first { $0.property == "voltage" || $0.name == "voltage" }?.unit ?? "mV"
    }

    var body: some View {
        Section {
            LabeledContent("Last Action") {
                Text(lastAction ?? "None yet")
            }
        } header: {
            Text("Remote")
        } footer: {
            if lastAction != nil, let pressed = DeviceStatus.lastSeenText(state.lastSeen) {
                Text("Pressed \(pressed)")
            }
        }
        if let voltage {
            Section("Diagnostics") {
                LabeledContent("Voltage") {
                    Text("\(Int(voltage)) \(voltageUnit)").monospacedDigit()
                }
            }
        }
    }
}

#Preview {
    List {
        RemoteSections(device: .preview, state: [
            "action": .string("brightness_up_click"),
            "voltage": .double(3045)
        ])
    }
}
