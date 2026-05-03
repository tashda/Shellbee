import Foundation

/// Navigation value types that carry a `bridgeID` alongside the payload.
///
/// In the multi-bridge era, pushing a bare `Device` / `Group` / `LogEntry`
/// onto a navigation path is ambiguous — the destination has to look up
/// "which bridge?" by name or id, which is fragile (friendly names can
/// collide across bridges; group ids are scoped per Z2M instance, not
/// globally unique). These route types make the bridge explicit at the
/// navigation boundary so detail views never have to guess.
///
/// Convention: list views push the route value; the corresponding
/// `.navigationDestination(for: ...Route.self)` unpacks it and constructs
/// the detail view with an explicit `bridgeID`.

struct DeviceRoute: Hashable {
    let bridgeID: UUID
    let device: Device
}

struct GroupRoute: Hashable {
    let bridgeID: UUID
    let group: Group
}

struct LogRoute: Hashable {
    let bridgeID: UUID
    let entry: LogEntry
}
