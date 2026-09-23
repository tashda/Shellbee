import SwiftUI

/// Only the Home canvas is themed. Card and row surfaces keep their shared
/// semantic style, and other tabs keep the platform grouped background.
struct HomeAmbientBackground: View {
    let theme: ShellbeeTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let colors = theme.homeMeshColors(for: colorScheme) {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        .init(0, 0), .init(0.5, 0), .init(1, 0),
                        .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                        .init(0, 1), .init(0.5, 1), .init(1, 1),
                    ],
                    colors: colors
                )
            } else {
                LinearGradient(
                    colors: [colors[0], colors[4], colors[8]],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            Color(.systemGroupedBackground)
        }
    }
}
