import SwiftUI

/// Settings exposes as native List sections, grouped the same way on every
/// device: Controls, Behaviour, Indicators, Maintenance, Status, More, then
/// Diagnostics. Every row is a `SettingsFormRow`. Place inside an
/// inset-grouped `List`.
struct FeatureSectionsList: View {
    let exposes: [Expose]
    let state: [String: JSONValue]
    let onSend: (JSONValue) -> Void

    var body: some View {
        ForEach(FeatureLayout.sections(from: exposes)) { section in
            Section(section.title) {
                ForEach(section.items, id: \.id) { item in
                    DeviceFeatureSectionRow(item: item, state: state, mode: .interactive, onSend: onSend)
                }
            }
        }
    }
}

/// Every setting a device exposes that its typed card doesn't already show.
/// Used beneath Lock and Remote, beside sensor readings, and for devices
/// with no typed card at all.
struct DeviceSettingsSections: View {
    let device: Device
    let state: [String: JSONValue]
    var claimedProperties: Set<String> = []
    let onSend: (JSONValue) -> Void

    var body: some View {
        FeatureSectionsList(
            exposes: Self.exposes(for: device, claimedProperties: claimedProperties),
            state: state,
            onSend: onSend
        )
    }

    /// The exposes shown, after removing what the typed card or readings
    /// already show. Writable config always survives (issue #135).
    static func exposes(for device: Device, claimedProperties: Set<String>) -> [Expose] {
        DeviceExtras.eligibleLeaves(
            from: (device.definition?.exposes ?? []).flattenedLeaves,
            primaryProps: claimedProperties
        )
    }
}
