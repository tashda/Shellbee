import SwiftUI

/// Owns pan/zoom state for the Network Map canvas, shared between
/// `NetworkMapView` (whose toolbar hosts the Zoom In/Out/Fit buttons) and
/// `NetworkMapCanvasView` (which owns the pinch/pan gestures and the
/// content/viewport sizes those buttons need to compute a fit). Living in
/// the parent means the toolbar buttons work without threading gesture
/// state back up through closures.
///
/// Screen position of a map point is `point * scale + offset`.
@Observable
final class NetworkMapZoomController {
    private(set) var scale: CGFloat = 1
    private(set) var offset: CGSize = .zero

    @ObservationIgnored private var settledScale: CGFloat = 1
    @ObservationIgnored private var settledOffset: CGSize = .zero
    @ObservationIgnored private var contentSize: CGSize = .zero
    @ObservationIgnored private var viewportSize: CGSize = .zero
    /// Height at the top of the viewport covered by the navigation bar. The
    /// map draws beneath it, but fitting and centring use the area below.
    @ObservationIgnored private var topInset: CGFloat = 0
    @ObservationIgnored private var isMagnifying = false
    @ObservationIgnored private var needsInitialCamera = false
    /// Drag translation already consumed by a pinch, so a finger left down
    /// after pinching continues panning from where the map is, not jumping.
    @ObservationIgnored private var panBaseline: CGSize?

    func updateBounds(contentSize: CGSize, viewportSize: CGSize, topInset: CGFloat) {
        self.contentSize = contentSize
        self.viewportSize = viewportSize
        self.topInset = topInset
        if needsInitialCamera { showInitialCamera() }
    }

    // MARK: - Gestures

    func pan(translation: CGSize) {
        guard !isMagnifying else {
            panBaseline = nil
            return
        }
        let baseline = panBaseline ?? translation
        if panBaseline == nil { panBaseline = translation }
        offset = CGSize(
            width: settledOffset.width + translation.width - baseline.width,
            height: settledOffset.height + translation.height - baseline.height
        )
    }

    /// Finishes a pan with a short glide in the flick direction, then keeps
    /// at least part of the map on screen.
    func endPan(translation: CGSize, predictedEndTranslation: CGSize) {
        panBaseline = nil
        guard !isMagnifying else { return }
        let glide = CGSize(
            width: (predictedEndTranslation.width - translation.width) * 0.5,
            height: (predictedEndTranslation.height - translation.height) * 0.5
        )
        let target = clamped(CGSize(width: offset.width + glide.width, height: offset.height + glide.height), scale: scale)
        withAnimation(.smooth(duration: 0.45)) { offset = target }
        settledOffset = target
    }

    /// Zooms around the point where the pinch started, so the content under
    /// the fingers stays under the fingers.
    func magnify(by magnification: CGFloat, anchor: CGPoint) {
        isMagnifying = true
        let next = clampedScale(settledScale * magnification)
        let ratio = next / settledScale
        scale = next
        offset = CGSize(
            width: anchor.x - (anchor.x - settledOffset.width) * ratio,
            height: anchor.y - (anchor.y - settledOffset.height) * ratio
        )
    }

    func endMagnify() {
        isMagnifying = false
        settledScale = scale
        let target = clamped(offset, scale: scale)
        withAnimation(.smooth) { offset = target }
        settledOffset = target
    }

    // MARK: - Toolbar

    func zoomIn() {
        zoom(by: DesignTokens.Size.networkMapZoomStep)
    }

    func zoomOut() {
        zoom(by: 1 / DesignTokens.Size.networkMapZoomStep)
    }

    /// Fits the complete graph in the viewport. Labels intentionally hide at
    /// low zoom, so the graph can remain fully visible without sacrificing the
    /// map's spatial overview.
    func fit() {
        guard let fitScale else { return }
        setCamera(scale: fitScale, centeredOn: CGPoint(x: contentSize.width / 2, y: contentSize.height / 2), animated: true)
    }

    /// The camera a freshly loaded map opens with: the whole graph when it
    /// fits at a readable size, otherwise a readable zoom on its centre so
    /// device names are legible straight away.
    func showInitialCamera() {
        guard let fitScale else {
            // The viewport hasn't been measured yet; apply once it has.
            needsInitialCamera = true
            return
        }
        needsInitialCamera = false
        setCamera(
            scale: max(fitScale, DesignTokens.Size.networkMapInitialScale),
            centeredOn: CGPoint(x: contentSize.width / 2, y: contentSize.height / 2),
            animated: false
        )
    }

    // MARK: - Helpers

    private var visibleHeight: CGFloat { viewportSize.height - topInset }

    private var visibleCenter: CGPoint {
        CGPoint(x: viewportSize.width / 2, y: topInset + visibleHeight / 2)
    }

    private var fitScale: CGFloat? {
        guard contentSize.width > 0, contentSize.height > 0, viewportSize.width > 0, visibleHeight > 0 else { return nil }
        return clampedScale(min(viewportSize.width / contentSize.width, visibleHeight / contentSize.height, 1))
    }

    private func zoom(by factor: CGFloat) {
        guard viewportSize != .zero else { return }
        let center = CGPoint(
            x: (visibleCenter.x - offset.width) / scale,
            y: (visibleCenter.y - offset.height) / scale
        )
        setCamera(scale: clampedScale(scale * factor), centeredOn: center, animated: true)
    }

    private func setCamera(scale nextScale: CGFloat, centeredOn point: CGPoint, animated: Bool) {
        let nextOffset = clamped(
            CGSize(
                width: visibleCenter.x - point.x * nextScale,
                height: visibleCenter.y - point.y * nextScale
            ),
            scale: nextScale
        )
        let apply = {
            self.scale = nextScale
            self.offset = nextOffset
        }
        if animated {
            withAnimation(.smooth, apply)
        } else {
            apply()
        }
        settledScale = nextScale
        settledOffset = nextOffset
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, DesignTokens.Size.networkMapMinimumScale), DesignTokens.Size.networkMapMaximumScale)
    }

    /// Keeps the map from being flung off screen: the content's edge may
    /// travel at most to the middle of the viewport.
    private func clamped(_ proposed: CGSize, scale: CGFloat) -> CGSize {
        guard viewportSize != .zero, contentSize != .zero else { return proposed }
        func clamp(_ value: CGFloat, center: CGFloat, content: CGFloat) -> CGFloat {
            min(max(value, center - content * scale), center)
        }
        return CGSize(
            width: clamp(proposed.width, center: visibleCenter.x, content: contentSize.width),
            height: clamp(proposed.height, center: visibleCenter.y, content: contentSize.height)
        )
    }
}
