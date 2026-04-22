import Foundation

struct Z2MMessageRouter: Sendable {

    private struct RawMessage: Decodable {
        let topic: String
        let payload: JSONValue

        func decode<T: Decodable>(_ type: T.Type) -> T? {
            guard let data = try? JSONEncoder().encode(payload) else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }
    }

    func route(_ data: Data) -> Z2MEvent? {
        guard let raw = try? JSONDecoder().decode(RawMessage.self, from: data) else { return nil }
        return dispatch(raw)
    }

    private func dispatch(_ raw: RawMessage) -> Z2MEvent? {
        switch raw.topic {
        case Z2MTopics.bridgeInfo:
            guard let info = raw.decode(BridgeInfo.self) else { return nil }
            return .bridgeInfo(info)

        case Z2MTopics.bridgeState:
            if let s = raw.payload.stringValue { return .bridgeState(s) }
            if let s = raw.payload.object?["state"]?.stringValue { return .bridgeState(s) }
            return nil

        case Z2MTopics.bridgeDevices:
            guard let devices = raw.decode([Device].self) else { return nil }
            return .devices(devices)

        case Z2MTopics.bridgeGroups:
            guard let groups = raw.decode([Group].self) else { return nil }
            return .groups(groups)

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
            return .bridgeResponse(topic: raw.topic, data: raw.payload)

        case Z2MTopics.bridgeResponseTouchlinkScan:
            guard let response = raw.decode(TouchlinkScanResponse.self) else { return nil }
            let found = response.status == "ok" ? (response.data?.found ?? []) : []
            return .touchlinkScanResult(found)

        case Z2MTopics.bridgeResponseTouchlinkIdentify:
            return .touchlinkIdentifyDone

        case Z2MTopics.bridgeResponseTouchlinkFactoryReset:
            return .touchlinkFactoryResetDone

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
