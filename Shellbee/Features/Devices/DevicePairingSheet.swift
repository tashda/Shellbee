import SwiftUI

struct DevicePairingSheet: View {
    let device: Device
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var section: DocSection?
    @State private var isLoading = false
    @State private var notFound = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("How to Pair")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .task { await loadPairing() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                Text("Loading pairing instructions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let section {
            ScrollView {
                PairingSectionView(section: section, showHeader: false)
                    .padding(DesignTokens.Spacing.lg)
            }
        } else if notFound {
            ContentUnavailableView(
                "No Pairing Instructions",
                systemImage: "doc.questionmark",
                description: Text("Pairing instructions aren't documented for \(device.definition?.model ?? "this device").")
            )
        }
    }

    private func loadPairing() async {
        guard let model = device.definition?.model else { notFound = true; return }
        let version = environment.store.bridgeInfo?.version ?? "master"
        isLoading = true
        defer { isLoading = false }
        do {
            let parsed = try await DeviceDocService.shared.doc(for: model, z2mVersion: version)
            section = parsed.pairingSection
            if section == nil { notFound = true }
        } catch {
            notFound = true
        }
    }
}

#Preview {
    DevicePairingSheet(device: .preview)
        .environment(AppEnvironment())
}
