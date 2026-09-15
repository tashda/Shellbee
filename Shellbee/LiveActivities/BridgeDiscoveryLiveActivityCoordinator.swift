import Foundation

@MainActor
final class BridgeDiscoveryLiveActivityCoordinator {
    static let shared = BridgeDiscoveryLiveActivityCoordinator()

    private let controller = LiveActivityController<BridgeDiscoveryActivityAttributes>(
        dismissesOtherActivities: false
    ) { existing, requested in
        existing.identifier == requested.identifier
    }

    private let attributes = BridgeDiscoveryActivityAttributes()
    private var isVisible = false
    private var foundCount = 0
    private var startedAt = Date.now
    private var endsAt = Date.now
    private var expiryTask: Task<Void, Never>?

    private init() {}

    func start(duration: TimeInterval) {
        expiryTask?.cancel()
        let now = Date.now
        let endsAt = now.addingTimeInterval(duration)
        startedAt = now
        self.endsAt = endsAt
        let state = BridgeDiscoveryActivityAttributes.ContentState(
            foundCount: 0,
            startedAt: now,
            endsAt: endsAt
        )
        isVisible = true
        foundCount = 0
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            guard let self, self.isVisible else { return }
            self.finish(foundCount: self.foundCount)
        }
        Task {
            await controller.present(
                attributes: attributes,
                state: state,
                staleDate: endsAt,
                relevanceScore: 25
            )
        }
    }

    func update(foundCount: Int) {
        guard isVisible else { return }
        self.foundCount = max(0, foundCount)
        let state = BridgeDiscoveryActivityAttributes.ContentState(
            foundCount: self.foundCount,
            startedAt: startedAt,
            endsAt: endsAt
        )
        Task {
            await controller.update(
                attributes: attributes,
                state: state,
                staleDate: endsAt,
                relevanceScore: 25
            )
        }
    }

    func finish(foundCount: Int) {
        guard isVisible else { return }
        isVisible = false
        self.foundCount = max(0, foundCount)
        expiryTask?.cancel()
        expiryTask = nil
        startedAt = .now
        endsAt = .now
        let now = Date.now
        let state = BridgeDiscoveryActivityAttributes.ContentState(
            foundCount: self.foundCount,
            startedAt: now,
            endsAt: now
        )
        Task {
            await controller.finish(
                attributes: attributes,
                state: state,
                displayFor: DesignTokens.Duration.liveActivityMinimumVisible
            )
        }
    }

    func cancel() {
        guard isVisible else { return }
        isVisible = false
        foundCount = 0
        expiryTask?.cancel()
        expiryTask = nil
        startedAt = .now
        endsAt = .now
        Task {
            await controller.cancel(
                attributes: attributes,
                with: .init(foundCount: 0, startedAt: .now, endsAt: .now)
            )
        }
    }

    func clearAll() {
        isVisible = false
        foundCount = 0
        expiryTask?.cancel()
        expiryTask = nil
        startedAt = .now
        endsAt = .now
        Task {
            await LiveActivityController<BridgeDiscoveryActivityAttributes>.endAllActivities()
        }
    }
}
