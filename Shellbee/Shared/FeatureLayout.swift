import Foundation
import SwiftUI

/// One bucket on a device card — title + ordered list of items.
struct LayoutSection: Identifiable, Equatable {
    let id: FeatureCategory
    let title: String
    let items: [LayoutItem]
}

/// A single rendered unit inside a section: a leaf row, or an indexed-family
/// disclosure (e.g. `speed1…speed4` → one "Speeds" row that opens a sheet).
enum LayoutItem: Identifiable, Equatable {
    case row(Expose)
    case indexedGroup(IndexedGroup)

    var id: String {
        switch self {
        case .row(let e):           return "row:\(e.property ?? e.name ?? "")"
        case .indexedGroup(let g):  return "group:\(g.prefix)"
        }
    }
}

/// A detected family of properties sharing a common alphabetic prefix and an
/// integer suffix forming a contiguous range. Rendered as one disclosure row
/// → opens a sheet with the members inside.
struct IndexedGroup: Identifiable, Equatable {
    let prefix: String
    let label: String
    let symbol: String
    let tint: Color
    let category: FeatureCategory
    let members: [Expose]

    var id: String { prefix }
}

enum FeatureLayout {
    /// Group exposes by their semantic `FeatureCategory`, detecting indexed
    /// families along the way. Sections come back in canonical display order
    /// and only non-empty ones are returned.
    static func sections(from exposes: [Expose]) -> [LayoutSection] {
        let groups = detectIndexedGroups(in: exposes)
        let claimed: Set<String> = Set(groups.flatMap { $0.members.compactMap(\.property) })

        var buckets: [FeatureCategory: [LayoutItem]] = [:]
        for group in groups {
            buckets[group.category, default: []].append(.indexedGroup(group))
        }
        for e in exposes {
            guard let prop = e.property, !claimed.contains(prop) else { continue }
            let meta = FeatureCatalog.meta(for: prop, exposeType: e.type)
            buckets[meta.category, default: []].append(.row(e))
        }

        return displayOrder.compactMap { cat in
            guard let items = buckets[cat], !items.isEmpty else { return nil }
            return LayoutSection(id: cat, title: title(for: cat), items: items)
        }
    }

    private static let displayOrder: [FeatureCategory] = [
        .behaviour, .indicator, .maintenance, .sensor, .advanced
    ]

    private static func title(for category: FeatureCategory) -> String {
        switch category {
        case .operation:    return "Controls"
        case .sensor:       return "Status"
        case .maintenance:  return "Maintenance"
        case .behaviour:    return "Behaviour"
        case .indicator:    return "Indicators"
        case .diagnostic:   return "Diagnostics"
        case .advanced:     return "More"
        }
    }

    // MARK: - Indexed-group detection

    /// Find families where the property name is `<prefix><N>` (with optional
    /// `_` separator) and the suffixes form a contiguous integer range. We
    /// require:
    ///   • prefix ≥ 3 letters (rules out `pm10` / `pm25` paired by "pm")
    ///   • ≥ 2 members
    ///   • indices are contiguous (no gaps) — guards against false positives
    ///     when a device exposes scattered numeric scientific names.
    private static func detectIndexedGroups(in exposes: [Expose]) -> [IndexedGroup] {
        var families: [String: [(index: Int, expose: Expose)]] = [:]

        for e in exposes {
            guard let prop = e.property,
                  let (prefix, idx) = splitIndex(from: prop),
                  prefix.count >= 3 else { continue }
            families[prefix, default: []].append((idx, e))
        }

        return families.compactMap { prefix, raw -> IndexedGroup? in
            guard raw.count >= 2 else { return nil }
            let sorted = raw.sorted { $0.index < $1.index }
            let indices = sorted.map(\.index)
            guard isContiguous(indices) else { return nil }

            let firstType = sorted.first?.expose.type ?? ""
            let prefixMeta = FeatureCatalog.meta(for: prefix, exposeType: firstType)
            return IndexedGroup(
                prefix: prefix,
                label: pluralLabel(for: prefix, fallback: prefixMeta.label),
                symbol: prefixMeta.symbol,
                tint: prefixMeta.tint,
                category: prefixMeta.category,
                members: sorted.map(\.expose)
            )
        }
        .sorted { $0.prefix < $1.prefix }
    }

    /// Split `speed1` / `speed_4` / `loadLevel2` into ("speed", 1) / ("speed", 4) / ("loadLevel", 2).
    private static func splitIndex(from property: String) -> (prefix: String, index: Int)? {
        var digits = ""
        var letters = property
        while let last = letters.last, last.isNumber {
            digits = String(last) + digits
            letters.removeLast()
        }
        guard !digits.isEmpty, let idx = Int(digits) else { return nil }
        // Trim a single trailing separator from the prefix.
        if let last = letters.last, last == "_" || last == "-" {
            letters.removeLast()
        }
        guard !letters.isEmpty else { return nil }
        return (letters, idx)
    }

    private static func isContiguous(_ sorted: [Int]) -> Bool {
        guard let first = sorted.first, let last = sorted.last else { return false }
        return last - first == sorted.count - 1
    }

    private static func pluralLabel(for prefix: String, fallback: String) -> String {
        // If the prefix itself is curated, pluralize lightly; otherwise smart-title it.
        let base = fallback.isEmpty ? FeatureCatalog.smartTitle(prefix) : fallback
        if base.hasSuffix("s") { return base }
        return base + "s"
    }
}
