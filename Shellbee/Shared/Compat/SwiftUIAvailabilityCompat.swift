import SwiftUI

extension View {
    /// Keeps navigation-bar content in place while a searchable toolbar is
    /// presented. Without this on iOS 26+, a large navigation title can be
    /// re-laid out to the leading edge while the search field expands.
    @ViewBuilder
    func avoidHidingSearchToolbarContentIfAvailable() -> some View {
        if #available(iOS 17.1, *) {
            self.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            self
        }
    }

    @ViewBuilder
    func minimizeSearchToolbarIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }

    @ViewBuilder
    func glassEffectIfAvailable<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
    }

    @ViewBuilder
    func glassProminentButtonStyleIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func glassButtonStyleIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// `.symbolEffect(.bounce)` (no value) needs iOS 18 because BounceSymbolEffect
    /// only conforms to IndefiniteSymbolEffect there. iOS 17 has no equivalent
    /// without an external `value:` trigger, so the effect is dropped on 17.
    @ViewBuilder
    func bounceSymbolEffectIfAvailable() -> some View {
        if #available(iOS 18.0, *) {
            self.bounceSymbolEffectIndefinite()
        } else {
            self
        }
    }

    @available(iOS 18.0, *)
    fileprivate func bounceSymbolEffectIndefinite() -> some View {
        self.symbolEffect(.bounce)
    }
}

/// Separates adjacent trailing toolbar items into their own glass capsules.
/// Without it, iOS 26+ fuses every trailing item into a single pill.
struct TrailingToolbarGroupSpacer: ToolbarContent {
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
    }
}

/// The sheet's confirming action. iOS 26+ draws it as the system's
/// prominent checkmark; earlier versions show the title as a bold button.
struct ConfirmToolbarButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(title, systemImage: "checkmark", role: .confirm, action: action)
        } else {
            Button(title, action: action)
                .fontWeight(.semibold)
        }
    }
}
