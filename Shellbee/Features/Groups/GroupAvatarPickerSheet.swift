import SwiftUI

struct GroupAvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let group: Group
    let memberDevices: [Device]
    @Binding var selectedIEEEs: [String]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if memberDevices.isEmpty {
                        Text("This group has no members yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(memberDevices, id: \.ieeeAddress) { device in
                            Button {
                                toggle(device)
                            } label: {
                                row(for: device)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text("Pick up to two members. Selecting a third replaces the earliest pick. Leave both unchecked to fall back to the default.")
                }
            }
            .navigationTitle("Group Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedIEEEs = []
                        save()
                    }
                    .disabled(selectedIEEEs.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func row(for device: Device) -> some View {
        let isSelected = selectedIEEEs.contains(device.ieeeAddress)
        let order = selectedIEEEs.firstIndex(of: device.ieeeAddress).map { $0 + 1 }
        HStack(spacing: DesignTokens.Spacing.md) {
            DeviceImageView(device: device, isAvailable: true,
                            size: DesignTokens.Size.deviceActionSheetImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.friendlyName)
                    .foregroundStyle(.primary)
                Text(device.definition?.model ?? device.modelId ?? device.ieeeAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let order {
                Text("\(order)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(.tint, in: Circle())
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func toggle(_ device: Device) {
        if let idx = selectedIEEEs.firstIndex(of: device.ieeeAddress) {
            selectedIEEEs.remove(at: idx)
        } else {
            selectedIEEEs.append(device.ieeeAddress)
            if selectedIEEEs.count > 2 {
                selectedIEEEs.removeFirst(selectedIEEEs.count - 2)
            }
        }
    }

    private func save() {
        GroupAvatarStore.save(selectedIEEEs, for: group)
    }
}
