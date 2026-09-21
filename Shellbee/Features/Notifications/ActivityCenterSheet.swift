import SwiftUI

/// The expanded state of the tab-bar Activity Center. A native sheet gives
/// it the direct, interactive collapse gesture users expect from a system
/// player without reimplementing a custom presentation controller.
struct ActivityCenterSheet: View {
    var body: some View {
        NavigationStack {
            LogsView(navigationTitle: "")
        }
        .configuredTopScrollEdgeEffect()
    }
}

/// Presents the same Activity Center on every app form factor. When it is
/// disabled, neither a direct notification action nor stale scene state can
/// surface an in-app event UI.
struct ActivityCenterSheetPresentation: ViewModifier {
    @Environment(\.sceneNavigation) private var sceneNavigation
    @AppStorage(ActivityCenterSettings.isEnabledStorageKey) private var isEnabled = true

    func body(content: Content) -> some View {
        if isEnabled {
            content.sheet(isPresented: Binding(
                get: { sceneNavigation.isActivityCenterPresented },
                set: { sceneNavigation.isActivityCenterPresented = $0 }
            )) {
                ActivityCenterSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        } else {
            content
        }
    }
}
