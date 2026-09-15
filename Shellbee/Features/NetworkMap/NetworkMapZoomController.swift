import SwiftUI

/// Owns pan/zoom state for the Network Map canvas, shared between
/// `NetworkMapView` (whose toolbar hosts the Zoom In/Out/Fit buttons) and
/// `NetworkMapCanvasView` (which owns the pinch/pan gestures and the
/// content/viewport sizes those buttons need to compute a fit). Living in
/// the parent means the toolbar buttons work without threading gesture
/// state back up through closures.
@Observable
final class NetworkMapZoomController {
    var scale: CGFloat = 1
    var settledScale: CGFloat = 1
    var offset: CGSize = .zero
    var settledOffset: CGSize = .zero

    private var contentSize: CGSize = .zero
    private var viewportSize: CGSize = .zero

    func updateBounds(contentSize: CGSize, viewportSize: CGSize) {
        self.contentSize = contentSize
        self.viewportSize = viewportSize
    }

    func zoomIn() {
        zoom(by: DesignTokens.Size.networkMapZoomStep)
    }

    func zoomOut() {
        zoom(by: 1 / DesignTokens.Size.networkMapZoomStep)
    }

    private func zoom(by factor: CGFloat) {
        let next = min(
            max(settledScale * factor, DesignTokens.Size.networkMapMinimumScale),
            DesignTokens.Size.networkMapMaximumScale
        )
        scale = next
        settledScale = next
    }

    /// Scales down just enough to fit the whole map, but never below a
    /// legible floor — a busy network fully "fit" to screen can shrink every
    /// label to nothing, which defeats the point. Below that floor the map
    /// simply stays pannable instead of cramming everything into view.
    func fit() {
        guard contentSize.width > 0, contentSize.height > 0, viewportSize.width > 0, viewportSize.height > 0 else { return }
        let nextScale = min(
            viewportSize.width / contentSize.width,
            viewportSize.height / contentSize.height,
            1
        )
        scale = max(nextScale, DesignTokens.Size.networkMapLegibleMinimumScale)
        settledScale = scale
        offset = .zero
        settledOffset = .zero
    }

    func reset() {
        scale = 1
        settledScale = 1
        offset = .zero
        settledOffset = .zero
    }
}
