#if DEBUG
import SwiftUI
import UIKit

/// Debug launch hook: `SHELLBEE_LIVE_ACTIVITY_STAGE=<kind>` opens the stage
/// in its own window above the app, independent of the app's navigation, so
/// it can be reviewed straight from a fresh launch.
@MainActor
enum LiveActivityStageLauncher {
    private static var window: UIWindow?

    static func openIfRequested() {
        guard #available(iOS 26.0, *),
              let raw = ProcessInfo.processInfo.environment["SHELLBEE_LIVE_ACTIVITY_STAGE"],
              let kind = LiveActivityGalleryKind(rawValue: raw)
        else { return }
        Task { @MainActor in
            // Wait for the first scene to connect.
            while UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) == nil {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert
            let env = ProcessInfo.processInfo.environment
            let stage = LiveActivityStageView(
                kind: kind,
                onClose: {
                    LiveActivityStageLauncher.window?.isHidden = true
                    LiveActivityStageLauncher.window = nil
                },
                sampleIndex: env["SHELLBEE_LIVE_ACTIVITY_STAGE_STATE"].flatMap(Int.init) ?? 0,
                surface: env["SHELLBEE_LIVE_ACTIVITY_STAGE_SURFACE"].flatMap(LiveActivityStageView.Surface.init) ?? .compact,
                style: env["SHELLBEE_LIVE_ACTIVITY_STAGE_STYLE"].flatMap(LiveActivityStyle.init) ?? .permitJoinDefault
            )
            window.rootViewController = UIHostingController(rootView: stage)
            window.makeKeyAndVisible()
            self.window = window
        }
    }
}
#endif
