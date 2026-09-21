import SwiftUI

/// Exhaustive design harness for the proposed Activity Center instruments.
/// Samples cover every structural Z2M expose type and Shellbee event family;
/// model-specific properties use the custom-property fallback.
struct ActivityInstrumentGalleryView: View {
    @State private var scope: ActivityInstrumentGalleryScope = .all
    @State private var searchText = ""
    @State private var colorScheme: ColorScheme = .light
    @State private var showsCompactSize = true

    private var samples: [ActivityInstrumentGallerySample] {
        ActivityInstrumentGalleryCatalog.filtered(scope: scope, searchText: searchText)
    }

    var body: some View {
        List {
            controls
            coverageSummary

            ForEach(visibleSections, id: \.self) { section in
                Section(section) {
                    ForEach(samples.filter { $0.section == section }) { sample in
                        sampleRow(sample)
                    }
                }
            }
        }
        .environment(\.colorScheme, colorScheme)
        .navigationTitle("Activity Instruments")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Find a device, change, or activity")
    }

    private var visibleSections: [String] {
        ActivityInstrumentGalleryCatalog.sections.filter { section in
            samples.contains { $0.section == section }
        }
    }

    private var controls: some View {
        Section {
            Picker("Appearance", selection: $colorScheme) {
                Text("Light").tag(ColorScheme.light)
                Text("Dark").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)

            Picker("Coverage", selection: $scope) {
                ForEach(ActivityInstrumentGalleryScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Show Compact Size", isOn: $showsCompactSize)
        } header: {
            Text("Preview")
        }
    }

    private var coverageSummary: some View {
        Section {
            LabeledContent("Visible Samples", value: samples.count.formatted())
            LabeledContent("Instrument Families", value: ActivityInstrumentKind.allCases.count.formatted())
            LabeledContent("Z2M Expose Shapes", value: ActivityInstrumentGalleryCatalog.requiredExposeTypes.count.formatted())
        } footer: {
            Text("Every Shellbee device and event category is represented. Unknown Z2M properties and future bridge events use explicit fallback instruments.")
        }
    }

    private func sampleRow(_ sample: ActivityInstrumentGallerySample) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.ActivityInstrument.rowSpacing) {
            ActivityInstrumentView(instrument: sample.instrument)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(sample.title)
                    .font(.subheadline.weight(.semibold))
                Text(sample.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let topic = sample.bridgeTopic {
                    Text(topic)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if showsCompactSize {
                ActivityInstrumentView(
                    instrument: sample.instrument,
                    size: DesignTokens.ActivityInstrument.compactSize
                )
            }
        }
        .padding(.vertical, DesignTokens.ActivityInstrument.rowVerticalPadding)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ActivityInstrumentGalleryView()
    }
}
