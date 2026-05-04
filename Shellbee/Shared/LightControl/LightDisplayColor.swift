import SwiftUI

enum LightDisplayColor {
    static func resolve(colorValue: JSONValue?, colorTemperature: Double?, colorMode: String?) -> Color {
        // If the payload carries a real color object (xy / hs / rgb), prefer
        // it over color_mode-derived hints. Hue lights with hue_native_control
        // enabled publish color_mode="color_temp" alongside a fresh color
        // payload during color changes; trusting the mode signal there
        // renders a peach-tinted card while the bulb is actually rendering
        // green. Color-only lights without color_temp obviously also belong
        // here, regardless of any stale color_mode value.
        if let color = colorValue?.object {
            if let x = color["x"]?.numberValue, let y = color["y"]?.numberValue {
                return xyColor(x: x, y: y)
            }

            let hue = color["hue"]?.numberValue ?? color["h"]?.numberValue
            let saturation = color["saturation"]?.numberValue ?? color["s"]?.numberValue
            if let hue, let saturation {
                return Color(hue: hue / 360.0, saturation: saturation / 100.0, brightness: 1)
            }

            if let r = color["r"]?.numberValue, let g = color["g"]?.numberValue, let b = color["b"]?.numberValue {
                return Color(red: r / 255.0, green: g / 255.0, blue: b / 255.0)
            }
        }

        if let colorTemperature {
            return temperatureColor(mireds: colorTemperature)
        }

        // colorMode is currently unused — the color object check above is the
        // dominant signal and the temperature fallback covers the rest.
        // Keep the parameter so callers stay symmetric with z2m's payload
        // shape if we need to gate on it again later.
        _ = colorMode

        return .accentColor
    }

    static func temperatureColor(mireds: Double) -> Color {
        let kelvin = max(1000, min(6500, 1_000_000 / max(mireds, 1)))
        let normalized = (kelvin - 1000) / 5500
        return Color(
            red: 1.0,
            green: 0.56 + (0.32 * normalized),
            blue: 0.24 + (0.76 * normalized)
        )
    }

    private static func xyColor(x: Double, y: Double) -> Color {
        guard y > 0 else { return .accentColor }

        let z = max(0, 1 - x - y)
        let luminance = 1.0
        let X = (luminance / y) * x
        let Z = (luminance / y) * z

        var red = (X * 1.656492) - (luminance * 0.354851) - (Z * 0.255038)
        var green = (-X * 0.707196) + (luminance * 1.655397) + (Z * 0.036152)
        var blue = (X * 0.051713) - (luminance * 0.121364) + (Z * 1.01153)

        red = gammaCorrect(red)
        green = gammaCorrect(green)
        blue = gammaCorrect(blue)

        let maxComponent = max(red, green, blue, 1)
        return Color(
            red: max(0, min(1, red / maxComponent)),
            green: max(0, min(1, green / maxComponent)),
            blue: max(0, min(1, blue / maxComponent))
        )
    }

    private static func gammaCorrect(_ value: Double) -> Double {
        let clamped = max(0, value)
        if clamped <= 0.0031308 {
            return 12.92 * clamped
        }

        return (1.055 * pow(clamped, 1 / 2.4)) - 0.055
    }
}
