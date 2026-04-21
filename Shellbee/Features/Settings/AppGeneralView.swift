import SwiftUI

struct AppGeneralView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(.automatic)
            }
        }
        .navigationTitle("General")
    }
}

#Preview {
    NavigationStack {
        AppGeneralView()
    }
}
