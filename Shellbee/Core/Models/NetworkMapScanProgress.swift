import Foundation

/// Live progress of a Zigbee2MQTT network scan, built only from what the
/// bridge actually reports. Nothing here is estimated or simulated.
///
/// Z2M queries the coordinator and every router one at a time (pausing a
/// second between each) for its neighbor table; end devices are never
/// contacted — they appear in the map through their parent's table. While it
/// works, Z2M writes these log lines, which reach us on `bridge/logging`:
///
/// - `Starting network scan (…)` — info
/// - `LQI succeeded for '<name>'` — debug, only forwarded when *Log level* is
///   debug and *Log debug to MQTT and frontend* is on
/// - `Failed to execute LQI for '<name>'` — error, always forwarded
/// - `Network scan finished` — info
struct NetworkMapScanProgress: Equatable, Sendable {
    /// How much of the scan the bridge's logging configuration lets us see.
    enum Visibility: Equatable, Sendable {
        /// Every router's response arrives, so progress can be counted.
        case everyDevice
        /// Start, finish and failures arrive; successes are debug-only.
        case startAndFailures
        /// Only failures (error level) arrive.
        case failuresOnly
    }

    enum Outcome: Equatable, Sendable {
        case responded
        case failed
    }

    struct Event: Identifiable, Equatable, Sendable {
        let id: UUID
        let deviceName: String
        let outcome: Outcome
        let date: Date
    }

    /// Devices Z2M will query: the coordinator and every enabled router.
    let targetNames: [String]
    let visibility: Visibility
    let requestedAt: Date
    private(set) var scanStartedAt: Date?
    private(set) var scanFinishedAt: Date?
    private(set) var respondedNames: Set<String> = []
    private(set) var failedNames: [String] = []
    /// Newest first, capped so the live feed stays short.
    private(set) var recentEvents: [Event] = []

    static let recentEventLimit = 4

    init(targetNames: [String], visibility: Visibility, requestedAt: Date) {
        self.targetNames = targetNames
        self.visibility = visibility
        self.requestedAt = requestedAt
    }

    var targetCount: Int { targetNames.count }
    var respondedCount: Int { respondedNames.count }
    var failedCount: Int { failedNames.count }
    var finishedCount: Int { respondedCount + failedCount }
    var waitingCount: Int { max(targetCount - finishedCount, 0) }

    /// Only meaningful when every response is visible.
    var fractionComplete: Double? {
        guard visibility == .everyDevice, targetCount > 0 else { return nil }
        return min(Double(finishedCount) / Double(targetCount), 1)
    }

    /// Time left at the pace measured so far in this scan. Needs a few real
    /// responses before it says anything.
    func estimatedTimeRemaining(now: Date) -> TimeInterval? {
        guard visibility == .everyDevice, scanFinishedAt == nil,
              finishedCount >= 3, waitingCount > 0
        else { return nil }
        let start = scanStartedAt ?? requestedAt
        let pace = now.timeIntervalSince(start) / Double(finishedCount)
        return pace * Double(waitingCount)
    }

    /// Folds one Z2M log line into the progress. Returns whether it was a
    /// scan message, so callers only publish a change when something moved.
    @discardableResult
    mutating func ingest(logMessage message: String, at date: Date) -> Bool {
        if message.hasPrefix("Starting network scan") {
            scanStartedAt = scanStartedAt ?? date
            return true
        }
        if message.hasPrefix("Network scan finished") {
            scanFinishedAt = date
            return true
        }
        if let name = Self.deviceName(in: message, prefix: "LQI succeeded for ") {
            guard !respondedNames.contains(name) else { return false }
            respondedNames.insert(name)
            // A retry that succeeds after an earlier failure line wins.
            failedNames.removeAll { $0 == name }
            record(name, .responded, at: date)
            return true
        }
        if let name = Self.deviceName(in: message, prefix: "Failed to execute LQI for ") {
            guard !failedNames.contains(name), !respondedNames.contains(name) else { return false }
            failedNames.append(name)
            record(name, .failed, at: date)
            return true
        }
        return false
    }

    private mutating func record(_ name: String, _ outcome: Outcome, at date: Date) {
        // The scan has evidently started even if its start line was missed.
        scanStartedAt = scanStartedAt ?? date
        recentEvents.insert(Event(id: UUID(), deviceName: name, outcome: outcome, date: date), at: 0)
        if recentEvents.count > Self.recentEventLimit {
            recentEvents.removeLast(recentEvents.count - Self.recentEventLimit)
        }
    }

    /// Extracts `name` from `<prefix>'name'`.
    private static func deviceName(in message: String, prefix: String) -> String? {
        guard message.hasPrefix(prefix) else { return nil }
        let quoted = message.dropFirst(prefix.count)
        guard quoted.hasPrefix("'"), let closing = quoted.lastIndex(of: "'"), closing > quoted.startIndex else {
            return nil
        }
        let name = quoted[quoted.index(after: quoted.startIndex)..<closing]
        return name.isEmpty ? nil : String(name)
    }
}

extension NetworkMapScanProgress.Visibility {
    /// Mirrors Z2M's `bridge/logging` rules: debug lines are only forwarded
    /// with `log_debug_to_mqtt_frontend`, and nothing below the configured
    /// level is logged at all.
    init(logLevel: String?, debugToFrontend: Bool) {
        switch logLevel?.lowercased() {
        case "debug":
            self = debugToFrontend ? .everyDevice : .startAndFailures
        case "warning", "warn", "error":
            self = .failuresOnly
        default:
            self = .startAndFailures
        }
    }
}

/// The outcome of a finished scan, taken from Z2M's response itself: every
/// device it queried carries a `failed` list, empty when it answered.
struct NetworkMapScanSummary: Equatable, Sendable {
    let deviceCount: Int
    let queriedCount: Int
    let failedDeviceNames: [String]
    let linkCount: Int
    let duration: TimeInterval?

    var respondedCount: Int { max(queriedCount - failedDeviceNames.count, 0) }

    init(topology: NetworkTopology, progress: NetworkMapScanProgress?, finishedAt: Date) {
        deviceCount = topology.nodes.count
        linkCount = topology.links.count
        let queried = topology.nodes.filter { $0.failed != nil }
        if queried.isEmpty {
            // Older Z2M releases don't include `failed`; fall back to what
            // the logs told us during the scan.
            queriedCount = progress?.targetCount ?? 0
            failedDeviceNames = progress?.failedNames ?? []
        } else {
            queriedCount = queried.count
            failedDeviceNames = queried
                .filter { !($0.failed ?? []).isEmpty }
                .map(\.friendlyName)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        duration = progress.map { finishedAt.timeIntervalSince($0.requestedAt) }
    }
}
