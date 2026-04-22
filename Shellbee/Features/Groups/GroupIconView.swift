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
                DeviceImageView(device: memberDevices[0], isAvailable: true, size: size * 0.72)
                DeviceImageView(device: memberDevices[1], isAvailable: true, size: size * 0.72)
                    .offset(x: size * 0.28, y: size * 0.28)
            }
            .frame(width: size, height: size, alignment: .topLeading)
        }
    }

    private var genericIcon: some View {
        Image(systemName: "square.on.square.fill")
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.fill.secondary, in: RoundedRectangle(cornerRadius: size * 0.28))
    }
}
