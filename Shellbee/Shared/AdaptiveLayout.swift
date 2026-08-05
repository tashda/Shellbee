import SwiftUI
import UIKit

@MainActor
enum AdaptiveLayout {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static func usesWideIPadLayout(in size: CGSize) -> Bool {
        isPad
            && size.width > size.height
            && size.width >= DesignTokens.Size.iPadLandscapeMinimumWidth
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
