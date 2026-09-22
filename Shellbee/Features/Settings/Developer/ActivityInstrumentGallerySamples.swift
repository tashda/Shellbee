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
        device("device.light", "Light", "Brightness · colour · state", .light, .level, value: 0.8),
        device("device.switch", "Switch or Plug", "State · power · energy", .switchPlug, .binary, value: 1),
        device("device.sensor", "Sensor", "Published measurements and alarms", .sensor, .trend, value: 0.62, trend: .rising),
        device("device.climate", "Climate", "Temperature · setpoint · mode", .climate, .temperature, value: 0.58),
        device("device.cover", "Cover", "Position · tilt · movement", .cover, .position, value: 0.67),
        device("device.lock", "Lock", "Locked · unlocked · PIN events", .lock, .binary, value: 1, variant: .lock),
        device("device.fan", "Fan", "State · speed · oscillation", .fan, .level, value: 0.54, variant: .fan),
        device("device.remote", "Remote", "Action · button · rotation", .remote, .action, value: 0.5, trend: .rising),
        device("device.other", "Other or Custom", "Unknown expose families", .other, .unknown, value: 0.5),
        topology("topology.coordinator", "Coordinator", "The Zigbee coordinator", "Coordinator", .network),
        topology("topology.router", "Router", "Mains-powered mesh router", "Router", .network),
        topology("topology.end-device", "End Device", "Battery-powered sleepy device", "EndDevice", .signal),
        topology("topology.unknown", "Unknown Device", "Unrecognised Z2M device type", "Unknown", .unknown)
    ]

    private static func device(
        _ id: String, _ title: String, _ detail: String, _ category: Device.Category,
        _ kind: ActivityInstrumentKind, value: Double,
        trend: ActivityInstrumentTrend = .none, variant: ActivityInstrumentVariant = .standard
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            id, scope: .devices, section: "Device Categories", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, trend: trend, variant: variant),
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
        expose("light", "Light", "Brightness 65 → 80", .level, value: 0.8),
        expose("switch", "Switch", "OFF → ON", .binary, value: 1),
        expose("cover", "Cover", "Position 42 → 67", .position, value: 0.67),
        expose("lock", "Lock", "UNLOCK → LOCK", .binary, value: 1, variant: .lock),
        expose("climate", "Climate", "Setpoint 20 → 21.5 °C", .temperature, value: 0.6),
        expose("fan", "Fan", "Speed 2 → 4", .level, value: 0.8, variant: .fan)
    ]

    private static func expose(
        _ type: String, _ title: String, _ detail: String, _ kind: ActivityInstrumentKind,
        value: Double, trend: ActivityInstrumentTrend = .none,
        variant: ActivityInstrumentVariant = .standard
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            "expose.\(type)", scope: .changes, section: "Z2M Expose Shapes", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, trend: trend, variant: variant),
            exposeType: type
        )
    }

    // MARK: - State semantics

    private static let stateChangeSamples: [ActivityInstrumentGallerySample] = [
        change("state-on", "State On", "state", from: .string("OFF"), to: .string("ON")),
        change("state-off", "State Off", "state", from: .string("ON"), to: .string("OFF")),
        change("brightness", "Brightness", "brightness", from: .int(165), to: .int(204)),
        change("brightness-off", "Brightness Zero", "brightness", from: .int(40), to: .int(0)),
        change("colour", "Colour", "color", from: nil, to: .object(["x": .double(0.17), "y": .double(0.12)])),
        change("colour-hex", "Colour (Hex)", "color", from: nil, to: .string("#ff4f6d")),
        change("colour-temperature", "Colour Temperature", "color_temp", from: .int(250), to: .int(370)),
        change("temperature", "Temperature", "temperature", from: .double(20.8), to: .double(21.4)),
        change("temperature-cold", "Temperature Cold", "temperature", from: .double(5.2), to: .double(4.1)),
        change("temperature-hot", "Temperature Hot", "temperature", from: .double(29), to: .double(31.5)),
        change("humidity", "Humidity", "humidity", from: .int(48), to: .int(53)),
        change("pressure", "Pressure", "pressure", from: .int(1008), to: .int(1007)),
        change("illuminance", "Illuminance", "illuminance", from: .int(12), to: .int(34)),
        change("air-quality", "Air Quality", "voc", from: .int(120), to: .int(220)),
        change("co2", "CO₂", "co2", from: .int(680), to: .int(1_600)),
        change("particles", "PM2.5", "pm25", from: .int(8), to: .int(16)),
        change("power", "Power", "power", from: .int(4), to: .int(812)),
        change("energy", "Energy", "energy", from: .double(3.8), to: .double(3.9)),
        change("voltage", "Voltage", "voltage", from: .int(229), to: .int(231)),
        change("current", "Current", "current", from: .double(0.1), to: .double(3.5)),
        change("frequency", "Frequency", "frequency", from: .double(50), to: .double(50)),
        change("battery", "Battery", "battery", from: .int(92), to: .int(80)),
        change("battery-low", "Battery Low", "battery", from: .int(24), to: .int(18)),
        change("link-quality", "Link Quality", "linkquality", from: .int(124), to: .int(120)),
        change("occupancy", "Occupancy", "occupancy", from: .bool(false), to: .bool(true)),
        change("occupancy-clear", "Occupancy Clear", "occupancy", from: .bool(true), to: .bool(false)),
        change("contact-open", "Contact Open", "contact", from: .bool(true), to: .bool(false)),
        change("contact-closed", "Contact Closed", "contact", from: .bool(false), to: .bool(true)),
        change("water-leak", "Water Leak", "water_leak", from: .bool(false), to: .bool(true)),
        change("water-dry", "Water Leak Cleared", "water_leak", from: .bool(true), to: .bool(false)),
        change("smoke", "Smoke", "smoke", from: .bool(false), to: .bool(true)),
        change("tamper", "Tamper", "tamper", from: .bool(false), to: .bool(true)),
        change("vibration", "Vibration", "vibration", from: .int(0), to: .int(12)),
        change("cover-position", "Cover Position", "position", from: .int(42), to: .int(67)),
        change("cover-closed", "Cover Closed", "position", from: .int(42), to: .int(0)),
        change("cover-tilt", "Cover Tilt", "tilt", from: .int(20), to: .int(75)),
        change("lock", "Lock", "lock", from: .string("UNLOCK"), to: .string("LOCK")),
        change("unlock", "Unlock", "lock", from: .string("LOCK"), to: .string("UNLOCK")),
        change("fan-speed", "Fan Speed", "speed", from: .int(40), to: .int(80)),
        change("thermostat", "Heating Setpoint", "occupied_heating_setpoint", from: .double(20), to: .double(21.5)),
        change("action", "Remote Action", "action", from: nil, to: .string("rotate_right")),
        change("custom", "Custom Property", "manufacturer_value", from: .string("alpha"), to: .string("beta"))
    ]

    /// Runs through the live resolver, so the gallery shows exactly what
    /// the Activity feed would draw for that report.
    private static func change(
        _ id: String, _ title: String, _ property: String, from: JSONValue?, to: JSONValue
    ) -> ActivityInstrumentGallerySample {
        let detail = [from?.stringified, to.stringified].compactMap { $0 }.joined(separator: " → ")
        return ActivityInstrumentGallerySample(
            "change.\(id)", scope: .changes, section: "State Changes", title: title,
            detail: "\(property): \(detail)",
            instrument: ActivityInstrumentResolver.instrument(forProperty: property, from: from, to: to),
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
        bridge("permit_join", "Permit Join", "Pairing opened for 254 seconds", .pairing, value: 1, category: .permitJoin, variant: .permitJoin),
        bridge("networkmap", "Network Map", "28 devices mapped", .network),
        bridge("touchlink/scan", "Touchlink Scan", "2 devices found", .touchlink),
        bridge("touchlink/identify", "Touchlink Identify", "Lamp identified", .touchlink),
        bridge("touchlink/factory_reset", "Touchlink Factory Reset", "Device reset", .touchlink, severity: .warning),
        bridge("device/configure", "Device Configure", "Reporting configured", .options),
        bridge("device/interview", "Device Interview", "Interview successful", .pairing, category: .interview, severity: .success),
        bridge("device/rename", "Device Rename", "Office Sensor → Studio Sensor", .lifecycle, variant: .rename),
        bridge("device/remove", "Device Remove", "Device removed", .lifecycle, category: .deviceLeave, severity: .warning, variant: .remove),
        bridge("device/options", "Device Options", "Options updated", .options),
        bridge("device/bind", "Device Bind", "Bound to coordinator", .pairing, severity: .success),
        bridge("device/unbind", "Device Unbind", "Binding removed", .pairing),
        bridge("device/configure_reporting", "Configure Reporting", "Reporting updated", .options),
        bridge("device/ota_update/check", "OTA Check", "Firmware is available", .update, value: 0.42),
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
            detail: "offline → online", instrument: .init(kind: .lifecycle, normalizedValue: 1, trend: .rising, severity: .success, variant: .availability),
            logCategory: .bridgeState, bridgeTopic: "bridge/state"
        ),
        ActivityInstrumentGallerySample(
            "bridge.state.offline", scope: .bridge, section: "Bridge Broadcasts", title: "Bridge Offline",
            detail: "online → offline", instrument: .init(kind: .lifecycle, normalizedValue: 0, trend: .falling, severity: .failure, variant: .availability),
            logCategory: .bridgeState, bridgeTopic: "bridge/state"
        )
    ]

    private static func bridge(
        _ topic: String, _ title: String, _ detail: String, _ kind: ActivityInstrumentKind,
        value: Double = 0.5, category: LogCategory = .bridgeActivity,
        severity: ActivityInstrumentSeverity = .routine, variant: ActivityInstrumentVariant = .standard
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            "bridge.\(topic)", scope: .bridge, section: "Bridge Requests", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, severity: severity, variant: variant),
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
        event("availability-online", "Device Online", "offline → online", .availability, .lifecycle, value: 1, trend: .rising, severity: .success, variant: .availability),
        event("availability-offline", "Device Offline", "online → offline", .availability, .lifecycle, value: 0, trend: .falling, severity: .failure, variant: .availability),
        event("pairing-open", "Pairing Opened", "Permit join is active", .permitJoin, .pairing, value: 1, variant: .permitJoin),
        event("pairing-closed", "Pairing Closed", "Permit join ended", .permitJoin, .pairing, value: 0, severity: .quiet, variant: .permitJoin),
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
        _ kind: ActivityInstrumentKind, value: Double = 0.5, trend: ActivityInstrumentTrend = .none,
        severity: ActivityInstrumentSeverity = .routine, variant: ActivityInstrumentVariant = .standard
    ) -> ActivityInstrumentGallerySample {
        ActivityInstrumentGallerySample(
            "event.\(id)", scope: .events, section: "Events and Outcomes", title: title, detail: detail,
            instrument: .init(kind: kind, normalizedValue: value, trend: trend, severity: severity, variant: variant),
            logCategory: category
        )
    }
}
