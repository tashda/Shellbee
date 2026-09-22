import SwiftUI

/// The expanded state of the tab-bar Activity Center. On iPhone it is the
/// destination of the tab accessory's system zoom transition.
struct ActivityCenterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transitionNamespace: Namespace.ID?
    let workspace: LogsWorkspaceState

    var body: some View {
        if #available(iOS 18.0, *), let transitionNamespace {
            // The zoom transition's own pull-down closes it, so no grabber:
            // a strip above the navigation bar can't share its scroll-edge
            // blur and would show as a flat band over scrolled content.
            navigation
                .accessibilityAction(.escape) { dismiss() }
                .navigationTransition(.zoom(sourceID: "activity-center", in: transitionNamespace))
        } else {
            // A plain full-screen cover can't be pulled down, so it keeps a
            // grabber strip of its own above the toolbar.
            VStack(spacing: 0) {
                GrabberCapsule()
                navigation
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    private var navigation: some View {
        NavigationStack {
            LogsView(usesActivityFeed: true, navigationTitle: "", workspace: workspace)
        }
        .configuredTopScrollEdgeEffect()
    }
}

/// The full-screen Activity Center's pull-down affordance, fixed at the
/// visual centre, for covers without a zoom transition. Dragging it down or
/// tapping it closes the Activity Center.
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
