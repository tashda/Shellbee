import SwiftUI

/// One figure in the network-scan overview: a large number over its label.
struct NetworkMapScanStatTile: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(
            tint.opacity(DesignTokens.Opacity.networkMapScanTileFill),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

/// The three stages of a refresh — request, router scan, map build — so
/// it's always clear the bridge is working and how far along it is.
struct NetworkMapScanStepsView: View {
    enum StepState {
        case pending
        case active
        case done
    }

    let request: StepState
    let scan: StepState
    let build: StepState

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            step("Request Sent", request)
            connector(after: request)
            step("Scanning Routers", scan)
            connector(after: scan)
            step("Building Map", build)
        }
        .frame(maxWidth: .infinity)
    }

    private func step(_ title: String, _ state: StepState) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(state == .pending ? Color.secondary.opacity(0.18) : Color.accentColor)
                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                } else if state == .active {
                    Circle()
                        .fill(.white)
                        .padding(DesignTokens.Spacing.xs)
                }
            }
            .frame(width: DesignTokens.Size.networkMapScanStepDot, height: DesignTokens.Size.networkMapScanStepDot)
            Text(title)
                .font(.caption2.weight(state == .active ? .semibold : .regular))
                .foregroundStyle(state == .pending ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(state == .done ? "Done" : state == .active ? "In progress" : "Pending")
    }

    private func connector(after state: StepState) -> some View {
        Capsule()
            .fill(state == .done ? Color.accentColor : Color.secondary.opacity(0.18))
            .frame(height: DesignTokens.Size.networkMapScanConnector)
            .frame(maxWidth: .infinity)
            // Line up with the centre of the step dots.
            .padding(.top, (DesignTokens.Size.networkMapScanStepDot - DesignTokens.Size.networkMapScanConnector) / 2)
            .accessibilityHidden(true)
    }
}
