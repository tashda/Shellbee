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
                                CardTintSwatch(amount: 0)
                            } maximumValueLabel: {
                                CardTintSwatch(amount: 1)
                            }
                        }
                        Toggle("Themed Indicators", isOn: $themesStatusColors)
                    } footer: {
                        Text("Card Tint sets how strongly rows and cards take on the theme. Themed Indicators recolors status, event icons, charts and swipe actions to match it.")
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

/// Two device rows as the Devices list draws them, with the monogram of
/// each row's bridge before its vendor.
private struct BridgeIndicatorPreview: View {
    let mode: BridgeGradientMode

    var body: some View {
        VStack(spacing: .zero) {
            previewRow("Hall Motion", vendor: "Aqara", device: .fallbackPreview,
                       bridgeName: "Home", color: DesignTokens.Bridge.palette[3])
            Divider()
            previewRow("Kitchen Light", vendor: "Philips", device: .preview,
                       bridgeName: "Studio", color: DesignTokens.Bridge.palette[4])
        }
    }

    private func previewRow(_ title: String, vendor: String, device: Device,
                            bridgeName: String, color: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DeviceImageView(
                device: device,
                isAvailable: true,
                size: DesignTokens.Size.logRowDeviceImage,
                showsAvailabilityIndicator: false
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if mode != .off {
                        BridgeMonogramMark(initial: BridgeMonogram.initial(for: bridgeName), color: color,
                                           size: DesignTokens.Size.bridgeMonogramCompact)
                    }
                    Text(vendor.uppercased())
                        .font(.system(size: DesignTokens.Size.chipSymbol, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            mode == .off
                ? "\(title), no bridge indicator"
                : "\(title), \(bridgeName) bridge"
        )
    }
}

private extension BridgeGradientMode {
    var description: String {
        switch self {
        case .always: "Devices, groups and events always show their bridge's monogram."
        case .auto: "Bridge monograms appear when more than one bridge is connected."
        case .off: "Devices, groups and events aren't marked with their bridge."
        }
    }
}

#Preview {
    NavigationStack {
        AppAppearanceSettingsView()
    }
}
