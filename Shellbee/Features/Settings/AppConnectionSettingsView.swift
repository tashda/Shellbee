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
