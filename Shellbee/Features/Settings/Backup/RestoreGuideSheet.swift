import SwiftUI

struct RestoreGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Host-only operation")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text("Shellbee cannot perform the restore. Run these steps on the machine that runs Zigbee2MQTT.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("What's in the backup") {
                    bulletRow("configuration.yaml")
                    bulletRow("coordinator_backup.json")
                    bulletRow("state.json")
                    bulletRow("database.db")
                    bulletRow("log files (optional, can be deleted before restoring)")
                }

                Section("Steps") {
                    stepRow(n: 1, title: "Stop Zigbee2MQTT", body: "On your host: `systemctl stop zigbee2mqtt`, `docker compose stop zigbee2mqtt`, or your equivalent. The bridge must not be running while you restore.")
                    stepRow(n: 2, title: "Back up the current data folder", body: "Move (don't delete) Z2M's existing data directory to a side location, e.g. `mv data data.before-restore`. If something goes wrong you can swap back.")
                    stepRow(n: 3, title: "Unzip the backup into the data folder", body: "Place the contents of the Shellbee-produced zip where the original `data/` directory was. Permissions should match the user that runs Z2M.")
                    stepRow(n: 4, title: "Start Zigbee2MQTT", body: "Bring Z2M back up. Watch the logs — coordinator backup mismatches will be reported on first start.")
                    stepRow(n: 5, title: "Verify in Shellbee", body: "Reconnect Shellbee. Confirm the device list is intact and devices report state. If devices don't respond, they may need re-pairing — but that's rare unless the coordinator firmware was also reflashed.")
                }

                Section("Notes") {
                    bulletRow("If you're moving Z2M to a new host, install the same Z2M version that produced the backup before restoring. Cross-version restores can fail on schema migrations.")
                    bulletRow("If the coordinator stick was reflashed or replaced, the network key may differ from what's in the backup. Re-pair affected devices or restore the coordinator firmware too.")
                    bulletRow("On Home Assistant OS, the Z2M add-on stores data in the add-on's persistent volume. Use the add-on's own snapshot/restore — don't try to overlay files manually.")
                }

                Section("Further reading") {
                    Link(destination: URL(string: "https://www.zigbee2mqtt.io/guide/installation/")!) {
                        Label("Zigbee2MQTT installation guide", systemImage: "arrow.up.right.square")
                    }
                    Link(destination: URL(string: "https://www.zigbee2mqtt.io/guide/usage/")!) {
                        Label("Zigbee2MQTT usage docs", systemImage: "arrow.up.right.square")
                    }
                }

                Section("Why Shellbee can't restore") {
                    Text("Z2M's MQTT API exposes a backup endpoint but no restore endpoint. Restoring means replacing the running Z2M's data directory and bringing the bridge back up — operations that need filesystem and process control on the Z2M host. Mobile apps don't have that, and exposing it over MQTT would be a way to wipe your network with one wrong tap.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Restoring a Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func stepRow(n: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.indigo, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
    }
}

#Preview {
    RestoreGuideSheet()
}
