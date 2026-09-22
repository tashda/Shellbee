import SwiftUI

/// Shellbee's own internal dev tools — galleries and rendering toggles used
/// to build the app's UI, as opposed to the Z2M-facing tools that live
/// directly on the Developer page.
struct ShellbeeDeveloperView: View {
    @AppStorage(DeveloperSettings.softTopEdgeEnabledKey)
    private var softTopEdgeEnabled = DeveloperSettings.softTopEdgeEnabledDefault

    var body: some View {
        Form {
            Section {
                NavigationLink("Live Activity Gallery") {
                    LiveActivityGalleryView()
                }
                Button("Preview Permit Join Activity") {
                    PermitJoinActivityPreview.run()
                }
            } header: {
                Text("Live Activities")
            } footer: {
                Text("Plays a scripted pairing session: a device interviews and pairs, then another fails. Go to the Home Screen or lock the device right after tapping to watch it in the Dynamic Island.")
            }

            Section {
                NavigationLink("Card Gallery") {
                    CardGalleryView()
                }
            } header: {
                Text("Device Pages")
            } footer: {
                Text("Preview every device and group card on the detail page where it appears, including its readings and settings rows.")
            }

            Section {
                NavigationLink("Activity Instruments") {
                    ActivityInstrumentGalleryView()
                }
                NavigationLink("Activity Icons (Deprecated)") {
                    ActivityIconGalleryView()
                }
            } header: {
                Text("Activity Center")
            } footer: {
                Text("Activity Icons is deprecated in favor of Activity Instruments, which supersedes it for real feed, Home, and tab bar surfaces.")
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
        .navigationTitle("Shellbee")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ShellbeeDeveloperView() }
        .configuredTopScrollEdgeEffect()
        .environment(AppEnvironment())
}
