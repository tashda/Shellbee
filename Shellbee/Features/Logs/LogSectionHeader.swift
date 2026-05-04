import SwiftUI

/// Section header used by the Activity Log to chunk rows by time bucket.
/// Plain List's default header is small all-caps tracked text — visually it
/// reads as a system label, not a section title. This replaces it with a
/// title-weight string that mirrors what Apple uses in Mail's mailbox list
/// (medium weight, primary tint, slightly inset).
struct LogSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

#Preview {
    List {
        Section {
            Text("Row 1")
            Text("Row 2")
        } header: {
            LogSectionHeader(title: "Earlier today")
        }
        Section {
            Text("Row 3")
        } header: {
            LogSectionHeader(title: "Yesterday")
        }
    }
    .listStyle(.plain)
}
