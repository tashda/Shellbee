import SwiftUI

struct DevicePickerRow: View {
    let device: Device
    /// Phase 1 multi-bridge: availability passed in by the caller (which
    /// knows the device's bridge). When omitted the row renders as available
    /// — presentational fallback for previews and any caller without scope.
    var isAvailable: Bool = true

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DeviceImageView(
                device: device,
                isAvailable: isAvailable,
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
