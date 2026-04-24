import SwiftUI

struct LoggingHubView: View {
    let highlight: SettingsHighlight?

    init(highlight: SettingsHighlight? = nil) {
        self.highlight = highlight
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    LoggingBasicView(highlight: highlight)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Basic")
                        Text("Log level and log file retention.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    LoggingSettingsView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Advanced")
                        Text("Outputs, formats, and debug namespace filter.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Logging")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LoggingHubView().environment(AppEnvironment())
    }
}
