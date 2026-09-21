import SwiftUI

struct AppAppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

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

            Section {
                NavigationLink { BridgeIndicatorSettingsView() } label: {
                    Label("Bridge Indicators", systemImage: "line.3.horizontal")
                }
            } header: {
                Text("Content")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BridgeIndicatorSettingsView: View {
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Show Indicators", selection: $indicatorModeRaw) {
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
        .navigationTitle("Bridge Indicators")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var indicatorMode: BridgeGradientMode {
        BridgeGradientMode(rawValue: indicatorModeRaw) ?? BridgeGradientMode.default
    }
}

private struct BridgeIndicatorPreview: View {
    let mode: BridgeGradientMode

    var body: some View {
        VStack {
            previewRow("Hall Motion", symbol: "figure.walk", color: .blue)
            Divider()
            previewRow("Kitchen Light", symbol: "lightbulb.fill", color: .orange)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous))
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func previewRow(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if mode != .off {
                Rectangle()
                    .fill(color)
                    .frame(width: DesignTokens.Size.levelIndicatorWidth)
            }
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(mode == .off ? "No indicator" : "Bridge")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.trailing, DesignTokens.Spacing.md)
    }
}

#Preview {
    NavigationStack {
        AppAppearanceSettingsView()
    }
}
