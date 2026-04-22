import XCTest
@testable import Shellbee

final class ConnectionConfigTests: XCTestCase, @unchecked Sendable {

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated { ConnectionConfig.clear() }
    }

    override func tearDown() {
        MainActor.assumeIsolated { ConnectionConfig.clear() }
        super.tearDown()
    }

    // MARK: - webSocketURL

    @MainActor
    func testWSURLPlain() {
        let cfg = config(host: "192.168.1.10", port: 8080, useTLS: false)
        XCTAssertEqual(cfg.webSocketURL?.absoluteString, "ws://192.168.1.10:8080/api")
    }

    @MainActor
    func testWSSURL() {
        let cfg = config(host: "myserver.local", port: 443, useTLS: true)
        XCTAssertEqual(cfg.webSocketURL?.absoluteString, "wss://myserver.local/api")
    }

    @MainActor
    func testWSSNonStandardPort() {
        let cfg = config(host: "myserver.local", port: 8443, useTLS: true)
        XCTAssertEqual(cfg.webSocketURL?.absoluteString, "wss://myserver.local:8443/api")
    }

    @MainActor
    func testWSDefaultPortOmitted() {
        let cfg = config(host: "host.local", port: 80, useTLS: false)
        XCTAssertEqual(cfg.webSocketURL?.absoluteString, "ws://host.local/api")
    }

    @MainActor
    func testBasePath() {
        let cfg = config(host: "host.local", port: 8080, basePath: "/z2m")
        XCTAssertEqual(cfg.webSocketURL?.absoluteString, "ws://host.local:8080/z2m/api")
    }

    @MainActor
    func testBasePathWithTrailingSlash() {
        let cfg = config(host: "host.local", port: 8080, basePath: "/z2m/")
        XCTAssertEqual(cfg.webSocketURL?.absoluteString, "ws://host.local:8080/z2m/api")
    }

    @MainActor
    func testAuthToken() {
        let cfg = config(host: "h", port: 8080, authToken: "secret123")
        XCTAssertTrue(cfg.webSocketURL?.absoluteString.contains("token=secret123") == true)
    }

    @MainActor
    func testNoAuthToken() {
        let cfg = config(host: "h", port: 8080, authToken: nil)
        XCTAssertFalse(cfg.webSocketURL?.absoluteString.contains("token") == true)
    }

    @MainActor
    func testEmptyAuthTokenOmitted() {
        let cfg = config(host: "h", port: 8080, authToken: "")
        XCTAssertFalse(cfg.webSocketURL?.absoluteString.contains("token") == true)
    }

    // MARK: - displayURL

    @MainActor
    func testDisplayURL() {
        let cfg = config(host: "192.168.1.1", port: 8080, useTLS: false)
        XCTAssertEqual(cfg.displayURL, "http://192.168.1.1:8080/")
    }

    // MARK: - Persistence

    @MainActor
    func testSaveAndLoad() {
        let cfg = config(host: "stored.host", port: 9090, authToken: "token")
        cfg.save()
        let loaded = ConnectionConfig.load()
        XCTAssertEqual(loaded?.host, "stored.host")
        XCTAssertEqual(loaded?.port, 9090)
        XCTAssertEqual(loaded?.authToken, "token")
    }

    @MainActor
    func testLoadReturnsNilAfterClear() {
        config(host: "x", port: 1).save()
        ConnectionConfig.clear()
        XCTAssertNil(ConnectionConfig.load())
    }

    @MainActor
    func testLoadReturnsNilWhenNeverSaved() {
        XCTAssertNil(ConnectionConfig.load())
    }

    // MARK: - parse(from:)

    @MainActor
    func testParseFromSimpleHostPort() {
        let cfg = ConnectionConfig.parse(from: "192.168.1.1:8080")
        XCTAssertEqual(cfg?.host, "192.168.1.1")
        XCTAssertEqual(cfg?.port, 8080)
        XCTAssertFalse(cfg?.useTLS ?? true)
    }

    @MainActor
    func testParseFromHTTPS() {
        let cfg = ConnectionConfig.parse(from: "https://myserver.local:8443")
        XCTAssertTrue(cfg?.useTLS ?? false)
        XCTAssertEqual(cfg?.host, "myserver.local")
        XCTAssertEqual(cfg?.port, 8443)
    }

    @MainActor
    func testParseFromHTTP() {
        let cfg = ConnectionConfig.parse(from: "http://10.0.0.1:8080")
        XCTAssertFalse(cfg?.useTLS ?? true)
        XCTAssertEqual(cfg?.host, "10.0.0.1")
    }

    @MainActor
    func testParseFromWithPath() {
        let cfg = ConnectionConfig.parse(from: "http://server.local:8080/z2m")
        XCTAssertEqual(cfg?.basePath, "/z2m")
    }

    @MainActor
    func testParseFromInvalidReturnsNil() {
        XCTAssertNil(ConnectionConfig.parse(from: "not a url!!!"))
    }

    // MARK: - Helpers

    @MainActor
    private func config(
        host: String,
        port: Int = 8080,
        useTLS: Bool = false,
        basePath: String = "/",
        authToken: String? = nil
    ) -> ConnectionConfig {
        ConnectionConfig(host: host, port: port, useTLS: useTLS,
                         basePath: basePath, authToken: authToken)
    }
}
