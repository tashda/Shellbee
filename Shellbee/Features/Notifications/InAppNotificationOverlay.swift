import SwiftUI
import UIKit

// MARK: - Overlay (queue manager)

struct InAppNotificationOverlay: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isExpanded = false
    // Index into notification pages that the user is viewing while expanded.
    // When collapsed, always shows the newest (last). When expanded, this
    // cursor is controlled by horizontal swipes.
    @State private var carouselIndex: Int = 0
    @State private var carouselDirection: CarouselDirection = .forward
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var fastTrackTask: Task<Void, Never>?
    @State private var currentFastTrack: InAppNotification?
    @State private var fastTrackVisible = false
    @State private var lastSeenArrivalIDs: [UUID] = []
    @State private var removalStyle: BannerRemovalStyle = .automatic

    private enum CarouselDirection { case forward, backward }
    private enum BannerRemovalStyle { case automatic, vertical }
    // Reason for the most recent banner identity change. Lets `bannerTransition`
    // distinguish "user expanded" (slide from bottom) from "user swiped to next
    // page in the stack" (slide horizontally).
    private enum BannerTransitionReason { case arrival, expansion, carousel }
    @State private var transitionReason: BannerTransitionReason = .arrival

    private struct NotificationPage: Identifiable, Equatable {
        let notification: InAppNotification
        let occurrence: InAppNotificationOccurrence
        /// Phase 1 multi-bridge: source bridge for this notification. Used by
        /// goToDevice/goToLog to route navigation to the originating bridge.
        let bridgeID: UUID?

        var id: String { "\(notification.id.uuidString)-\(occurrence.id.uuidString)" }

        var bannerNotification: InAppNotification {
            notification.displaying(occurrence)
        }
    }

    /// Merged page list across every connected bridge so notifications from a
    /// non-selected bridge still surface. Each page carries its source bridge
    /// id so navigation lands on the right store.
    private var pages: [NotificationPage] {
        let connected = environment.registry.sessions.values.filter(\.isConnected)
        if connected.count >= 2 {
            return environment.allPendingNotifications.flatMap { bound in
                bound.notification.occurrences.map {
                    NotificationPage(
                        notification: bound.notification,
                        occurrence: $0,
                        bridgeID: bound.bridgeID
                    )
                }
            }
        }
        let bridgeID = environment.registry.primaryBridgeID
        let stack = bridgeID
            .flatMap { environment.registry.session(for: $0)?.store.pendingNotifications }
            ?? []
        return stack.flatMap { notification in
            notification.occurrences.map {
                NotificationPage(notification: notification, occurrence: $0, bridgeID: bridgeID)
            }
        }
    }

    private var displayedPage: NotificationPage? {
        guard !pages.isEmpty else { return nil }
        if isExpanded {
            let clamped = max(0, min(carouselIndex, pages.count - 1))
            return pages[clamped]
        }
        return pages.last
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let page = displayedPage {
                InAppNotificationBanner(
                    notification: page.bannerNotification,
                    isExpanded: $isExpanded,
                    stackCount: pages.count,
                    stackPositionLabel: positionLabel,
                    onDismiss: dismissStack,
                    onGoToLog: { goToLog(for: page) },
                    onGoToDevice: { goToDevice(for: page) },
                    onCopyMessage: { copy(page.occurrence.subtitle ?? page.notification.title) },
                    onSwipeNext: advanceCarousel,
                    onSwipePrevious: reverseCarousel
                )
                // Identity changes with the viewed notification so SwiftUI
                // runs the transition between distinct banners rather than
                // mutating the existing view in place.
                .id(bannerIdentity(for: page))
                .transition(bannerTransition)
                .zIndex(1)
            }

            if let fast = currentFastTrack, fastTrackVisible {
                FastTrackBanner(notification: fast)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(duration: DesignTokens.Duration.standardAnimation), value: pages.isEmpty)
        .animation(Self.carouselAnimation, value: displayedPage.map { bannerIdentity(for: $0) })
        .animation(.spring(duration: DesignTokens.Duration.mediumAnimation), value: fastTrackVisible)
        .onChange(of: environment.aggregateNotificationArrivalID) { _, newIDs in
            // New (non-coalesced) normal notification arrived on any bridge.
            // Haptic once, and schedule auto-dismiss on the now-visible banner.
            guard lastSeenArrivalIDs != newIDs else { return }
            lastSeenArrivalIDs = newIDs
            if let top = pages.last?.notification { playHaptic(for: top) }
            scheduleDismissIfPossible()
        }
        .onChange(of: environment.totalFastTrackNotifications) { _, count in
            if count > 0, !fastTrackVisible { showNextFastTrack() }
        }
        .onChange(of: isExpanded) { _, expanded in
            transitionReason = .expansion
            if expanded {
                autoDismissTask?.cancel()
                carouselIndex = max(0, pages.count - 1)
            } else {
                scheduleDismissIfPossible()
            }
        }
        .onChange(of: environment.aggregateNotificationArrivalID) { _, _ in
            transitionReason = .arrival
        }
        .onChange(of: pages.count) { _, _ in
            // Keep the expanded carousel pinned to the same item when new
            // notifications arrive (the spec says new arrivals land at the
            // end of the ring, current position unchanged).
            if !isExpanded {
                scheduleDismissIfPossible()
            } else {
                carouselIndex = min(carouselIndex, max(0, pages.count - 1))
            }
        }
    }

    private static var carouselAnimation: Animation {
        .interactiveSpring(response: 0.24, dampingFraction: 0.88, blendDuration: 0.04)
    }

    private func bannerIdentity(for page: NotificationPage) -> String {
        isExpanded ? page.id : page.notification.id.uuidString
    }

    private var bannerTransition: AnyTransition {
        if removalStyle == .vertical {
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
        // Carousel transitions only fire when the user is actively swiping
        // between stack pages. Expansion (swipe up to reveal actions) and
        // arrival (new banner from below the tab bar) both come from the
        // bottom edge so they read as a single continuous "rise" gesture.
        guard transitionReason == .carousel else {
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
        switch carouselDirection {
        case .forward:
            // Swiping content left (viewing next): old slides left, new comes from right.
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }

    private var positionLabel: String? {
        guard isExpanded, pages.count > 1 else { return nil }
        let clamped = max(0, min(carouselIndex, pages.count - 1))
        // Position 1 = newest (last in the array); N = oldest (first).
        let position = pages.count - clamped
        return "\(position)/\(pages.count)"
    }

    // MARK: - Auto-dismiss (top-of-stack only, paused when expanded)

    private func scheduleDismissIfPossible() {
        autoDismissTask?.cancel()
        guard !isExpanded, let top = pages.last?.notification else { return }
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
        // In multi-bridge mode the stack merges across bridges; pop from
        // Phase 2 multi-bridge: always pop from the bridge that holds the
        // newest notification — single-bridge case collapses naturally.
        guard environment.totalPendingNotifications > 0 else { return }
        removalStyle = .vertical
        environment.popLatestPendingNotification()
        scheduleDismissIfPossible()
        resetRemovalStyleSoon()
    }

    // Swipe-down dismisses the entire stack per user spec.
    private func dismissStack() {
        autoDismissTask?.cancel()
        removalStyle = .vertical
        isExpanded = false
        environment.clearAllPendingNotifications()
        resetRemovalStyleSoon()
    }

    // MARK: - Carousel navigation (expanded only)

    private func advanceCarousel() {
        guard isExpanded, pages.count > 1 else { return }
        transitionReason = .carousel
        withAnimation(Self.carouselAnimation) {
            carouselDirection = .forward
            carouselIndex = (carouselIndex - 1 + pages.count) % pages.count
        }
    }

    private func reverseCarousel() {
        guard isExpanded, pages.count > 1 else { return }
        transitionReason = .carousel
        withAnimation(Self.carouselAnimation) {
            carouselDirection = .backward
            carouselIndex = (carouselIndex + 1) % pages.count
        }
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

    private func goToLog(for page: NotificationPage) {
        guard !page.notification.logEntryIDs.isEmpty else { return }
        environment.pendingLogSheet = LogSheetRequest(entryIDs: page.notification.logEntryIDs)
        // Keep the banner expanded so it's still there when the sheet/nav
        // is dismissed. The user dismisses it by swiping down.
        autoDismissTask?.cancel()
    }

    private func goToDevice(for page: NotificationPage) {
        guard let name = page.occurrence.deviceName else { return }
        // Phase 1 multi-bridge: every page carries its source bridge id, so
        // we route DeviceListView straight to the right bridge — no
        // `setPrimary` side effect, no name-collision risk across bridges.
        guard let bridgeID = page.bridgeID,
              let device = environment.registry.session(for: bridgeID)?.store.device(named: name)
        else { return }
        environment.pendingDeviceNavigation = DeviceRoute(bridgeID: bridgeID, device: device)
        environment.selectedTab = .devices
        autoDismissTask?.cancel()
    }

    private func copy(_ value: String) {
        UIPasteboard.general.string = value
        // Phase 2 multi-bridge: enqueue the fast-track on any connected
        // bridge — the overlay scans all sessions for fast-track and surfaces
        // them globally regardless of source store.
        if let store = environment.registry.orderedSessions.first(where: \.isConnected)?.store {
            store.enqueueNotification(
                InAppNotification(level: .info, title: "Copied to Clipboard", priority: .fastTrack)
            )
        }
    }

    // MARK: - Fast-track lane

    private func showNextFastTrack() {
        // Phase 2 multi-bridge: always pop across every bridge — single-
        // bridge collapses to a one-element search.
        guard let notification = environment.popNextFastTrackNotification()?.notification else { return }
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
                    if environment.hasFastTrackNotifications {
                        showNextFastTrack()
                    }
                }
            }
        }
    }

    private func resetRemovalStyleSoon() {
        Task { @MainActor in
            await Task.yield()
            removalStyle = .automatic
        }
    }
}
