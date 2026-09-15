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
        let previousScale = settledScale
        let next = min(
            max(settledScale * factor, DesignTokens.Size.networkMapMinimumScale),
            DesignTokens.Size.networkMapMaximumScale
        )
        scale = next
        settledScale = next
        guard previousScale > 0, viewportSize != .zero else { return }
        let ratio = next / previousScale
        let center = CGSize(width: viewportSize.width / 2, height: viewportSize.height / 2)
        offset = CGSize(
            width: (offset.width - center.width) * ratio + center.width,
            height: (offset.height - center.height) * ratio + center.height
        )
        settledOffset = offset
    }

    /// Fits the complete graph in the viewport. Labels intentionally hide at
    /// low zoom, so the graph can remain fully visible without sacrificing the
    /// map's spatial overview.
    func fit() {
        guard contentSize.width > 0, contentSize.height > 0, viewportSize.width > 0, viewportSize.height > 0 else { return }
        let nextScale = min(
            viewportSize.width / contentSize.width,
            viewportSize.height / contentSize.height,
            1
        )
        scale = nextScale
        settledScale = scale
        offset = CGSize(
            width: (viewportSize.width - contentSize.width * scale) / 2,
            height: (viewportSize.height - contentSize.height * scale) / 2
        )
        settledOffset = offset
    }

    func reset() {
        scale = 1
        settledScale = 1
        offset = .zero
        settledOffset = .zero
    }
}
