import SwiftUI

struct DefaultDocSectionView: View {
    let section: DocSection

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            SectionHeader(title: section.title)
            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                DocBlockView(block: block)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(iconColor.opacity(DesignTokens.Opacity.accentFill))
                    .frame(width: DesignTokens.Size.docSectionIconFrame,
                           height: DesignTokens.Size.docSectionIconFrame)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.title3.weight(.bold))
        }
    }

    private var iconName: String {
        switch title.lowercased() {
        case "pairing":              return "link.badge.plus"
        case "options":              return "slider.horizontal.3"
        case "notes":                return "note.text"
        case "exposes":              return "antenna.radiowaves.left.and.right"
        case "troubleshooting":      return "wrench.and.screwdriver"
        case "ota updates", "ota":   return "arrow.triangle.2.circlepath"
        case "configuration":        return "gear"
        case "usage":                return "hand.tap"
        default:                     return "doc.text"
        }
    }

    private var iconColor: Color {
        switch title.lowercased() {
        case "pairing":              return .blue
        case "options":              return Color(.systemGray)
        case "notes":                return .indigo
        case "exposes":              return .green
        case "troubleshooting":      return .orange
        case "ota updates", "ota":   return .teal
        case "configuration":        return Color(.systemGray)
        case "usage":                return .purple
        default:                     return Color(.systemGray)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.xl) {
            DefaultDocSectionView(section: DocSection(
                title: "Notes",
                level: 2,
                blocks: [
                    .paragraph([.text("IKEA lights only support transitions on "), .bold("1 attribute"), .text(" at a time.")]),
                    .note([.text("If you send both brightness and color-temperature, the color-temperature transition is ignored.")])
                ]
            ))
            DefaultDocSectionView(section: DocSection(
                title: "Pairing",
                level: 2,
                blocks: [
                    .stepList([
                        StepItem(number: 1, spans: [.text("Factory reset the bulb.")]),
                        StepItem(number: 2, spans: [.text("The bulb will "), .bold("automatically connect"), .text(".")])
                    ])
                ]
            ))
        }
        .padding()
    }
}
