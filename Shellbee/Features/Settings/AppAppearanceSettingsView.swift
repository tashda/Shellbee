import SwiftUI

struct AppAppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(ShellbeeTheme.storageKey) private var themeRawValue = ShellbeeTheme.defaultTheme.rawValue
    @AppStorage(StatusTone.themedStorageKey) private var themesStatusColors = false
    @AppStorage(ShellbeeTheme.surfaceTintKey) private var surfaceTint = ShellbeeTheme.defaultSurfaceTint
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        Form {
            SwiftUI.Group {
                Section {
                    ShellbeeThemePreview(theme: theme)
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.md,
                                                  leading: DesignTokens.Spacing.lg,
                                                  bottom: DesignTokens.Spacing.md,
                                                  trailing: DesignTokens.Spacing.lg))
                    NavigationLink {
                        HomeThemePickerView()
                    } label: {
                        LabeledContent("Color Theme") {
                            Text(theme.displayName)
                        }
                    }
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag(AppearanceMode.system)
                        Text("Light").tag(AppearanceMode.light)
                        Text("Dark").tag(AppearanceMode.dark)
                    }
                    .tint(.secondary)
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Themes tint the background, rows, cards and controls of every screen.")
                }

                if theme != .system {
                    Section {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Card Tint")
                            Slider(value: $surfaceTint, in: 0...1) {
                                Text("Card Tint")
                            } minimumValueLabel: {
                                Image(systemName: "square")
                                    .foregroundStyle(.secondary)
                            } maximumValueLabel: {
                                Image(systemName: "square.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Toggle("Themed Status Colors", isOn: $themesStatusColors)
                    } footer: {
                        Text("Card Tint sets how strongly rows and cards take on the theme. Themed Status Colors recolors link quality, battery, offline and warning states to match it.")
                    }
                }

                Section("Layout") {
                    NavigationLink("Home Screen") { HomeSettingsView() }
                }

                Section {
                    Picker("Show", selection: $indicatorModeRaw) {
                        ForEach(BridgeGradientMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .tint(.secondary)
                    BridgeIndicatorPreview(mode: indicatorMode)
                } header: {
                    Text("Bridge Indicators")
                } footer: {
                    Text(indicatorMode.description)
                }
            }
            .shellbeeThemedRows()
        }
        .shellbeeThemedCanvas()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var theme: ShellbeeTheme { ShellbeeTheme.stored(themeRawValue) }

    private var indicatorMode: BridgeGradientMode {
        BridgeGradientMode(rawValue: indicatorModeRaw) ?? BridgeGradientMode.default
    }
}

private struct BridgeIndicatorPreview: View {
    let mode: BridgeGradientMode

    var body: some View {
        VStack(spacing: .zero) {
            previewRow(
                "Hall Motion",
                device: .fallbackPreview,
                bridgeName: "Home",
                color: .blue
            )
            Divider()
            previewRow(
                "Kitchen Light",
                device: .preview,
                bridgeName: "Studio",
                color: .orange
            )
        }
    }

    private func previewRow(
        _ title: String,
        device: Device,
        bridgeName: String,
        color: Color
    ) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DeviceImageView(
                device: device,
                isAvailable: true,
                size: DesignTokens.Size.logRowDeviceImage,
                showsAvailabilityIndicator: false
            )
            Text(title)
                .lineLimit(1)
            Spacer()
            Text(bridgeName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .overlay(alignment: .leading) {
            if mode != .off {
                Rectangle()
                    .fill(color)
                    .frame(width: DesignTokens.Size.levelIndicatorWidth)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            mode == .off
                ? "\(title), no bridge indicator"
                : "\(title), \(bridgeName) bridge indicator"
        )
    }
}

private extension BridgeGradientMode {
    var description: String {
        switch self {
        case .always: "Each row shows its source bridge."
        case .auto: "Source bridges appear when more than one bridge is connected."
        case .off: "Rows stay free of bridge source indicators."
        }
    }
}

#Preview {
    NavigationStack {
        AppAppearanceSettingsView()
    }
}
