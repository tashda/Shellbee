import SwiftUI

// Maps section titles to specialized renderers.
// To add a new specialized renderer:
//   1. Create MySectionView.swift in Shared/Components/Doc/
//   2. Add a `case "my section title":` branch below
// Unrecognized section titles fall through to DefaultDocSectionView.
enum DocSectionRegistry {
    @ViewBuilder
    static func view(for section: DocSection) -> some View {
        switch section.title.lowercased() {
        case "pairing":
            PairingSectionView(section: section)
        case "options":
            OptionsSectionView(section: section)
        default:
            DefaultDocSectionView(section: section)
        }
    }
}
