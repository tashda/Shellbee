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

            VStack(spacing: DesignTokens.Spacing.lg) {
                networkActivityGraphic(rotation: rotation)
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.title3.weight(.semibold))
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
            .padding(DesignTokens.Spacing.xxl)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous))
            .glassEffectIfAvailable(in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous)
                    .strokeBorder(.white.opacity(0.32), lineWidth: DesignTokens.Size.hairline)
            }
            .shadow(color: .black.opacity(0.12), radius: DesignTokens.Shadow.floatingRadius, y: DesignTokens.Shadow.floatingY)
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
            VStack(spacing: DesignTokens.Spacing.lg) {
                NetworkMapScanStepsView(request: requestStep, scan: scanStep, build: buildStep)
                if let scan {
                    NetworkMapScanLiveView(scan: scan, now: now)
                }
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

    // MARK: - Steps

    /// Z2M logs the start of its scan at info level; with a stricter log
    /// level that line never arrives, so the scan is assumed to be running
    /// as soon as the request is out.
    private var scanHasStarted: Bool {
        guard let scan else { return true }
        return scan.scanStartedAt != nil || scan.visibility == .failuresOnly
    }

    private var requestStep: NetworkMapScanStepsView.StepState {
        scanHasStarted ? .done : .active
    }

    private var scanStep: NetworkMapScanStepsView.StepState {
        if case .building = phase { return .done }
        if scan?.scanFinishedAt != nil { return .done }
        return scanHasStarted ? .active : .pending
    }

    private var buildStep: NetworkMapScanStepsView.StepState {
        if case .building = phase { return .active }
        return scan?.scanFinishedAt != nil ? .active : .pending
    }

    // MARK: - Copy

    private var title: String {
        switch phase {
        case .idle: "Network Map"
        case .requesting, .building: "Refreshing Network Map"
        case .completed: "Network Map Ready"
        case .failed: "Network Map Refresh Failed"
        }
    }

    private var detail: String? {
        switch phase {
        case .idle, .completed:
            return nil
        case .requesting:
            if scan?.scanFinishedAt != nil { return "Scan finished, waiting for the results" }
            return scanHasStarted
                ? "Zigbee2MQTT is asking each router for its neighbors"
                : "Waiting for Zigbee2MQTT to start the scan"
        case .building:
            return "Arranging devices and connections"
        case .failed(let message):
            return message
        }
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
                .font(.system(size: 38, weight: .medium))
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
