import SwiftUI

struct AppAppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(ShellbeeTheme.storageKey) private var themeRawValue = ShellbeeTheme.defaultTheme.rawValue
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                Picker("Color theme", selection: $themeRawValue) {
                    ForEach(ShellbeeTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
                .tint(.secondary)
            } header: {
                Text("Theme")
            } footer: {
                Text("Color themes currently change the Home background and accent.")
            }

            Section("Home") {
                NavigationLink { HomeSettingsView() } label: {
                    SettingsNavigationLabel(
                        title: "Home",
                        systemImage: "house.fill",
                        color: .blue
                    )
                }
            }

            Section {
                Picker("Show", selection: $indicatorModeRaw) {
                    ForEach(BridgeGradientMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                BridgeIndicatorPreview(mode: indicatorMode)
            } header: {
                Text("Bridge Indicators")
            } footer: {
                Text(indicatorMode.description)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

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
