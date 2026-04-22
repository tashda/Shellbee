import SwiftUI

struct MemberAvatarStack: View {
    let devices: [Device]
    let size: CGFloat
    var maxVisible: Int = 5

    private var overlap: CGFloat { size / 3 }
    private var borderWidth: CGFloat { max(1.5, size * 0.063) }
    private var placeholderFont: CGFloat { size * 0.375 }
    private var badgeSize: CGFloat { size + 2 }
    private var badgeFont: CGFloat { max(9, size * 0.44) }
    private var badgePadding: CGFloat { size * 0.25 }

    var body: some View {
        HStack(spacing: -overlap) {
            let shown = Array(devices.prefix(maxVisible))
            let overflow = devices.count - shown.count
            ForEach(Array(shown.enumerated()), id: \.element.ieeeAddress) { index, device in
                avatarCircle(for: device)
                    .zIndex(Double(shown.count - index))
            }
            if overflow > 0 {
                overflowBadge(overflow)
                    .padding(.leading, badgePadding)
                    .zIndex(0)
            }
        }
    }

    private func avatarCircle(for device: Device) -> some View {
        DeviceImageView(device: device, isAvailable: true, size: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.background, lineWidth: borderWidth))
    }

    private func overflowBadge(_ count: Int) -> some View {
        Text("+\(count)")
            .font(.system(size: badgeFont, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: badgeSize, height: badgeSize)
            .background(Color(.systemGray5), in: Circle())
            .overlay(Circle().strokeBorder(.background, lineWidth: borderWidth))
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        MemberAvatarStack(devices: [.preview, .fallbackPreview, .preview], size: 24)
        MemberAvatarStack(devices: [.preview, .fallbackPreview, .preview, .preview], size: 40, maxVisible: 3)
    }
    .padding()
}
