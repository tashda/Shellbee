import SwiftUI

/// Conditionally applies `BridgeRowLeadingBar` as the row's background.
/// `listRowBackground` modifier types itself per call site, so a ternary
/// won't type-check — this `ViewModifier` does the conditional apply.
///
/// Disabled in iPad 3-column mode because iPadOS 26's selection chrome
/// overlays a custom listRowBackground and squashes row content.
struct BridgeRowLeadingBarBackground: ViewModifier {
    let bridgeID: UUID?
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))
        } else {
            content
        }
    }
}
