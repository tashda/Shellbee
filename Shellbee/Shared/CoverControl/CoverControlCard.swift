import SwiftUI

struct CoverControlCard: View {
    let context: CoverControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var positionDraft: Double
    @State private var tiltDraft: Double

    init(context: CoverControlContext, mode: CardDisplayMode, onSend: @escaping (JSONValue) -> Void = { _ in }) {
        self.context = context
        self.mode = mode
        self.onSend = onSend
        _positionDraft = State(initialValue: context.positionValue ?? 0)
        _tiltDraft = State(initialValue: context.tiltValue ?? 0)
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
                    value: headerValue,
                    tint: heroTint
                )
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
                if showsActionButtons { actionButtons }
                if let f = context.tiltFeature {
                    ValueCapsule(
                        value: tiltDraft,
                        range: f.range ?? 0...100,
                        fillColor: capsuleFill,
                        systemImage: "rotate.3d",
                        isInteractive: f.isWritable && mode == .interactive,
                        label: { "Tilt \(Int($0.rounded())) %" },
                        onChange: { value in
                            tiltDraft = value
                            if let p = context.tiltPayload(value) { onSend(p) }
                        }
                    )
                }
            }
            .cardSurface()
            .onChange(of: context.positionValue) { _, v in
                positionDraft = v ?? 0
            }
            .onChange(of: context.tiltValue) { _, v in tiltDraft = v ?? 0 }
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

    /// "64 % open", or the state word when position isn't reported.
    private var headerValue: String {
        if context.positionFeature != nil {
            return "\(Int(positionDraft.rounded())) % · \(context.displayState)"
        }
        return context.displayState
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

    private var actionButtons: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            actionButton(title: "Open", systemImage: "arrow.up.to.line", payload: "OPEN")
            actionButton(title: "Stop", systemImage: "stop.fill", payload: "STOP")
            actionButton(title: "Close", systemImage: "arrow.down.to.line", payload: "CLOSE")
        }
    }

    private func actionButton(title: String, systemImage: String, payload: String) -> some View {
        Button {
            if let p = context.statePayload(payload) { onSend(p) }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.lightSecondaryIcon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .glassButtonStyleIfAvailable()
        .buttonBorderShape(.capsule)
        .tint(.primary)
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
