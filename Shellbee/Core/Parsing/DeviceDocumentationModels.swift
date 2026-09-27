import Foundation

/// Top-level container pairing the raw `ParsedDeviceDoc` (from `DocParser`)
/// with the higher-level `NormalizedDeviceDoc` (from `DeviceDocNormalizer`).
/// `sourcePath` is the path that produced the document, used for resolving
/// relative image links.
struct DeviceDocumentation: Sendable {
    let sourcePath: String
    let parsed: ParsedDeviceDoc
    let normalized: NormalizedDeviceDoc
}

struct NormalizedDeviceDoc: Sendable {
    let identity: DeviceDocIdentity
    let pairing: DevicePairingGuide?
    let capabilities: [DeviceDocCapability]
    let options: [DocOption]
    let notesSections: [DocSection]
    let advancedSections: [DocSection]
    let miscSections: [DocSection]
    let quality: Quality

    enum Quality: Sendable, Equatable {
        case fullyNormalized
        case partiallyNormalized
        case parsedOnly
    }

    var additionalSections: [DocSection] { advancedSections + miscSections }
    var hasSemanticContent: Bool {
        pairing != nil || !capabilities.isEmpty || !options.isEmpty || !notesSections.isEmpty
    }
}

struct DeviceDocIdentity: Sendable {
    let vendor: String
    let model: String
    let description: String
    let imageURL: URL?
    let supportsOTA: Bool
}

struct DevicePairingGuide: Sendable {
    let summary: [InlineSpan]
    let prerequisites: [[InlineSpan]]
    let primarySteps: [StepItem]
    let alternatives: [DevicePairingMethod]
    let successCues: [[InlineSpan]]
    let troubleshooting: [[InlineSpan]]
    let additionalNotes: [DocBlock]

    nonisolated var hasContent: Bool {
        !summary.isEmpty
            || !prerequisites.isEmpty
            || !primarySteps.isEmpty
            || !alternatives.isEmpty
            || !successCues.isEmpty
            || !troubleshooting.isEmpty
            || !additionalNotes.isEmpty
    }
}

struct DevicePairingMethod: Sendable, Identifiable {
    let id: UUID
    let title: String
    let summary: [InlineSpan]
    let steps: [StepItem]
    let notes: [DocBlock]
    /// True when this alternative is purely a reference to the Touchlink guide with no
    /// device-specific steps. The UI replaces the generic card with an in-app Touchlink button.
    let isTouchlinkReset: Bool
    /// True when this alternative describes a Philips Hue serial-number factory reset.
    /// The UI replaces the raw Z2M content with an in-app Philips Hue Reset action.
    let isPhilipsHueSerialReset: Bool

    nonisolated init(title: String, summary: [InlineSpan] = [], steps: [StepItem] = [], notes: [DocBlock] = [], isTouchlinkReset: Bool = false, isPhilipsHueSerialReset: Bool = false) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.steps = steps
        self.notes = notes
        self.isTouchlinkReset = isTouchlinkReset
        self.isPhilipsHueSerialReset = isPhilipsHueSerialReset
    }
}

/// One expose from the device definition, as the documentation lists it:
/// z2m's label, what it accepts and whether it can be read or set.
struct DeviceDocCapability: Sendable, Identifiable {
    let id: UUID
    let label: String
    let property: String?
    let description: String?
    let kind: String
    let unit: String?
    let valueMin: Double?
    let valueMax: Double?
    let valueStep: Double?
    let values: [String]
    let endpoint: String?
    let isReadable: Bool
    let isWritable: Bool
    let isDiagnostic: Bool

    nonisolated init(expose: Expose) {
        self.id = UUID()
        self.label = expose.label ?? expose.name ?? expose.property ?? expose.type.capitalized
        self.property = expose.property
        self.description = expose.description
        self.kind = expose.type
        self.unit = expose.unit
        self.valueMin = expose.valueMin
        self.valueMax = expose.valueMax
        self.valueStep = expose.valueStep
        self.values = expose.values ?? []
        self.endpoint = expose.endpoint
        self.isReadable = expose.isReadable
        self.isWritable = expose.isWritable
        self.isDiagnostic = expose.isDiagnostic
    }

    /// The range with its unit, e.g. "0–254" or "153–500 mired".
    nonisolated var rangeText: String? {
        guard let valueMin, let valueMax else { return nil }
        let range = "\(Self.format(valueMin))–\(Self.format(valueMax))"
        guard let unit, !unit.isEmpty else { return range }
        return "\(range) \(unit)"
    }

    /// A short summary for the trailing side of a row.
    nonisolated var valueSummary: String? {
        if let rangeText { return rangeText }
        switch kind {
        case "binary": return "On, Off"
        case "enum" where values.count > 4: return "\(values.count) options"
        case "enum" where !values.isEmpty: return values.joined(separator: ", ")
        default: return unit?.isEmpty == false ? unit : nil
        }
    }

    nonisolated var accessText: String {
        switch (isReadable, isWritable) {
        case (true, true): "Read and write"
        case (true, false): "Read only"
        case (false, true): "Write only"
        case (false, false): "Reported in state"
        }
    }

    nonisolated var kindText: String {
        switch kind {
        case "numeric": "Number"
        case "binary": "On or off"
        case "enum": "Choice"
        case "text": "Text"
        case "list": "List"
        default: kind.capitalized
        }
    }

    private nonisolated static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
