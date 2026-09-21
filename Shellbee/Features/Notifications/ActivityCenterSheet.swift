import SwiftUI

/// The expanded state of the tab-bar Activity Center. On iPhone it is the
/// destination of the tab accessory's system zoom transition.
struct ActivityCenterSheet: View {
    let transitionNamespace: Namespace.ID?
    let workspace: LogsWorkspaceState

    @Environment(\.dismiss) private var dismiss
    @State private var topSafeArea: CGFloat = 0

    var body: some View {
        activityContent
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topSafeArea = $0 }
            .overlay(alignment: .top) { grabber }
    }

    /// Sheets show a grabber when they can be dragged away; this full-screen
    /// presentation can too, so it gets the same cue just above the toolbar.
    private var grabber: some View {
        let tokens = DesignTokens.ActivityFeed.self
        return Capsule()
            .fill(.tertiary)
            .frame(width: tokens.grabberWidth, height: tokens.grabberHeight)
            .padding(.top, max(topSafeArea - tokens.grabberHeight - tokens.grabberGap, tokens.grabberMinimumTop))
            .ignoresSafeArea(edges: .top)
            .accessibilityElement()
            .accessibilityLabel("Close Activity")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { dismiss() }
    }

    @ViewBuilder
    private var activityContent: some View {
        let content = NavigationStack {
            LogsView(usesActivityFeed: true, navigationTitle: "", workspace: workspace)
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
