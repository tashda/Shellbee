import SwiftUI

/// The expanded/collapsed notification banner shown above the floating tab
/// bar. Vertical drags collapse / expand / dismiss; horizontal drags
/// (expanded, stack > 1) page the carousel via `onSwipeNext` / `onSwipePrevious`.
struct InAppNotificationBanner: View {
    let notification: InAppNotification
    @Binding var isExpanded: Bool
    var stackCount: Int = 1
    var stackPositionLabel: String? = nil
    let onDismiss: () -> Void
    let onGoToLog: () -> Void
    let onGoToDevice: () -> Void
    let onCopyMessage: () -> Void
    var onSwipeNext: (() -> Void)? = nil
    var onSwipePrevious: (() -> Void)? = nil

    @State private var dragOffset: CGSize = .zero
    // Vertical drag = collapse/expand/dismiss. Horizontal drag while
    // expanded = carousel left/right. See dragGesture.

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            header
            if isExpanded { expandedBody }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        // iOS 26 floating tab bar uses a continuous capsule; per Apple HIG
        // (Tab bars — floating accessories), floating UI above the tab bar
        // should match its silhouette. Expanded uses a rounded rect for body room.
        .glassEffectIfAvailable(
            in: isExpanded
                ? AnyShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous))
                : AnyShape(Capsule(style: .continuous))
        )
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.floatingOpacity),
            radius: DesignTokens.Shadow.floatingRadius,
            y: -DesignTokens.Shadow.floatingY
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .offset(x: dragOffset.width, y: dragOffset.height)
        .contentShape(bannerHitShape)
        .highPriorityGesture(dragGesture, including: .all)
        .animation(Self.settleAnimation, value: isExpanded)
    }

    private static var settleAnimation: Animation {
        .interactiveSpring(response: 0.24, dampingFraction: 0.9, blendDuration: 0.04)
    }

    private var bannerHitShape: AnyShape {
        isExpanded
            ? AnyShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous))
            : AnyShape(Capsule(style: .continuous))
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: notification.level.systemImage)
                .font(DesignTokens.Typography.notificationLevelIcon)
                .foregroundStyle(notification.level.color)
                .frame(width: DesignTokens.Size.cardSymbol)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(notification.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    if notification.count > 1, stackPositionLabel == nil {
                        Text("× \(notification.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(.secondary.opacity(DesignTokens.Opacity.subtleFill), in: Capsule())
                    }
                    if let stackPositionLabel {
                        Text(stackPositionLabel)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(.tint.opacity(DesignTokens.Opacity.softFill), in: Capsule())
                    }
                }
                if let subtitle = notification.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: DesignTokens.Size.cardSymbol, height: DesignTokens.Size.cardSymbol)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded {
                onCopyMessage()
            } else {
                isExpanded = true
            }
        }
    }

    private var expandedBody: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if notification.deviceName != nil {
                Button(action: onGoToDevice) {
                    Label("Device", systemImage: "sensor.tag.radiowaves.forward.fill")
                }
                .glassProminentButtonStyleIfAvailable()
                .controlSize(.small)
            } else if !notification.logEntryIDs.isEmpty {
                Button(action: onGoToLog) {
                    Label("Log", systemImage: "list.bullet.rectangle.portrait")
                }
                .glassProminentButtonStyleIfAvailable()
                .controlSize(.small)
            }

            if notification.deviceName != nil, !notification.logEntryIDs.isEmpty {
                Button(action: onGoToLog) {
                    Label("Log", systemImage: "list.bullet.rectangle.portrait")
                }
                .glassButtonStyleIfAvailable()
                .controlSize(.small)
            }

            Button(action: onCopyMessage) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .glassButtonStyleIfAvailable()
            .controlSize(.small)

            Spacer(minLength: 0)
        }
        .padding(.leading, DesignTokens.Size.cardSymbol + DesignTokens.Spacing.sm)
    }

    private var dragGesture: some Gesture {
        // Vertical: swipe up expands (from collapsed), swipe down dismisses
        //          the entire stack (from either state).
        // Horizontal (expanded only): carousel left/right when stack > 1.
        DragGesture(minimumDistance: DesignTokens.Spacing.sm)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let verticalDominant = abs(dy) > abs(dx)
                if verticalDominant {
                    if isExpanded {
                        dragOffset = CGSize(width: 0, height: max(dy, 0))
                    } else {
                        dragOffset = CGSize(width: 0, height: dy > 0 ? dy : dy / 3)
                    }
                } else if isExpanded, stackCount > 1 {
                    dragOffset = CGSize(width: dx, height: 0)
                } else {
                    dragOffset = .zero
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let verticalDominant = abs(dy) > abs(dx)
                var committedSwipe = false
                if verticalDominant {
                    if !isExpanded, dy < -30 {
                        isExpanded = true
                    } else if dy > 60 {
                        onDismiss()
                    }
                } else if isExpanded, stackCount > 1 {
                    if dx < -60 {
                        onSwipeNext?()
                        committedSwipe = true
                    } else if dx > 60 {
                        onSwipePrevious?()
                        committedSwipe = true
                    }
                }
                // On a committed carousel swipe, the outgoing banner is now a
                // removed view — its position doesn't matter. Drop offset
                // without animating so the slide-out transition takes over
                // cleanly instead of the finger-follow offset snapping back.
                if committedSwipe {
                    dragOffset = .zero
                } else {
                    withAnimation(Self.settleAnimation) { dragOffset = .zero }
                }
            }
    }
}

// MARK: - Previews

private struct PreviewHost: View {
    let notification: InAppNotification
    var expanded: Bool = false
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Spacer()
            InAppNotificationBanner(
                notification: notification,
                isExpanded: $isExpanded,
                stackCount: 1,
                stackPositionLabel: nil,
                onDismiss: {},
                onGoToLog: {},
                onGoToDevice: {},
                onCopyMessage: {}
            )
            .padding(.bottom, DesignTokens.Size.notificationBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear { isExpanded = expanded }
    }
}

#Preview("Info — collapsed") {
    PreviewHost(
        notification: InAppNotification(
            level: .info,
            title: "Bind Successful",
            subtitle: "hallway_motion_sensor → living_room_light",
            logEntryID: UUID()
        )
    )
}

#Preview("Error — collapsed") {
    PreviewHost(
        notification: InAppNotification(
            level: .error,
            title: "Operation Failed",
            subtitle: "Publish 'zigbee2mqtt/hallway_ff_sensor/set' failed because the device is offline and no response was received within the timeout window.",
            logEntryID: UUID()
        )
    )
}

#Preview("Warning — collapsed") {
    PreviewHost(
        notification: InAppNotification(
            level: .warning,
            title: "Device Left Network",
            subtitle: "bedroom_thermostat",
            logEntryID: UUID()
        )
    )
}

#Preview("Error — expanded") {
    PreviewHost(
        notification: InAppNotification(
            level: .error,
            title: "Operation Failed",
            subtitle: "Publish 'zigbee2mqtt/hallway_ff_sensor/set' failed because the device is offline and no response was received within the timeout window.",
            logEntryID: UUID()
        ),
        expanded: true
    )
}

#Preview("Coalesced burst (× 12)") {
    PreviewHost(
        notification: {
            var n = InAppNotification(
                level: .error,
                title: "Operation Failed",
                subtitle: "Interview of 'sensor_12' failed",
                logEntryID: UUID()
            )
            n.count = 12
            n.logEntryIDs = (0..<12).map { _ in UUID() }
            return n
        }()
    )
}

#Preview("Coalesced — expanded") {
    PreviewHost(
        notification: {
            var n = InAppNotification(
                level: .warning,
                title: "Interview Failed",
                subtitle: "Most recent: 'attic_sensor_3'",
                logEntryID: UUID()
            )
            n.count = 4
            n.logEntryIDs = (0..<4).map { _ in UUID() }
            return n
        }(),
        expanded: true
    )
}

#Preview("Interview started — collapsed") {
    PreviewHost(
        notification: InAppNotification(
            level: .info,
            title: "Interviewing Device",
            subtitle: "kitchen_motion_sensor",
            logEntryID: UUID(),
            deviceName: "kitchen_motion_sensor"
        )
    )
}

#Preview("Interview successful — expanded") {
    PreviewHost(
        notification: InAppNotification(
            level: .info,
            title: "Interview Successful",
            subtitle: "kitchen_motion_sensor",
            logEntryID: UUID(),
            deviceName: "kitchen_motion_sensor"
        ),
        expanded: true
    )
}

#Preview("Interview failed — expanded") {
    PreviewHost(
        notification: InAppNotification(
            level: .error,
            title: "Interview Failed",
            subtitle: "attic_thermostat",
            logEntryID: UUID(),
            deviceName: "attic_thermostat"
        ),
        expanded: true
    )
}

#Preview("Info — no logEntry (Go to Log hidden)") {
    PreviewHost(
        notification: InAppNotification(
            level: .info,
            title: "Reporting Configured",
            subtitle: "living_room_light"
        ),
        expanded: true
    )
}

#Preview("Stacked carousel — 1 of 12 expanded") {
    @Previewable @State var expanded = true
    VStack {
        Spacer()
        InAppNotificationBanner(
            notification: InAppNotification(
                level: .error,
                title: "Operation Failed",
                subtitle: "Publish 'zigbee2mqtt/hallway_ff_sensor/set' failed",
                logEntryID: UUID(),
                deviceName: "hallway_ff_sensor"
            ),
            isExpanded: $expanded,
            stackCount: 12,
            stackPositionLabel: "1/12",
            onDismiss: {},
            onGoToLog: {},
            onGoToDevice: {},
            onCopyMessage: {},
            onSwipeNext: {},
            onSwipePrevious: {}
        )
        .padding(.bottom, DesignTokens.Size.notificationBottomInset)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}
