import SwiftUI

struct AppPerformanceView: View {
    @AppStorage(OTABulkOperationQueue.concurrencyKey) private var concurrency: Int = OTABulkOperationQueue.defaultConcurrency
    @AppStorage(OTABulkOperationQueue.checkTimeoutKey) private var checkTimeout: Int = OTABulkOperationQueue.defaultCheckTimeoutSeconds

    var body: some View {
        Form {
            Section {
                InlineIntField(
                    "Concurrent Requests",
                    value: $concurrency,
                    unit: "requests",
                    range: OTABulkOperationQueue.concurrencyRange
                )
                InlineIntField(
                    "Device Timeout",
                    value: $checkTimeout,
                    unit: "s",
                    range: OTABulkOperationQueue.checkTimeoutRange
                )
            } header: {
                Text("Bulk OTA Checks")
            } footer: {
                Text("Controls how Shellbee paces \"Check All for Updates\". Higher concurrency finishes faster but can flood the Zigbee coordinator.")
            }
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppPerformanceView()
    }
}
