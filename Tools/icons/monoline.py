"""Convert a rounded-polyline centreline into a filled monoline outline.

Generalises the approach in `house.py` to open paths and to corners that turn
either way, so a glyph can be composed from several strokes. Offsetting a
rounded corner is exact: the arc centre stays put and the radius becomes
R +/- t depending on which side of the turn you are on.
"""
import math

def _u(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    m = math.hypot(dx, dy)
    return (dx / m, dy / m)

def _left(d):
    """Normal on the left-hand side of travel, in y-down screen coordinates."""
    return (d[1], -d[0])

def _arc(c, r, a0, a1, cw):
    sweep = (a1 - a0) % (2 * math.pi) if cw else -((a0 - a1) % (2 * math.pi))
    n = max(1, math.ceil(abs(sweep) / (math.pi / 2)))
    step = sweep / n
    k = 4 / 3 * math.tan(step / 4)
    out, a = [], a0
    for _ in range(n):
        b = a + step
        p0 = (c[0] + r * math.cos(a), c[1] + r * math.sin(a))
        p1 = (c[0] + r * math.cos(b), c[1] + r * math.sin(b))
        t0 = (-math.sin(a) * r * k, math.cos(a) * r * k)
        t1 = (-math.sin(b) * r * k, math.cos(b) * r * k)
        out.append(((p0[0] + t0[0], p0[1] + t0[1]),
                    (p1[0] - t1[0], p1[1] - t1[1]), p1))
        a = b
    return out

def side(verts, radii, t, closed):
    """Points and segments of the centreline offset by `t` along its left normal."""
    n = len(verts)
    idx = range(n) if closed else range(1, n - 1)
    segs, start = [], None
    if not closed:
        d0 = _u(verts[0], verts[1])
        nl = _left(d0)
        start = (verts[0][0] + nl[0] * t, verts[0][1] + nl[1] * t)
    for i in idx:
        p, prev, nxt = verts[i], verts[i - 1], verts[(i + 1) % n]
        d_in, d_out = _u(prev, p), _u(p, nxt)
        cross = d_in[0] * d_out[1] - d_in[1] * d_out[0]
        if abs(cross) < 1e-9:
            continue                                  # collinear: no corner
        dot = max(-1.0, min(1.0, d_in[0] * d_out[0] + d_in[1] * d_out[1]))
        alpha = math.pi - math.acos(dot)              # interior angle
        r = radii[i]
        T, D = r / math.tan(alpha / 2), r / math.sin(alpha / 2)
        bis = (d_out[0] - d_in[0], d_out[1] - d_in[1])
        m = math.hypot(*bis)
        bis = (bis[0] / m, bis[1] / m)
        c = (p[0] + bis[0] * D, p[1] + bis[1] * D)
        n_in, n_out = _left(d_in), _left(d_out)
        a_pt = (p[0] - d_in[0] * T + n_in[0] * t, p[1] - d_in[1] * T + n_in[1] * t)
        b_pt = (p[0] + d_out[0] * T + n_out[0] * t, p[1] + d_out[1] * T + n_out[1] * t)
        rr = r + t if cross > 0 else r - t            # left side is outer on a right turn
        if start is None:
            start = a_pt
        else:
            segs.append(('L', a_pt))
        a0 = math.atan2(a_pt[1] - c[1], a_pt[0] - c[0])
        a1 = math.atan2(b_pt[1] - c[1], b_pt[0] - c[0])
        for cub in _arc(c, abs(rr), a0, a1, cross > 0):
            segs.append(('C', cub))
    if closed:
        segs.append(('L', start))
    else:
        dn = _u(verts[-2], verts[-1])
        nl = _left(dn)
        segs.append(('L', (verts[-1][0] + nl[0] * t, verts[-1][1] + nl[1] * t)))
    return start, segs

def _rev(start, segs):
    pts, kinds = [start], []
    for kind, a in segs:
        if kind == 'L':
            kinds.append(('L', None, None)); pts.append(a)
        else:
            kinds.append(('C', a[0], a[1])); pts.append(a[2])
    out = []
    for i in range(len(kinds) - 1, -1, -1):
        kind, c1, c2 = kinds[i]
        out.append(('L', pts[i]) if kind == 'L' else ('C', (c2, c1, pts[i])))
    return pts[-1], out

def _emit(start, segs, close=True):
    parts = [f"M {start[0]:.2f} {start[1]:.2f}"]
    for kind, a in segs:
        if kind == 'L':
            parts.append(f"L {a[0]:.2f} {a[1]:.2f}")
        else:
            c1, c2, p = a
            parts.append(f"C {c1[0]:.2f} {c1[1]:.2f} {c2[0]:.2f} {c2[1]:.2f} "
                         f"{p[0]:.2f} {p[1]:.2f}")
    return " ".join(parts) + (" Z" if close else "")

_K = 0.5522847498  # circle-to-cubic constant, a quarter arc


def _semicircle(centre, direction, h):
    """Two cubic quarter-arcs sweeping from the centreline's left offset,
    around the tip in `direction`, to its right offset — a round cap."""
    d = direction
    n = _left(d)
    a = (centre[0] + n[0] * h, centre[1] + n[1] * h)
    tip = (centre[0] + d[0] * h, centre[1] + d[1] * h)
    b = (centre[0] - n[0] * h, centre[1] - n[1] * h)
    k = _K * h
    return [
        ('C', ((a[0] + d[0] * k, a[1] + d[1] * k),
               (tip[0] + n[0] * k, tip[1] + n[1] * k), tip)),
        ('C', ((tip[0] - n[0] * k, tip[1] - n[1] * k),
               (b[0] + d[0] * k, b[1] + d[1] * k), b)),
    ]


def stroke(verts, radii, w, closed=False, cap="round"):
    """Filled outline of a rounded polyline drawn at width `w`.

    A closed centreline yields two contours (the band's two edges). An open one
    yields a single contour: the left edge forward, a cap around the far end,
    the right edge back, and a cap around the start.

    `cap` defaults to `"round"`. The family's caps and joins are fully rounded
    throughout, and a butt-capped stroke reads as belonging to a different set
    the moment it sits beside one. `"butt"` is kept for a stroke that ends
    against something else and would otherwise bulge past it.
    """
    h = w / 2
    if closed:
        a = _emit(*side(verts, radii, h, True))
        b = _emit(*_rev(*side(verts, radii, -h, True)))
        return f"{a} {b}"

    fs, fsegs = side(verts, radii, h, False)
    bs, bsegs = _rev(*side(verts, radii, -h, False))
    if cap != "round":
        body = _emit(fs, fsegs, close=False)
        tail = _emit(bs, bsegs, close=False).replace("M", "L", 1)
        return f"{body} {tail} Z"

    # Each cap lands exactly on the other edge's endpoint, so the whole outline
    # is one contour and `Z` closes it without a seam.
    segs = list(fsegs)
    segs += _semicircle(verts[-1], _u(verts[-2], verts[-1]), h)
    segs += bsegs
    segs += _semicircle(verts[0], _u(verts[1], verts[0]), h)
    return _emit(fs, segs, close=True)
