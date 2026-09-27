import SwiftUI

/// The full-width main button at the bottom of a sheet (Create Group, Save
/// Changes, Remove Device). Filled with the accent, or the warning red for
/// a destructive role. While disabled it sits on the card surface with
/// secondary text rather than going black, so it still belongs to the
/// sheet in every theme.
struct SheetActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.self) private var environment

    func makeBody(configuration: Configuration) -> some View {
        let fill = fillColor(for: configuration.role)
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.sheetActionButtonHeight)
            .foregroundStyle(labelStyle(on: fill))
            .background(fill.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.shellbeeSurface), in: Capsule())
            .opacity(configuration.isPressed ? DesignTokens.Opacity.pressed : 1)
            .contentShape(Capsule())
    }

    /// `nil` while disabled, when the button sits on the card surface.
    private func fillColor(for role: ButtonRole?) -> Color? {
        guard isEnabled else { return nil }
        if role == .destructive { return environment.themedStatusColor(.red) }
        return environment.shellbeeTheme.palette?.accent ?? Color(.systemBlue)
    }

    /// White on deep fills, black on light ones (a theme's dark-mode accent
    /// is often a pale amber or mint that white text disappears on).
    private func labelStyle(on fill: Color?) -> AnyShapeStyle {
        guard let fill else { return AnyShapeStyle(.secondary) }
        let resolved = fill.resolve(in: environment)
        let luminance = 0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen + 0.0722 * resolved.linearBlue
        return AnyShapeStyle(luminance > DesignTokens.Theme.darkLabelLuminance ? Color.black : Color.white)
    }
}

extension ButtonStyle where Self == SheetActionButtonStyle {
    static var sheetAction: SheetActionButtonStyle { SheetActionButtonStyle() }
}
