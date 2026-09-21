import SwiftUI

struct NetworkMapRefreshProgressView: View {
    let bridgeName: String
    let phase: NetworkMapRefreshPhase
    let startedAt: Date?
    let totalDevices: Int
    let reportedDevices: Int
    let fillsViewport: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30, paused: false)) { context in
            let elapsed = startedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            let rotation = reduceMotion ? 0 : elapsed * 42

            VStack(spacing: DesignTokens.Spacing.lg) {
                networkActivityGraphic(rotation: rotation)
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(bridgeName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(detail(for: elapsed))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                }

                if phase != .failed(message: failureMessage) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.accentColor)
                }

                if totalDevices > 0 {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                            .foregroundStyle(.tint)
                        Text("\(reportedCount) of \(max(totalDevices, reportedCount)) devices reported")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: fillsViewport ? 560 : 420)
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
    }

    private var title: String {
        switch phase {
        case .idle: "Network Map"
        case .requesting: "Refreshing Network Map"
        case .building: "Organizing Network Map"
        case .completed: "Network Map Ready"
        case .failed: "Network Map Refresh Failed"
        }
    }

    private var reportedCount: Int {
        switch phase {
        case .building(let count), .completed(let count): count
        case .idle, .requesting, .failed: reportedDevices
        }
    }

    private var failureMessage: String {
        if case .failed(let message) = phase { return message }
        return ""
    }

    private func detail(for elapsed: TimeInterval) -> String {
        switch phase {
        case .idle: return ""
        case .requesting:
            if elapsed < 1.5 { return "Contacting the coordinator" }
            if elapsed < 4 { return "Reading device routes and link quality" }
            return "Waiting for the coordinator to finish its scan"
        case .building:
            return "Arranging devices and connections"
        case .completed:
            return "The latest topology is now available"
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

            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(
            width: DesignTokens.Size.networkMapRefreshGraphic,
            height: DesignTokens.Size.networkMapRefreshGraphic
        )
        .accessibilityHidden(true)
    }
}
