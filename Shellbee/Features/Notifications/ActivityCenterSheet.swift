import SwiftUI

/// The expanded state of the tab-bar Activity Center. On iPhone it is the
/// destination of the tab accessory's system zoom transition.
struct ActivityCenterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pullDistance: CGFloat = 0
    let transitionNamespace: Namespace.ID?
    let workspace: LogsWorkspaceState

    var body: some View {
        let content = NavigationStack {
            LogsView(usesActivityFeed: true, navigationTitle: "", workspace: workspace)
        }
        .configuredTopScrollEdgeEffect()
        .offset(y: pullDistance)
        .overlay(alignment: .top) {
            TopPullHandle(pullDistance: $pullDistance)
        }
        .accessibilityAction(.escape) { dismiss() }

        if #available(iOS 18.0, *), let transitionNamespace {
            content
                .navigationTransition(.zoom(sourceID: "activity-center", in: transitionNamespace))
        } else {
            content
        }
    }
}

/// The pull-down affordance of the full-screen Activity Center.
///
/// The grabber sits in the middle of the navigation bar row, level with the
/// toolbar capsules. It is an overlay rather than a principal toolbar item,
/// so it stays at the exact centre when trailing items such as Clear
/// Filters come and go. The page follows a pull on it and closes past a
/// threshold, wherever the feed is scrolled; tapping it also closes.
private struct TopPullHandle: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pullDistance: CGFloat

    var body: some View {
        Capsule()
            .fill(.tertiary)
            .frame(
                width: DesignTokens.ActivityFeed.grabberWidth,
                height: DesignTokens.ActivityFeed.grabberHeight
            )
            .frame(
                width: DesignTokens.ActivityFeed.grabberHitWidth,
                height: DesignTokens.ActivityFeed.navigationBarHeight
            )
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
            .gesture(pullGesture)
            .offset(y: pullDistance)
            .accessibilityElement()
            .accessibilityLabel("Close Activity")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { dismiss() }
    }

    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: DesignTokens.Spacing.xs, coordinateSpace: .global)
            .onChanged { value in
                pullDistance = max(0, value.translation.height)
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                if max(value.translation.height, projected) > DesignTokens.ActivityFeed.grabberDismissDistance {
                    dismiss()
                } else {
                    withAnimation(.smooth) { pullDistance = 0 }
                }
            }
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
