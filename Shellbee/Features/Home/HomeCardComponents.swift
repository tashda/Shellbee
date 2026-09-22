import SwiftUI

/// The Home card surface: flat, with a hairline edge instead of a shadow.
/// A shadow does nothing against the black grouped background in dark mode,
/// so the edge is what separates the card from the page in both appearances.
struct HomeCardContainer<Content: View>: View {
    var padding: CGFloat = DesignTokens.Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: DesignTokens.Size.hairline)
        }
    }
}

/// Card heading: the glyph carries the card's tint, the text stays primary.
/// Colour is reserved for severity, so a red count is the only coloured thing
/// on a healthy screen.
struct HomeCardTitle: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

/// One figure in a card's stat row. The label sits above the value so the cell
/// reads top-to-bottom as "Offline → 7", and the value itself carries any
/// trouble: it turns red and grows a caption rather than handing the problem
/// to a chip or a separate alert row.
struct HomeStatCell: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var caption: String? = nil
    /// The underlying count. Drives the rolling digit transition and the brief
    /// highlight when the figure changes while the card is on screen.
    var count: Int? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFlashing = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.eyebrowLabel)
                .tracking(DesignTokens.Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count ?? 0)))
                .animation(.easeOut(duration: DesignTokens.Duration.mediumAnimation), value: count)
                .padding(.horizontal, isFlashing ? DesignTokens.Spacing.xs : 0)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                        .fill(valueColor.opacity(isFlashing ? DesignTokens.Opacity.statChangeFlash : 0))
                }

            if let caption {
                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(captionTint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: count) { _, _ in flash() }
    }

    private var captionTint: Color {
        valueColor == .primary ? .secondary : valueColor
    }

    @MainActor
    private func flash() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: DesignTokens.Duration.quickFade)) { isFlashing = true }
        Task {
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.statChangeFlash))
            withAnimation(.easeOut(duration: DesignTokens.Duration.mediumAnimation)) { isFlashing = false }
        }
    }
}

/// The stat row every card uses, so cells line up card to card.
struct HomeStatRow<Content: View>: View {
    @ViewBuilder let cells: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            cells()
        }
    }
}

/// How much of the network answered, as three proportional shares. A bar
/// rather than a ring: untracked devices get an honest slice instead of being
/// hidden in the arithmetic, and nothing implies 100% is a goal.
struct HomeReachabilityBar: View {
    let online: Int
    let offline: Int
    let untracked: Int

    private struct Segment: Identifiable {
        let id: String
        let count: Int
        let color: Color
    }

    private var segments: [Segment] {
        [
            Segment(id: "online", count: online, color: .green),
            Segment(id: "offline", count: offline, color: .red),
            Segment(id: "untracked", count: untracked, color: Color(.systemGray)),
        ].filter { $0.count > 0 }
    }

    private var total: Int { max(online + offline + untracked, 1) }

    var body: some View {
        GeometryReader { proxy in
            let gaps = CGFloat(max(segments.count - 1, 0)) * DesignTokens.Spacing.xxs
            let usable = max(proxy.size.width - gaps, 0)
            HStack(spacing: DesignTokens.Spacing.xxs) {
                ForEach(segments) { segment in
                    Capsule(style: .continuous)
                        .fill(segment.color)
                        .frame(width: usable * CGFloat(segment.count) / CGFloat(total))
                }
            }
        }
        .frame(height: DesignTokens.Size.reachabilityBar)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(online) answering, \(offline) offline, \(untracked) untracked")
    }
}

/// A live status dot. Pulses only while the connection is unsettled, so a
/// steady dot genuinely means steady.
struct HomeStatusDot: View {
    let color: Color
    var isPulsing: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: DesignTokens.Size.homeStatusDot, height: DesignTokens.Size.homeStatusDot)
            .opacity(isDimmed ? 0.35 : 1)
            .onAppear { syncPulse() }
            .onChange(of: isPulsing) { _, _ in syncPulse() }
            .accessibilityHidden(true)
    }

    /// A repeating animation only runs once something animates *into* it, so
    /// the pulse is started by a state change rather than declared on a
    /// constant.
    @MainActor
    private func syncPulse() {
        guard isPulsing, !reduceMotion else {
            withAnimation(.easeOut(duration: DesignTokens.Duration.quickFade)) { isDimmed = false }
            return
        }
        withAnimation(
            .easeInOut(duration: DesignTokens.Duration.statusPulse).repeatForever(autoreverses: true)
        ) {
            isDimmed = true
        }
    }
}

/// A one-line card body for a subject with nothing to report. Used when a card
/// collapses on a healthy day, so the shape of the page answers "is anything
/// wrong" before a single figure is read.
struct HomeCalmSummary: View {
    let symbol: String
    let title: String
    let tint: Color
    let detail: String
    var detailColor: Color = .secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            HomeCardTitle(symbol: symbol, title: title, tint: tint)
            Spacer(minLength: DesignTokens.Spacing.sm)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(detailColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// An actionable line under a card's figures — a restart to apply, an update to
/// install, permit join to close. Counts live in the stat cells; this row is
/// for things the user can *do*.
struct HomeCardAlertRow: View {
    let symbol: String
    let title: String
    let color: Color
    let action: (() -> Void)?

    var body: some View {
        SwiftUI.Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(HomeAlertButtonStyle())
            } else {
                label
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var label: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: DesignTokens.Size.summaryRowTrailingIcon)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

struct HomeCardAlertList<Content: View>: View {
    @ViewBuilder let rows: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            _VariadicView.Tree(DividerLayout()) { rows() }
        }
        .padding(.bottom, -DesignTokens.Spacing.sm)
    }
}

private struct DividerLayout: _VariadicView.MultiViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        ForEach(children) { child in
            child
            if child.id != last {
                Divider().padding(.leading, DesignTokens.Size.summaryRowTrailingIcon + DesignTokens.Spacing.md)
            }
        }
    }
}

struct StatCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1, anchor: .leading)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}

struct HomeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}

private struct HomeAlertButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}

#Preview("Stat cells") {
    VStack(spacing: DesignTokens.Spacing.md) {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HomeCardTitle(symbol: "sensor.tag.radiowaves.forward.fill", title: "Devices", tint: .orange)
                HomeStatRow {
                    HomeStatCell(label: "Devices", value: "119", caption: "23 groups", count: 119)
                    HomeStatCell(label: "Offline", value: "7", valueColor: .red, caption: "3h+ quiet", count: 7)
                    HomeStatCell(label: "Battery", value: "2", valueColor: .red, caption: "lowest 8%", count: 2)
                }
                HomeReachabilityBar(online: 112, offline: 7, untracked: 2)
            }
        }
        HomeCardContainer(padding: DesignTokens.Spacing.md) {
            HomeCalmSummary(
                symbol: "sensor.tag.radiowaves.forward.fill",
                title: "Devices",
                tint: .orange,
                detail: "119 · all answering"
            )
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
