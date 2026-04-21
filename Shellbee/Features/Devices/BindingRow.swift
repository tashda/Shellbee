import SwiftUI

struct BindingRow: View {
    let binding: ParsedBinding
    let store: AppStore

    private var targetDevice: Device? {
        guard let ieee = binding.targetIEEE else { return nil }
        return store.devices.first { $0.ieeeAddress == ieee }
    }

    private var targetName: String {
        if binding.targetType == "group" {
            return store.groups.first { $0.id == binding.groupId }?.friendlyName
                ?? "Group \(binding.groupId ?? 0)"
        }
        if let device = targetDevice { return device.friendlyName }
        if let ieee = binding.targetIEEE { return ieee }
        return "Coordinator"
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            leadingIcon
            VStack(alignment: .leading, spacing: 0) {
                Text(targetName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary).lineLimit(1)
                Text(binding.cluster)
                    .font(.caption).foregroundStyle(.secondary).monospaced()
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if binding.targetType == "group" {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.summaryRowSymbolBackground)
                    .fill(Color.blue.opacity(DesignTokens.Opacity.chipFill))
                    .frame(width: DesignTokens.Size.summaryRowSymbolFrame,
                           height: DesignTokens.Size.summaryRowSymbolFrame)
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: DesignTokens.Size.chipSymbol + 2, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        } else if let device = targetDevice {
            DeviceImageView(
                device: device,
                isAvailable: store.isAvailable(device.friendlyName),
                size: DesignTokens.Size.summaryRowSymbolFrame
            )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.summaryRowSymbolBackground)
                    .fill(Color.purple.opacity(DesignTokens.Opacity.chipFill))
                    .frame(width: DesignTokens.Size.summaryRowSymbolFrame,
                           height: DesignTokens.Size.summaryRowSymbolFrame)
                Image(systemName: "network")
                    .font(.system(size: DesignTokens.Size.chipSymbol + 4, weight: .semibold))
                    .foregroundStyle(.purple)
            }
        }
    }
}
