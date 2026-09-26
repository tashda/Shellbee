import SwiftUI

struct CoverControlCard: View {
    let context: CoverControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var positionDraft: Double
    /// Set when Open or Close is tapped, so Stop is offered even for
    /// motors that never report that they're moving.
    @State private var commandedAt: Date?

    init(context: CoverControlContext, mode: CardDisplayMode, onSend: @escaping (JSONValue) -> Void = { _ in }) {
        self.context = context
        self.mode = mode
        self.onSend = onSend
        _positionDraft = State(initialValue: context.positionValue ?? 0)
    }

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                CardHeader(
                    systemImage: isFullyClosed ? "blinds.horizontal.closed" : "blinds.horizontal.open",
                    title: eyebrowLabel,
                    value: context.displayState,
                    tint: heroTint
                ) {
                    if showsActionButtons { headerButtons }
                }
                if let f = context.positionFeature {
                    ValueCapsule(
                        value: positionDraft,
                        range: f.range ?? 0...100,
                        fillColor: capsuleFill,
                        systemImage: isFullyClosed ? "blinds.horizontal.closed" : "blinds.horizontal.open",
                        isInteractive: showsPositionSlider,
                        label: { "\(Int($0.rounded())) %" },
                        onChange: { value in
                            positionDraft = value
                            if let p = context.positionPayload(value) { onSend(p) }
                        }
                    )
                }
            }
            .cardSurface()
            .onChange(of: context.positionValue) { _, v in
                positionDraft = v ?? 0
                if v == 0 || v == 100 { commandedAt = nil }
            }
            .task(id: commandedAt) {
                guard commandedAt != nil else { return }
                try? await Task.sleep(for: .seconds(DesignTokens.Duration.coverStopWindow))
                commandedAt = nil
            }
        }
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Blinds glyph + "Cover" + position
    /// summary + OPEN/CLOSED pill.
    private var snapshotContent: some View {
        CompactSnapshotCard {
            CompactControlSnapshotRow(
                systemImage: isFullyClosed ? "blinds.horizontal.closed" : "blinds.horizontal.open",
                title: eyebrowLabel,
                subtitle: snapshotSecondaryText,
                tint: heroTint
            ) {
                Text(isFullyClosed ? "CLOSED" : "OPEN")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isFullyClosed ? Color(.secondaryLabel) : heroTint)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        isFullyClosed ? Color(.tertiarySystemFill)
                                      : heroTint.opacity(DesignTokens.Opacity.chipFill),
                        in: Capsule()
                    )
            }
        }
    }

    private var snapshotSecondaryText: String? {
        var parts: [String] = []
        if let pos = context.positionValue {
            parts.append("\(Int(pos))%")
        }
        if let tilt = context.tiltValue {
            parts.append("Tilt \(Int(tilt))%")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Tinting

    /// One state-derived color for the gradient, eyebrow, slider, and action
    /// buttons. Orange when any opening is present (a "letting in light" feel
    /// that matches Apple Home's blinds tile when open); grey when fully closed.
    private var heroTint: Color {
        if isFullyClosed { return Color(.tertiaryLabel) }
        return .orange
    }

    /// "Fully closed" means the state explicitly says CLOSED *and* (if position
    /// is reported) position is 0. We don't trust state alone — many covers
    /// keep state at OPEN while position falls below 100%.
    private var isFullyClosed: Bool {
        if let pos = context.positionValue, pos > 0 { return false }
        let state = context.stateValue?.uppercased()
        return state == "CLOSED" || state == "CLOSE" || (state == nil && context.positionValue == 0)
    }

    private var eyebrowLabel: String {
        if let endpoint = context.endpointLabel { return "Cover · \(endpoint)" }
        return "Cover"
    }

    private var capsuleFill: Color {
        Color.orange.opacity(isFullyClosed ? 0.18 : 0.35)
    }

    // MARK: - Position slider

    private var showsPositionSlider: Bool {
        guard let f = context.positionFeature else { return false }
        return mode == .interactive && f.isWritable
    }

    // MARK: - Action buttons

    private var showsActionButtons: Bool {
        mode == .interactive && context.stateFeature?.isWritable == true
    }

    private var showsStop: Bool { context.isMoving || commandedAt != nil }

    /// Open and Close as two round buttons; one Stop button while moving.
    @ViewBuilder
    private var headerButtons: some View {
        if showsStop {
            CardAccessoryButton(systemImage: "stop.fill", accessibilityLabel: "Stop") {
                send("STOP")
                commandedAt = nil
            }
        } else {
            HStack(spacing: DesignTokens.Spacing.sm) {
                CardAccessoryButton(systemImage: "arrow.up", accessibilityLabel: "Open") {
                    send("OPEN")
                    commandedAt = .now
                }
                CardAccessoryButton(systemImage: "arrow.down", accessibilityLabel: "Close") {
                    send("CLOSE")
                    commandedAt = .now
                }
            }
        }
    }

    private func send(_ command: String) {
        if let p = context.statePayload(command) { onSend(p) }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = CoverControlContext(device: .preview, state: [
                "state": .string("OPEN"), "position": .int(65), "tilt": .int(45)
            ]) {
                CoverControlCard(context: ctx, mode: .interactive, onSend: { _ in })
                CoverControlCard(context: ctx, mode: .snapshot, onSend: { _ in })
            }
            if let closed = CoverControlContext(device: .preview, state: [
                "state": .string("CLOSED"), "position": .int(0)
            ]) {
                CoverControlCard(context: closed, mode: .interactive, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
