import SwiftUI

struct RestoreGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    header

                    section(
                        title: "Why Shellbee can't restore",
                        body: "Z2M's MQTT API exposes a backup endpoint but no restore endpoint. Restoring means replacing the running Z2M's data directory and bringing the bridge back up — operations that need filesystem and process control on the Z2M host. Mobile apps don't have that, and exposing it over MQTT would be a way to wipe your network with one wrong tap. Use the steps below from a machine that has shell access to your Z2M host."
                    )

                    section(
                        title: "What's in the backup",
                        body: "The zip Shellbee produces contains everything Z2M needs to come back online with the same network: \u{2022} configuration.yaml \u{2022} coordinator_backup.json \u{2022} state.json \u{2022} database.db \u{2022} log files (optional, can be deleted before restoring)."
                    )

                    stepsSection
                    notesSection
                    linksSection
                }
                .padding()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Host-only operation", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline.weight(.semibold))
            Text("This guide covers restoring Zigbee2MQTT from a backup. Shellbee cannot perform the restore — it has to be done on the machine running Z2M.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps").font(.headline)
            stepRow(n: 1, title: "Stop Zigbee2MQTT", body: "On your host: `systemctl stop zigbee2mqtt`, `docker compose stop zigbee2mqtt`, or your equivalent. The bridge must not be running while you restore.")
            stepRow(n: 2, title: "Back up the current data folder", body: "Move (don't delete) Z2M's existing data directory to a side location, e.g. `mv data data.before-restore`. If something goes wrong you can swap back.")
            stepRow(n: 3, title: "Unzip the backup into the data folder", body: "Place the contents of the Shellbee-produced zip where the original `data/` directory was. Permissions should match the user that runs Z2M.")
            stepRow(n: 4, title: "Start Zigbee2MQTT", body: "Bring Z2M back up. Watch the logs — coordinator backup mismatches will be reported on first start.")
            stepRow(n: 5, title: "Verify in Shellbee", body: "Reconnect Shellbee. Confirm the device list is intact and devices report state. If devices don't respond, they may need re-pairing — but that's rare unless the coordinator firmware was also reflashed.")
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
                Text(body).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.headline)
            bullet("If you're moving Z2M to a new host, install the same Z2M version that produced the backup before restoring. Cross-version restores can fail on schema migrations.")
            bullet("If the coordinator stick was reflashed or replaced, the network key may differ from what's in the backup. Re-pair affected devices or restore the coordinator firmware too.")
            bullet("On Home Assistant OS, the Z2M add-on stores data in the add-on's persistent volume. Use the add-on's own snapshot/restore — don't try to overlay files manually.")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}").font(.callout).foregroundStyle(.secondary)
            Text(text).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Further reading").font(.headline)
            Link(destination: URL(string: "https://www.zigbee2mqtt.io/guide/installation/")!) {
                Label("Zigbee2MQTT installation guide", systemImage: "arrow.up.right.square")
            }
            Link(destination: URL(string: "https://www.zigbee2mqtt.io/guide/usage/")!) {
                Label("Zigbee2MQTT usage docs", systemImage: "arrow.up.right.square")
            }
        }
    }
}

#Preview {
    RestoreGuideSheet()
}
