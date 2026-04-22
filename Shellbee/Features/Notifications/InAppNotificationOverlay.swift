import SwiftUI

// MARK: - Overlay (queue manager)

struct InAppNotificationOverlay: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var current: InAppNotification?
    @State private var isVisible = false
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let notification = current, isVisible {
                InAppNotificationBanner(
                    notification: notification,
                    onDismiss: dismiss,
                    onTap: {
                        environment.selectedTab = .settings
                        dismiss()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(duration: DesignTokens.Duration.standardAnimation), value: isVisible)
        .onChange(of: environment.store.pendingNotifications.count) { _, count in
            if count > 0, !isVisible { showNext() }
        }
    }

    private func showNext() {
        guard let notification = environment.store.popNotification() else { return }
        current = notification
        isVisible = true

        let duration: Double = switch notification.level {
        case .error: 6
        case .warning: 5
        default: 3
        }

        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private func dismiss() {
        autoDismissTask?.cancel()
        isVisible = false
        Task {
            try? await Task.sleep(for: .milliseconds(Int(DesignTokens.Duration.standardAnimation * 1000) + 50))
            if !environment.store.pendingNotifications.isEmpty {
                showNext()
            } else {
                current = nil
            }
        }
    }
}

// MARK: - Banner (single notification pill)

private struct InAppNotificationBanner: View {
    let notification: InAppNotification
    let onDismiss: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: notification.level.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(notification.level.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle = notification.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.floatingOpacity),
            radius: DesignTokens.Shadow.floatingRadius,
            y: -DesignTokens.Shadow.floatingY
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .onTapGesture(perform: onTap)
    }
}
