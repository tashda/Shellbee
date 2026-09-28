import SwiftUI

struct CopyableRow: View {
    let label: String
    let value: String

    var body: some View {
        Button {
            UIPasteboard.general.string = value
        } label: {
            LabeledContent(label, value: value)
        }
        .buttonStyle(.plain)
    }
}
