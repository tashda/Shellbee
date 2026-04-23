import Foundation

@Observable
final class AppEnvironment {
    let store = AppStore()
    let discovery = Z2MDiscoveryService()
    let history = ConnectionHistory()
    let session: ConnectionSessionController
    var selectedTab: AppTab = .home
    var pendingDeviceFilter: DeviceQuickFilter?
    var pendingLogEntryIDs: [UUID]?
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
        selectedTab = .home
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

    func refreshBridgeData() async {
        send(topic: Z2MTopics.Request.devices, payload: .string(""))
        send(topic: Z2MTopics.Request.groups, payload: .string(""))
        try? await Task.sleep(for: .milliseconds(600))
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

        let env = ProcessInfo.processInfo.environment
        if env["UI_TEST_MODE"] == "1" {
            if env["UI_TEST_CLEAR_SAVED_SERVER"] == "1" {
                ConnectionConfig.clear()
                session.connectionConfig = nil
                return
            }
            if let host = env["UI_TEST_Z2M_HOST"],
               let portStr = env["UI_TEST_Z2M_PORT"],
               let port = Int(portStr) {
                connect(config: ConnectionConfig(host: host, port: port, useTLS: false, basePath: "/", authToken: nil))
                return
            }
        }

        if let config = connectionConfig {
            connect(config: config)
        }
    }
}
