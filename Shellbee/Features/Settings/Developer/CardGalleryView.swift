import SwiftUI

/// A developer-only catalog of every device card and its native rows. Unlike
/// previews, this stays inside a real grouped List so card/section boundaries,
/// picker rows and sliders can be judged together.
struct CardGalleryView: View {
    @State private var searchText = ""

    private var samples: [CardGallerySample] {
        guard !searchText.isEmpty else { return CardGalleryCatalog.samples }
        return CardGalleryCatalog.samples.filter {
            $0.title.localizedStandardContains(searchText)
                || $0.detail.localizedStandardContains(searchText)
                || $0.device.category.label.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Text("Each example uses a real Device definition and state payload. Cards are followed by the settings, readings, diagnostics or activity rows that appear beneath them in the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                CardGalleryGroupSurface()
            } header: {
                Label("Gallery Group", systemImage: "rectangle.3.group")
            } footer: {
                Text("A uniform light group: the group identity, group control, member rows, scenes and synthesized state shown together.")
            }

            ForEach(samples) { sample in
                Section {
                    CardGalleryDeviceSurface(sample: sample)
                } header: {
                    Label(sample.title, systemImage: sample.device.category.systemImage)
                } footer: {
                    Text(sample.detail)
                }
            }
        }
        .navigationTitle("Card Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Find a card or device")
    }
}

private struct CardGalleryGroupSurface: View {
    let group = CardGalleryCatalog.group
    let memberDevices = CardGalleryCatalog.groupMembers
    let state = CardGalleryCatalog.groupState

    var body: some View {
        GroupCard(
            group: group,
            memberDevices: memberDevices,
            state: state,
            membersOnCount: 2
        )
        .galleryCardRow()

        if let context = LightControlContext(device: memberDevices[0], state: state) {
            LightControlCard(context: context, mode: .interactive, onSend: { _ in })
                .galleryCardRow()
        }

        PayloadSectionsView(payload: state, device: memberDevices[0])

        Section("Members") {
            ForEach(Array(zip(group.members, memberDevices)), id: \.0.ieeeAddress) { member, device in
                GroupMemberRow(member: member, device: device, state: state, isAvailable: true)
            }
        }

        Section("Scenes") {
            ForEach(group.scenes) { scene in
                LabeledContent(scene.name) { Text("ID \(scene.id)") }
            }
        }
    }
}

private struct CardGalleryDeviceSurface: View {
    let sample: CardGallerySample

    var body: some View {
        let device = sample.device
        let state = sample.state
        let send: (JSONValue) -> Void = { _ in }

        DeviceCard(
            device: device,
            state: state,
            isAvailable: sample.isAvailable,
            otaStatus: nil,
            lastSeenEnabled: true
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        switch device.category {
        case .light:
            if let context = LightControlContext(device: device, state: state) {
                LightControlCard(context: context, mode: .interactive, onSend: send, rendersAdvancedSheetsInline: false)
                    .galleryCardRow()
                LightFeatureSections(context: context, onSend: send)
            }
        case .switchPlug:
            ExposeCardView(device: device, state: state, mode: .interactive, onSend: send)
                .galleryCardRow()
            if let context = SwitchControlContext(device: device, state: state) {
                DeviceSettingsSections(device: device, state: state, claimedProperties: Self.switchProperties(context), onSend: send)
            }
        case .sensor:
            SensorSections(device: device, state: state)
            DeviceSettingsSections(
                device: device,
                state: state,
                claimedProperties: SensorSections.readingProperties(device: device, state: state),
                onSend: send
            )
        case .climate:
            if let context = ClimateControlContext(device: device, state: state) {
                ClimateControlCard(context: context, mode: .interactive, onSend: send)
                    .galleryCardRow()
                ClimateFeatureSections(device: device, context: context, state: state, onSend: send)
            }
        case .cover:
            if let context = CoverControlContext(device: device, state: state) {
                CoverControlCard(context: context, mode: .interactive, onSend: send)
                    .galleryCardRow()
                CoverFeatureSections(device: device, context: context, state: state, onSend: send)
            }
        case .lock:
            if let context = LockControlContext(device: device, state: state) {
                LockControlCard(context: context, mode: .interactive, onSend: send)
                    .galleryCardRow()
                DeviceSettingsSections(device: device, state: state, claimedProperties: Set([context.stateFeature?.property].compactMap { $0 }), onSend: send)
            }
        case .fan:
            if let context = FanControlContext(device: device, state: state) {
                FanControlCard(context: context, mode: .interactive, onSend: send)
                    .galleryCardRow()
                FanReadingsSections(context: context)
                FanFeatureSections(context: context, onSend: send)
            }
        case .remote:
            RemoteSections(device: device, state: state)
            DeviceSettingsSections(device: device, state: state, claimedProperties: RemoteSections.claimedProperties, onSend: send)
        case .other:
            DeviceSettingsSections(device: device, state: state, onSend: send)
        }
    }

    private static func switchProperties(_ context: SwitchControlContext) -> Set<String> {
        [context.stateFeature, context.powerFeature, context.energyFeature, context.voltageFeature, context.currentFeature]
            .compactMap { $0?.property }
            .reduce(into: Set<String>()) { $0.insert($1) }
    }
}

private extension View {
    func galleryCardRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack { CardGalleryView() }
}
