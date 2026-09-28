import SwiftUI

/// One device in `DevicePickerSheet`: identity, bridge, a filled check when
/// selected, and an inline endpoint picker for multi-endpoint devices.
struct DevicePickerRow: View {
    let item: DevicePickerItem
    let isSelected: Bool
    let showsEndpoints: Bool
    let endpoint: Int
    let onToggle: () -> Void
    let onEndpointChange: (Int) -> Void

    @Environment(AppEnvironment.self) private var environment

    private var endpoints: [Int] { item.device.availableEndpoints }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Button(action: onToggle) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    IdentityRow(
                        name: item.device.friendlyName,
                        subtitle: item.device.cardSubtitle,
                        bridgeID: item.bridgeID,
                        bridgeName: environment.attributionBridgeName(for: item.bridgeID),
                        isListRow: true
                    ) {
                        DeviceImageView(
                            device: item.device,
                            isAvailable: item.isAvailable,
                            size: DesignTokens.Size.summaryRowSymbolFrame
                        )
                    }
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: DesignTokens.Size.summaryRowTrailingIcon, weight: .medium))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .symbolEffect(.bounce, value: isSelected)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if isSelected && showsEndpoints && endpoints.count > 1 {
                Picker("Endpoint", selection: Binding(get: { endpoint }, set: onEndpointChange)) {
                    ForEach(endpoints, id: \.self) { Text("Endpoint \($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
