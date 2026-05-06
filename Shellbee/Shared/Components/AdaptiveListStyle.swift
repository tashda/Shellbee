import SwiftUI

/// Picks `.insetGrouped` vs `.plain` at runtime. SwiftUI's `listStyle`
/// modifier types each style separately, so a ternary expression won't
/// type-check — this `ViewModifier` does the conditional apply for us.
///
/// `useGrouped == true` is the iPhone / iPad-2-column default. `false`
/// is for the iPad 3-column content column where `.insetGrouped`'s
/// rounded card sections fight with iPadOS 26's selection chrome.
struct AdaptiveListStyle: ViewModifier {
    let useGrouped: Bool

    func body(content: Content) -> some View {
        if useGrouped {
            content.listStyle(.insetGrouped)
        } else {
            content.listStyle(.plain)
        }
    }
}
