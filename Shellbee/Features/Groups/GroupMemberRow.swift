import SwiftUI

struct GroupMemberRow: View {
    let member: GroupMember
    let device: Device?
    let state: [String: JSONValue]
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let device {
                DeviceImageView(
                    device: device,
                    isAvailable: isAvailable,
                    size: DesignTokens.Size.summaryRowSymbolFrame
                )
            } else {
                unknownDeviceIcon
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(device?.friendlyName ?? member.ieeeAddress)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(device != nil ? .primary : .secondary)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if device == nil {
                        StatusChip(title: "Unknown", symbol: "questionmark.circle", tint: .orange)
                    }
                    StatusChip(title: "EP \(member.endpoint)", tint: .secondary)
                    if device != nil && !isAvailable {
                        StatusChip(title: "Offline", symbol: "xmark.circle.fill", tint: .red)
                    }
                }
                .padding(.top, DesignTokens.Spacing.xs)
            }

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var unknownDeviceIcon: some View {
        Image(systemName: "questionmark.square")
            .font(.system(size: DesignTokens.Size.summaryRowSymbol, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: DesignTokens.Size.summaryRowSymbolFrame, height: DesignTokens.Size.summaryRowSymbolFrame)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.summaryRowSymbolBackground))
    }
}

#Preview {
    List {
        GroupMemberRow(
            member: GroupMember(ieeeAddress: "0x00158d0004512345", endpoint: 1),
            device: .preview,
            state: [:],
            isAvailable: true
        )
        GroupMemberRow(
            member: GroupMember(ieeeAddress: "0x00158d0004599999", endpoint: 1),
            device: nil,
            state: [:],
            isAvailable: false
        )
    }
    .listStyle(.insetGrouped)
}
