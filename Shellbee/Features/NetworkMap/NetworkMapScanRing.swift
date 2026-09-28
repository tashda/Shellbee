import SwiftUI

/// The scan's progress as a ring around the network symbol: it fills as
/// routers answer, spins while progress can't be counted, and settles on a
/// checkmark, warning or failure when the scan ends.
struct NetworkMapScanRing: View {
    enum State: Equatable {
        /// `nil` fraction: working, but progress isn't visible.
        case working(fraction: Double?)
        case succeeded
        case partial
        case failed
    }

    let state: State
    /// Seconds since the scan began, for the spinning arc.
    let elapsed: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shellbeeTheme) private var theme

    private static let spinningArc = 0.28

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(DesignTokens.Opacity.chipFill), lineWidth: DesignTokens.Size.networkMapScanRingLine)
            Circle()
                .trim(from: 0, to: trim)
                .stroke(tint, style: StrokeStyle(lineWidth: DesignTokens.Size.networkMapScanRingLine, lineCap: .round))
                .rotationEffect(.degrees(rotation - 90))
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: DesignTokens.Size.networkMapScanRing, height: DesignTokens.Size.networkMapScanRing)
        .animation(.smooth, value: state)
        .accessibilityHidden(true)
    }

    private var trim: Double {
        switch state {
        case .working(let fraction): fraction.map { max($0, 0.02) } ?? Self.spinningArc
        case .succeeded, .partial, .failed: 1
        }
    }

    private var rotation: Double {
        guard case .working(nil) = state, !reduceMotion else { return 0 }
        return elapsed * 180
    }

    private var symbol: String {
        switch state {
        case .working: "point.3.connected.trianglepath.dotted"
        case .succeeded: "checkmark"
        case .partial: "exclamationmark"
        case .failed: "xmark"
        }
    }

    private var tint: AnyShapeStyle {
        switch state {
        case .working: AnyShapeStyle(theme.accent)
        case .succeeded: AnyShapeStyle(.themedStatus(.green))
        case .partial: AnyShapeStyle(.themedStatus(.orange))
        case .failed: AnyShapeStyle(.themedStatus(.red))
        }
    }
}
