import SwiftUI

/// Horizontally scrolling filter bubbles above the results. A bubble only
/// appears when its category has matches, so the bar never offers a filter
/// that would show an empty list. The selected bubble always stays visible.
struct GlobalSearchScopeBar: View {
    @Binding var selection: GlobalSearchScope
    let results: GlobalSearchResults

    private var visibleScopes: [GlobalSearchScope] {
        GlobalSearchScope.allCases.filter { scope in
            scope == .all || scope == selection || results.count(for: scope) > 0
        }
    }

    var body: some View {
        GlassChipRow {
            ForEach(visibleScopes) { scope in
                SelectableFilterChip(
                    title: scope.title,
                    isSelected: selection == scope,
                    systemImage: scope.symbol,
                    count: results.count(for: scope)
                ) {
                    selection = scope
                }
                .accessibilityLabel(Text("\(scope.title), ^[\(results.count(for: scope)) result](inflect: true)"))
            }
        }
        .animation(.snappy, value: visibleScopes)
    }
}
