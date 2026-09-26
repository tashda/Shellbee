import ActivityKit
import SwiftUI
import WidgetKit

struct OTAUpdateActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OTAUpdateActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .otaUpdate(context))
        } dynamicIsland: { context in
            .blueprint(.otaUpdate(context))
        }
    }
}

private extension LiveActivityLayout {
    static func otaUpdate(_ context: ActivityViewContext<OTAUpdateActivityAttributes>) -> Self {
        .otaUpdate(attributes: context.attributes, state: context.state, isStale: context.isStale)
    }
}
