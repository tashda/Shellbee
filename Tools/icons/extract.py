"""Recraft SVG -> symbolset-ready glyph `.d`, with the checks batch 1 lacked.

Usage:  python3 extract.py <name>...      # reads <name>.svg, writes <name>.d

Joins every path in the file (Recraft splits a glyph across several), collapses
the hairline segments the tracer leaves at apexes, corrects winding, then
reports the defects that only showed up on render last time: sliver subpaths,
remaining hairlines, aspect, and stroke weight.
"""
import re, sys, math, os
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import pathkit as pk
from build_symbolset import bbox, CAP

def glyph_d(svg_path):
    """Every subpath that is part of the glyph, whatever colour it is drawn in.

    Recraft returns a glyph in one of two shapes and the extraction rule has to
    survive both. Sometimes it is a compound path whose counters are subpaths of
    the same fill; sometimes it is stacked opaque layers -- black shape, white
    shape over it, black again -- where the white ones ARE the counters. Keying
    on the ink colour works for the first and fills the second solid, which is
    what happened to the washing machine.

    So take everything and let winding decide: drop the near-transparent backing
    path, drop the full-canvas rectangle, drop tracer specks, and hand the rest
    to make_nonzero_safe, which assigns each subpath's direction from how deeply
    it nests. A white counter sits one level inside its black parent and comes
    out reversed either way it was authored.
    """
    s = re.sub(r'<metadata>.*?</metadata>', '', open(svg_path).read(), flags=re.S)
    box = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', s)
    W, H = (float(box.group(1)), float(box.group(2))) if box else (2048.0, 2048.0)
    kept, dropped = [], []
    for m in re.finditer(r'<path([^>]*)>', s):
        a = m.group(1)
        dm = re.search(r'\sd="([^"]+)"', a)
        if not dm:
            continue
        op = re.search(r'fill-opacity="([\d.]+)"', a)
        if op and float(op.group(1)) < 0.99:
            dropped.append("transparent"); continue
        for sub in pk.subpaths(pk.to_absolute(pk.tokenize(dm.group(1)))):
            flat = pk.flatten(sub)
            xs = [q[0] for q in flat]; ys = [q[1] for q in flat]
            bw, bh = max(xs) - min(xs), max(ys) - min(ys)
            area = abs(pk.signed_area(flat))
            if bw > 0.98 * W and bh > 0.98 * H:
                dropped.append("canvas"); continue
            if area < (W * H) * 2e-5:
                dropped.append("speck"); continue
            kept.append(pk.render(sub))
    if not kept:
        raise SystemExit(f"{svg_path}: nothing left after filtering")
    return " ".join(kept), (len(kept), dropped)

def clean(d, min_len=9.0):
    subs = pk.subpaths(pk.to_absolute(pk.tokenize(d)))
    return " ".join(pk.render(pk.despeckle(s, min_len)) for s in subs)

def hairlines(sub):
    pts, segs, _ = pk._seg_points(sub)
    return sum(1 for i in range(len(segs)) if math.dist(pts[i], pts[i+1]) < 9.0)

def winding(polys, pt):
    x, y = pt; w = 0
    for poly in polys:
        n = len(poly)
        for i in range(n):
            x0, y0 = poly[i]; x1, y1 = poly[(i+1) % n]
            if y0 <= y < y1 or y1 <= y < y0:
                if x0 + (y-y0)/(y1-y0)*(x1-x0) > x:
                    w += 1 if y1 > y0 else -1
    return w

def runs(polys, y, x0, x1, steps=3000):
    out, start = [], None
    for i in range(steps+1):
        x = x0 + (x1-x0)*i/steps
        if winding(polys, (x, y)) != 0:
            if start is None: start = x
        elif start is not None:
            out.append(x-start); start = None
    if start is not None: out.append(x1-start)
    return out

for name in sys.argv[1:]:
    raw, (nsub, dropped) = glyph_d(f"{name}.svg")
    d, _ = pk.make_nonzero_safe(clean(raw))
    open(f"{name}.d", "w").write(d)
    subs = pk.subpaths(pk.to_absolute(pk.tokenize(d)))
    x0, y0, x1, y1 = bbox(d)
    w, h = x1-x0, y1-y0
    k = CAP/h
    polys = [pk.flatten(s) for s in subs]
    drop = f", dropped {len(dropped)} ({', '.join(sorted(set(dropped)))})" if dropped else ""
    print(f"\n{name}  ({nsub} subpaths kept{drop})")
    print(f"  aspect w/h {w/h:.3f}  ({abs(1-w/h)*100:.1f}% off square)   scale {k:.5f}")
    bad = []
    for i, s in enumerate(subs):
        flat = polys[i]
        xs=[p[0] for p in flat]; ys=[p[1] for p in flat]
        bw, bh = max(xs)-min(xs), max(ys)-min(ys)
        ar = max(bw, bh)/max(min(bw, bh), 1)
        hl = hairlines(s)
        flag = []
        if hl: flag.append(f"{hl} hairline")
        if ar > 6: flag.append(f"sliver {ar:.1f}:1")
        if flag: bad.append(f"[{i}] {bw:.0f}x{bh:.0f} " + ", ".join(flag))
    print(f"  {len(subs)} subpaths; defects: " + ("; ".join(bad) if bad else "none"))
    vals = []
    for frac in (0.30, 0.50, 0.70):
        r = [v*k for v in runs(polys, y0+h*frac, x0-1, x1+1) if v*k > 4.0]
        vals += r
        print(f"  y={frac:.0%}  " + ", ".join(f"{v:.2f}" for v in r))
    if vals:
        print(f"  stroke range {min(vals):.2f}-{max(vals):.2f}  (family band 5.5-7.3, home 6.48)")
