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

    @State private var selectedSurface: Surface
    @State private var showEffects = false
    @State private var showStartup = false
    @State private var showMore = false

    init(context: LightControlContext, mode: CardDisplayMode, onSend: @escaping (JSONValue) -> Void = { _ in }) {
        self.context = context
        self.mode = mode
        self.onSend = onSend
        _selectedSurface = State(initialValue: Self.initialSurface(for: context))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if mode == .snapshot { snapshotContent } else { interactiveContent }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
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

    // MARK: – Interactive

    @ViewBuilder private var interactiveContent: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text("Light").font(.headline)
            Spacer()
            if context.effectFeature != nil { configButton("sparkles") { showEffects = true } }
            if !context.startupFeatures.isEmpty { configButton("sunrise.fill") { showStartup = true } }
            if !context.otherAdvancedFeatures.isEmpty { configButton("ellipsis") { showMore = true } }
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
        snapshotHeader
        if context.brightness != nil { brightnessSnapshotRow }
        colorSnapshotRow
    }

    private var snapshotHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(context.isOn ? context.displayColor : Color(.tertiaryLabel))
            Text("Light State").font(.headline)
            Spacer()
            stateBadge
        }
    }

    private var stateBadge: some View {
        Text(context.isOn ? "ON" : "OFF")
            .font(.caption.weight(.bold))
            .foregroundStyle(context.isOn ? Color.green : Color(.secondaryLabel))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                context.isOn ? Color.green.opacity(DesignTokens.Opacity.chipFill) : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }

    @ViewBuilder private var brightnessSnapshotRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("Brightness").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(context.brightnessPercent)%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill)).frame(height: 6)
                    Capsule()
                        .fill(context.isOn ? AnyShapeStyle(context.displayColor.gradient) : AnyShapeStyle(Color(.systemFill).gradient))
                        .frame(width: max(6, geo.size.width * CGFloat(context.brightnessPercent) / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder private var colorSnapshotRow: some View {
        let isColorMode = context.colorMode == "color_xy" || context.colorMode == "color_hs"
        if !isColorMode, let tempMireds = context.colorTemperatureValue {
            HStack {
                Text("Color Temperature").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(1_000_000 / tempMireds))K").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Circle().fill(context.displayColor).frame(width: 12, height: 12)
            }
        } else if isColorMode {
            HStack {
                Text("Color").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Circle().fill(context.displayColor).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.separator, lineWidth: DesignTokens.Size.badgeStroke))
            }
        }
    }

    // MARK: – Helpers

    private func configButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
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
