import Foundation

@MainActor
final class BridgeOperationLiveActivityCoordinator {
    static let shared = BridgeOperationLiveActivityCoordinator()

    private let controller = LiveActivityController<BridgeOperationActivityAttributes>(
        dismissesOtherActivities: false
    ) { existing, requested in
        existing.identifier == requested.identifier
    }

    private var tracked: [String: BridgeOperationActivityAttributes] = [:]
    private var expiryTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    func startScan(bridgeID: UUID?, bridgeDisplayName: String) {
        let attributes = makeAttributes(
            bridgeID: bridgeID,
            operation: .touchlinkScan,
            bridgeDisplayName: bridgeDisplayName
        )
        start(
            attributes: attributes,
            detail: "Looking for nearby devices",
            duration: DesignTokens.Duration.liveActivityTouchlinkScan
        )
    }

    func finishScan(bridgeID: UUID?, foundCount: Int) {
        let attributes = makeAttributes(
            bridgeID: bridgeID,
            operation: .touchlinkScan,
            bridgeDisplayName: ""
        )
        finish(
            attributes: attributes,
            detail: foundCount == 1 ? "1 device found" : "\(foundCount) devices found",
            foundCount: foundCount
        )
    }

    func startIdentify(bridgeID: UUID?, bridgeDisplayName: String, deviceName: String) {
        let attributes = makeAttributes(
            bridgeID: bridgeID,
            operation: .touchlinkIdentify,
            bridgeDisplayName: bridgeDisplayName,
            deviceName: deviceName
        )
        start(
            attributes: attributes,
            detail: deviceName,
            duration: DesignTokens.Duration.liveActivityTouchlinkIdentify
        )
    }

    func finishIdentify(bridgeID: UUID?, success: Bool) {
        let attributes = makeAttributes(
            bridgeID: bridgeID,
            operation: .touchlinkIdentify,
            bridgeDisplayName: ""
        )
        finish(
            attributes: attributes,
            detail: success ? "Identify complete" : "Identify failed",
            foundCount: 0,
            success: success
        )
    }

    func failAll(bridgeID: UUID?) {
        let suffix = identifierSuffix(bridgeID: bridgeID)
        let operations = tracked.filter { $0.key.hasSuffix(suffix) }.map(\.value)
        for attributes in operations {
            finish(
                attributes: attributes,
                detail: "Operation failed",
                foundCount: 0,
                success: false
            )
        }
    }

    func clear(bridgeID: UUID?) {
        let suffix = identifierSuffix(bridgeID: bridgeID)
        let operations = tracked.filter { $0.key.hasSuffix(suffix) }.map(\.value)
        for attributes in operations {
            let key = attributes.identifier
            expiryTasks[key]?.cancel()
            expiryTasks.removeValue(forKey: key)
            tracked.removeValue(forKey: key)
            Task {
                await controller.cancel(
                    attributes: attributes,
                    with: .init(
                        phase: .completed,
                        detail: "",
                        foundCount: 0,
                        startedAt: .now,
                        endsAt: .now
                    )
                )
            }
        }
    }

    func clearAll() {
        tracked.removeAll()
        expiryTasks.values.forEach { $0.cancel() }
        expiryTasks.removeAll()
        Task {
            await LiveActivityController<BridgeOperationActivityAttributes>.endAllActivities()
        }
    }

    private func start(
        attributes: BridgeOperationActivityAttributes,
        detail: String,
        duration: TimeInterval
    ) {
        let now = Date.now
        let endsAt = now.addingTimeInterval(duration)
        let state = BridgeOperationActivityAttributes.ContentState(
            phase: .active,
            detail: detail,
            foundCount: 0,
            startedAt: now,
            endsAt: endsAt
        )
        let key = attributes.identifier
        expiryTasks[key]?.cancel()
        tracked[key] = attributes
        expiryTasks[key] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            guard let self, self.tracked[key] != nil else { return }
            self.finish(attributes: attributes, detail: "Operation timed out", foundCount: 0, success: false)
        }
        Task {
            await controller.present(
                attributes: attributes,
                state: state,
                staleDate: endsAt,
                relevanceScore: attributes.operation == .touchlinkIdentify ? 45 : 35
            )
        }
    }

    private func finish(
        attributes: BridgeOperationActivityAttributes,
        detail: String,
        foundCount: Int,
        success: Bool = true
    ) {
        let key = attributes.identifier
        expiryTasks[key]?.cancel()
        expiryTasks.removeValue(forKey: key)
        tracked.removeValue(forKey: key)
        let now = Date.now
        let state = BridgeOperationActivityAttributes.ContentState(
            phase: success ? .completed : .failed,
            detail: detail,
            foundCount: foundCount,
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

    private func makeAttributes(
        bridgeID: UUID?,
        operation: BridgeOperationActivityAttributes.Operation,
        bridgeDisplayName: String,
        deviceName: String? = nil
    ) -> BridgeOperationActivityAttributes {
        let bridgePart = bridgeID.map { $0.uuidString } ?? "default"
        let operationPart = operation.rawValue
        return BridgeOperationActivityAttributes(
            identifier: "\(operationPart)-\(bridgePart)",
            operation: operation,
            bridgeDisplayName: bridgeDisplayName,
            deviceName: deviceName
        )
    }

    private func identifierSuffix(bridgeID: UUID?) -> String {
        let bridgePart = bridgeID.map { $0.uuidString } ?? "default"
        return "-\(bridgePart)"
    }
}
