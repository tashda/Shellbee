import SwiftUI

/// Lays content out at the width it would have at full size, then draws it
/// scaled down to fit the available width, taking only the scaled height.
/// For showing a real card as a thumbnail. Not interactive.
struct ScaledPreview<Content: View>: View {
    let scale: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0

    var body: some View {
        Color.clear
            .frame(height: height * scale)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay(alignment: .topLeading) {
                if width > 0 {
                    content()
                        .frame(width: width / scale)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                        .scaleEffect(scale, anchor: .topLeading)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
