import SwiftUI

struct LogRowView: View {
    @Environment(AppEnvironment.self) private var environment
    let entry: LogEntry
    /// Phase 1 multi-bridge: explicit store for resolving the leading
    /// device/group avatar. Callers that know the entry's source bridge
    /// pass that bridge's store directly. Nil falls back to the
    /// notification-overlay-style heuristic of searching every connected
    /// bridge by name (used by previews and any rare site that lacks a
    /// scope to hand in).
    var store: AppStore? = nil
    /// Source bridge id. When non-nil and the user's Bridge Indicator
    /// setting is enabled, the row paints a thin colored bar on its
    /// leading edge — same uniform attribution as Devices and Groups.
    var bridgeID: UUID? = nil

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            leadingVisual

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Text(entry.summaryTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    absoluteTimestamp
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(entry.summarySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.Spacing.xs)
                    relativeTimestamp
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.summaryRowVerticalPadding)
        // NOTE: the leading-bar `.listRowBackground` is applied at the call
        // site (the row's outermost view in the List), not here — most
        // callers wrap LogRowView in a ZStack with a hidden NavigationLink,
        // and `.listRowBackground` only takes effect at the row's top level.
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

    private enum Subject {
        case device(Device)
        case group(Group, members: [Device])
        case none
    }

    private var subject: Subject {
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
        guard let name = candidate else { return .none }

        // When a scoped store is provided, resolve from it — this is the
        // multi-bridge correct path (entries from bridge B render against B's
        // device/group registry). Without a scope, fall back to scanning every
        // connected bridge for the name; first match wins.
        if let store {
            if let device = store.device(named: name) { return .device(device) }
            if let group = store.group(named: name) {
                return .group(group, members: store.memberDevices(of: group))
            }
            return .none
        }

        for session in environment.registry.orderedSessions {
            if let device = session.store.device(named: name) { return .device(device) }
            if let group = session.store.group(named: name) {
                return .group(group, members: session.store.memberDevices(of: group))
            }
        }
        return .none
    }

    private var leadingVisual: some View {
        let size = DesignTokens.Size.logRowDeviceImage
        let badgeSize = size * DesignTokens.Ratio.logRowBadgeSize
        let hasSubject: Bool
        switch subject {
        case .device, .group: hasSubject = true
        case .none: hasSubject = false
        }

        return ZStack(alignment: .bottomTrailing) {
            avatar(size: size)

            if hasSubject {
                categoryBadge(size: badgeSize)
                    .offset(x: DesignTokens.Size.logRowBadgeOffset,
                            y: DesignTokens.Size.logRowBadgeOffset)
            }
        }
    }

    @ViewBuilder
    private func avatar(size: CGFloat) -> some View {
        switch subject {
        case .device(let device):
            DeviceImageView(device: device, isAvailable: true, size: size)
                .frame(width: size, height: size)
        case .group(_, let members):
            GroupIconView(memberDevices: Array(members.prefix(2)), size: size)
                .frame(width: size, height: size)
        case .none:
            Circle()
                .fill(entry.category.chipTint)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: entry.category.systemImage)
                        .font(.system(size: size * DesignTokens.Typography.iconRatioSmall, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
    }

    private func categoryBadge(size: CGFloat) -> some View {
        let stroke = max(DesignTokens.Ratio.logRowBadgeBorderMin,
                         size * DesignTokens.Ratio.logRowBadgeBorder)
        let inner = size - stroke * 2
        return Circle()
            .fill(Color(.systemBackground))
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .fill(entry.category.chipTint)
                    .frame(width: inner, height: inner)
                    .overlay {
                        Image(systemName: entry.category.systemImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: 1, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(inner * 0.22)
                    }
            }
    }

    // MARK: - Timestamps

    private var absoluteTimestamp: some View {
        Text(entry.timestamp, format: .dateTime.hour().minute().second())
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private var relativeTimestamp: some View {
        Text(entry.timestamp, style: .relative)
            .font(.caption2)
            .foregroundStyle(.tertiary)
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
