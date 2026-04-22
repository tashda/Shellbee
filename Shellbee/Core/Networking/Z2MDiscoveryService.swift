import Foundation
import Network
import Darwin

@Observable
final class Z2MDiscoveryService {
    @MainActor public var discoveredHosts: Set<String> = []
    @MainActor public private(set) var isScanning: Bool = false

    @MainActor private var scanTask: Task<Void, Never>?

    nonisolated private static let z2mPort: UInt16 = 8080
    nonisolated private static let probeTimeout: TimeInterval = 1.5
    nonisolated private static let maxConcurrent = 48

    @MainActor
    func start() {
        guard !isScanning else { return }
        isScanning = true
        discoveredHosts.removeAll()

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await Self.scan { host in
                Task { @MainActor [weak self] in
                    self?.discoveredHosts.insert(host)
                }
            }
            await MainActor.run { self.isScanning = false }
        }
    }

    @MainActor
    func stop() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    // MARK: - Scan

    nonisolated private static func scan(onFound: @Sendable @escaping (String) -> Void) async {
        guard let localIP = localIPv4Address() else { return }
        let parts = localIP.split(separator: ".")
        guard parts.count == 4 else { return }
        let prefix = "\(parts[0]).\(parts[1]).\(parts[2])"

        let sem = AsyncSemaphore(limit: maxConcurrent)

        await withTaskGroup(of: Void.self) { group in
            for i in 1...254 {
                let host = "\(prefix).\(i)"
                if host == localIP { continue }
                group.addTask {
                    await sem.acquire()
                    if Task.isCancelled {
                        await sem.release()
                        return
                    }
                    let isZ2M = await probe(host: host)
                    await sem.release()
                    if isZ2M {
                        onFound(host)
                    }
                }
            }
        }
    }

    // MARK: - Probe

    nonisolated private static func probe(host: String) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            guard let port = NWEndpoint.Port(rawValue: z2mPort) else {
                continuation.resume(returning: false)
                return
            }

            let conn = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
            let state = ProbeState(continuation: continuation, connection: conn)

            let timeoutItem = DispatchWorkItem { state.finish(false) }
            state.setTimeoutItem(timeoutItem)
            DispatchQueue.global().asyncAfter(deadline: .now() + probeTimeout, execute: timeoutItem)

            let hostCopy = host
            conn.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    let request = "GET / HTTP/1.1\r\nHost: \(hostCopy):\(z2mPort)\r\nUser-Agent: Shellbee\r\nConnection: close\r\n\r\n"
                    if let data = request.data(using: .utf8) {
                        conn.send(content: data, completion: .contentProcessed({ _ in }))
                    }
                    readLoop(connection: conn, state: state)
                case .failed, .cancelled:
                    state.finish(false)
                default:
                    break
                }
            }

            conn.start(queue: DispatchQueue.global())
        }
    }

    nonisolated private static func readLoop(connection: NWConnection, state: ProbeState) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                let shouldStop = state.appendAndCheck(data)
                if shouldStop {
                    state.finish(true)
                    return
                }
            }
            if isComplete || error != nil || state.accumulatedCount >= 32_768 {
                state.finish(false)
                return
            }
            readLoop(connection: connection, state: state)
        }
    }

    // MARK: - Local IP

    nonisolated private static func localIPv4Address() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
                  (flags & IFF_LOOPBACK) == 0,
                  let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }

            var host = [UInt8](repeating: 0, count: Int(NI_MAXHOST))
            let result = host.withUnsafeMutableBufferPointer { buffer -> Int32 in
                buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) { cbuf in
                    getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                cbuf, socklen_t(buffer.count),
                                nil, 0, NI_NUMERICHOST)
                }
            }
            if result == 0, let end = host.firstIndex(of: 0) {
                return String(decoding: host[..<end], as: UTF8.self)
            }
        }
        return nil
    }
}

// MARK: - Probe state

nonisolated private final class ProbeState: @unchecked Sendable {
    private var accumulated = Data()
    private var timeoutItem: DispatchWorkItem?
    private let continuation: CheckedContinuation<Bool, Never>
    private weak var connection: NWConnection?
    private var finished = false
    private let lock = NSLock()

    init(continuation: CheckedContinuation<Bool, Never>, connection: NWConnection) {
        self.continuation = continuation
        self.connection = connection
    }

    func setTimeoutItem(_ item: DispatchWorkItem) {
        lock.lock(); defer { lock.unlock() }
        timeoutItem = item
    }

    var accumulatedCount: Int {
        lock.lock(); defer { lock.unlock() }
        return accumulated.count
    }

    /// Appends data and returns true if the Z2M signature was found.
    func appendAndCheck(_ data: Data) -> Bool {
        lock.lock(); defer { lock.unlock() }
        accumulated.append(data)
        if let text = String(data: accumulated, encoding: .utf8)?.lowercased(),
           text.contains("zigbee2mqtt") {
            return true
        }
        return false
    }

    func finish(_ result: Bool) {
        lock.lock()
        if finished { lock.unlock(); return }
        finished = true
        let item = timeoutItem
        let conn = connection
        lock.unlock()

        item?.cancel()
        conn?.cancel()
        continuation.resume(returning: result)
    }
}

// MARK: - AsyncSemaphore

private actor AsyncSemaphore {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { self.available = limit }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            available += 1
        }
    }
}
