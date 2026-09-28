import ActivityKit
import UIKit

/// Keeps Shellbee running for the short background window iOS grants after
/// the user leaves the app, but only while a Live Activity is on screen.
///
/// Live Activities are only visible once the app is in the background, and
/// the app is suspended moments later. Without this, a device that joins or
/// an interview that completes right after the user locks the phone never
/// reaches the activity, and "done" states that end themselves after a few
/// seconds never get to end.
@MainActor
enum LiveActivityBackgroundGrace {
    private static var task: UIBackgroundTaskIdentifier = .invalid
    private static var watcher: Task<Void, Never>?
    private static var observers: [NSObjectProtocol] = []
    /// Runs just before the grace time runs out, so cards can drop anything
    /// they won't be able to keep current once the app is suspended.
    private static var willSuspend: @MainActor () -> Void = {}

    static func install(willSuspend: @escaping @MainActor () -> Void) {
        self.willSuspend = willSuspend
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { begin() }
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { end() }
            }
        ]
    }

    private static func begin() {
        guard task == .invalid, hasActivities else { return }
        task = UIApplication.shared.beginBackgroundTask(withName: "Live Activities") {
            MainActor.assumeIsolated { end() }
        }
        // Give the time back as soon as nothing is left to keep current.
        watcher = Task { @MainActor in
            while !Task.isCancelled, hasActivities {
                if UIApplication.shared.backgroundTimeRemaining < DesignTokens.Duration.liveActivityGraceWrapUp {
                    willSuspend()
                    // Give the final card update time to reach the system.
                    try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityGracePoll))
                    break
                }
                try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityGracePoll))
            }
            end()
        }
    }

    private static func end() {
        watcher?.cancel()
        watcher = nil
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }

    private static var hasActivities: Bool {
        isShowing(PermitJoinActivityAttributes.self)
            || isShowing(OTAUpdateActivityAttributes.self)
            || isShowing(BridgeOperationActivityAttributes.self)
    }

    private static func isShowing<A: ActivityAttributes>(_: A.Type) -> Bool {
        Activity<A>.activities.contains { $0.activityState == .active || $0.activityState == .stale }
    }
}
