import SwiftUI

struct AcknowledgementsView: View {
    @State private var contributors: [Contributor] = ContributorsService.shared.loadCached()

    var body: some View {
        Form {
            Section("Open Source") {
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
            }

            if !contributors.isEmpty {
                Section("Contributors") {
                    ContributorsGrid(contributors: contributors)
                        .listRowInsets(EdgeInsets(
                            top: DesignTokens.Spacing.md,
                            leading: DesignTokens.Spacing.md,
                            bottom: DesignTokens.Spacing.md,
                            trailing: DesignTokens.Spacing.md
                        ))
                }
            }

            Section("Support") {
                Link(destination: URL(string: "https://github.com/sponsors/Koenkk")!) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "heart.fill")
                            .font(.body)
                            .foregroundStyle(.pink)
                            .frame(width: DesignTokens.Size.settingsIconFrame)
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
        .task {
            let fresh = await ContributorsService.shared.refresh()
            if !fresh.isEmpty {
                contributors = fresh
            }
        }
    }

    private func acknowledgementRow(title: String, subtitle: String, badge: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.body)
                    .foregroundStyle(.green)
                    .frame(width: DesignTokens.Size.settingsIconFrame)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text(title)
                            .foregroundStyle(.primary)
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
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

private struct ContributorsGrid: View {
    let contributors: [Contributor]

    private let avatarSize: CGFloat = 44
    private let columns = [GridItem(.adaptive(minimum: 52), spacing: DesignTokens.Spacing.sm)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ForEach(contributors) { contributor in
                Link(destination: contributor.htmlURL) {
                    AsyncImage(url: contributor.avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle().fill(.quaternary)
                        }
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.quaternary, lineWidth: 0.5))
                }
                .accessibilityLabel(contributor.login)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
