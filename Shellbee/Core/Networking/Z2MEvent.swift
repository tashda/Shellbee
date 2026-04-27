import Foundation

enum Z2MEvent: Sendable {
    case bridgeInfo(BridgeInfo)
    case bridgeState(String)
    case devices([Device])
    case groups([Group])
    case logMessage(LogMessage)
    case deviceState(friendlyName: String, state: [String: JSONValue])
    case deviceAvailability(friendlyName: String, available: Bool)
    case deviceOTAUpdateResponse(DeviceOTAUpdateResponse)
    case deviceOTACheckResponse(DeviceOTAUpdateResponse)
    case permitJoinChanged(enabled: Bool, remaining: Int?)
    case bridgeResponse(topic: String, data: JSONValue)
    case bridgeEvent(BridgeDeviceEvent)
    case bridgeHealth(BridgeHealth)
    case operationError(Z2MOperationError)
    case touchlinkScanResult([TouchlinkDevice])
    case touchlinkIdentifyDone
    case touchlinkFactoryResetDone
    case deviceRenameResponse(from: String, to: String, ok: Bool, error: String?)
    case deviceRemoveResponse(id: String, ok: Bool, error: String?)
    case unknown(topic: String)
}

struct BridgeDeviceEvent: Codable, Sendable {
    let type: String
    let data: JSONValue
}

struct TouchlinkScanResponse: Codable, Sendable {
    struct ScanData: Codable, Sendable {
        let found: [TouchlinkDevice]
    }
    let status: String
    let data: ScanData?
}

struct DeviceOTAUpdateResponse: Codable, Sendable {
    struct ResponseData: Codable, Sendable {
        let id: String?
    }

    let data: ResponseData?
    let status: String
    let error: String?

    var deviceName: String? {
        if let id = data?.id {
            return id
        }

        guard let error else { return nil }
        guard let start = error.firstIndex(of: "'") else { return nil }
        let remainder = error[error.index(after: start)...]
        guard let endOffset = remainder.firstIndex(of: "'") else { return nil }
        return String(remainder[..<endOffset])
    }

    var isSuccess: Bool {
        status == "ok"
    }
}
