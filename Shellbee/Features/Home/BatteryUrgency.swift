import Foundation

/// What to do about a battery, for the Batteries page's sections and
/// filter chips. "Replace now" uses the same threshold as Needs attention's
/// Low battery row, so the two always agree.
enum BatteryUrgency: String, CaseIterable, Identifiable {
    case replaceNow
    case silent
    case soon
    case fine

    /// Batteries below this, but not yet low, are next in line. Shared with
    /// the battery colours so a Soon battery is always drawn in the fair colour.
    static let soonBelow = DesignTokens.Threshold.fairBattery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replaceNow: "Replace now"
        case .silent: "Silent"
        case .soon: "Soon"
        case .fine: "OK"
        }
    }

    var footnote: String {
        switch self {
        case .replaceNow: "Below \(DesignTokens.Threshold.lowBattery) %"
        case .silent: "No report in 3 days, often a flat battery"
        case .soon: "\(DesignTokens.Threshold.lowBattery)–\(Self.soonBelow) %"
        case .fine: "\(Self.soonBelow) % and above"
        }
    }
}

extension HomeDeviceReading {
    /// `nil` for devices that don't report a battery.
    var batteryUrgency: BatteryUrgency? {
        guard let battery else { return nil }
        if DesignTokens.Threshold.isLowBattery(battery) { return .replaceNow }
        if isSilent { return .silent }
        if battery < BatteryUrgency.soonBelow { return .soon }
        return .fine
    }
}
