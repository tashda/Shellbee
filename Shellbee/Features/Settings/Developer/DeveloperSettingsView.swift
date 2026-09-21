import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage(DeveloperSettings.softTopEdgeEnabledKey)
    private var softTopEdgeEnabled = DeveloperSettings.softTopEdgeEnabledDefault

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    MQTTInspectorView()
                } label: {
                    Label {
                        Text("MQTT Inspector")
                    } icon: {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                            .background(.purple, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
                    }
                }
            } footer: {
                Text("Inspect every message flowing over the bridge connection and publish arbitrary topics. For debugging Z2M behavior — be careful publishing to bridge/request/* topics.")
            }

            Section {
                Toggle("Soft Top Edge", isOn: $softTopEdgeEnabled)
            } header: {
                Text("Rendering")
            } footer: {
                Text("Use the soft toolbar edge treatment when enabled. Turn this off to compare the native iOS and iPadOS rendering.")
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
