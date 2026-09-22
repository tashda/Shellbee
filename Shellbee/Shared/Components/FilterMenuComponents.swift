import SwiftUI

// Shared building blocks for every Filter menu, so each one follows the
// same layout:
//
//   1. Bridge            — only when two or more bridges are connected
//   2. Page filters      — one submenu each. Filters that appear on several
//                          pages keep the same relative order: Status/Level,
//                          then Type/Category, then Manufacturer/Namespace,
//                          then Network Role/Device.
//   3. Display options   — toggles that change what is shown, after a divider
//   4. Clear Filters     — last, after a divider, only while a filter is set
//
// Each submenu is titled with the filter name, and reads "Name: Value" with
// the value's icon once set. Its first choice is always "All …".

/// Toolbar label for a Filter menu; fills while any filter is active.
struct FilterMenuLabel: View {
    let isActive: Bool

    var body: some View {
        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            .symbolVariant(isActive ? .fill : .none)
    }
}

/// Title of one filter submenu: "Status" when unset, "Status: Offline" once
/// a value is picked.
struct FilterSubmenuLabel: View {
    let name: String
    let systemImage: String
    var value: String? = nil
    var valueSystemImage: String? = nil

    var body: some View {
        if let value {
            Label("\(name): \(value)", systemImage: valueSystemImage ?? systemImage)
        } else {
            Label(name, systemImage: systemImage)
        }
    }
}

/// Icon for every "All …" choice, so resetting a single filter looks the
/// same in every menu.
enum FilterMenuSymbol {
    static let all = "square.grid.2x2"
    static let bridge = "antenna.radiowaves.left.and.right"
    static let clear = "xmark.circle"
}

/// The Bridge submenu shared by every multi-bridge Filter menu.
struct BridgeFilterMenu: View {
    @Binding var selection: UUID?
    let sessions: [BridgeSession]

    var body: some View {
        Menu {
            Picker("Bridge", selection: $selection) {
                Label("All Bridges", systemImage: FilterMenuSymbol.all)
                    .tag(UUID?.none)
                ForEach(sessions, id: \.bridgeID) { session in
                    Text(session.displayName).tag(UUID?.some(session.bridgeID))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(
                name: "Bridge",
                systemImage: FilterMenuSymbol.bridge,
                value: sessions.first { $0.bridgeID == selection }?.displayName
            )
        }
    }
}

/// The closing "Clear Filters" item of a Filter menu, preceded by a divider.
/// Renders nothing while no filter is set.
struct ClearFiltersMenuItem: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        if isActive {
            Divider()
            Button(role: .destructive, action: action) {
                Label("Clear Filters", systemImage: FilterMenuSymbol.clear)
            }
        }
    }
}

/// One-tap "Clear Filters" button placed in a toolbar's Filter group, next
/// to the Filter menu, while any filter is set.
struct ClearFiltersToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Clear Filters", systemImage: FilterMenuSymbol.clear)
        }
        .accessibilityIdentifier("clear-filters")
    }
}
