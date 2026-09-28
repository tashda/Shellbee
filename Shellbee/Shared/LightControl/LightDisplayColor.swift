import SwiftUI

/// The one place Shellbee turns whatever a light reports into the colour it
/// is showing. Devices disagree on format — CIE xy, hue/saturation on
/// several scales, RGB, hex strings, colour temperature in mireds or kelvin
/// — so every surface that draws a light's colour goes through here.
enum LightDisplayColor {
    /// For views that always need a colour; falls back to the accent colour.
    static func resolve(colorValue: JSONValue?, colorTemperature: Double?, colorMode: String?) -> Color {
        resolvedColor(colorValue: colorValue, colorTemperature: colorTemperature, colorMode: colorMode) ?? .accentColor
    }

    /// The colour from a full device state snapshot, or nil when the state
    /// carries no colour information at all.
    static func resolve(state: [String: JSONValue]) -> Color? {
        let temperature = temperatureKeys.lazy.compactMap { state[$0]?.numberValue }.first
        return resolvedColor(
            colorValue: state["color"] ?? state["colour"],
            colorTemperature: temperature,
            colorMode: state["color_mode"]?.stringValue
        )
    }

    /// The colour a single reported property describes: a colour object or
    /// hex string for `color`, a number for colour temperature properties.
    static func color(property: String, value: JSONValue) -> Color? {
        let key = property.lowercased()
        if key.contains("temp") {
            return value.numberValue.map(temperatureColor(whiteValue:))
        }
        return colorObjectColor(value, preferred: nil)
    }

    static func resolvedColor(colorValue: JSONValue?, colorTemperature: Double?, colorMode: String?) -> Color? {
        let mode = colorMode?.lowercased()
        // Trust color_mode as the authoritative signal — z2m sets it
        // deliberately to describe what the bulb is actively rendering. A
        // bulb in color_temp mode can also publish a stale color object
        // (notably Hue with hue_native_control), but the true output is the
        // temperature.
        if mode == "color_temp", let colorTemperature {
            return temperatureColor(whiteValue: colorTemperature)
        }
        if let colorValue, let color = colorObjectColor(colorValue, preferred: mode) {
            return color
        }
        return colorTemperature.map(temperatureColor(whiteValue:))
    }

    /// A plain name for a light colour ("Pink", "Warm White"), for places
    /// where coordinates would mean nothing to a person.
    static func name(for color: Color) -> String {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let degrees = hue * 360
        if saturation < 0.12 { return String(localized: "White") }
        if saturation < 0.45, degrees < 60 { return String(localized: "Warm White") }
        if saturation < 0.3, (180..<260).contains(degrees) { return String(localized: "Cool White") }
        switch degrees {
        case ..<15, 345...: return String(localized: "Red")
        case ..<40: return String(localized: "Orange")
        case ..<68: return String(localized: "Yellow")
        case ..<160: return String(localized: "Green")
        case ..<195: return String(localized: "Cyan")
        case ..<250: return String(localized: "Blue")
        case ..<285: return String(localized: "Purple")
        default: return String(localized: "Pink")
        }
    }

    // MARK: - Colour formats

    private static let temperatureKeys = ["color_temp", "color_temperature", "colour_temp", "color_temp_kelvin"]

    /// Reads any colour object shape. `preferred` ("xy" or "hs") picks which
    /// representation wins when a device reports several at once.
    private static func colorObjectColor(_ value: JSONValue, preferred mode: String?) -> Color? {
        if let hex = value.stringValue { return hexColor(hex) }
        guard let color = value.object else { return nil }

        let readers: [([String: JSONValue]) -> Color?] = mode == "hs"
            ? [hueSaturationColor, { xyColor($0) }, rgbColor, hexField]
            : [{ xyColor($0) }, hueSaturationColor, rgbColor, hexField]
        return readers.lazy.compactMap { $0(color) }.first
    }

    private static func xyColor(_ color: [String: JSONValue]) -> Color? {
        guard let x = color["x"]?.numberValue, let y = color["y"]?.numberValue else { return nil }
        return xyColor(x: x, y: y)
    }

    /// Hue arrives as degrees (0–360) or as Zigbee's enhanced hue (0–65535);
    /// saturation as a percentage, a Zigbee byte (0–254) or Tuya's 0–1000.
    /// A device that reports hue alone is shown fully saturated.
    private static func hueSaturationColor(_ color: [String: JSONValue]) -> Color? {
        guard let rawHue = color["hue"]?.numberValue ?? color["h"]?.numberValue else { return nil }
        let hue = rawHue > 360 ? rawHue / 65_535 : rawHue / 360
        let rawSaturation = color["saturation"]?.numberValue ?? color["s"]?.numberValue ?? 100
        let saturation: Double
        switch rawSaturation {
        case ...100: saturation = rawSaturation / 100
        case ...254: saturation = rawSaturation / 254
        default: saturation = rawSaturation / 1_000
        }
        return Color(hue: min(max(hue, 0), 1), saturation: min(max(saturation, 0), 1), brightness: 1)
    }

    /// RGB as bytes (0–255) or, when every channel is at most 1, fractions.
    private static func rgbColor(_ color: [String: JSONValue]) -> Color? {
        guard let red = color["r"]?.numberValue ?? color["red"]?.numberValue,
              let green = color["g"]?.numberValue ?? color["green"]?.numberValue,
              let blue = color["b"]?.numberValue ?? color["blue"]?.numberValue else { return nil }
        let scale = max(red, green, blue) <= 1 ? 1.0 : 255.0
        return Color(red: red / scale, green: green / scale, blue: blue / scale)
    }

    private static func hexField(_ color: [String: JSONValue]) -> Color? {
        (color["hex"]?.stringValue).flatMap(hexColor)
    }

    /// "#6874ff", "6874FF" or the short "#67f".
    private static func hexColor(_ string: String) -> Color? {
        var hex = string.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else { return nil }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// Colour temperature arrives in mireds (Z2M's `color_temp`, 150–500)
    /// or, from some devices, in kelvin (2000–6500). Anything above 1000
    /// can only be kelvin.
    static func temperatureColor(whiteValue: Double) -> Color {
        temperatureColor(mireds: whiteValue > 1_000 ? 1_000_000 / whiteValue : whiteValue)
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

    private static func xyColor(x: Double, y: Double) -> Color? {
        guard y > 0 else { return nil }

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
