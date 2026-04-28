import SwiftUI

struct DeviceUpgradeBadgeView: View {
    let status: OTAUpdateStatus?
    let hasUpdate: Bool
    let size: CGFloat

    var body: some View {
        if let status, status.isActive {
            activeProgressBadge(for: status)
        } else if hasUpdate {
            availableBadge
        }
    }

    private var availableBadge: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: DesignTokens.Gradient.updateAvailable,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Image(systemName: "arrow.down")
                .font(.system(size: size * DesignTokens.Size.deviceUpgradeIconScale, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: size * DesignTokens.Size.deviceUpgradeBadgeScale, height: size * DesignTokens.Size.deviceUpgradeBadgeScale)
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
            radius: DesignTokens.Shadow.badgeRadius,
            x: 0,
            y: DesignTokens.Shadow.badgeY
        )
    }

    @ViewBuilder
    private func activeProgressBadge(for status: OTAUpdateStatus) -> some View {
        let badgeSize = size * (DesignTokens.Size.deviceUpgradeBadgeScale * 1.25)
        
        ZStack {
            // Floating Base
            Circle()
                .fill(.background)
                .shadow(
                    color: .black.opacity(DesignTokens.Shadow.floatingOpacity),
                    radius: DesignTokens.Shadow.floatingRadius,
                    x: 0,
                    y: DesignTokens.Shadow.floatingY
                )
            
            // Progress Track
            Circle()
                .stroke(.blue.opacity(DesignTokens.Opacity.subtleFill), lineWidth: DesignTokens.Size.badgeStroke * 3)
                .padding(DesignTokens.Size.badgeStroke * 2)

            if let progress = status.progress, status.phase == .updating {
                // Determinate Gradient Ring
                Circle()
                    .trim(from: 0, to: CGFloat(progress / 100.0))
                    .stroke(
                        AngularGradient(
                            colors: DesignTokens.Gradient.progress,
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: DesignTokens.Size.badgeStroke * 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(DesignTokens.Size.badgeStroke * 2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
            } else if status.phase == .scheduled {
                // Static ring — scheduled is parked, waiting for the device
                // to wake. No animation conveys "queued, idle".
                Circle()
                    .stroke(
                        Color.blue.opacity(DesignTokens.Opacity.subtleFill * 2),
                        style: StrokeStyle(lineWidth: DesignTokens.Size.badgeStroke * 3, lineCap: .round)
                    )
                    .padding(DesignTokens.Size.badgeStroke * 2)
            } else {
                // Indeterminate Animated Ring
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: DesignTokens.Size.badgeStroke * 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(DesignTokens.Size.badgeStroke * 2)
                    .phaseAnimator([0, 360]) { content, phase in
                        content.rotationEffect(.degrees(phase))
                    } animation: { _ in
                        .linear(duration: 1.0).repeatForever(autoreverses: false)
                    }
            }

            // Center Icon
            Image(systemName: iconName(for: status.phase))
                .font(.system(size: size * (DesignTokens.Size.deviceUpgradeIconScale * 1.1), weight: .black))
                .foregroundStyle(.blue)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: badgeSize, height: badgeSize)
        .transition(.scale.combined(with: .opacity))
    }

    private func iconName(for phase: OTAUpdateStatus.Phase) -> String {
        switch phase {
        case .updating: return "arrow.down"
        case .checking: return "magnifyingglass"
        case .scheduled: return "clock.badge"
        default: return "arrow.trianglehead.2.clockwise"
        }
    }
}

#Preview {
    HStack(spacing: DesignTokens.Spacing.lg) {
        DeviceUpgradeBadgeView(status: nil, hasUpdate: true, size: 60)
        DeviceUpgradeBadgeView(
            status: OTAUpdateStatus(deviceName: "Lamp", phase: .requested, progress: nil, remaining: nil),
            hasUpdate: false,
            size: 60
        )
        DeviceUpgradeBadgeView(
            status: OTAUpdateStatus(deviceName: "Lamp", phase: .updating, progress: 75, remaining: 1200),
            hasUpdate: false,
            size: 60
        )
    }
    .padding()
    .background(Color.secondary.opacity(DesignTokens.Opacity.chipFill))
}
