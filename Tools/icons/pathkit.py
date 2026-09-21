"""Minimal SVG path utilities: parse, flatten, and rewind subpaths so a shape
authored for fill-rule="evenodd" renders identically under nonzero winding.
SF Symbols' asset compiler ignores fill-rule, so holes must be wound opposite
to the contour that encloses them or they fill solid."""
import re

COUNTS = {'M':2,'L':2,'T':2,'H':1,'V':1,'C':6,'S':4,'Q':4,'A':7,'Z':0}
TOK = re.compile(r'([MmLlHhVvCcSsQqTtAaZz])|([-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?)')


def tokenize(d):
    toks = [(m.group(1), m.group(2)) for m in TOK.finditer(d)]
    cmds, i = [], 0
    while i < len(toks):
        if not toks[i][0]:
            raise ValueError("path does not start with a command")
        cmd = toks[i][0]; i += 1
        n = COUNTS[cmd.upper()]
        if n == 0:
            cmds.append((cmd, [])); continue
        first = True
        while i < len(toks) and toks[i][1] is not None:
            args = []
            while len(args) < n and i < len(toks) and toks[i][1] is not None:
                args.append(float(toks[i][1])); i += 1
            if len(args) < n:
                raise ValueError("truncated command")
            cmds.append((cmd, args))
            if first and cmd == 'M': cmd = 'L'
            elif first and cmd == 'm': cmd = 'l'
            first = False
    return cmds


def to_absolute(cmds):
    """Absolute M/L/C/Z only; enough for vectorizer output."""
    out, cx, cy, sx, sy = [], 0.0, 0.0, 0.0, 0.0
    prev = None
    for cmd, a in cmds:
        u, rel = cmd.upper(), cmd.islower()
        if u == 'Z':
            out.append(('Z', [])); cx, cy = sx, sy; prev = None; continue
        b = list(a)
        if u in ('M', 'L', 'T'):
            if rel: b = [cx + b[0], cy + b[1]]
            if u == 'M': sx, sy = b
            cx, cy = b
            out.append(('M' if u == 'M' else 'L', b))
        elif u == 'H':
            x = cx + b[0] if rel else b[0]; cx = x
            out.append(('L', [x, cy]))
        elif u == 'V':
            y = cy + b[0] if rel else b[0]; cy = y
            out.append(('L', [cx, y]))
        elif u == 'C':
            if rel: b = [cx + v if j % 2 == 0 else cy + v for j, v in enumerate(b)]
            cx, cy = b[4], b[5]
            out.append(('C', b))
        elif u == 'S':
            if rel: b = [cx + v if j % 2 == 0 else cy + v for j, v in enumerate(b)]
            px, py = (2 * cx - prev[0], 2 * cy - prev[1]) if prev else (cx, cy)
            b = [px, py] + b
            cx, cy = b[4], b[5]
            out.append(('C', b))
        elif u == 'Q':
            if rel: b = [cx + v if j % 2 == 0 else cy + v for j, v in enumerate(b)]
            c1 = [cx + 2/3*(b[0]-cx), cy + 2/3*(b[1]-cy)]
            c2 = [b[2] + 2/3*(b[0]-b[2]), b[3] + 2/3*(b[1]-b[3])]
            out.append(('C', c1 + c2 + [b[2], b[3]])); cx, cy = b[2], b[3]
        else:
            raise ValueError(f"unsupported command {cmd}")
        prev = (out[-1][1][2], out[-1][1][3]) if out[-1][0] == 'C' else None
    return out


def subpaths(cmds):
    subs, cur = [], []
    for c in cmds:
        if c[0] == 'M' and cur:
            subs.append(cur); cur = [c]
        elif c[0] == 'Z':
            cur.append(c); subs.append(cur); cur = []
        else:
            cur.append(c)
    if cur: subs.append(cur)
    return subs


def flatten(sub, steps=16):
    pts, cx, cy = [], 0.0, 0.0
    for cmd, a in sub:
        if cmd == 'M':
            cx, cy = a; pts.append((cx, cy))
        elif cmd == 'L':
            cx, cy = a; pts.append((cx, cy))
        elif cmd == 'C':
            x0, y0 = cx, cy
            for s in range(1, steps + 1):
                t = s / steps; m = 1 - t
                x = m**3*x0 + 3*m*m*t*a[0] + 3*m*t*t*a[2] + t**3*a[4]
                y = m**3*y0 + 3*m*m*t*a[1] + 3*m*t*t*a[3] + t**3*a[5]
                pts.append((x, y))
            cx, cy = a[4], a[5]
    return pts


def signed_area(pts):
    s = 0.0
    for i in range(len(pts)):
        x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % len(pts)]
        s += x0 * y1 - x1 * y0
    return s / 2


def contains(poly, pt):
    x, y = pt; inside = False
    for i in range(len(poly)):
        x0, y0 = poly[i]; x1, y1 = poly[(i + 1) % len(poly)]
        if (y0 > y) != (y1 > y):
            if x < (x1 - x0) * (y - y0) / (y1 - y0) + x0:
                inside = not inside
    return inside


def reverse_sub(sub):
    """Reverse the direction of one absolute M/L/C/Z subpath."""
    pts = [sub[0][1]]
    segs = []
    for cmd, a in sub[1:]:
        if cmd == 'Z': continue
        if cmd == 'L':
            segs.append(('L', None, None, a)); pts.append(a)
        else:
            segs.append(('C', a[0:2], a[2:4], a[4:6])); pts.append(a[4:6])
    closed = sub[-1][0] == 'Z'
    if closed and pts[-1] != pts[0]:
        segs.append(('L', None, None, pts[0])); pts.append(pts[0])
    out = [('M', list(pts[-1]))]
    for i in range(len(segs) - 1, -1, -1):
        kind, c1, c2, _ = segs[i]
        start = pts[i]
        if kind == 'L':
            out.append(('L', list(start)))
        else:
            out.append(('C', list(c2) + list(c1) + list(start)))
    if closed: out.append(('Z', []))
    return out


def fmt(v):
    s = f"{v:.3f}".rstrip('0').rstrip('.')
    return "0" if s in ("", "-0") else s


def render(cmds):
    return " ".join(c + ((" " + " ".join(fmt(v) for v in a)) if a else "") for c, a in cmds)


def make_nonzero_safe(d):
    """Rewind nested contours by containment depth so nonzero == evenodd."""
    subs = subpaths(to_absolute(tokenize(d)))
    flats = [flatten(s) for s in subs]
    depths = []
    for i, f in enumerate(flats):
        probe = f[len(f) // 4]
        depths.append(sum(1 for j, g in enumerate(flats) if j != i and contains(g, probe)))
    out = []
    for s, f, depth in zip(subs, flats, depths):
        want_ccw = depth % 2 == 1
        is_ccw = signed_area(f) > 0
        out.extend(reverse_sub(s) if is_ccw != want_ccw else s)
    return render(out), depths


def _seg_points(sub):
    pts = [tuple(sub[0][1])]
    segs = []
    for cmd, a in sub[1:]:
        if cmd == 'Z': continue
        if cmd == 'L':
            segs.append(['L', None, None, tuple(a)])
        else:
            segs.append(['C', tuple(a[0:2]), tuple(a[2:4]), tuple(a[4:6])])
        pts.append(segs[-1][3])
    return pts, segs, sub[-1][0] == 'Z'


def despeckle(sub, min_len=9.0):
    """Collapse runs of hairline segments left by raster tracing into one
    cubic that keeps the tangents on either side of the run."""
    import math
    pts, segs, closed = _seg_points(sub)
    n = len(segs)
    lens = [math.dist(pts[i], pts[i + 1]) for i in range(n)]
    keep, i = [], 0
    while i < n:
        if lens[i] >= min_len:
            keep.append(segs[i]); i += 1; continue
        j = i
        while j < n and lens[j] < min_len:
            j += 1
        # tangent leaving pts[i] (from the previous long segment) and
        # arriving at pts[j] (into the next long segment)
        start, end = pts[i], pts[j] if j < len(pts) else pts[-1]
        prev = keep[-1] if keep else segs[n - 1]
        nxt = segs[j] if j < n else segs[0]
        t_in = _unit(prev[2] if prev[0] == 'C' else pts[max(i - 1, 0)], start)
        t_out = _unit(nxt[1] if nxt[0] == 'C' else nxt[3], end)
        dist = math.dist(start, end) / 3
        c1 = (start[0] + t_in[0] * dist, start[1] + t_in[1] * dist)
        c2 = (end[0] + t_out[0] * dist, end[1] + t_out[1] * dist)
        keep.append(['C', c1, c2, end])
        i = j
    out = [('M', list(pts[0]))]
    for s in keep:
        out.append(('L', list(s[3])) if s[0] == 'L'
                   else ('C', list(s[1]) + list(s[2]) + list(s[3])))
    if closed: out.append(('Z', []))
    return out


def _unit(a, b):
    import math
    dx, dy = b[0] - a[0], b[1] - a[1]
    m = math.hypot(dx, dy) or 1.0
    return (dx / m, dy / m)
