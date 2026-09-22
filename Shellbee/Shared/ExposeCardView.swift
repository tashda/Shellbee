import SwiftUI

/// Dispatches to the correct typed control card based on device.category.
/// Use mode:.interactive in DeviceDetailView and mode:.snapshot in LogDetailView.
struct ExposeCardView: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    var onSend: (JSONValue) -> Void = { _ in }
    /// When false, the generic fallback rows are left out so the caller can
    /// draw them as native List sections (`GenericExposeSections`).
    var includesGenericRows: Bool = true

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
                genericRows()
            } else {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(switchContexts) { ctx in
                        SwitchControlCard(context: ctx, mode: mode, onSend: onSend)
                    }
                }
            }
        case .sensor:
            let hasReadings = SensorCard.hasReadings(device: device, state: state)
            let hasWritableExtras = GenericExposeCard.hasWritableRows(device: device, state: state)
            if hasReadings && hasWritableExtras {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    SensorCard(device: device, state: state, mode: mode)
                    genericRows(writableOnly: true)
                }
            } else if hasReadings {
                SensorCard(device: device, state: state, mode: mode)
            } else {
                genericRows()
            }
        case .climate:
            if let ctx = ClimateControlContext(device: device, state: state) {
                ClimateControlCard(context: ctx, mode: mode, onSend: onSend)
            } else {
                genericRows()
            }
        case .cover:
            let coverContexts = CoverControlContext.contexts(for: device, state: state)
            if coverContexts.isEmpty {
                genericRows()
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
                genericRows()
            }
        case .fan:
            if let ctx = FanControlContext(device: device, state: state) {
                FanControlCard(context: ctx, mode: mode, onSend: onSend)
            } else {
                genericRows()
            }
        case .remote:
            RemoteCard(device: device, state: state, mode: mode)
        case .other:
            genericRows()
        }
    }

    @ViewBuilder
    private func genericRows(writableOnly: Bool = false) -> some View {
        if includesGenericRows {
            GenericExposeCard(device: device, state: state, mode: mode, onSend: onSend, writableOnly: writableOnly)
        }
    }

    /// Whether the device gets a typed control card, as opposed to only
    /// generic rows.
    static func hasPrimaryCard(device: Device, state: [String: JSONValue]) -> Bool {
        switch device.category {
        case .light: return !LightControlContext.contexts(for: device, state: state).isEmpty
        case .switchPlug: return !SwitchControlContext.contexts(for: device, state: state).isEmpty
        case .sensor: return SensorCard.hasReadings(device: device, state: state)
        case .climate: return ClimateControlContext(device: device, state: state) != nil
        case .cover: return !CoverControlContext.contexts(for: device, state: state).isEmpty
        case .lock: return LockControlContext(device: device, state: state) != nil
        case .fan: return FanControlContext(device: device, state: state) != nil
        case .remote: return true
        case .other: return false
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
