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
        joinedCount: Int
    ) {
        guard Self.isEnabled else {
            clear(bridgeID: bridgeID)
            return
        }
        guard isOpen,
              let endMilliseconds,
              endMilliseconds > 0,
              Date(timeIntervalSince1970: Double(endMilliseconds) / 1_000) > .now
        else {
            clear(bridgeID: bridgeID)
            return
        }
        let endsAt = Date(timeIntervalSince1970: Double(endMilliseconds) / 1_000)

        let attributes = makeAttributes(bridgeID: bridgeID, bridgeDisplayName: bridgeDisplayName)
        let key = attributes.identifier
        let state = PermitJoinActivityAttributes.ContentState(
            joinedCount: max(0, joinedCount),
            // Keep the original start time across bridge-state syncs. A new
            // value here turns an otherwise identical update into a visual
            // change, making Dynamic Island repeatedly expand on Home Screen.
            startedAt: states[key]?.startedAt ?? .now,
            endsAt: endsAt,
            targetName: targetName
        )
        let alreadyVisible = tracked[key] != nil
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

        Task { [attributes] in
            if alreadyVisible {
                await controller.update(
                    attributes: attributes,
                    state: state,
                    staleDate: endsAt,
                    relevanceScore: 65
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
        Task {
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
