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
                Label(kind.name, symbol: kind.symbol)
            }
        }
        .fullScreenCover(item: $staged) { kind in
            if #available(iOS 26.0, *) {
                LiveActivityStageView(kind: kind)
            }
        }
        .navigationTitle("Live Activity Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { LiveActivityGalleryView() }
}
