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
                Text(entry.summaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

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

    private static let avatarSize: CGFloat = 38

    @ViewBuilder
    private var leadingVisual: some View {
        let visual = LogRowIconography.visual(for: entry, store: resolvedStore)
        switch visual {
        case .deviceThumbnail(let device):
            DeviceImageView(device: device, isAvailable: true, size: Self.avatarSize)
                .frame(width: Self.avatarSize, height: Self.avatarSize)
        case .groupThumbnail(_, let members):
            GroupIconView(memberDevices: Array(members.prefix(2)), size: Self.avatarSize)
                .frame(width: Self.avatarSize, height: Self.avatarSize)
        case .symbol(let name, let tint):
            symbolAvatar(name: name, tint: tint)
        }
    }

    /// Tinted circular badge — mirrors the leading-icon treatment Apple
    /// uses in Reminders / Settings rows. Distinct from the device thumbnail
    /// path so non-device events don't masquerade as devices, and distinct
    /// from the old single-blue-circle treatment because the tint changes
    /// per category.
    private func symbolAvatar(name: String, tint: Color) -> some View {
        Circle()
            .fill(tint.opacity(0.18))
            .frame(width: Self.avatarSize, height: Self.avatarSize)
            .overlay {
                Image(systemName: name)
                    .font(.system(size: Self.avatarSize * 0.46, weight: .semibold))
                    .foregroundStyle(tint)
            }
    }

    private var resolvedStore: AppStore? {
        if let store { return store }
        // Fallback: pick any connected bridge that knows the device by name.
        // Single-bridge installs always satisfy this.
        let candidate: String?
        if let ctx = entry.context, !ctx.devices.isEmpty {
            candidate = ctx.devices.first?.friendlyName
        } else if let n = entry.deviceName {
            candidate = n
        } else if case .mqttPublish(let d, _, _) = entry.parsedMessageKind {
            candidate = d
        } else {
            candidate = nil
        }
        guard let name = candidate else { return nil }
        for session in environment.registry.orderedSessions {
            if session.store.device(named: name) != nil || session.store.group(named: name) != nil {
                return session.store
            }
        }
        return nil
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
