import SwiftUI

/// Draggable capsule whose fill shows a value across a range. Drag to set
/// the value; a tap runs `onTap` (the Light card uses it to toggle power).
/// Shared by Light brightness and Cover position and tilt.
struct ValueCapsule: View {
    let value: Double
    let range: ClosedRange<Double>
    let fillColor: Color
    let systemImage: String
    let label: (Double) -> String
    var isInteractive: Bool = true
    let onChange: (Double) -> Void
    var onTap: (() -> Void)? = nil

    @State private var draftValue: Double
    @State private var isDragging = false

    init(value: Double, range: ClosedRange<Double>, fillColor: Color, systemImage: String,
         isInteractive: Bool = true, label: @escaping (Double) -> String,
         onChange: @escaping (Double) -> Void, onTap: (() -> Void)? = nil) {
        self.value = value
        self.range = range
        self.fillColor = fillColor
        self.systemImage = systemImage
        self.isInteractive = isInteractive
        self.label = label
        self.onChange = onChange
        self.onTap = onTap
        _draftValue = State(initialValue: value)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Rectangle()
                    .fill(fillColor)
                    .frame(width: max(0, proxy.size.width * fraction))
                    .animation(isDragging ? .none : .spring(response: 0.35, dampingFraction: 1), value: fraction)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.formRowIconBold)
                        .contentTransition(.symbolEffect(.replace))
                    Spacer()
                    Text(label(draftValue))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .disabled(!isInteractive)
            .gesture(gesture(totalWidth: proxy.size.width))
        }
        .frame(height: DesignTokens.Size.valueCapsuleHeight)
        .onChange(of: value) { _, v in
            guard !isDragging else { return }
            draftValue = v
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(label(draftValue))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 10
            let next = direction == .increment ? draftValue + step : draftValue - step
            draftValue = min(max(next, range.lowerBound), range.upperBound)
            onChange(draftValue)
        }
    }

    private var fraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return max(0, min(1, (draftValue - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }

    private func gesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                guard hypot(g.translation.width, g.translation.height) > DesignTokens.Size.capsuleDragThreshold else { return }
                isDragging = true
                draftValue = valueAt(x: g.location.x, totalWidth: totalWidth)
            }
            .onEnded { g in
                defer { isDragging = false }
                if hypot(g.translation.width, g.translation.height) < DesignTokens.Size.capsuleDragThreshold {
                    onTap?()
                } else {
                    let final = valueAt(x: g.location.x, totalWidth: totalWidth)
                    draftValue = final
                    onChange(final)
                }
            }
    }

    private func valueAt(x: CGFloat, totalWidth: CGFloat) -> Double {
        let f = max(0, min(1, x / totalWidth))
        return range.lowerBound + f * (range.upperBound - range.lowerBound)
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        ValueCapsule(value: 64, range: 0...100, fillColor: .orange.opacity(0.35),
                     systemImage: "blinds.horizontal.open",
                     label: { "\(Int($0)) %" }, onChange: { _ in })
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
