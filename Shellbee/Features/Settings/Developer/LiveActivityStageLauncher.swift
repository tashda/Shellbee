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
            window.rootViewController = UIHostingController(rootView: LiveActivityStageView(kind: kind) {
                LiveActivityStageLauncher.window?.isHidden = true
                LiveActivityStageLauncher.window = nil
            })
            window.makeKeyAndVisible()
            self.window = window
        }
    }
}
#endif
