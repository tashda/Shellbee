import SwiftUI

/// Only the Home canvas is themed. Card and row surfaces keep their shared
/// semantic style, and other tabs keep the platform grouped background.
struct HomeAmbientBackground: View {
    let theme: ShellbeeTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let colors = theme.homeMeshColors(for: colorScheme) {
            ZStack {
                mesh(colors)
                if let motifColor = theme.motifColor(for: colorScheme) {
                    HomeNetworkMotif(color: motifColor)
                }
            }
        } else {
            Color(.systemGroupedBackground)
        }
    }

    @ViewBuilder
    private func mesh(_ colors: [Color]) -> some View {
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
    }
}

private struct HomeNetworkMotif: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing = DesignTokens.HomeTheme.networkSpacing
            let radius = DesignTokens.HomeTheme.networkNodeDiameter / 2
            let rows = Int(size.height / spacing) + 1
            let columns = Int(size.width / spacing) + 1

            for row in 0...rows {
                let y = CGFloat(row) * spacing
                let offset = row.isMultiple(of: 2) ? CGFloat.zero : spacing / 2
                for column in 0...columns {
                    let x = CGFloat(column) * spacing + offset
                    let node = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: node), with: .color(color))

                    guard row < rows else { continue }
                    var link = Path()
                    link.move(to: CGPoint(x: x, y: y))
                    link.addLine(to: CGPoint(x: x + (row.isMultiple(of: 2) ? spacing / 2 : -spacing / 2),
                                             y: y + spacing))
                    context.stroke(link, with: .color(color),
                                   lineWidth: DesignTokens.HomeTheme.networkLineWidth)
                }
            }
        }
        .opacity(DesignTokens.HomeTheme.networkOpacity)
        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        .accessibilityHidden(true)
    }
}
