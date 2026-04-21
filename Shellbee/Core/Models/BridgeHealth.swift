import Foundation

struct BridgeHealth: Sendable {
    let healthy: Bool?
    let responseTime: Double?
    let process: ProcessStats?
    let os: OSStats?
    let mqtt: MQTTStats?

    struct ProcessStats: Sendable {
        let uptimeSec: Double?
        let memoryUsedMb: Double?
        let memoryPercent: Double?

        var uptimeFormatted: String? {
            guard let s = uptimeSec else { return nil }
            let t = Int(s)
            let years  = t / (365 * 86400)
            let days   = (t % (365 * 86400)) / 86400
            let hours  = (t % 86400) / 3600
            let mins   = (t % 3600) / 60
            if years > 0  { return "\(years)y \(days)d" }
            if days  > 0  { return "\(days)d \(hours)h" }
            if hours > 0  { return "\(hours)h \(mins)m" }
            return "\(mins)m"
        }

        var rssMB: String? {
            guard let mb = memoryUsedMb else { return nil }
            return String(format: "%.0f MB", mb)
        }

        var ramPercentFormatted: String? {
            guard let pct = memoryPercent else { return nil }
            return String(format: "%.1f%%", pct)
        }
    }

    struct OSStats: Sendable {
        let loadAverage: [Double]?
        let memoryUsedMb: Double?
        let memoryPercent: Double?

        var ramMB: String? {
            guard let mb = memoryUsedMb else { return nil }
            return String(format: "%.0f MB", mb)
        }

        var ramPercentFormatted: String? {
            guard let pct = memoryPercent else { return nil }
            return String(format: "%.1f%%", pct)
        }
    }

    struct MQTTStats: Codable, Sendable {
        let connected: Bool?
        let queued: Int?
        let published: Int?
        let received: Int?
    }
}

// MARK: - Codable

extension BridgeHealth: Codable {
    enum CodingKeys: String, CodingKey {
        case healthy
        case responseTime = "response_time"
        case process, os, mqtt
    }
}

extension BridgeHealth.ProcessStats: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        // v2: uptime_sec  /  v1: uptime
        uptimeSec = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("uptime_sec")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("uptime")))
        // v2: memory_used_mb  /  v1: rss (bytes → MB)
        if let mb = try? c.decodeIfPresent(Double.self, forKey: AnyKey("memory_used_mb")) {
            memoryUsedMb = mb
        } else if let rss = try? c.decodeIfPresent(Double.self, forKey: AnyKey("rss")) {
            memoryUsedMb = rss / 1_048_576
        } else {
            memoryUsedMb = nil
        }
        memoryPercent = try? c.decodeIfPresent(Double.self, forKey: AnyKey("memory_percent"))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encodeIfPresent(uptimeSec, forKey: AnyKey("uptime_sec"))
        try c.encodeIfPresent(memoryUsedMb, forKey: AnyKey("memory_used_mb"))
        try c.encodeIfPresent(memoryPercent, forKey: AnyKey("memory_percent"))
    }
}

extension BridgeHealth.OSStats: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        // v2: load_average  /  v1: loadavg
        loadAverage = (try? c.decodeIfPresent([Double].self, forKey: AnyKey("load_average")))
            ?? (try? c.decodeIfPresent([Double].self, forKey: AnyKey("loadavg")))
        let freemem = try? c.decodeIfPresent(Double.self, forKey: AnyKey("freemem"))
        let totalmem = try? c.decodeIfPresent(Double.self, forKey: AnyKey("totalmem"))
        // v2: memory_used_mb  /  v1: (totalmem - freemem) in bytes → MB
        if let mb = try? c.decodeIfPresent(Double.self, forKey: AnyKey("memory_used_mb")) {
            memoryUsedMb = mb
        } else if let free = freemem, let total = totalmem {
            memoryUsedMb = (total - free) / 1_048_576
        } else {
            memoryUsedMb = nil
        }
        // v2: memory_percent  /  v1: computed
        if let pct = try? c.decodeIfPresent(Double.self, forKey: AnyKey("memory_percent")) {
            memoryPercent = pct
        } else if let free = freemem, let total = totalmem, total > 0 {
            memoryPercent = ((total - free) / total) * 100
        } else {
            memoryPercent = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encodeIfPresent(loadAverage, forKey: AnyKey("load_average"))
        try c.encodeIfPresent(memoryUsedMb, forKey: AnyKey("memory_used_mb"))
        try c.encodeIfPresent(memoryPercent, forKey: AnyKey("memory_percent"))
    }
}

private struct AnyKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
