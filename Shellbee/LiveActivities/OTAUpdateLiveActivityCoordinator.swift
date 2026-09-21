import Foundation

/// Manages OTA Live Activities. Phase 2 multi-bridge: each connected bridge
/// gets its own OTA activity (identifier `"ota-updates-<bridgeID>"`) so two
/// bridges running simultaneous upgrades surface as two distinct activities
/// rather than colliding on one. The coordinator stays a singleton because
/// ActivityKit itself is process-wide; per-bridge state lives in
/// `visibleBridges`.
@MainActor
final class OTAUpdateLiveActivityCoordinator {
    static let shared = OTAUpdateLiveActivityCoordinator()

    private let controller = LiveActivityController<OTAUpdateActivityAttributes>(
        dismissesOtherActivities: false
    ) {
        (existing: OTAUpdateActivityAttributes, requested: OTAUpdateActivityAttributes) in
        existing.identifier == requested.identifier
    }
    /// Bridge ids whose activities are currently presented. Lets us decide
    /// between `present` and `update` per bridge without re-querying ActivityKit.
    private var visibleBridges: Set<UUID> = []
    /// Last estimated finish per bridge, kept steady unless Z2M's estimate
    /// moves meaningfully so the countdown doesn't twitch.
    private var estimatedEnds: [UUID: Date] = [:]

    private init() {}

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: ConnectionSessionController.otaLiveActivityEnabledKey) as? Bool ?? true
    }

    /// Whether scheduled OTAs (parked, waiting for the device to wake) are
    /// surfaced in the OTA Live Activity. Off by default — a scheduled OTA can
    /// sit pending for hours or days, and most users don't want a Lock-Screen
    /// surface for that.
    static var isScheduledEnabled: Bool {
        UserDefaults.standard.object(forKey: ConnectionSessionController.otaScheduledLiveActivityEnabledKey) as? Bool ?? false
    }

    func sync(
        with statuses: [OTAUpdateStatus],
        devices: [Device] = [],
        bridgeID: UUID? = nil,
        bridgeDisplayName: String = ""
    ) {
        guard Self.isEnabled else {
            if !visibleBridges.isEmpty { clearAll() }
            return
        }
        let scheduledEnabled = Self.isScheduledEnabled
        let activeStatuses = statuses
            .filter(\.isActive)
            .filter { scheduledEnabled || $0.phase != .scheduled }
            .sorted { lhs, rhs in
                if lhs.sortPriority != rhs.sortPriority {
                    return lhs.sortPriority < rhs.sortPriority
                }
                return lhs.deviceName.localizedCompare(rhs.deviceName) == .orderedAscending
            }

        let attributes = makeAttributes(bridgeID: bridgeID, bridgeDisplayName: bridgeDisplayName)
        let key = bridgeID ?? defaultKey

        guard !activeStatuses.isEmpty else {
            if visibleBridges.contains(key) {
                clear(bridgeID: bridgeID)
            }
            return
        }

        let symbolMap = Dictionary(uniqueKeysWithValues: devices.map { ($0.friendlyName, $0.categorySystemImage) })

        var content = contentState(
            phase: .active,
            statuses: activeStatuses,
            detail: detailText(for: activeStatuses),
            symbolMap: symbolMap
        )
        applyEstimate(to: &content, from: activeStatuses, key: key)

        let alreadyVisible = visibleBridges.contains(key)
        let staleDate = max(
            Date.now.addingTimeInterval(DesignTokens.Duration.liveActivityOTAStale),
            content.estimatedEnd ?? .distantPast
        )
        Task { [attributes] in
            if alreadyVisible {
                await controller.update(
                    attributes: attributes,
                    state: content,
                    staleDate: staleDate,
                    relevanceScore: 70
                )
            } else {
                await controller.present(
                    attributes: attributes,
                    state: content,
                    staleDate: staleDate,
                    relevanceScore: 70
                )
            }
        }
        visibleBridges.insert(key)
    }

    func finish(for deviceName: String, success: Bool, bridgeID: UUID? = nil) {
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

        let key = bridgeID ?? defaultKey
        visibleBridges.remove(key)
        estimatedEnds.removeValue(forKey: key)
        let attributes = makeAttributes(bridgeID: bridgeID, bridgeDisplayName: "")

        Task { [attributes] in
            await controller.finish(
                attributes: attributes,
                state: state,
                displayFor: success
                    ? DesignTokens.Duration.liveActivitySuccess
                    : DesignTokens.Duration.liveActivityFailure
            )
        }
    }

    /// Tear down a single bridge's activity. Other bridges' activities stay.
    func clear(bridgeID: UUID?) {
        let key = bridgeID ?? defaultKey
        estimatedEnds.removeValue(forKey: key)
        guard visibleBridges.remove(key) != nil else { return }
        let cancelState = OTAUpdateActivityAttributes.ContentState(
            phase: .completed,
            activeCount: 0,
            headline: "",
            detail: "",
            progress: nil,
            items: []
        )
        let attributes = makeAttributes(bridgeID: bridgeID, bridgeDisplayName: "")
        Task { [attributes] in
            await controller.cancel(attributes: attributes, with: cancelState)
        }
    }

    func clearAll() {
        visibleBridges.removeAll()
        estimatedEnds.removeAll()
        Task {
            await LiveActivityController<OTAUpdateActivityAttributes>.endAllActivities()
        }
    }

    // MARK: - Helpers

    /// Sentinel UUID for "no bridge id supplied" — keeps the legacy
    /// single-bridge `sync(with:)` callers working with a stable key.
    private let defaultKey = UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))

    private func makeAttributes(bridgeID: UUID?, bridgeDisplayName: String) -> OTAUpdateActivityAttributes {
        let id = bridgeID.map { "ota-updates-\($0.uuidString)" } ?? "ota-updates"
        return OTAUpdateActivityAttributes(identifier: id, bridgeDisplayName: bridgeDisplayName)
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
            headline: statuses.count == 1 ? "Updating" : "\(statuses.count) device updates",
            detail: detail,
            progress: aggregateProgress(for: statuses),
            items: statuses.map {
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
            return "\(updating.deviceName) · \(progressText)"
        }

        if let scheduled = statuses.first(where: { $0.phase == .scheduled }) {
            return "\(scheduled.deviceName) · Scheduled"
        }

        if let requested = statuses.first(where: { $0.phase == .requested }) {
            return "\(requested.deviceName) · Starting"
        }

        return "Preparing upgrades"
    }

    /// Pins the running update's finish time from Z2M's `remaining`, and
    /// back-computes a start so a filling timer begins at the current
    /// progress. The finish only moves when the estimate shifts by more
    /// than the tolerance.
    private func applyEstimate(
        to content: inout OTAUpdateActivityAttributes.ContentState,
        from statuses: [OTAUpdateStatus],
        key: UUID
    ) {
        guard let running = statuses.first(where: { $0.phase == .updating }),
              let remaining = running.remaining, remaining > 0
        else {
            estimatedEnds.removeValue(forKey: key)
            return
        }
        let now = Date.now
        let reported = now.addingTimeInterval(Double(remaining))
        let end: Date
        if let previous = estimatedEnds[key],
           abs(previous.timeIntervalSince(reported)) < Double(remaining) * DesignTokens.Duration.liveActivityOTAEstimateTolerance {
            end = previous
        } else {
            end = reported
        }
        estimatedEnds[key] = end
        let fraction = min(max((running.progress ?? 0) / 100, 0), 0.99)
        let left = max(end.timeIntervalSince(now), 1)
        content.estimatedEnd = end
        content.progressStart = end.addingTimeInterval(-left / (1 - fraction))
    }

    private func aggregateProgress(for statuses: [OTAUpdateStatus]) -> Int? {
        let progressValues = statuses.compactMap(\.progress)
        guard !progressValues.isEmpty else { return nil }
        let total = progressValues.reduce(0.0, +)
        return Int(total / Double(progressValues.count))
    }
}
