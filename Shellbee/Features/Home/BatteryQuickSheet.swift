import SwiftUI

/// A battery at a glance, opened from the Batteries card or page: level,
/// last report, when it was last replaced, and the two things you'd do
/// next — open the device, or note that you've just replaced it.
struct BatteryQuickSheet: View {
    let reading: HomeDeviceReading
    let onOpenDevice: (DeviceRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var log = BatteryReplacementLog.shared

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Group {
                    Section {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            DeviceImageView(device: reading.device, isAvailable: true,
                                            size: DesignTokens.Size.summaryRowSymbolFrame,
                                            showsAvailabilityIndicator: false)
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                Text(reading.name).font(.headline)
                                Text(reading.device.cardSubtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    Section {
                        LabeledContent("Battery") {
                            Text("\(reading.battery ?? 0) %")
                                .foregroundStyle(.status(reading.battery?.batteryTone ?? .poor))
                                .monospacedDigit()
                        }
                        LabeledContent("Last report") {
                            if let lastSeen = reading.lastSeen {
                                Text(lastSeen, format: .relative(presentation: .named))
                            } else {
                                Text("Unknown")
                            }
                        }
                        if let replaced = log.replacedDate(for: reading) {
                            LabeledContent("Replaced") {
                                Text(replaced, format: .dateTime.day().month().year())
                            }
                        }
                        if let source = reading.device.powerSource, !source.isEmpty {
                            LabeledContent("Power source", value: source)
                        }
                    }
                }
                .shellbeeThemedRows()
            }
            .shellbeeThemedCanvas()
            .navigationTitle("Battery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button("Mark Replaced") { log.markReplaced(reading) }
                        .buttonStyle(.sheetSecondaryAction)
                    Button("Open Device") {
                        dismiss()
                        onOpenDevice(reading.route)
                    }
                    .buttonStyle(.sheetAction)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
                .shellbeeThemedBar()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
