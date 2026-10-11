import XCTest

/// Drives the mock bridge's test center (docker/seeder/control.py) so a test
/// sets up the state it asserts on instead of relying on what the seeder's
/// random drift happens to have produced.
enum MockBridgeControl {
    private static let baseURL = URL(string: "http://localhost:8765/api/scenarios/")!

    /// Forces a device online or offline. The mock publishes the change as
    /// retained availability, so the connected app sees it live. Fails the
    /// test, rather than skipping, when the test center can't be reached.
    static func setAvailability(_ name: String, online: Bool,
                                file: StaticString = #filePath, line: UInt = #line) {
        post("availability", ["name": name, "state": online ? "online" : "offline"],
             file: file, line: line)
    }

    /// Posts a scenario, retrying while the seeder is still finishing its
    /// initial publish (the test center answers 503 until then).
    private static func post(_ path: String, _ body: [String: Any],
                             file: StaticString, line: UInt) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5

        var lastError = "no response"
        for _ in 0..<5 {
            let done = DispatchSemaphore(value: 0)
            var status = 0
            var failure: String?
            URLSession.shared.dataTask(with: request) { _, response, error in
                status = (response as? HTTPURLResponse)?.statusCode ?? 0
                failure = error?.localizedDescription
                done.signal()
            }.resume()
            _ = done.wait(timeout: .now() + 8)
            if status == 200 { return }
            lastError = failure ?? "HTTP \(status)"
            Thread.sleep(forTimeInterval: 1)
        }
        XCTFail("Mock test center rejected '\(path)': \(lastError). Is it running on localhost:8765?",
                file: file, line: line)
    }
}
