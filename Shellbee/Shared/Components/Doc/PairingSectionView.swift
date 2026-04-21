import SwiftUI

// Renders the "Pairing" section with visual emphasis on numbered steps.
// Used both in DeviceDocView (inline) and DevicePairingSheet (focused sheet).
// The section header is shown when displayed inline; the sheet provides its own title.
struct PairingSectionView: View {
    let section: DocSection
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if showHeader {
                SectionHeader(title: section.title)
            }

            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                DocBlockView(block: block)
            }
        }
    }
}

#Preview {
    ScrollView {
        PairingSectionView(section: DocSection(
            title: "Pairing",
            level: 2,
            blocks: [
                .stepList([
                    StepItem(number: 1, spans: [.text("Factory reset the light bulb ("), .link(label: "video", url: "https://youtube.com"), .text(").")]),
                    StepItem(number: 2, spans: [.text("After resetting, the bulb will "), .bold("automatically connect"), .text(".")]),
                    StepItem(number: 3, spans: [.text("While pairing, keep the bulb "), .bold("close to the coordinator"), .text(" (adapter).")])
                ]),
                .note([.text("Use very short on/off cycles. Start with bulb on, then off, then 6 on's — wait for the 6th ON state.")])
            ]
        ))
        .padding()
    }
}
