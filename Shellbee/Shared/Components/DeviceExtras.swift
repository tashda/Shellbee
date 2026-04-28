import Foundation

/// Helpers for selecting the "leftover" leaf exposes that a category card does
/// not bind to a primary control. These get surfaced in
/// `…FeatureSections` views rendered as native iOS Settings sections beneath
/// the hero card.
enum DeviceExtras {
    /// Properties that must never appear in any feature section. These are
    /// either surfaced elsewhere (battery + linkquality on the device card)
    /// or noisy diagnostics that don't belong in a settings list.
    static let alwaysHiddenProperties: Set<String> = [
        "linkquality",
        "battery",
        "last_seen",
        "update",
        "update_available"
    ]

    /// Property prefixes we always hide. `identify` is a Zigbee diagnostic
    /// trigger that should never surface as a user-facing setting.
    static let alwaysHiddenPrefixes: [String] = ["identify"]

    /// Returns the leaf exposes that are eligible for a `…FeatureSections`
    /// rendering, after subtracting:
    /// - properties already bound to primary controls in the card
    /// - the `alwaysHiddenProperties` list
    /// - any property starting with `alwaysHiddenPrefixes`
    /// - composites with sub-features (those need bundled-payload writes that
    ///   the leaf renderer can't do; surface them via dedicated sheets)
    /// - non-renderable types (anything that isn't binary/enum/numeric/text)
    static func eligibleLeaves(
        from exposes: [Expose],
        primaryProps: Set<String>,
        extraExcludedProps: Set<String> = []
    ) -> [Expose] {
        exposes.filter { e in
            guard let prop = e.property, !prop.isEmpty else { return false }
            if primaryProps.contains(prop) { return false }
            if extraExcludedProps.contains(prop) { return false }
            if alwaysHiddenProperties.contains(prop) { return false }
            if alwaysHiddenPrefixes.contains(where: { prop.hasPrefix($0) }) { return false }
            if let f = e.features, !f.isEmpty { return false }
            switch e.type {
            case "binary", "enum", "numeric", "text": return true
            default: return false
            }
        }
    }
}
