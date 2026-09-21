import SwiftUI

/// The expanded state of the tab-bar Activity Center. On iPhone it is the
/// destination of the tab accessory's system zoom transition.
struct ActivityCenterSheet: View {
    let transitionNamespace: Namespace.ID?
    let workspace: LogsWorkspaceState

    var body: some View {
        activityContent
    }

    @ViewBuilder
    private var activityContent: some View {
        let content = NavigationStack {
            LogsView(usesActivityFeed: true, navigationTitle: "", workspace: workspace)
                .toolbar { ActivityCenterGrabber() }
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

/// Sheets show a grabber when they can be dragged away; this full-screen
/// presentation can too. It takes the toolbar's centre slot, so it lines up
/// with the buttons on either side and stays clear of the Dynamic Island.
private struct ActivityCenterGrabber: ToolbarContent {
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .principal) { GrabberCapsule() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) { GrabberCapsule() }
        }
    }
}

private struct GrabberCapsule: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Capsule()
            .fill(.tertiary)
            .frame(
                width: DesignTokens.ActivityFeed.grabberWidth,
                height: DesignTokens.ActivityFeed.grabberHeight
            )
            .accessibilityElement()
            .accessibilityLabel("Close Activity")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { dismiss() }
    }
}

/// Presents the iPhone Activity Center. When it is disabled, neither a direct
/// notification action nor stale scene state can surface an in-app event UI.
struct ActivityCenterSheetPresentation: ViewModifier {
    @Environment(\.sceneNavigation) private var sceneNavigation
    @AppStorage(ActivityCenterSettings.isEnabledStorageKey) private var isEnabled = true
    let transitionNamespace: Namespace.ID?
    let workspace: LogsWorkspaceState

    func body(content: Content) -> some View {
        if isEnabled {
            content.fullScreenCover(isPresented: Binding(
                get: { sceneNavigation.isActivityCenterPresented },
                set: { sceneNavigation.isActivityCenterPresented = $0 }
            )) {
                ActivityCenterSheet(
                    transitionNamespace: transitionNamespace,
                    workspace: workspace
                )
            }
        } else {
            content
        }
    }
}
