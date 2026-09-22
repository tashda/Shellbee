import SwiftUI

struct HomeLogsCard: View {
    /// A slice larger than `limit` — consecutive repeats collapse first, then
    /// the result is trimmed, so a chatty poll can't crowd out real events.
    let entries: [LogEntry]
    let limit: Int
    let onOpenEntry: (LogEntry) -> Void
    let onOpenAll: () -> Void

    /// A run of identical consecutive events, shown once with a ×N counter.
    /// The health-check poll writes the same line repeatedly; stacking those
    /// into one row is the difference between a feed and a log tail.
    struct Run: Identifiable {
        let entry: LogEntry
        let count: Int
        var id: UUID { entry.id }
    }

    static func collapse(_ entries: [LogEntry]) -> [Run] {
        var runs: [Run] = []
        for entry in entries {
            if let last = runs.last,
               last.entry.summaryTitle == entry.summaryTitle,
               last.entry.summarySubtitle == entry.summarySubtitle {
                runs[runs.count - 1] = Run(entry: last.entry, count: last.count + 1)
            } else {
                runs.append(Run(entry: entry, count: 1))
            }
        }
        return runs
    }

    private var runs: [Run] {
        Array(Self.collapse(entries).prefix(limit))
    }

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center) {
                    HomeCardTitle(symbol: "list.bullet.rectangle.fill", title: "Activity", tint: .blue)
                    Spacer()
                    Button("Show All", action: onOpenAll)
                        .font(.subheadline.weight(.medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }

                if runs.isEmpty {
                    Text("No recent events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    VStack(spacing: 0) {
                        Divider().padding(.top, DesignTokens.Spacing.xs)
                        ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                            Button { onOpenEntry(run.entry) } label: {
                                HomeLogRow(entry: run.entry, repeatCount: run.count)
                            }
                            .buttonStyle(HomeAlertRowButtonStyle())
                            if index < runs.count - 1 {
                                Divider().padding(.leading, HomeLogRow.leadingInset)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HomeLogRow: View {
    @Environment(AppEnvironment.self) private var environment
    let entry: LogEntry
    /// How many identical events this row stands for. 1 hides the counter.
    var repeatCount: Int = 1

    static let badgeSize: CGFloat = 32
    static var leadingInset: CGFloat { badgeSize + DesignTokens.Spacing.md }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            leadingVisual
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(entry.summaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if repeatCount > 1 {
                        Text("×\(repeatCount)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text(entry.summarySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var titleColor: Color {
        switch entry.level {
        case .error: return .red
        case .warning: return .orange
        default: return .primary
        }
    }

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
        // Phase 2 multi-bridge: scan every connected bridge for the named
        // device/group. The Home logs card merges across bridges so the
        // avatar resolution must too.
        for session in environment.registry.orderedSessions {
            if let device = session.store.device(named: name) { return .device(device) }
            if let group = session.store.group(named: name) {
                return .group(group, members: session.store.memberDevices(of: group))
            }
        }
        return .none
    }

    private var leadingVisual: some View {
        let size = Self.badgeSize
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
        .frame(width: size, height: size)
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
                            .foregroundStyle(.white)
                            .padding(inner * 0.22)
                    }
            }
    }
}

private struct HomeAlertRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}
