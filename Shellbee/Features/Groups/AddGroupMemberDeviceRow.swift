import SwiftUI

struct AddGroupMemberDeviceRow: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device
    let isSelected: Bool
    let selectedEndpoint: Int
    let onTap: () -> Void
    let onEndpointChange: (Int) -> Void

    private var endpoints: [Int] { device.availableEndpoints }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                DeviceImageView(
                    device: device,
                    isAvailable: environment.store.isAvailable(device.friendlyName),
                    size: DesignTokens.Size.summaryRowSymbolFrame
                )

                VStack(alignment: .leading, spacing: 0) {
                    if let vendor = device.definition?.vendor {
                        Text(vendor.uppercased())
                            .font(.system(size: DesignTokens.Size.chipSymbol, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(DesignTokens.Opacity.secondaryText))
                            .lineLimit(1)
                    }
                    Text(device.friendlyName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: DesignTokens.Size.summaryRowTrailingIcon, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isSelected)
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            if isSelected && endpoints.count > 1 {
                Picker("Endpoint", selection: Binding(get: { selectedEndpoint }, set: { onEndpointChange($0) })) {
                    ForEach(endpoints, id: \.self) { ep in
                        Text("EP \(ep)").tag(ep)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.xs)
            }
        }
    }
}

#Preview {
    List {
        AddGroupMemberDeviceRow(
            device: .preview,
            isSelected: false,
            selectedEndpoint: 1,
            onTap: {},
            onEndpointChange: { _ in }
        )
        AddGroupMemberDeviceRow(
            device: .preview,
            isSelected: true,
            selectedEndpoint: 1,
            onTap: {},
            onEndpointChange: { _ in }
        )
    }
    .listStyle(.plain)
    .environment(AppEnvironment())
}
