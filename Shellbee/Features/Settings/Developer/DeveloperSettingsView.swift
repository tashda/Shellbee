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
                NavigationLink("Live Activity Gallery") {
                    LiveActivityGalleryView()
                }
                NavigationLink("Activity Instruments") {
                    ActivityInstrumentGalleryView()
                }
                NavigationLink("Activity Icons") {
                    ActivityIconGalleryView()
                }
                Button("Preview Permit Join Activity") {
                    PermitJoinActivityPreview.run()
                }
            } header: {
                Text("Live Activities")
            } footer: {
                Text("Plays a scripted pairing session: a device interviews and pairs, then another fails. Go to the Home Screen or lock the device right after tapping to watch it in the Dynamic Island.")
            }

            if #available(iOS 27.0, *) {
                Section {
                    Toggle("Soft Top Edge", isOn: $softTopEdgeEnabled)
                } header: {
                    Text("Rendering")
                } footer: {
                    Text("Use the soft toolbar edge treatment when enabled.")
                }
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
