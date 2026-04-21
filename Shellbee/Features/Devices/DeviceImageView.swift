import SwiftUI

struct DeviceImageView: View {
    let device: Device
    let isAvailable: Bool
    var hasUpdate: Bool = false
    var otaStatus: OTAUpdateStatus?
    var size: CGFloat = 44
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PersistentAsyncImage(url: device.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } placeholder: {
                fallbackIcon
            }
            
            if hasUpdate || otaStatus?.isActive == true {
                DeviceUpgradeBadgeView(status: otaStatus, hasUpdate: hasUpdate, size: size)
                    .offset(
                        x: DesignTokens.Size.deviceUpgradeBadgeInset,
                        y: DesignTokens.Size.deviceUpgradeBadgeInset
                    )
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: DesignTokens.Duration.standardAnimation), value: isAvailable)
    }
    
    private var fallbackIcon: some View {
        Image(systemName: device.categorySystemImage)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(isAvailable ? Color.accentColor : .secondary.opacity(DesignTokens.Opacity.overlay))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Optional: add a very subtle circle for fallbacks only 
            // to maintain visual weight parity with real images
            .background {
                if !isAvailable {
                    Circle()
                        .fill(Color.secondary.opacity(DesignTokens.Opacity.subtleFill / 2))
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            DeviceImageView(device: .preview, isAvailable: true)
            Text("Available Image")
        }
        HStack {
            DeviceImageView(
                device: .preview,
                isAvailable: true,
                hasUpdate: false,
                otaStatus: OTAUpdateStatus(deviceName: "Preview Device", phase: .updating, progress: 42, remaining: 900)
            )
            Text("Update In Progress")
        }
        HStack {
            DeviceImageView(device: .preview, isAvailable: false)
            Text("Offline Image")
        }
        HStack {
            DeviceImageView(device: .fallbackPreview, isAvailable: true)
            Text("Fallback Icon")
        }
    }
    .padding()
}

extension Device {
    static var preview: Device {
        Device(
            ieeeAddress: "0x001",
            type: .endDevice,
            networkAddress: 1,
            supported: true,
            friendlyName: "Preview Device",
            disabled: false,
            definition: DeviceDefinition(
                model: "LCA001",
                vendor: "Philips",
                description: "Hue bulb",
                supportsOTA: true,
                exposes: [],
                options: nil,
                icon: nil
            ),
            powerSource: "mains",
            interviewCompleted: true,
            interviewing: false
        )
    }

    static var fallbackPreview: Device {
        Device(
            ieeeAddress: "0x002",
            type: .endDevice,
            networkAddress: 2,
            supported: true,
            friendlyName: "Other Device",
            disabled: false,
            definition: nil, // Triggers fallback
            powerSource: "battery",
            interviewCompleted: true,
            interviewing: false
        )
    }
}
