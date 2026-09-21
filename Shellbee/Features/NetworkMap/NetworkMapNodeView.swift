import SwiftUI

/// One device on the Network Map: a glass bubble lightly tinted by the
/// device's health, with its name underneath.
///
/// The glass is drawn with static gradients rather than `.glassEffect` or a
/// material. Live glass samples and blurs whatever is behind it every frame,
/// which is unaffordable for a hundred-plus bubbles moving under a pan
/// gesture, and it can't render at all inside a flattened layer. Gradients
/// give the same rim, highlight and tint and cost nothing to move.
struct NetworkMapNodeView: View {
    let node: NetworkMapLayout.Node
    let device: Device
    let isOnline: Bool
    let hasWeakLink: Bool
    let hasUpdate: Bool
    let otaStatus: OTAUpdateStatus?
    let showsLabel: Bool
    let isDimmed: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var size: CGFloat { NetworkMapLayoutEngine.nodeSize(for: node.topology.role) }

    private var status: NetworkMapNodeStatus {
        NetworkMapNodeStatus(role: node.topology.role, isOnline: isOnline, hasWeakLink: hasWeakLink)
    }

    var body: some View {
        bubble
            .frame(width: size, height: size)
            .overlay(alignment: .top) {
                if showsLabel {
                    label
                        .offset(y: size + DesignTokens.Size.networkMapNodeLabelSpacing)
                }
            }
            .opacity(isDimmed ? DesignTokens.Opacity.accentFill : 1)
    }

    private var bubble: some View {
        let tint = status.tint
        return ZStack {
            // Soft contact shadow, drawn as a gradient so it stays free.
            Circle()
                .fill(RadialGradient(
                    colors: [.black.opacity(DesignTokens.Opacity.networkMapBubbleShadow), .clear],
                    center: .center,
                    startRadius: size * 0.35,
                    endRadius: size / 2 + DesignTokens.Size.networkMapBubbleShadowRadius
                ))
                .frame(
                    width: size + DesignTokens.Size.networkMapBubbleShadowRadius * 2,
                    height: size + DesignTokens.Size.networkMapBubbleShadowRadius * 2
                )
                .offset(y: DesignTokens.Size.networkMapBubbleShadowY)

            // Glass body: a translucent base with the status tint pooling
            // towards the edge, the way light bends through a real bubble.
            Circle()
                .fill(Color(.systemBackground).opacity(colorScheme == .dark ? 0.55 : 0.78))
            Circle()
                .fill(RadialGradient(
                    colors: [
                        tint.opacity(DesignTokens.Opacity.networkMapBubbleTint * 0.4),
                        tint.opacity(status.isHealthy
                            ? DesignTokens.Opacity.networkMapBubbleTint
                            : DesignTokens.Opacity.networkMapBubbleStatusTint)
                    ],
                    center: UnitPoint(x: 0.4, y: 0.35),
                    startRadius: 0,
                    endRadius: size * 0.6
                ))

            DeviceImageView(
                device: device,
                isAvailable: isOnline,
                hasUpdate: hasUpdate,
                otaStatus: otaStatus,
                size: size * DesignTokens.Size.networkMapNodeImageRatio,
                showsAvailabilityIndicator: false
            )

            // Specular highlight across the top of the bubble.
            Ellipse()
                .fill(LinearGradient(
                    colors: [.white.opacity(colorScheme == .dark ? 0.28 : 0.7), .white.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(
                    width: size * DesignTokens.Size.networkMapBubbleHighlightRatio,
                    height: size * DesignTokens.Size.networkMapBubbleHighlightRatio / 2
                )
                .offset(y: -size * 0.24)
                .allowsHitTesting(false)

            // Rim light, plus a stronger status ring only when something is wrong.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.45 : 0.95),
                            tint.opacity(0.35),
                            .white.opacity(colorScheme == .dark ? 0.15 : 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DesignTokens.Size.networkMapBubbleRimWidth
                )
            if !status.isHealthy {
                Circle()
                    .strokeBorder(
                        tint.opacity(0.6),
                        lineWidth: DesignTokens.Size.networkMapBubbleStatusRimWidth
                    )
            }
        }
    }

    private var label: some View {
        Text(node.topology.friendlyName)
            .font(.caption.weight(.medium))
            .foregroundStyle(isOnline ? .primary : .secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(DesignTokens.Size.networkMapNodeLabelScale)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .frame(height: DesignTokens.Size.networkMapNodeLabelHeight)
            .background(Color(.systemBackground).opacity(0.8), in: Capsule())
            .frame(width: DesignTokens.Size.networkMapNodeLabelWidth)
            .fixedSize()
    }
}

/// The health a bubble's tint communicates. Kept separate so edges, bubbles
/// and any legend agree on the same colours.
struct NetworkMapNodeStatus {
    let role: NetworkTopologyNode.Role
    let isOnline: Bool
    let hasWeakLink: Bool

    var isHealthy: Bool { isOnline && !hasWeakLink }

    var tint: Color {
        if !isOnline { return .red }
        if hasWeakLink { return .orange }
        return role == .coordinator ? .blue : .green
    }
}
