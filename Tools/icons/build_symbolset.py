"""Emit an SF Symbols Template v3.0 file from one glyph path.

The glyph is placed once per weight/size variant, scaled to the row's cap
height and centred between that column's margins. Windings are corrected so
the artwork fills identically under nonzero, which is what Xcode's asset
compiler uses regardless of the fill-rule attribute.
"""
import re, sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import pathkit as pk

ROWS = {'S': (76, 146), 'M': (276, 346), 'L': (476, 546)}
COLS = {'Ultralight': 265.0, 'Regular': 465.0, 'Black': 665.0}
CAP = 71.9  # matches the optical size the existing casita symbols were set at


def bbox(d):
    subs = pk.subpaths(pk.to_absolute(pk.tokenize(d)))
    pts = [p for s in subs for p in pk.flatten(s)]
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def build(d, template, out, scale=None, valign="baseline", pre_wound=False):
    """`scale` pins units-per-point explicitly. Symbols that share a stroke
    width must share a scale, or the same 134 units render at different
    thicknesses; only the first symbol of a family derives it from CAP.

    `valign` decides where short ink sits in the cap box. "baseline" sits it
    on the baseline, which is right for a glyph that nearly fills the box --
    a house stands on the ground. A small mark must be "center"ed instead:
    the system centres the symbol's whole layout box, so ink parked at the
    bottom of a box it doesn't fill renders visibly low inside a button.

    `pre_wound=True` skips the rewind below. A hand-built compound glyph
    whose module already fixed each sibling sub-shape's winding
    independently (see tree.py, lamp.py) must set this -- re-running
    make_nonzero_safe here on the *combined* path reintroduces the exact bug
    those modules work around: a probe point for one subpath can land inside
    a sibling whose bounding box happens to overlap (the cord poking into
    the dome's join, the trunk plugging into the crown), miscounting
    containment depth and flipping that subpath's winding. Recraft-sourced
    glyphs still need the rewind here, since their raw export relies on
    evenodd and has no independently-fixed subpaths to protect.
    """
    if not pre_wound:
        d, _ = pk.make_nonzero_safe(d)
    x0, y0, x1, y1 = bbox(d)
    k = scale if scale else CAP / (y1 - y0)
    svg = open(template).read()
    for size, (capline, baseline) in ROWS.items():
        for weight, cx in COLS.items():
            tx = cx - k * (x0 + x1) / 2
            if valign == "center":
                cap_height = baseline - capline
                top = capline + (cap_height - k * (y1 - y0)) / 2
                ty = top - k * y0
            else:
                ty = baseline - k * y1
            path = (f'<path transform="translate({tx:.3f},{ty:.3f}) scale({k:.5f})" '
                    f'fill="currentColor" d="{d}"/>')
            svg = re.sub(rf'(<g id="{weight}-{size}">)(.*?)(</g>)', 
                         lambda m: m.group(1) + "\n" + path + "\n" + m.group(3),
                         svg, count=1, flags=re.S)
    open(out, 'w').write(svg)
    print(f"wrote {out}  scale={k:.5f}")


if __name__ == "__main__":
    scale = float(sys.argv[4]) if len(sys.argv) > 4 else None
    valign = sys.argv[5] if len(sys.argv) > 5 else "baseline"
    build(open(sys.argv[1]).read().strip(), sys.argv[2], sys.argv[3], scale, valign)
