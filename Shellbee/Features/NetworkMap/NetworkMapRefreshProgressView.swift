import SwiftUI

/// The floating card over the map while it refreshes: a progress ring, the
/// title and bridge, then live figures, the result, or what went wrong.
/// One Liquid Glass panel, tinted toward the theme by the Card Tint.
struct NetworkMapRefreshProgressView: View {
    let bridgeID: UUID
    let bridgeName: String
    let phase: NetworkMapRefreshPhase
    let startedAt: Date?
    let scan: NetworkMapScanProgress?
    let fillsViewport: Bool
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isWorking: Bool {
        switch phase {
        case .requesting, .building: true
        case .idle, .completed, .failed: false
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30, paused: !isWorking)) { context in
            let elapsed = startedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                header(elapsed: elapsed)
                content(now: context.date)
            }
            .frame(maxWidth: fillsViewport
                   ? DesignTokens.Size.networkMapScanCardWideWidth
                   : DesignTokens.Size.networkMapScanCardWidth)
            .padding(DesignTokens.Spacing.xl)
            .modifier(NetworkMapScanCardBackground())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
        .animation(.smooth, value: phase)
    }

    private func header(elapsed: TimeInterval) -> some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            NetworkMapScanRing(state: ringState, elapsed: elapsed)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let name = environment.attributionBridgeName(for: bridgeID) {
                        BridgeMonogram(bridgeID: bridgeID, bridgeName: name)
                        Text(name)
                    } else {
                        Text(bridgeName)
                    }
                    if isWorking {
                        Text("· \(NetworkMapScanLiveView.clock(elapsed))")
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch phase {
        case .idle:
            EmptyView()
        case .requesting, .building:
            if let scan {
                NetworkMapScanLiveView(scan: scan, now: now)
            }
        case .completed(let summary):
            NetworkMapScanSummaryView(summary: summary, onDismiss: onDismiss)
        case .failed(let message):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DesignTokens.Spacing.md) {
                    Button(action: onDismiss) {
                        Text("Done").frame(maxWidth: .infinity)
                    }
                    .glassButtonStyleIfAvailable()
                    Button(action: onRetry) {
                        Text("Try Again").frame(maxWidth: .infinity)
                    }
                    .glassProminentButtonStyleIfAvailable()
                }
                .controlSize(.large)
            }
        }
    }

    private var title: String {
        switch phase {
        case .idle: "Network map"
        case .requesting, .building: "Refreshing network map"
        case .completed: "Network map updated"
        case .failed: "Couldn't refresh the network map"
        }
    }

    private var ringState: NetworkMapScanRing.State {
        switch phase {
        case .idle, .requesting, .building: .working(fraction: scan?.fractionComplete)
        case .completed(let summary): summary.failedDeviceNames.isEmpty ? .succeeded : .partial
        case .failed: .failed
        }
    }
}

/// Liquid Glass leaning toward the theme accent by the Card Tint, so the
/// card belongs to the theme; Standard is plain glass. Material before
/// iOS 26.
private struct NetworkMapScanCardBackground: ViewModifier {
    @Environment(\.shellbeeTheme) private var theme
    @Environment(\.shellbeeSurfaceTint) private var surfaceTint

    private static let maximumTint = 0.22

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous)
        if #available(iOS 26.0, *) {
            if let accent = theme.palette?.accent {
                content.glassEffect(.regular.tint(accent.opacity(Self.maximumTint * surfaceTint)), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}
