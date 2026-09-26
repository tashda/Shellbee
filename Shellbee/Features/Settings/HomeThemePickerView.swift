import SwiftUI

struct HomeThemePickerView: View {
    @AppStorage(ShellbeeTheme.storageKey) private var themeRawValue = ShellbeeTheme.defaultTheme.rawValue

    var body: some View {
        List {
            ForEach(ShellbeeTheme.allCases, id: \.self) { theme in
                Button {
                    themeRawValue = theme.rawValue
                } label: {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        swatch(for: theme)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            Text(theme.displayName)
                                .foregroundStyle(.primary)
                            Text(theme.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: DesignTokens.Spacing.sm)
                        if theme == ShellbeeTheme.stored(themeRawValue) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.displayName), \(theme.summary)")
                .accessibilityValue(theme == ShellbeeTheme.stored(themeRawValue) ? "Selected" : "")
            }
        }
        .navigationTitle("Color theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func swatch(for theme: ShellbeeTheme) -> some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
            .fill(LinearGradient(
                colors: theme.swatchColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: DesignTokens.HomeTheme.swatchWidth,
                   height: DesignTokens.HomeTheme.swatchHeight)
            .accessibilityHidden(true)
    }
}
