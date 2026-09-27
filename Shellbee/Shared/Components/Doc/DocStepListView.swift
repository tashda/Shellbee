import SwiftUI

/// Numbered steps inside documentation prose. Numbers sit in a neutral
/// circle; colour is kept for state (see `DocStepNumber`'s checked form).
struct DocStepListView: View {
    let steps: [StepItem]
    let sourcePath: String?

    init(steps: [StepItem], sourcePath: String? = nil) {
        self.steps = steps
        self.sourcePath = sourcePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                    DocStepNumber(number: step.number)
                    DocInlineTextView(spans: step.spans, sourcePath: sourcePath)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// A step's number in a neutral circle, or a filled accent checkmark once
/// the step is done. Without a number it's an empty checklist circle.
struct DocStepNumber: View {
    var number: Int? = nil
    var isChecked: Bool = false

    var body: some View {
        ZStack {
            if isChecked {
                Circle()
                    .fill(.tint)
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
            } else if let number {
                Circle()
                    .fill(.fill.tertiary)
                Text("\(number)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            } else {
                Circle()
                    .strokeBorder(.tertiary, lineWidth: DesignTokens.Size.docCheckCircleStroke)
            }
        }
        .frame(width: DesignTokens.Size.docStepCircle, height: DesignTokens.Size.docStepCircle)
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + DesignTokens.Spacing.xs }
        .accessibilityHidden(true)
    }
}

#Preview {
    DocStepListView(steps: [
        StepItem(number: 1, spans: [.text("Factory reset the light bulb. Keep it close to the coordinator.")]),
        StepItem(number: 2, spans: [.text("After resetting, the bulb will "), .bold("automatically connect"), .text(".")])
    ])
    .padding()
}
