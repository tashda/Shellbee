import SwiftUI

struct LightControlCard: View {
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

    @State private var showColor = false
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
    }

    var body: some View {
        // Snapshot bypasses the interactive-mode chrome (gradient tint,
        // large padding, drop shadow) — those exist for the controls
        // surface. Snapshot lives in a log row and uses the shared
        // CompactSnapshotCard chrome so it lines up with every other
        // card type at the same scale.
        modeSwitchedBody
        .sheet(isPresented: $showColor) {
            LightColorSheet(context: context, onSend: onSend)
        }
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

    @ViewBuilder
    private var modeSwitchedBody: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                interactiveContent
            }
            .cardSurface()
        }
    }

    /// Symbol tint. Tracks the live bulb colour when on, neutral when off.
    private var headerTint: Color {
        context.isOn ? context.displayColor : Color(.tertiaryLabel)
    }

    // MARK: – Interactive

    @ViewBuilder private var interactiveContent: some View {
        CardHeader(
            systemImage: context.isOn ? "lightbulb.fill" : "lightbulb",
            title: eyebrowLabel,
            value: headerValue,
            tint: headerTint
        ) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if hasColorControls {
                    colorButton
                }
                if context.effectFeature != nil {
                    CardAccessoryButton(systemImage: "sparkles", accessibilityLabel: "Effects") { showEffects = true }
                }
                if rendersAdvancedSheetsInline {
                    if !context.startupFeatures.isEmpty {
                        CardAccessoryButton(systemImage: "sunrise.fill", accessibilityLabel: "Startup") { showStartup = true }
                    }
                    if !context.otherAdvancedFeatures.isEmpty {
                        CardAccessoryButton(systemImage: "ellipsis", accessibilityLabel: "Settings") { showMore = true }
                    }
                }
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
    }

    private var hasColorControls: Bool {
        context.supportsColorControls || context.colorTemperature != nil
    }

    /// The light's current colour as a swatch; opens the Color sheet.
    private var colorButton: some View {
        Button { showColor = true } label: {
            Circle()
                .fill(context.displayColor)
                .overlay(Circle().strokeBorder(Color.primary.opacity(DesignTokens.Opacity.hairline)))
                .frame(width: DesignTokens.Size.changeSwatch, height: DesignTokens.Size.changeSwatch)
                .frame(width: DesignTokens.Size.cardAccessoryButton, height: DesignTokens.Size.cardAccessoryButton)
        }
        .buttonBorderShape(.circle)
        .glassButtonStyleIfAvailable()
        .accessibilityLabel("Color")
        .accessibilityValue(colorDescription ?? "")
    }

    // MARK: – Snapshot

    /// Compact log-row rendering. Single-row card with bulb icon, name +
    /// summary value (brightness / on/off / color temp), and trailing
    /// ON/OFF pill. Same scale as DeviceCard.compact so a stack of mixed
    /// cards in the log detail reads as a uniform list.
    @ViewBuilder private var snapshotContent: some View {
        CompactSnapshotCard {
            CompactControlSnapshotRow(
                systemImage: context.isOn ? "lightbulb.fill" : "lightbulb",
                title: eyebrowLabel,
                subtitle: snapshotSecondaryText,
                tint: headerTint
            ) {
                stateBadge
            }
        }
    }

    /// "80% · 2700 K" / "80%" / "2700 K" / nil. Only emits text when the
    /// payload actually carries a brightness or color value — log entries
    /// often don't (state-change diff omits unchanged fields). Returning
    /// nil collapses the row to a single line.
    private var snapshotSecondaryText: String? {
        var parts: [String] = []
        if context.isOn, context.brightness != nil, context.brightnessValue != nil {
            parts.append("\(context.brightnessPercent)%")
        }
        if !context.isColorMode, let mireds = context.colorTemperatureValue {
            parts.append("\(Int(1_000_000 / mireds)) K")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Off", "Pink" or "Warm white" beside the title. Brightness is
    /// left to the capsule, which already shows it.
    private var headerValue: String {
        guard context.isOn else { return "Off" }
        return colorDescription ?? "On"
    }

    private var colorDescription: String? {
        if context.isColorMode, context.supportsColorControls {
            return LightDisplayColor.name(for: context.displayColor)
        }
        guard let mireds = context.colorTemperatureValue, mireds > 0 else { return nil }
        let kelvin = 1_000_000 / mireds
        if kelvin < 3000 { return String(localized: "Warm white") }
        if kelvin < 4500 { return String(localized: "Neutral white") }
        return String(localized: "Cool white")
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

    private var eyebrowLabel: String {
        if let endpoint = context.endpointLabel { return "Light · \(endpoint)" }
        return "Light"
    }

    // MARK: – Helpers

    private func togglePower() {
        if context.isOn {
            guard let payload = context.powerPayload(isOn: false) else { return }
            onSend(payload)
            return
        }
        guard let payload = context.brightnessCommandPayload(context.suggestedOnBrightnessValue()) else { return }
        onSend(payload)
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
