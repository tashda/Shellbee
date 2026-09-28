import SwiftUI

/// A remote as a native List section: its last press in words, with when
/// it was pressed as the footer. Voltage and other diagnostics are left to
/// the settings sections' single Diagnostics section. A remote has nothing
/// to control in the app, so it gets no card.
struct RemoteSections: View {
    let device: Device
    let state: [String: JSONValue]

    static let claimedProperties: Set<String> = ["action"]

    private var lastAction: String? {
        guard let s = state["action"]?.stringValue, !s.isEmpty else { return nil }
        return s.replacingOccurrences(of: "_", with: " ").capitalized
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
