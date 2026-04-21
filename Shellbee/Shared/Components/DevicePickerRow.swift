import SwiftUI

struct DevicePickerRow: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DeviceImageView(
                device: device,
                isAvailable: environment.store.isAvailable(device.friendlyName),
                size: DesignTokens.Size.summaryRowSymbolFrame
            )
            VStack(alignment: .leading, spacing: 0) {
                if let vendor = device.definition?.vendor {
                    Text(vendor.uppercased())
                        .font(.system(size: DesignTokens.Size.chipSymbol, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(DesignTokens.Opacity.secondaryText))
                        .lineLimit(1)
                }
                Text(device.friendlyName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

#Preview {
    List {
        DevicePickerRow(device: .preview)
    }
    .environment(AppEnvironment())
}
