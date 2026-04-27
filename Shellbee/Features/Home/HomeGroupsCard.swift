import SwiftUI

struct HomeGroupsCard: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HomeCardContainer {
                HStack(alignment: .center) {
                    HomeCardTitle(symbol: "rectangle.3.group.fill", title: "Groups", tint: .green)
                    Spacer()
                    Text("\(count)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(HomeCardButtonStyle())
    }
}

struct HomeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}
