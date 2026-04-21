import SwiftUI

struct ConnectionSetupView: View {
    let environment: AppEnvironment
    @State private var viewModel: ConnectionViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: ConnectionViewModel(environment: environment))
    }

    var body: some View {
        ConnectionOverviewView(viewModel: viewModel)
    }
}

#Preview {
    let environment = AppEnvironment()
    ConnectionSetupView(environment: environment)
        .environment(environment)
}
