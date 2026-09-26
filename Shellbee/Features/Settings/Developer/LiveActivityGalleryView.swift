import SwiftUI

/// Lists every Live Activity; each opens on a stand-in Home Screen and Lock
/// Screen. The real surfaces only show an activity while the app is in the
/// background, so the stage draws the widget's own views instead.
struct LiveActivityGalleryView: View {
    @State private var staged: LiveActivityGalleryKind?

    var body: some View {
        List(LiveActivityGalleryKind.allCases) { kind in
            Button {
                staged = kind
            } label: {
                LabeledContent {
                    Text(kind.defaultStyle.name)
                } label: {
                    Label(kind.name, symbol: kind.symbol)
                }
            }
            .foregroundStyle(.primary)
        }
        .fullScreenCover(item: $staged) { kind in
            if #available(iOS 26.0, *) {
                LiveActivityStageView(kind: kind)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("The design on the right is the one each activity uses today. Open an activity to compare it with the alternatives.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
        .navigationTitle("Live Activity Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { LiveActivityGalleryView() }
}
