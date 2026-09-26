import SwiftUI
import UIKit

@MainActor
enum AdaptiveLayout {
    enum WindowClass: Equatable {
        case compact
        case standard
        case expansive
    }

    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Classifies the space offered by the current scene. This deliberately
    /// ignores device orientation and model: Stage Manager and external
    /// displays can produce landscape-shaped narrow windows or very wide
    /// portrait scenes.
    static func windowClass(in size: CGSize) -> WindowClass {
        if size.width < DesignTokens.Size.iPadStandardWindowMinimumWidth {
            return .compact
        }
        if size.width < DesignTokens.Size.iPadThreeColumnMinimumWidth {
            return .standard
        }
        return .expansive
    }

    static func usesWideIPadLayout(in size: CGSize) -> Bool {
        isPad && windowClass(in: size) == .expansive
    }
}

private struct IPadReadableWidthModifier: ViewModifier {
    let maxWidth: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if AdaptiveLayout.isPad {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    func iPadReadableWidth(
        maxWidth: CGFloat = DesignTokens.Size.readableContentMaxWidth
    ) -> some View {
        modifier(IPadReadableWidthModifier(maxWidth: maxWidth))
    }
}
