import SwiftUI

/// A tappable filter chip in Liquid Glass (All, Lights, Replace now). The
/// selected chip takes the accent tint. Place several in a `GlassChipRow`
/// so they share one glass layer. Search's scope bubbles use it too.
struct SelectableFilterChip: View {
    let title: String
    let isSelected: Bool
    var systemImage: ShellbeeSymbol? = nil
    /// Shown after the title in secondary text, such as a result count.
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let systemImage {
                    systemImage.image.imageScale(.small)
                }
                Text(title)
                if let count {
                    Text(count, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(isSelected
                            ? AnyShapeStyle(.white.opacity(DesignTokens.Opacity.secondaryText))
                            : AnyShapeStyle(.secondary))
                }
            }
            .glassChipLabel(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Horizontally scrolling row of glass chips. Shares one glass layer across
/// the chips on iOS 26 so they render and morph together.
struct GlassChipRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal) {
            chips.padding(.vertical, DesignTokens.Spacing.sm)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var chips: some View {
        let row = HStack(spacing: DesignTokens.Spacing.sm, content: content)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: DesignTokens.Spacing.sm) { row }
        } else {
            row
        }
    }
}

extension View {
    /// The type, padding and glass capsule every filter chip shares.
    func glassChipLabel(isSelected: Bool = false) -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .modifier(GlassChipBackground(isSelected: isSelected))
            .contentShape(Capsule())
    }
}

/// Liquid Glass capsule; the selected chip takes the accent tint. Falls
/// back to material and a filled accent capsule before iOS 26.
private struct GlassChipBackground: ViewModifier {
    let isSelected: Bool

    @Environment(\.shellbeeTheme) private var theme

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                isSelected ? .regular.tint(theme.accent).interactive() : .regular.interactive(),
                in: Capsule()
            )
        } else if isSelected {
            content.background(Capsule().fill(.tint))
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
