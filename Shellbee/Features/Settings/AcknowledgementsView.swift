import SwiftUI

struct AcknowledgementsView: View {
    var body: some View {
        Form {
            Section {
                acknowledgementRow(
                    title: "Zigbee2MQTT",
                    subtitle: "The open-source Zigbee gateway this app connects to",
                    badge: "AGPL-3.0",
                    url: URL(string: "https://github.com/Koenkk/zigbee2mqtt")!
                )
                acknowledgementRow(
                    title: "zigbee2mqtt.io",
                    subtitle: "Documentation and device library used in Shellbee",
                    badge: "GPL-3.0",
                    url: URL(string: "https://github.com/Koenkk/zigbee2mqtt.io")!
                )
                acknowledgementRow(
                    title: "Sentry Cocoa SDK",
                    subtitle: "Powers opt-in crash reporting (off by default)",
                    badge: "MIT",
                    url: URL(string: "https://github.com/getsentry/sentry-cocoa")!
                )
            } header: {
                Text("Open Source")
            } footer: {
                Text("Shellbee uses documentation and data from the zigbee2mqtt.io project (GPL-3.0). Crash reporting, when enabled, is powered by the Sentry Cocoa SDK (MIT).")
            }

            Section("Support") {
                Link(destination: URL(string: "https://github.com/sponsors/Koenkk")!) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "heart.fill")
                            .font(.body)
                            .foregroundStyle(.pink)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Donate to Koenkk")
                                .foregroundStyle(.primary)
                            Text("Support the creator of Zigbee2MQTT")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func acknowledgementRow(title: String, subtitle: String, badge: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.body)
                    .foregroundStyle(.green)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text(title)
                            .foregroundStyle(.primary)
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
