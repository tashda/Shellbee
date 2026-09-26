import SwiftUI

struct DeveloperSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    private var resolvedBridgeID: UUID? {
        environment.registry.primaryBridgeID
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    MQTTInspectorView()
                } label: {
                    SettingsNavigationLabel(title: "MQTT Inspector", systemImage: "dot.radiowaves.left.and.right", color: .purple)
                }
            } footer: {
                Text("Inspect every message flowing over the bridge connection and publish arbitrary topics. For debugging Z2M behavior — be careful publishing to bridge/request/* topics.")
            }

            Section {
                NavigationLink {
                    ShellbeeDeveloperView()
                } label: {
                    SettingsNavigationLabel(title: "Shellbee", systemImage: "wand.and.stars", color: .pink)
                }
            } footer: {
                Text("Live Activity, device page, Activity Center, and rendering previews used to develop Shellbee's own UI.")
            }

            Section {
                if let bridgeID = resolvedBridgeID {
                    NavigationLink {
                        FrontendSettingsView(bridgeID: bridgeID)
                    } label: {
                        SettingsNavigationLabel(title: "Frontend", systemImage: "globe", color: .teal)
                    }
                } else {
                    LabeledContent("Frontend", value: "No bridge connected")
                }
            } header: {
                Text("Z2M Advanced")
            } footer: {
                Text("Direct access to Zigbee2MQTT options not yet exposed elsewhere in the app. Changes are sent straight to bridge/request/options — double check before applying.")
            }
        }
        .navigationTitle("Developer")
    }
}

#Preview {
    NavigationStack { DeveloperSettingsView() }
    .configuredTopScrollEdgeEffect()
        .environment(AppEnvironment())
}
