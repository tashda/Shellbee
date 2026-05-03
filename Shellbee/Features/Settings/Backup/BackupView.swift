import SwiftUI
import Foundation

struct BackupView: View {
    @Environment(AppEnvironment.self) private var environment
    var bridgeID: UUID? = nil
    private var scope: BridgeScopeBindings { environment.bridgeScope(bridgeID) }
    @State private var status: Status = .idle
    @State private var lastBackupURL: URL?
    @State private var lastBackupSize: Int?
    @State private var history: [HistoryEntry] = HistoryEntry.load()
    @State private var showRestoreGuide = false
    @State private var shareItem: ShareItem?

    private struct ShareItem: Identifiable {
        let url: URL
        var id: URL { url }
    }

    enum Status: Equatable {
        case idle
        case running
        case success(size: Int)
        case failed(reason: String)
    }

    var body: some View {
        Form {
            Section {
                Button {
                    triggerBackup()
                } label: {
                    HStack {
                        Text("Create Backup")
                        Spacer()
                        if status == .running {
                            ProgressView()
                        }
                    }
                }
                .disabled(status == .running || !scope.isConnected)

                if let url = lastBackupURL, let size = lastBackupSize {
                    Button {
                        shareItem = ShareItem(url: url)
                    } label: {
                        LabeledContent("Share Backup", value: formatted(size: size))
                    }
                }
            } footer: {
                statusFooter
            }

            if !history.isEmpty {
                Section {
                    ForEach(history) { entry in
                        LabeledContent {
                            Text(formatted(size: entry.size))
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(entry.timestamp, format: .dateTime.day().month().year().hour().minute())
                        }
                    }
                    .onDelete { indices in
                        history.remove(atOffsets: indices)
                        HistoryEntry.save(history)
                    }
                } header: {
                    Text("Recent Backups")
                } footer: {
                    Text("Shellbee does not retain backup files — save them to Files or iCloud Drive when prompted.")
                }
            }

            Section {
                Button {
                    showRestoreGuide = true
                } label: {
                    HStack {
                        Text("Restore Guide")
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } footer: {
                Text("Restoring requires host-level access to your Z2M data directory. Shellbee can't perform the restore.")
            }
        }
        .navigationTitle("Backup")
        .sheet(isPresented: $showRestoreGuide) {
            RestoreGuideSheet()
        }
        .sheet(item: $shareItem) { item in
            ActivityViewController(activityItems: [item.url])
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch status {
        case .idle:
            Text("Backs up Z2M configuration and coordinator state via the bridge. Save the resulting zip to Files, iCloud Drive, or AirDrop.")
        case .running:
            Text("Working…")
        case .success:
            Text("Backup ready. Use Share Backup to save it.")
        case .failed(let reason):
            Text(reason)
                .foregroundStyle(.red)
        }
    }

    private func triggerBackup() {
        status = .running
        scope.store.backupResponseHandler = { zipBase64, error in
            Task { @MainActor in
                if let zipBase64 {
                    do {
                        let url = try saveBackup(base64: zipBase64)
                        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                        lastBackupURL = url
                        lastBackupSize = size
                        status = .success(size: size)
                        let entry = HistoryEntry(id: UUID(), timestamp: .now, size: size, filename: url.lastPathComponent)
                        history.insert(entry, at: 0)
                        if history.count > 20 { history = Array(history.prefix(20)) }
                        HistoryEntry.save(history)
                    } catch {
                        status = .failed(reason: error.localizedDescription)
                    }
                } else {
                    status = .failed(reason: error ?? "Unknown error")
                }
            }
        }
        scope.send(topic: Z2MTopics.Request.backup, payload: .string(""))
    }

    private func saveBackup(base64: String) throws -> URL {
        let data = try BackupPayload.decode(base64: base64)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "shellbee-z2m-backup-\(formatter.string(from: .now)).zip"
        // Documents/Backups/ — durable enough for the share sheet to expose
        // the full set of receivers (AirDrop, Mail, Messages, third-party apps).
        // temporaryDirectory works for ShareLink in theory but receivers see
        // a sandboxed URL and many fall back to "Save to Files" only.
        let docs = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        do {
            try BackupPayload.verifyZip(at: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        return url
    }

    private func formatted(size: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    struct HistoryEntry: Identifiable, Codable, Hashable {
        let id: UUID
        let timestamp: Date
        let size: Int
        let filename: String

        private static let key = "BackupHistory.entries"

        static func load() -> [HistoryEntry] {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
            else { return [] }
            return decoded
        }

        static func save(_ entries: [HistoryEntry]) {
            guard let data = try? JSONEncoder().encode(entries) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { BackupView() }
        .environment(AppEnvironment())
}
