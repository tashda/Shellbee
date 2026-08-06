import SwiftUI

/// Shared pointer language for custom interactive surfaces. Native controls
/// such as Button, NavigationLink, Toggle, and TextField keep their system
/// pointer behavior; use this only where a plain custom surface needs the
/// equivalent affordance.
enum IPadPointerEffect: Equatable {
    case highlight
    case lift

    enum Resolved: Equatable {
        case highlight
        case lift
    }

    func resolved(reduceMotion: Bool) -> Resolved {
        if reduceMotion, self == .lift {
            return .highlight
        }
        switch self {
        case .highlight: return .highlight
        case .lift: return .lift
        }
    }
}

private struct IPadPointerEffectModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let effect: IPadPointerEffect

    @ViewBuilder
    func body(content: Content) -> some View {
        if AdaptiveLayout.isPad {
            switch effect.resolved(reduceMotion: reduceMotion) {
            case .highlight:
                content.hoverEffect(.highlight)
            case .lift:
                content.hoverEffect(.lift)
            }
        } else {
            content
        }
    }
}

extension View {
    func iPadPointerEffect(_ effect: IPadPointerEffect) -> some View {
        modifier(IPadPointerEffectModifier(effect: effect))
    }
}
