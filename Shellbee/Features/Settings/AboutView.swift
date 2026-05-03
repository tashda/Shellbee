import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private static let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6763139074?action=write-review")!
    private static let githubURL = URL(string: "https://github.com/tashda/Shellbee")!

    var body: some View {
        Form {
            shellbeeSection
            connectSection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shellbeeSection: some View {
        Section("Shellbee") {
            CopyableRow(label: "Version", value: appVersion)
            CopyableRow(label: "Build", value: appBuild)
            NavigationLink { AcknowledgementsView() } label: {
                Text("Acknowledgements")
            }
        }
    }

    private var connectSection: some View {
        Section("Connect") {
            externalLinkRow(
                title: "Rate Shellbee",
                systemImage: "star.fill",
                color: .pink,
                url: Self.appStoreReviewURL
            )
            externalLinkRow(
                title: "View on GitHub",
                systemImage: "chevron.left.forwardslash.chevron.right",
                color: Color(.darkGray),
                url: Self.githubURL
            )
        }
    }

    private func externalLinkRow(title: String, systemImage: String, color: Color, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                    .background(color, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
