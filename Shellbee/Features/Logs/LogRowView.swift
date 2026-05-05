import SwiftUI

struct LogRowView: View {
    @Environment(AppEnvironment.self) private var environment
    let entry: LogEntry
    /// Phase 1 multi-bridge: explicit store for resolving the leading
    /// device/group avatar. Callers that know the entry's source bridge
    /// pass that bridge's store directly. Nil falls back to scanning every
    /// connected bridge by name (used by previews and any rare site that
    /// lacks a scope to hand in).
    var store: AppStore? = nil
    /// Source bridge id. When non-nil and the user's Bridge Indicator
    /// setting is enabled, the row paints a thin colored bar on its
    /// leading edge — same uniform attribution as Devices and Groups.
    var bridgeID: UUID? = nil

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            leadingVisual

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(entry.summaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if entry.coalescedCount > 1 {
                        Text("× \(entry.coalescedCount)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(DesignTokens.Opacity.subtleFill), in: Capsule())
                    }
                }

                Text(entry.summarySubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            Text(entry.timestamp, style: .relative)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .layoutPriority(1)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    // MARK: - Title tint

    private var titleColor: Color {
        switch entry.level {
        case .error: return .red
        case .warning: return .orange
        default: return .primary
        }
    }

    // MARK: - Leading visual

    private var leadingVisual: some View {
        LogRowAvatar(entry: entry, store: store, size: 38)
    }
}

#Preview {
    List {
        ForEach(LogEntry.previewEntries) { entry in
            LogRowView(entry: entry)
        }
    }
    .listStyle(.plain)
    .environment(AppEnvironment())
}
