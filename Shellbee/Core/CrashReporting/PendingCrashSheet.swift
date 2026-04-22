import SwiftUI

struct PendingCrashSheet: View {
    let crash: PendingCrash
    let onShare: () -> Void
    let onAlwaysShare: () -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    header

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        DisclosureGroup(isExpanded: $showDetails) {
                            Text(crash.summary)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(DesignTokens.Spacing.md)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
                        } label: {
                            Text("Show report")
                                .font(.subheadline.weight(.semibold))
                        }

                        Text("Nothing is sent until you tap Share. Bridge URLs, tokens, and IP addresses are redacted.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Button {
                            onShare()
                            dismiss()
                        } label: {
                            Text("Share report")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            onAlwaysShare()
                            dismiss()
                        } label: {
                            Text("Always share crash reports")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button(role: .destructive) {
                            onDiscard()
                            dismiss()
                        } label: {
                            Text("Discard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .navigationTitle("Shellbee crashed")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Shellbee crashed last time it was running.")
                .font(.headline)
            Text("Share the crash report with the developer to help fix it? The report contains the error, a short stack trace, and your iOS and app version. No bridge URLs, tokens, or device names are included.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
