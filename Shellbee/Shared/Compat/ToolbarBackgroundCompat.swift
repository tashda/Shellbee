import SwiftUI

extension View {
    /// iOS 26 introduced `scrollEdgeEffectStyle(_:for:)` with an `.auto` default
    /// that picked `.soft` (fade & blur) for the top edge. The iOS 27 SDK
    /// changed what `.auto` resolves to there, defaulting to `.hard` (flat,
    /// opaque) instead — a look Shellbee's toolbars were never designed for.
    /// This is the shipped behavior in both official releases, not a beta
    /// quirk, so this forces the old `.soft` background back for the top
    /// scroll edge only; bottom edges (tab bars) are left on the system
    /// default.
    @ViewBuilder
    func forceSoftTopScrollEdgeEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}
