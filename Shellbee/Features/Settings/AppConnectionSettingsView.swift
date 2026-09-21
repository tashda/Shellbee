import SwiftUI

struct AppConnectionSettingsView: View {
    @AppStorage(ConnectionSessionController.maxReconnectAttemptsKey) private var maxReconnectAttempts = ConnectionSessionController.defaultMaxReconnectAttempts

    var body: some View {
        Form {
            Section {
                InlineIntField(
                    "Reconnect Limit",
                    value: $maxReconnectAttempts,
                    unit: "attempts",
                    range: ConnectionSessionController.maxReconnectAttemptsRange
                )
            } footer: {
                Text("How many times Shellbee retries before giving up. Opening the app always tries again.")
            }
        }
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppConnectionSettingsView()
    }
}
