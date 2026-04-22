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

    var batteryColor: Color {
        if self < DesignTokens.Threshold.lowBattery { return .red }
        if self < 50 { return .orange }
        return .green
    }

    var lqiSymbol: String {
        self < DesignTokens.Threshold.weakSignal ? "wifi.exclamationmark" : "wifi"
    }

    var lqiColor: Color {
        if self == 0 { return .secondary }
        if self < DesignTokens.Threshold.weakSignal { return .red }
        if self < 80 { return .orange }
        if self < 150 { return .blue }
        return .green
    }
}
