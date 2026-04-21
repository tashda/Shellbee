import Foundation

@MainActor
final class OTAUpdateLiveActivityCoordinator {
    static let shared = OTAUpdateLiveActivityCoordinator()

    private let controller = LiveActivityController<OTAUpdateActivityAttributes> {
        (existing: OTAUpdateActivityAttributes, requested: OTAUpdateActivityAttributes) in
        existing.identifier == requested.identifier
    }
    private let attributes = OTAUpdateActivityAttributes(identifier: "ota-updates")
    private var isVisible = false

    private init() {}

    func sync(with statuses: [OTAUpdateStatus], devices: [Device] = []) {
        let activeStatuses = statuses
            .filter(\.isActive)
            .sorted { lhs, rhs in
                if lhs.sortPriority != rhs.sortPriority {
                    return lhs.sortPriority < rhs.sortPriority
                }
                return lhs.deviceName.localizedCompare(rhs.deviceName) == .orderedAscending
            }

        guard !activeStatuses.isEmpty else {
            if isVisible {
                clearAll()
            }
            return
        }

        let symbolMap = Dictionary(uniqueKeysWithValues: devices.map { ($0.friendlyName, $0.categorySystemImage) })

        let content = contentState(
            phase: .active,
            statuses: activeStatuses,
            detail: detailText(for: activeStatuses),
            symbolMap: symbolMap
        )

        Task {
            if isVisible {
                await controller.update(state: content)
            } else {
                isVisible = true
                await controller.present(attributes: attributes, state: content)
            }
        }
    }

    func finish(for deviceName: String, success: Bool) {
        let state = OTAUpdateActivityAttributes.ContentState(
            phase: success ? .completed : .failed,
            activeCount: 0,
            headline: success ? "Upgrade complete" : "Upgrade failed",
            detail: deviceName,
            progress: success ? 100 : nil,
            items: [
                .init(
                    name: deviceName,
                    phase: success ? .idle : .available,
                    progress: success ? 100 : nil,
                    remaining: nil,
                    categorySymbol: nil
                )
            ]
        )

        isVisible = false

        Task {
            await controller.finish(
                state: state,
                displayFor: success
                    ? DesignTokens.Duration.liveActivitySuccess
                    : DesignTokens.Duration.liveActivityFailure
            )
        }
    }

    func clearAll() {
        isVisible = false
        Task {
            await LiveActivityController<OTAUpdateActivityAttributes>.endAllActivities()
        }
    }

    private func contentState(
        phase: OTAUpdateActivityAttributes.ContentState.Phase,
        statuses: [OTAUpdateStatus],
        detail: String,
        symbolMap: [String: String] = [:]
    ) -> OTAUpdateActivityAttributes.ContentState {
        OTAUpdateActivityAttributes.ContentState(
            phase: phase,
            activeCount: statuses.count,
            headline: statuses.count == 1 ? "1 upgrade running" : "\(statuses.count) upgrades running",
            detail: detail,
            progress: aggregateProgress(for: statuses),
            items: Array(statuses.prefix(3)).map {
                .init(
                    name: $0.deviceName,
                    phase: $0.phase,
                    progress: $0.progress.map(Int.init),
                    remaining: $0.remaining,
                    categorySymbol: symbolMap[$0.deviceName]
                )
            }
        )
    }

    private func detailText(for statuses: [OTAUpdateStatus]) -> String {
        if let updating = statuses.first(where: { $0.phase == .updating }) {
            let progressText = updating.progress.map { "\(Int($0))%" } ?? "Preparing"
            return "\(updating.deviceName) • \(progressText)"
        }

        if let scheduled = statuses.first(where: { $0.phase == .scheduled }) {
            return "\(scheduled.deviceName) • Scheduled"
        }

        if let requested = statuses.first(where: { $0.phase == .requested }) {
            return "\(requested.deviceName) • Starting"
        }

        return "Preparing upgrades"
    }

    private func aggregateProgress(for statuses: [OTAUpdateStatus]) -> Int? {
        let progressValues = statuses.compactMap(\.progress)
        guard !progressValues.isEmpty else { return nil }
        let total = progressValues.reduce(0.0, +)
        return Int(total / Double(progressValues.count))
    }
}
