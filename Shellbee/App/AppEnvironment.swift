import Foundation

@Observable
final class AppEnvironment {
    let store = AppStore()
    let discovery = Z2MDiscoveryService()
    let history = ConnectionHistory()
    let session: ConnectionSessionController
    var selectedTab: AppTab = .home
    var pendingDeviceFilter: DeviceQuickFilter?
    private var hasStarted = false

    init() {
        session = ConnectionSessionController(store: store, history: history)
    }

    var connectionState: ConnectionSessionController.State {
        session.connectionState
    }

    var connectionConfig: ConnectionConfig? {
        session.connectionConfig
    }

    var hasBeenConnected: Bool {
        session.hasBeenConnected
    }

    var errorMessage: String? {
        session.errorMessage
    }

    static let maxReconnectAttempts = ConnectionSessionController.maxReconnectAttempts

    func connect(config: ConnectionConfig) {
        session.connect(config: config)
    }

    func cancelConnection() async {
        await session.cancelConnection()
    }

    func disconnect() async {
        await session.disconnect()
    }

    func forgetServer() async {
        await session.forgetServer()
    }

    func retryFromLost() {
        session.retryFromLost()
    }

    func clearErrorMessage() {
        session.clearErrorMessage()
    }

    func restartBridge() {
        send(topic: Z2MTopics.Request.restart, payload: .string(""))
    }

    func send(topic: String, payload: JSONValue) {
        session.send(topic: topic, payload: payload)
    }

    func sendDeviceState(_ friendlyName: String, payload: JSONValue) {
        send(topic: Z2MTopics.deviceSet(friendlyName), payload: payload)
    }

    func showDevices(filter: DeviceQuickFilter) {
        pendingDeviceFilter = filter
        selectedTab = .devices
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        ConnectionLiveActivityCoordinator.shared.clearAll()
        OTAUpdateLiveActivityCoordinator.shared.clearAll()
        await Task.yield()

        if let config = connectionConfig {
            connect(config: config)
        }
    }
}
