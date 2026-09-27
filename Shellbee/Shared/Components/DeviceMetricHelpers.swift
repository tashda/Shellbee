import SwiftUI

extension Int {
    var batterySymbol: String {
        switch self {
        case 0..<15:  return "battery.0"
        case 15..<40: return "battery.25"
        case 40..<65: return "battery.50"
        case 65..<85: return "battery.75"
        default:      return "battery.100"
        }
    }

    var batteryTone: StatusTone {
        if DesignTokens.Threshold.isLowBattery(self) { return .poor }
        if self < 50 { return .fair }
        return .excellent
    }

    var lqiSymbol: String {
        self < DesignTokens.Threshold.weakSignal ? "wifi.exclamationmark" : "wifi"
    }

    /// `nil` for an LQI of 0, which z2m reports before it has measured one.
    var lqiTone: StatusTone? {
        if self == 0 { return nil }
        if self < DesignTokens.Threshold.weakSignal { return .poor }
        if self < 80 { return .fair }
        if self < 150 { return .good }
        return .excellent
    }
}
