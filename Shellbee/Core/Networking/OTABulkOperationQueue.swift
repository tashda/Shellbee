import Foundation

// Rate-limited queue for bulk OTA check/update requests.
//
// Why this exists: Z2M dispatches OTA checks through the Zigbee mesh via
// zigbee-herdsman. It serializes per-device (via `#inProgress` keyed by
// ieeeAddr) but not globally — concurrent checks are bounded only by the
// adapter's `adapter_concurrent` setting. Firing 80+ checks in parallel
// floods the coordinator's APS queue and produces "server didn't respond"
// errors on zStack (CC2652/CC1352), EZSP, and deCONZ adapters alike.
//
// Defaults (3 concurrent, 45s check timeout) target zStack/EZSP, which are
// the most common adapters. Users on deCONZ/ConBee can drop concurrency to
// 1 from Settings > Application > Performance.
@MainActor
@Observable
final class OTABulkOperationQueue {

    enum Kind: Sendable, Equatable {
        case check
        case update
    }

    struct Progress: Equatable, Sendable {
        var kind: Kind
        var total: Int
        var completed: Int
        var inFlight: Int
        var failed: Int
    }

    struct CompletionSummary: Identifiable, Equatable, Sendable {
        let id: UUID
        let kind: Kind
        let total: Int
        let succeeded: Int
        let failed: Int
        let wasCancelled: Bool
    }

    static let concurrencyKey = "appOTABulkConcurrency"
    static let checkTimeoutKey = "appOTABulkCheckTimeoutSeconds"
    static let defaultConcurrency = 3
    static let defaultCheckTimeoutSeconds = 45
    static let concurrencyRange = 1...8
    static let checkTimeoutRange = 10...180

    private(set) var progress: Progress?
    private(set) var lastSummary: CompletionSummary?

    var isActive: Bool { progress != nil }

    private let sender: @MainActor (String, JSONValue) -> Void
    private let onCompletion: (@MainActor (CompletionSummary) -> Void)?
    private let updateTimeout: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let settingsProvider: @MainActor () -> (concurrency: Int, checkTimeout: Duration)

    private var pending: [String] = []
    private var currentKind: Kind?
    private var inFlight: [String: CheckedContinuation<Bool, Never>] = [:]
    private var timeoutTasks: [String: Task<Void, Never>] = [:]
    private var activeWorkers = 0
    private var totalCount = 0
    private var completedCount = 0
    private var failedCount = 0
    private var wasCancelled = false

    init(
        sender: @escaping @MainActor (String, JSONValue) -> Void,
        onCompletion: (@MainActor (CompletionSummary) -> Void)? = nil,
        updateTimeout: Duration = .seconds(600),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        settingsProvider: (@MainActor () -> (concurrency: Int, checkTimeout: Duration))? = nil
    ) {
        self.sender = sender
        self.onCompletion = onCompletion
        self.updateTimeout = updateTimeout
        self.sleep = sleep
        self.settingsProvider = settingsProvider ?? Self.defaultSettingsProvider
    }

    static let defaultSettingsProvider: @MainActor () -> (concurrency: Int, checkTimeout: Duration) = {
        let defaults = UserDefaults.standard
        let rawConcurrency = defaults.object(forKey: concurrencyKey) as? Int ?? defaultConcurrency
        let concurrency = min(max(rawConcurrency, concurrencyRange.lowerBound), concurrencyRange.upperBound)
        let rawTimeout = defaults.object(forKey: checkTimeoutKey) as? Int ?? defaultCheckTimeoutSeconds
        let timeoutSeconds = min(max(rawTimeout, checkTimeoutRange.lowerBound), checkTimeoutRange.upperBound)
        return (concurrency, .seconds(timeoutSeconds))
    }

    func enqueue(_ friendlyNames: [String], kind: Kind) {
        guard !friendlyNames.isEmpty else { return }
        if let currentKind, currentKind != kind { return }

        pending.append(contentsOf: friendlyNames)
        totalCount += friendlyNames.count
        currentKind = kind
        refreshProgress()

        startWorkersIfNeeded(kind: kind)
    }

    func cancelAll() {
        wasCancelled = true
        pending.removeAll()
        for (_, task) in timeoutTasks { task.cancel() }
        timeoutTasks.removeAll()
        let pendingContinuations = inFlight
        inFlight.removeAll()
        for (_, cont) in pendingContinuations {
            cont.resume(returning: false)
        }
    }

    func handleResponse(friendlyName: String, success: Bool, kind: Kind) {
        guard currentKind == kind else { return }
        finishInFlight(name: friendlyName, success: success)
    }

    private func finishInFlight(name: String, success: Bool) {
        if let task = timeoutTasks.removeValue(forKey: name) {
            task.cancel()
        }
        guard let cont = inFlight.removeValue(forKey: name) else { return }
        cont.resume(returning: success)
    }

    private func startWorkersIfNeeded(kind: Kind) {
        let settings = settingsProvider()
        let target = kind == .check ? settings.concurrency : 1
        let timeout = kind == .check ? settings.checkTimeout : updateTimeout
        let topic = kind == .check ? Z2MTopics.Request.deviceOTACheck : Z2MTopics.Request.deviceOTAUpdate
        while activeWorkers < target, !pending.isEmpty {
            activeWorkers += 1
            Task { [weak self] in
                await self?.workerLoop(kind: kind, topic: topic, timeout: timeout)
            }
        }
    }

    private func workerLoop(kind: Kind, topic: String, timeout: Duration) async {
        while !wasCancelled, let name = pending.first {
            pending.removeFirst()
            refreshProgress(inFlightDelta: 1)
            sender(topic, .object(["id": .string(name)]))

            let success = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                inFlight[name] = cont
                let localSleep = sleep
                let task = Task { [weak self] in
                    try? await localSleep(timeout)
                    if Task.isCancelled { return }
                    self?.finishInFlight(name: name, success: false)
                }
                timeoutTasks[name] = task
            }

            completedCount += 1
            if !success { failedCount += 1 }
            refreshProgress(inFlightDelta: -1)
        }

        activeWorkers -= 1
        if activeWorkers == 0 && inFlight.isEmpty && pending.isEmpty {
            finalize(kind: kind)
        }
    }

    private func finalize(kind: Kind) {
        let summary = CompletionSummary(
            id: UUID(),
            kind: kind,
            total: totalCount,
            succeeded: completedCount - failedCount,
            failed: failedCount,
            wasCancelled: wasCancelled
        )
        lastSummary = summary
        onCompletion?(summary)

        progress = nil
        currentKind = nil
        totalCount = 0
        completedCount = 0
        failedCount = 0
        wasCancelled = false
    }

    private func refreshProgress(inFlightDelta: Int = 0) {
        guard let kind = currentKind ?? (progress?.kind) else {
            progress = nil
            return
        }
        let currentInFlight = (progress?.inFlight ?? 0) + inFlightDelta
        progress = Progress(
            kind: kind,
            total: totalCount,
            completed: completedCount,
            inFlight: max(0, currentInFlight),
            failed: failedCount
        )
    }
}
