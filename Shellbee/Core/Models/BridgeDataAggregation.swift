import Foundation

/// Value snapshot of the data the merged views need from one bridge session.
/// Keeping aggregation independent from live sessions lets tests cover bridge
/// attribution and ordering without opening WebSocket connections.
struct BridgeDataSnapshot {
    let bridgeID: UUID
    let bridgeName: String
    let devices: [Device]
    let groups: [Group]
    let logEntries: [LogEntry]
}

enum BridgeDataAggregation {
    static func devices(from snapshots: [BridgeDataSnapshot]) -> [BridgeBoundDevice] {
        snapshots.flatMap { snapshot in
            snapshot.devices.map { device in
                BridgeBoundDevice(
                    bridgeID: snapshot.bridgeID,
                    bridgeName: snapshot.bridgeName,
                    device: device
                )
            }
        }
    }

    static func groups(from snapshots: [BridgeDataSnapshot]) -> [BridgeBoundGroup] {
        snapshots.flatMap { snapshot in
            snapshot.groups.map { group in
                BridgeBoundGroup(
                    bridgeID: snapshot.bridgeID,
                    bridgeName: snapshot.bridgeName,
                    group: group
                )
            }
        }
    }

    static func logEntries(from snapshots: [BridgeDataSnapshot]) -> [BridgeBoundLogEntry] {
        snapshots
            .flatMap { snapshot in
                snapshot.logEntries.map { entry in
                    BridgeBoundLogEntry(
                        bridgeID: snapshot.bridgeID,
                        bridgeName: snapshot.bridgeName,
                        entry: entry
                    )
                }
            }
            .sorted { $0.entry.timestamp > $1.entry.timestamp }
    }
}
