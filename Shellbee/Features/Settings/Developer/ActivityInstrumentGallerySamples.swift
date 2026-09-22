import Foundation

enum ActivityInstrumentGalleryScope: String, CaseIterable, Identifiable {
    case all
    case devices
    case changes
    case bridge
    case events

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .devices: "Devices"
        case .changes: "Changes"
        case .bridge: "Bridge"
        case .events: "Events"
        }
    }
}

struct ActivityInstrumentGallerySample: Identifiable {
    let id: String
    let scope: ActivityInstrumentGalleryScope
    let section: String
    let title: String
    let detail: String
    let instrument: ActivityInstrument
    let deviceCategory: Device.Category?
    let topologyType: String?
    let exposeType: String?
    let logCategory: LogCategory?
    let bridgeTopic: String?

    init(
        _ id: String,
        scope: ActivityInstrumentGalleryScope,
        section: String,
        title: String,
        detail: String,
        instrument: ActivityInstrument,
        deviceCategory: Device.Category? = nil,
        topologyType: String? = nil,
        exposeType: String? = nil,
        logCategory: LogCategory? = nil,
        bridgeTopic: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.section = section
        self.title = title
        self.detail = detail
        self.instrument = instrument
        self.deviceCategory = deviceCategory
        self.topologyType = topologyType
        self.exposeType = exposeType
        self.logCategory = logCategory
        self.bridgeTopic = bridgeTopic
    }
}

enum ActivityInstrumentGalleryCatalog {
    static let samples = deviceSamples + exposeShapeSamples + stateChangeSamples + bridgeSamples + eventSamples

    static let requiredExposeTypes: Set<String> = [
        "binary", "climate", "composite", "cover", "enum", "fan",
        "light", "list", "lock", "numeric", "switch", "text"
    ]

    static let requiredTopologyTypes: Set<String> = ["Coordinator", "Router", "EndDevice", "Unknown"]

    static var sections: [String] {
        var seen = Set<String>()
        return samples.compactMap { sample in
            seen.insert(sample.section).inserted ? sample.section : nil
        }
    }

    static func filtered(scope: ActivityInstrumentGalleryScope, searchText: String) -> [ActivityInstrumentGallerySample] {
        let scoped = scope == .all ? samples : samples.filter { $0.scope == scope }
        guard !searchText.isEmpty else { return scoped }
        return scoped.filter {
            $0.title.localizedStandardContains(searchText)
                || $0.detail.localizedStandardContains(searchText)
                || $0.section.localizedStandardContains(searchText)
                || ($0.bridgeTopic?.localizedStandardContains(searchText) ?? false)
        }
    }

    // MARK: - Devices

    private static let deviceSamples: [ActivityInstrumentGallerySample] = [
        device("device.light", "Light", "Brightness · colour · state", .light, .level, value: 0.8, text: "80"),
        device("device.switch", "Switch or Plug", "State · power · energy", .switchPlug, .binary, value: 1),
        device("device.sensor", "Sensor", "Published measurements and alarms", .sensor, .trend, value: 0.62, trend: .rising),
        device("device.climate", "Climate", "Temperature · setpoint · mode", .climate, .temperature, value: 0.58, text: "21°"),
        device("device.cover", "Cover", "Position · tilt · movement", .cover, .position, value: 0.67, text: "67"),
        device("device.lock", "Lock", "Locked · unlocked · PIN events", .lock, .binary, value: 1),
        device("device.fan", "Fan", "State · speed · oscillation", .fan, .level, value: 0.54, text: "54"),
        device("device.remote", "Remote", "Action · button · rotation", .remote, .action, value: 0.5, trend: .rising),
        device("device.other", "Other or Custom", "Unknown expose families", .other, .unknown, value: 0.5),
        topology("topology.coordinator", "Coordinator", "The Zigbee coordinator", "Coordinator", .network),
        topology("topology.router", "Router", "Mains-powered mesh router", "Router", .network),
        topology("topology.end-device", "End Device", "Battery-powered sleepy device", "EndDevice", .lifecycle),
        topology("topology.unknown", "Unknown Device", "Unrecognised Z2M device type", "Unknown", .unknown)
    ]

    private static func device(
        _ id: String, _ title: String, _ detail: String, _ category: Device.Category,
        _ kind: ActivityInstrumentKind, value: Double, text: String? = nil,
        trend: ActivityInstrumentTrend = .none
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            id, scope: .devices, section: "Device Categories", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, primaryText: text, trend: trend),
            deviceCategory: category
        )
    }

    private static func topology(
        _ id: String, _ title: String, _ detail: String, _ type: String, _ kind: ActivityInstrumentKind
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            id, scope: .devices, section: "Topology Roles", title: title, detail: detail,
            instrument: .init(kind: kind), topologyType: type
        )
    }

    // MARK: - Expose shapes

    private static let exposeShapeSamples: [ActivityInstrumentGallerySample] = [
        expose("binary", "Binary", "ON → OFF", .binary, value: 0),
        expose("numeric", "Numeric", "42 → 57", .trend, value: 0.57, trend: .rising),
        expose("enum", "Enum", "heat → auto", .action, value: 0.65),
        expose("text", "Text", "old label → new label", .message, value: 0.5),
        expose("composite", "Composite", "x, y and z changed", .group, value: 0.5),
        expose("list", "List", "2 items → 4 items", .group, value: 0.67),
        expose("light", "Light", "Brightness 65 → 80", .level, value: 0.8, text: "80"),
        expose("switch", "Switch", "OFF → ON", .binary, value: 1),
        expose("cover", "Cover", "Position 42 → 67", .position, value: 0.67, text: "67"),
        expose("lock", "Lock", "UNLOCK → LOCK", .binary, value: 1),
        expose("climate", "Climate", "Setpoint 20 → 21.5 °C", .temperature, value: 0.6, text: "22°"),
        expose("fan", "Fan", "Speed 2 → 4", .level, value: 0.8, text: "4")
    ]

    private static func expose(
        _ type: String, _ title: String, _ detail: String, _ kind: ActivityInstrumentKind,
        value: Double, text: String? = nil, trend: ActivityInstrumentTrend = .none
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            "expose.\(type)", scope: .changes, section: "Z2M Expose Shapes", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, primaryText: text, trend: trend),
            exposeType: type
        )
    }

    // MARK: - State semantics

    private static let stateChangeSamples: [ActivityInstrumentGallerySample] = [
        change("state", "State", "OFF → ON", .binary, value: 1),
        change("brightness", "Brightness", "65 → 80%", .level, value: 0.8, text: "80", trend: .rising),
        change("colour", "Colour", "Warm white → blue", .colour, value: 0.7),
        change("colour-temperature", "Colour Temperature", "370 → 250 mired", .temperature, value: 0.45, text: "250", trend: .falling),
        change("temperature", "Temperature", "20.8 → 21.4 °C", .temperature, value: 0.57, text: "21°", trend: .rising),
        change("humidity", "Humidity", "48 → 53%", .humidity, value: 0.53, trend: .rising),
        change("pressure", "Pressure", "1008 → 1007 hPa", .trend, value: 0.48, trend: .falling),
        change("illuminance", "Illuminance", "120 → 340 lx", .level, value: 0.68, text: "340", trend: .rising),
        change("air-quality", "Air Quality", "Good → moderate", .airQuality, value: 0.45),
        change("co2", "CO₂", "680 → 920 ppm", .airQuality, value: 0.62, text: "920", trend: .rising),
        change("particles", "PM2.5", "8 → 16 µg/m³", .airQuality, value: 0.32, text: "16", trend: .rising),
        change("power", "Power", "4 → 812 W", .energy, value: 0.76, text: "812", trend: .rising),
        change("energy", "Energy", "3.8 → 3.9 kWh", .energy, value: 0.39, trend: .rising),
        change("voltage", "Voltage", "229 → 231 V", .trend, value: 0.54, trend: .rising),
        change("current", "Current", "0.1 → 3.5 A", .energy, value: 0.7, trend: .rising),
        change("frequency", "Frequency", "49.9 → 50 Hz", .trend, value: 0.5, trend: .steady),
        change("battery", "Battery", "24 → 18%", .battery, value: 0.18, text: "18", trend: .falling, severity: .warning),
        change("battery-low", "Battery Low", "false → true", .battery, value: 0.08, severity: .warning),
        change("link-quality", "Link Quality", "124 → 120", .signal, value: 120.0 / 255.0, trend: .falling, severity: .quiet),
        change("last-seen", "Last Seen", "Device reported now", .lifecycle, value: 1, severity: .quiet),
        change("occupancy", "Occupancy", "clear → occupied", .presence, value: 1),
        change("presence", "Presence", "false → true", .presence, value: 1),
        change("motion", "Motion", "clear → detected", .presence, value: 1),
        change("contact", "Contact", "closed → open", .binary, value: 1),
        change("water-leak", "Water Leak", "dry → leak", .safety, value: 1, severity: .failure),
        change("smoke", "Smoke", "clear → detected", .safety, value: 1, severity: .failure),
        change("gas", "Gas", "clear → detected", .safety, value: 1, severity: .failure),
        change("tamper", "Tamper", "false → true", .safety, value: 1, severity: .warning),
        change("vibration", "Vibration", "idle → vibration", .trend, value: 0.8, trend: .rising),
        change("cover-position", "Cover Position", "42 → 67%", .position, value: 0.67, text: "67", trend: .rising),
        change("cover-tilt", "Cover Tilt", "20 → 75%", .position, value: 0.75, text: "75", trend: .rising),
        change("lock", "Lock", "unlocked → locked", .binary, value: 1, severity: .success),
        change("fan-speed", "Fan Speed", "2 → 4", .level, value: 0.8, text: "4", trend: .rising),
        change("thermostat", "Heating Setpoint", "20 → 21.5 °C", .temperature, value: 0.58, text: "22°", trend: .rising),
        change("action", "Remote Action", "rotate_right", .action, value: 0.65, trend: .rising),
        change("multi", "Multiple Properties", "Temperature, humidity and battery", .group, value: 0.5),
        change("custom", "Custom Property", "manufacturer_value: alpha → beta", .unknown, value: 0.5)
    ]

    private static func change(
        _ id: String, _ title: String, _ detail: String, _ kind: ActivityInstrumentKind,
        value: Double, text: String? = nil, trend: ActivityInstrumentTrend = .none,
        severity: ActivityInstrumentSeverity = .routine
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            "change.\(id)", scope: .changes, section: "State Changes", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, primaryText: text, trend: trend, severity: severity),
            logCategory: .stateChange
        )
    }

    // MARK: - Bridge activities

    private static let bridgeSamples: [ActivityInstrumentGallerySample] = [
        bridge("health_check", "Health Check", "Bridge is healthy", .health, category: .bridgeActivity, severity: .success),
        bridge("info", "Info Refreshed", "Bridge information updated", .message),
        bridge("options", "Bridge Options", "Configuration updated", .options),
        bridge("backup", "Backup", "Backup created", .backup, severity: .success),
        bridge("restart", "Restart", "Bridge restarted", .restart, category: .bridgeState),
        bridge("permit_join", "Permit Join", "Pairing opened for 254 seconds", .pairing, category: .permitJoin),
        bridge("networkmap", "Network Map", "28 devices mapped", .network),
        bridge("touchlink/scan", "Touchlink Scan", "2 devices found", .touchlink),
        bridge("touchlink/identify", "Touchlink Identify", "Lamp identified", .touchlink),
        bridge("touchlink/factory_reset", "Touchlink Factory Reset", "Device reset", .touchlink, severity: .warning),
        bridge("device/configure", "Device Configure", "Reporting configured", .options),
        bridge("device/interview", "Device Interview", "Interview successful", .pairing, category: .interview, severity: .success),
        bridge("device/rename", "Device Rename", "Office Sensor → Studio Sensor", .lifecycle),
        bridge("device/remove", "Device Remove", "Device removed", .lifecycle, category: .deviceLeave, severity: .warning),
        bridge("device/options", "Device Options", "Options updated", .options),
        bridge("device/bind", "Device Bind", "Bound to coordinator", .pairing, severity: .success),
        bridge("device/unbind", "Device Unbind", "Binding removed", .pairing),
        bridge("device/configure_reporting", "Configure Reporting", "Reporting updated", .options),
        bridge("device/ota_update/check", "OTA Check", "Firmware is available", .update, value: 0),
        bridge("device/ota_update/update", "OTA Update", "Firmware updated", .update, value: 1, severity: .success),
        bridge("device/ota_update/schedule", "OTA Schedule", "Update scheduled", .update, value: 0.25),
        bridge("device/ota_update/unschedule", "OTA Unschedule", "Scheduled update removed", .update, value: 0),
        bridge("group/add", "Group Add", "Living Room created", .group),
        bridge("group/remove", "Group Remove", "Group removed", .group, severity: .warning),
        bridge("group/rename", "Group Rename", "Lounge → Living Room", .group),
        bridge("group/options", "Group Options", "Options updated", .options),
        bridge("group/members/add", "Group Member Add", "Lamp added", .group),
        bridge("group/members/remove", "Group Member Remove", "Lamp removed", .group),
        bridge("install_code/add", "Install Code", "Install code added", .pairing, severity: .success),
        bridge("devices", "Device List", "Devices refreshed", .network),
        bridge("groups", "Group List", "Groups refreshed", .group),
        bridge("action", "Bridge Action", "Action executed", .action),
        bridge("custom_response", "Unknown Response", "Future Z2M response", .unknown),
        ActivityInstrumentGallerySample(
            "bridge.health", scope: .bridge, section: "Bridge Broadcasts", title: "Bridge Health",
            detail: "Periodic health broadcast", instrument: .init(kind: .health, severity: .success),
            logCategory: .bridgeActivity, bridgeTopic: "bridge/health"
        ),
        ActivityInstrumentGallerySample(
            "bridge.state.online", scope: .bridge, section: "Bridge Broadcasts", title: "Bridge Online",
            detail: "offline → online", instrument: .init(kind: .lifecycle, normalizedValue: 1, trend: .rising, severity: .success),
            logCategory: .bridgeState, bridgeTopic: "bridge/state"
        ),
        ActivityInstrumentGallerySample(
            "bridge.state.offline", scope: .bridge, section: "Bridge Broadcasts", title: "Bridge Offline",
            detail: "online → offline", instrument: .init(kind: .lifecycle, normalizedValue: 0, trend: .falling, severity: .failure),
            logCategory: .bridgeState, bridgeTopic: "bridge/state"
        )
    ]

    private static func bridge(
        _ topic: String, _ title: String, _ detail: String, _ kind: ActivityInstrumentKind,
        value: Double = 0.5, category: LogCategory = .bridgeActivity,
        severity: ActivityInstrumentSeverity = .routine
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            "bridge.\(topic)", scope: .bridge, section: "Bridge Requests", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, severity: severity),
            logCategory: category, bridgeTopic: "bridge/response/\(topic)"
        )
    }

    // MARK: - Events and outcomes

    private static let eventSamples: [ActivityInstrumentGallerySample] = [
        event("device-joined", "Device Joined", "New device joined the network", .deviceJoined, .lifecycle, trend: .rising, severity: .success),
        event("device-announced", "Device Announced", "Device announced itself", .deviceAnnounce, .signal),
        event("interview-started", "Interview Started", "Interview is in progress", .interview, .pairing),
        event("interview-success", "Interview Successful", "Device is ready", .interview, .pairing, severity: .success),
        event("interview-failed", "Interview Failed", "Interview timed out", .interview, .pairing, severity: .failure),
        event("device-left", "Device Left", "Device left the network", .deviceLeave, .lifecycle, trend: .falling, severity: .warning),
        event("availability-online", "Device Online", "offline → online", .availability, .lifecycle, trend: .rising, severity: .success),
        event("availability-offline", "Device Offline", "online → offline", .availability, .lifecycle, trend: .falling, severity: .failure),
        event("pairing-open", "Pairing Opened", "Permit join is active", .permitJoin, .pairing),
        event("pairing-closed", "Pairing Closed", "Permit join ended", .permitJoin, .pairing, severity: .quiet),
        event("device-options", "Device Options Changed", "Options changed outside Shellbee", .bridgeActivity, .options),
        event("scene-added", "Scene Added", "Scene 4 added", .bridgeActivity, .group),
        event("scene-removed", "Scene Removed", "Scene 4 removed", .bridgeActivity, .group),
        event("restart-required", "Restart Required", "Configuration needs a restart", .bridgeActivity, .restart, severity: .warning),
        event("general-info", "General Info", "Informational Z2M log", .general, .message),
        event("general-warning", "General Warning", "A device did not respond", .general, .message, severity: .warning),
        event("general-error", "General Error", "Publish failed", .general, .message, severity: .failure),
        event("general-debug", "Debug", "Routine low-priority detail", .general, .message, severity: .quiet),
        event("unknown-event", "Unknown Bridge Event", "Future event type", .bridgeActivity, .unknown)
    ]

    private static func event(
        _ id: String, _ title: String, _ detail: String, _ category: LogCategory,
        _ kind: ActivityInstrumentKind, trend: ActivityInstrumentTrend = .none,
        severity: ActivityInstrumentSeverity = .routine
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            "event.\(id)", scope: .events, section: "Events and Outcomes", title: title, detail: detail,
            instrument: .init(kind: kind, trend: trend, severity: severity), logCategory: category
        )
    }
}
