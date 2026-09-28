import Foundation

/// Turns one WebSocket frame into a `Z2MEvent`. Runs off the main actor:
/// the connect burst carries megabytes of JSON (`bridge/devices` with every
/// definition), so decoding happens on the socket's decode task and only
/// the finished events reach the store.
nonisolated struct Z2MMessageRouter: Sendable {

    private struct TopicProbe: Decodable {
        let topic: String
    }

    /// A typed payload decoded straight from the frame, without building a
    /// `JSONValue` tree and re-encoding it first.
    private struct Envelope<Payload: Decodable>: Decodable {
        let payload: Payload
    }

    private struct RawMessage: Decodable {
        let topic: String
        let payload: JSONValue

        /// For the small response payloads routed by topic below.
        func decode<T: Decodable>(_ type: T.Type) -> T? {
            guard let data = try? JSONEncoder().encode(payload) else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }
    }

    /// Bridge topics the app reads. Other `bridge/…` topics (definitions,
    /// extensions, converters, config) are large and unused, so they're
    /// dropped after reading their topic.
    private static let handledBridgeTopics: Set<String> = [
        Z2MTopics.bridgeInfo, Z2MTopics.bridgeState, Z2MTopics.bridgeDevices, Z2MTopics.bridgeGroups,
        Z2MTopics.bridgeLogging, Z2MTopics.bridgeEvent, Z2MTopics.bridgeHealth
    ]

    func route(_ data: Data) -> Z2MEvent? {
        let decoder = JSONDecoder()
        guard let topic = try? decoder.decode(TopicProbe.self, from: data).topic else { return nil }
        if topic.hasPrefix("bridge/"), !topic.hasPrefix("bridge/response/"),
           !Self.handledBridgeTopics.contains(topic) {
            return .unknown(topic: topic)
        }
        switch topic {
        case Z2MTopics.bridgeInfo:
            return (try? decoder.decode(Envelope<BridgeInfo>.self, from: data)).map { .bridgeInfo($0.payload) }
        case Z2MTopics.bridgeDevices:
            return (try? decoder.decode(Envelope<[Device]>.self, from: data)).map { .devices($0.payload) }
        case Z2MTopics.bridgeGroups:
            return (try? decoder.decode(Envelope<[Group]>.self, from: data)).map { .groups($0.payload) }
        default:
            guard let raw = try? decoder.decode(RawMessage.self, from: data) else { return nil }
            return dispatch(raw)
        }
    }

    static func decodeRaw(_ data: Data) -> (topic: String, payload: JSONValue)? {
        guard let raw = try? JSONDecoder().decode(RawMessage.self, from: data) else { return nil }
        return (raw.topic, raw.payload)
    }

    private func dispatch(_ raw: RawMessage) -> Z2MEvent? {
        switch raw.topic {
        case Z2MTopics.bridgeState:
            if let s = raw.payload.stringValue { return .bridgeState(s) }
            if let s = raw.payload.object?["state"]?.stringValue { return .bridgeState(s) }
            return nil

        case Z2MTopics.bridgeLogging:
            if let log = raw.decode(LogMessage.self) {
                return .logMessage(log)
            }
            if let str = raw.payload.stringValue,
               let d = str.data(using: .utf8),
               let log = try? JSONDecoder().decode(LogMessage.self, from: d) {
                return .logMessage(log)
            }
            return nil

        case Z2MTopics.bridgeEvent:
            guard let event = raw.decode(BridgeDeviceEvent.self) else { return nil }
            return .bridgeEvent(event)

        case Z2MTopics.bridgeResponseDeviceOTAUpdate:
            guard let response = raw.decode(DeviceOTAUpdateResponse.self) else { return nil }
            return .deviceOTAUpdateResponse(response)

        case Z2MTopics.bridgeResponseDeviceOTACheck:
            guard let response = raw.decode(DeviceOTAUpdateResponse.self) else { return nil }
            return .deviceOTACheckResponse(response)

        case Z2MTopics.bridgeResponseOptions, Z2MTopics.bridgeResponseInfo:
            if let obj = raw.payload.object,
               obj["status"]?.stringValue == "error",
               let errorMsg = obj["error"]?.stringValue {
                return .operationError(Z2MOperationError(
                    id: UUID(), topic: raw.topic, message: errorMsg, timestamp: .now
                ))
            }
            return .bridgeResponse(topic: raw.topic, data: raw.payload)

        case Z2MTopics.bridgeResponseTouchlinkScan, Z2MTopics.bridgeResponseTouchlinkIdentify:
            // A failed scan or identify is an error, not an empty result:
            // route it like any other failed request so the UI and the Live
            // Activity report the failure.
            if let obj = raw.payload.object,
               obj["status"]?.stringValue == "error" {
                return .operationError(Z2MOperationError(
                    id: UUID(), topic: raw.topic,
                    message: obj["error"]?.stringValue ?? "Touchlink request failed", timestamp: .now
                ))
            }
            if raw.topic == Z2MTopics.bridgeResponseTouchlinkIdentify {
                return .touchlinkIdentifyDone
            }
            guard let response = raw.decode(TouchlinkScanResponse.self) else { return nil }
            let found = response.status == "ok" ? (response.data?.found ?? []) : []
            return .touchlinkScanResult(found)

        case Z2MTopics.bridgeResponseTouchlinkFactoryReset:
            return .touchlinkFactoryResetDone

        case Z2MTopics.bridgeResponseDeviceRename:
            let obj = raw.payload.object
            let data = obj?["data"]?.object
            guard let from = data?["from"]?.stringValue,
                  let to = data?["to"]?.stringValue else {
                return .bridgeResponse(topic: raw.topic, data: raw.payload)
            }
            let ok = obj?["status"]?.stringValue == "ok"
            let error = obj?["error"]?.stringValue
            return .deviceRenameResponse(from: from, to: to, ok: ok, error: error)

        case Z2MTopics.bridgeResponseDeviceRemove:
            let obj = raw.payload.object
            let ok = obj?["status"]?.stringValue == "ok"
            let error = obj?["error"]?.stringValue
            // z2m echoes the request as `data` on both ok and error. The id
            // lives there; on error it may also be embedded in the message.
            let id = obj?["data"]?.object?["id"]?.stringValue
                ?? Self.idFromRemoveError(error)
                ?? ""
            return .deviceRemoveResponse(id: id, ok: ok, error: error)

        case Z2MTopics.bridgeResponseNetworkMap:
            guard let response = raw.decode(NetworkMapResponse.self) else { return nil }
            return .networkMapResponse(response)

        case Z2MTopics.bridgeHealth:
            guard let health = raw.decode(BridgeHealth.self) else { return nil }
            return .bridgeHealth(health)

        case Z2MTopics.bridgeResponseHealthCheck:
            guard let data = raw.payload.object?["data"],
                  let encoded = try? JSONEncoder().encode(data),
                  let health = try? JSONDecoder().decode(BridgeHealth.self, from: encoded) else { return nil }
            return .bridgeHealth(health)

        default:
            return routeDynamic(raw)
        }
    }

    private static func idFromRemoveError(_ error: String?) -> String? {
        guard let error else { return nil }
        guard let start = error.firstIndex(of: "'") else { return nil }
        let remainder = error[error.index(after: start)...]
        guard let end = remainder.firstIndex(of: "'") else { return nil }
        return String(remainder[..<end])
    }

    private func routeDynamic(_ raw: RawMessage) -> Z2MEvent? {
        if raw.topic.hasPrefix("bridge/response/") {
            if let obj = raw.payload.object,
               obj["status"]?.stringValue == "error",
               let errorMsg = obj["error"]?.stringValue {
                return .operationError(Z2MOperationError(
                    id: UUID(), topic: raw.topic, message: errorMsg, timestamp: .now
                ))
            }
            return .bridgeResponse(topic: raw.topic, data: raw.payload)
        }

        if raw.topic.hasSuffix(Z2MTopics.availabilitySuffix) {
            let name = String(raw.topic.dropLast(Z2MTopics.availabilitySuffix.count))
            let available = raw.payload.stringValue == "online"
                || raw.payload.object?["state"]?.stringValue == "online"
            return .deviceAvailability(friendlyName: name, available: available)
        }

        if let state = raw.payload.object {
            return .deviceState(friendlyName: raw.topic, state: state)
        }

        return .unknown(topic: raw.topic)
    }
}
