import SwiftUI

/// Horizontally scrolling filter bubbles above the results. A bubble only
/// appears when its category has matches, so the bar never offers a filter
/// that would show an empty list. The selected bubble always stays visible.
struct GlobalSearchScopeBar: View {
    @Binding var selection: GlobalSearchScope
    let results: GlobalSearchResults

    private var visibleScopes: [GlobalSearchScope] {
        GlobalSearchScope.allCases.filter { scope in
            scope == .all || scope == selection || results.count(for: scope) > 0
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            bubbles
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .animation(.snappy, value: visibleScopes)
    }

    /// Shares one glass layer across bubbles on iOS 26 so they render and
    /// morph together as the visible set changes.
    @ViewBuilder
    private var bubbles: some View {
        let row = HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(visibleScopes) { scope in
                bubble(for: scope)
            }
        }
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: DesignTokens.Spacing.sm) { row }
        } else {
            row
        }
    }

    private func bubble(for scope: GlobalSearchScope) -> some View {
        let isSelected = selection == scope
        let count = results.count(for: scope)
        return Button {
            selection = scope
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: scope.systemImage)
                    .imageScale(.small)
                Text(scope.title)
                Text(count, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(DesignTokens.Opacity.secondaryText)) : AnyShapeStyle(.secondary))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .modifier(GlobalSearchBubbleBackground(isSelected: isSelected))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(scope.title), \(count) results")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Liquid Glass capsule for a filter bubble; the selected bubble takes the
/// accent tint. Falls back to material and a filled accent capsule before
/// iOS 26.
private struct GlobalSearchBubbleBackground: ViewModifier {
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                in: Capsule()
            )
        } else if isSelected {
            content.background(Capsule().fill(Color.accentColor))
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
