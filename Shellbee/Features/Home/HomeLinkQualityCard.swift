import SwiftUI

/// How well the mesh is connected, as a distribution rather than an
/// average. 126 average is a healthy network or a bimodal one with a
/// corner of the house barely hanging on, and the average alone can't
/// tell you which. Tap a bar to see its devices; the weakest band is the
/// only coloured thing.
struct HomeLinkQualityCard: View {
    let snapshot: HomeSnapshot
    let readings: [HomeDeviceReading]
    /// Opens Devices filtered to weak signal.
    let onTapWeak: () -> Void
    /// Opens the full Link quality page.
    let onOpenPage: () -> Void

    @State private var selectedBand: Int?
    @State private var hoveredBand: Int?

    private static let listedCount = 3

    private var bands: [HomeSnapshot.LinkQualityBand] { snapshot.linkQualityBands }
    private var peak: Int { max(bands.map(\.count).max() ?? 0, 1) }
    private var measured: [HomeDeviceReading] {
        readings.filter { ($0.linkQuality ?? 0) > 0 }.sorted { ($0.linkQuality ?? 0) < ($1.linkQuality ?? 0) }
    }
    private var median: Int? {
        let values = measured.compactMap(\.linkQuality)
        return values.isEmpty ? nil : values[values.count / 2]
    }
    private var focusedBand: HomeSnapshot.LinkQualityBand? {
        bands.first { $0.id == (hoveredBand ?? selectedBand) }
    }
    private var weakCount: Int { measured.filter { ($0.linkQuality ?? 0) < DesignTokens.Threshold.weakSignal }.count }
    private var weakRouterCount: Int {
        measured.filter { $0.device.type == .router && ($0.linkQuality ?? 0) < DesignTokens.Threshold.weakSignal }.count
    }
    private var listed: [HomeDeviceReading] {
        guard let band = bands.first(where: { $0.id == selectedBand }) else { return Array(measured.prefix(Self.listedCount)) }
        return Array(measured.filter { band.contains($0.linkQuality ?? 0) }.prefix(Self.listedCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                CardHeader(
                    instrument: .init(kind: .signal, normalizedValue: Double(median ?? 0) / DesignTokens.Threshold.maxLinkQuality),
                    title: "Link quality",
                    value: headerValue
                )
                CardAccessoryButton(systemImage: "arrow.up.right", accessibilityLabel: "Open Link Quality", action: onOpenPage)
            }

            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xs) {
                ForEach(bands) { band in
                    bar(for: band)
                }
            }
            .frame(height: DesignTokens.Size.linkQualityChart)

            if weakCount > 0 {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Button(action: onTapWeak) { chipLabel("\(weakCount) weak") }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows devices with a weak signal")
                    if weakRouterCount > 0 {
                        chipLabel("\(weakRouterCount) weak router\(weakRouterCount == 1 ? "" : "s")")
                    }
                }
            }

            if !listed.isEmpty {
                VStack(spacing: 0) {
                    ForEach(listed) { reading in
                        NavigationLink(value: reading.route) {
                            HomeDeviceReadingRow(
                                reading: reading,
                                value: "\(reading.linkQuality ?? 0)",
                                valueStyle: AnyShapeStyle(.status(reading.linkQuality?.lqiTone ?? .poor))
                            )
                            .padding(.vertical, DesignTokens.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                        if reading.id != listed.last?.id { Divider() }
                    }
                }
            }
        }
        .cardSurface()
    }

    private var headerValue: String? {
        if let band = focusedBand { return "\(band.label) · \(band.count) device\(band.count == 1 ? "" : "s")" }
        return median.map { "\($0) median" }
    }

    private func chipLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(.fill.tertiary, in: Capsule())
    }

    private func bar(for band: HomeSnapshot.LinkQualityBand) -> some View {
        let isSelected = selectedBand == band.id
        return VStack(spacing: DesignTokens.Spacing.xs) {
            Text("\(band.count)")
                .font(.caption2.weight(isSelected ? .bold : .regular))
                .foregroundStyle(.themedStatus(band.needsAttention && band.count > 0 ? .red : isSelected ? .primary : .secondary))
                .monospacedDigit()
                .lineLimit(1)

            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                        .fill(fill(for: band))
                        .frame(height: max(proxy.size.height * CGFloat(band.count) / CGFloat(peak),
                                           DesignTokens.Size.linkQualityBarMinimum))
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                                    .strokeBorder(.primary, lineWidth: DesignTokens.Size.linkQualitySelectionStroke)
                            }
                        }
                }
            }

            Text(band.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) { selectedBand = isSelected ? nil : band.id }
        }
        .onHover { inside in hoveredBand = inside ? band.id : (hoveredBand == band.id ? nil : hoveredBand) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(band.count) devices between \(band.label)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// One hue in three weights, so the shape carries the meaning and only
    /// the band you'd act on takes a colour.
    private func fill(for band: HomeSnapshot.LinkQualityBand) -> AnyShapeStyle {
        if band.needsAttention {
            return band.count > 0 ? AnyShapeStyle(.status(.poor)) : AnyShapeStyle(Color(.tertiarySystemFill))
        }
        let share = Double(band.count) / Double(peak)
        return AnyShapeStyle(.shellbeeChartInk.opacity(DesignTokens.Opacity.chartBarFloor
            + share * DesignTokens.Opacity.chartBarRange))
    }
}

extension HomeSnapshot.LinkQualityBand {
    func contains(_ value: Int) -> Bool {
        value >= lowerBound && upperBound.map { value < $0 } ?? true
    }
}

#Preview {
    NavigationStack {
        HomeLinkQualityCard(snapshot: .preview, readings: [], onTapWeak: {}, onOpenPage: {})
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}
