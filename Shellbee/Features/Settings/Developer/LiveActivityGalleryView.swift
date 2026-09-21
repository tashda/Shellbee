import SwiftUI

/// Lists every Live Activity so each can be reviewed on its own page. The
/// real Lock Screen and Dynamic Island only show an activity while the app is
/// in the background, so this gallery draws the widget's own views instead.
struct LiveActivityGalleryView: View {
    var body: some View {
        List(LiveActivityGalleryKind.allCases) { kind in
            NavigationLink {
                LiveActivityGalleryDetailView(kind: kind)
            } label: {
                Label(kind.name, symbol: kind.symbol)
            }
        }
        .navigationTitle("Live Activity Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { LiveActivityGalleryView() }
}
