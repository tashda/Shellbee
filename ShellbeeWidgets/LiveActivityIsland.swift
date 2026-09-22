import SwiftUI
import WidgetKit

extension DynamicIsland {
    /// The one island every Shellbee activity uses, built from the shared
    /// region views in `LiveActivityViews`.
    static func blueprint(_ layout: LiveActivityLayout) -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                LiveActivityIslandLeading(layout: layout)
            }
            DynamicIslandExpandedRegion(.trailing) {
                LiveActivityIslandTrailing(layout: layout)
            }
            DynamicIslandExpandedRegion(.bottom) {
                LiveActivityIslandBottom(layout: layout)
            }
        } compactLeading: {
            LiveActivityCompactLeading(layout: layout)
        } compactTrailing: {
            LiveActivityCompactTrailing(layout: layout)
        } minimal: {
            LiveActivityMinimal(layout: layout)
        }
        .keylineTint(layout.tint)
    }
}
