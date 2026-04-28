import SwiftUI
import Foundation

struct BackupView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var status: Status = .idle
    @State private var lastBackupURL: URL?
    @State private var history: [HistoryEntry] = HistoryEntry.load()
    @State private var showRestoreGuide = false

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
                        Label("Create Backup", systemImage: "arrow.down.doc.fill")
                        Spacer()
                        if status == .running {
                            ProgressView()
                        }
                    }
                }
                .disabled(status == .running || !environment.connectionState.isConnected)

                if let url = lastBackupURL {
                    ShareLink(
                        item: url,
                        preview: SharePreview(url.lastPathComponent, image: Image(systemName: "doc.zipper"))
                    ) {
                        Label("Save / Share", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Create")
            } footer: {
                Text("Backs up Z2M configuration and coordinator state via the bridge. Save the resulting zip to Files, iCloud Drive, or AirDrop.")
            }

            switch status {
            case .idle:
                EmptyView()
            case .running:
                Section { Text("Working…").foregroundStyle(.secondary) }
            case .success(let size):
                Section {
                    Label("Backup ready (\(formatted(size: size)))", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            case .failed(let reason):
                Section {
                    Label(reason, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }

            if !history.isEmpty {
                Section {
                    ForEach(history) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.timestamp, format: .dateTime.day().month().year().hour().minute())
                                    .font(.callout)
                                Text(formatted(size: entry.size))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indices in
                        history.remove(atOffsets: indices)
                        HistoryEntry.save(history)
                    }
                } header: {
                    Text("Recent")
                } footer: {
                    Text("Metadata only — Shellbee does not retain backup files. Save them to Files / iCloud Drive when prompted.")
                }
            }

            Section {
                Button {
                    showRestoreGuide = true
                } label: {
                    Label("Restore Guide", systemImage: "arrow.up.bin.fill")
                }
            } footer: {
                Text("Restoring a backup requires host-level access to your Z2M data directory. Shellbee can't perform the restore — open the guide for the steps.")
            }
        }
        .navigationTitle("Backup")
        .sheet(isPresented: $showRestoreGuide) {
            RestoreGuideSheet()
        }
    }

    private func triggerBackup() {
        status = .running
        environment.store.backupResponseHandler = { zipBase64, error in
            Task { @MainActor in
                if let zipBase64 {
                    do {
                        let url = try saveBackup(base64: zipBase64)
                        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                        lastBackupURL = url
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
        environment.send(topic: Z2MTopics.Request.backup, payload: .string(""))
    }

    private func saveBackup(base64: String) throws -> URL {
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "Backup", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base64 zip"])
        }
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

#Preview {
    NavigationStack { BackupView() }
        .environment(AppEnvironment())
}
