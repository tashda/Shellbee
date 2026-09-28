import SwiftUI

struct HomeThemePickerView: View {
    @AppStorage(ShellbeeTheme.storageKey) private var themeRawValue = ShellbeeTheme.defaultTheme.rawValue

    private var selected: ShellbeeTheme { ShellbeeTheme.stored(themeRawValue) }

    var body: some View {
        List {
            SwiftUI.Group {
                ForEach(ShellbeeTheme.allCases, id: \.self) { theme in
                    Section {
                        Button {
                            withAnimation { themeRawValue = theme.rawValue }
                        } label: {
                            row(for: theme)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(theme.displayName). \(theme.summary)")
                        .accessibilityAddTraits(theme == selected ? .isSelected : [])
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .listSectionSpacing(.compact)
        .shellbeeThemedCanvas()
        .navigationTitle("Color Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for theme: ShellbeeTheme) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ShellbeeThemePreview(theme: theme)
            HStack(spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(theme.displayName)
                        .font(.headline)
                    Text(theme.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DesignTokens.Spacing.sm)
                if theme == selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
