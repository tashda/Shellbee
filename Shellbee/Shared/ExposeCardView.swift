import SwiftUI

/// Dispatches to the correct typed control card based on device.category.
/// Use mode:.interactive in DeviceDetailView and mode:.snapshot in LogDetailView.
struct ExposeCardView: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    var onSend: (JSONValue) -> Void = { _ in }

    var body: some View {
        switch device.category {
        case .light:
            let lightContexts = LightControlContext.contexts(for: device, state: state)
            if !lightContexts.isEmpty {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(lightContexts) { ctx in
                        LightControlCard(context: ctx, mode: mode, onSend: onSend)
                    }
                }
            }
        case .switchPlug:
            let switchContexts = SwitchControlContext.contexts(for: device, state: state)
            if switchContexts.isEmpty {
                GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend)
            } else {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(switchContexts) { ctx in
                        SwitchControlCard(context: ctx, mode: mode, onSend: onSend)
                    }
                }
            }
        case .sensor:
            if SensorCard.hasReadings(device: device, state: state) {
                SensorCard(device: device, state: state, mode: mode)
            } else {
                GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend)
            }
        case .climate:
            if let ctx = ClimateControlContext(device: device, state: state) {
                ClimateControlCard(context: ctx, mode: mode, onSend: onSend)
            } else {
                GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend)
            }
        case .cover:
            let coverContexts = CoverControlContext.contexts(for: device, state: state)
            if coverContexts.isEmpty {
                GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend)
            } else {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(coverContexts) { ctx in
                        CoverControlCard(context: ctx, mode: mode, onSend: onSend)
                    }
                }
            }
        case .lock:
            if let ctx = LockControlContext(device: device, state: state) {
                LockControlCard(context: ctx, mode: mode, onSend: onSend)
            } else {
                GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend)
            }
        case .fan:
            if let ctx = FanControlContext(device: device, state: state) {
                FanControlCard(context: ctx, mode: mode, onSend: onSend)
            } else {
                GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend)
            }
        case .remote:
            RemoteCard(device: device, state: state, mode: mode)
        case .other:
            GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ExposeCardView(device: .preview, state: [
                "state": .string("ON"), "brightness": .int(160),
                "color_mode": .string("color_temp"), "color_temp": .int(300)
            ], mode: .interactive)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
