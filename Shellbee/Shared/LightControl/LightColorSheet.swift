import SwiftUI

/// Colour and white-temperature controls for a light, opened from the swatch
/// in the Light card header so the card itself stays a header and a capsule.
struct LightColorSheet: View {
    enum Surface: String, CaseIterable, Identifiable {
        case color = "Color"
        case white = "White"
        var id: String { rawValue }
    }

    let context: LightControlContext
    let onSend: (JSONValue) -> Void

    @State private var surface: Surface
    @State private var contentHeight: CGFloat = 0

    init(context: LightControlContext, onSend: @escaping (JSONValue) -> Void) {
        self.context = context
        self.onSend = onSend
        _surface = State(initialValue: Self.initialSurface(for: context))
    }

    var body: some View {
        // The sheet is the card: its controls sit straight on the sheet,
        // with no title or inset section, and it's only as tall as they are.
        VStack(spacing: DesignTokens.Spacing.lg) {
            if context.supportsColorControls && context.supportsWhiteControls {
                Picker("Mode", selection: $surface) {
                    ForEach(Surface.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            controls
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.top, DesignTokens.Spacing.xxl)
        .padding(.bottom, DesignTokens.Spacing.lg)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.visible)
        .configuredTopScrollEdgeEffect()
    }

    @ViewBuilder
    private var controls: some View {
        if surface == .color, context.supportsColorControls {
            LightColorControl(
                value: context.displayColor,
                isInteractive: context.color?.isWritable ?? false,
                showsSelection: context.isOn && context.isColorMode,
                onChange: { color in
                    guard let hex = color.hexString, let payload = context.colorPayload(hex: hex) else { return }
                    onSend(payload)
                }
            )
        } else if let ct = context.colorTemperature {
            LightTemperatureControl(
                range: context.colorTemperatureRange,
                value: context.colorTemperatureValue ?? context.colorTemperatureRange.lowerBound,
                isInteractive: ct.isWritable,
                onChange: { value in
                    guard let payload = context.colorTemperaturePayload(value) else { return }
                    onSend(payload)
                }
            )
        }
    }

    private static func initialSurface(for context: LightControlContext) -> Surface {
        if context.supportsColorControls && context.supportsWhiteControls {
            return context.colorMode == "color_temp" ? .white : .color
        }
        return context.supportsWhiteControls ? .white : .color
    }
}
