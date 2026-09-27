import SwiftUI

/// iPad sidebar sections for the Device Library: the models in your network,
/// every entry, then one row per device type. The selected slice fills the
/// content column.
struct DocLibraryWorkspaceFilters: View {
    @Binding var scope: DocLibraryScope
    let entries: [DocBrowserEntry]

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Section {
            ForEach([DocLibraryScope.owned, .all], id: \.self) { item in
                scopeButton(item)
            }
        }
        Section("Types") {
            ForEach(typeScopes, id: \.self) { item in
                scopeButton(item)
            }
        }
    }

    private var typeScopes: [DocLibraryScope] {
        let types = DocDeviceType.allCases.map(DocLibraryScope.type)
        return entries.contains { $0.deviceType == nil } ? types + [.other] : types
    }

    private func scopeButton(_ item: DocLibraryScope) -> some View {
        let isSelected = scope == item
        return Button {
            scope = item
        } label: {
            HStack {
                Label(item.title, systemImage: item.systemImage)
                Spacer()
                Text(count(for: item).formatted())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func count(for item: DocLibraryScope) -> Int {
        item.entries(from: entries, owned: environment.ownedLibraryModels).count
    }
}
