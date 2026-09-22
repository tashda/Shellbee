import SwiftUI

/// Dispatches to the correct typed control card based on device.category.
/// Use mode:.interactive in DeviceDetailView and mode:.snapshot in LogDetailView.
struct ExposeCardView: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    var onSend: (JSONValue) -> Void = { _ in }
    /// When false, the generic fallback rows are left out so the caller can
    /// draw them as native List sections (`DeviceSettingsSections`).
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
            // Readings are native List sections (SensorSections), drawn by
            // DeviceDetailView; only the generic rows fit in a card.
            genericRows()
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
            // Remotes are rows only (RemoteSections), drawn by DeviceDetailView.
            genericRows()
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

    /// Properties the typed card shows for lock and remote devices, so the
    /// settings sections beneath skip them.
    static func claimedProperties(device: Device, state: [String: JSONValue]) -> Set<String> {
        let exposes = device.definition?.exposes ?? []
        switch device.category {
        case .lock:
            let lock = exposes.first { $0.type == "lock" }?.features?.flattenedLeaves ?? []
            return Set(lock.compactMap(\.property))
        default:
            return []
        }
    }

    /// Whether the device gets a typed control card, as opposed to only
    /// generic rows.
    static func hasPrimaryCard(device: Device, state: [String: JSONValue]) -> Bool {
        switch device.category {
        case .light: return !LightControlContext.contexts(for: device, state: state).isEmpty
        case .switchPlug: return !SwitchControlContext.contexts(for: device, state: state).isEmpty
        case .sensor: return false
        case .climate: return ClimateControlContext(device: device, state: state) != nil
        case .cover: return !CoverControlContext.contexts(for: device, state: state).isEmpty
        case .lock: return LockControlContext(device: device, state: state) != nil
        case .fan: return FanControlContext(device: device, state: state) != nil
        case .remote: return false
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
