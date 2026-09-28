import Foundation

/// Custom symbol assets and every drawn instrument used by Shellbee.
/// Keep the symbol list in step with Assets.xcassets/Custom Icons.
struct IconGallerySample: Identifiable {
    enum Artwork {
        case symbol(ShellbeeSymbol)
        case instrument(ActivityInstrument)
    }

    let id: String
    let title: String
    let section: String
    let artwork: Artwork

    var assetName: String {
        if id.hasPrefix("variant.") { return String(id.dropFirst("variant.".count)) }
        return switch artwork {
        case .symbol(let symbol): symbol.name
        case .instrument(let instrument): instrument.kind.rawValue
        }
    }

    static let symbols: [Self] = [
        symbol("Home", "home", section: "Navigation"),
        symbol("Devices", "devices", section: "Navigation"),
        symbol("Groups", "groups", section: "Navigation"),
        symbol("Activity", "activity", section: "Navigation"),
        symbol("Mesh", "mesh", section: "Navigation"),
        symbol("Bridge", "bridge", section: "Navigation"),
        symbol("Search", "search", section: "Navigation"),
        symbol("Settings", "settings", section: "Navigation"),
        symbol("Device library", "library", section: "Navigation"),
        symbol("Permit join", "permitjoin", section: "Actions"),
        symbol("Touchlink", "touchlink", section: "Actions"),
        symbol("Identify", "identify", section: "Actions"),
        symbol("Firmware", "firmware", section: "Actions"),
        symbol("Follow live", "followlive", section: "Actions")
    ]

    private static let cardKinds: [ActivityInstrumentKind] = [
        .health, .vendors, .network, .signal, .battery,
        .models, .energy, .pairing, .update
    ]

    static let instruments: [Self] = (cardKinds + ActivityInstrumentKind.allCases.filter { !cardKinds.contains($0) }).map { kind in
        Self(
            id: "instrument.\(kind.rawValue)",
            title: kind.rawValue
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized,
            section: cardKinds.contains(kind) ? "Card instruments" : "Activity instruments",
            artwork: .instrument(.init(kind: kind))
        )
    }

    static let variants: [Self] = [
        variant("Fan", "fan", kind: .level, variant: .fan),
        variant("Contact", "contact", kind: .binary, variant: .contact),
        variant("Lock", "lock", kind: .binary, variant: .lock),
        variant("Permit join", "permitJoin", kind: .pairing, variant: .permitJoin),
        variant("Availability", "availability", kind: .lifecycle, variant: .availability),
        variant("Rename", "rename", kind: .lifecycle, variant: .rename),
        variant("Remove", "remove", kind: .lifecycle, variant: .remove),
        Self(id: "variant.message.warning", title: "Warning", section: "Instrument variants",
             artwork: .instrument(.init(kind: .message, severity: .warning))),
        Self(id: "variant.message.failure", title: "Failure", section: "Instrument variants",
             artwork: .instrument(.init(kind: .message, severity: .failure)))
    ]

    static let all = symbols + instruments + variants
    static let sections = ["Card instruments", "Navigation", "Actions", "Activity instruments", "Instrument variants"]

    private static func symbol(_ title: String, _ name: String, section: String) -> Self {
        Self(id: "symbol.\(name)", title: title, section: section, artwork: .symbol(.custom(name)))
    }

    private static func variant(
        _ title: String, _ name: String, kind: ActivityInstrumentKind, variant: ActivityInstrumentVariant
    ) -> Self {
        Self(id: "variant.\(name)", title: title, section: "Instrument variants",
             artwork: .instrument(.init(kind: kind, variant: variant)))
    }
}
