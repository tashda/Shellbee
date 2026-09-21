import SwiftUI

struct NetworkMapRefreshProgressView: View {
    let bridgeName: String
    let phase: NetworkMapRefreshPhase
    let startedAt: Date?
    let scan: NetworkMapScanProgress?
    let fillsViewport: Bool
    let onDismiss: () -> Void
    let onRetry: () -> Void

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
            let rotation = reduceMotion || !isWorking ? 0 : elapsed * 42

            VStack(spacing: DesignTokens.Spacing.md) {
                networkActivityGraphic(rotation: rotation)
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    Text(title)
                        .font(.headline)
                    Text(bridgeName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                    }
                }

                content(now: context.date)
            }
            .frame(maxWidth: fillsViewport
                   ? DesignTokens.Size.networkMapScanCardWideWidth
                   : DesignTokens.Size.networkMapScanCardWidth)
            .padding(DesignTokens.Spacing.xl)
            .modifier(CardBackground())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
        .animation(.smooth, value: phase)
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
        case .failed:
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("Done", action: onDismiss)
                    .buttonStyle(.bordered)
                Button("Try Again", action: onRetry)
                    .glassProminentButtonStyleIfAvailable()
            }
            .controlSize(.large)
        }
    }

    // MARK: - Copy

    private var title: String {
        switch phase {
        case .idle: "Network Map"
        case .requesting, .building: "Refreshing Network Map"
        case .completed: "Network Map Updated"
        case .failed: "Network Map Refresh Failed"
        }
    }

    private var detail: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    private func networkActivityGraphic(rotation: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.tint.opacity(0.14), lineWidth: DesignTokens.Size.hairline)
                .frame(
                    width: DesignTokens.Size.networkMapRefreshOuterRing,
                    height: DesignTokens.Size.networkMapRefreshOuterRing
                )
            Circle()
                .stroke(.tint.opacity(0.18), style: StrokeStyle(lineWidth: DesignTokens.Size.hairline, dash: [4, 7]))
                .frame(
                    width: DesignTokens.Size.networkMapRefreshInnerRing,
                    height: DesignTokens.Size.networkMapRefreshInnerRing
                )
                .rotationEffect(.degrees(rotation))

            ForEach(0..<6, id: \.self) { index in
                let angle = Angle.degrees(Double(index) * 60 + rotation)
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.accentColor : Color.secondary.opacity(0.48))
                    .frame(
                        width: index.isMultiple(of: 2)
                            ? DesignTokens.Size.networkMapRefreshActiveDot
                            : DesignTokens.Size.networkMapRefreshPassiveDot,
                        height: index.isMultiple(of: 2)
                            ? DesignTokens.Size.networkMapRefreshActiveDot
                            : DesignTokens.Size.networkMapRefreshPassiveDot
                    )
                    .offset(
                        x: cos(angle.radians) * DesignTokens.Size.networkMapRefreshOrbitRadius,
                        y: sin(angle.radians) * DesignTokens.Size.networkMapRefreshOrbitRadius
                    )
            }

            Image(systemName: centerSymbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(centerTint)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(
            width: DesignTokens.Size.networkMapRefreshGraphic,
            height: DesignTokens.Size.networkMapRefreshGraphic
        )
        .accessibilityHidden(true)
    }

    private var centerSymbol: String {
        switch phase {
        case .completed(let summary):
            summary.failedDeviceNames.isEmpty ? "checkmark.circle" : "exclamationmark.triangle"
        case .failed: "xmark.octagon"
        case .idle, .requesting, .building: "point.3.connected.trianglepath.dotted"
        }
    }

    private var centerTint: Color {
        switch phase {
        case .completed(let summary): summary.failedDeviceNames.isEmpty ? .green : .orange
        case .failed: .red
        case .idle, .requesting, .building: .accentColor
        }
    }
}

/// Liquid Glass where available, otherwise a single system material — no
/// stacked strokes or shadows, so the card reads like system chrome.
private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}
