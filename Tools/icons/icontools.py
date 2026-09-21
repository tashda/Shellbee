"""Raster checks for a candidate glyph.

Two things the contour-level checks cannot see:

  * A stroke that does not quite meet the shape it should join. Every contour
    is closed and every winding is right, so topology says the glyph is fine;
    what is wrong is a white channel narrower than the stroke sitting between
    two pieces of ink. Rasterise, count ink components, dilate by half a
    stroke, count again -- if pieces merged, they were meant to be touching.

  * The real stroke weight of a glyph drawn on a diagonal. A horizontal
    scanline across a stroke at angle t measures w/sin(t), which is why the
    hammer read 14 units and the saw 5.3. The distance transform does not
    care about direction: inside a stroke of width w the distance to the
    background is uniform on [0, w/2], so 4 x the median recovers w whatever
    way the stroke runs.

Both are calibrated against casita.home rather than an absolute figure, so
the numbers stay meaningful if the family's weight is ever retuned.
"""
import sys, math, re
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import pathkit as pk

# The symbolset build scales a glyph by its OUTLINE HEIGHT, so the raster has
# to do the same or every landscape glyph measures thin and every tall one
# heavy -- the bed read 0.86 of the house purely because it is 1.25 wide.
# Height fills the canvas; width is whatever the aspect makes it.
N = 320
MARGIN = 6


def _edges(d):
    out = []
    for sub in pk.subpaths(pk.to_absolute(pk.tokenize(d))):
        pts = pk.flatten(sub)
        for i in range(len(pts)):
            out.append((pts[i], pts[(i + 1) % len(pts)]))
    return out


def rasterize(d):
    """Nonzero-winding scanline fill of the glyph, normalised to an N x N grid."""
    segs = _edges(d)
    xs = [p[0] for e in segs for p in e]
    ys = [p[1] for e in segs for p in e]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    k = (N - 2 * MARGIN) / (y1 - y0)
    W = int(round((x1 - x0) * k)) + 2 * MARGIN
    ox, oy = MARGIN, MARGIN
    grid = [bytearray(W) for _ in range(N)]
    for row in range(N):
        wy = ((row + 0.5) - oy) / k + y0
        xw = []
        for (ax, ay), (bx, by) in segs:
            if (ay <= wy < by) or (by <= wy < ay):
                t = (wy - ay) / (by - ay)
                xw.append((ax + t * (bx - ax), 1 if by > ay else -1))
        if not xw:
            continue
        xw.sort()
        wind, start = 0, None
        for wx, dirn in xw:
            prev = wind
            wind += dirn
            if prev == 0 and wind != 0:
                start = wx
            elif prev != 0 and wind == 0 and start is not None:
                a = int(round((start - x0) * k + ox))
                b = int(round((wx - x0) * k + ox))
                for col in range(max(a, 0), min(b, W)):
                    grid[row][col] = 1
                start = None
    return grid, k


def _distance_to_ink(grid):
    W = len(grid[0])
    """Chamfer distance from every cell to the nearest ink cell, in pixels."""
    INF = 10 ** 6
    dist = [[0 if grid[r][c] else INF for c in range(W)] for r in range(N)]
    for r in range(N):
        for c in range(W):
            best = dist[r][c]
            if r: best = min(best, dist[r-1][c] + 10)
            if c: best = min(best, dist[r][c-1] + 10)
            if r and c: best = min(best, dist[r-1][c-1] + 14)
            if r and c + 1 < W: best = min(best, dist[r-1][c+1] + 14)
            dist[r][c] = best
    for r in range(N - 1, -1, -1):
        for c in range(W - 1, -1, -1):
            best = dist[r][c]
            if r + 1 < N: best = min(best, dist[r+1][c] + 10)
            if c + 1 < W: best = min(best, dist[r][c+1] + 10)
            if r + 1 < N and c + 1 < W: best = min(best, dist[r+1][c+1] + 14)
            if r + 1 < N and c: best = min(best, dist[r+1][c-1] + 14)
            dist[r][c] = best
    return dist


def _distance_inside(grid):
    """Chamfer distance from every ink cell to the nearest background cell."""
    W = len(grid[0])
    inv = [bytearray(1 - grid[r][c] for c in range(W)) for r in range(N)]
    return _distance_to_ink(inv)


def _components(test, W):
    seen = [bytearray(W) for _ in range(N)]
    n = 0
    for r in range(N):
        for c in range(W):
            if test(r, c) and not seen[r][c]:
                n += 1
                stack = [(r, c)]
                seen[r][c] = 1
                while stack:
                    y, x = stack.pop()
                    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                        ny, nx = y+dy, x+dx
                        if 0 <= ny < N and 0 <= nx < W and not seen[ny][nx] and test(ny, nx):
                            seen[ny][nx] = 1
                            stack.append((ny, nx))
    return n


def analyse(d):
    grid, _ = rasterize(d)
    W = len(grid[0])
    inside = _distance_inside(grid)
    vals = sorted(inside[r][c] / 10.0 for r in range(N) for c in range(W) if grid[r][c])
    if not vals:
        raise ValueError("empty raster")
    median = vals[len(vals) // 2]
    stroke_px = 4.0 * median            # uniform on [0, w/2] -> median is w/4
    ink = len(vals) / float(N * W)

    outward = _distance_to_ink(grid)
    r_join = stroke_px * 0.55           # just over half a stroke

    # A monoline glyph encloses its counters. A stroke with a gap in it lets a
    # counter drain into the background, and the two become one region -- which
    # topology cannot see, because every contour is still closed. Seal every
    # sub-stroke-width channel by dilating the ink; a counter that reappears
    # was leaking through a gap that should not be there.
    holes_raw = _components(lambda r, c: grid[r][c] == 0, W) - 1
    sealed = lambda r, c: outward[r][c] / 10.0 <= r_join
    holes_sealed = _components(lambda r, c: not sealed(r, c), W) - 1
    return dict(stroke_px=stroke_px, ink=ink,
                parts=_components(lambda r, c: grid[r][c] == 1, W),
                holes=holes_raw, holes_sealed=holes_sealed,
                leaks=holes_sealed - holes_raw)


def reference_stroke():
    """`shellbee.home`'s stroke in this module's raster units -- every
    candidate is judged as a ratio to this rather than to an absolute
    figure, so the numbers stay meaningful if the family's weight is ever
    retuned."""
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "..", "..", "Shellbee", "Assets.xcassets",
                        "Custom Icons", "Navigation",
                        "shellbee.home.symbolset", "shellbee.home.svg")
    svg = open(path).read()
    g = re.search(r'<g id="Regular-M">(.*?)</g>', svg, re.S).group(1)
    return analyse(re.search(r'\sd="([^"]+)"', g).group(1))["stroke_px"]


if __name__ == "__main__":
    home = reference_stroke()
    print(f"{'glyph':16} {'vs home':>8} {'ink%':>7} {'parts':>6}")
    for arg in sys.argv[1:]:
        a = analyse(open(arg).read().strip())
        flag = "" if 0.90 <= a["stroke_px"] / home <= 1.10 else "   <-- outside 0.90-1.10"
        print(f"{arg:16} {a['stroke_px']/home:8.2f} {a['ink']*100:7.1f} {a['parts']:6d}{flag}")


def mirror_asymmetry(d):
    """How far a glyph's raster deviates from left/right mirror symmetry
    about its own bbox centre. Returns a 0-1 fraction of mismatched ink --
    0 is a perfect mirror, higher means real asymmetry.

    Any element documented as "centered" (a chimney on a gable, a knob on a
    door, glazing bars) must be built symmetric about the same axis as the
    rest of the glyph, not merely close to it: a single off-axis mark is
    exactly what read as broken rather than deliberate on `casita.cabin`'s
    first hand-built chimney, which floated to one side of an otherwise
    mirror-symmetric pentagon. This is a diagnostic for subjects that are
    *supposed* to be symmetric, checked by choice -- not a blanket gate
    every glyph must pass, since plenty of the family's subjects (a lock's
    shackle, a suitcase's handle offset) are deliberately asymmetric.
    """
    grid, _ = rasterize(d)
    h = len(grid)
    w = len(grid[0])
    mismatch = 0
    ink = 0
    for row in grid:
        for col in range(w):
            v = row[col]
            ink += v
            mirror_v = row[w - 1 - col]
            if v != mirror_v:
                mismatch += 1
    return mismatch / ink if ink else 0.0
