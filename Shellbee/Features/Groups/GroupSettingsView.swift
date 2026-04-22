import SwiftUI

struct GroupSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    let group: Group

    private var currentOptions: [String: JSONValue] {
        environment.store.bridgeInfo?.config?.groups?[String(group.id)] ?? [:]
    }

    var body: some View {
        List {
            Section {
                Picker("Off State", selection: Binding(
                    get: { currentOptions["off_state"]?.stringValue ?? "all_members_off" },
                    set: { sendOption("off_state", value: .string($0)) }
                )) {
                    Text("All Members Off").tag("all_members_off")
                    Text("Last Member State").tag("last_member_state")
                }
                Toggle("Optimistic", isOn: Binding(
                    get: { currentOptions["optimistic"]?.boolValue ?? true },
                    set: { sendOption("optimistic", value: .bool($0)) }
                ))
                Toggle("Retain Messages", isOn: Binding(
                    get: { currentOptions["retain"]?.boolValue ?? false },
                    set: { sendOption("retain", value: .bool($0)) }
                ))
                Picker("Quality of Service", selection: Binding(
                    get: { currentOptions["qos"]?.intValue ?? -1 },
                    set: { sendOption("qos", value: $0 < 0 ? .null : .int($0)) }
                )) {
                    Text("Default").tag(-1)
                    Text("QoS 0 — At most once").tag(0)
                    Text("QoS 1 — At least once").tag(1)
                    Text("QoS 2 — Exactly once").tag(2)
                }
            } header: {
                Text("General")
            } footer: {
                Text("Changes apply immediately.")
            }
        }
        .navigationTitle("Group Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendOption(_ key: String, value: JSONValue) {
        environment.send(
            topic: Z2MTopics.Request.groupOptions,
            payload: .object([
                "id": .string(String(group.id)),
                "options": .object([key: value])
            ])
        )
    }
}

#Preview {
    NavigationStack {
        GroupSettingsView(group: .preview)
            .environment(AppEnvironment())
    }
}
