import SwiftUI

struct CoverControlCard: View {
    let context: CoverControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var positionDraft: Double
    @State private var tiltDraft: Double
    @State private var isDraggingPosition = false

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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                heroHeadline
                if showsPositionSlider { positionSliderRow }
                if showsActionButtons { hairline; actionButtons }
                if context.tiltFeature != nil { hairline; tiltRow }
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(heroBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                    radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
            .onChange(of: context.positionValue) { _, v in
                guard !isDraggingPosition else { return }
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
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: isFullyClosed ? "blinds.horizontal.closed" : "blinds.horizontal.open")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(heroTint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(eyebrowLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let secondary = snapshotSecondaryText {
                        Text(secondary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

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

    private var heroBackground: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [heroTint.opacity(isFullyClosed ? 0.06 : 0.18),
                         heroTint.opacity(DesignTokens.Opacity.subtleFade)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Hero headline

    private var heroHeadline: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                heroEyebrow
                heroValue
            }
            Spacer(minLength: 0)
        }
    }

    private var heroEyebrow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: isFullyClosed ? "blinds.horizontal.closed" : "blinds.horizontal.open")
                .font(DesignTokens.Typography.eyebrowIcon)
                .symbolRenderingMode(.hierarchical)
            Text(eyebrowLabel)
                .font(DesignTokens.Typography.eyebrowLabel)
                .tracking(DesignTokens.Typography.eyebrowTracking)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .foregroundStyle(heroTint)
    }

    private var eyebrowLabel: String {
        if let endpoint = context.endpointLabel { return "Cover · \(endpoint)" }
        return "Cover"
    }

    @ViewBuilder
    private var heroValue: some View {
        if context.positionFeature != nil {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                    Text("\(Int(positionDraft.rounded()))")
                        .font(DesignTokens.Typography.heroValue)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)
                        .contentTransition(.numericText(value: positionDraft))
                        .animation(.snappy, value: positionDraft)
                    Text("%")
                        .font(DesignTokens.Typography.heroUnit)
                        .foregroundStyle(.secondary)
                }
                Text(context.displayState)
                    .font(DesignTokens.Typography.heroSubtitle)
                    .foregroundStyle(heroTint)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorRelaxed)
            }
        } else {
            Text(context.displayState)
                .font(DesignTokens.Typography.heroStateText)
                .foregroundStyle(heroTint)
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(DesignTokens.Opacity.hairline))
            .frame(height: DesignTokens.Size.hairline)
    }

    // MARK: - Position slider

    private var showsPositionSlider: Bool {
        guard let f = context.positionFeature else { return false }
        return mode == .interactive && f.isWritable
    }

    @ViewBuilder
    private var positionSliderRow: some View {
        if let f = context.positionFeature {
            Slider(
                value: $positionDraft,
                in: f.range ?? 0...100,
                onEditingChanged: { editing in
                    isDraggingPosition = editing
                    if !editing, let p = context.positionPayload(positionDraft) { onSend(p) }
                }
            )
            .tint(heroTint == Color(.tertiaryLabel) ? .orange : heroTint)
        }
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
        .buttonStyle(.bordered)
        .tint(heroTint == Color(.tertiaryLabel) ? .orange : heroTint)
    }

    // MARK: - Tilt

    @ViewBuilder
    private var tiltRow: some View {
        let writable = context.tiltFeature?.isWritable == true && mode == .interactive
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "rotate.3d")
                        .font(DesignTokens.Typography.eyebrowIcon)
                        .symbolRenderingMode(.hierarchical)
                    Text("Tilt")
                        .font(DesignTokens.Typography.eyebrowLabel)
                        .tracking(DesignTokens.Typography.eyebrowTracking)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                    Text("\(Int(tiltDraft.rounded()))")
                        .font(DesignTokens.Typography.snapshotRowValue)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("%")
                        .font(DesignTokens.Typography.snapshotRowUnit)
                        .foregroundStyle(.secondary)
                }
            }
            if writable, let f = context.tiltFeature {
                Slider(value: $tiltDraft, in: f.range ?? 0...100) { editing in
                    guard !editing else { return }
                    if let p = context.tiltPayload(tiltDraft) { onSend(p) }
                }
                .tint(heroTint == Color(.tertiaryLabel) ? .orange : heroTint)
            }
        }
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
