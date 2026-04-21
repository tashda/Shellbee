import SwiftUI
import UIKit

extension Color {
    init?(hex: String) {
        let r, g, b: Double
        let start = hex.hasPrefix("#") ? hex.index(after: hex.startIndex) : hex.startIndex
        let hexColor = String(hex[start...])
        guard hexColor.count == 6 else { return nil }
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        r = Double((hexNumber & 0xff0000) >> 16) / 255
        g = Double((hexNumber & 0x00ff00) >> 8) / 255
        b = Double(hexNumber & 0x0000ff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    var hexString: String? {
        let components = UIColor(self).cgColor.components
        let resolved: [CGFloat]

        switch components?.count {
        case 2:
            resolved = [components?[0] ?? 0, components?[0] ?? 0, components?[0] ?? 0]
        case 4:
            resolved = [components?[0] ?? 0, components?[1] ?? 0, components?[2] ?? 0]
        default:
            return nil
        }

        let red = Int((resolved[0] * 255).rounded())
        let green = Int((resolved[1] * 255).rounded())
        let blue = Int((resolved[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
