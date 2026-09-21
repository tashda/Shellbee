import ActivityKit
import Foundation

/// Presents pairing only while Z2M reports a finite, still-open permit-join
/// window. Expiry is enforced locally as a second line of defence; the
/// system's stale date handles the case where the app is suspended.
@MainActor
final class PermitJoinLiveActivityCoordinator {
    static let shared = PermitJoinLiveActivityCoordinator()

    private let controller = LiveActivityController<PermitJoinActivityAttributes>(
        dismissesOtherActivities: false
    ) { existing, requested in
        existing.identifier == requested.identifier
    }

    private var tracked: [String: PermitJoinActivityAttributes] = [:]
    private var states: [String: PermitJoinActivityAttributes.ContentState] = [:]
    private var expiryTasks: [String: Task<Void, Never>] = [:]
    /// Card updates run one after another. Separate tasks can finish out of
    /// order, letting an older state land after a newer one.
    private var lastDelivery: Task<Void, Never>?

    private init() {}

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: ConnectionSessionController.permitJoinLiveActivityEnabledKey) as? Bool ?? true
    }

    func sync(
        bridgeID: UUID?,
        bridgeDisplayName: String,
        isOpen: Bool,
        endMilliseconds: Int?,
        targetName: String?,
        joinedCount: Int,
        interviewing: [String] = [],
        interviewFailure: String? = nil,
        recentlyPaired: String? = nil
    ) {
        guard Self.isEnabled else {
            clear(bridgeID: bridgeID)
            return
        }
        guard isOpen else {
            clear(bridgeID: bridgeID)
            return
        }
        // Some messages report an open window without its deadline. That
        // says nothing new, so leave the card alone rather than clearing it.
        guard let endMilliseconds, endMilliseconds > 0 else { return }
        guard Date(timeIntervalSince1970: Double(endMilliseconds) / 1_000) > .now else {
            clear(bridgeID: bridgeID)
            return
        }
        let reportedEnd = Date(timeIntervalSince1970: Double(endMilliseconds) / 1_000)

        let attributes = makeAttributes(bridgeID: bridgeID, bridgeDisplayName: bridgeDisplayName)
        let key = attributes.identifier
        // The app derives the deadline from "now + remaining" on each event,
        // so the same window drifts by a moment between syncs. Only a real
        // jump in the deadline counts as a new window.
        let previous = states[key].flatMap {
            abs($0.endsAt.timeIntervalSince(reportedEnd)) < DesignTokens.Duration.liveActivityWindowTolerance ? $0 : nil
        }
        let endsAt = previous?.endsAt ?? reportedEnd
        let state = PermitJoinActivityAttributes.ContentState(
            joinedCount: max(0, joinedCount),
            // Keep the original start time across bridge-state syncs of the
            // same window. A new value here turns an otherwise identical
            // update into a visual change, making Dynamic Island repeatedly
            // expand on Home Screen.
            startedAt: previous?.startedAt ?? .now,
            endsAt: endsAt,
            targetName: targetName,
            interviewing: interviewing,
            interviewFailure: interviewFailure,
            recentlyPaired: recentlyPaired
        )
        // A new window (different deadline) is presented fresh: the previous
        // card may already have been ended or swiped away, and an update
        // alone would never bring it back.
        let alreadyVisible = tracked[key] != nil && previous != nil
        tracked[key] = attributes
        guard states[key] != state || !alreadyVisible else { return }
        states[key] = state
        expiryTasks[key]?.cancel()
        expiryTasks[key] = Task { @MainActor [weak self] in
            let seconds = max(0, endsAt.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            guard let self, self.tracked[key] != nil else { return }
            self.clear(bridgeID: bridgeID)
        }

        let alert = Self.alert(from: previous, to: state)
        let previousDelivery = lastDelivery
        lastDelivery = Task { [attributes, controller] in
            await previousDelivery?.value
            if alreadyVisible {
                await controller.update(
                    attributes: attributes,
                    state: state,
                    staleDate: endsAt,
                    relevanceScore: 65,
                    alert: alert
                )
            } else {
                await controller.present(
                    attributes: attributes,
                    state: state,
                    staleDate: endsAt,
                    relevanceScore: 65
                )
            }
        }
    }

    func clear(bridgeID: UUID?) {
        let identifier = makeIdentifier(bridgeID: bridgeID)
        // An activity outlives the process that started it. After a relaunch
        // nothing is tracked, but a stale pairing activity may still be on
        // screen, so end any activity carrying this identifier.
        let attributes = tracked.removeValue(forKey: identifier)
            ?? Activity<PermitJoinActivityAttributes>.activities
                .first { $0.attributes.identifier == identifier }?.attributes
        guard let attributes else { return }
        let last = states.removeValue(forKey: identifier)
        expiryTasks.removeValue(forKey: identifier)?.cancel()
        let state = PermitJoinActivityAttributes.ContentState(
            joinedCount: last?.joinedCount ?? 0,
            startedAt: last?.startedAt ?? .now,
            endsAt: .now,
            targetName: nil
        )
        let previousDelivery = lastDelivery
        lastDelivery = Task { [controller] in
            await previousDelivery?.value
            await controller.cancel(attributes: attributes, with: state)
        }
    }

    func clearAll() {
        tracked.removeAll()
        states.removeAll()
        expiryTasks.values.forEach { $0.cancel() }
        expiryTasks.removeAll()
        Task {
            await LiveActivityController<PermitJoinActivityAttributes>.endAllActivities()
        }
    }

    /// A device finishing its interview is the moment worth interrupting
    /// for: the alert briefly expands the Dynamic Island (and lights the Lock
    /// Screen) to show it.
    private static func alert(
        from previous: PermitJoinActivityAttributes.ContentState?,
        to state: PermitJoinActivityAttributes.ContentState
    ) -> AlertConfiguration? {
        if let paired = state.recentlyPaired, paired != previous?.recentlyPaired {
            return AlertConfiguration(title: "Paired", body: "\(paired)", sound: .default)
        }
        if let failed = state.interviewFailure, failed != previous?.interviewFailure {
            return AlertConfiguration(title: "Interview failed", body: "\(failed)", sound: .default)
        }
        return nil
    }

    private func makeAttributes(bridgeID: UUID?, bridgeDisplayName: String) -> PermitJoinActivityAttributes {
        PermitJoinActivityAttributes(
            identifier: makeIdentifier(bridgeID: bridgeID),
            bridgeDisplayName: bridgeDisplayName
        )
    }

    private func makeIdentifier(bridgeID: UUID?) -> String {
        bridgeID.map { "permit-join-\($0.uuidString)" } ?? "permit-join-default"
    }
}
