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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            if mode == .interactive { actionButtons }
            if context.positionFeature != nil { positionRow }
            if context.tiltFeature != nil { tiltRow }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
        .onChange(of: context.positionValue) { _, v in positionDraft = v ?? 0 }
        .onChange(of: context.tiltValue) { _, v in tiltDraft = v ?? 0 }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: context.isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(context.isOpen ? Color.accentColor : Color(.tertiaryLabel))
                Text("Cover State").font(.headline)
            } else {
                Text("Cover").font(.headline)
            }
            Spacer()
            stateBadge
        }
    }

    private var stateBadge: some View {
        Text(context.displayState)
            .font(.caption.weight(.bold))
            .foregroundStyle(context.isOpen ? Color.accentColor : Color(.secondaryLabel))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                context.isOpen ? Color.accentColor.opacity(DesignTokens.Opacity.chipFill) : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }

    private var actionButtons: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            coverButton("Open", icon: "chevron.up") { onSend(.object(["state": .string("OPEN")])) }
            coverButton("Stop", icon: "stop.circle") { onSend(.object(["state": .string("STOP")])) }
            coverButton("Close", icon: "chevron.down") { onSend(.object(["state": .string("CLOSE")])) }
        }
    }

    private func coverButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(label).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    @ViewBuilder private var positionRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("Position").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(positionDraft))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if mode == .interactive, let f = context.positionFeature, f.isWritable {
                Slider(value: $positionDraft, in: f.range ?? 0...100) { editing in
                    guard !editing else { return }
                    if let p = context.positionPayload(positionDraft) { onSend(p) }
                }
            } else {
                progressBar(fraction: positionDraft / 100)
            }
        }
    }

    @ViewBuilder private var tiltRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("Tilt").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(tiltDraft))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if mode == .interactive, let f = context.tiltFeature, f.isWritable {
                Slider(value: $tiltDraft, in: f.range ?? 0...100) { editing in
                    guard !editing else { return }
                    if let p = context.tiltPayload(tiltDraft) { onSend(p) }
                }
            } else {
                progressBar(fraction: tiltDraft / 100)
            }
        }
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill)).frame(height: 6)
                Capsule().fill(Color.accentColor.opacity(0.6))
                    .frame(width: max(6, geo.size.width * CGFloat(fraction)), height: 6)
            }
        }
        .frame(height: 6)
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
