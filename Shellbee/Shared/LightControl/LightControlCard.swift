import SwiftUI

struct LightControlCard: View {
    enum Surface: String, CaseIterable, Identifiable {
        case color = "Color"
        case white = "White"
        var id: String { rawValue }
    }

    let context: LightControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void
    /// When `true` (the default for snapshot contexts like LogDetailView),
    /// Startup + Other-advanced configuration is reachable via sheet buttons
    /// inside the card. When `false`, those buttons are suppressed because
    /// the surrounding screen is rendering them as native iOS Settings
    /// sections beneath the card via `LightFeatureSections`. Effects stays
    /// inside the card either way — it's a light-specific control, not
    /// configuration.
    var rendersAdvancedSheetsInline: Bool = true

    @State private var selectedSurface: Surface
    @State private var showEffects = false
    @State private var showStartup = false
    @State private var showMore = false

    init(context: LightControlContext,
         mode: CardDisplayMode,
         onSend: @escaping (JSONValue) -> Void = { _ in },
         rendersAdvancedSheetsInline: Bool = true) {
        self.context = context
        self.mode = mode
        self.onSend = onSend
        self.rendersAdvancedSheetsInline = rendersAdvancedSheetsInline
        _selectedSurface = State(initialValue: Self.initialSurface(for: context))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if mode == .snapshot { snapshotContent } else { interactiveContent }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
        .sheet(isPresented: $showEffects) {
            if let effect = context.effectFeature {
                LightEffectsSheet(feature: effect) { onSend(effect.payload($0)) }
            }
        }
        .sheet(isPresented: $showStartup) {
            LightAdvancedSheet(title: "Startup", features: context.startupFeatures, onChange: onSend)
        }
        .sheet(isPresented: $showMore) {
            LightAdvancedSheet(title: "Settings", features: context.otherAdvancedFeatures, onChange: onSend)
        }
    }

    // MARK: – Background

    /// Snapshot mode gets a subtle gradient tinted by the bulb's displayColor
    /// when on — same hero treatment as other cards, since there's no
    /// interactive `LightBrightnessArea` to carry the color.
    /// Interactive mode keeps a clean neutral card so the colored brightness
    /// capsule inside doesn't have to compete with a gradient behind it.
    @ViewBuilder
    private var cardBackground: some View {
        if mode == .snapshot {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [
                        (context.isOn ? context.displayColor : Color(.tertiaryLabel)).opacity(context.isOn ? 0.18 : 0.06),
                        (context.isOn ? context.displayColor : Color(.tertiaryLabel)).opacity(DesignTokens.Opacity.subtleFade)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            Color(.secondarySystemGroupedBackground)
        }
    }

    /// Tint used by the interactive eyebrow and snapshot eyebrow/value. Tracks
    /// the live bulb color when on, fades to neutral when off.
    private var headerTint: Color {
        context.isOn ? context.displayColor : Color(.tertiaryLabel)
    }

    // MARK: – Interactive

    @ViewBuilder private var interactiveContent: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: context.isOn ? "lightbulb.fill" : "lightbulb")
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text(eyebrowLabel)
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            .foregroundStyle(headerTint)
            Spacer()
            if context.effectFeature != nil { configButton("sparkles") { showEffects = true } }
            if rendersAdvancedSheetsInline {
                if !context.startupFeatures.isEmpty { configButton("sunrise.fill") { showStartup = true } }
                if !context.otherAdvancedFeatures.isEmpty { configButton("ellipsis") { showMore = true } }
            }
        }
        if let brightness = context.brightness {
            LightBrightnessArea(
                isOn: context.isOn,
                isInteractive: brightness.isWritable || context.power?.isWritable == true,
                value: context.brightnessValue ?? context.suggestedOnBrightnessValue(),
                range: brightness.range ?? 0...254,
                displayColor: context.displayColor,
                onChange: { value in
                    guard let payload = context.brightnessCommandPayload(value) else { return }
                    onSend(payload)
                },
                onTogglePower: togglePower
            )
        }
        if context.supportsColorControls && context.supportsWhiteControls {
            Picker("Mode", selection: $selectedSurface) {
                ForEach(Surface.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        if selectedSurface == .color, context.supportsColorControls {
            LightColorControl(
                value: context.displayColor,
                isInteractive: context.color?.isWritable ?? false,
                onChange: { color in
                    guard let hex = color.hexString, let payload = context.colorPayload(hex: hex) else { return }
                    onSend(payload)
                }
            )
        }
        if selectedSurface == .white, let ct = context.colorTemperature {
            LightTemperatureControl(
                range: ct.range ?? 153...500,
                value: context.colorTemperatureValue ?? ct.range?.lowerBound ?? 250,
                isInteractive: ct.isWritable,
                onChange: { value in
                    guard let payload = context.colorTemperaturePayload(value) else { return }
                    onSend(payload)
                }
            )
        }
    }

    // MARK: – Snapshot

    @ViewBuilder private var snapshotContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            snapshotHero
            if hasColorOrTempInfo {
                hairline
                colorSnapshotRow
            }
        }
    }

    private var snapshotHero: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: context.isOn ? "lightbulb.fill" : "lightbulb")
                        .font(DesignTokens.Typography.eyebrowIcon)
                        .symbolRenderingMode(.hierarchical)
                    Text(eyebrowLabel)
                        .font(DesignTokens.Typography.eyebrowLabel)
                        .tracking(DesignTokens.Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .lineLimit(1)
                }
                .foregroundStyle(headerTint)

                snapshotHeroValue
            }
            Spacer(minLength: 0)
            stateBadge
        }
    }

    @ViewBuilder
    private var snapshotHeroValue: some View {
        // Snapshot is a frozen view of the payload at log time — never invent
        // a brightness value. State-change diffs (and ON/OFF-only publishes)
        // omit brightness when it didn't change, so brightnessValue is nil;
        // showing brightnessPercent there would fabricate a default (100%).
        if context.isOn, context.brightness != nil, context.brightnessValue != nil {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Text("\(context.brightnessPercent)")
                    .font(DesignTokens.Typography.heroValue)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)
                Text("%")
                    .font(DesignTokens.Typography.heroUnit)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(context.isOn ? "On" : "Off")
                .font(DesignTokens.Typography.heroStateText)
                .foregroundStyle(headerTint)
        }
    }

    private var stateBadge: some View {
        Text(context.isOn ? "ON" : "OFF")
            .font(.caption.weight(.bold))
            .foregroundStyle(context.isOn ? headerTint : Color(.secondaryLabel))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                context.isOn ? headerTint.opacity(DesignTokens.Opacity.chipFill)
                             : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(DesignTokens.Opacity.hairline))
            .frame(height: DesignTokens.Size.hairline)
    }

    private var hasColorOrTempInfo: Bool {
        let isColorMode = context.isColorMode
        return isColorMode || context.colorTemperatureValue != nil
    }

    @ViewBuilder private var colorSnapshotRow: some View {
        let isColorMode = context.isColorMode
        if !isColorMode, let tempMireds = context.colorTemperatureValue {
            snapshotInfoRow(
                icon: "thermometer.medium",
                label: "Color Temperature",
                value: "\(Int(1_000_000 / tempMireds))",
                unit: "K"
            )
        } else if isColorMode {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "paintpalette.fill")
                        .font(DesignTokens.Typography.eyebrowIcon)
                        .symbolRenderingMode(.hierarchical)
                    Text("Color")
                        .font(DesignTokens.Typography.eyebrowLabel)
                        .tracking(DesignTokens.Typography.eyebrowTracking)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func snapshotInfoRow(icon: String, label: String, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                Text(value)
                    .font(DesignTokens.Typography.snapshotRowValue)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(DesignTokens.Typography.snapshotRowUnit)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eyebrowLabel: String {
        if let endpoint = context.endpointLabel { return "Light · \(endpoint)" }
        return "Light"
    }

    // MARK: – Helpers

    private func configButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.sectionHeader)
                .foregroundStyle(.primary)
                .frame(width: DesignTokens.Size.lightControlButton, height: DesignTokens.Size.lightControlButton)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffectIfAvailable(in: Circle())
    }

    private func togglePower() {
        if context.isOn {
            guard let payload = context.powerPayload(isOn: false) else { return }
            onSend(payload)
            return
        }
        guard let payload = context.brightnessCommandPayload(context.suggestedOnBrightnessValue()) else { return }
        onSend(payload)
    }

    private static func initialSurface(for context: LightControlContext) -> Surface {
        if context.supportsColorControls && context.supportsWhiteControls {
            return context.colorMode == "color_temp" ? .white : .color
        }
        return context.supportsWhiteControls ? .white : .color
    }
}


#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = LightControlContext(device: .preview, state: [
                "state": .string("ON"), "brightness": .int(160),
                "color_mode": .string("color_temp"), "color_temp": .int(300)
            ]) {
                LightControlCard(context: ctx, mode: .interactive)
                LightControlCard(context: ctx, mode: .snapshot)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
