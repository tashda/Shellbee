import SwiftUI

/// Universal catalog for Z2M expose properties — beautiful display labels,
/// SF Symbol + tint, and a semantic category. Used by every device card so
/// naming and iconography stay consistent across Fan / Light / Cover / etc.
///
/// When `meta(for:)` doesn't have a curated entry, the smart fallback splits
/// camelCase / snake_case, preserves common acronyms (LED, PM2.5, CO₂, Wi-Fi,
/// Hz, dB, QoS), and applies British spelling (behaviour, colour, centre).
///
/// Adding entries: keep alphabetical within section, prefer concrete device
/// terminology over Z2M's wire names ("Power-On Behaviour" not "Power On Behavior").

enum FeatureCategory: Hashable, CaseIterable {
    /// Primary actuators: power, mode, speed, brightness, position.
    case operation
    /// Live readings: PM2.5, temperature, power draw.
    case sensor
    /// Filter / calibration / device wear.
    case maintenance
    /// Power-on, defaults, ramp rates, dim curves — knobs that shape behaviour.
    case behaviour
    /// LEDs, child lock, buzzer — physical feedback affordances.
    case indicator
    /// Battery / link quality / last seen — usually hosted on the device header.
    case diagnostic
    /// Long-tail config that doesn't fit anywhere else.
    case advanced
}

struct FeatureMeta: Equatable {
    let label: String
    let symbol: String
    let tint: Color
    let category: FeatureCategory
}

enum FeatureCatalog {
    /// Look up display metadata for a Z2M expose property.
    /// `exposeType` is used only by the smart fallback when no curated entry exists.
    static func meta(for property: String, exposeType: String = "") -> FeatureMeta {
        if let m = curated[property] { return m }
        return fallback(property: property, exposeType: exposeType)
    }

    /// Convenience for callers that only need a label.
    static func label(for property: String) -> String {
        meta(for: property).label
    }

    // MARK: - Curated entries

    private static let curated: [String: FeatureMeta] = [
        // --- Operation ---
        "fan_mode":          .init(label: "Fan Mode", symbol: "slider.horizontal.3", tint: .indigo, category: .operation),
        "mode":              .init(label: "Mode", symbol: "slider.horizontal.3", tint: .indigo, category: .operation),
        "fan_speed":         .init(label: "Fan Speed", symbol: "wind", tint: .blue, category: .operation),
        "fan_speed_percent": .init(label: "Fan Speed", symbol: "wind", tint: .blue, category: .operation),
        "speed":             .init(label: "Speed", symbol: "wind", tint: .blue, category: .operation),
        "percentage":        .init(label: "Speed", symbol: "wind", tint: .blue, category: .operation),
        "preset":            .init(label: "Preset", symbol: "slider.horizontal.3", tint: .indigo, category: .operation),
        "fan_state":         .init(label: "Fan State", symbol: "wind", tint: .teal, category: .operation),
        "oscillation":       .init(label: "Oscillation", symbol: "arrow.left.and.right", tint: .indigo, category: .operation),
        "swing":             .init(label: "Swing", symbol: "arrow.left.and.right", tint: .indigo, category: .operation),
        "angle":             .init(label: "Angle", symbol: "arrow.left.and.right", tint: .indigo, category: .operation),
        "brightness":        .init(label: "Brightness", symbol: "sun.max.fill", tint: .orange, category: .operation),
        "color_temp":        .init(label: "Colour Temperature", symbol: "thermometer.sun.fill", tint: .orange, category: .operation),

        // --- Sensors: air ---
        "pm1":               .init(label: "PM1", symbol: "aqi.medium", tint: .green, category: .sensor),
        "pm10":              .init(label: "PM10", symbol: "aqi.medium", tint: .green, category: .sensor),
        "pm25":              .init(label: "PM2.5", symbol: "aqi.medium", tint: .green, category: .sensor),
        "air_quality":       .init(label: "Air Quality", symbol: "leaf.fill", tint: .green, category: .sensor),
        "co2":               .init(label: "CO₂", symbol: "carbon.dioxide.cloud.fill", tint: .gray, category: .sensor),
        "voc":               .init(label: "VOC", symbol: "wind", tint: .mint, category: .sensor),
        "tvoc":              .init(label: "TVOC", symbol: "wind", tint: .mint, category: .sensor),
        "voc_index":         .init(label: "VOC Index", symbol: "wind", tint: .mint, category: .sensor),
        "formaldehyd":       .init(label: "Formaldehyde", symbol: "drop.fill", tint: .cyan, category: .sensor),
        "formaldehyde":      .init(label: "Formaldehyde", symbol: "drop.fill", tint: .cyan, category: .sensor),
        "hcho":              .init(label: "Formaldehyde", symbol: "drop.fill", tint: .cyan, category: .sensor),

        // --- Sensors: climate ---
        "temperature":       .init(label: "Temperature", symbol: "thermometer.medium", tint: .red, category: .sensor),
        "local_temperature": .init(label: "Temperature", symbol: "thermometer.medium", tint: .red, category: .sensor),
        "humidity":          .init(label: "Humidity", symbol: "humidity.fill", tint: .cyan, category: .sensor),
        "pressure":          .init(label: "Pressure", symbol: "barometer", tint: .indigo, category: .sensor),
        "illuminance":       .init(label: "Illuminance", symbol: "sun.max.fill", tint: .yellow, category: .sensor),
        "illuminance_lux":   .init(label: "Illuminance", symbol: "sun.max.fill", tint: .yellow, category: .sensor),

        // --- Sensors: power ---
        "power":             .init(label: "Power", symbol: "bolt.fill", tint: .yellow, category: .sensor),
        "energy":            .init(label: "Energy", symbol: "bolt.fill", tint: .orange, category: .sensor),
        "voltage":           .init(label: "Voltage", symbol: "bolt.fill", tint: .yellow, category: .sensor),
        "current":           .init(label: "Current", symbol: "bolt.fill", tint: .orange, category: .sensor),
        "power_factor":      .init(label: "Power Factor", symbol: "function", tint: .gray, category: .sensor),
        "frequency":         .init(label: "Frequency", symbol: "waveform", tint: .gray, category: .sensor),

        // --- Sensors: presence / safety ---
        "occupancy":         .init(label: "Occupancy", symbol: "figure.walk", tint: .purple, category: .sensor),
        "presence":          .init(label: "Presence", symbol: "figure.walk", tint: .purple, category: .sensor),
        "motion":            .init(label: "Motion", symbol: "figure.walk.motion", tint: .purple, category: .sensor),
        "vibration":         .init(label: "Vibration", symbol: "waveform.path", tint: .pink, category: .sensor),
        "tamper":            .init(label: "Tamper", symbol: "exclamationmark.shield.fill", tint: .orange, category: .sensor),
        "smoke":             .init(label: "Smoke", symbol: "smoke.fill", tint: .gray, category: .sensor),
        "water_leak":        .init(label: "Water Leak", symbol: "drop.fill", tint: .blue, category: .sensor),
        "gas":               .init(label: "Gas", symbol: "flame.fill", tint: .orange, category: .sensor),
        "contact":           .init(label: "Contact", symbol: "rectangle.portrait.on.rectangle.portrait", tint: .blue, category: .sensor),

        // --- Maintenance ---
        "replace_filter":    .init(label: "Replace Filter", symbol: "exclamationmark.triangle.fill", tint: .orange, category: .maintenance),
        "filter_age":        .init(label: "Filter Age", symbol: "hourglass", tint: .blue, category: .maintenance),
        "device_age":        .init(label: "Device Age", symbol: "clock.fill", tint: .blue, category: .maintenance),
        "calibration":       .init(label: "Calibration", symbol: "gauge.medium", tint: .gray, category: .maintenance),
        "calibration_time":  .init(label: "Calibration Time", symbol: "gauge.medium", tint: .gray, category: .maintenance),

        // --- Behaviour ---
        "power_on_behavior":   .init(label: "Power-On Behaviour", symbol: "arrow.uturn.backward.circle.fill", tint: .indigo, category: .behaviour),
        "power_on_behaviour":  .init(label: "Power-On Behaviour", symbol: "arrow.uturn.backward.circle.fill", tint: .indigo, category: .behaviour),
        "restore_state":       .init(label: "Restore State", symbol: "arrow.uturn.backward.circle.fill", tint: .indigo, category: .behaviour),
        "startup_on_off":      .init(label: "Startup State", symbol: "power", tint: .indigo, category: .behaviour),
        "startup_brightness":  .init(label: "Startup Brightness", symbol: "sun.max.fill", tint: .indigo, category: .behaviour),
        "startup_color_temp":  .init(label: "Startup Colour Temperature", symbol: "thermometer.sun.fill", tint: .indigo, category: .behaviour),
        "default_level":       .init(label: "Default Level", symbol: "gauge.medium", tint: .indigo, category: .behaviour),
        "default_brightness":  .init(label: "Default Brightness", symbol: "gauge.medium", tint: .indigo, category: .behaviour),
        "default_transition":  .init(label: "Default Transition", symbol: "timer", tint: .indigo, category: .behaviour),
        "transition":          .init(label: "Transition", symbol: "timer", tint: .indigo, category: .behaviour),
        "on_transition":       .init(label: "On Transition", symbol: "timer", tint: .indigo, category: .behaviour),
        "off_transition":      .init(label: "Off Transition", symbol: "timer", tint: .indigo, category: .behaviour),
        "min_brightness":      .init(label: "Minimum Brightness", symbol: "sun.min.fill", tint: .indigo, category: .behaviour),
        "max_brightness":      .init(label: "Maximum Brightness", symbol: "sun.max.fill", tint: .indigo, category: .behaviour),
        "min_level":           .init(label: "Minimum Level", symbol: "gauge.low", tint: .indigo, category: .behaviour),
        "max_level":           .init(label: "Maximum Level", symbol: "gauge.high", tint: .indigo, category: .behaviour),
        "auto_off":            .init(label: "Auto Off", symbol: "timer", tint: .indigo, category: .behaviour),
        "auto_off_timer":      .init(label: "Auto-Off Timer", symbol: "timer", tint: .indigo, category: .behaviour),
        "countdown":           .init(label: "Countdown", symbol: "timer", tint: .indigo, category: .behaviour),
        "countdown_hours":     .init(label: "Countdown Hours", symbol: "timer", tint: .indigo, category: .behaviour),
        "smart_bulb_mode":     .init(label: "Smart Bulb Mode", symbol: "lightbulb.led.fill", tint: .indigo, category: .behaviour),
        "light_mode":          .init(label: "Light Mode", symbol: "lightbulb.fill", tint: .indigo, category: .behaviour),
        "dim_curve":           .init(label: "Dim Curve", symbol: "function", tint: .indigo, category: .behaviour),
        "dimmer_curve":        .init(label: "Dimmer Curve", symbol: "function", tint: .indigo, category: .behaviour),
        "output_mode":         .init(label: "Output Mode", symbol: "lightbulb.led.fill", tint: .indigo, category: .behaviour),

        // --- Indicators ---
        "led_enable":          .init(label: "LED Enable", symbol: "lightbulb.fill", tint: .yellow, category: .indicator),
        "led":                 .init(label: "LED", symbol: "lightbulb.fill", tint: .yellow, category: .indicator),
        "indicator":           .init(label: "Indicator", symbol: "lightbulb.fill", tint: .yellow, category: .indicator),
        "indicator_mode":      .init(label: "Indicator Mode", symbol: "lightbulb.fill", tint: .yellow, category: .indicator),
        "child_lock":          .init(label: "Child Lock", symbol: "lock.fill", tint: .orange, category: .indicator),
        "buzzer":              .init(label: "Buzzer", symbol: "speaker.wave.2.fill", tint: .pink, category: .indicator),
        "beep":                .init(label: "Beep", symbol: "speaker.wave.2.fill", tint: .pink, category: .indicator),
        "beeper":              .init(label: "Beeper", symbol: "speaker.wave.2.fill", tint: .pink, category: .indicator),

        // --- Inovelli: dim / ramp / level behaviour ---
        "dimmingSpeedUpLocal":    .init(label: "Dim Up Speed (Local)",    symbol: "arrow.up.to.line",   tint: .indigo, category: .behaviour),
        "dimmingSpeedUpRemote":   .init(label: "Dim Up Speed (Remote)",   symbol: "arrow.up.to.line",   tint: .indigo, category: .behaviour),
        "dimmingSpeedDownLocal":  .init(label: "Dim Down Speed (Local)",  symbol: "arrow.down.to.line", tint: .indigo, category: .behaviour),
        "dimmingSpeedDownRemote": .init(label: "Dim Down Speed (Remote)", symbol: "arrow.down.to.line", tint: .indigo, category: .behaviour),
        "rampRateOffToOnLocal":   .init(label: "Ramp Off→On (Local)",     symbol: "arrow.up.right",     tint: .indigo, category: .behaviour),
        "rampRateOffToOnRemote":  .init(label: "Ramp Off→On (Remote)",    symbol: "arrow.up.right",     tint: .indigo, category: .behaviour),
        "rampRateOnToOffLocal":   .init(label: "Ramp On→Off (Local)",     symbol: "arrow.down.right",   tint: .indigo, category: .behaviour),
        "rampRateOnToOffRemote":  .init(label: "Ramp On→Off (Remote)",    symbol: "arrow.down.right",   tint: .indigo, category: .behaviour),
        "minimumLevel":           .init(label: "Minimum Level",           symbol: "gauge.low",          tint: .indigo, category: .behaviour),
        "maximumLevel":           .init(label: "Maximum Level",           symbol: "gauge.high",         tint: .indigo, category: .behaviour),
        "defaultLevelLocal":      .init(label: "Default Level (Local)",   symbol: "gauge.medium",       tint: .indigo, category: .behaviour),
        "defaultLevelRemote":     .init(label: "Default Level (Remote)",  symbol: "gauge.medium",       tint: .indigo, category: .behaviour),
        "stateAfterPowerRestored": .init(label: "After Power Restored",   symbol: "arrow.uturn.backward.circle.fill", tint: .indigo, category: .behaviour),
        "autoTimerOff":           .init(label: "Auto-Off Timer",          symbol: "timer",              tint: .indigo, category: .behaviour),
        "loadLevelIndicatorTimeout": .init(label: "LED Bar Timeout",      symbol: "timer",              tint: .indigo, category: .behaviour),
        "buttonDelay":            .init(label: "Button Delay",            symbol: "timer",              tint: .indigo, category: .behaviour),
        "quickStartTime":         .init(label: "Quick Start Time",        symbol: "bolt.fill",          tint: .indigo, category: .behaviour),
        "quickStartLevel":        .init(label: "Quick Start Level",       symbol: "bolt.fill",          tint: .indigo, category: .behaviour),
        "invertSwitch":           .init(label: "Invert Switch",           symbol: "arrow.up.arrow.down.square.fill", tint: .indigo, category: .behaviour),
        "switchType":             .init(label: "Switch Type",             symbol: "switch.2",           tint: .indigo, category: .behaviour),
        "dimmingMode":            .init(label: "Dimming Mode",            symbol: "lightbulb.fill",     tint: .indigo, category: .behaviour),
        "dimmingAlgorithm":       .init(label: "Dimming Algorithm",       symbol: "function",           tint: .indigo, category: .behaviour),
        "powerType":              .init(label: "Wiring",                  symbol: "powerplug.fill",     tint: .indigo, category: .behaviour),
        "higherOutputInNonNeutral": .init(label: "Higher Output (No Neutral)", symbol: "bolt.fill",     tint: .indigo, category: .behaviour),
        "auxDetectionLevel":      .init(label: "Aux Detection Level",     symbol: "switch.2",           tint: .indigo, category: .advanced),
        "dumbDetectionLevel":     .init(label: "Dumb Switch Detection",   symbol: "switch.2",           tint: .indigo, category: .advanced),
        "nonNeutralAuxMediumGear": .init(label: "Aux Medium Gear",        symbol: "bolt.fill",          tint: .indigo, category: .advanced),
        "nonNeutralAuxLowGear":   .init(label: "Aux Low Gear",            symbol: "bolt.fill",          tint: .indigo, category: .advanced),
        "smartBulbMode":          .init(label: "Smart Bulb Mode",         symbol: "lightbulb.led.fill", tint: .indigo, category: .behaviour),
        "outputMode":             .init(label: "Output Mode",             symbol: "lightbulb.led.fill", tint: .indigo, category: .behaviour),
        "onOffLedMode":           .init(label: "On/Off LED Mode",         symbol: "lightbulb.fill",     tint: .yellow, category: .indicator),
        "fanLedLevelType":        .init(label: "Fan LED Level Type",      symbol: "wind",               tint: .indigo, category: .behaviour),
        "fanControlMode":         .init(label: "Fan Control Mode",        symbol: "fanblades.fill",     tint: .indigo, category: .behaviour),
        "lowLevelForFanControlMode":    .init(label: "Low Speed Level",   symbol: "gauge.low",          tint: .indigo, category: .behaviour),
        "mediumLevelForFanControlMode": .init(label: "Medium Speed Level", symbol: "gauge.medium",      tint: .indigo, category: .behaviour),
        "highLevelForFanControlMode":   .init(label: "High Speed Level",  symbol: "gauge.high",         tint: .indigo, category: .behaviour),

        // --- Inovelli: LED bar (per-step + global) ---
        "ledColorWhenOn":          .init(label: "LED Colour When On",     symbol: "circle.fill",        tint: .yellow, category: .indicator),
        "ledColorWhenOff":         .init(label: "LED Colour When Off",    symbol: "circle.fill",        tint: .yellow, category: .indicator),
        "ledIntensityWhenOn":      .init(label: "LED Brightness When On", symbol: "sun.max.fill",       tint: .yellow, category: .indicator),
        "ledIntensityWhenOff":     .init(label: "LED Brightness When Off", symbol: "sun.min.fill",      tint: .yellow, category: .indicator),
        "ledBarScaling":           .init(label: "LED Bar Scaling",        symbol: "ruler.fill",         tint: .yellow, category: .indicator),
        "ledColorForFanControlMode": .init(label: "Fan-Mode LED Colour",  symbol: "circle.fill",        tint: .yellow, category: .indicator),
        "firmwareUpdateInProgressIndicator": .init(label: "Firmware-Update LED", symbol: "arrow.triangle.2.circlepath", tint: .yellow, category: .indicator),

        // --- Inovelli: tap behaviour & protection ---
        "doubleTapUpToParam55":    .init(label: "Double-Tap Up Action",   symbol: "hand.tap.fill",      tint: .indigo, category: .behaviour),
        "doubleTapDownToParam56":  .init(label: "Double-Tap Down Action", symbol: "hand.tap.fill",      tint: .indigo, category: .behaviour),
        "brightnessLevelForDoubleTapUp":   .init(label: "Double-Tap Up Level",   symbol: "sun.max.fill", tint: .indigo, category: .behaviour),
        "brightnessLevelForDoubleTapDown": .init(label: "Double-Tap Down Level", symbol: "sun.min.fill", tint: .indigo, category: .behaviour),
        "doubleTapClearNotifications": .init(label: "Double-Tap Clears Notifications", symbol: "bell.slash.fill", tint: .indigo, category: .behaviour),
        "singleTapBehavior":       .init(label: "Single-Tap Behaviour",   symbol: "hand.tap.fill",      tint: .indigo, category: .behaviour),
        "fanTimerMode":            .init(label: "Fan Timer Mode",         symbol: "timer",              tint: .indigo, category: .behaviour),
        "auxSwitchUniqueScenes":   .init(label: "Aux Switch Unique Scenes", symbol: "rectangle.on.rectangle", tint: .indigo, category: .advanced),
        "bindingOffToOnSyncLevel": .init(label: "Sync Level on Off→On",   symbol: "arrow.triangle.2.circlepath", tint: .indigo, category: .advanced),
        "localProtection":         .init(label: "Disable Local Control",  symbol: "lock.fill",          tint: .orange, category: .indicator),
        "remoteProtection":        .init(label: "Disable Remote Control", symbol: "lock.fill",          tint: .orange, category: .indicator),
        "relayClick":              .init(label: "Relay Click",            symbol: "speaker.wave.2.fill", tint: .pink,  category: .indicator),
        "deviceBindNumber":        .init(label: "Bind Number",            symbol: "link",               tint: .gray,   category: .diagnostic),
        "internalTemperature":     .init(label: "Internal Temperature",   symbol: "thermometer.medium", tint: .red,    category: .sensor),
        "overheat":                .init(label: "Overheat",               symbol: "thermometer.high",   tint: .red,    category: .sensor),
        "activePowerReports":      .init(label: "Active Power Reports",   symbol: "bolt.fill",          tint: .indigo, category: .advanced),
        "periodicPowerAndEnergyReports": .init(label: "Periodic Reports", symbol: "clock.fill",         tint: .indigo, category: .advanced),
        "activeEnergyReports":     .init(label: "Active Energy Reports",  symbol: "bolt.fill",          tint: .indigo, category: .advanced),
        "otaImageType":            .init(label: "OTA Image Type",         symbol: "arrow.triangle.2.circlepath", tint: .gray, category: .advanced),

        // --- Diagnostic ---
        "battery":             .init(label: "Battery", symbol: "battery.100", tint: .green, category: .diagnostic),
        "battery_low":         .init(label: "Battery Low", symbol: "battery.25", tint: .orange, category: .diagnostic),
        "battery_state":       .init(label: "Battery State", symbol: "battery.100", tint: .green, category: .diagnostic),
        "linkquality":         .init(label: "Link Quality", symbol: "antenna.radiowaves.left.and.right", tint: .gray, category: .diagnostic),
        "last_seen":           .init(label: "Last Seen", symbol: "clock.fill", tint: .gray, category: .diagnostic),
    ]

    // MARK: - Smart fallback

    private static func fallback(property: String, exposeType: String) -> FeatureMeta {
        let hint = inferHint(property: property)
        return FeatureMeta(
            label: smartTitle(property),
            symbol: hint?.symbol ?? fallbackSymbol(exposeType: exposeType),
            tint: hint?.tint ?? .gray,
            category: hint?.category ?? .advanced
        )
    }

    private static func fallbackSymbol(exposeType: String) -> String {
        switch exposeType {
        case "binary": return "switch.2"
        case "enum":   return "list.bullet"
        case "numeric": return "number"
        case "text":   return "textformat"
        default:       return "circle.dotted"
        }
    }

    /// Substring-matched hints so uncatalogued properties still land in a
    /// sensible category with reasonable iconography. First match wins.
    private struct Hint { let symbol: String; let tint: Color; let category: FeatureCategory }
    private static func inferHint(property: String) -> Hint? {
        let p = property.lowercased()

        // LED / colour / indicator surfaces
        if p.contains("ledcolor") || p.contains("led_color") || p.contains("ledcolour") || p.contains("led_colour") {
            return Hint(symbol: "circle.fill", tint: .yellow, category: .indicator)
        }
        if p.contains("ledintensity") || p.contains("led_intensity") {
            return Hint(symbol: "sun.max.fill", tint: .yellow, category: .indicator)
        }
        if p.contains("led") || p.contains("indicator") {
            return Hint(symbol: "lightbulb.fill", tint: .yellow, category: .indicator)
        }

        // Locks / protection
        if p.contains("lock") || p.contains("protect") {
            return Hint(symbol: "lock.fill", tint: .orange, category: .indicator)
        }

        // Audio feedback
        if p.contains("beep") || p.contains("buzzer") || p.contains("click") || p.contains("chime") {
            return Hint(symbol: "speaker.wave.2.fill", tint: .pink, category: .indicator)
        }

        // Tap / button behaviours
        if p.contains("doubletap") || p.contains("double_tap") || p.contains("singletap") || p.contains("single_tap") || p.contains("hold") {
            return Hint(symbol: "hand.tap.fill", tint: .indigo, category: .behaviour)
        }

        // Timing / durations
        if p.contains("timeout") || p.contains("countdown") || p.contains("delay")
            || p.contains("autooff") || p.contains("auto_off") || p.contains("autotimer") {
            return Hint(symbol: "timer", tint: .indigo, category: .behaviour)
        }
        if p.contains("transition") {
            return Hint(symbol: "timer", tint: .indigo, category: .behaviour)
        }

        // Slope behaviours: ramp / dim speed / curve
        if p.contains("ramp") || p.contains("dimming") || p.contains("dim_") || p.hasPrefix("dim") {
            return Hint(symbol: "arrow.up.and.down", tint: .indigo, category: .behaviour)
        }

        // Levels / brightness defaults
        if p.contains("brightness") {
            return Hint(symbol: "sun.max.fill", tint: .indigo, category: .behaviour)
        }
        if p.contains("level") {
            return Hint(symbol: "gauge.medium", tint: .indigo, category: .behaviour)
        }

        // Restore / startup / power-on
        if p.contains("startup") || p.contains("poweron") || p.contains("power_on") || p.contains("restore") || p.contains("afterpower") {
            return Hint(symbol: "arrow.uturn.backward.circle.fill", tint: .indigo, category: .behaviour)
        }

        // Sensors
        if p.contains("temperature") || p.contains("temp") || p.contains("overheat") {
            return Hint(symbol: "thermometer.medium", tint: .red, category: .sensor)
        }
        if p.contains("humidity") {
            return Hint(symbol: "humidity.fill", tint: .cyan, category: .sensor)
        }

        return nil
    }

    /// Convert a Z2M property name (snake_case, camelCase, or mixed) into a
    /// human title. Preserves known acronyms; applies British spelling.
    static func smartTitle(_ property: String) -> String {
        let words = splitWords(property)
        guard !words.isEmpty else { return property }
        return words.map(transformWord).joined(separator: " ")
    }

    private static func splitWords(_ s: String) -> [String] {
        var words: [String] = []
        var current = ""
        for ch in s {
            if ch == "_" || ch == "-" || ch == " " {
                if !current.isEmpty { words.append(current); current = "" }
                continue
            }
            // camelCase boundary: lowercase → uppercase
            if let last = current.last, last.isLowercase, ch.isUppercase {
                words.append(current); current = String(ch); continue
            }
            // letter ↔ digit boundary
            if let last = current.last,
               (last.isLetter && ch.isNumber) || (last.isNumber && ch.isLetter) {
                words.append(current); current = String(ch); continue
            }
            current.append(ch)
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    private static func transformWord(_ word: String) -> String {
        let upper = word.uppercased()
        if let acronym = acronymOverrides[upper] { return acronym }
        if knownAcronyms.contains(upper) { return upper }
        // All-digit chunks pass through.
        if word.allSatisfy({ $0.isNumber }) { return word }
        let lower = word.lowercased()
        let british = britishSpellings[lower] ?? lower
        return british.prefix(1).uppercased() + british.dropFirst()
    }

    private static let knownAcronyms: Set<String> = [
        "LED", "RGB", "RGBW", "IR", "UV",
        "DC", "AC", "USB",
        "OTA", "API", "ID", "URL", "IP", "MAC",
        "VOC", "TVOC", "AQI",
        "MQTT"
    ]

    private static let acronymOverrides: [String: String] = [
        "PM1":  "PM1",
        "PM10": "PM10",
        "PM25": "PM2.5",
        "CO":   "CO",
        "CO2":  "CO₂",
        "QOS":  "QoS",
        "WIFI": "Wi-Fi",
        "HZ":   "Hz",
        "DB":   "dB",
        "HCHO": "HCHO"
    ]

    private static let britishSpellings: [String: String] = [
        "behavior":   "behaviour",
        "behaviors":  "behaviours",
        "color":      "colour",
        "colors":     "colours",
        "center":     "centre",
        "centered":   "centred",
        "favorite":   "favourite",
        "neighbor":   "neighbour",
        "ionized":    "ionised",
        "optimize":   "optimise"
    ]
}
