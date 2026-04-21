import SwiftUI

struct SettingsWarningBanner: View {
    let message: String
    var severity: Severity = .caution

    enum Severity { case caution, danger }

    private var color: Color { severity == .danger ? .red : .orange }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(color.opacity(DesignTokens.Opacity.chipFill))
    }
}

#Preview {
    Form {
        Section {
            SettingsWarningBanner(
                message: "Changes here can prevent the bridge from connecting to the Zigbee adapter.",
                severity: .danger
            )
        }
        Section {
            SettingsWarningBanner(
                message: "Changing the channel requires re-pairing all devices.",
                severity: .caution
            )
        }
    }
}
