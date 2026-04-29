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
    let exposesSummary: String?
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

struct DeviceDocCapability: Sendable, Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let summary: String
    let kind: String
    let unit: String?
    let isReadable: Bool
    let isWritable: Bool
    let detailChips: [String]

    nonisolated init(
        title: String,
        subtitle: String? = nil,
        summary: String,
        kind: String,
        unit: String? = nil,
        isReadable: Bool,
        isWritable: Bool,
        detailChips: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.kind = kind
        self.unit = unit
        self.isReadable = isReadable
        self.isWritable = isWritable
        self.detailChips = detailChips
    }
}
