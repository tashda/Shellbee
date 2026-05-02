import Foundation
import Observation

#if canImport(Sentry)
import Sentry
#endif

@Observable
final class SentryService {
    static let shared = SentryService()

    private(set) var isEnabled = false
    private(set) var hasPendingCrash: Bool = PendingCrashStore.load() != nil

    private var sessionApproved = false
    private let consent = CrashReportingConsent.shared

    private init() {}

    func start() {
        #if canImport(Sentry)
        #if DEBUG
        return
        #else
        guard let dsn = Self.dsnFromInfoPlist(), !dsn.isEmpty else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.enableAutoSessionTracking = true
            options.enableCrashHandler = true
            options.enableAppHangTracking = true
            options.attachStacktrace = true
            options.sendDefaultPii = false
            options.maxBreadcrumbs = 50
            options.releaseName = Self.releaseName
            options.environment = "production"
            options.beforeSend = { [weak self] event in
                self?.processOutgoing(event: event) ?? nil
            }
            options.beforeBreadcrumb = { breadcrumb in
                Self.scrub(breadcrumb: breadcrumb)
                return breadcrumb
            }
        }

        isEnabled = true
        hasPendingCrash = PendingCrashStore.load() != nil
        #endif
        #endif
    }

    /// Called when user taps Share on the pending-crash sheet. The original
    /// Sentry event was dropped in beforeSend; we re-submit the stored summary
    /// as a manual message so it reaches the dashboard.
    func approveAndSendPending() {
        guard let pending = PendingCrashStore.load() else { return }
        PendingCrashStore.clear()
        hasPendingCrash = false

        #if canImport(Sentry)
        #if !DEBUG
        sessionApproved = true
        let scoped = { (scope: Scope) in
            scope.setTag(value: "user_approved", key: "crash_report.source")
            scope.setContext(value: [
                "captured_at": ISO8601DateFormatter().string(from: pending.capturedAt),
                "event_id": pending.eventID ?? ""
            ], key: "pending_crash")
        }
        SentrySDK.capture(message: pending.summary, block: scoped)
        SentrySDK.flush(timeout: 5)
        #endif
        #endif
    }

    func discardPending() {
        PendingCrashStore.clear()
        hasPendingCrash = false
    }

    /// Records a connection-lifecycle event for the named bridge. Surfaces in
    /// Sentry breadcrumbs alongside the bridge name so multi-bridge crash
    /// reports show which network was involved at the time of failure.
    /// Bridge names are user-readable strings — do not include tokens or
    /// other secrets.
    func recordBridgeEvent(_ message: String, bridgeName: String, level: BridgeEventLevel = .info) {
        #if canImport(Sentry)
        #if !DEBUG
        let breadcrumb = Breadcrumb(level: level.sentryLevel, category: "bridge")
        breadcrumb.message = "\(message) (\(bridgeName))"
        breadcrumb.data = ["bridge": bridgeName]
        SentrySDK.addBreadcrumb(breadcrumb)
        #endif
        #endif
    }

    enum BridgeEventLevel {
        case info, warning, error

        #if canImport(Sentry)
        var sentryLevel: SentryLevel {
            switch self {
            case .info: .info
            case .warning: .warning
            case .error: .error
            }
        }
        #endif
    }

    func enableAlwaysShareAndSendPending() {
        consent.alwaysShare = true
        approveAndSendPending()
    }

    // MARK: - Private

    #if canImport(Sentry)
    private func processOutgoing(event: Event) -> Event? {
        Self.scrub(event: event)

        if consent.alwaysShare || sessionApproved {
            return event
        }

        // User has not consented — save a summary so we can prompt on next launch,
        // then drop the event.
        let summary = Self.summarize(event: event)
        PendingCrashStore.save(PendingCrash(
            summary: summary,
            eventID: event.eventId.sentryIdString
        ))
        return nil
    }

    private static func summarize(event: Event) -> String {
        var lines: [String] = []
        if let exc = event.exceptions?.first {
            lines.append("\(exc.type): \(exc.value)")
            if let frames = exc.stacktrace?.frames.suffix(10) {
                for frame in frames {
                    let fn = frame.function ?? "?"
                    let file = frame.fileName ?? ""
                    let ln = frame.lineNumber.map { "\($0)" } ?? ""
                    lines.append("  at \(fn) \(file):\(ln)")
                }
            }
        } else if let msg = event.message?.formatted {
            lines.append(msg)
        } else {
            lines.append("Unknown crash")
        }
        return CrashReportScrubber.scrub(lines.joined(separator: "\n"))
    }

    private static func scrub(event: Event) {
        if let message = event.message?.formatted {
            event.message = SentryMessage(formatted: CrashReportScrubber.scrub(message))
        }
        if let exceptions = event.exceptions {
            for exc in exceptions {
                exc.value = CrashReportScrubber.scrub(exc.value)
            }
        }
        if let breadcrumbs = event.breadcrumbs {
            for bc in breadcrumbs { scrub(breadcrumb: bc) }
        }
        // Drop any user identifier — we never want to attach one.
        event.user = nil
    }

    private static func scrub(breadcrumb: Breadcrumb) {
        if let msg = breadcrumb.message {
            breadcrumb.message = CrashReportScrubber.scrub(msg)
        }
        if let data = breadcrumb.data {
            var scrubbed: [String: Any] = [:]
            for (k, v) in data {
                if let s = v as? String {
                    scrubbed[k] = CrashReportScrubber.scrub(s)
                } else {
                    scrubbed[k] = v
                }
            }
            breadcrumb.data = scrubbed
        }
    }
    #endif

    private static func dsnFromInfoPlist() -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static var releaseName: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let bundle = Bundle.main.bundleIdentifier ?? "shellbee"
        return "\(bundle)@\(version)+\(build)"
    }
}
