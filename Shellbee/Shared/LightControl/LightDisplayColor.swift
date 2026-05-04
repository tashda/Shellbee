import SwiftUI

enum LightDisplayColor {
    static func resolve(colorValue: JSONValue?, colorTemperature: Double?, colorMode: String?) -> Color {
        // Trust color_mode as the authoritative signal — z2m sets it
        // deliberately to one of "xy", "hs", or "color_temp" to describe
        // what the bulb is actively rendering. A bulb in color_temp mode
        // can also publish a stale color object (notably Hue with
        // hue_native_control), but the true output is the temperature.
        if colorMode == "color_temp", let colorTemperature {
            return temperatureColor(mireds: colorTemperature)
        }

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

        return .accentColor
    }

    /// Convert mireds to a representative RGB color using Tanner Helland's
    /// CCT-to-RGB approximation. The previous implementation kept red pinned
    /// at 1.0 and ramped blue/green linearly — every white above ~5000K
    /// landed as the same peach-pink tint, and warm vs cool whites were
    /// nearly indistinguishable. This produces visually correct shifts:
    /// 2000K → amber, 2700K → tungsten, 4000K → neutral, 5500K → daylight,
    /// 6500K+ → cool blue-white. Clamped to 1000–10000K to keep the
    /// rendering usable for both extreme bulb reports and home-class
    /// lighting.
    static func temperatureColor(mireds: Double) -> Color {
        let kelvin = max(1000, min(10_000, 1_000_000 / max(mireds, 1)))
        let temp = kelvin / 100

        let red: Double
        if temp <= 66 {
            red = 255
        } else {
            let v = 329.698727446 * pow(temp - 60, -0.1332047592)
            red = clamp(v)
        }

        let green: Double
        if temp <= 66 {
            let v = 99.4708025861 * log(max(temp, 1)) - 161.1195681661
            green = clamp(v)
        } else {
            let v = 288.1221695283 * pow(temp - 60, -0.0755148492)
            green = clamp(v)
        }

        let blue: Double
        if temp >= 66 {
            blue = 255
        } else if temp <= 19 {
            blue = 0
        } else {
            let v = 138.5177312231 * log(temp - 10) - 305.0447927307
            blue = clamp(v)
        }

        return Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(255, value))
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
