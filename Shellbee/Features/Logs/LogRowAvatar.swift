import SwiftUI

/// Leading-visual avatar for a log row. Used by every place that lists
/// log entries (Activity Log row, Home "Recent Events" card) so the
/// iconography stays unified — change `LogRowIconography` once and every
/// call site updates.
///
/// `size` controls the diameter; the row decides what fits its layout.
/// The activity log uses ~38pt; the home card uses ~32pt.
struct LogRowAvatar: View {
    @Environment(AppEnvironment.self) private var environment
    let entry: LogEntry
    var store: AppStore? = nil
    var size: CGFloat = 38

    var body: some View {
        let visual = LogRowIconography.visual(for: entry, store: resolvedStore)
        switch visual {
        case .deviceThumbnail(let device):
            DeviceImageView(device: device, isAvailable: true, size: size)
                .frame(width: size, height: size)
        case .groupThumbnail(_, let members):
            GroupIconView(memberDevices: Array(members.prefix(2)), size: size)
                .frame(width: size, height: size)
        case .symbol(let name, let tint):
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: name)
                        .font(.system(size: size * 0.46, weight: .semibold))
                        .foregroundStyle(tint)
                }
        }
    }

    /// When the caller doesn't pass a store, scan connected bridges for
    /// a session that knows the device/group by name. Single-bridge
    /// installs always satisfy this; multi-bridge callers should pass an
    /// explicit store so a name collision routes correctly.
    private var resolvedStore: AppStore? {
        if let store { return store }
        let candidate: String?
        if let ctx = entry.context, !ctx.devices.isEmpty {
            candidate = ctx.devices.first?.friendlyName
        } else if let n = entry.deviceName {
            candidate = n
        } else if case .mqttPublish(let d, _, _) = entry.parsedMessageKind {
            candidate = d
        } else {
            candidate = nil
        }
        guard let name = candidate else { return nil }
        for session in environment.registry.orderedSessions {
            if session.store.device(named: name) != nil || session.store.group(named: name) != nil {
                return session.store
            }
        }
        return nil
    }
}
