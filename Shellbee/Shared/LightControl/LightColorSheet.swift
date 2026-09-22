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

    @Environment(\.dismiss) private var dismiss
    @State private var surface: Surface

    init(context: LightControlContext, onSend: @escaping (JSONValue) -> Void) {
        self.context = context
        self.onSend = onSend
        _surface = State(initialValue: Self.initialSurface(for: context))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if context.supportsColorControls && context.supportsWhiteControls {
                        Picker("Mode", selection: $surface) {
                            ForEach(Surface.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowSeparator(.hidden)
                    }
                    controls
                        .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
            .navigationTitle(surface == .color ? "Color" : "Color Temperature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

    private static func initialSurface(for context: LightControlContext) -> Surface {
        if context.supportsColorControls && context.supportsWhiteControls {
            return context.colorMode == "color_temp" ? .white : .color
        }
        return context.supportsWhiteControls ? .white : .color
    }
}
