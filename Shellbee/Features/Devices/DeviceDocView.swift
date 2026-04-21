import SwiftUI
import OSLog

private let log = Logger(subsystem: "dev.echodb.shellbee", category: "DeviceDocView")

struct DeviceDocView: View {
    let device: Device
    @Environment(AppEnvironment.self) private var environment
    @State private var doc: ParsedDeviceDoc?
    @State private var loadError: DeviceDocError?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                DeviceInfoCardView(device: device)
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                if isLoading {
                    HStack {
                        Spacer()
                        VStack(spacing: DesignTokens.Spacing.md) {
                            ProgressView()
                            Text("Loading documentation")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, DesignTokens.Spacing.xxl)
                } else if let error = loadError {
                    errorView(error)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                } else if let doc {
                    if doc.isEmpty {
                        ContentUnavailableView(
                            "No Documentation",
                            systemImage: "doc.questionmark",
                            description: Text("No documentation is available for \(device.definition?.model ?? "this device").")
                        )
                        .padding(.top, DesignTokens.Spacing.xxl)
                    } else {
                        ForEach(doc.sections) { section in
                            DocSectionRegistry.view(for: section)
                                .padding(DesignTokens.Spacing.lg)
                                .background(
                                    Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                )
                                .padding(.horizontal, DesignTokens.Spacing.lg)
                        }
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Documentation")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadDoc() }
    }

    @ViewBuilder
    private func errorView(_ error: DeviceDocError) -> some View {
        ContentUnavailableView(
            "Documentation Unavailable",
            systemImage: "wifi.exclamationmark",
            description: Text(error.localizedDescription)
        )
    }

    private func loadDoc() async {
        guard let model = device.definition?.model else {
            log.warning("loadDoc: no model — skipping")
            return
        }
        let version = environment.store.bridgeInfo?.version ?? "master"
        log.debug("loadDoc: model=\(model) version=\(version)")
        isLoading = true
        defer { isLoading = false }
        do {
            doc = try await DeviceDocService.shared.doc(for: model, z2mVersion: version)
            log.debug("loadDoc: success, sections=\(doc?.sections.count ?? 0)")
        } catch let err as DeviceDocError {
            log.error("loadDoc: DeviceDocError — \(err.localizedDescription)")
            loadError = err
        } catch {
            log.error("loadDoc: unexpected error — \(error)")
            loadError = .networkError(error)
        }
    }
}

#Preview {
    NavigationStack {
        DeviceDocView(device: .preview)
            .environment(AppEnvironment())
    }
}
