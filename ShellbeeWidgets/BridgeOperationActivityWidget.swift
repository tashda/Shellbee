import ActivityKit
import SwiftUI
import WidgetKit

struct BridgeOperationActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeOperationActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .bridgeOperation(context))
        } dynamicIsland: { context in
            .blueprint(.bridgeOperation(context))
        }
    }
}

private extension LiveActivityLayout {
    static func bridgeOperation(_ context: ActivityViewContext<BridgeOperationActivityAttributes>) -> Self {
        .bridgeOperation(attributes: context.attributes, state: context.state, isStale: context.isStale)
    }
}
