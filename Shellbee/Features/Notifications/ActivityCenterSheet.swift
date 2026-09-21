import SwiftUI

/// The expanded state of the tab-bar Activity Center. On iPhone it is the
/// destination of the tab accessory's system zoom transition.
struct ActivityCenterSheet: View {
    let transitionNamespace: Namespace.ID?

    var body: some View {
        activityContent
    }

    @ViewBuilder
    private var activityContent: some View {
        let content = NavigationStack {
            LogsView(navigationTitle: "")
        }
        .configuredTopScrollEdgeEffect()

        if #available(iOS 18.0, *), let transitionNamespace {
            content
                .navigationTransition(.zoom(sourceID: "activity-center", in: transitionNamespace))
        } else {
            content
        }
    }
}

/// Presents the same Activity Center on every app form factor. When it is
/// disabled, neither a direct notification action nor stale scene state can
/// surface an in-app event UI.
struct ActivityCenterSheetPresentation: ViewModifier {
    @Environment(\.sceneNavigation) private var sceneNavigation
    @AppStorage(ActivityCenterSettings.isEnabledStorageKey) private var isEnabled = true
    let transitionNamespace: Namespace.ID?

    func body(content: Content) -> some View {
        if isEnabled {
            content.fullScreenCover(isPresented: Binding(
                get: { sceneNavigation.isActivityCenterPresented },
                set: { sceneNavigation.isActivityCenterPresented = $0 }
            )) {
                ActivityCenterSheet(transitionNamespace: transitionNamespace)
            }
        } else {
            content
        }
    }
}
