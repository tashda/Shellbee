import SwiftUI

struct GroupIconView: View {
    let memberDevices: [Device]
    let size: CGFloat

    var body: some View {
        if memberDevices.isEmpty {
            genericIcon
        } else if memberDevices.count == 1 {
            DeviceImageView(device: memberDevices[0], isAvailable: true, size: size)
                .frame(width: size, height: size)
        } else {
            ZStack(alignment: .topLeading) {
                DeviceImageView(device: memberDevices[0], isAvailable: true, size: size * DesignTokens.Ratio.groupIconMember)
                DeviceImageView(device: memberDevices[1], isAvailable: true, size: size * DesignTokens.Ratio.groupIconMember)
                    .offset(x: size * DesignTokens.Ratio.groupIconOffset,
                            y: size * DesignTokens.Ratio.groupIconOffset)
            }
            .frame(width: size, height: size, alignment: .topLeading)
        }
    }

    private var genericIcon: some View {
        Image(systemName: "square.on.square.fill")
            .font(.system(size: size * DesignTokens.Typography.iconRatioHalf, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.fill.secondary,
                        in: RoundedRectangle(cornerRadius: size * DesignTokens.Ratio.groupIconCorner))
    }
}
