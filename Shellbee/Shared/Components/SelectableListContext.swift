import SwiftUI

/// Environment flag set by the iPad 3-column shell to mark its inner
/// list as a selection-driven column. Rows read it to suppress
/// `.listRowBackground` — iPadOS 26's selection chrome overlays the
/// custom background and squashes row content into the bar's bounds.
private struct SelectableListContextKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSelectableListContext: Bool {
        get { self[SelectableListContextKey.self] }
        set { self[SelectableListContextKey.self] = newValue }
    }
}
