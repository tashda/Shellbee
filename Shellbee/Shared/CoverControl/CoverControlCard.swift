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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            if context.positionFeature != nil {
                positionHero
            }
            if mode == .interactive, context.stateFeature?.isWritable == true {
                actionButtons
            }
            if context.tiltFeature != nil {
                tiltRow
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .onChange(of: context.positionValue) { _, v in
            guard !isDraggingPosition else { return }
            positionDraft = v ?? 0
        }
        .onChange(of: context.tiltValue) { _, v in tiltDraft = v ?? 0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: coverIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(context.isOpen ? Color.accentColor : Color.secondary)
                .frame(width: 36, height: 36)
                .background(
                    (context.isOpen ? Color.accentColor.opacity(DesignTokens.Opacity.chipFill) : Color(.tertiarySystemFill)),
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Cover")
                    .font(.headline)
                Text(context.displayState)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var coverIcon: String {
        context.isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
    }

    // MARK: - Position hero

    @ViewBuilder
    private var positionHero: some View {
        let writable = context.positionFeature?.isWritable == true && mode == .interactive
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .lastTextBaseline) {
                Text("\(Int(positionDraft.rounded()))%")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: positionDraft))
                    .animation(.snappy, value: positionDraft)
                Text("open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if writable, let f = context.positionFeature {
                Slider(
                    value: $positionDraft,
                    in: f.range ?? 0...100,
                    onEditingChanged: { editing in
                        isDraggingPosition = editing
                        if !editing, let p = context.positionPayload(positionDraft) { onSend(p) }
                    }
                )
            } else {
                positionFillBar(fraction: positionDraft / 100)
            }
        }
    }

    private func positionFillBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(Color.accentColor)
                    .frame(width: max(8, geo.size.width * CGFloat(max(0, min(1, fraction)))))
            }
        }
        .frame(height: 10)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            coverActionButton(title: "Open", systemImage: "arrow.up.to.line") {
                onSend(.object(["state": .string("OPEN")]))
            }
            coverActionButton(title: "Stop", systemImage: "stop.fill") {
                onSend(.object(["state": .string("STOP")]))
            }
            coverActionButton(title: "Close", systemImage: "arrow.down.to.line") {
                onSend(.object(["state": .string("CLOSE")]))
            }
        }
    }

    private func coverActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
    }

    // MARK: - Tilt

    @ViewBuilder private var tiltRow: some View {
        let writable = context.tiltFeature?.isWritable == true && mode == .interactive
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("Tilt")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(tiltDraft.rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if writable, let f = context.tiltFeature {
                Slider(value: $tiltDraft, in: f.range ?? 0...100) { editing in
                    guard !editing else { return }
                    if let p = context.tiltPayload(tiltDraft) { onSend(p) }
                }
            } else {
                positionFillBar(fraction: tiltDraft / 100)
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
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
