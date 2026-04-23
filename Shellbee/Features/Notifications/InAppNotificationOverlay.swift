import SwiftUI
import UIKit

// MARK: - Overlay (queue manager)

struct InAppNotificationOverlay: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var currentNormal: InAppNotification?
    @State private var currentFastTrack: InAppNotification?
    @State private var isVisible = false
    @State private var fastTrackVisible = false
    @State private var isExpanded = false
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var fastTrackTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let notification = currentNormal, isVisible {
                InAppNotificationBanner(
                    notification: notification,
                    isExpanded: $isExpanded,
                    onDismiss: dismissNormal,
                    onGoToLog: { goToLog(for: notification) },
                    onCopyMessage: { copy(notification.subtitle ?? notification.title) }
                )
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
        .animation(.spring(duration: DesignTokens.Duration.standardAnimation), value: isVisible)
        .animation(.spring(duration: 0.25), value: fastTrackVisible)
        .onChange(of: environment.store.pendingNotifications.count) { _, count in
            if count > 0, !isVisible { showNextNormal() }
        }
        .onChange(of: environment.store.fastTrackNotifications.count) { _, count in
            if count > 0, !fastTrackVisible { showNextFastTrack() }
        }
        .onChange(of: environment.store.currentNotification?.lastUpdated) { _, _ in
            if currentNormal != nil, let updated = environment.store.currentNotification {
                currentNormal = updated
                if !isExpanded { scheduleDismiss(for: updated) }
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                autoDismissTask?.cancel()
            } else if let note = currentNormal, isVisible {
                scheduleDismiss(for: note)
            }
        }
    }

    // MARK: - Normal lane

    private func showNextNormal() {
        guard let notification = environment.store.popNotification() else { return }
        currentNormal = notification
        environment.store.currentNotification = notification
        isExpanded = false
        isVisible = true
        playHaptic(for: notification)
        scheduleDismiss(for: notification)
    }

    private func scheduleDismiss(for notification: InAppNotification) {
        guard !isExpanded else { return }
        let duration = dismissDuration(for: notification)
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run { dismissNormal() }
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

    private func dismissNormal() {
        autoDismissTask?.cancel()
        isExpanded = false
        isVisible = false
        environment.store.currentNotification = nil
        Task {
            try? await Task.sleep(for: .milliseconds(Int(DesignTokens.Duration.standardAnimation * 1000) + 50))
            if !environment.store.pendingNotifications.isEmpty {
                showNextNormal()
            } else {
                currentNormal = nil
            }
        }
    }

    private func playHaptic(for notification: InAppNotification) {
        switch notification.level {
        case .error: Haptics.notification(.error)
        case .warning: Haptics.notification(.warning)
        default: break
        }
    }

    private func goToLog(for notification: InAppNotification) {
        if !notification.logEntryIDs.isEmpty {
            environment.pendingLogEntryIDs = notification.logEntryIDs
        }
        environment.selectedTab = .settings
        dismissNormal()
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
    let onDismiss: () -> Void
    let onGoToLog: () -> Void
    let onCopyMessage: () -> Void

    @State private var dragOffset: CGSize = .zero

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
            if !notification.logEntryIDs.isEmpty {
                Button(action: onGoToLog) {
                    Label("Go to Log", systemImage: "list.bullet.rectangle.portrait")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button(action: onCopyMessage) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 0)
        }
        .padding(.leading, 30)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if isExpanded {
                    // Expanded: allow horizontal drag (swipe-right to dismiss)
                    // and downward drag (collapse/dismiss).
                    dragOffset = CGSize(
                        width: max(dx, 0),
                        height: max(dy, 0)
                    )
                } else {
                    // Collapsed: downward drag to dismiss, upward to peek-expand.
                    dragOffset = CGSize(width: 0, height: dy > 0 ? dy : dy / 3)
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height

                if isExpanded {
                    if dx > 80 {
                        onDismiss()
                    } else if dy > 60 {
                        isExpanded = false
                    }
                } else {
                    if dy < -30 {
                        isExpanded = true
                    } else if dy > 60 {
                        onDismiss()
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
                onDismiss: {},
                onGoToLog: {},
                onCopyMessage: {}
            )
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear { isExpanded = expanded }
    }
}
