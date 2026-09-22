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
        }
        .configuredTopScrollEdgeEffect()
        .overlay(alignment: .top) {
            GrabberCapsule()
                .padding(.top, DesignTokens.Spacing.xs)
        }

        if #available(iOS 18.0, *), let transitionNamespace {
            content
                .navigationTransition(.zoom(sourceID: "activity-center", in: transitionNamespace))
        } else {
            content
        }
    }
}

/// The full-screen Activity Center keeps its pull-down affordance fixed at
/// the visual centre. A navigation-bar principal item would move sideways as
/// filters and other trailing actions appear.
private struct GrabberCapsule: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Capsule()
                .fill(.tertiary)
                .frame(
                    width: DesignTokens.ActivityFeed.grabberWidth,
                    height: DesignTokens.ActivityFeed.grabberHeight
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close Activity")
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
