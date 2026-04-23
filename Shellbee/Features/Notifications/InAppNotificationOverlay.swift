import SwiftUI
import UIKit

// MARK: - Overlay (queue manager)

struct InAppNotificationOverlay: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isExpanded = false
    // Index into pendingNotifications that the user is viewing while expanded.
    // When collapsed, always shows the newest (last). When expanded, this
    // cursor is controlled by horizontal swipes.
    @State private var carouselIndex: Int = 0
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var fastTrackTask: Task<Void, Never>?
    @State private var currentFastTrack: InAppNotification?
    @State private var fastTrackVisible = false
    @State private var lastSeenArrivalID: UUID?

    private var stack: [InAppNotification] {
        environment.store.pendingNotifications
    }

    private var displayed: InAppNotification? {
        guard !stack.isEmpty else { return nil }
        if isExpanded {
            let clamped = max(0, min(carouselIndex, stack.count - 1))
            return stack[clamped]
        }
        return stack.last
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let notification = displayed {
                InAppNotificationBanner(
                    notification: notification,
                    isExpanded: $isExpanded,
                    stackCount: stack.count,
                    stackPositionLabel: positionLabel,
                    onDismiss: dismissStack,
                    onGoToLog: { goToLog(for: notification) },
                    onGoToDevice: { goToDevice(for: notification) },
                    onCopyMessage: { copy(notification.subtitle ?? notification.title) },
                    onSwipeNext: advanceCarousel,
                    onSwipePrevious: reverseCarousel
                )
                .id(stack.count) // re-insert when stack grows, keep cross-fade
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }

            if let fast = currentFastTrack, fastTrackVisible {
                FastTrackBanner(notification: fast)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(duration: DesignTokens.Duration.standardAnimation), value: stack.isEmpty)
        .animation(.spring(duration: 0.25), value: fastTrackVisible)
        .onChange(of: environment.store.notificationArrivalID) { _, newID in
            // New (non-coalesced) normal notification arrived. Haptic once,
            // and schedule auto-dismiss on the now-visible banner.
            guard lastSeenArrivalID != newID else { return }
            lastSeenArrivalID = newID
            if let top = stack.last { playHaptic(for: top) }
            scheduleDismissIfPossible()
        }
        .onChange(of: environment.store.fastTrackNotifications.count) { _, count in
            if count > 0, !fastTrackVisible { showNextFastTrack() }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                autoDismissTask?.cancel()
                carouselIndex = max(0, stack.count - 1)
            } else {
                scheduleDismissIfPossible()
            }
        }
        .onChange(of: stack.count) { _, _ in
            // Keep the expanded carousel pinned to the same item when new
            // notifications arrive (the spec says new arrivals land at the
            // end of the ring, current position unchanged).
            if !isExpanded {
                scheduleDismissIfPossible()
            } else {
                carouselIndex = min(carouselIndex, max(0, stack.count - 1))
            }
        }
    }

    private var positionLabel: String? {
        guard isExpanded, stack.count > 1 else { return nil }
        let clamped = max(0, min(carouselIndex, stack.count - 1))
        // Position 1 = newest (last in the array); N = oldest (first).
        let position = stack.count - clamped
        return "\(position)/\(stack.count)"
    }

    // MARK: - Auto-dismiss (top-of-stack only, paused when expanded)

    private func scheduleDismissIfPossible() {
        autoDismissTask?.cancel()
        guard !isExpanded, let top = stack.last else { return }
        let duration = dismissDuration(for: top)
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run { dismissTop() }
        }
    }

    private func dismissDuration(for notification: InAppNotification) -> Double {
        let base: Double = switch notification.level {
        case .error: 6
        case .warning: 5
        default: 3
        }
        return base + min(Double(notification.count - 1) * 0.3, 3)
    }

    private func dismissTop() {
        guard !environment.store.pendingNotifications.isEmpty else { return }
        environment.store.pendingNotifications.removeLast()
        scheduleDismissIfPossible()
    }

    // Swipe-down dismisses the entire stack per user spec.
    private func dismissStack() {
        autoDismissTask?.cancel()
        isExpanded = false
        environment.store.pendingNotifications.removeAll()
    }

    // MARK: - Carousel navigation (expanded only)

    private func advanceCarousel() {
        guard isExpanded, stack.count > 1 else { return }
        carouselIndex = (carouselIndex - 1 + stack.count) % stack.count
    }

    private func reverseCarousel() {
        guard isExpanded, stack.count > 1 else { return }
        carouselIndex = (carouselIndex + 1) % stack.count
    }

    // MARK: - Haptic

    private func playHaptic(for notification: InAppNotification) {
        switch notification.level {
        case .error: Haptics.notification(.error)
        case .warning: Haptics.notification(.warning)
        default: break
        }
    }

    // MARK: - Actions

    private func goToLog(for notification: InAppNotification) {
        guard !notification.logEntryIDs.isEmpty else { return }
        environment.pendingLogSheet = LogSheetRequest(entryIDs: notification.logEntryIDs)
        dismissStack()
    }

    private func goToDevice(for notification: InAppNotification) {
        guard let name = notification.deviceName else { return }
        environment.pendingDeviceNavigation = name
        environment.selectedTab = .devices
        dismissStack()
    }

    private func copy(_ value: String) {
        UIPasteboard.general.string = value
        environment.store.enqueueNotification(
            InAppNotification(level: .info, title: "Copied to Clipboard", priority: .fastTrack)
        )
    }

    // MARK: - Fast-track lane

    private func showNextFastTrack() {
        guard let notification = environment.store.popFastTrackNotification() else { return }
        currentFastTrack = notification
        fastTrackVisible = true
        fastTrackTask?.cancel()
        fastTrackTask = Task {
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                fastTrackVisible = false
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    currentFastTrack = nil
                    if !environment.store.fastTrackNotifications.isEmpty {
                        showNextFastTrack()
                    }
                }
            }
        }
    }
}

// MARK: - Main banner

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
        .glassEffect(
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
        .gesture(dragGesture)
        .animation(.spring(duration: 0.25), value: isExpanded)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: notification.level.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(notification.level.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(notification.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    if notification.count > 1 {
                        Text("× \(notification.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(DesignTokens.Opacity.subtleFill), in: Capsule())
                    }
                    if let stackPositionLabel {
                        Text(stackPositionLabel)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 2)
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
                    .frame(width: 22, height: 22)
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
                .buttonStyle(.glassProminent)
                .controlSize(.small)
            } else if !notification.logEntryIDs.isEmpty {
                Button(action: onGoToLog) {
                    Label("Log", systemImage: "list.bullet.rectangle.portrait")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
            }

            if notification.deviceName != nil, !notification.logEntryIDs.isEmpty {
                Button(action: onGoToLog) {
                    Label("Log", systemImage: "list.bullet.rectangle.portrait")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            Button(action: onCopyMessage) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.glass)
            .controlSize(.small)

            Spacer(minLength: 0)
        }
        .padding(.leading, 30)
    }

    private var dragGesture: some Gesture {
        // Vertical: swipe up expands (from collapsed), swipe down dismisses
        //          the entire stack (from either state).
        // Horizontal (expanded only): carousel left/right when stack > 1.
        DragGesture(minimumDistance: 10)
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
                if verticalDominant {
                    if !isExpanded, dy < -30 {
                        isExpanded = true
                    } else if dy > 60 {
                        onDismiss()
                    }
                } else if isExpanded, stackCount > 1 {
                    if dx < -60 {
                        onSwipeNext?()
                    } else if dx > 60 {
                        onSwipePrevious?()
                    }
                }
                withAnimation(.spring(duration: 0.25)) { dragOffset = .zero }
            }
    }
}

// MARK: - Fast-track banner

struct FastTrackBanner: View {
    let notification: InAppNotification

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: notification.level.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(notification.level.color)
            Text(notification.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .glassEffect(in: Capsule(style: .continuous))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.floatingOpacity),
            radius: DesignTokens.Shadow.floatingRadius,
            y: -DesignTokens.Shadow.floatingY
        )
    }
}

// MARK: - Previews

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
        .padding(.bottom, 80)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}

#Preview("Fast-track — Copied") {
    VStack {
        Spacer()
        FastTrackBanner(
            notification: InAppNotification(
                level: .info,
                title: "Copied to Clipboard",
                priority: .fastTrack
            )
        )
        .padding(.bottom, 80)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}

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
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear { isExpanded = expanded }
    }
}
