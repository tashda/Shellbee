import SwiftUI

struct DocStepListView: View {
    let steps: [StepItem]
    let sourcePath: String?

    init(steps: [StepItem], sourcePath: String? = nil) {
        self.steps = steps
        self.sourcePath = sourcePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                DocStepRow(step: step, showConnector: idx < steps.count - 1, sourcePath: sourcePath)
            }
        }
    }
}

private struct DocStepRow: View {
    let step: StepItem
    let showConnector: Bool
    let sourcePath: String?

    init(step: StepItem, showConnector: Bool, sourcePath: String?) {
        self.step = step
        self.showConnector = showConnector
        self.sourcePath = sourcePath
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(.tint)
                        .frame(width: DesignTokens.Size.docStepCircle,
                               height: DesignTokens.Size.docStepCircle)
                    Text("\(step.number)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                if showConnector {
                    Rectangle()
                        .fill(.tint.opacity(0.25))
                        .frame(width: DesignTokens.Size.docStepConnector)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: DesignTokens.Size.docStepCircle)

            DocInlineTextView(spans: step.spans, sourcePath: sourcePath)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, showConnector ? DesignTokens.Spacing.xl : 0)
        }
    }
}

#Preview {
    DocStepListView(steps: [
        StepItem(number: 1, spans: [.text("Factory reset the light bulb. Keep it close to the coordinator.")]),
        StepItem(number: 2, spans: [.text("After resetting, the bulb will "), .bold("automatically connect"), .text(".")]),
        StepItem(number: 3, spans: [.text("While pairing, keep the bulb "), .bold("close to the coordinator"), .text(" (adapter).")])
    ])
    .padding()
    .tint(.blue)
}
