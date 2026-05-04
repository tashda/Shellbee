import Foundation

enum DeviceAvailabilityStatus: Sendable, Equatable {
    case online
    case offline
    case untracked

    var isAvailable: Bool {
        self != .offline
    }
}

enum DeviceCondition: String, CaseIterable, Sendable {
    case updatesAvailable = "Updates Available"
    case online           = "Online"
    case offline          = "Offline"
    case availabilityOff  = "Untracked"
    case batteryLow       = "Low Battery"
    case weakSignal       = "Bad Signal"
    case interviewing     = "Interviewing"
    case unsupported      = "Unsupported"

    var systemImage: String {
        switch self {
        case .updatesAvailable: return "arrow.down.circle"
        case .online:           return "wifi"
        case .offline:          return "wifi.slash"
        case .availabilityOff:  return "minus.circle"
        case .batteryLow:       return "battery.25"
        case .weakSignal:       return "wifi.exclamationmark"
        case .interviewing:     return "waveform.path.ecg"
        case .unsupported:      return "exclamationmark.triangle"
        }
    }

    func matches(
        device: Device,
        state: [String: JSONValue],
        availabilityStatus: DeviceAvailabilityStatus,
        otaStatus: OTAUpdateStatus? = nil
    ) -> Bool {
        switch self {
        case .updatesAvailable:
            if state.hasUpdateAvailable || state.isUpdating { return true }
            switch otaStatus?.phase {
            case .scheduled, .requested, .updating: return true
            default: return false
            }
        case .online:           return availabilityStatus == .online
        case .offline:          return availabilityStatus == .offline
        case .availabilityOff:  return availabilityStatus == .untracked
        case .batteryLow:       return (state.battery ?? 100) < DesignTokens.Threshold.lowBattery
        case .weakSignal:       return (state.linkQuality ?? 999) < DesignTokens.Threshold.weakSignal
        case .interviewing:     return device.isInterviewing
        case .unsupported:      return !device.supported
        }
    }

    func matches(device: Device, state: [String: JSONValue], isAvailable: Bool, otaStatus: OTAUpdateStatus? = nil) -> Bool {
        matches(
            device: device,
            state: state,
            availabilityStatus: isAvailable ? .online : .offline,
            otaStatus: otaStatus
        )
    }
}
