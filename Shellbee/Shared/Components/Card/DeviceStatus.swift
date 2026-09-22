import SwiftUI

/// The one place that decides a device's status wording and colour
/// (Online, Offline, Interviewing, Updating, Untracked). Identity headers,
/// compact rows and any other surface read it from here.
struct DeviceStatus {
    let title: String
    let color: Color
    /// True when the status is worth surfacing on quiet surfaces such as the
    /// compact row, where a healthy "Online" is left out.
    let needsAttention: Bool

    init(device: Device, isAvailable: Bool, otaStatus: OTAUpdateStatus?) {
        if let otaStatus, otaStatus.isActive {
            switch otaStatus.phase {
            case .checking: title = "Checking"
            case .updating: title = "Updating"
            default: title = "Starting"
            }
            color = .blue
            needsAttention = true
        } else if device.isInterviewing {
            title = "Interviewing"
            color = .orange
            needsAttention = true
        } else if !device.availabilityTrackingEnabled {
            title = "Untracked"
            color = .secondary
            needsAttention = false
        } else if isAvailable {
            title = "Online"
            color = .green
            needsAttention = false
        } else {
            title = "Offline"
            color = .red
            needsAttention = true
        }
    }

    /// Short relative last-seen text ("4 min ago"), or nil when unknown.
    static func lastSeenText(_ date: Date?) -> String? {
        guard let date else { return nil }
        let seconds = max(Int(Date().timeIntervalSince(date)), 0)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60) min ago" }
        if seconds < 86_400 { return "\(seconds / 3600) h ago" }
        return "\(seconds / 86_400) d ago"
    }
}

extension Device {
    /// Human description for subtitles: "Philips · Hue White and Colour
    /// Ambiance GU10". Falls back to the model identifier when z2m has no
    /// description.
    var cardSubtitle: String {
        let vendor = definition?.vendor ?? manufacturer
        let detail = definition?.description ?? definition?.model ?? modelId
        return [vendor, detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
