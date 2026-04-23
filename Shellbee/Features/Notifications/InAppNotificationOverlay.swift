import SwiftUI
import UIKit

// MARK: - Overlay (queue manager)

struct InAppNotificationOverlay: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var currentNormal: InAppNotification?
    @State private var currentFastTrack: InAppNotification?
    @State private var isVisible = false
    @State private var fastTrackVisible = false
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var fastTrackTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let notification = currentNormal, isVisible {
                InAppNotificationBanner(
                    notification: notification,
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
        .onChange(of: environment.store.currentNotification?.count) { _, newCount in
            if currentNormal != nil, let updated = environment.store.currentNotification {
                currentNormal = updated
                extendDismissTimer(for: updated)
            }
            _ = newCount
        }
    }

    // MARK: - Normal lane

    private func showNextNormal() {
        guard let notification = environment.store.popNotification() else { return }
        currentNormal = notification
        environment.store.currentNotification = notification
        isVisible = true
        scheduleDismiss(for: notification)
    }

    private func scheduleDismiss(for notification: InAppNotification) {
        let duration = dismissDuration(for: notification)
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run { dismissNormal() }
        }
    }

    private func extendDismissTimer(for notification: InAppNotification) {
        scheduleDismiss(for: notification)
    }

    private func dismissDuration(for notification: InAppNotification) -> Double {
        let base: Double = switch notification.level {
        case .error: 6
        case .warning: 5
        default: 3
        }
        // Extra time when coalesced so the user can read the pile-up.
        return base + min(Double(notification.count - 1) * 0.3, 3)
    }

    private func dismissNormal() {
        autoDismissTask?.cancel()
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

private struct InAppNotificationBanner: View {
    let notification: InAppNotification
    let onDismiss: () -> Void
    let onGoToLog: () -> Void
    let onCopyMessage: () -> Void

    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0

    // iOS 26 floating tab bar uses a continuous capsule shape; Apple HIG recommends
    // matching floating elements to the tab bar silhouette (Human Interface
    // Guidelines — Tab bars, "Floating accessories").
    private var shape: some Shape { Capsule(style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            header
            if isExpanded { expandedBody }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, isExpanded ? DesignTokens.Spacing.md : DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: isExpanded ? AnyShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous)) : AnyShape(shape))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.floatingOpacity),
            radius: DesignTokens.Shadow.floatingRadius,
            y: -DesignTokens.Shadow.floatingY
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .offset(y: dragOffset)
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
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(.tint.opacity(DesignTokens.Opacity.softFill), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button(action: onCopyMessage) {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(.secondary.opacity(DesignTokens.Opacity.subtleFill), in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.leading, 30)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                } else if isExpanded {
                    dragOffset = value.translation.height / 3
                }
            }
            .onEnded { value in
                let dy = value.translation.height
                if dy < -30, !isExpanded {
                    isExpanded = true
                } else if dy > 60 {
                    if isExpanded {
                        isExpanded = false
                    } else {
                        onDismiss()
                    }
                }
                withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
            }
    }
}

// MARK: - Fast-track banner

private struct FastTrackBanner: View {
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
