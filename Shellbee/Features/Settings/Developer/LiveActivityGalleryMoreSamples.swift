import SwiftUI

enum OTAUpdateGallerySamples {
    static func all(anchor: Date) -> [LiveActivityGallerySample] {
        typealias State = OTAUpdateActivityAttributes.ContentState
        typealias Item = State.Item
        let attributes = OTAUpdateActivityAttributes(identifier: "gallery", bridgeDisplayName: "")
        let multiBridge = OTAUpdateActivityAttributes(identifier: "gallery", bridgeDisplayName: "Upstairs Bridge")

        func running(_ progress: Int, _ minutesLeft: Double) -> (end: Date, start: Date) {
            let end = anchor.addingTimeInterval(minutesLeft * 60)
            let fraction = Double(progress) / 100
            return (end, end.addingTimeInterval(-(minutesLeft * 60) / (1 - fraction)))
        }

        let one = running(45, 4)
        var single = State(
            phase: .active, activeCount: 1, headline: "Updating", detail: "Kitchen Light · 45%", progress: 45,
            items: [Item(name: "Kitchen Light", phase: .updating, progress: 45, remaining: 240, categorySymbol: nil)]
        )
        single.estimatedEnd = one.end
        single.progressStart = one.start

        let many = running(62, 3)
        var queue = State(
            phase: .active, activeCount: 5, headline: "5 device updates", detail: "Kitchen Light · 62%", progress: 38,
            items: [
                Item(name: "Kitchen Light", phase: .updating, progress: 62, remaining: 180, categorySymbol: nil),
                Item(name: "Living Room Plug", phase: .updating, progress: 18, remaining: 600, categorySymbol: nil),
                Item(name: "Front Door Lock", phase: .scheduled, progress: nil, remaining: nil, categorySymbol: nil),
                Item(name: "Thermostat", phase: .requested, progress: nil, remaining: nil, categorySymbol: nil),
                Item(name: "Garage Light", phase: .checking, progress: nil, remaining: nil, categorySymbol: nil)
            ]
        )
        queue.estimatedEnd = many.end
        queue.progressStart = many.start

        let starting = State(
            phase: .active, activeCount: 1, headline: "Updating", detail: "Front Door Lock · Starting", progress: nil,
            items: [Item(name: "Front Door Lock", phase: .requested, progress: nil, remaining: nil, categorySymbol: nil)]
        )
        let done = State(
            phase: .completed, activeCount: 0, headline: "Update complete", detail: "Kitchen Light", progress: 100,
            items: [Item(name: "Kitchen Light", phase: .idle, progress: 100, remaining: nil, categorySymbol: nil)]
        )
        let failed = State(
            phase: .failed, activeCount: 0, headline: "Update failed", detail: "Kitchen Light", progress: nil,
            items: [Item(name: "Kitchen Light", phase: .available, progress: nil, remaining: nil, categorySymbol: nil)]
        )

        func sample(_ name: String, _ state: State, _ attributes: OTAUpdateActivityAttributes = attributes, stale: Bool = false) -> LiveActivityGallerySample {
            LiveActivityGallerySample(name: name, layout: .otaUpdate(attributes: attributes, state: state, isStale: stale, now: anchor))
        }
        return [
            sample("One device", single),
            sample("Five devices", queue),
            sample("Starting", starting),
            sample("Several bridges", queue, multiBridge),
            sample("Out of date", single, stale: true),
            sample("Complete", done),
            sample("Failed", failed)
        ]
    }
}

enum TouchlinkGallerySamples {
    typealias State = BridgeOperationActivityAttributes.ContentState

    static func scan(anchor: Date) -> [LiveActivityGallerySample] {
        let attributes = BridgeOperationActivityAttributes(identifier: "gallery", operation: .touchlinkScan, bridgeDisplayName: "")
        let end = anchor.addingTimeInterval(DesignTokens.Duration.liveActivityTouchlinkScan)
        func sample(_ name: String, _ state: State) -> LiveActivityGallerySample {
            LiveActivityGallerySample(name: name, layout: .bridgeOperation(attributes: attributes, state: state, isStale: false))
        }
        return [
            sample("Searching", State(phase: .active, detail: "", foundCount: 0, startedAt: anchor, endsAt: end)),
            sample("Found devices", State(phase: .active, detail: "", foundCount: 3, startedAt: anchor, endsAt: end)),
            sample("Complete", State(phase: .completed, detail: "3 devices found", foundCount: 3, startedAt: anchor, endsAt: anchor)),
            sample("Ended while suspended", State(phase: .active, detail: "", foundCount: 0, startedAt: anchor.addingTimeInterval(-30), endsAt: anchor.addingTimeInterval(-1))),
            sample("Failed", State(phase: .failed, detail: "Coordinator doesn't support Touchlink", foundCount: 0, startedAt: anchor, endsAt: anchor))
        ]
    }

    static func identify(anchor: Date) -> [LiveActivityGallerySample] {
        let attributes = BridgeOperationActivityAttributes(identifier: "gallery", operation: .touchlinkIdentify, bridgeDisplayName: "", deviceName: "Living Room Light")
        let end = anchor.addingTimeInterval(DesignTokens.Duration.liveActivityTouchlinkIdentify)
        func sample(_ name: String, _ state: State) -> LiveActivityGallerySample {
            LiveActivityGallerySample(name: name, layout: .bridgeOperation(attributes: attributes, state: state, isStale: false))
        }
        return [
            sample("Blinking", State(phase: .active, detail: "Living Room Light", foundCount: 0, startedAt: anchor, endsAt: end)),
            sample("Complete", State(phase: .completed, detail: "Living Room Light", foundCount: 0, startedAt: anchor, endsAt: anchor)),
            sample("Ended while suspended", State(phase: .active, detail: "Living Room Light", foundCount: 0, startedAt: anchor.addingTimeInterval(-20), endsAt: anchor.addingTimeInterval(-1))),
            sample("Failed", State(phase: .failed, detail: "No response", foundCount: 0, startedAt: anchor, endsAt: anchor))
        ]
    }
}
