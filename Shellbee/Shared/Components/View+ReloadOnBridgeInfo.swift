import SwiftUI

extension View {
    /// Runs `load` when the view first appears AND again whenever `value`
    /// changes — so settings views hydrate correctly even if the underlying
    /// bridge info arrives after the view has mounted (e.g. on auto-reconnect).
    /// Skips the reload while the user has unsaved edits.
    func reloadOnBridgeInfo<V: Equatable>(
        info value: V,
        hasChanges: Bool,
        load: @escaping () -> Void
    ) -> some View {
        self
            .task { load() }
            .onChange(of: value) { _, _ in
                if !hasChanges { load() }
            }
    }
}
