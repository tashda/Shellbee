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
        // The grabber gets its own strip above the navigation bar so the
        // toolbar capsules can never cover it.
        .safeAreaInset(edge: .top, spacing: 0) {
            GrabberCapsule()
        }

        if #available(iOS 18.0, *), let transitionNamespace {
            content
                .navigationTransition(.zoom(sourceID: "activity-center", in: transitionNamespace))
        } else {
            content
        }
    }
}

/// The full-screen Activity Center's pull-down affordance, fixed at the
/// visual centre. Dragging it down closes the Activity Center even while
/// the feed is scrolled, and tapping it does the same.
private struct GrabberCapsule: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Capsule()
            .fill(.tertiary)
            .frame(
                width: DesignTokens.ActivityFeed.grabberWidth,
                height: DesignTokens.ActivityFeed.grabberHeight
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .contentShape(Rectangle())
            .background(Color(.systemGroupedBackground))
            .onTapGesture { dismiss() }
            .gesture(DragGesture(minimumDistance: DesignTokens.Spacing.xs).onEnded { value in
                if value.translation.height > DesignTokens.ActivityFeed.grabberDismissDistance {
                    dismiss()
                }
            })
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
