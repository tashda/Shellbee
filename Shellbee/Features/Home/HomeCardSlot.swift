import SwiftUI

struct HomeCardSlot<Content: View>: View {
    let card: HomeCardID
    let isEditing: Bool
    let onHide: () -> Void
    let onEnterEdit: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .opacity(isEditing ? 0.75 : 1)
            .overlay(alignment: .topLeading) {
                if isEditing {
                    Button(action: onHide) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide \(card.title)")
                    .offset(x: -8, y: -8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .contextMenu {
                if !isEditing {
                    Button(role: .destructive) { onHide() } label: {
                        Label("Hide \(card.title)", systemImage: "eye.slash")
                    }
                    Button { onEnterEdit() } label: {
                        Label("Edit Home", systemImage: "square.grid.2x2")
                    }
                }
            }
    }
}
