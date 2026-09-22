import SwiftUI

/// Lists every card family. Each opens on a full device or group detail page,
/// matching the context where that card ships instead of squeezing all cards
/// into a comparison list.
struct CardGalleryView: View {
    @State private var staged: StagedCard?

    var body: some View {
        List(CardGalleryCatalog.previews.indices, id: \.self) { index in
            let preview = CardGalleryCatalog.previews[index]
            Button {
                staged = StagedCard(index: index)
            } label: {
                LabeledContent {
                    Text(preview.detail)
                } label: {
                    Label(preview.title, systemImage: preview.symbol)
                }
            }
            .foregroundStyle(.primary)
        }
        .fullScreenCover(item: $staged) { staged in
            if #available(iOS 26.0, *) {
                CardGalleryStageView(
                    previews: CardGalleryCatalog.previews,
                    startIndex: staged.index
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Open a card to inspect it on the device or group page where it ships, together with the rows beneath it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
        .navigationTitle("Card Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct StagedCard: Identifiable {
        let index: Int
        var id: Int { index }
    }
}

#Preview {
    NavigationStack { CardGalleryView() }
}
