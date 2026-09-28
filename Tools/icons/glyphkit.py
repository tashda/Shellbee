"""Shared primitives for the hand-built Casita glyphs.

`door.py` and `lock.py` each grew a private copy of the same three helpers.
A third and fourth copy is where that stops: the arc emitter, the winding
flip, and the rounded rectangle live here, and a glyph script is left with
only the geometry that makes it *that* glyph.

Every glyph in this family is drawn on a 2048-unit canvas centred on
(`CX`, `CY`), and carries the family's line weight: `STROKE_RATIO` of the
finished glyph's height. That one number decides whether a new symbol reads
as a member of the set or as a foreign icon beside it, so it is measured,
not assumed.

`CLAUDE.md` quotes the house at w=134 on a 1398-unit glyph -- 1/10.4 -- but
1398 is the *centreline* extent, and `build_symbolset` scales by the
**outline** bbox, which the stroke itself widens. Sampling the shipped
`casita.home` artwork with `isPointInFill` puts its rendered wall at 6.48
template units; the Recraft-drawn `casita.integrations` and
`casita.accentColor` land at 6.41 and 6.55. Reproducing that from an
outline height means 1/11.1, and building at 1/10.4 instead ships a stroke
7% heavy against every symbol it sits next to.
"""
import math
import monoline as ml
import pathkit as pk

CX = CY = 1024.0
STROKE_RATIO = 1 / 11.1


def stroke_for(height):
    """The family's line weight for a glyph of this overall height."""
    return height * STROKE_RATIO


def arc(center, r, a0, a1, cw, ky=1.0):
    """Cubic segments along a circular arc. `ky` < 1 squashes it toward the
    centre's height; an affine map of a Bezier arc is still exact."""
    cy = center[1]
    parts = []
    for c1, c2, p in ml._arc(center, r, a0, a1, cw):
        pts = [(q[0], cy + (q[1] - cy) * ky) for q in (c1, c2, p)]
        parts.append("C " + " ".join(f"{q[0]:.2f} {q[1]:.2f}" for q in pts))
    return " ".join(parts)


def reversed_sub(path_str):
    """Flip one closed subpath's winding — hand-deriving the reverse
    traversal of a four-arc ring is exactly the error `pathkit` exists for."""
    sub = pk.subpaths(pk.to_absolute(pk.tokenize(path_str)))[0]
    return pk.render(pk.reverse_sub(sub))


def rounded_rect(cx, cy, half_w, half_h, r):
    """A closed rounded rectangle, wound clockwise in y-down coordinates."""
    left, right = cx - half_w, cx + half_w
    top, bot = cy - half_h, cy + half_h
    parts = [f"M {left:.2f} {top + r:.2f}"]
    parts.append(arc((left + r, top + r), r, math.pi, math.pi * 1.5, True))
    parts.append(f"L {right - r:.2f} {top:.2f}")
    parts.append(arc((right - r, top + r), r, -math.pi / 2, 0.0, True))
    parts.append(f"L {right:.2f} {bot - r:.2f}")
    parts.append(arc((right - r, bot - r), r, 0.0, math.pi / 2, True))
    parts.append(f"L {left + r:.2f} {bot:.2f}")
    parts.append(arc((left + r, bot - r), r, math.pi / 2, math.pi, True))
    parts.append("Z")
    return " ".join(parts)


def rect_ring(cx, cy, half_w, half_h, r, w, min_inner_r=40.0):
    """A hollow rounded rectangle of line weight `w` — the outer wall and
    its reversed inner wall, so it fills as an outline under nonzero."""
    outer = rounded_rect(cx, cy, half_w, half_h, r)
    inner = rounded_rect(cx, cy, half_w - w, half_h - w, max(r - w, min_inner_r))
    return f"{outer} {reversed_sub(inner)}"


def disc(cx, cy, r):
    """A filled circle. A single 0->2pi sweep is degenerate, so it goes
    round in two half-turns."""
    return (f"M {cx + r:.2f} {cy:.2f} "
            + arc((cx, cy), r, 0.0, math.pi, True) + " "
            + arc((cx, cy), r, math.pi, 2 * math.pi, True) + " Z")


def ring(cx, cy, r, w):
    """A hollow circle of line weight `w`, centred on (cx, cy)."""
    return f"{disc(cx, cy, r)} {reversed_sub(disc(cx, cy, r - w))}"


def blob(verts, radii):
    """A filled rounded polygon. `monoline.side` at zero offset *is* the
    rounded centreline, so the shape a stroke would be drawn around can be
    filled directly rather than approximated."""
    return ml._emit(*ml.side(verts, radii, 0.0, True))


def arc_points(cx, cy, r, a0, a1, n=16):
    """Sample points along a circular arc, degrees, for feeding to
    `monoline.stroke` as a polyline -- a curved stroke without a dedicated
    arc-stroking routine, since `monoline` only rounds *corners* between
    straight segments. `n` segments over the sweep is dense enough that the
    facets are invisible at the family's stroke weight."""
    a0r, a1r = math.radians(a0), math.radians(a1)
    return [(cx + r * math.cos(a0r + (a1r - a0r) * i / n),
             cy + r * math.sin(a0r + (a1r - a0r) * i / n)) for i in range(n + 1)]


def squash_y(d, cy, ky):
    """Scale every y-coordinate of a closed path toward `cy` by `ky` --
    turns a circle (e.g. from `ring`) into an ellipse exactly, since scaling
    one axis of a Bezier curve's control points scales the curve itself.
    Shared by `lamp.py` (the pendant dome) and `toilet.py` (the seat)."""
    cmds = pk.to_absolute(pk.tokenize(d))
    out = []
    for cmd, args in cmds:
        a = list(args)
        for i in range(1, len(a), 2):
            a[i] = cy + (a[i] - cy) * ky
        out.append((cmd, a))
    return pk.render(out)
