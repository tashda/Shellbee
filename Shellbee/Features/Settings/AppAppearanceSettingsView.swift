import SwiftUI

struct AppAppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearanceMode) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
            } header: {
                Text("Theme")
            }

            Section("Home") {
                NavigationLink { HomeCardsSettingsView() } label: {
                    SettingsNavigationLabel(
                        title: "Home Cards",
                        systemImage: "rectangle.3.group.fill",
                        color: .blue
                    )
                }
            }

            Section("Bridge Indicators") {
                Picker("Show", selection: $indicatorModeRaw) {
                    ForEach(BridgeGradientMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
            }

            Section("Preview") {
                BridgeIndicatorPreview(mode: indicatorMode)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(mode.description)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: .zero) {
                previewRow("Hall Motion", symbol: "figure.walk", bridgeName: "Home", color: .blue)
                Divider()
                previewRow("Kitchen Light", symbol: "lightbulb.fill", bridgeName: "Studio", color: .orange)
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous))
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func previewRow(
        _ title: String,
        symbol: String,
        bridgeName: String,
        color: Color
    ) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if mode != .off {
                Rectangle()
                    .fill(color)
                    .frame(width: DesignTokens.Size.levelIndicatorWidth)
            } else {
                Color.clear
                    .frame(width: DesignTokens.Size.levelIndicatorWidth)
            }
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(mode == .off ? "Hidden" : bridgeName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.trailing, DesignTokens.Spacing.md)
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
